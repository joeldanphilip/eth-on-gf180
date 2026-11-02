# Engineering work log — 2026-10-31

## Objective and architecture

Build an open-source study of formal verification and multi-clock timing for a
1G Ethernet MAC. The projects started as README-only directories. The canonical
implementation is in `ethernet_formal`; the sibling `ethernet_sta` forwards build
targets here so that verification and timing analyze the same source revision.

We integrated the existing MIT-licensed `eth_mac_1g_fifo` from Alex Forencich's
verilog-ethernet repository, rather than writing the MAC itself. It provides
AXI-Stream host ports, GMII, independent logic/TX/RX clocks, asynchronous frame
FIFOs, preamble, padding, TX CRC and RX CRC validation. Vendor RTL remains
unchanged. `SOURCES.md` records revisions and licensing. The repository is
deprecated upstream; the pinned Verilog version was selected for compatibility
with the Yosys flow.

## 2026-11-02 — physical ECO continuation and current boundary

The GitHub source snapshot was pushed to `git@github.com:joeldanphilip/eth-on-gf180.git`
on `main` at commit `bf2f984`. Generated build databases were retained locally
for reproducibility; obsolete ECO databases were removed after authorization,
freeing roughly 34 GB. The source-only repository excludes `build/`, `tools/`,
and virtual-environment artifacts.

The GF180 physical flow uses the vendored 5LM/1TM, 9-track, 9K standard-cell
views (`gf180mcu_5LM_1TM_9K_9t`) at the native 5 V range, with 8 ns clocks. A
workspace audit found no physical SRAM macro collateral. The Liberty-only
`gf180mcu_sram.lib.gz` test model is not sufficient for LEF/GDS/CDL/RC-backed
macro integration.

The accepted ECO lineage is preserved under
`build/physical_pipeline_layout/results/gf180/ethernet_pipeline_4096/base/`:

| Candidate | Physical result | Extracted WC setup |
| --- | --- | ---: |
| split2 | DRT 0, antenna 0, legal after finalization | -1.136206 ns |
| split3 | DRT 0, antenna 0; legalized ECO | -0.980902 ns |
| split4 | DRT 0, antenna 0; legalized ECO | -0.961612 ns |
| split5 | DRT 0, antenna 0; WC electrical clean | -0.862076 ns |
| split6 | DRT 0, antenna 0 | -0.862076 ns |
| split7 | DRT 0, antenna 0; strongest current candidate | -0.778950 ns |

Each split was a localized buffer insertion on a high-fanout bank-select or
banked-mux net, followed by detailed placement legalization, full detailed
routing, antenna checking, filler insertion, power connectivity audit, RC
extraction, and WC/BC/TC STA. Split7 passes WC electrical checks but BC/TC
max-slew remains failing; setup is still negative at WC. Therefore no GDS is
claimed, and the next engineering step is a structural FIFO/mux partition or a
real SRAM macro with complete physical collateral, not a blind GDS stream-out.

At GMII, eight data bits per 125 MHz cycle provide 1 Gb/s raw line rate. The
host AXI interface can stall; the receive PHY cannot. RX buffering and whole
frame drop/recovery behavior therefore matter as much as handshake behavior.

## Environment bring-up and actual problems encountered

1. Initial sandbox startup failed with `bwrap: loopback: Failed RTM_NEWADDR`.
   After access was restored, both project READMEs were inspected.
2. Found an existing OSS CAD Suite, but its Icarus compiler support files,
   bundled Python modules, and common Yosys technology maps were incomplete.
   Created local tool wrappers without modifying that installation.
3. Downloaded/extracted the Ubuntu Icarus package locally. Installed isolated
   Cocotb, cocotb-test, cocotbext-eth/axi and pytest packages in `.venv`.
   A configured secondary package index had DNS failures; public PyPI succeeded.
4. Built OpenSTA locally. Its missing Eigen, SWIG and CUDD dependencies were
   installed/built locally. CUDD required regenerating old automake metadata;
   OpenSTA's optional unit-test build was disabled because GTest was absent.
5. Yosys elaboration of the generic upstream CRC generator was expensive.
   Selected its existing reduction implementation using `SIMULATION` and
   cached elaborated RTLIL in `build/mac_elaborated.il` for timing iterations.
6. Initial replacement technology maps came from a newer Yosys source tree and
   requested a `$pmux` simple mapper absent in the installed binary. Replaced
   them with version-matched `v0.61` maps. Added a local ABC executable wrapper.
7. Post-mapping structural checking initially lacked Liberty cell pin direction
   definitions and reported 31 apparent undriven outputs. Loading the library
   with `read_liberty -lib` resolved these; subsequent checks reported zero
   problems.
8. An automatic review rejected stopping an unverified PID. The process identity,
   start time, command and working directory were checked before stopping only
   the superseded project jobs.

## Simulation experiments and results

The upstream packet regression passed. It checks transmit/receive payloads,
FCS, frame lengths from 60 through 1514 bytes, GMII/MII selection, and clock-enable
pauses. `build/simulation.log` preserves the first passing run. The combined
Makefile regression passed two pytest entry points in 68.74 seconds, recorded in
`build/test_final.log`; pytest entry-point counts are not packet counts.

The project regression in `tests/test_multiclock.py` adds:

- Logic/TX/RX clock periods of 6.400/8.000/8.008 ns, expressed in integer ps to
  avoid a floating-point simulator precision error encountered during bring-up.
- Twelve TX frames with independent FCS/payload comparison.
- RX frames of 60, 61, 512 and 1514 bytes; the host sink stalls for three of
  every four cycles.
- A corrupt FCS frame that must not reach the host.
- A 3000-byte RX frame exceeding the 2048-byte test FIFO capacity, followed by
  a valid frame to verify recovery.
- A corresponding oversized TX frame and valid subsequent transmission,
  including a valid FCS check.
- Simulation timeouts so stalled interfaces produce a failure.

The latest expanded project regression passed in 6.58 seconds; see
`build/multiclock.log`. Early failed logs and XML traces may remain in simulator
build directories; consult the named final logs, not an arbitrary XML file.

## Formal model, properties and evidence

Harness: `formal/fifo_harness.sv`; configuration: `formal/fifo.sby`.
The actual upstream FIFO is instantiated at depth four, with frame mode
disabled. This is a deliberate reduced model of the byte FIFO, not a proof of
the frame-commit protocol used by the full MAC.

The arbitrary-clock task permits independently advancing or stopped clocks.
Reset is asserted for eight global ticks. A producer assumption requires valid,
data and TLAST to remain stable while stalled. There is no fairness assumption.

Assertions check output stability during backpressure, no output beat before
an accepted input, and preservation of a symbolic selected input byte/TLAST at
the corresponding output sequence index. A completion cover demonstrates a
reachable transfer with TLAST. The counters cannot wrap within these bounds.

Results:

- Arbitrary-clock bounded model check: PASS through 30 steps using Z3; 330 s.
  Evidence: `build/verified_formal.log` and `build/verified_fifo_bmc/status`.
- Completion cover: PASS, reached at step 23. Evidence includes a VCD under
  `build/verified_fifo_cover/engine_0/`.
- Additional periodic-clock BMC: PASS through 60 steps using Yices, about 7 s;
  explicit source/sink periods of four/six global ticks.
  Evidence: `build/periodic_formal.log`.

Z3 and Yices were both tried on the arbitrary-clock task; the duplicate Yices
run was stopped after Z3 completed. The periodic task was much faster because
clock schedules were constrained. The deeper periodic result does not imply
60-step coverage of every arbitrary clock schedule.

These results establish finite-bound safety for this reduced configuration.
They do not prove eventual delivery, absence of all packet loss, unbounded
correctness, full MAC FSM behavior, reset during active traffic, analog
metastability, or the complete frame/drop/commit policy.

## STA assumptions, failures and closure iteration

Yosys synthesizes the full default MAC. Both 4096-byte frame FIFOs are expanded
into standard cells; about 82,434 flip-flops are mapped. This is intentionally
a register-based timing study, not a realistic SRAM area estimate.

OpenSTA uses the public Nangate45 typical Liberty library. Logic, TX and RX
clocks each have an 8 ns period and are declared mutually asynchronous. I/O
delays are assigned by domain: 1 ns maximum and 0.2 ns minimum; uncertainty and
modeled transitions are 0.1 ns; output loading is 10 fF. Reset input budgets are
explicitly zero and reset paths are excluded. See `sta/mac.sdc`.

