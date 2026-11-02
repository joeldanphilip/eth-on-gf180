# Current measured status

**125 MHz pre-layout setup/hold closure is achieved** for the 4096-entry TX/RX
MAC using GF180MCU 180 nm, nine-track cells at the native 5 V operating range.
The exact replayed netlist passes SS/FF setup/hold and TT checks, with zero TNS:
SS setup +0.0515 ns, FF hold +0.1578 ns, TT setup/hold +3.1994/+0.1982 ns.
All clocks are 8 ns. This is Liberty-only analysis with ideal clocks; placement,
CTS, routing and extracted-parasitic signoff remain outstanding. The 3.3 V
studies below remain separate failing historical results.

The selected RTL uses `ELASTIC_READ`, `FAST_CONTROL`, `REGISTER_EMPTY`,
`FULL_LOOKAHEAD`, `WRITE_AHEAD`, `READ_ONEHOT`, registered full flags and one-hot
write decode, plus RX CRC lookahead. Full MAC simulation passed both suites
(`2 passed in 520.08s`), reduced 100-step safety BMC/covers passed, and full-size
TX/RX pointer, row-selection and control invariants passed unbounded induction.
This does not constitute a full-MAC unbounded proof.

Final artifacts: `build/gf180_read_onehot_finish/mac_resized.v`,
`timing_ss_ff.log`, `timing_tt.log`, `closure_ss_ff.json`, `closure_tt.json`.
Both closure gates report `timing_met: true`; Yosys reports zero structural
problems. The two sizing stages accepted 21 then 13 same-family drive changes;
JSON replay preserves constants and wiring. No clock reduction, FIFO capacity
reduction, added false path or multicycle exception was used for this result.
Run `make sta` or `make sta-check` for the saved netlist, `make verify-1g` for
simulation/formal/STA, or `make sta-close-1g` to rebuild and search from RTL.
Search duration may change the chosen swaps; the closure gates enforce the
result rather than assuming a rerun succeeds.

## Technology

Earlier verified control improvement: `FAST_CONTROL` + `REGISTER_EMPTY` on the
elastic FIFO passes the full-depth MAC suites, reduced 100-step BMC/covers,
and full-size TX/RX induction of exact empty, carry, full-frame and decode
invariants. A 31-change sizing replay measures SS setup -0.6166 ns, FF hold
+0.1578 ns, and TT +2.9733/+0.1982 ns. SS TNS is -2821.03 ns. The replayed
netlist has zero structural problems. Evidence is in `build/gf180_empty/` and
`build/gf180/{empty_simulation,empty_formal,empty_invariant}.log`.
The additional `FULL_LOOKAHEAD` rewrite passes tests and proofs but maps to the
same 271061-cell circuit as registered empty, so it adds no timing gain. The
remaining worst resized path is TX write-pointer to `full_reg`, clocked by
logic. Consolidated results are in `build/control_report_summary.json`.

The new opt-in `ELASTIC_READ` FIFO passes the project suite and all eight
upstream GMII/MII compatibility cases (`2 passed in 250.88s`). It adds an
independent address stage and separates fetch reservation from storage-credit
release. At the native 5 V corners and 8 ns clocks its mapped/checked netlist
measures SS setup -0.9159 ns, FF hold +0.1578 ns, and TT +2.8496/+0.1981 ns.
No hold buffers were needed. The worst path now involves RX write-side
drop-frame/full control; fetch-pointer control also limits timing. See
`build/gf180_elastic/timing_ss_ff.log` and `timing_tt.log`. Slow-corner setup
remained open for that profile. Commands: `make test-elastic`, `make formal-elastic`, and
`make -f sta/gf180.mk gf180-elastic`.

The elastic candidate's 100-step safety BMC and three cover goals within 320
steps passed (`build/gf180/elastic_checked_formal.log`). A 35-change same-family
sizing replay improves SS setup to -0.8296 ns and TNS to -5098.44 ns; hold and
TT results stay positive. The replay preserves constants and wiring, and Yosys
reports zero structural problems. Final reports are
`build/gf180_elastic/timing_resized_ss_ff.log` and `timing_resized_tt.log`.

Historical study target: 9-track `gf180mcu_fd_sc_mcu9t5v0`, 3.3 V nominal, with SS
3.0 V/125C setup and FF 3.6 V/-40C hold. Also evaluated its published 5 V range.
Exact timing/physical file names and usage are in [TECHNOLOGY.md](TECHNOLOGY.md).
LEFs are downloaded; no placement, CTS, routing or extracted-parasitic run exists.

