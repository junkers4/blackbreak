# Checks a screenshot of the break: warm black background, light pixel text in the upper half.
import struct, sys, zlib

def read_png(path):
    data = open(path, 'rb').read()
    pos, chunks = 8, {}
    idat = b''
    while pos < len(data):
        n, kind = struct.unpack('>I4s', data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + n]
        if kind == b'IHDR':
            w, h, depth, ctype = struct.unpack('>IIBB', body[:10])
        elif kind == b'IDAT':
            idat += body
        pos += 12 + n
    bpp = {6: 4, 2: 3}[ctype]
    raw = zlib.decompress(idat)
    rows, prev, stride, i = [], bytearray(w * bpp), w * bpp, 0
    for _ in range(h):
        f, line = raw[i], bytearray(raw[i + 1:i + 1 + stride])
        i += 1 + stride
        for x in range(stride):
            a = line[x - bpp] if x >= bpp else 0
            b = prev[x]
            c = prev[x - bpp] if x >= bpp else 0
            if f == 1: line[x] = (line[x] + a) & 255
            elif f == 2: line[x] = (line[x] + b) & 255
            elif f == 3: line[x] = (line[x] + (a + b) // 2) & 255
            elif f == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                line[x] = (line[x] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        rows.append(line)
        prev = line
    return w, h, bpp, rows

w, h, bpp, rows = read_png(sys.argv[1])
px = lambda x, y: tuple(rows[y][x * bpp:x * bpp + 3])
fails = 0
corner = px(3, 3)
ok = all(abs(a - b) <= 2 for a, b in zip(corner, (0x0D, 0x0C, 0x0B)))
print(f"  {'ok  ' if ok else 'FAIL'} background is #0D0C0B (got {corner})"); fails += not ok
far = px(w - 4, h - 4)
ok = all(abs(a - b) <= 2 for a, b in zip(far, (0x0D, 0x0C, 0x0B)))
print(f"  {'ok  ' if ok else 'FAIL'} the second monitor is covered too (bottom right {far})"); fails += not ok
bright = sum(1 for y in range(0, h // 2, 2) for x in range(0, w, 2) if px(x, y)[0] > 200)
ok = bright > 300
print(f"  {'ok  ' if ok else 'FAIL'} the lines are drawn in the upper half ({bright} light pixels)"); fails += not ok
sys.exit(1 if fails else 0)
