import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {Scheduler, Phase, WORK_MS, WARN_MS, BREAK_MS, IDLE_MS}
    from '../blackbreak@junkers4.github.io/scheduler.js';

const scenarios = JSON.parse(
    readFileSync(new URL('../../spec/scenarios.json', import.meta.url), 'utf8'));
const dayKey = ms => String(Math.floor(ms / 86_400_000));

function run(sc) {
    const startS = sc.start ?? 0;
    const s = new Scheduler(startS * 1000, {dayKey, lastPauseDay: sc.lastPauseDay ?? null});
    const maxT = Math.max(...sc.expect.map(e => e.t));
    let input = {};
    for (let t = startS; t <= maxT; t++) {
        const step = sc.steps.find(st => st.t === t);
        if (step)
            input = {idle: step.idle ?? 0, inCall: step.inCall ?? false,
                inPhoneCall: step.inPhoneCall ?? false};
        let result;
        const act = step?.do;
        if (act?.startsWith('pause:'))
            result = s.pause(Number(act.slice(6)) * 1000, t * 1000);
        else if (act === 'cancelPause')
            result = s.cancelPause(t * 1000);
        s.update({now: t * 1000, idleMs: (input.idle ?? 0) * 1000,
            inCall: input.inCall, inPhoneCall: input.inPhoneCall});
        for (const e of sc.expect.filter(x => x.t === t)) {
            const where = `${sc.name} @${t}s`;
            assert.equal(s.phase, e.phase, `${where} phase`);
            if (e.canPause !== undefined)
                assert.equal(s.canPause, e.canPause, `${where} canPause`);
            if (e.pauseResult !== undefined)
                assert.equal(result, e.pauseResult, `${where} pauseResult`);
        }
    }
}

for (const sc of scenarios)
    test(`scenario: ${sc.name}`, () => run(sc));

const T = WORK_MS - WARN_MS;

// Walk forward in steps below IDLE_MS so no step counts as a clock jump.
function walk(s, from, to, step = 60_000) {
    for (let n = from + step; n < to; n += step)
        s.update({now: n});
    return s.update({now: to});
}

test('suspend in work', () => {
    const s = new Scheduler(0);
    s.update({now: 0});
    s.update({now: 600_000});
    const jump = 600_000 + 4 * 3_600_000;
    assert.equal(s.update({now: jump}), Phase.WORK);
    assert.equal(walk(s, jump, jump + T - 1), Phase.WORK);
    assert.equal(s.update({now: jump + T}), Phase.WARNING);
});

test('suspend in break', () => {
    const s = new Scheduler(0);
    walk(s, 0, WORK_MS);
    assert.equal(s.phase, Phase.BREAK);
    assert.equal(s.breakEndsAt, WORK_MS + BREAK_MS);
    assert.equal(s.update({now: WORK_MS + 2 * 3_600_000}), Phase.WORK);
    assert.equal(s.breakEndsAt, null);
});

test('clock backward', () => {
    const s = new Scheduler(0);
    walk(s, 0, 1_000_000);
    assert.equal(s.update({now: 100_000}), Phase.WORK);
    assert.equal(walk(s, 100_000, 100_000 + T - 1), Phase.WORK);
    assert.equal(s.update({now: 100_000 + T}), Phase.WARNING);
});

test('clock backward during warning ends it', () => {
    const s = new Scheduler(0);
    walk(s, 0, T);
    assert.equal(s.phase, Phase.WARNING);
    assert.equal(s.warningEndsAt, WORK_MS);
    assert.equal(s.update({now: T - 5000}), Phase.WORK);
    assert.equal(s.warningEndsAt, null);
});

test('gap just under the idle limit is not a jump', () => {
    const s = new Scheduler(0);
    walk(s, 0, WORK_MS - 1, IDLE_MS - 1);
    assert.equal(s.update({now: WORK_MS}), Phase.BREAK);
});

test('idle holds the interval, restarts at first non-idle update', () => {
    const s = new Scheduler(0);
    s.update({now: 1000, idleMs: IDLE_MS});
    s.update({now: 2000, idleMs: IDLE_MS + 1000});
    s.update({now: 3000, idleMs: 0});
    assert.equal(walk(s, 3000, 3000 + T - 1), Phase.WORK);
    assert.equal(s.update({now: 3000 + T}), Phase.WARNING);
});

test('scale divides durations', () => {
    const s = new Scheduler(0, {scale: 10});
    assert.equal(walk(s, 0, T / 10 - 1, 1000), Phase.WORK);
    assert.equal(s.update({now: T / 10}), Phase.WARNING);
});

test('pause basics, scaling and cancel result', () => {
    const s = new Scheduler(0, {scale: 10, dayKey: ms => String(Math.floor(ms / 86_400_000))});
    assert.equal(s.canPause, true);
    assert.equal(s.pause(0, 0), false);
    assert.equal(s.pause(-5, 0), false);
    assert.equal(s.cancelPause(0), false);
    assert.equal(s.pause(100_000, 0), true);
    assert.equal(s.pauseEndsAt, 10_000);
    assert.equal(s.lastPauseDay, '0');
    assert.equal(s.cancelPause(1000), true);
    assert.equal(s.pauseEndsAt, null);
});
