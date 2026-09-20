#!/usr/bin/env python3
"""Generate CryptoAI PRO site icons + social banner (no third-party deps).

    python3 web/tools/make_icons.py

Writes: web/icons/{icon-192,icon-512,icon-maskable-512,apple-touch-icon,favicon-32}.png
        web/og-cover.png
The mark mirrors the app launcher (dark tile + gold rounded square + dark chart line).
"""
import os, struct, zlib, math

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "icons")
BG, GOLD, DARK, MUT, UP, TXT = (10, 14, 23), (240, 185, 11), (10, 14, 23), (131, 148, 180), (14, 203, 129), (233, 238, 251)
SS = 4  # supersampling factor


# ----------------------------------------------------------------- canvas
class Canvas:
    def __init__(self, w, h, bg=(0, 0, 0, 0)):
        self.w, self.h = w, h
        self.px = bytearray(w * h * 4)
        if bg[3]:
            for i in range(w * h):
                self.px[i * 4:i * 4 + 4] = bytes(bg)

    def blend(self, x, y, col):
        if x < 0 or y < 0 or x >= self.w or y >= self.h:
            return
        i = (y * self.w + x) * 4
        a = col[3] / 255.0
        if a <= 0:
            return
        for c in range(3):
            self.px[i + c] = int(self.px[i + c] * (1 - a) + col[c] * a + 0.5)
        self.px[i + 3] = int(self.px[i + 3] * (1 - a) + 255 * a + 0.5)

    # ---- shapes (hard edged; edges are smoothed by the final downscale)
    def round_rect(self, x, y, w, h, r, col):
        x, y, w, h, r = int(x), int(y), int(w), int(h), int(r)
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                dx = min(xx - x, x + w - 1 - xx)
                dy = min(yy - y, y + h - 1 - yy)
                if dx < r and dy < r:
                    cx, cy = x + r - 0.5, y + r - 0.5
                    if dx < r:
                        cx = x + r - 0.5 if xx - x < r else x + w - r - 0.5
                        cy = y + r - 0.5 if yy - y < r else y + h - r - 0.5
                    if math.hypot(xx - cx, yy - cy) > r:
                        continue
                self.blend(xx, yy, col)

    def rect(self, x, y, w, h, col):
        self.round_rect(x, y, w, h, 0, col)

    def disc(self, cx, cy, r, col):
        r = int(r)
        for yy in range(int(cy - r), int(cy + r) + 1):
            for xx in range(int(cx - r), int(cx + r) + 1):
                if math.hypot(xx - cx, yy - cy) <= r:
                    self.blend(xx, yy, col)

    def line(self, x1, y1, x2, y2, w, col):
        n = max(2, int(math.hypot(x2 - x1, y2 - y1) / max(w / 3.0, 1)))
        for i in range(n + 1):
            t = i / n
            self.disc(x1 + (x2 - x1) * t, y1 + (y2 - y1) * t, w / 2.0, col)

    def poly(self, pts, w, col):
        for i in range(len(pts) - 1):
            self.line(pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1], w, col)

    def downsample(self, f):
        w, h = self.w // f, self.h // f
        out = Canvas(w, h)
        for y in range(h):
            for x in range(w):
                rs = gs = bs = as_ = 0
                for dy in range(f):
                    for dx in range(f):
                        i = ((y * f + dy) * self.w + (x * f + dx)) * 4
                        a = self.px[i + 3]
                        rs += self.px[i] * a
                        gs += self.px[i + 1] * a
                        bs += self.px[i + 2] * a
                        as_ += a
                if as_ == 0:
                    continue
                j = (y * w + x) * 4
                out.px[j] = rs // as_
                out.px[j + 1] = gs // as_
                out.px[j + 2] = bs // as_
                out.px[j + 3] = as_ // (f * f)
        return out

    def png(self, path):
        raw = bytearray()
        for y in range(self.h):
            raw.append(0)
            raw += self.px[y * self.w * 4:(y + 1) * self.w * 4]
        def chunk(tag, data):
            return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        blob = b"\x89PNG\r\n\x1a\n"
        blob += chunk(b"IHDR", struct.pack(">IIBBBBB", self.w, self.h, 8, 6, 0, 0, 0))
        blob += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        blob += chunk(b"IEND", b"")
        open(path, "wb").write(blob)
        print("  %-46s %d×%d  %d bytes" % (os.path.relpath(path), self.w, self.h, len(blob)))