The first electrically unconstrained mapping had enormous fanout-related
delays: worst setup slack -13143.61 ns and hold slack about -0.02 ns. These
numbers reflected overloaded unbuffered standard-cell nets and Liberty table
extrapolation, not a meaningful achievable MAC frequency. The baseline is saved
as `build/timing_unconstrained_mapping.log` and `build/mac_mapped_baseline.v`.

Added ABC drive/load constraints: BUF_X1 driver proxy, 5 fF output load, and a
7000 ps combinational delay target. The mapped circuit then achieved:

- Setup worst slack: +6.3073 ns; setup TNS: 0.
- Hold worst slack: -0.0161 ns; 12 failing endpoints.
- No missing input-delay warnings after assigning explicit reset budgets.

The hold stage collects all failing endpoints using OpenSTA's path API, inserts
four positive BUF_X1 cells at each failing DFF D pin, checks each inserted chain
resolves to the original signal, and reruns Yosys connectivity and STA.
An instance-name mismatch between generated Verilog and internal JSON was found
and fixed with stable public instance names (`rename -enumerate`).

Final ECO: 48 BUF_X1 cells inserted on 12 endpoints; identity-chain checks passed
and Yosys reported zero connectivity problems. Completed nominal results:

- Setup worst slack: **+6.3073 ns**; setup TNS: **0**.
- Hold worst slack: **+0.0009 ns**, only **0.9 ps** margin.
- Evidence: `build/hold_eco.log`, `build/hold_check.log`,
  `build/timing_hold.log`, and `build/hold_remaining.txt`.

The positive hold margin is extremely small. It is not evidence of robustness
against process/voltage/temperature variation, routing or clock skew.

## Limits and next research work

The clock-group exceptions do not prove CDC correctness. `sta/CDC.md` lists the
Gray-pointer, frame-commit, reset and toggle-synchronizer boundaries. Physical
flight-time/skew constraints, synchronizer preservation and metastability/MTBF
analysis remain separate work.

No floorplan, placement, clock tree, routing, SPEF extraction or slow/fast-corner
signoff has been performed. Even if nominal setup/hold passes after the ECO,
describe it as **pre-layout typical-corner closure under stated assumptions**.
The Tcl script accepts compatible `LIB_MAX`/`LIB_MIN` files, but supplying those
paths is not evidence that a multi-corner run has happened.

## Extension: GF180MCU and stronger formal checks

At the user's request, added the open GF180MCU 180 nm 9-track standard-cell
platform. `TECHNOLOGY.md` records exact Liberty/LEF names, voltage and temperature.
The assembled TT/SS/FF libraries come from the pinned ORFS checkout; SHA-256
hashes of those libraries and selected physical LEFs are in
`build/gf180/technology.sha256`. No physical tool has consumed the LEFs yet.

The full unmodified MAC was mapped at SS 3.0 V/125°C, checked with FF
3.6 V/−40°C for hold, and checked separately at TT 3.3 V/25°C. Results:

| Configuration | Setup WNS (ns) | Hold WNS (ns) |
| --- | ---: | ---: |
| Original FIFO, SS/FF | -9.8908 | +0.0908 |
| Original FIFO, TT | -1.1027 | +0.0960 |

Evidence: `build/gf180/timing_ss_ff.log`, `timing_tt.log`, `mapping.log`.
The original architecture therefore does not meet 125 MHz in this library.
The initial hypothesis implicated the wide register-bank FIFO read mux. Later
path inspection showed the dominant worst path was actually write-address /
write-control distribution. Retained the failing results rather than changing
the target clock; read banking alone was not sufficient to close timing.

Added `formal/frame_fifo.sby`: depth-four frame FIFO, one/two-beat frames,
zero bad-frame markers, four/six-tick periodic clocks. Assertions add the
requirement that output data must belong to an already committed frame.
Bitwuzla passed the 100-step BMC in 29 s; covers reached a completed frame at
step 51 and a later transfer at step 81. See `build/frame_bitwuzla.log`.
Yices was slow on the same task and was stopped after Bitwuzla passed.
This still excludes arbitrary oversized/bad frames and unbounded operation.

Created a separate MIT-header-preserving FIFO variant at
`rtl/axis_async_fifo_banked.v`. Vendor source remains untouched. With
`RAM_PIPELINE >= 2`, it registers reads from 16-word banks, then registers a
partial bank selection, then selects the final group into the existing output
stage. At depth 4096 this divides a twelve-address-bit mux into three four-bit
selections instead of one large combinational read. Pointer and valid control
remain the upstream implementation. At fixed RAM_PIPELINE the transfer latency
is unchanged; the GF180 candidate increases RAM_PIPELINE from one to two, adding
one read-clock cycle relative to the original default configuration.

The banked variant passed the expanded full-MAC unequal-clock/error/backpressure
simulation in 11.92 s. `formal/banked_equivalence.sby` compares it against an
upstream RAM_PIPELINE=2 FIFO at depth 32 and data width two. Cycle-by-cycle ready,
valid, data and TLAST comparisons passed 100 periodic-clock steps in about 7 s;
the transfer cover also passed. Evidence: `build/gf180/banked_simulation.log`
and `build/gf180/banked_formal.log`. This is reduced-model bounded equivalence,
not an unbounded proof of the 4096-entry production-width instance.

The GF180 banked synthesis/STA candidate uses a separate elaboration checkpoint
and writes all mapping and corner results under `build/gf180_banked/`. Check its
completed results before claiming it achieves the 8 ns timing target.

The first banked RTL expression read many banks from one shared Verilog memory.
Although its simulation and reduced equivalence passed, Yosys expanded it into
over one million mux cells per FIFO before pruning constant addresses, reaching
about 18 GB resident memory and beginning to swap. Stopped only the verified
project synthesis PID and replaced this expression with explicit 16-word memory
arrays per bank. This preserves the same transfer behavior while avoiding the
large multiport-memory intermediate representation. Bounded equivalence was
rerun and passed in about 8 s. The final 4096-entry packet regression is saved
in `build/gf180/banked_4096_simulation.log`; synthesis uses this final explicit-bank
source. This is an example of making an RTL representation synthesis-friendly
without changing the intended hardware pipeline.

The final explicit-bank source passed its 4096-entry regression in 22.07 s and
the full eight-case upstream MAC compatibility suite in 200.04 s. This includes
GMII/MII modes and clock-enable pauses. Its mapping has 87,880 flip-flops versus
82,434 in the original. The un-sized banked results were SS WNS -9.7969 ns,
FF hold WNS +0.0786 ns; TT setup WNS -1.2918 ns and hold +0.0758 ns.

Reverse-mapping the worst-path JSON instance names identified the launch signal
as `tx_fifo.fifo_inst.wr_ptr_reg[6]` and the endpoint as a stored data bit in
`banked_read_mux.storage[100].words[15]`. This confirms a write decode/control
path, not a read-data pipeline path. The earlier read-mux hypothesis was
incomplete; the logs preserve that unsuccessful experiment.

A sizing experiment excludes drive-one cells in ABC and drive-one/two flops in
dfflibmap, mapping flops to drive-four variants. Verified the ABC wildcard
exclusion removed 46 cells, rather than assuming it was honored. Results:

| Sized banked GF180, 3.3 V range | Setup WNS (ns) | Hold WNS (ns) |
| --- | ---: | ---: |
| SS 3.0 V/125C + FF 3.6 V/-40C | -7.3520 | +0.0583 |
| TT 3.3 V/25C | +0.2383 | +0.0487 |

Nominal 3.3 V timing now passes at 125 MHz, but the selected slow corner does
not. Evidence is under `build/gf180_sized/`. Also characterizing the officially
supported native 5 V range in a separate `build/gf180_5v/` directory. A higher
core supply is an operating-point change, not an improvement to the 3.3 V result;
its eventual PHY I/O implementation would need compatible I/O/level shifting.

## Native 5 V investigation and verified control/CRC optimizations

The published 5 V range uses TT 5.0 V/25C, SS 4.5 V/125C and FF 5.5 V/-40C.
Its sized/banked baseline measured setup WNS -1.6457 ns at SS, hold WNS
+0.0645 ns at FF; TT setup/hold were +2.6974/+0.0560 ns. This improves the
performance operating point but does not change the failing 3.3 V SS result.
Evidence: `build/gf180_5v/`.

