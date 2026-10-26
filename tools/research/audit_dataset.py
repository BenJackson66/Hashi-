#!/usr/bin/env python3
"""Replay checked-in classifications and test every trace against its witness."""
import argparse
from pathlib import Path
from compare_experiments import rows, stable
from logical_difficulty import Analyzer


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument('directory', type=Path)
    args = parser.parse_args()
    count = 0
    for path in sorted(args.directory.glob('*-raw.jsonl*')):
        raw = [r for r in rows(path) if r['type'] == 'board' and r['status'] == 'success']
        analysis_path = args.directory / path.name.replace('-raw.', '-analysis.')
        records = rows(analysis_path)
        assert len(raw) == len(records)
        for board, record in zip(raw, records):
            assert board['seed'] == record['seed'] and board['puzzle']['id'] == record['puzzle_id']
            analyzer = Analyzer(board['puzzle']['islands'])
            result = analyzer.analyze()
            assert stable(result) == stable(record['analysis'])
            expected = []
            for i, j in analyzer.edges:
                a, b = sorted((board['puzzle']['islands'][i]['id'], board['puzzle']['islands'][j]['id']))
                expected.append(board['solution'].get(a + ':' + b, 0))
            domains = [[0, 1, 2] for _ in analyzer.edges]
            for event in result['trace']:
                e = event['edge']
                assert event['before'] == domains[e]
                assert expected[e] in event['after']
                domains[e] = event['after']
            assert domains == result['domains']
            count += 1
    assert count > 0
    print(f'PASS: {count} classifications replayed; all committed deductions preserve the unique witness.')


if __name__ == '__main__':
    main()
