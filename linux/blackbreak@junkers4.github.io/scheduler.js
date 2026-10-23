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
        this._work = WORK_MS / scale;
        this._warn = WARN_MS / scale;
        this._break = BREAK_MS / scale;
        this._idle = IDLE_MS / scale;
        this._dayKey = dayKey;
        this._lastPauseDay = lastPauseDay;
        this._phase = Phase.WORK;
        this._workStart = nowMs;
        this._breakStart = null;
        this._lastNow = nowMs;
        this._idleHeld = false;
    }

    get lastPauseDay() { return this._lastPauseDay; }
    get phase() { return this._phase; }
    get breakEndsAt() {
        return this._phase === Phase.BREAK ? this._breakStart + this._break : null;
    }
    get warningEndsAt() {
        return this._phase === Phase.WARNING ? this._workStart + this._work : null;
    }
    get pauseEndsAt() { return null; }
    get canPause() { return this._phase === Phase.WORK; }

    pause(_durationMs, _now) { return false; }
    cancelPause(_now) { return false; }

    _restart(now) {
        this._phase = Phase.WORK;
        this._workStart = now;
        this._breakStart = null;
    }

    update({now, idleMs = 0, inCall = false, inPhoneCall = false}) {
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

        // Calls are handled in a later task.
        void inCall; void inPhoneCall;

        if (this._phase === Phase.BREAK && now >= this._breakStart + this._break)
            this._restart(this._breakStart + this._break);
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