Inspected the actual paths instead of inferring the problem from WNS alone.
The native-voltage RX worst path was from `gmii_rxd_d4[0]` through the byte CRC
update and FCS comparison to `error_bad_fcs_reg`. Created a separate RX
derivative, `rtl/axis_gmii_rx_lookahead.v`, that consumes delayed byte `d3`
one byte earlier. On SFD recognition it initializes to CRC(first payload byte).
The final FCS comparator then uses the already computed CRC state. No output
stream latency is added; clock-enable and MII gating are retained.

Added optional `ONEHOT_WRITE` to the FIFO derivative. Bank and row predecode
are registered alongside the binary write pointer, and actual writes use those
registered selections. An initial expression decoded a selected next pointer;
its SS result was -2.1809 ns overall, exposing the new predecode-register path.
Reworked this to decode each increment/rollback/reset candidate before selecting
the update. This preserves transitions and avoids placing the decoder after
the entire write-accept selector. The failed iteration is preserved as
`build/gf180/closure_select_then_decode_ss_ff.log`.

The combined candidate passed full-depth packet/error/backpressure simulation
(latest `closure_simulation.log`: 23.74 s) and the full upstream GMII/MII,
clock-enable suite before the final write-selector rewrite (229.37 s). The
final selector rewrite is separately rechecked against the same suite.

Formal results now include:

- `formal/onehot_equivalence.sby`: PASS through 100 steps against the original
  pipeline-two FIFO in the reduced model, after the final selector rewrite.
- `formal/rx_induction.sby`: **unbounded RX reference equivalence PASS by
  k-induction**, with both base case and inductive step passing. Exposed and
  asserted data/dv/error pipeline equality, FSM equality, and the relation that
  candidate CRC state equals reference CRC-next while in PAYLOAD. These are
  proved assertions, not assumed equivalence. The good-frame cover passed.
  Inputs include arbitrary bytes, DV/error, clock enable, MII select and RX
  configuration enable; reset is the modeled startup reset, and PTP is disabled.
  Evidence: `build/gf180/rx_induction.log`; elapsed 275 s including elaboration.
- The earlier plain 40-step RX BMC became slow after step 15 and was stopped
  after the stronger induction result passed. Its log is retained, and it is
  not counted as a completed 40-step run.
- `formal/onehot_invariant.sby`: unbounded decode consistency PASS at depth 32.
  A clock-edge-only assertion initially yielded UNKNOWN in induction because
  clocks could stop before any checked edge, allowing unrelated unreachable
  encoding state in the inductive hypothesis. Strengthening the invariant to
  hold in every state made both base case and induction pass. The first attempt
  is preserved in `onehot_invariant_clocked_attempt.log`; it was not a reachable
  counterexample in the initialized design.

The RX result proves equivalence of that receiver configuration, not the entire
MAC, FIFO payload/liveness, physical metastability or PTP functionality.
Full-size TX/RX decode-state invariant jobs and final corner characterization
are recorded separately under `build/onehot_full_*` and `build/gf180_closure/`.

Both full-size TX and RX decode-invariant induction jobs passed (4096 entries,
eight data bits and distinct DROP_WHEN_FULL policies), in about 29 s. Final
GMII/MII compatibility passed in 217.04 s after the selector rewrite. Final
native-voltage candidate: SS setup -2.1043 ns, FF hold +0.1524 ns; TT setup
+2.0399 ns and hold +0.1878 ns. These are not corner closure.

Added a bounded 90 s OpenSTA-feedback sizing search using `replace_cell`.
It rejects incompatible ports, different cell families, hold failures, and
non-improving setup/TNS. It tried 136 candidates and accepted five drive-grade
changes, reducing SS WNS to -1.9767 ns with +0.1524 ns hold; TT remained
+2.0399/+0.1878 ns. Runtime-budget searches may vary; the accepted transcript
and final netlist are saved for exact replay. `make sta-resize` runs the experiment.

Structural checking caught missing constant drivers in OpenSTA's raw Verilog
export: `rx_axis_tkeep` and `zero_`. Retained that file as
`mac_resized_opensta_raw.v`. Added `scripts/replay_sizing.py` to replay only the
accepted type swaps on the known-good Yosys JSON. It checks increasing drive
grades within the same family and identical port directions, preserving all
wiring/constants. The corrected Yosys-emitted netlist reports zero connectivity
problems. Repeated SS/FF and TT analysis; the results above are unchanged.
The validated artifact is `build/gf180_closure/mac_resized.v`.

Current conclusion: GF180 migration, simulation, bounded FIFO checks and the
stated unbounded component proofs are implemented. Nominal 125 MHz timing
passes for the sized 3.3 V study and 5 V candidates. Slow-corner setup remains
failing; further control-path/physical optimization is required before claiming
125 MHz corner closure. No routed or unbounded full-system claim is made.
`CURRENT_STATUS.md` is the concise source of truth.

## 2026-10-31 — Registered full-control candidate and rejected low-mux experiment

The registered-full FIFO variant was added as a separate GF180 candidate. The
write-side `full` and `full_wr` controls are registered from the current pointer
update, and the full computation uses the second synchronized read-pointer
stage. This deliberately adds conservative ready latency; it does not compare
the registered variant cycle-for-cycle against the unregistered upstream FIFO.
The variant passed its transactional FIFO BMC and cover checks, including
backpressure and later-frame reachability. The full-size TX/RX decode and
registered-full-flag invariant also passed base plus induction. Evidence is in
`build/gf180/registered_formal.log` and
`build/gf180/registered_invariant.log`.

The 4096-entry registered candidate passed the four project multiclock tests
and the complete eight-case upstream GMII/MII and clock-enable suite. The saved
logs are `build/gf180/registered_simulation.log` and
`build/gf180/registered_upstream_simulation.log`.

The native GF180 5 V registered candidate mapped with the same 5 ns ABC target
used by the previous closure candidate. SS/FF STA measured setup WNS -0.9877 ns
and hold WNS +0.1578 ns; TT measured setup +2.4988 ns and hold +0.1982 ns. The
remaining SS path is a registered FIFO read-row path from `rd_ptr_reg` into a
`bank_read_data` bit. A 180-second greedy same-family sizing search accepted 42
drive-grade changes. Replaying those changes through the known-good Yosys JSON
preserved constants and connectivity, reduced SS TNS from about -12230 ns to
-10037.82 ns, and retained hold +0.1578 ns, but WNS remained -0.9701 ns. The
corrected reports are under `build/gf180_registered/`.

I then tested `LOW_MUX_ROWS`, first as a smaller-bank experiment and then with
an explicit one-entry read prefetch register. The prefetch version passed the
same targeted and upstream simulation suite (`2 passed in 237.80 s`), proving
the functional latency change was compatible. However, Yosys remained in
global mux reduction for more than five minutes at roughly 1.7 GB RSS and did
not produce a mapped netlist. It was stopped and rejected on implementation
cost. The elaboration and interrupted mapping logs remain under
`build/gf180/registered_lowmux*`; no timing result from this experiment is
counted.

To attack the remaining `rd_ptr_reg` to `bank_read_data` path directly, I then
attempted a separate `REGISTERED_READ_ADDRESS` architecture using the original
256-word-per-bank topology. It registered the selected row/bank address and
added a one-entry prefetch/valid path. The project-level multiclock test passed,
but the complete upstream compatibility suite failed three TX cases involving
MII and clock-enable operation. Instrumentation showed that the added latency
was not safely aligned with the frame/valid protocol in all modes. The change
was reverted rather than promoted as a timing fix. A second, narrower attempt
gated bank-data refresh on the pending read request, but it failed the same
three cases. The failure evidence is preserved in
`build/gf180/registered_prefetch_simulation.log` and
`build/gf180/registered_address_gated_simulation.log`, plus the related
`build/gf180/registered_prefetch*` debug logs. The post-revert baseline
regression passed again (`build/test_after_revert.log`, 2 tests).

Current engineering conclusion: GF180 integration, simulation, bounded FIFO
proofs, unbounded RX component equivalence, full-size decode invariants and
registered-full transactional checks are complete. Nominal timing passes, but
the selected 125 MHz slow-corner setup target is not closed. No false path,
multicycle path or routed-signoff claim was added to make the report pass.

### Elastic read-side pipeline implementation

Added the opt-in `ELASTIC_READ` address stage with independent occupancy and
backpressure. The first version still advanced the storage-credit pointer on
address issue. Full MAC testing caught three TX failures despite project packet
tests passing (`build/gf180/elastic_simulation.log`). The revised version uses a
separate fetch pointer and releases memory only on bank-data capture. This is
essential when an address waits while the downstream pipeline stalls. Tests and
formal logs for this revision are `build/gf180/elastic_credit_simulation.log`
and `build/gf180/elastic_credit_formal.log`; GF180 mapping/timing runs through
`build/gf180/elastic_credit_flow.log` into `build/gf180_elastic/`.

