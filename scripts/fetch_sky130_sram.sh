#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dest="$root/build/sky130_sram_macros"
repo="https://github.com/VLSIDA/sky130_sram_macros.git"
commit="965df150c754fe2b3f93a0bd1f9883eb114279b2"
macro_dir="$dest/sky130_sram_2kbyte_1rw1r_32x512_8"

if [[ ! -d "$dest/.git" ]]; then
    git clone --filter=blob:none "$repo" "$dest"
fi

git -C "$dest" fetch --depth 1 origin "$commit"
git -C "$dest" checkout --detach "$commit"

for file in \
    "$macro_dir/sky130_sram_2kbyte_1rw1r_32x512_8.v" \
    "$macro_dir/sky130_sram_2kbyte_1rw1r_32x512_8.lef" \
    "$macro_dir/sky130_sram_2kbyte_1rw1r_32x512_8.gds" \
    "$macro_dir/sky130_sram_2kbyte_1rw1r_32x512_8_TT_1p8V_25C.lib"; do
    test -f "$file" || { echo "missing Sky130 SRAM collateral: $file" >&2; exit 1; }
done

echo "Sky130 SRAM collateral ready: $macro_dir"
