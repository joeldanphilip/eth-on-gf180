"""Check a completed OpenSTA summary; optionally fail CI on negative slack."""
import argparse
import json
import re
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('report', type=Path)
parser.add_argument('--require-closure', action='store_true')
args = parser.parse_args()
log = args.report.read_text(errors='replace')
values = {kind: float(value) for kind, value in
          re.findall(r'^worst slack (max|min)\s+(-?[\d.]+)', log, re.M)}
errors = re.findall(r'^Error:.*', log, re.M)
complete = set(values) == {'min', 'max'} and not errors
met = complete and all(value >= 0 for value in values.values())
print(json.dumps({'report':str(args.report), 'complete':complete,
                  'slack_ns':values, 'timing_met':met, 'errors':errors}, indent=2))
raise SystemExit(0 if complete and (met or not args.require_closure) else 1)
