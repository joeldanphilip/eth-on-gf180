# Technology selection

The selected closed target is **GlobalFoundries GF180MCU, 180 nm**, using the
9-track `gf180mcu_fd_sc_mcu9t5v0` family at its native 5 V operating range.
The 4096-entry MAC closes pre-layout setup/hold at 125 MHz in these views:

| Purpose | Source Liberty file | PVT |
| --- | --- | --- |
| Setup | `gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib.gz` | SS / 4.50 V / 125°C |
| Hold | `gf180mcu_fd_sc_mcu9t5v0__ff_n40C_5v50.lib.gz` | FF / 5.50 V / −40°C |
| Nominal | `gf180mcu_fd_sc_mcu9t5v0__tt_025C_5v00.lib.gz` | TT / 5.00 V / 25°C |

Final decompressed files and replayed netlist are under
`build/gf180_read_onehot_finish/`. This does not close the separate 3.3 V study
or establish a physical 5 V-core/3.3 V-PHY interface without compatible I/O or
level shifting. Physical technology views below remain downloaded references;
the achieved timing result is Liberty-only.

## Historical 3.3 V timing views

Files are supplied by the pinned OpenROAD-flow-scripts checkout under
`tools/ORFS/flow/platforms/gf180/lib/`; they are decompressed to `build/gf180`.

| Purpose | File | Process / voltage / temperature |
| --- | --- | --- |
| Nominal comparison | `gf180mcu_fd_sc_mcu9t5v0__tt_025C_3v30.lib.gz` | TT / 3.30 V / 25°C |
| Setup view | `gf180mcu_fd_sc_mcu9t5v0__ss_125C_3v00.lib.gz` | SS / 3.00 V / 125°C |
| Hold view | `gf180mcu_fd_sc_mcu9t5v0__ff_n40C_3v60.lib.gz` | FF / 3.60 V / −40°C |

Mapping uses the SS library. OpenSTA loads SS as `-max` and FF as `-min`, then
runs a separate TT comparison. This covers three representative PVT views,
not every available temperature/voltage corner. Timing uses ns and pF units.

## Physical technology and cell views

Selected five-metal/one-top-metal, 9K, nine-track files:

```
tools/ORFS/flow/platforms/gf180/lef/gf180mcu_5LM_1TM_9K_9t_tech.lef
tools/ORFS/flow/platforms/gf180/lef/gf180mcu_5LM_1TM_9K_9t_sc.lef
```

The technology LEF defines routing layers/vias and rules; the cell LEF defines
standard-cell geometry and pins. These files are downloaded and selected but
are **not consumed by the current Liberty-only synthesis/STA flow**. No physical
placement, routing or extraction result is implied by having them available.

## Commands and evidence

Run `make sta` for the sized 3.3 V banked study (`build/gf180_sized/`) or
`make -f sta/gf180.mk gf180` for the original GF180 baseline. Baseline logs, mapped
netlists, baseline/ECO results and remaining hold endpoints are kept separately
in `build/gf180/`. The GF180 ABC constraints use the library's `buf_4` driver and
13.43 fF load, with a 7 ns combinational mapping target. External clock and I/O
assumptions remain in `sta/mac.sdc`; the 8 ns clock target is unchanged.
The pipelined candidate is kept separately in `build/gf180_banked/`. It selects
RAM_PIPELINE=2 and the project banked FIFO source; the baseline uses upstream
RAM_PIPELINE=1. Read-pipeline latency therefore increases by one cycle, while
the sustained throughput target remains one GMII byte per 8 ns cycle.

The native 5 V comparison uses TT 5.0 V/25C, SS 4.5 V/125C and FF 5.5 V/-40C
files named `tt_025C_5v00`, `ss_125C_4v50`, and `ff_n40C_5v50`. Run
`make -f sta/gf180.mk gf180-5v` for the sized/banked baseline, or
`make sta-candidate` for one-hot write predecode and lookahead CRC. These are
different operating assumptions and would require compatible PHY I/O/level
shifting. They do not establish 3.3 V closure. The candidate uses a 5 ns ABC
budget while keeping the actual clock at 8 ns. See `CURRENT_STATUS.md`.

The previous Nangate45 run is retained under `build/`. Its library was
`NangateOpenCellLibrary_typical.lib`, characterized at 1.1 V and 25°C. Results
from that library do not establish GF180 performance.

Measured original GF180 mapping: SS setup WNS −9.8908 ns and FF hold WNS
+0.0908 ns; TT setup WNS −1.1027 ns and hold WNS +0.0960 ns. Those are failing
setup results, retained to motivate the banked-read pipeline. The optimized
corner results are separate and must be assessed on their own.

Upstream sources: https://github.com/google/globalfoundries-pdk-libs-gf180mcu_fd_sc_mcu9t5v0
and https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts . The direct
GF180 checkout is pinned at `3781fd2951da6e3dc4600e52d997398a9463caeb`;
ORFS is pinned in `SOURCES.md`. Consult the upstream Apache-2.0 license files.
