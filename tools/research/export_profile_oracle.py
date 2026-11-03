#!/usr/bin/env python3
"""H03-A evidence -> independent runtime port oracle. Does not change h03a-1."""
import gzip
import json
from pathlib import Path
import sys
root = Path(__file__).resolve().parents[2]
records = []
for raw in sorted((root / 'docs/research/h03a').glob('*-raw.jsonl.gz')):
    with gzip.open(raw, 'rt') as stream:
        boards = [json.loads(line) for line in stream if json.loads(line)['type'] == 'board']
    with gzip.open(str(raw).replace('-raw.', '-analysis.'), 'rt') as stream:
        analyses = [json.loads(line) for line in stream]
    for board, analysis in zip(boards, analyses):
        assert board['seed'] == analysis['seed']
        records.append({'puzzle': board['puzzle'], 'solution': board['solution'],
                        'expected': analysis['analysis']})
assert len(records) == 1000
Path(sys.argv[1]).write_text(json.dumps(records))
