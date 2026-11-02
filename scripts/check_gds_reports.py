"""Strict, small summaries of real GF180 DRC/LVS outputs."""
import argparse
from collections import Counter
import json
from pathlib import Path
import sys
import xml.etree.ElementTree as ET

p = argparse.ArgumentParser()
p.add_argument('kind', choices=['drc', 'lvs'])
p.add_argument('report', type=Path)
p.add_argument('--output', type=Path)
args = p.parse_args()
if args.kind == 'drc':
    counts = Counter()
    root_tag = None
    for event, elem in ET.iterparse(args.report, events=('start', 'end')):
        if root_tag is None:
            root_tag = elem.tag
        if event == 'end' and elem.tag == 'item':
            category = elem.findtext('category') or 'uncategorized'
            counts[category.strip("\"'")] += 1
            elem.clear()
    if root_tag != 'report-database':
        raise ValueError(f'Not a KLayout report database: {root_tag}')
    result = {'check': 'GF180 full DRC', 'report': str(args.report),
              'violations': sum(counts.values()), 'by_category': dict(sorted(counts.items())),
              'pass': not counts}
else:
    log = args.report.read_text(errors='replace')
    matched = 'INFO : Congratulations! Netlists match.' in log
    failed = "ERROR : Netlists don't match" in log or 'ERROR:' in log or 'Exception' in log
    result = {'check': 'GF180 GDS LVS', 'log': str(args.report), 'pass': matched and not failed,
              'match_message_found': matched, 'failure_message_found': failed}
text = json.dumps(result, indent=2) + '\n'
if args.output:
    args.output.write_text(text)
print(text, end='')
sys.exit(0 if result['pass'] else 1)
