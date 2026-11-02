"""Assemble original GF180 CDL and bind body ports omitted by the 2-rail LEF.

OpenROAD writes VNW/VPW as unconnected because the standard-cell LEF exposes
VDD/VSS only.  This block uses the normal body-rail contract: VNW=VDD and
VPW=VSS.  The unmodified device models are retained; GDS LVS must validate
that the tapcells actually implement these connections.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser()
p.add_argument('--input', type=Path)
p.add_argument('--output', type=Path)
args = p.parse_args()
outdir = ROOT / 'build/gf180_lvs'
outdir.mkdir(exist_ok=True)
files = sorted((ROOT / 'tools/gf180_9t_lvs/cells').glob('*/*.cdl'))
assert files
texts = [f.read_text() for f in files]
normalizations = []
lvs_texts = []
for source, text in zip(files, texts):
    lines = text.splitlines()
    for i, line in enumerate(lines):
        if not re.match(r'^[dD]\S*\s', line):
            continue
        fields = line.split()
        # Legacy CDL gives positional area/perimeter; KLayout's SPICE
        # reader requires A/P keywords in SI units. Preserve both values,
        # both terminals, model and multiplicity exactly.
        assert len(fields) == 7 and fields[6].lower() == '$m=1', line
        assert fields[3] in ('diode_nd2ps_06v0', 'diode_pd2nw_06v0'), line
        replacement = ' '.join(fields[:4] + [f'A={fields[4]}', f'P={fields[5]}', 'M=1'])
        normalizations.append({'source': str(source.relative_to(ROOT)),
                               'original': line, 'spice': replacement})
        lines[i] = replacement
    lvs_texts.append('\n'.join(lines)+'\n')
masters = {}
for text in texts:
    for match in re.finditer(r'^\.SUBCKT\s+(\S+)\s+([^\n]+)', text, re.M | re.I):
        assert match[1] not in masters
        masters[match[1]] = match[2].split()
(outdir / 'masters.cdl').write_text('\n'.join(texts))
(outdir / 'masters_lvs.cdl').write_text('\n'.join(lvs_texts))
(outdir / 'masters_manifest.json').write_text(json.dumps({
    'body_connections': {'VNW': 'VDD', 'VPW': 'VSS'},
    'body_connections_require_gds_lvs_validation': True,
    'master_count': len(masters),
    'diode_syntax_normalizations': normalizations,
    'sources_sha256': {str(f.relative_to(ROOT)): hashlib.sha256(f.read_bytes()).hexdigest() for f in files},
}, indent=2) + '\n')
if args.input:
    assert args.output
    # Rejoin CDL continuations before resolving positional master ports.
    logical = []
    for line in args.input.read_text().splitlines():
        if line.startswith('+'):
            logical[-1] += ' ' + line[1:]
        else:
            logical.append(line)
    changed = 0
    for i, line in enumerate(logical):
        if not line.lstrip().upper().startswith('X'):
            continue
        fields = line.split()
        model = fields[-1]
        assert model in masters, f'Missing CDL master {model}'
        ports = masters[model]
        assert len(fields) == len(ports) + 2, (model, len(fields), ports)
        for body, rail in [('VNW', 'VDD'), ('VPW', 'VSS')]:
            if body not in ports:
                continue
            pos = ports.index(body) + 1
            rail_net = fields[ports.index(rail) + 1]
            assert fields[pos].startswith('_unconnected_') or fields[pos] == rail_net, (model, body, fields[pos])
            fields[pos] = rail_net
            changed += 1
        assert not any(x.startswith('_unconnected_') for x in fields), f'Unresolved CDL port on {fields[0]}'
        logical[i] = ' '.join(fields)
    args.output.write_text('\n'.join(logical) + '\n\n' + '\n'.join(lvs_texts))
    print(f'GF180_LVS body_ports_bound={changed} masters={len(masters)} output={args.output}')
else:
    print(f'GF180_LVS masters={len(masters)} file={outdir / "masters.cdl"}')