The bounded harness uses 32 entries to activate banking, two symbolic data bits,
short frames, startup reset and unequal periodic clocks. Safety depth is 100;
cover depth is 320 so full-FIFO backpressure is reachable. This is a reduced
transactional proof, not full-MAC induction. The original eight-data-bit proof
attempt was stopped for solver cost; no pass is claimed for that attempt.
The deeper 160-step two-bit safety attempt reached step 105 without a reported
counterexample but had expensive solver queries; the reproducible default uses
100 steps with a separate 320-step cover run under `build/elastic_checked*`.

Corrected full-depth simulation passed both suites in 250.88 seconds, including
all eight upstream cases. Native 5 V GF180 timing at the unchanged 8 ns clocks
measured SS setup WNS -0.9159 ns, FF hold +0.1578 ns, SS TNS -11887.04 ns;
TT setup/hold is +2.8496/+0.1981 ns. Mapping and hold-export structural checks
reported zero problems, and zero hold buffers were inserted. Reverse mapping
the worst RX path identifies `drop_frame_reg` to `full_wr_reg`; logic and TX
also have paths into `elastic_fetch_ptr_reg`. Thus the rewrite changes the
limiting paths but does not achieve 125 MHz slow-corner closure.

Final elastic safety BMC passed at 100 steps, with all three covers reached
within the separate 320-step run (`build/gf180/elastic_checked_formal.log`).
The bounded sizing search accepted 35 same-family drive-grade changes in 166
trials. JSON replay and a fresh Yosys structural check preserved wiring and
constants with zero problems. Replayed SS setup/hold is -0.8296/+0.1578 ns,
TNS -5098.44 ns; TT is +2.8496/+0.1981 ns. Evidence is under
`build/gf180_elastic/{resize.log,resize_replay.log,resized_structural.log,
timing_resized_ss_ff.log,timing_resized_tt.log}`. The report collector includes
this candidate in `build/elastic_report_summary.json`.

### Frame/full and fetch control optimization

Added opt-in `FAST_CONTROL` on top of `ELASTIC_READ`. Frame-mode full detection
now computes the incremented-pointer comparison independently of the pointer
action selection, then explicitly selects hold, increment, rollback, or commit
flag values. This removes frame-drop control from the wide mux-then-comparison
path. The elastic fetch increment uses a registered low-four-bit carry, splitting
the counter carry chain while preserving one-word-per-cycle throughput.

The full-size formal model asserts that the carry equals reduction-AND of the
current low fetch bits, alongside the existing full-flag and write-decode
invariants. TX and RX both passed basecase plus induction. Reduced 32-entry,
two-bit transactional BMC passed 100 steps and all three covers were reached
within 320 steps. Evidence: `build/gf180/fast_formal.log`. Both full-depth MAC
suites passed in 259.38 seconds, including all eight upstream GMII/MII cases
(`build/gf180/fast_simulation.log`). The isolated 8 ns, native 5 V mapping and
STA profile is `build/gf180_fast/`, driven by `make -f sta/gf180.mk
gf180-fast-control`; orchestration log is `build/gf180/fast_flow.log`.

The initial control rewrite regressed mapped SS WNS to -1.1636 ns, hold stayed
+0.1578 ns, and TNS was -13020.86 ns. Its bounded sizing search accepted 28
changes but only reached -1.1350 ns in the timing tool, still behind the saved
elastic baseline; these swaps were not promoted. The worst logic path became
fetch-pointer feedback, and an RX write-pointer to `full_reg` path also limited
timing. The unsized saved netlist is the reproducible profile; the sizing log
is an experiment, not a structurally replayed accepted result.

A second optional `REGISTER_EMPTY` variant precomputes empty for both held and
incremented fetch pointers and registers the selected flag. It accounts for the
commit synchronizer update on the same edge and pointer reset, avoiding stale
availability. Full-size TX/RX induction proves exact empty-flag equality to the
current pointer comparison, alongside carry/full/decode invariants
(`build/gf180/empty_invariant.log`). Reduced 100-step BMC and 320-step cover
checks also pass (`build/gf180/empty_formal.log`). Its simulation and timing
profiles are `build/gf180/empty_simulation.log`, `build/gf180/empty_flow.log`,
and `build/gf180_empty/`.

The registered-empty variant passed both full-depth MAC suites in 251.89 s.
Its initial SS WNS was -0.7390 ns, hold +0.1578 ns, TNS -2936.01 ns. A
31-change same-family sizing search (134 trials) was replayed on the known-good
JSON and passed structural checking. Final replayed SS setup/hold is
-0.6166/+0.1578 ns, TNS -2821.03 ns; TT is +2.9733/+0.1982 ns. Saved reports
are `build/gf180_empty/timing_resized_ss_ff.log` and `timing_resized_tt.log`.
Remaining paths include TX write pointer to full flag and RX write decode.

A third `FULL_LOOKAHEAD` variant precomputes held/incremented/rollback full
comparisons before selecting the flag, addressing the remaining pointer-to-full
path. A formal-only reference register retains the original next-pointer full
calculation; full-size TX/RX induction proves the new flag matches it, alongside
empty/carry/full-frame/decode invariants. Reduced safety/covers also pass.
Both full-depth simulation suites passed in 256.62 s. Logs:
`build/gf180/lookahead_formal.log`, `lookahead_simulation.log`, and
`lookahead_flow.log`; timing profile: `build/gf180_lookahead/`.

The third variant measured exactly the same unsized SS/FF and TT timing as the
registered-empty variant. Comparing mapped cell type, parameters, directions
and connectivity (excluding source attributes) produced identical SHA-256
`ecadfa9fbf4c8ed3d263437672e7721a3affc3b90de134423d087f450c72b060`
for both 271061-cell designs. Synthesis collapsed the full-flag source rewrite
to the same circuit. It is a verified no-gain experiment, not an additional
timing improvement. The selected result remains the 31-change registered-empty
replay at -0.6166 ns setup / +0.1578 ns hold. The remaining worst path is TX FIFO
write-pointer control to `full_reg` in the logic domain. All clocks remain
8 ns and the slow-corner setup target is still open. Consolidated evidence:
`build/control_report_summary.json`.

### Registered next-write pointer and one-hot row read

Traced the residual 0.6166 ns miss to increment/Gray/full calculation and the
second miss to binary RAM-row selection. The optional `WRITE_AHEAD` state stores
`wr_ptr+1`, updates alongside every pointer commit/rollback/reset, and supplies
pointer advancement and control/decode calculations directly. Full-size TX/RX
induction proves the redundant pointer invariant plus the existing full/empty,
carry and decode invariants. Reduced 100-step BMC/covers pass; both full-depth
MAC suites passed in 249.34 s. Logs are `build/gf180/write_ahead_*`; profile is
`build/gf180_write_ahead/`.

The combined `READ_ONEHOT` variant registers a one-hot row selector in the
existing elastic address stage, then reads each bank using a masked OR rather
than the binary row mux. This preserves capacity, pipeline latency and FIFO
ownership. Full-size TX/RX induction proves row-selector alignment whenever a
request is valid, alongside all pointer/control invariants. Reduced BMC/covers
also pass (`build/gf180/read_onehot_formal.log`). Simulation and technology
results are recorded separately under `build/gf180/read_onehot_*` and
`build/gf180_read_onehot/`.

Inspection also found the earlier sizing search stopped after the first legal
drive grade per cell. Optional `RESIZE_EXHAUSTIVE` and
`RESIZE_BIDIRECTIONAL` now explore every compatible grade, retaining hold checks
on every accepted swap. The historical mode remains the default. An isolated
search from the registered-empty baseline accepted 24 substitutions in 305
trials and reached -0.5444 ns in the tool. It is replayed with
`scripts/replay_sizing.py --allow-downsize`; all wiring/constants and cell pin
directions are preserved. Fresh STA evidence is under
`build/gf180_empty_search/`.

### Achieved 125 MHz pre-layout closure, 4096 entries

