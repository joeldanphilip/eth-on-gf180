#!/usr/bin/env python3
"""Create the hard-macro integration view used by the top-level Sky130 DRC.

The SRAM provider owns signoff of the macro's internal hierarchy.  This keeps
the routed MAC and standard-cell hierarchy, replaces the SRAM contents with
the two exact LEF M4 pin rectangles used by this routed design, and removes
the SRAM's internal child hierarchy.
"""

import argparse
import os
import klayout.db as db


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("input_gds", nargs="?")
    parser.add_argument("output_gds", nargs="?")
    parser.add_argument("--macro", default=os.environ.get("SKY130_MACRO", "sky130_sram_2kbyte_1rw1r_32x512_8"))
    args = parser.parse_args()
    if args.input_gds is None:
        args.input_gds = os.environ["SKY130_IN_GDS"]
    if args.output_gds is None:
        args.output_gds = os.environ["SKY130_OUT_GDS"]

    layout = db.Layout()
    layout.read(args.input_gds)
    macro = layout.cell(args.macro)
    if macro is None:
        raise SystemExit(f"macro cell not found: {args.macro}")

    removed = sum(1 for _ in macro.each_inst())
    macro.clear()
    m4 = layout.layer(71, 20)
    for left, right in ((190.4, 190.78), (143.48, 143.86)):
        macro.shapes(m4).insert(db.Box(
            round(left / layout.dbu),
            round(0.0 / layout.dbu),
            round(right / layout.dbu),
            round(1.06 / layout.dbu)))
    top = layout.cell("eth_mac_1g_fifo")
    reachable = set()

    def visit(cell):
        if cell.cell_index in reachable:
            return
        reachable.add(cell.cell_index)
        for inst in cell.each_inst():
            visit(inst.cell)

    visit(top)
    unused = [cell for cell in layout.each_cell() if cell.cell_index not in reachable]
    if unused:
        layout.delete_cells(unused)

    layout.write(args.output_gds)
    print(f"wrote {args.output_gds}: stripped {removed} internal instances from {args.macro}")


if __name__ == "__main__":
    main()
