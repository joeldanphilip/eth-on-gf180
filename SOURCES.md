# Sources and licensing

MAC and AXI components: https://github.com/alexforencich/verilog-ethernet
revision `77320a9471d19c7dd383914bc049e02d9f4f1ffb`. MIT license in
`vendor/verilog-ethernet/COPYING`. Upstream is deprecated in favor of Taxi;
this pinned Verilog implementation is selected for direct Yosys compatibility.
Vendor RTL is unmodified.

Timing engine: https://github.com/The-OpenROAD-Project/OpenSTA
revision `a50641666c6e2fd19ff0226f9b6300d876bf8613`.
Typical Nangate45 library: OpenROAD-flow-scripts, under
`tools/ORFS/flow/platforms/nangate45/lib`. Consult upstream license files.
ORFS revision: `202c7fccbce32e86db899c54b0a0f0484f869cc3`.
SymbiYosys revision: `79fc9eddca5e33a28cc2f2cd19c9825efd9a7255`.
Yosys SMT Python support revision: `63eecf3ddca2f143750f11e37ebd18ecb16b51c7`.
The repaired Yosys technology maps use tag `v0.61`, matching the installed
binary's `0.61+21` version; current-main maps require newer internal mappers.
CUDD revision: `f54f533303640afd5dbe47a05ebeabb3066f2a25`.
Eigen revision: `36b95962756c1fce8e29b1f8bc45967f30773c00`.

The GF180MCU 180 nm extension uses assembled 9-track Liberty files and five-metal
technology/cell LEFs from the same pinned ORFS checkout. A direct official
standard-cell checkout at `tools/gf180mcu9t` is pinned at
`3781fd2951da6e3dc4600e52d997398a9463caeb`; its root Liberty files are headers,
whereas ORFS supplies the assembled libraries consumed by this flow. See
`TECHNOLOGY.md` for exact corners, names and use of the physical views.

Downloaded tool sources, libraries and local builds are in `tools/`.
Python packages are isolated in `.venv`; simulation versions are pinned in
`requirements.txt`. `scripts/` repairs runtime path problems in this machine's
existing OSS CAD Suite without modifying that installation.