# ----------------------------------------------------------------- 5×7 font
FONT = {
    "F": ["11111", "10000", "11110", "10000", "10000", "10000", "10000"],
    "H": ["10001", "10001", "10001", "11111", "10001", "10001", "10001"],
    "J": ["00111", "00010", "00010", "00010", "10010", "10010", "01100"],
    "K": ["10001", "10010", "10100", "11000", "10100", "10010", "10001"],
    "M": ["10001", "11011", "10101", "10101", "10001", "10001", "10001"],
    "Q": ["01110", "10001", "10001", "10001", "10101", "10010", "01101"],
    "U": ["10001", "10001", "10001", "10001", "10001", "10001", "01110"],
    "X": ["10001", "10001", "01010", "00100", "01010", "10001", "10001"],
    "Z": ["11111", "00001", "00010", "00100", "01000", "10000", "11111"],
    "0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
    "1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
    "2": ["01110", "10001", "00001", "00110", "01000", "10000", "11111"],
    "3": ["11110", "00001", "00001", "01110", "00001", "00001", "11110"],
    "4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
    "5": ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
    "6": ["01110", "10000", "11110", "10001", "10001", "10001", "01110"],
    "7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
    "8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
    "9": ["01110", "10001", "10001", "01111", "00001", "00001", "01110"],
    "!": ["00100", "00100", "00100", "00100", "00100", "00000", "00100"],
    "%": ["11001", "11010", "00010", "00100", "01000", "01011", "10011"],
    "A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
    "B": ["11110", "10001", "11110", "10001", "10001", "10001", "11110"],
    "C": ["01110", "10001", "10000", "10000", "10000", "10001", "01110"],
    "D": ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
    "E": ["11111", "10000", "11110", "10000", "10000", "10000", "11111"],
    "G": ["01110", "10001", "10000", "10111", "10001", "10001", "01111"],
    "I": ["11111", "00100", "00100", "00100", "00100", "00100", "11111"],
    "L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
    "N": ["10001", "11001", "11001", "10101", "10011", "10011", "10001"],
    "O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
    "P": ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
    "R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
    "S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
    "T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
    "V": ["10001", "10001", "10001", "10001", "10001", "01010", "00100"],
    "W": ["10001", "10001", "10001", "10101", "10101", "11011", "10001"],
    "Y": ["10001", "10001", "01010", "00100", "00100", "00100", "00100"],
    " ": ["00000"] * 7,
    ".": ["00000", "00000", "00000", "00000", "00000", "00110", "00110"],
    "+": ["00000", "00100", "00100", "11111", "00100", "00100", "00000"],
    "/": ["00001", "00010", "00010", "00100", "01000", "01000", "10000"],
    ":": ["00000", "00110", "00110", "00000", "00110", "00110", "00000"],
    "-": ["00000", "00000", "00000", "11111", "00000", "00000", "00000"],
    "·": ["00000", "00000", "00000", "00110", "00110", "00000", "00000"],
}


def text(cv, x, y, s, scale, col, spacing=1):
    cx = x
    for ch in s.upper():
        glyph = FONT.get(ch, FONT[" "])
        for r, row in enumerate(glyph):
            for c, bit in enumerate(row):
                if bit == "1":
                    cv.rect(cx + c * scale, y + r * scale, scale, scale, col)
        cx += (5 + spacing) * scale
    return cx - spacing * scale


def text_w(s, scale, spacing=1):
    return (len(s) * (5 + spacing) - spacing) * scale


# ----------------------------------------------------------------- artwork
def draw_mark(cv, x, y, size):
    """Rounded gold tile with a dark rising chart inside (the app launcher mark)."""
    cv.round_rect(x, y, size, size, size * 0.22, GOLD + (255,))
    pts = [(0.24, 0.70), (0.40, 0.52), (0.52, 0.62), (0.66, 0.40), (0.78, 0.50)]
    cv.poly([(x + px * size, y + py * size) for px, py in pts], size * 0.075, DARK + (255,))
    cv.disc(x + 0.78 * size, y + 0.50 * size, size * 0.055, DARK + (255,))


