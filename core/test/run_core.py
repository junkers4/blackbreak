#!/usr/bin/env python3
"""Runs the shared cases against an assembler core through its driver.

    run_core.py <driver command...>     e.g. core/build/driver-x86_64
                                         or qemu-aarch64 core/build/driver-aarch64

The driver protocol is described in core/x86_64/driver.S. The stepping follows
spec/README.md exactly, as the JS, C# and Kotlin runners did.
"""
import json
import pathlib
import struct
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
NONE = -(1 << 63)
PHASES = ['work', 'warning', 'break', 'paused']
GET = {'phase': 0, 'canPause': 1, 'nextBreakAt': 2, 'breakEndsAt': 3,
       'warningEndsAt': 4, 'pauseEndsAt': 5, 'lastPauseDay': 6}
CONTROLLER = '--controller' in sys.argv
DRIVER = [a for a in sys.argv[1:] if a != '--controller']


def scale_bits(scale):
    return struct.unpack('<q', struct.pack('<d', float(scale)))[0]


def day(v):
    return NONE if v is None else int(v)


class Session:
    """Collects commands, runs the driver once, then hands out the answers in order."""

    def __init__(self):
        self.cmds, self.checks = [], []

    def cmd(self, line, check=None):
        self.cmds.append(line)
        if check is not None:
            self.checks.append(check)

    def run(self):
        out = subprocess.run(DRIVER, input='\n'.join(self.cmds) + '\n', capture_output=True,
                             text=True, timeout=60)
        if out.returncode:
            return [f'driver exited {out.returncode}: {out.stderr.strip()}']
        answers = out.stdout.splitlines()
        if len(answers) != len(self.checks):
            return [f'{len(answers)} answers for {len(self.checks)} questions']
        return [msg for check, ans in zip(self.checks, answers) if (msg := check(ans))]


def expect(where, want):
    def check(ans):
        return None if ans == str(want) else f'{where}: want {want}, got {ans}'
    return check


def expect_phase(where, want):
    def check(ans):
        got = PHASES[int(ans)] if ans.isdigit() and int(ans) < 4 else ans
        return None if got == want else f'{where}: want {want}, got {got}'
    return check


def scenario(sc):
    s = Session()
    start = sc.get('start', 0)
    s.cmd(f'i {start * 1000} {scale_bits(1)} {day(sc.get("lastPauseDay"))}')
    max_t = max(e['t'] for e in sc['expect'])
    idle, call, phone = 0, False, False
    for t in range(start, max_t + 1):
        step = next((st for st in sc['steps'] if st['t'] == t), None)
        if step:
            idle, call, phone = step.get('idle', 0), step.get('inCall', False), step.get('inPhoneCall', False)
        exps = [e for e in sc['expect'] if e['t'] == t]
        act = step.get('do') if step else None
        want_result = next((e['pauseResult'] for e in exps if 'pauseResult' in e), None)
        where = f'{sc["name"]} @{t}s'
        if act and act.startswith('pause:'):
            s.cmd(f'p {int(act[6:]) * 1000} {t * 1000}',
                  (lambda a: None) if want_result is None else expect(where + ' pauseResult', int(want_result)))
        elif act == 'cancelPause':
            s.cmd(f'c {t * 1000}',
                  (lambda a: None) if want_result is None else expect(where + ' pauseResult', int(want_result)))
        flags = (1 if call else 0) | (2 if phone else 0)
        s.cmd(f'u {t * 1000} {idle * 1000} {flags}')
        s.checks.append(lambda ans: None)  # the update's own answer
        for e in exps:
            s.cmd('g 0', expect_phase(where + ' phase', e['phase']))
            if 'canPause' in e:
                s.cmd('g 1', expect(where + ' canPause', int(e['canPause'])))
    return s.run()