The write-ahead RTL alone improved unsized SS setup to -0.2603 ns, hold
+0.1578 ns and TNS -592.51 ns. Exhaustive sizing reached -0.1684 ns. Eight
launch-flop replicas improved this only to -0.1585 ns; subsequent buffer
replication regressed to -0.6872 ns. Both ECOs were rejected. The replica
shared-D/CLK lemma passed induction and the quotient-graph/initial-state
certificates and structural checks are retained, but these transformations are
not part of the selected circuit. A 3 ns ABC-budget experiment mapped to the
same -0.2603 ns timing. No clock constraint was changed.

The combined one-hot read/write-ahead configuration passed both full-depth MAC
suites in 520.08 s, including all eight upstream GMII/MII/clock-enable cases.
Its reduced 100-step safety BMC and three covers within 320 steps passed.
Full-size TX/RX induction proved next-write-pointer, read-row one-hot alignment,
fetch carry, exact empty flag, full-flag reference and write-decode invariants.
This is still scoped formal verification, not full-MAC unbounded proof.

Its initial mapping missed SS setup by 0.6453 ns. Exhaustive bidirectional
same-family sizing accepted 21 substitutions and left only one failing endpoint
at -0.0137 ns. A second search included side-load cells, allowing smaller cells
to reduce critical-net input capacitance. It accepted 13 further substitutions
and reached a 0.05 ns search margin. Both stages were replayed on known-good
Yosys JSON, preserving all wiring/constants and validating pin directions.

Fresh STA on the final exported netlist measured:

| View | Setup WNS (ns) | Hold WNS (ns) | Setup TNS (ns) |
| --- | ---: | ---: | ---: |
| SS 4.5 V / 125 C setup, FF 5.5 V / -40 C hold | +0.0515 | +0.1578 | 0.00 |
| TT 5.0 V / 25 C | +3.1994 | +0.1982 | 0.00 |

Both `check_timing.py --require-closure` gates report `timing_met: true`, and
Yosys reports zero structural problems. The final netlist and reports are under
`build/gf180_read_onehot_finish/`: `mac_resized.{json,v}`, `resize.log`,
`resize_replay.log`, `resized_structural.log`, `timing_ss_ff.log`,
`timing_tt.log`, `closure_ss_ff.json` and `closure_tt.json`. First-stage evidence
is under `build/gf180_read_onehot/`. The selected result uses the original
4096-entry capacity, 8 ns clocks, and the existing CDC exception set; no added
false/multicycle exception was used. The final circuit contains no replication
ECO. The unused 2048-entry alternative was not promoted; its simulation was
interrupted once the full-capacity target closed.

`make sta` and `make sta-check` now rerun/enforce the selected saved-netlist
result. `make verify-1g` combines the selected tests, proofs and saved STA.
`make sta-close-1g` rebuilds mapping, both searches, JSON replay, structural
checks and final closure gates. Search wall-clock budgets can affect accepted
swaps, so reruns are gated rather than presumed successful. The historical
3.3 V study remains available as `make sta-gf180-3v3` and is not claimed closed.
Achieved scope is selected-corner pre-layout timing with ideal clocks and no
extracted interconnect. The 51.5 ps setup margin requires placement/CTS/routing
validation before physical signoff.

### Physical implementation attempt: GF180 ORFS/OpenROAD 26Q2

Follow-up correction: the aborted detailed-router iteration counts below are
intermediate counts, not final DRC results or evidence of non-convergence.
The earlier conclusion that an SRAM rewrite was mandatory was premature.
The subsequent CTS-path audit found approximately 6.5 ns clock insertion
latency dominating external I/O checks and delay cells on output ports.
An experimental ECO replacing 28 output `dlyb` cells with `buf_16` reduced WC
worst setup from -5.4736 ns to about -3.61 ns. Per-corner internal reports
identify WC setup misses of about -1.01 ns (logic), -1.54 ns (RX), and -2.53 ns
(TX), with the worst TX launch at `tx_fifo_axis_tready`. Original constraints
remain unchanged. The experiment is saved as `4_output_buffer_eco.odb`, with
reports `audit_output_buffer_eco.rpt.{WC,BC,TC}{,.internal}` in the physical
run directory. Separate hold repair is being evaluated because the earlier
setup repair loops never reached their hold phase. This ECO is experimental
and still requires legalization, equivalence and routed verification.

Independent bounded hold repair subsequently inserted 111 buffers and resized
11 cells. Before legalization it reduced hold WNS from -5.493 ns to -0.691 ns
and hold TNS from -105241.289 ns to -0.691 ns, leaving one violating endpoint.
Legalization passed with zero failures. Re-estimated timing measured setup
-9.8077 ns and hold -0.6868 ns, so this candidate is rejected for promotion:
the hold delay chains worsened setup. Complete evidence is in
`hold_repair_driver.log` and `physical_hold_repaired_timing.rpt`, with a saved
`4_hold_repaired.odb`. A bounded setup-repair trial and a separate CTS trial
using clkbuf_20 and 200 um sink-cluster diameter are evaluated independently;
neither is accepted without its final reports. No SDC budgets were changed.

The revised clock-tree trial completed legal placement and measured -3.1734 ns
setup/-5.0481 ns hold. The bounded setup pass from the hold-repaired candidate
resized 2,287 cells, cloned 38 and inserted 38 buffers. Its subsequent hold
cleanup reached +0.0732 ns after legalization, but setup regressed to -14.8921
ns, so it was rejected. The current balanced trial starts from the revised
clock tree and excludes `dly*` cells from resizer selection to test ordinary
buffer insertion instead. Its complete log is `balanced_repair_driver.log`.

That ordinary-buffer trial completed but failed: final setup -5.4672 ns and
hold -2.0794 ns after legal placement. The worst logic path includes newly
inserted clkbuf_1 hold buffers on shared full/valid logic. This identifies a
concrete repair defect: input hold padding must be isolated from shared
internal control paths, and custom repair scripts must apply the platform's
drive-1 exclusion. None of these trials is promoted to routing.

Follow-up trials completed: enforcing the drive-1 exclusion measured -3.2788
ns setup/-2.1213 ns hold. Restricting hold repair to top-level input nets
preserved setup at -2.5418 ns, with hold -2.8600 ns. Both passed legal placement
but remain experimental timing failures. The port-isolated trial saved
`4_port_setup.{odb,sdc}` and `4_port_hold_trial.{odb,sdc}`. Its first API attempt
failed because `get_nets -of_objects` does not support Port objects in this
build; the retry uses BTerm-to-net connections and completed successfully.
Eight hold buffers were inserted. The dominant setup path is now the output
status pulse after approximately 6.12 ns clock insertion, identifying interface
clock latency/pipelining as the next target. See `physical/EXPERIMENTS.md` for
the candidate comparison. Full physical closure is not achieved.

### SoC integration target and decoupled read pipeline

The user confirmed the deliverable is a MAC IP block inside a SoC. The old
1 ns external I/O budgets were examples inherited from the initial SDC, not
board requirements. `physical/soc_interface.tcl` now describes a separate,
explicit hierarchical interface contract: neighboring registers are balanced
to a representative clock leaf in each domain, with the existing 1.0/0.2 ns
I/O budgets and 8 ns clocks. SoC-level CTS must validate that reference and
residual skew. This does not relax internal setup/hold or add CDC exceptions.

A core-only optimizer experiment (temporary I/O exclusions, never exported as
signoff SDC) reached -1.4815 ns setup and +0.1983 ns hold after legalization.
The saved ODB was independently rechecked using the original complete SDC;
full-design timing still failed. The remaining core endpoint was identified
as `tx_fifo.fifo_inst.group_read_data[12]`, fed by the ready/control cone.

The new optional `DECOUPLE_READ` configuration enables the existing output
FIFO in the banked implementation. Main frame storage remains 4096 entries;
the output queue adds read staging and removes downstream ready from wide
bank/group pipeline enables. The default RTL configuration is unchanged.
Bounded FIFO safety passed 100 steps and all three cover goals passed within
320 steps (last cover at step 202). Full-size TX/RX pointer/decode invariants
passed unbounded induction. The full-depth packet/error test passed, while
the upstream GMII/MII suite and GF180 mapping are recorded separately as they
finish. Files: `build/decoupled_read_{formal,simulation,mapping_driver}.log`
and `build/decoupled_read_invariant_retry.log`. The initial direct induction
command lacked the project tool PATH; the retry through Make completed.

### Physical pipeline candidate: bank selection and registered writes

