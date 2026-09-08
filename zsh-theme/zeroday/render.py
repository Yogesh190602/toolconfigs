#!/usr/bin/env python3
"""Render a PNG to truecolor Unicode half-block art.

Each terminal cell carries two stacked pixels: the upper half is drawn as the
foreground of U+2580 (UPPER HALF BLOCK), the lower half as its background.
That makes the effective pixel grid square, so the art keeps the source's
aspect ratio instead of being squashed by the ~1:2 cell shape.
Alpha below the threshold falls through to the terminal's own background.
"""
import subprocess, sys

UPPER, LOWER, FULL = "▀", "▄", "█"
RESET, DEFBG = "\x1b[0m", "\x1b[49m"


def load(path, rows):
    w, h = subprocess.run(["identify", "-format", "%w %h", path],
                          capture_output=True, text=True, check=True).stdout.split()
    px_h = rows * 2
    px_w = max(1, round(int(w) / int(h) * px_h))
    raw = subprocess.run(
        ["magick", path, "-resize", f"{px_w}x{px_h}!", "-depth", "8", "RGBA:-"],
        capture_output=True, check=True).stdout
    return px_w, px_h, raw


def art(path, rows, alpha_min=110):
    w, h, raw = load(path, rows)

    def px(x, y):
        i = (y * w + x) * 4
        r, g, b, a = raw[i], raw[i + 1], raw[i + 2], raw[i + 3]
        return (r, g, b) if a >= alpha_min else None

    out = []
    for y in range(0, h - 1, 2):
        line, last = [], None
        for x in range(w):
            top, bot = px(x, y), px(x, y + 1)
            if top is None and bot is None:
                if last is not None:
                    line.append(DEFBG); last = None
                line.append(" ")
            elif bot is None:
                line.append("\x1b[38;2;%d;%d;%dm%s%s" % (*top, DEFBG, UPPER)); last = None
            elif top is None:
                line.append("\x1b[38;2;%d;%d;%dm%s%s" % (*bot, DEFBG, LOWER)); last = None
            else:
                line.append("\x1b[38;2;%d;%d;%dm\x1b[48;2;%d;%d;%dm%s" % (*top, *bot, UPPER))
                last = bot
        out.append("".join(line) + RESET)
    return "\n".join(out)


if __name__ == "__main__":
    print(art(sys.argv[1], int(sys.argv[2]) if len(sys.argv) > 2 else 16))
