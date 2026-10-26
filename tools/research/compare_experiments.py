#!/usr/bin/env python3
"""Assert identical board content, proof traces and deterministic metrics.
Only elapsed times, CPU/environment and summary timing fields are excluded.
Accepts JSONL or checked-in JSONL.gz files.
"""
import argparse
import gzip
import json
from pathlib import Path


def rows(path):
    if not path.exists():
        path = Path(str(path) + '.gz')
    opener = gzip.open if path.suffix == '.gz' else open
    with opener(path, 'rt') as stream:
        return [json.loads(line) for line in stream]


def stable(value):
    if isinstance(value, dict):
        return {k: stable(v) for k, v in value.items() if k not in ('elapsed_ms', 'analysis_ms', 'generation_ms')}
    if isinstance(value, (list, tuple)):
        return [stable(v) for v in value]
    return value


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument('reference', type=Path)
    parser.add_argument('candidate', type=Path)
    args = parser.parse_args()
    count = 0
    for ref in sorted(args.reference.glob('*-raw.jsonl*')):
        name = ref.name.removesuffix('.gz')
        first = [r for r in rows(args.reference / name) if r['type'] == 'board']
        second = [r for r in rows(args.candidate / name) if r['type'] == 'board']
        assert stable(first) == stable(second), name
        analysis = name.replace('-raw.', '-analysis.')
        assert stable(rows(args.reference / analysis)) == stable(rows(args.candidate / analysis)), analysis
        count += len(first)
    assert count > 0
    print(f'PASS: {count} boards; identical identities, clues, solutions, attempts, metrics and proof traces (times excluded).')


if __name__ == '__main__':
    main()
