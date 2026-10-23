// Pure scheduling logic: no GNOME imports, runs under node and gjs.

export const WORK_MS = 1_200_000, WARN_MS = 10_000, BREAK_MS = 30_000,
    FAILSAFE_MS = 35_000, MAX_PAUSE_MS = 10_800_000, IDLE_MS = 300_000,
    MAX_CALL_WAIT_MS = 10_800_000;

export const Phase = Object.freeze({
    WORK: 'work', WARNING: 'warning', BREAK: 'break', PAUSED: 'paused',
});

export function localDayKey(ms) {
    const d = new Date(ms);
    const p = n => String(n).padStart(2, '0');
    return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
}

export class Scheduler {
    constructor(nowMs, {scale = 1, dayKey = localDayKey, lastPauseDay = null} = {}) {
        this._scale = scale;
        this._work = WORK_MS / scale;
        this._warn = WARN_MS / scale;
        this._break = BREAK_MS / scale;
        this._idle = IDLE_MS / scale;
        this._dayKey = dayKey;
        this._lastPauseDay = lastPauseDay;
        this._phase = Phase.WORK;
        this._workStart = nowMs;
        this._breakStart = null;
        this._holdSince = null; // when the warning was first due, while a call holds it
        this._callSeen = false; // a call was active before the warning was due
        this._phoneHeld = false; // the current hold included a phone call
        this._holdSpent = false; // a hold already ended in this interval
        this._lastNow = nowMs;
        this._idleHeld = false;
        this._pauseStart = null;
        this._pauseEnd = null;
    }

    get lastPauseDay() { return this._lastPauseDay; }
    get phase() { return this._phase; }
    get breakEndsAt() {
        return this._phase === Phase.BREAK ? this._breakStart + this._break : null;
    }
    get warningEndsAt() {
        return this._phase === Phase.WARNING ? this._workStart + this._work : null;
    }
    get nextBreakAt() {
        return this._phase === Phase.WORK || this._phase === Phase.WARNING
            ? this._workStart + this._work : null;
    }
    get pauseEndsAt() { return this._phase === Phase.PAUSED ? this._pauseEnd : null; }
    get canPause() {
        return this._phase === Phase.WORK &&
            this._dayKey(this._lastNow) !== this._lastPauseDay;
    }

    // Durations are scaled like every other duration; the cap is checked unscaled.
    pause(durationMs, now) {
        if (this._phase !== Phase.WORK || !(durationMs > 0) ||
            durationMs > MAX_PAUSE_MS || this._dayKey(now) === this._lastPauseDay)
            return false;
        this._phase = Phase.PAUSED;
        this._pauseStart = now;
        this._pauseEnd = now + durationMs / this._scale;
        this._lastPauseDay = this._dayKey(now);
        this._breakStart = null;
        return true;
    }

    cancelPause(now) {
        if (this._phase !== Phase.PAUSED)
            return false;
        this._endPause(now);
        return true;
    }

    _endPause(at) {
        this._pauseStart = this._pauseEnd = null;
        this._restart(at);
    }

    _restart(now) {
        this._phase = Phase.WORK;
        this._workStart = now;
        this._breakStart = null;
        this._holdSince = null;
        this._holdSpent = false;
        this._callSeen = false;
        this._phoneHeld = false;
    }

    update({now, idleMs = 0, inCall = false, inPhoneCall = false}) {
        if (this._phase === Phase.PAUSED) {
            // Idle input and calls do not matter; only the pause clock.
            const prev = this._lastNow;
            this._lastNow = now;
            this._idleHeld = false;
            if (now < prev) // backward step: never longer than the cap from now
                this._pauseEnd = Math.min(this._pauseEnd, now + MAX_PAUSE_MS / this._scale);
            if (now < this._pauseEnd)
                return this._phase;
            // Suspended through the end, or idle that long: the rest counts.
            const rested = now - prev >= this._idle || now - this._pauseEnd >= this._idle;
            this._endPause(rested ? now : this._pauseEnd);
            return this.update({now, idleMs, inCall, inPhoneCall});
        }
        const gap = now - this._lastNow;
        this._lastNow = now;
        if (gap < 0 || gap >= this._idle) {
            this._restart(now); // suspend or clock step counts as rest
            return this._phase;
        }

        if (idleMs >= this._idle) {
            this._idleHeld = true;
            this._restart(now);
            return this._phase;
        }
        if (this._idleHeld) {
            this._idleHeld = false;
            this._restart(now);
            return this._phase;
        }

        if (this._phase === Phase.BREAK && now >= this._breakStart + this._break)
            this._restart(this._breakStart + this._break);
        if (this._phase === Phase.WORK && !this._holdSpent) {
            // Only the work phase holds; calls in warning or break change nothing.
            const dueAt = this._workStart + this._work - this._warn;
            if (now < dueAt)
                this._callSeen = inCall || inPhoneCall;
            else if (this._holdSince !== null || this._callSeen) {
                // A call first seen once the warning is due changes nothing.
                const capEnd = dueAt + MAX_CALL_WAIT_MS / this._scale;
                if (inPhoneCall || (inCall && now < capEnd)) {
                    this._holdSince = dueAt;
                    this._phoneHeld ||= inPhoneCall;
                    return this._phase;
                }
                if (this._holdSince !== null) {
                    // Released: the warning starts now (at the cap if it ran out).
                    const at = inCall && !this._phoneHeld ? capEnd : now;
                    this._workStart = at - (this._work - this._warn);
                    this._holdSince = null;
                    this._holdSpent = true;
                    this._phoneHeld = false;
                }
            }
        }
        if (this._phase !== Phase.BREAK) {
            const elapsed = now - this._workStart;
            if (elapsed >= this._work) {
                this._phase = Phase.BREAK;
                this._breakStart = this._workStart + this._work;
                if (now >= this._breakStart + this._break)
                    this._restart(this._breakStart + this._break);
            } else {
                this._phase = elapsed >= this._work - this._warn
                    ? Phase.WARNING : Phase.WORK;
            }
        }
        return this._phase;
    }
}