def trace(tr):
    s = Session()
    start = tr.get('start', 0)
    s.cmd(f'i {start} {scale_bits(tr.get("scale", 1))} {day(tr.get("lastPauseDay"))}')
    last = start
    result = None
    for i, ev in enumerate(tr['events']):
        where = f'{tr["name"]} #{i}'
        if sum(k in ev for k in ('now', 'walk', 'do')) > 1:
            return [f'{where}: more than one action']
        if 'now' in ev:
            flags = (1 if ev.get('inCall') else 0) | (2 if ev.get('inPhoneCall') else 0)
            s.cmd(f'u {ev["now"]} {ev.get("idle", 0)} {flags}', lambda a: None)
            last = ev['now']
        elif 'walk' in ev:
            every = ev.get('every', 60000)
            n = last + every
            while n < ev['walk']:
                s.cmd(f'u {n} 0 0', lambda a: None)
                n += every
            s.cmd(f'u {ev["walk"]} 0 0', lambda a: None)
            last = ev['walk']
        elif 'do' in ev:
            if 'at' not in ev:
                return [f'{where}: do needs at']
            d = ev['do']
            result = {'pending': True}
            box = result
            def keep(ans, box=box):
                box['value'] = ans
            if d.startswith('pause:'):
                s.cmd(f'p {int(d[6:])} {ev["at"]}', keep)
            elif d == 'cancelPause':
                s.cmd(f'c {ev["at"]}', keep)
            else:
                return [f'{where}: unknown do {d}']
        for k, v in ev.get('expect', {}).items():
            w = f'{where} {k}'
            if k == 'phase':
                s.cmd('g 0', expect_phase(w, v))
            elif k == 'canPause':
                s.cmd('g 1', expect(w, int(v)))
            elif k == 'result':
                if result is None:
                    return [f'{where}: no do yet']
                s.checks.append(lambda a, box=result, w=w, v=v:
                                None if box.get('value') == str(int(v)) else f'{w}: want {int(v)}, got {box.get("value")}')
                s.cmds.append('m')  # a harmless question so the check has an answer to sit on
            elif k in GET:
                s.cmd(f'g {GET[k]}', expect(w, day(v)))
            else:
                return [f'{w}: unknown expect key']
    return s.run()


def units():
    """The menu, call and text rules (REQ-008/010/014/017/021, REQ-011/026-028, REQ-030)."""
    fails = []
    s = Session()
    one = scale_bits(1)
    # menu: work, warning, break, paused, after the day's pause
    s.cmd(f'i 0 {one} {NONE}')
    s.cmd('u 60000 0 0', lambda a: None)
    s.cmd('m', expect('menu in work: pause and settings', 1 | 4))
    for t in range(120000, 1195001, 60000):
        s.cmd(f'u {t} 0 0', lambda a: None)
    s.cmd('u 1195000 0 0', lambda a: None)
    s.cmd('m', expect('menu in the warning: nothing', 0))
    s.cmd('u 1200000 0 0', lambda a: None)
    s.cmd('m', expect('menu in the break: nothing', 0))
    s.cmd('u 1230000 0 0', lambda a: None)
    s.cmd('p 1800000 1230000', expect('pause in work', 1))
    s.cmd('m', expect('menu while paused: cancel and settings', 2 | 4))
    s.cmd('c 1240000', expect('cancel', 1))
    s.cmd('m', expect('menu after the day\'s pause: settings only', 4))
    s.cmd('p 1800000 1250000', expect('a second pause the same day is refused', 0))
    # local day numbers follow the time zone
    s.cmd(f'i 0 {one} 0')
    s.cmd('g 1', expect('UTC day 0 already paused', 0))
    s.cmd('t -3600000')
    s.cmd('g 1', expect('one hour west it is still the day before', 1))
    # calls: settings bits 1 exemption, 2 microphone, 4 camera
    for name, sets, mic, cam, want in [
        ('defaults (exemption off): microphone use does not count', 2 | 4, 1, 0, 0),
        ('exemption off: camera use does not count', 2 | 4, 0, 1, 0),
        ('microphone on: microphone use counts', 1 | 2, 1, 0, 1),
        ('microphone off: microphone use does not count', 1 | 4, 1, 0, 0),
        ('camera on: camera use counts', 1 | 4, 0, 1, 1),
        ('camera off: camera use does not count', 1 | 2, 0, 1, 0),
        ('nothing in use: no call', 1 | 2 | 4, 0, 0, 0)]:
        s.cmd(f'k {sets} {mic} {cam}', expect(name, want))
    # the seconds text
    for n, sk, want in [(1, 0, '1 second'), (30, 0, '30 seconds'), (0, 0, '0 seconds'),
                        (1, 1, '1 sekunda'), (2, 1, '2 sekundy'), (4, 1, '4 sekundy'),
                        (5, 1, '5 sekúnd'), (30, 1, '30 sekúnd'), (3600, 0, '3600 seconds')]:
        s.cmd(f's {n} {sk}', expect(f'seconds {n} {"sk" if sk else "en"}', want))
    return s.run()


