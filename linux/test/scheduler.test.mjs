import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {Scheduler}
    from '../blackbreak@junkers4.github.io/scheduler.js';

const scenarios = JSON.parse(
    readFileSync(new URL('../../spec/scenarios.json', import.meta.url), 'utf8'));
const traces = JSON.parse(
    readFileSync(new URL('../../spec/traces.json', import.meta.url), 'utf8'));
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

function runTrace(tr) {
    const start = tr.start ?? 0;
    const s = new Scheduler(start, {scale: tr.scale ?? 1, dayKey,
        lastPauseDay: tr.lastPauseDay ?? null});
    let last = start;
    let result;
    const update = (now, ev = {}) => {
        s.update({now, idleMs: ev.idle ?? 0, inCall: ev.inCall ?? false,
            inPhoneCall: ev.inPhoneCall ?? false});
        last = now;
    };
    tr.events.forEach((ev, i) => {
        if (ev.now !== undefined)
            update(ev.now, ev);
        else if (ev.walk !== undefined) {
            const every = ev.every ?? 60_000;
            for (let n = last + every; n < ev.walk; n += every)
                update(n);
            update(ev.walk);
        } else if (ev.do !== undefined) {
            if (ev.do.startsWith('pause:'))
                result = s.pause(Number(ev.do.slice(6)), ev.at);
            else if (ev.do === 'cancelPause')
                result = s.cancelPause(ev.at);
            else
                assert.fail(`${tr.name} #${i}: unknown do ${ev.do}`);
        }
        for (const [k, v] of Object.entries(ev.expect ?? {}))
            assert.equal(k === 'result' ? result : s[k], v, `${tr.name} #${i} ${k}`);
    });
}

for (const tr of traces)
    test(`trace: ${tr.name}`, () => runTrace(tr));