def icon(size, maskable=False):
    cv = Canvas(size * SS, size * SS, BG + (255,))
    inner = 0.60 if maskable else 0.80
    off = (1 - inner) / 2
    cv.round_rect(off * size * SS, off * size * SS, inner * size * SS, inner * size * SS, inner * size * SS * 0.2, GOLD + (255,))
    pts = [(0.24, 0.70), (0.40, 0.52), (0.52, 0.62), (0.66, 0.40), (0.78, 0.50)]
    cv.poly([((off + px * inner) * size * SS, (off + py * inner) * size * SS) for px, py in pts], inner * size * SS * 0.075, DARK + (255,))
    cv.disc((off + 0.78 * inner) * size * SS, (off + 0.50 * inner) * size * SS, inner * size * SS * 0.055, DARK + (255,))
    return cv.downsample(SS)


def candles(cv, x, y, w, h, seed=7):
    s = seed
    def rnd():
        nonlocal s
        s = (s * 1103515245 + 12345) & 0x7FFFFFFF
        return s / 0x7FFFFFFF
    n = 26
    bw = w / n * 0.55
    price = 0.55
    for i in range(n):
        o = price
        c = min(0.98, max(0.05, o + (rnd() - 0.45) * 0.16))
        hi = max(o, c) + rnd() * 0.06
        lo = min(o, c) - rnd() * 0.06
        cx = x + (i + 0.5) * (w / n)
        col = (UP if c >= o else (246, 70, 93)) + (110,)
        cv.line(cx, y + (1 - hi) * h, cx, y + (1 - lo) * h, bw * 0.28, col)
        cv.rect(cx - bw / 2, y + (1 - max(o, c)) * h, bw, max(2, abs(c - o) * h), col)
        price = c


def cover(w=1200, h=630):
    cv = Canvas(w * 2, h * 2, BG + (255,))
    W, H = w * 2, h * 2
    for gx in range(0, W, 80):                     # faint grid
        cv.rect(gx, 0, 1, H, (31, 42, 66, 90))
    for gy in range(0, H, 80):
        cv.rect(0, gy, W, 1, (31, 42, 66, 90))
    for r in range(320, 0, -8):                    # soft gold glow behind the mark
        cv.disc(240, 270, r, GOLD + (max(0, 3 - r // 100),))
    candles(cv, W * 0.50, H * 0.32, W * 0.46, H * 0.46)                  # chart motif
    cv.line(W * 0.50, H * 0.60, W * 0.965, H * 0.30, 11, GOLD + (210,))  # gold trend line
    cv.rect(0, 0, W, 8, GOLD + (255,))
    draw_mark(cv, 90, 120, 300)
    text(cv, 440, 130, "CRYPTOAI PRO", 15, TXT + (255,))
    text(cv, 444, 266, "SINHALA + ENGLISH CRYPTO TERMINAL", 6, GOLD + (255,))
    text(cv, 444, 330, "MARKETS - SIGNALS - PAPER + LIVE TRADING - AUTO BOT", 5, MUT + (255,))
    text(cv, 92, H - 196, "ANDROID APK + WEB APP", 9, TXT + (255,))
    text(cv, 92, H - 112, "NO ACCOUNT NEEDED FOR SIGNALS OR PAPER TRADING", 5, MUT + (255,))
    return cv.downsample(2)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    print("CryptoAI PRO — generating site art")
    icon(512).png(os.path.join(OUT, "icon-512.png"))
    icon(512, maskable=True).png(os.path.join(OUT, "icon-maskable-512.png"))
    icon(192).png(os.path.join(OUT, "icon-192.png"))
    icon(180).png(os.path.join(OUT, "apple-touch-icon.png"))
    icon(32).png(os.path.join(OUT, "favicon-32.png"))
    cover().png(os.path.join(os.path.dirname(OUT), "og-cover.png"))
    print("done")