## Recorded timing at 8 ns clocks

| Saved experiment | SS setup WNS (ns) | FF hold WNS (ns) | TT setup WNS (ns) | TT hold WNS (ns) |
| --- | ---: | ---: | ---: | ---: |
| Selected 4096-entry write-ahead/one-hot-read MAC + sizing, 5 V range | +0.0515 | +0.1578 | +3.1994 | +0.1982 |
| GF180 original, 3.3 V range | -9.8908 | +0.0908 | -1.1027 | +0.0960 |
| Banked read, 3.3 V range | -9.7969 | +0.0786 | -1.2918 | +0.0758 |
| Sized banked, 3.3 V range | -7.3520 | +0.0583 | +0.2383 | +0.0487 |
| Sized banked, 5 V range | -1.6457 | +0.0645 | +2.6974 | +0.0560 |
| One-hot write + CRC lookahead, 5 V range | -2.1043 | +0.1524 | +2.0399 | +0.1878 |
| Registered full flags + one-hot write + CRC lookahead, 5 V range | -0.9877 | +0.1578 | +2.4988 | +0.1982 |
| Elastic FIFO + optimized full-frame/fetch control + registered empty + sizing, 5 V range | -0.6166 | +0.1578 | +2.9733 | +0.1982 |

The final sizing experiment accepted five additional drive-grade substitutions.
Its complete corrected-netlist reports are
`build/gf180_closure/timing_resized_ss_ff.log` and `timing_resized_tt.log`.
The search log is `build/gf180_closure/resize.log`. It improved SS setup to
approximately -1.9767 ns and retained +0.1524 ns hold; TT is +2.0399/+0.1878 ns.
It did not close slow-corner timing. Yosys reports zero connectivity problems
on the corrected, constant-preserving resized netlist.

These are recorded results for the saved netlists. Different supply ranges are
different operating assumptions, not fixes to the 3.3 V result. A physical 5 V
core/3.3 V PHY integration would require compatible I/O/level shifting.

The registered-full candidate was the best profile before the elastic rewrite.
It registers the write-side full controls using the second synchronized read
pointer and adds conservative ready latency; its transactional FIFO checks and
full-flag invariant pass. A 42-change same-family sizing replay reduced the
slow-corner TNS to -10037.82 ns but did not improve WNS beyond -0.9701 ns.
The corrected replay netlist passes Yosys structural checking; OpenSTA's raw
temporary Verilog is retained only as a diagnostic and is not the signoff
artifact.

## Verification evidence

| Check | Result and scope | Evidence |
| --- | --- | --- |
| Upstream MAC packet regression | PASS, original RTL | `build/test_final.log` |
| Full-depth banked MAC packet/error tests | PASS, 4096 entries | `build/gf180/banked_4096_simulation.log` |
| Banked upstream GMII/MII and clock-enable suite | PASS | `build/gf180/banked_upstream_simulation.log` |
| Final one-hot/CRC candidate packet/error tests | PASS | `build/gf180/closure_simulation.log` |
| Final candidate upstream GMII/MII suite | PASS | `build/gf180/closure_upstream_simulation.log` |
| Byte FIFO, arbitrary-clock schedules | PASS, 30-step BMC, depth four | `build/verified_formal.log` |
| Byte FIFO, periodic schedules | PASS, 60-step BMC | `build/periodic_formal.log` |
| Frame FIFO commit/order/stall checks | PASS, 100-step BMC, short good frames, depth four | `build/frame_bitwuzla.log` |
| Banked FIFO reference equivalence | PASS, 100 steps, depth 32 / two data bits | `build/gf180/banked_formal.log` |
| One-hot FIFO reference equivalence | PASS, same reduced configuration | `build/gf180/onehot_formal.log` |
| RX block reference equivalence | PASS, **unbounded k-induction** | `build/gf180/rx_induction.log` |
| One-hot decode/pointer consistency | PASS, **unbounded k-induction**, actual 4096-entry/eight-data-bit TX and RX configurations | `build/gf180/onehot_full_invariant.log` |
| Registered-full FIFO transactional checks | PASS, 100-step BMC plus three covers | `build/gf180/registered_formal.log` |
| Registered-full full-flag/decode invariant | PASS, **unbounded k-induction**, actual 4096-entry/eight-data-bit TX and RX configurations | `build/gf180/registered_invariant.log` |
| Registered-full packet/error tests | PASS, full-depth 4096-entry suite | `build/gf180/registered_simulation.log` |
| Registered-full upstream GMII/MII suite | PASS, eight compatibility cases | `build/gf180/registered_upstream_simulation.log` |