The decoupled-read candidate completed both MAC regression suites (485.90 s).
It mapped to 263,194 cells. With the explicit SoC interface contract, its
legal post-CTS placement measured -1.2273 ns setup / +0.0624 ns hold;
setup/hold repair improved setup to -0.9423 ns while preserving hold.
These are placement-parasitic estimates, not routed closure. The remaining
paths were traced to bank selection and write-side memory enables/data.

`READ_BANK_ONEHOT` registers bank/group selectors and uses masked OR muxes.
`PIPELINED_WRITE` registers write data, row selection and bank enables before
the storage write. Frame commit visibility is delayed by one source edge
with the write, preserving the data-before-commit ordering. Main storage is
still 4096 entries per direction; the clock target stays 125 MHz. Non-frame
FIFO operation retains the existing write implementation.

Reduced FIFO BMC passed 100 steps; all cover goals passed within 320 steps.
Full-size TX/RX pointer/decode/alignment induction and a combinational masked
mux equivalence proof passed. An additional 40-step safety check with
arbitrarily advancing/stopping clocks passed. These scoped proofs do not
constitute unbounded whole-MAC payload equivalence. Initial induction was
UNKNOWN because edge-only history assertions did not constrain stuttering
clock histories; continuous metadata-alignment invariants resolved it.
Original traces are retained under `build/physical_pipeline_invariant_*`.

Mapping produced 259,559 standard cells, with no Yosys structural errors;
every used master has LEF and GDS coverage. The isolated physical run uses
`physical/pipeline_design.mk` and `build/physical_pipeline_layout`. The
initial Icarus regression was stopped after excessive runtime. Per-group
combinational accumulators were made local to avoid shared-array sensitivity
feedback; a fresh regression is logged in
`build/physical_pipeline_simulation_v2.log`. Its result remains pending.
Proof evidence: `build/physical_pipeline_formal.log`,
`build/physical_pipeline_invariant_v2.log`, and
`build/physical_pipeline_arbitrary.log`.

The corrected full-MAC regressions completed successfully: both pytest suites
passed in 731.32 s, covering the four project packet/error cases and eight
upstream GMII/MII/clock-enable cases. A separate final-source remap produced
259,558 cells versus the original physical candidate's 259,559. The physical
run keeps its original immutable mapped netlist; the source-level local mux
accumulator change preserves the masked-OR equation but changes ABC ordering.
Do not substitute the remapped file into a running physical checkpoint.

The installed OpenROAD STA uses `report_checks -scenes`, so new per-corner
reports use that option. Older diagnostic scripts using `-corner` have been
corrected; their old per-corner files are not used as signoff evidence.

The active pipeline candidate completed legal placement and CTS. Propagated
clock timing was -0.7340 ns setup / +0.1684 ns hold; CTS repair improved it to
-0.3304 ns / +0.1684 ns. The repaired checkpoint was routed with the GF180
tie-cell hook fixed for sanitized checkpoint-replay environments. Global
routing completed with zero overflow on Metal2 through Metal5, 245,570 routed
nets, approximately 36.26 million um aggregate wirelength, and zero final antenna net or pin violations.
Global-route timing was -0.4160 ns setup / +0.1522 ns hold. The three 8 ns
clocks and SoC interface reference-pin contract were preserved.

Detailed routing completed only optimization iteration 0, with a configured
limit of 64 iterations; it did not complete that iteration budget:
the violation count rose from 3,851 at 10% to 36,350 at 100%, and the router
reported 83,609 violations at the initial-pass check. Optimization iteration 1
was interrupted. This was an intermediate result, not a terminal failure.
No `5_2_route.odb`, final DEF or
GDS was accepted. Evidence is in
`build/physical_pipeline_layout/logs/gf180/ethernet_pipeline_4096/base/5_2_route.log`,
`build/physical_pipeline_layout/drt_driver.log`, and
`build/physical_pipeline_layout/results/gf180/ethernet_pipeline_4096/base/5_1_grt.odb`.
The candidate has a zero-overflow global route and incomplete detailed
routing. These logs do not establish whether detailed routing can converge.

A targeted retry enabled GF180 detailed-router via generation, because the
first pass was dominated by Metal2/Via2 rechecks, shorts and cut-spacing
violations. The retry produced the identical 10/20/30% checkpoints
(3,851/6,198/10,141 violations), so it was stopped early. The setting is
recorded in `physical/pipeline_design.mk`; its effect on final convergence
remains untested because the retry was also interrupted early.

### Metal1 routing experiment and SRAM collateral audit

The next targeted experiment enabled signal routing on Metal1 through
`physical/pipeline_m1_design.mk`, while preserving the same 35% floorplan,
three-clock CTS and GF180 5LM technology views. The saved Metal2-only global
route checkpoint was retained as `5_1_grt_m2.odb` before running the
Metal1-enabled flow.

Metal1-enabled global routing completed with zero overflow on every layer:
Metal1 15.24%, Metal2 28.49%, Metal3 16.94%, Metal4 1.02%, and Metal5 1.18%
usage, with 245,570 routed nets. Antenna repair ended at zero net and pin
violations. The resulting global-route timing was -0.3870 ns setup and
+0.1545 ns hold, which still misses setup. The complete
driver log is `build/physical_pipeline_layout/m1_grt_driver.log`.

Detailed routing from the Metal1-enabled guides was relaunched in a detached
process so the long OpenROAD run would not be killed by the inspection shell.
At its first checkpoint it reported 8,017 violations at 10% completion after
3:09 of detail routing, versus 3,851 violations at 10% for the prior
Metal2-only guide set. The run was intentionally interrupted based on those
partial counts; that early comparison does not establish final convergence.
No `5_2_route.odb`, final DEF or GDS
was accepted. The preserved evidence is
`build/physical_pipeline_layout/m1_drt_driver_v2.log` and the corresponding
ORFS run log.

The workspace was also audited for a real GF180 SRAM macro. No matching
physical SRAM LEF/GDS/CDL/RC collateral is present under the project
workspace or Documents tree. `tools/OpenSTA/test/gf180mcu_sram.lib.gz` is
only a Liberty test model and cannot legally be used to stream out a physical
macro. SRAM integration remains an option that needs matching physical and
timing views; the interrupted routing runs do not establish it as mandatory.

### Audit corrections after the routing experiments

The first-pass DRC counts above were previously misreported as exhausted
64-iteration runs. The logs explicitly show `Start 0th optimization iteration`
and interruption just after `Start 1st optimization iteration`. Final routing
convergence is unresolved. Initial percentage counts cover different subsets
of the design and must not be interpreted as a convergence curve.

The GF180 6LM/7t branch mapped and legalized, but its final placement setup
slack was -2.9072 ns, hold +0.1476 ns. Its global-placement diagnostic value
`-4.1912807e-09` is seconds, or -4.1912807 ns, not -0.004 ns. The earlier
near-zero-slack progress messages were incorrect. This branch also inherited
a 9t ABC driver constraint and used incorrect Metal5 RC for the 6LM stack;
its results are not a controlled comparison isolating metal count.

The remaining critical path in the Metal1 9t route is WC logic-clock
`_424531_` to `_380055_`, corresponding to RX FIFO `m_rst_sync3_reg` to
`elastic_empty_reg`, at -0.3870 ns. Both flops share the same CTS leaf;
the path includes the reset-dependent empty/comparison logic, so changing
I/O clock references cannot fix this internal path. Timing closure and
detailed-route convergence are separate outstanding checks.

The user's second cleanup removed generated result databases from the
25%-utilization, 6LM/7t, original baseline and decoupled branches, keeping
their logs/reports. Those databases require regeneration; their entries in
the earlier compression inventory do not imply the files still exist.
Build usage fell from about 35 GiB to 17 GiB, with about 45 GiB disk free.

### Storage cleanup requested by the user

### Local physical ECO after the audit (2026-11-01)

The original 9t/5LM physical checkpoint is retained as
`5_1_grt_before_empty_eco.{odb,sdc}` in the active results directory.
No RTL behavior, FIFO depth, clock period, CDC exception, or I/O budget was
changed. Initial Shannon-decomposition experiments were SAT-equivalent but
regressed timing (-0.3993, -1.2432 and -1.2260 ns) and were rejected.
Their small generated proofs and logs remain under `build/empty_eco_*`.

The accepted approach balances the actual mapped reduction trees. The RX
empty output replaces four serial gates with five NAND/NOR gates; the RX
carry tree replaces four gates with four. TX has a corresponding five-gate
negative reduction and a five-gate combined carry/output reduction. Each
replacement is SAT-proven against the extracted physical gate function with
all cut-point inputs unconstrained. Only exclusively unused old gates are
removed. Buffer drive changes and normal setup/hold repair follow the logic
patches. The final physical stage legalized all 248,845 cells with no
placement failures.

