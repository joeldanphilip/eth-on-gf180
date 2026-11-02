# GF180 MAC physical implementation

Current run: `build/physical_pipeline_layout/` with
`physical/pipeline_eco_design.mk`. SAT-proven local RX/TX gate-tree ECOs pass
placement timing at +0.1734 ns setup / +0.1684 ns hold; the first global-route
timing result was +0.1115/+0.1522 ns. A completed clean reroute reproduced
those margins after `eco_pre_grt.tcl` cleared inherited cached guides and
orphan nets. The corrected `eco-clean-guides` audit accepts legal single-cell
Metal1 pin access, including the oversized final GCell, and found zero invalid
guides. Detailed routing is running (`build/eco_drt_validated.log`). This does
not establish detailed-route or extracted closure.

The active ECO flow uses eight threads and sparse DRC snapshots. Explicit
`eco-extract` targets take `CORNER=WC`, `BC`, and `TC`, followed by
`eco-check-extracted`; `eco-finish` and `eco-gds` operate directly on the
routed checkpoint without rebuilding deleted upstream intermediates.
Native Ruby DRC/LVS execution is now available through
`physical/bin/klayout-native` (KLayout 0.30.12); the separate Python stream-out
adapter remains available. `scripts/prepare_gf180_lvs.py` keeps the original
CDL devices and binds omitted VNW/VPW ports to VDD/VSS in the top schematic.
Actual GDS LVS must validate that normal body-rail contract through tapcells.
Legacy positional antenna-diode area/perimeter fields are normalized to
explicit SPICE A/P parameters without changing values or device models.
The small NAND-plus-tap fixture passes transistor LVS; the MAC requires its
own completed comparison.
All DRC/LVS result claims require completed design runs, not tool smoke tests.

After `eco-drt` completes, run the serial, fail-on-error acceptance sequence:

```sh
make -f physical/Makefile \
  WORK_HOME="$PWD/build/physical_pipeline_layout" eco-verify-final
```

It requires a completed zero-violation route and zero antenna violations,
binds physical power pins, finishes the layout, then extracts WC/BC/TC from
the exact `6_final.odb` used for GDS. It checks functional setup/hold and electrical
limits, audits the 85 mapped CDC paths, and then writes GDS/CDL and runs
full public GF180 DRC and transistor LVS. `eco-check-route` rejects stale or
incomplete logs. This command has been staged; its successful completion is
still required before accepting the final GDS.

Input: the verified 4096-entry MAC netlist from
`build/gf180_read_onehot_finish/mac_resized.v`, with the original 8 ns clocks.
The pinned ORFS flow consumes the GF180 nine-track 5LM/1TM/9K LEF/GDS views
and WC/BC/TC 5 V Liberty views. This is a MAC block with its existing signal
ports, not a pad-frame integration.

Project-local OpenROAD: `26Q2-1164-g08f67ee5ec`, public Ubuntu 24.04 package.
Package MD5: `fb584a509787fae166276e148e7524de` (matches the vendor API).
KLayout: Python layout engine 0.30.12; the batch adapter supports the ORFS
Python stream-out script. It does not implement Ruby DRC/LVS decks.

Run `make -f physical/Makefile floorplan`, then `place`, `cts`, `route`,
`finish`, and `gds`. Checkpoints, reports and logs are under `build/physical/`;
the latest compatible-flow run is under `build/physical_compat_rc/`.
Each stage is a real ORFS/OpenROAD operation, using the saved mapped netlist
instead of rerunning RTL synthesis. Four worker threads limit memory pressure.

`layer_rc.tcl` uses ohm/um resistance from the selected LEF sheet resistance and
wire width, plus public platform capacitance estimates. The platform's raw
per-length resistance numbers are inconsistent with the current flow's ohm
command units; the override prevents optimistic placement RC. Final extraction
must use the foundry OpenRCX rules and be reported separately from these estimates.

