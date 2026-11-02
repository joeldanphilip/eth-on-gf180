# Physical repair experiments

All measurements below use placement parasitics at the saved CTS checkpoint,
unchanged 8 ns clocks and original I/O budgets. They are not extracted signoff.

| Candidate | Setup WNS (ns) | Hold WNS (ns) | Outcome |
| --- | ---: | ---: | --- |
| Original CTS | -5.4736 | -5.4928 | Baseline |
| Replace 28 output delay cells with buf_16 | -3.61 | -5.49 | Experimental, not yet legalized |
| Independent hold repair and legalization | -9.8077 | -0.6868 | Rejected setup regression |
| Revised clock tree, output buffers, legalization | -3.1734 | -5.0481 | New experimental baseline |
| Setup then hold repair, legalized | -14.8921 | +0.0732 | Rejected setup regression |
| Ordinary buffers, revised CTS, legalized | -5.4672 | -2.0794 | Rejected; both analyses fail |
| Ordinary buffers excluding drive-1 cells | -3.2788 | -2.1213 | Both analyses still fail |
| Hold padding restricted to input nets | -2.5418 | -2.8600 | Legal placement; both analyses still fail |
| Broad early-clock interface ECO, 97 flops | -5.1733 | -2.5423 | Rejected internal setup regressions |

The ordinary-buffer trial starts from the revised clock tree and
excludes delay cells from resizer choices. Run and inspect it with:

```sh
make -f physical/Makefile WORK_HOME="$PWD/build/physical_compat_rc" repair-balanced
```

Full logs are `build/physical_compat_rc/*_driver.log`. Checkpoints and timing
reports live in that directory's `results/gf180/ethernet_1g_4096/base` and
`reports/gf180/ethernet_1g_4096/base` subdirectories. Candidates remain
experimental until functional equivalence, legal placement, setup/hold,
electrical constraints and routing have all been checked.

The previous detailed-route run was interrupted during its optimization. Its
93,631 first-pass violations do not establish a final DRC failure or prove that
the design cannot route. SRAM integration remains an architectural option;
the present experiments first address the concrete I/O/clock repair problems.

The ordinary-buffer trial's worst internal path includes hold buffers on a
shared FIFO-full/data-valid cone. This damages internal setup while repairing
external input hold. Further repair must isolate I/O hold padding from shared
control cones and honor the platform prohibition on drive-1 cells; the trial
selected clkbuf_1 cells with multi-nanosecond slew. These candidates are not
promoted to routing.

The separate port-isolation trial protects internal nets during hold repair,
allowing padding only on input nets. It saves `4_port_setup.odb` before that
step for reproducible retries. Its first attempt stopped on unsupported
`get_nets -of_objects` for ports; the retry uses OpenDB's BTerm connections.
Evidence: `port_hold_driver.log` and `port_hold_retry_driver.log`.

The corrected port-isolation trial saved `4_port_hold_trial.{odb,sdc}`. It
inserted eight hold buffers and preserved setup WNS at -2.5418 ns; hold WNS
remains -2.8600 ns. The dominant setup path is an output status pulse launched
after about 6.12 ns of logic-clock insertion. Further work must address
interface clock latency and/or explicit interface pipeline stages. Cell
resizing alone has not achieved closure under the current I/O budgets.

The broad early-clock ECO reduced setup TNS to -9527.59 ns but worsened worst
setup to -5.1733 ns, so it is rejected. It retained the same root clock for
each moved flop and did not modify RTL or SDC. Its initial query/API issues
are preserved in `interface_skew*_driver.log`.

Core optimization uses a temporary analysis view that excludes I/O paths only
while the optimizer works on register-to-register paths. It never exports that
SDC. A fresh process reloads the candidate ODB and original full SDC, reports
the full timing result and separately reports internal paths at all three cell
corners. Temporary-view slack is not a full-design closure result. The current
1 ns I/O budgets originated as example assumptions, not a supplied board spec;
integration timing requirements remain to be clarified.

The user subsequently confirmed SoC IP-block integration. The explicit
`soc_interface.tcl` contract keeps 8 ns periods and 1.0/0.2 ns budgets and
references a clock leaf in each domain; top-level CTS must validate this.
It does not add CDC exceptions or remove internal timing paths.

| Candidate | Setup WNS (ns) | Hold WNS (ns) | Evidence |
| --- | ---: | ---: | --- |
| DECOUPLE_READ post-CTS | -1.2273 | +0.0624 | `build/physical_decoupled/reports/gf180/ethernet_decoupled_4096/base/physical_soc_cts_timing.rpt` |
| DECOUPLE_READ repaired | -0.9423 | +0.0624 | `physical_soc_cts_repaired_timing.rpt` in the same directory |

These are legal-placement estimates, not extracted results. Actual remaining
paths identified binary bank selection and storage writes. The new
`READ_BANK_ONEHOT` + `PIPELINED_WRITE` candidate addresses those cones, keeps
4096-entry main FIFOs and 125 MHz clocks, and has a separate physical run in
`build/physical_pipeline_layout/`. Its mapped design has 259,559 cells. No
timing result is assigned until the corresponding stage completes.
