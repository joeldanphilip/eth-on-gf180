#!/usr/bin/env python3
"""Render a lightweight headless floorplan preview from a routed GDS."""

import os
import klayout.db as db


WIDTH = 1800
HEIGHT = 1200
MARGIN = 24
BACKGROUND = (248, 248, 248)
METAL_COLORS = {
    68: (205, 70, 70),
    69: (220, 135, 40),
    70: (55, 145, 70),
    71: (55, 105, 205),
    72: (145, 75, 170),
}


def main():
    layout = db.Layout()
    layout.read(os.environ["GDS_IN"])
    top = layout.top_cell()
    bb = top.bbox()
    scale = min((WIDTH - 2 * MARGIN) / max(bb.width(), 1),
                (HEIGHT - 2 * MARGIN) / max(bb.height(), 1))
    pixels = bytearray(BACKGROUND * (WIDTH * HEIGHT))

    def point(x, y):
        px = int(MARGIN + (x - bb.left) * scale)
        py = int(HEIGHT - MARGIN - (y - bb.bottom) * scale)
        return px, py

    def rect(box, color, fill=False):
        x0, y0 = point(box.left, box.top)
        x1, y1 = point(box.right, box.bottom)
        x0, x1 = sorted((max(0, min(WIDTH - 1, x0)), max(0, min(WIDTH - 1, x1))))
        y0, y1 = sorted((max(0, min(HEIGHT - 1, y0)), max(0, min(HEIGHT - 1, y1))))
        if fill:
            for y in range(y0, y1 + 1):
                start = (y * WIDTH + x0) * 3
                pixels[start:start + (x1 - x0 + 1) * 3] = bytes(color) * (x1 - x0 + 1)
        else:
            for x in range(x0, x1 + 1):
                for y in (y0, y1):
                    off = (y * WIDTH + x) * 3
                    pixels[off:off + 3] = bytes(color)
            for y in range(y0, y1 + 1):
                for x in (x0, x1):
                    off = (y * WIDTH + x) * 3
                    pixels[off:off + 3] = bytes(color)

    # Top-level routed metal is stored directly in the MAC cell.
    for layer_index in layout.layer_indices():
        info = layout.get_info(layer_index)
        color = METAL_COLORS.get(info.layer)
        if color is None:
            continue
        for shape in top.shapes(layer_index).each():
            rect(shape.bbox(), color, fill=False)

    # Show placed instances; SRAM macros are emphasized in dark blue.
    for inst in top.each_inst():
        name = inst.cell.name
        if name.startswith("sky130_sram_2kbyte_1rw1r_32x512_8"):
            rect(inst.bbox(), (20, 65, 155), fill=True)
            rect(inst.bbox(), (5, 25, 90), fill=False)
        else:
            rect(inst.bbox(), (170, 170, 170), fill=False)

    rect(bb, (20, 20, 20), fill=False)
    out = os.environ["PNG_OUT"]
    with open(out, "wb") as fh:
        fh.write(f"P6\n{WIDTH} {HEIGHT}\n255\n".encode())
        fh.write(pixels)
    print(f"wrote {out}: {top.name}, bbox={bb}, instances={sum(1 for _ in top.each_inst())}")


if __name__ == "__main__":
    main()