The unbounded RX proof uses eight-bit data and full 32-bit CRC, arbitrary PHY
input/error, clock-enable/MII/configuration inputs, PTP disabled, declared RTL
initial state and a modeled two-cycle startup reset. It proves equivalence to
the upstream receiver, not independent IEEE compliance or arbitrary reset
recovery. The full-size decode invariant does not prove FIFO payload/liveness.
**There is no unbounded proof of the complete MAC system.**

## Reproduce

```sh
make test                      # original reference regression
make test-banked               # banked implementation
make test-closure              # one-hot/CRC candidate
make formal                    # original bounded byte-FIFO checks
make formal-frame
make formal-banked
make formal-rx                 # unbounded RX reference comparison + cover
make formal-onehot             # unbounded full-size decode consistency
make -f sta/gf180.mk gf180-registered  # registered-full 5 V timing candidate
make sta                       # selected closed 4096-entry 5 V netlist
make sta-close-1g               # rebuild selected RTL and run both sizing stages
make verify-1g                  # selected packet tests, FIFO proofs, saved STA
make sta-gf180-3v3              # historical 3.3 V study
make sta-candidate             # one-hot/CRC GF180 5 V candidate
make sta-resize                # bounded STA-feedback drive-grade experiment
make sta-check                 # enforce selected 125 MHz setup/hold closure
python3 scripts/check_reports.py
```

For exact historical timing, use the saved profile netlist and Liberty files
directly rather than resynthesizing after source/tool changes. Experimental
same-family sizing is reproducible with `sta/resize.tcl` and
`scripts/replay_sizing.py`; JSON replay preserves the original constant drivers.

The isolated `LOW_MUX_ROWS` prefetch experiment also passed the full functional
suite (`make test-registered-lowmux`) but was rejected for implementation cost:
Yosys remained in global mux reduction for more than five minutes at roughly
1.7 GB RSS. Its preserved elaboration and interrupted mapping log are under
`build/gf180/registered_lowmux*`; it is not counted as an STA result.

A separate `REGISTERED_READ_ADDRESS` attempt targeted the remaining read-row
critical path while keeping the original bank topology. Both the initial and a
narrower request-gated version failed three upstream TX compatibility cases in
MII/clock-enable modes, so both were reverted; their logs remain under
`build/gf180/registered_*prefetch*` and
`build/gf180/registered_address_gated_simulation.log`. The verified baseline
was rerun afterward and passed (`build/test_after_revert.log`).

Read [WORK_LOG.md](WORK_LOG.md) for the hypotheses that failed, tool repairs,
counterexamples, assumptions and measured tradeoffs. Read
[INTERVIEW_GUIDE.md](INTERVIEW_GUIDE.md) for how to present the work accurately.

## Physical implementation status

Latest candidate: local SAT-proven RX/TX reduction-tree ECOs now pass
placement-based propagated-clock timing at 125 MHz: setup WNS +0.1734 ns,
hold WNS +0.1684 ns, setup TNS zero, and legal placement. The source RTL
behavior, FIFO sizes and timing constraints are unchanged. The active
checkpoint is `4_tx_and_reduction.odb` in `build/physical_pipeline_layout`.
Global routing subsequently passed at +0.1115 ns setup / +0.1522 ns hold,
zero setup TNS, zero overflow and zero antenna net/pin violations. Complete
detailed routing has completed and its strict acceptance gate passes with
zero route violations and zero antenna net/pin violations. Post-route antenna
repair needed five diode/reroute cycles. The final route has 28,028,279 um
wirelength and 1,939,713 vias; 689,911 filler cells were then placed.
Evidence: `build/eco_drt_validated.log` and
`build/physical_pipeline_layout/reports/gf180/ethernet_pipeline_4096/base/route_acceptance.json`.
Finishing and real WC/BC/TC extraction completed. Extracted setup/hold is
WC -1.334403/+0.486239 ns, BC +4.159819/+0.167639 ns, and TC
+2.618635/+0.323664 ns. WC bank-select distribution has excessive routed
delay/slew, so physical timing is **not closed**. Both supply grids pass
connectivity. The failed sequence is `build/eco_verify_final.log`; baseline
reports are preserved in `build/extracted_baseline/`. A physical control-net
buffer/sizing repair using measured parasitics is running in
`build/eco_control_repair.log`. GDS, final CDC and full-layout DRC/LVS remain
outstanding.
The historical results below describe earlier candidates and interrupted runs.

