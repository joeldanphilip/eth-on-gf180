# Explaining this project in an interview

## Latest physical work (2026-11-02)

The newer `PIPELINED_WRITE` candidate keeps 4096 entries per direction and
8 ns logic/TX/RX clocks. Full packet/error tests and all upstream GMII/MII
cases passed (`build/physical_pipeline_simulation_v2.log`). Formal evidence
includes reduced 100-step safety, 320-step covers, arbitrary-clock 40-step
BMC, and full-depth pointer/decode/write alignment induction. State those
scopes separately; this is not a complete unbounded MAC proof.

After CTS, the remaining critical paths were FIFO empty/carry reductions.
Four local gate-tree replacements were proved by SAT for every combination
of their cut inputs, using the actual GF180 Liberty functions. Balancing
the reductions and sizing two overloaded buffers improved placement setup
to +0.1734 ns with +0.1684 ns hold. The clean global-route result is
+0.1115 ns setup / +0.1522 ns hold, zero setup TNS, zero routing overflow
and zero antenna net/pin violations. Detailed routing and extracted STA
are still in progress; these estimated margins are not routed signoff.

One useful debugging example: an inherited route-guide handoff failed.
After clearing and rebuilding cached guides, our audit still rejected all
Metal1 guides. Reading the matching OpenROAD source showed that single-cell
Metal1 pin access is legal below the Metal2 routing minimum, with special
clamping for the final grid cell. Correcting the audit accepted 887,053
legal access guides and found zero invalid guides. We preserved the layers,
connectivity and 125 MHz target throughout. Proofs and run details are in
`WORK_LOG.md`, `build/{empty_eco,carry_eco,tx_reduction,tx_and_reduction}/`
and `build/eco_{grt_resume,guides_validated,drt_validated}.log`.

## Earlier pre-layout result

“I integrated an open-source 1G Ethernet MAC and built a verification and timing
flow around it using Cocotb/Icarus, Yosys, SymbiYosys and OpenSTA. I tested the
packet datapath across unequal clocks and backpressure, wrote bounded formal
properties for a reduced asynchronous FIFO, and iterated technology mapping
and timing constraints against public Nangate45 and GF180MCU libraries. I then
proved RX lookahead equivalence and write-decode consistency by induction.”

“I closed the 4096-entry MAC's pre-layout 125 MHz setup/hold views in GF180's
native 5 V range. The key changes were an elastic read pipeline, separate fetch
and storage-credit pointers, registered next-write-pointer state, and one-hot
read selection. Exhaustive drive-grade and side-load optimization finished at
+0.0515 ns SS setup and +0.1578 ns FF hold, with zero TNS. I verified the exact
replayed netlist structurally. Placement, CTS and routed signoff remain future
work; I do not claim a full-MAC unbounded proof.”

Show `build/gf180_read_onehot_finish/closure_ss_ff.json`, `closure_tt.json`,
the final timing reports, and `build/gf180/read_onehot_formal.log` and
`read_onehot_simulation.log`. The full MAC suite passed in 520.08 seconds.

The earlier Nangate45 nominal result is +6.3073 ns setup and +0.0009 ns hold.
The constrained mapping initially had -0.0161 ns hold slack; 48 buffers at 12
endpoints made nominal hold positive. Be explicit that 0.9 ps is a tiny margin
and this result has not been validated across routing, clock skew or corners.

## Your contribution versus reused work

The Ethernet MAC/CRC/FIFO RTL was reused under its MIT license. The contribution
in this project is integration, extra tests, formal harness/properties, CDC
assumption documentation, constraints, tool bring-up, mapping experiments,
hold ECO automation and result analysis. Do not claim to have designed the MAC
RTL from scratch.
The later GF180 extension also adds a separate banked FIFO read-pipeline
implementation. Explain this as a targeted modification derived from the
upstream FIFO, tested in full-MAC simulation and against a reduced reference
model. It does not make the rest of the MAC original work.

## The 180 nm extension

