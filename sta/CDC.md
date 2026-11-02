# CDC boundaries to constrain during physical implementation

The TX FIFO crosses `logic_clk` to `tx_clk`; the RX FIFO crosses `rx_clk` to
`logic_clk`. Both are upstream `axis_async_fifo_adapter` instances with frame
FIFO mode enabled in the MAC. The byte-mode formal harness is a reduced study
of the underlying FIFO, not a proof of the frame-commit handshake.

Inside `axis_async_fifo.v`, read/write Gray pointers cross through
`rd_ptr_gray_sync1_reg` / `rd_ptr_gray_sync2_reg` and
`wr_ptr_gray_sync1_reg` / `wr_ptr_gray_sync2_reg`. Frame-commit pointers use a
separate update/acknowledge handshake. The MAC also transfers error/status
pulses through toggle synchronizers, and the FIFO synchronizes resets.

For physical implementation, preserve synchronizer stages and constrain each
source Gray bus to its first synchronizer bank using the relevant source clock
period as the maximum flight-time/skew budget. Also check the stable-data
requirements on frame-commit handshake buses. Obtain endpoints from the final
mapped hierarchy; do not silently accept empty wildcard collections.

The functional clock-group exceptions in `mac.sdc` deliberately suppress
inter-domain setup/hold comparisons. Separate physical CDC constraints must
take precedence as supported by the selected implementation tool. A clean
functional STA report alone cannot validate these crossings or metastability.

For the mapped `PIPELINED_WRITE` build, `scripts/build_cdc_endpoints.py`
resolves semantic register outputs in the synthesis netlist to physical flop
instances and records a source hash. It requires all expected endpoints;
TX/RX read Gray pointers each have 13 bits. Frame mode optimizes away the
unused write-Gray synchronizers. Status `sync1` registers generate source-domain
toggles; `sync2` is their first receiving stage.

`make -f physical/Makefile WORK_HOME=... eco-check-cdc` loads the completed
routed checkpoint and all three extracted SPEFs in an independent process.
It removes asynchronous clock groups only in that audit process and checks
85 explicit paths with a conservative 8 ns maximum delay, ignoring launch
and capture clock latencies. The checked paths include source clock-to-Q and
endpoint setup. Gray flight bounds restrict transition overlap; frame data
is held by the update/acknowledge protocol. The frame bus is also checked to
the elastic-empty lookahead consumer, not just the commit register bank.
Every path must exist and have nonnegative slack at WC, BC and TC.

This target is staged pending the routed SPEFs. A generated endpoint list is
not a passing CDC result. It does not measure metastability MTBF, prove reset
release recovery/removal, or validate top-level SoC clock distribution.