def controller():
    """The Android controller (REQ-002, REQ-003, REQ-011, REQ-013, REQ-019, REQ-020, REQ-027)."""
    RING, VOIP = 1, 3
    one = scale_bits(1)

    def run(mode, exempt, frm, to, s):
        for t in range(frm, to + 1, 1000):
            s.cmd(f'x {t} 0 {mode} {exempt}', lambda a: None)

    out = []
    cases = []

    s = Session(); s.cmd(f'i 0 {one} {NONE}'); run(0, 0, 0, 1189000, s)
    s.cmd('x 1190000 0 0 0', expect('warning: no break screen', NONE)); s.cmd('g 0', expect_phase('warning shows the notice', 'warning'))
    cases.append(('warning shows notice', s))

    s = Session(); s.cmd(f'i 0 {one} {NONE}'); run(0, 0, 0, 1199000, s)
    s.cmd('x 1200000 0 0 0', expect('break shows overlay until breakEndsAt', 1230000))
    run(0, 0, 1201000, 1229000, s)
    s.cmd('x 1230000 0 0 0', expect('the screen goes at the end', NONE))
    cases.append(('break shows overlay until breakEndsAt', s))

    s = Session(); s.cmd(f'i 0 {one} {NONE}'); run(0, 0, 0, 1200000, s)
    s.cmd(f'x 1205000 0 {RING} 0', expect('ringing removes the break screen', NONE))
    s.cmd('x 1206000 0 0 0', expect('and it does not come back in that break', NONE))
    cases.append(('ringing during break hides overlay', s))

    s = Session(); s.cmd(f'i 0 {one} {NONE}'); run(VOIP, 0, 0, 1199000, s)
    s.cmd(f'x 1200000 0 {VOIP} 0', expect('VoIP with the switch off: the break comes', 1230000))
    cases.append(('VoIP mode ignored when exemption off', s))

    s = Session(); s.cmd(f'i 0 {one} {NONE}'); run(0, 0, 0, 1139000, s); run(VOIP, 1, 1140000, 1299000, s)
    s.cmd(f'x 1300000 0 {VOIP} 1', expect('VoIP with the switch on, seen before due: no break', NONE))
    s.cmd('g 0', expect_phase('still work', 'work'))
    s.cmd('h 1300000', expect('held', 1))
    s.cmd('x 1301000 0 0 1', lambda a: None); s.cmd('g 0', expect_phase('the call ends: the warning starts', 'warning'))
    cases.append(('VoIP mode holds when on and seen before due', s))

    s = Session(); s.cmd(f'i 0 {one} {NONE}'); run(RING, 0, 0, 1299000, s)
    s.cmd(f'x 1300000 0 {RING} 0', expect('phone call, switch off: no break', NONE))
    s.cmd('g 0', expect_phase('phone call holds without exemption', 'work'))
    cases.append(('phone call holds without exemption', s))

    s = Session(); s.cmd(f'i 0 {one} {NONE}'); run(0, 0, 0, 100000, s)
    s.cmd('o 400000 300000'); s.cmd('g 2', expect('screen off 5 min is rest', 1600000))
    cases.append(('screen off 5 min is rest', s))

    s = Session(); s.cmd(f'i 0 {one} {NONE}'); run(0, 0, 0, 100000, s)
    s.cmd('o 340000 240000'); s.cmd('g 2', expect('screen off 4 min is not', 1200000))
    cases.append(('screen off 4 min is not', s))

    for name, sess in cases:
        msgs = sess.run()
        out.append((name, msgs))
    return out


def main():
    if not DRIVER:
        sys.exit(__doc__)
    total = failed = 0
    for kind, cases, fn in [('scenario', 'scenarios.json', scenario), ('trace', 'traces.json', trace)]:
        for c in json.loads((ROOT / 'spec' / cases).read_text()):
            total += 1
            msgs = fn(c)
            print(f'  {"ok  " if not msgs else "FAIL"} {kind}: {c["name"]}')
            for m in msgs:
                print(f'       {m}')
            failed += bool(msgs)
    msgs = units()
    total += 1
    print(f'  {"ok  " if not msgs else "FAIL"} units: menu, calls, time zone, seconds')
    for m in msgs:
        print(f'       {m}')
    failed += bool(msgs)
    if CONTROLLER:
        for name, msgs in controller():
            total += 1
            print(f'  {"ok  " if not msgs else "FAIL"} controller: {name}')
            for m in msgs:
                print(f'       {m}')
            failed += bool(msgs)
    print(f'{total - failed}/{total} passed')
    sys.exit(1 if failed else 0)


if __name__ == '__main__':
    main()