The new platform is GF180MCU, 9-track standard cells, operated at nominal 3.3 V.
SS 3.0 V/125°C is the setup view and FF 3.6 V/−40°C is the hold view, with a
separate TT comparison. The original register-based FIFO misses the 8 ns target:
setup WNS is -9.8908 ns at SS and -1.1027 ns at TT. These results motivated
pipelining the read selection across banks. Consult the completed
`build/gf180_banked/timing_ss_ff.log` before quoting optimized timing numbers.
Read banking alone did not fix the dominant path. Reverse mapping the worst
endpoint showed a write-address/control path into the stored FIFO data. A
stronger-cell mapping then achieved +0.2383 ns setup and +0.0487 ns hold at TT
3.3 V, but still -7.3520 ns setup at SS 3.0 V. Be ready to explain this failed
corner and the power/area tradeoff of stronger cells; do not claim full GF180
corner closure from the nominal pass.

The formal extension checks commit visibility for short frames through 100
steps. A second 100-step check compares the optimized FIFO and upstream FIFO at
equal pipeline settings on a reduced 32-entry/two-data-bit model. Describe the
model bounds and restrictions explicitly.

An earlier GF180 candidate added registered full controls, using the second
synchronized read-pointer stage and accepting conservative ready latency. It
passed transactional BMC/covers, full-size decode/full-flag induction, the
4096-entry packet tests and the upstream GMII/MII suite. At the native 5 V
range it measured SS WNS -0.9877 ns before, and -0.9701 ns after, a replayed
42-cell sizing pass; hold remained positive. This is an honest near-miss, not
slow-corner closure. A lower-mux/prefetch variant passed simulation but was
rejected because Yosys could not practically complete global mux reduction.
I also tried registering the bank read address to break the remaining
pointer-to-row-mux path; three upstream MII/clock-enable TX cases failed, so I
reverted it and kept the failure logs instead of claiming a broken fix.

## Questions to be ready for

The next control experiment precomputed frame-full decisions and registered a
fetch carry. It passed formal and simulation but initially worsened timing.
Registering the exact empty comparison then improved the selected sized result
from -0.8296 to -0.6166 ns, retaining +0.1578 ns hold. Full-size TX/RX induction
proved empty-flag equality and carry/decode/full-frame invariants. A further
full-flag rewrite mapped back to an identical circuit: comparing connectivity
explained why source-level simplification produced no STA gain. The 125 MHz
slow-corner target still needed work at that stage; these are pre-layout results.

The later elastic read pipeline fixes storage ownership by separating an
address-fetch pointer from the pointer that returns free slots to the writer.
The first version released slots before pending reads completed; the full
GMII/MII suite exposed corruption. Releasing slots only on bank-data capture
passed the project tests and all eight upstream cases. The reduced 32-entry,
two-data-bit model passed 100-step safety BMC and three covers within 320 steps.
Mapped slow-corner setup improved to -0.9159 ns before sizing, while hold stayed
positive. This is a verified architectural change with an open timing target.

**Why 125 MHz?** GMII transfers eight bits per cycle, so 125 million cycles/s
gives one billion bits/s. Payload throughput is lower because Ethernet adds
preamble, FCS and inter-frame gap.

**Why multiple clocks?** The host stream and receive/transmit datapaths can have
different timing sources. Async FIFOs transfer data while synchronizing
control state. A receive PHY cannot be backpressured like an AXI source.

**What did formal prove?** Finite-bound safety: output stability while stalled,
no phantom output, and preservation of a symbolic selected byte/TLAST in FIFO
order. Thirty arbitrary-clock steps passed; sixty steps passed with a specified
periodic clock ratio. These are not an unbounded proof of the complete MAC.
The RX optimization later gained an unbounded reference-equivalence proof under
the modeled startup/PTP-disabled configuration. The write-decode state has
unbounded consistency proofs at the actual TX/RX FIFO dimensions. These are
specific component results, not a proved lossless full MAC.

**What assumptions mattered?** The producer obeys ready/valid stall rules;
startup reset is asserted; clocks are arbitrary for one task and periodic for
the other. There is no clock fairness assumption, so eventual delivery is not
claimed. The formal FIFO has depth four and frame mode disabled.

**How did you avoid a vacuous proof?** Added a cover that reaches an output
transfer with TLAST at step 23. This demonstrates an active scenario, though it
does not establish exhaustive coverage of every property or configuration.

**What did simulation add?** Full MAC payload/FCS checks, unequal clocks, host
backpressure, malformed FCS, oversized-frame dropping and recovery. These
exercise behaviors outside the reduced formal model.

