"""Summarize measured internal and I/O timing without promoting an ECO."""
import argparse
import json
from pathlib import Path
import re

parser = argparse.ArgumentParser()
parser.add_argument('reports', type=Path)
args = parser.parse_args()
results = []
for corner in ('WC', 'BC', 'TC'):
    for scope in ('all', 'internal'):
        path = args.reports / ('audit_output_buffer_eco.rpt.' + corner +
                               ('.internal' if scope == 'internal' else ''))
        if not path.exists():
            raise SystemExit(f'Missing report: {path}')
        paths = []
        for block in path.read_text().split('Startpoint: ')[1:]:
            delay = re.search(r'Path Type: (min|max)', block)
            slack = re.search(r'([-+\d.]+)\s+slack \((MET|VIOLATED)\)', block)
            if delay and slack:
                paths.append((delay[1], float(slack[1])))
        if not paths:
            raise SystemExit(f'No measured paths in {path}')
        results.append(dict(corner=corner, scope=scope,
                            setup_ns=min(v for t, v in paths if t == 'max'),
                            hold_ns=min(v for t, v in paths if t == 'min')))
print(json.dumps(dict(stage='CTS output-buffer ECO',
                      parasitics='placement estimate',
                      constraints_changed=False, timing=results), indent=2))