Measured placement-RC progression, using the same propagated clocks and
WC/BC/TC cell views, was:

| Stage | Setup WNS (ns) | Hold WNS (ns) |
| --- | ---: | ---: |
| Re-estimated original checkpoint | -0.3304 | +0.1684 |
| RX output-tree balance | -0.2543 | +0.1684 |
| RX carry-tree balance | -0.2238 | +0.1684 |
| RX buffer/setup repair | -0.0104 | +0.1684 |
| Final cumulative RX/TX ECO | +0.1734 | +0.1684 |

The final stage has zero setup TNS. This is placement-based physical timing
closure, not extracted route closure. The global maximum reported by
`report_worst_slack` must be checked across all path groups: the first path
in a grouped `report_checks` file is not necessarily the global worst path.

Proofs: `build/empty_eco/proof_generic.log`,
`build/empty_eco/proof_mapped.log`, `build/carry_eco/proof.log`,
`build/tx_reduction/proof.log`, and `build/tx_and_reduction/proof.log`.
Physical evidence: `build/empty_eco_*log`, `build/carry_eco_apply.log`,
`build/tx_reduction_apply.log`, `build/tx_and_reduction_apply.log`, and
`physical_tx_and_reduction_timing.rpt` under the active reports directory.

Reproduction uses `empty-eco-export`, `scripts/build_empty_eco.py --balance`,
`empty-eco-apply`, `scripts/build_carry_balance_eco.py`, `carry-eco-apply`,
`empty-eco-repair`, `empty-eco-finalize`, `tx-reduction-export`,
`scripts/build_carry_balance_eco.py --tx`, `tx-reduction-apply`,
`scripts/build_carry_balance_eco.py --tx-and`, and `tx-and-reduction-apply`.
Make targets are in `physical/Makefile` with the active WORK_HOME. The final
`4_tx_and_reduction.odb` is hard-linked as the route input `4_cts.odb`;
the original `4_2_timing_repaired.odb` remains intact. Global routing uses
`pipeline_eco_design.mk`, eight threads, the original Metal2-Metal5 signal
policy, and positive setup/hold repair margins. Detailed routing is configured
to finish its repair iterations, with sparse DRC snapshots to limit disk use.

The ECO then completed global routing in 664 seconds. Final route-estimated
setup WNS is +0.1115 ns, hold WNS +0.1522 ns, and setup TNS zero.
All layers have zero overflow. Antenna repair inserted 305 jumpers for 198
nets and finished with zero net/pin antenna violations. There are 245,617
routed nets and 36,261,019 um aggregate wirelength. This is a passing
global-route timing result; detailed routing and extracted STA are still
separate required checks. Evidence: `build/eco_grt.log` and the active
`physical_global_route_timing.rpt`.

Superseded floorplan/placement and intermediate ECO ODB files were removed
after validating the retained checkpoints. The original repaired CTS,
original pre-ECO global route, final RX stage used by the TX proof exporter,
and final cumulative candidate remain. Regenerate deleted intermediate
databases by replaying the documented targets. The active physical tree was
reduced to approximately 3.2 GiB before the new global-route database, leaving
about 51 GiB free. No source, constraint, proof, timing report or driver log
was removed in that cleanup.

Verification tooling was added as small workspace-local installations:
native KLayout 0.28.16 plus public Ubuntu runtime libraries, and sparse
checkouts of the FOSSi GF180 physical-verification decks (commit
`a561909c667ce1e8485313f5d280a7014f524e49`) and matching 9t CDL views
(`02b7af3f8d88c0b014d9af3db6a17f02aa983305`). The GF180 DRC deck's help
invocation executed successfully with Ruby 3.2.3. This smoke test is not a
design DRC/LVS result. The selected 5LM/9K/MIM-B stack corresponds to variant
C; all applicable rule checks must be reviewed before any signoff claim.

### Routing-guide serialization fix and resumed run (2026-11-02)

The first detailed-route handoff rejected stale Metal1 guides in a checkpoint
whose selected signal policy was Metal2-Metal5. The first audit counted
887,053 Metal1 guides on active nets, but incorrectly classified every Metal1
guide as invalid. This count is not the number of invalid guides: single-cell
Metal1 pin-access guides are legal. The original DRT-0155 error remains evidence
of a bad guide in the earlier database. The corrected
`eco_pre_grt.tcl` deletes cached dbGuide objects and completely unconnected
orphan nets before a fresh global route; it does not remove cells or active
connections. It cleared 2,422,522 cached guides and 10 orphan nets. Guide-audit
logging is capped at 10 examples, preserving the aggregate count without a
large repetitive log (`build/eco_clean_guides_summary.log`).

The first clean reroute was interrupted during timing repair. On resume,
`build/eco_grt_resume.log` records the restarted clean route. The command
sequence stopped at the overly strict audit (`build/eco_guides_resume.log`).
The completed clean reroute reproduced setup +0.1115 ns / hold +0.1522 ns.

Inspection of the exact OpenROAD source at `08f67ee5ec` showed that
`GuideProcessor::isValidGuideLayerNum` permits below-minimum-layer pin access
within one GCell; `frBlock::getGCellIdx` clamps the oversized final grid cell.
The guide file has 886,984 Metal1 rectangles of 16,800 x 16,800 DBU and 69
right-edge rectangles of 18,660 x 16,800 DBU. The saved grid has 798 entries
per axis, spacing 16,800 DBU. The corrected audit implements the same shrunken
corner comparison and clamping, preserves every active guide, and rejects
genuine multi-cell Metal1 routing. The validated sequence logs to
`build/eco_guides_validated.log` then `build/eco_drt_validated.log`.
Earlier positive timing estimates are not a claim that this corrected
detailed-route/extraction/GDS sequence has completed.

Final targets now include `eco-extract` per WC/BC/TC RC corner,
`eco-check-extracted`, `eco-finish`, `eco-gds`, `eco-cdl`, `eco-drc`, and
`eco-lvs`. The extracted check fails on negative setup/hold or electrical
slack and verifies 8 ns clock periods and power-grid connectivity. GF180
native DRC uses all variant-C decks; the report checker counts actual XML
violations. LVS requires the deck's explicit netlist-match message, because
the upstream deck can return process exit code zero even on a mismatch.
Neither checker treats successful tool launch as a completed design check.

The original CDL views expose VNW/VPW while the LEF exposes VDD/VSS only.
A one-cell export confirmed OpenROAD otherwise emits unconnected body ports.
`prepare_gf180_lvs.py` preserves original device models and explicitly binds
VNW to that instance's VDD and VPW to VSS. GDS LVS must validate this normal
body-rail connection through the physical tapcells; it is not assumed to be
proven by the export smoke test.

### Extracted CDC audit staged (2026-11-02)

Added a separate physical CDC audit rather than treating asynchronous clock
groups as proof of the crossings. The mapped-netlist inventory resolves 85
explicit source-flop/capture-D paths: 26 read Gray bits, 26 frame-commit bits,
26 commit-to-elastic-empty lookahead paths, four update/acknowledge toggles,
and three RX status toggles. The generator verifies source/destination clock
domains differ and fails on missing registers. An initial inventory mistake
treated status `sync1` as a receiving stage; RTL inspection showed it is the
source-domain toggle, so the actual crossing is `sync1` to `sync2`.

`eco-check-cdc` runs only after routed WC/BC/TC extraction. Its independent
process removes asynchronous clock groups for this audit and applies
conservative one-period maximum delays with ignored clock latencies. The
functional setup/hold checker and implementation constraints remain unchanged.
Missing paths or negative slack fail the audit. No CDC pass or metastability
MTBF claim is made before actual extracted results.

The read-only global-route sanity run then found all 85 paths, with worst
WC estimate slack +2.363789 ns (`rx_commit_empty_1`). The example expanded
report confirms the 8 ns max-delay check includes clock-to-Q and endpoint
setup, with clock latencies excluded. It also confirms VDD/VSS each have a
physical block port. Evidence: `build/cdc_estimate_sanity_v2.log`. The first
attempt failed because the installed STA advertises `unset_clock_groups -all`
but omits its C++ backing command; named removal of saved `group1` works.
These are endpoint/API checks with estimated parasitics, not extracted CDC
closure. The final target will still load WC/BC/TC SPEFs.