The historical mapped netlist remains closed only for pre-layout 125 MHz STA.
Its physical experiments are preserved in `build/physical_compat_rc/`; none
closed full physical timing. The first detailed-route run was interrupted
during optimization, so its 93,631 first-pass violations are not a final DRC
result. A mandatory SRAM rewrite was not established by that aborted run.

The user confirmed a SoC IP-block integration target. The preceding candidate
enables `DECOUPLE_READ` to decouple the wide bank/group read pipeline using
the existing output queue, retaining 4096-entry main frame storage in each
direction. Full packet/error and upstream eight-case GMII/MII regressions
passed in 485.90 s. Reduced 100-step FIFO safety, all three covers, and
full-size TX/RX pointer/decode induction passed. This remains scoped formal
verification, not complete-MAC unbounded proof.

That mapped netlist is `build/gf180_decoupled_read/mac_mapped.v`:
263,194 cells, zero structural problems, and complete GF180 LEF/GDS coverage.
The run `build/physical_decoupled/` completed legal placement and CTS;
post-CTS repair measured -0.9423 ns setup / +0.0624 ns hold. It avoids port
delay cells and uses an explicit SoC timing
contract (`physical/soc_interface.tcl`): neighboring logic is clock-balanced
to the MAC leaf reference, with 8 ns periods and 1.0/0.2 ns interface budgets.
That assumption requires top-level integration/CTS validation. No final GDS
or extracted timing closure is claimed until the corresponding stages pass.

The active candidate adds `READ_BANK_ONEHOT` and `PIPELINED_WRITE`, addressing
the measured bank-selection and memory-write paths. The write data and
decode are registered, and frame-commit visibility is delayed with the
physical write. Mapping produced 259,559 cells with complete LEF/GDS
coverage. Reduced 100-step safety, covers, full-size pointer/decode/alignment
induction, masked-mux equivalence, and arbitrary-clock 40-step safety passed.
Both packet regression suites passed in 731.32 s after the simulator
sensitivity correction.
Fresh placement/CTS uses `build/physical_pipeline_layout/`; routed timing
closure remains pending. See `WORK_LOG.md` for exact logs and limitations.

The pipeline candidate then completed global routing with zero Metal2-Metal5
overflow and measured -0.4160 ns setup / +0.1522 ns hold. Its first complete
detailed-route iteration 0 reported 83,609 violations; iteration 1 was
interrupted. The configured 64-iteration limit was never exhausted, so
convergence is unresolved. No accepted detailed-route database, extracted
STA or GDS exists. A via-enabled retry reproduced early partial counts and
was stopped; its effect on final convergence was not established.

The Metal1-enabled global-routing experiment is complete. Global routing
had zero overflow on all five layers and zero antenna violations, but timing
measured -0.3870 ns setup / +0.1545 ns hold. Detailed routing was
stopped at its first 10% checkpoint because it produced 8,017 violations,
above the prior 3,851-violation checkpoint. That partial count is not evidence
of final non-convergence. No final route, extracted
STA, LVS, or GDS exists. A real SRAM macro was not available: only a Liberty
test model was found, with no matching LEF/GDS/CDL/RC views. The project must
not claim SRAM-backed physical closure until that collateral is supplied.

The alternate 6LM/7t branch completed legal placement at -2.9072 ns setup /
+0.1476 ns hold. Earlier near-zero placement updates misconverted seconds
to ns. This branch also has mapping-driver and RC-model confounders; it does
not establish that changing metal count fixes or worsens closure in isolation.
Its generated databases were removed during the requested cleanup; logs and
reports remain. See the audit corrections in `WORK_LOG.md`.

Some inactive physical checkpoints and old synthesis RTLIL/JSON were
losslessly compressed to reclaim space. Every archive is verified by
decompression and SHA-256 comparison; logs, reports, constraints and the
active physical inputs remain intact. Historical files may need `gunzip`
to restore before replay. A further 2026-11-02 cleanup reclaimed 3.01 GiB
using 87 hash-verified archives of inactive netlists/library copies; see
`build/inactive_text_cleanup.log` and its timestamped manifest.
The earlier cleanup removed the superseded baseline, decoupled,
25%-utilization and 6LM/7t result trees, including their compressed databases.
The compression inventory is historical; those removed files must be rebuilt.
