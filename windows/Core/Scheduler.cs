// Pure scheduling logic: no Windows APIs, runs on any .NET 10 host.
namespace BlackBreak.Core;

public enum Phase { Work, Warning, Break, Paused }

public sealed class Scheduler
{
    public const long WorkMs = 1_200_000, WarnMs = 10_000, BreakMs = 30_000,
        FailsafeMs = 35_000, MaxPauseMs = 10_800_000, IdleMs = 300_000,
        MaxCallWaitMs = 10_800_000;

    public static string LocalDayKey(long ms) =>
        DateTimeOffset.FromUnixTimeMilliseconds(ms).ToLocalTime().ToString("yyyy-MM-dd");

    // Scaled durations can be fractional, so the internal clock values are doubles.
    readonly double _scale, _work, _warn, _break, _idle;
    readonly Func<long, string> _dayKey;
    string? _lastPauseDay;
    Phase _phase = Phase.Work;
    double _workStart;
    double? _breakStart;
    double? _holdSince; // when the warning was first due, while a call holds it
    bool _callSeen; // a call was active before the warning was due
    bool _phoneHeld; // the current hold included a phone call
    bool _holdSpent; // a hold already ended in this interval
    double _lastNow;
    bool _idleHeld;
    double? _pauseStart;
    double? _pauseEnd;

    public Scheduler(long nowMs, double scale = 1, Func<long, string>? dayKey = null, string? lastPauseDay = null)
    {
        _scale = scale;
        _work = WorkMs / scale;
        _warn = WarnMs / scale;
        _break = BreakMs / scale;
        _idle = IdleMs / scale;
        _dayKey = dayKey ?? LocalDayKey;
        _lastPauseDay = lastPauseDay;
        _workStart = nowMs;
        _lastNow = nowMs;
    }

    static long Ms(double v) => (long)Math.Round(v);

    public string? LastPauseDay => _lastPauseDay;
    public Phase Phase => _phase;
    public long? BreakEndsAt => _phase == Phase.Break ? Ms(_breakStart!.Value + _break) : null;
    public long? WarningEndsAt => _phase == Phase.Warning ? Ms(_workStart + _work) : null;
    public long? NextBreakAt => _phase is Phase.Work or Phase.Warning ? Ms(_workStart + _work) : null;
    public long? PauseEndsAt => _phase == Phase.Paused ? Ms(_pauseEnd!.Value) : null;
    public bool CanPause => _phase == Phase.Work && _dayKey(Ms(_lastNow)) != _lastPauseDay;

    // Durations are scaled like every other duration; the cap is checked unscaled.
    public bool Pause(long durationMs, long now)
    {
        if (_phase != Phase.Work || !(durationMs > 0) ||
            durationMs > MaxPauseMs || _dayKey(now) == _lastPauseDay)
            return false;
        _phase = Phase.Paused;
        _pauseStart = now;
        _pauseEnd = now + durationMs / _scale;
        _lastPauseDay = _dayKey(now);
        _breakStart = null;
        return true;
    }

    public bool CancelPause(long now)
    {
        if (_phase != Phase.Paused)
            return false;
        EndPause(now);
        return true;
    }

    void EndPause(double at)
    {
        _pauseStart = _pauseEnd = null;
        Restart(at);
    }

    void Restart(double now)
    {
        _phase = Phase.Work;
        _workStart = now;
        _breakStart = null;
        _holdSince = null;
        _holdSpent = false;
        _callSeen = false;
        _phoneHeld = false;
    }

    public Phase Update(long now, long idleMs = 0, bool inCall = false, bool inPhoneCall = false)
    {
        if (_phase == Phase.Paused)
        {
            // Idle input and calls do not matter; only the pause clock.
            var prev = _lastNow;
            _lastNow = now;
            _idleHeld = false;
            if (now < prev) // backward step: never longer than the cap from now
                _pauseEnd = Math.Min(_pauseEnd!.Value, now + MaxPauseMs / _scale);
            if (now < _pauseEnd)
                return _phase;
            // Suspended through the end, or idle that long: the rest counts.
            var rested = now - prev >= _idle || now - _pauseEnd!.Value >= _idle;
            EndPause(rested ? now : _pauseEnd!.Value);
            return Update(now, idleMs, inCall, inPhoneCall);
        }
        var gap = now - _lastNow;
        _lastNow = now;
        if (gap < 0 || gap >= _idle)
        {
            Restart(now); // suspend or clock step counts as rest
            return _phase;
        }

        if (idleMs >= _idle)
        {
            _idleHeld = true;
            Restart(now);
            return _phase;
        }
        if (_idleHeld)
        {
            _idleHeld = false;
            Restart(now);
            return _phase;
        }

        if (_phase == Phase.Break && now >= _breakStart!.Value + _break)
            Restart(_breakStart.Value + _break);
        if (_phase == Phase.Work && !_holdSpent)
        {
            // Only the work phase holds; calls in warning or break change nothing.
            var dueAt = _workStart + _work - _warn;
            if (now < dueAt)
                _callSeen = inCall || inPhoneCall;
            else if (_holdSince is not null || _callSeen)
            {
                // A call first seen once the warning is due changes nothing.
                var capEnd = dueAt + MaxCallWaitMs / _scale;
                if (inPhoneCall || (inCall && now < capEnd))
                {
                    _holdSince = dueAt;
                    _phoneHeld |= inPhoneCall;
                    return _phase;
                }
                if (_holdSince is not null)
                {
                    // Released: the warning starts now (at the cap if it ran out).
                    var at = inCall && !_phoneHeld ? capEnd : now;
                    _workStart = at - (_work - _warn);
                    _holdSince = null;
                    _holdSpent = true;
                    _phoneHeld = false;
                }
            }
        }
        if (_phase != Phase.Break)
        {
            var elapsed = now - _workStart;
            if (elapsed >= _work)
            {
                _phase = Phase.Break;
                _breakStart = _workStart + _work;
                if (now >= _breakStart + _break)
                    Restart(_breakStart.Value + _break);
            }
            else
            {
                _phase = elapsed >= _work - _warn ? Phase.Warning : Phase.Work;
            }
        }
        return _phase;
    }
}