**Why did setup initially fail badly?** Large frame FIFOs became register banks
with overloaded control/data nets. Electrically unconstrained mapping produced
unrealistic delays from extreme loads. Explicit drive/load constraints allowed
buffering/sizing and brought nominal setup slack positive.

**Why can setup pass but hold fail?** Setup limits the maximum data-path delay;
hold requires a minimum delay. Speeding up cells does not fix a too-short path.
The hold stage therefore adds small delay-buffer chains at failing D pins.

**Did you achieve physical signoff?** No. The selected 5 V SS/FF and TT views
pass setup/hold at 125 MHz with ideal clocks and no routed parasitics. The setup
margin is only 51.5 ps. Placement, CTS and extracted timing remain required;
describe the achieved result as selected-corner pre-layout closure.

**Are false paths enough for CDC?** No. They prevent meaningless synchronous
comparisons between unrelated clocks. Gray-bus flight-time/skew constraints,
reset release, frame-commit handshakes and metastability are separate checks.

## Evidence to show

State the result precisely: the 4096-entry MAC passes selected 5 V SS/FF and TT
pre-layout setup/hold at 125 MHz. Full-depth functional tests and reduced safety
checks pass, with unbounded component/control invariants. Physical signoff and
a full-MAC unbounded proof remain outstanding. Negative experiments explain
why a successful simulation or source simplification alone was insufficient.

Deeper examples: a clock-edge-only invariant had unreachable stopped-clock
induction states, then passed after strengthening it to all states; sizing
improved WNS but did not close it; structural checks caught lost constant
drivers in a timing-tool export, so accepted swaps were replayed on the
known-good JSON. A successful tool invocation is not a validated design result.

Start with `WORK_LOG.md`, then show the actual harness and test file. Use
`build/verified_formal.log`, `build/periodic_formal.log`,
`build/multiclock.log`, and the final timing report. Explain one failure and its
fix using the preserved unconstrained-mapping report. A credible discussion of
assumptions and incomplete coverage is stronger than claiming “everything is
formally verified.”

## Physical implementation follow-up

The integration target was clarified as an IP block in a SoC. The block timing
contract explicitly balances neighboring registers to a MAC clock leaf in
each clock domain. The 8 ns periods and 1.0/0.2 ns interface budgets remain;
top-level CTS/STA must validate the assumed residual skew.

The first physical attempts exposed concrete issues: automatic multi-nanosecond
port delay cells, incorrect via-resistance defaults, missing physical tie-cell
drivers on imported constant nets, and setup damage from indiscriminate hold
repair. The failed checkpoints and reports are retained. The interrupted first
detailed-route pass is not a completed route-DRC result.

Enabling the output queue removed downstream ready from the wide bank/group
read pipeline. This candidate passed full MAC regressions, but post-CTS repair
still measured -0.9423 ns setup / +0.0624 ns hold with placement parasitics.
The next change registered one-hot bank/group selectors and the write data and
decode. Commit visibility was delayed with the physical write to preserve
data-before-commit ordering. Main FIFO depth remains 4096 and the target stays
125 MHz. This candidate maps to 259,559 GF180 nine-track cells.

For that candidate, 100-step reduced safety, cover goals, full-size control
and alignment induction, and masked-mux equivalence passed; an independent
40-step check permits arbitrary clock progress and stalling. Full-size control
proofs do not establish unbounded full-size payload correctness. Physical
timing closure remains a separate result requiring completed routing and
corner-specific parasitic extraction. Use `CURRENT_STATUS.md` and the actual
reports for the latest outcome before quoting a closure claim.

The latest physical attempt is a useful honest result: the structural rewrite
reduced the CTS-repaired setup miss to 330 ps and produced a zero-overflow
global route. Detailed routing was interrupted after its initial iteration
reported 83,609 violations; this is not a final DRC result or evidence that
the design cannot route. The Metal1 global route measured -0.3870 ns setup
and +0.1545 ns hold. The project does not claim GDS or physical signoff.
The remaining tasks include correcting the RX reset-to-empty critical path,
completing router optimization and checking extracted timing. Partial
via-generation and Metal1 routing attempts do not establish their effects
on final convergence. Do not describe SRAM as a demonstrated requirement.
