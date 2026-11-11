"""Blizzard's art for the benches, made locally: files downloaded from this build's game data on wago.tools (each
cached, so a re-run is quick), BLP textures decoded, PNGs written. What it makes is Blizzard's: local only, never
published (.gitignore keeps the benches' art/ out). First written for KaLi Quest's bench.
"""
import struct
import time
import urllib.request
import zlib

# The game data's build the benches' art and the generated tables come from, one small patch behind the client.
BUILD = "1.60.1.70790"
CASC = "https://wago.tools/api/casc/{}?version=" + BUILD


def fetch(url, dest):
    if dest.exists() and dest.stat().st_size > 0:
        return dest.read_bytes()
    for attempt in range(3):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "wow-addon-testbench"})
            with urllib.request.urlopen(req, timeout=120) as r:
                data = r.read()
            dest.write_bytes(data)
            return data
        except Exception as e:
            print("  retry", attempt + 1, url, e)
            time.sleep(2 + attempt * 3)
    raise SystemExit(f"Could not download {url}")


def dxt_colors(c0, c1, force_four):
    def rgb(c):
        return (((c >> 11) & 31) * 255 // 31, ((c >> 5) & 63) * 255 // 63, (c & 31) * 255 // 31)
    a, b = rgb(c0), rgb(c1)
    if force_four or c0 > c1:
        return [a + (255,), b + (255,),
                tuple((2 * a[i] + b[i]) // 3 for i in range(3)) + (255,),
                tuple((a[i] + 2 * b[i]) // 3 for i in range(3)) + (255,)]
    return [a + (255,), b + (255,), tuple((a[i] + b[i]) // 2 for i in range(3)) + (255,), (0, 0, 0, 0)]


def decode_dxt(data, w, h, kind):
    """kind: 1, 3 or 5. Returns RGBA bytes."""
    out = bytearray(w * h * 4)
    block_size = 8 if kind == 1 else 16
    pos = 0
    for by in range(0, h, 4):
        for bx in range(0, w, 4):
            alpha = None
            if kind == 3:
                bits = int.from_bytes(data[pos:pos + 8], "little")
                alpha = [((bits >> (4 * i)) & 15) * 17 for i in range(16)]
            elif kind == 5:
                a0, a1 = data[pos], data[pos + 1]
                if a0 > a1:
                    table = [a0, a1] + [((7 - i) * a0 + i * a1) // 7 for i in range(1, 7)]
                else:
                    table = [a0, a1] + [((5 - i) * a0 + i * a1) // 5 for i in range(1, 5)] + [0, 255]
                bits = int.from_bytes(data[pos + 2:pos + 8], "little")
                alpha = [table[(bits >> (3 * i)) & 7] for i in range(16)]
            color_pos = pos + (0 if kind == 1 else 8)
            c0, c1 = struct.unpack_from("<HH", data, color_pos)
            colors = dxt_colors(c0, c1, kind != 1)
            indices = struct.unpack_from("<I", data, color_pos + 4)[0]
            for py in range(4):
                y = by + py
                if y >= h:
                    continue
                for px in range(4):
                    x = bx + px
                    if x >= w:
                        continue
                    i = py * 4 + px
                    r, g, b, a = colors[(indices >> (2 * i)) & 3]
                    if alpha is not None:
                        a = alpha[i]
                    o = (y * w + x) * 4
                    out[o:o + 4] = bytes((r, g, b, a))
            pos += block_size
    return bytes(out)


def decode_blp(blob):
    if blob[:4] != b"BLP2":
        raise ValueError("Not a BLP2 file")
    compression, alpha_depth, alpha_type = blob[8], blob[9], blob[10]
    w, h = struct.unpack_from("<II", blob, 12)
    offset = struct.unpack_from("<I", blob, 20)[0]
    size = struct.unpack_from("<I", blob, 84)[0]
    mip = blob[offset:offset + size]
    if compression == 2:
        kind = {0: 1, 1: 3, 7: 5}.get(alpha_type)
        if kind is None:
            raise ValueError(f"Unknown DXT type {alpha_type}")
        return w, h, decode_dxt(mip, w, h, kind)
    if compression == 3:  # BGRA
        out = bytearray(mip[:w * h * 4])
        out[0::4], out[2::4] = out[2::4], out[0::4]
        return w, h, bytes(out)
    if compression == 1:  # 256-colour palette, then alpha
        palette = blob[148:148 + 1024]
        out = bytearray(w * h * 4)
        n = w * h
        for i in range(n):
            p = mip[i] * 4
            out[i * 4:i * 4 + 3] = bytes((palette[p + 2], palette[p + 1], palette[p]))
            if alpha_depth == 8:
                a = mip[n + i]
            elif alpha_depth == 1:
                a = 255 if mip[n + i // 8] >> (i % 8) & 1 else 0
            elif alpha_depth == 4:
                a = ((mip[n + i // 2] >> (4 * (i % 2))) & 15) * 17
            else:
                a = 255
            out[i * 4 + 3] = a
        return w, h, bytes(out)
    raise ValueError(f"Unknown compression {compression}")


def write_png(path, w, h, rgba):
    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data))
    stride = w * 4
    raw = b"".join(b"\0" + rgba[y * stride:(y + 1) * stride] for y in range(h))
    path.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
                     + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))