Intermediate power/IR reporting is disabled in this run. The power grid is
physically generated, and lightweight timing/electrical checks are saved per
stage. Power/IR signoff is a separate, unverified item.

Pre-layout timing closure is prior evidence only. Placement/CTS/routing timing,
route DRC, extracted timing, GDS completeness, and foundry DRC/LVS must each be
reported from their actual completed checks before signoff is claimed.

Earlier physical baseline: floorplan/PDN, legal placement, CTS, and global
route completed with failing timing. Detailed routing was interrupted after
93,631 first-pass violations; that is not a final DRC result. No final GDS is
accepted. The active structural revisions below address measured critical
paths; the earlier interrupted run did not establish that SRAM is mandatory.

## Active SoC-block implementation

The user confirmed the target is a MAC IP block inside a SoC. The first
candidate enables `DECOUPLE_READ`, using the existing output queue to remove
downstream ready from the bank/group read pipeline. Main frame storage remains
4096 entries per direction. The candidate passed the full packet/error and
upstream eight-case GMII/MII suites (485.90 s), 100-step bounded FIFO safety,
all three covers, and full-size TX/RX pointer/decode induction. This is scoped
formal verification, not an unbounded proof of the complete MAC.

Its mapped netlist is `build/gf180_decoupled_read/mac_mapped.v` (263,194 cells,
zero Yosys structural problems). A fresh physical run is under
`build/physical_decoupled/`, driven by `decoupled_design.mk`:

```sh
make test-decoupled-read
make formal-decoupled-read
make -f sta/gf180.mk gf180-decoupled-read
make -f physical/Makefile WORK_HOME="$PWD/build/physical_decoupled" decoupled-cts
```

`soc_interface.tcl` states the hierarchical timing assumption explicitly:
neighboring SoC registers are balanced to a representative MAC clock leaf in
each domain, retaining 8 ns periods and 1.0/0.2 ns interface budgets. This
assumption requires validation in top-level CTS/STA; it is not a PHY board
timing specification. Native cell PVT and extracted interconnect checks remain
required for actual block timing closure. No closure or GDS is claimed merely
because the interface target was clarified.

The next candidate adds registered one-hot bank/group selection and a
registered write stage (`READ_BANK_ONEHOT`, `PIPELINED_WRITE`). Commit
visibility is delayed with physical writes. It mapped to 259,559 cells and
passed reduced FIFO safety/cover and full-size control/alignment induction.
An additional arbitrary-clock BMC passed 40 steps. Its packet regressions and
physical timing results are recorded separately as those stages finish.

```sh
make test-physical-pipeline
make formal-physical-pipeline formal-physical-pipeline-arbitrary
make -f sta/gf180.mk gf180-physical-pipeline
.venv/bin/python physical/preflight.py --profile build/gf180_physical_pipeline --stem mac_mapped --soc --design-config physical/pipeline_design.mk --output build/physical_pipeline_layout/input_manifest.json
make -f physical/Makefile WORK_HOME="$PWD/build/physical_pipeline_layout" pipeline-cts
make -f physical/Makefile WORK_HOME="$PWD/build/physical_pipeline_layout" pipeline-repair
```

`pipeline-grt`, `pipeline-drt`, and `pipeline-extract` operate on saved
checkpoints. Promote a repaired checkpoint only after reviewing its actual
timing and placement results; the existence of a checkpoint is not closure.
Extraction runs separately with `CORNER=WC`, `BC`, and `TC`, followed by
`pipeline-check-extracted` to load all three SPEFs into the same analysis.

Latest pipeline result: CTS repair reached -0.3304/+0.1684 ns setup/hold;
global route measured -0.4160/+0.1522 ns with zero overflow. Detailed routing
reported 83,609 violations in iteration 0 and was interrupted as iteration 1
started. This does not establish non-convergence across the configured 64
iterations. No final route or GDS was accepted. The Metal1 variant completed
global routing at -0.3870/+0.1545 ns, but its detailed routing was interrupted
at 10% of the initial iteration. Both routing results remain incomplete.