### Native DRC runtime upgrade (2026-11-02)

Running all public variant-C rule decks on the tiny original `nand2_4` GDS
exposed an actual KLayout 0.28.16 deep-mode failure (`DeepShapeStore container
no longer exists`) that the earlier version/help smoke test could not catch.
Downloaded the official Ubuntu 24 KLayout 0.30.12 package from
https://www.klayout.org/downloads/Ubuntu-24/klayout_0.30.12-1_amd64.deb and
verified publisher MD5 `0181713e60891e461d6d1664c1b8e213`. It is extracted
locally under `tools/klayout_030_runtime`; system packages were not modified.

The repeated full-deck single-cell trial completed in 3.96 seconds and reported
seven actual violations: DF.13_MV, DF.14_MV, M2.4, M3.4, M4.4, M5.4 and MT.3.
The strict XML checker rejected it with the same count. This is successful
runtime and failure-gate validation, not a passing DRC result for the cell or
the MAC. Logs/reports: `build/native_verify/nand2_030_full_drc.*`.
Removed the superseded 172 MB native library tree and 38 MB old package;
retained the shared local dependency libraries needed by the replacement.

The native transistor-LVS trial on that isolated, untapped cell also completed
(3.33 seconds). It reported a mismatch while returning process exit zero;
the explicit-message checker correctly rejected it. Its extracted netlist
uses the expected `nfet_05v0`/`pfet_05v0` classes and original transistor
dimensions. The extracted cell has a `SUB` port and a floating nwell body,
whereas the original CDL has separate VNW/VPW ports. This trial does not
validate the full block's body connections; actual physical tapcells and
the bound top-level schematic still require full-design LVS.
Evidence: `build/native_verify/nand2_full_lvs.{log,lvsdb}` and
`nand2_extracted.cir`.

A second tiny fixture abuts an original `filltie` cell to `nand2_4` and uses
the same explicit VNW=VDD/VPW=VSS top-level schematic contract as the MAC.
Aggregating all 229 masters exposed legacy antenna-diode CDL with positional
area/perimeter fields, which KLayout rejects as extra nodes. The exporter
now retains the original masters for OpenROAD and source hashing, and creates
an LVS-only syntax-normalized copy: `A=0.2034p P=1.85u M=1`. Terminal order,
model names and dimensions are unchanged. The exact KLayout 0.30.12 SPICE
reader source confirms parameters A/P use SI scaling; an independent parser
check imported both diode devices at 0.2034 um^2 / 1.85 um
(`build/gf180_lvs/diode_import_check.json`).

The fixture also needed explicit top-level GDS port labels, rather than only
labels inside its child cells. With those present, real transistor LVS
passed in 2.41 seconds and the strict checker accepted the explicit match
message (`build/native_verify/native_lvs_tapped_v3*`). This validates the
small physical tap/body connection and import format, not full-MAC LVS.

The clean MAC detailed route finished initial iteration 0 with 83,145
violations, 28,119,643 um wirelength and 1,945,343 vias. This is an initial
route, not a final DRC result. Iteration 1 is running; it is deliberately
not being interrupted based on an early partial count.

The continued repair completed at 83,145 -> 6,357 -> 2,975 -> 12 -> 0
router violations. The first routing call took 1,456 seconds. Post-route
antenna checking found 20 violations and inserted 23 diodes. The required
reroute then converged 657 -> 95 -> 63 -> 0 in about 5 minutes. Final
antenna checking/checkpoint save are still pending at this entry; zero router
violations alone does not establish extracted timing or full-layout DRC.

Added `eco-check-route` to reject stale/incomplete logs and nonzero final
route/antenna counts. `eco-bind-power` explicitly binds and audits every
standard-cell PG pin after antenna and filler insertion. `eco-verify-final`
sequences those gates, three fresh RC extractions, functional/electrical STA,
the independent CDC audit, final stream-out, and public DRC/transistor LVS.

The automatic antenna loop ultimately converged to zero net and pin
violations after five diode/reroute cycles (23 + 2 + 1 + 1 + 1 new diodes).
The final detailed route is 28,028,279 um long with 1,939,713 vias. OpenROAD
saved `5_2_route.odb`, placed 689,911 fillers, and produced `5_route.odb`.
The strict route gate passed (`route_acceptance.json`: all three counts zero).
The serial final flow is now in `build/eco_verify_final.log`. Its acceptance
extraction explicitly uses the finished `6_final.odb` that supplies GDS,
rather than an earlier pre-finish checkpoint. Extracted timing and full
GDS DRC/LVS remain pending until that sequence actually passes.

### Additional storage cleanup (2026-11-02)

Extended the lossless cleanup to inactive top-level generated netlists and
duplicate Liberty copies. One worker compressed and SHA-256 verified 87
archives before removing their original files, reclaiming 3.01 GiB. Active
physical inputs, the accepted pre-layout baseline, current LVS masters/proof
metadata, reports and simulation/formal evidence were excluded. Earlier
cleanup manifests were preserved by writing a timestamped new inventory:
`build/inactive_artifact_compression_20261101_200509.json` (UTC timestamp).
Console evidence: `build/inactive_text_cleanup.log`. Restore an archived
historical input with `gunzip path/to/file.gz`; current flow inputs remain
directly available. Filesystem free space increased to approximately 53 GB.

### Historical compressed-artifact inventory (earlier run)

The build tree reached approximately 40 GiB, mainly superseded physical
checkpoints. Automatic approval review rejected broad deletion because it
could discard useful evidence. The safer cleanup losslessly compresses
inactive physical checkpoint/DEF/generated-Verilog files and old synthesis
RTLIL/JSON, verifies each SHA-256 after decompression, then retains the gzip
as a byte-for-byte recoverable replacement. Active physical inputs,
selected sizing profiles, installed tools, RTL, reports, logs and SDC files
remain available. The exact inventory and hashes are in
`build/inactive_artifact_compression.json`; restore a historical generated
file with `gunzip path/to/file.gz` before directly opening it in its tool.
The active physical run is excluded from compression.

### Earlier physical baseline (retained failed experiment)

The physical run used the public GF180 MCU 180 nm nine-track, 5LM/1TM/9K
technology views and OpenROAD 26Q2-1164-g08f67ee5ec. A separate compatible
ORFS worktree at commit `2669d02a45b59bad9d826f383fa526c60beaacd6` was used
because the newer flow called commands unavailable in the installed release.
Evidence is under `build/physical_compat_rc/`.

Preflight passed for 275,111 standard-cell instances. The 35% floorplan made a
6.797 mm square die/core, inserted 2,694 endcaps and 45,866 tapcells, and
generated the GF180 PDN. The custom RC model was corrected after the first run:
Metal2-4 use 0.3214 ohm/um, Metal5 0.0909 ohm/um, and WC/BC/TC via resistance
is 16.845/4.23/4.5 ohm. The first zero-via-resistance attempt was discarded.

Placement legalized all cells with zero placement failures and zero overlaps.
Routability placement reported weighted congestion 0.8319 against a 1.01
target, but timing degraded to -4.9455 ns setup. CTS built trees for logic_clk
(2,404 buffers), tx_clk (230) and rx_clk (1,856); post-CTS timing was -5.4736
ns setup and -5.4928 ns hold. CTS repair was stopped after 960 iterations
because 44,775 violating endpoints remained and the dominant path stayed at
-3.045 ns.

Global routing completed with zero congestion overflow on Metal2-Metal5,
274,441 routed nets, and 38,960,754 um wirelength. Antenna repair inserted 7
diodes and 320 jumpers and ended with zero net/pin antenna violations. Global
route timing remained -5.5848 ns setup and -5.4404 ns hold. GF180/OpenDB had
misclassified constant-driver nets `one_` and `zero_` as POWER/GROUND; a scoped
pre-global-route hook reclassified only those two nets as SIGNAL, leaving VDD
and VSS as true PDN nets.

Detailed routing was started from `5_1_grt.odb`. Its first pass reported
93,631 violations, dominated by Metal2 shorts/rechecks and Via2/Metal2 issues;
the optimization was stopped at 20% after only reducing this to 79,767. No
`5_2_route.odb`, final DEF, or GDS was accepted. The project therefore does
not claim physical timing closure, routed DRC closure, LVS, extracted STA,
power/IR signoff, or GDS signoff. The actionable fix is physical architecture
and floorplan work—SRAM/macro-backed FIFOs or partitioning plus clock/fanout
reduction—not lowering the clock or hiding the failure with constraints.
