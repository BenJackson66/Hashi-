#!/usr/bin/env python3
"""Generate with unchanged Godot utility, analyze offline, retain auditable JSONL."""
import argparse
import hashlib
import json
import math
import platform
import statistics
import subprocess
import time
from collections import Counter
from pathlib import Path
from logical_difficulty import Analyzer, VERSION

ROOT = Path(__file__).resolve().parents[2]
CONFIGS = [(5, 5, 10), (5, 5, 16), (7, 7, 16), (8, 8, 24), (10, 10, 30)]


def percentile(values, p):
    return sorted(values)[max(0, math.ceil(len(values) * p) - 1)] if values else None


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument('--count', type=int, default=200)
    parser.add_argument('--seed', type=int, default=1)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if not 1 <= args.count <= 1000:
        parser.error('count must be 1..1000')
    args.output.mkdir(parents=True, exist_ok=True)
    summary = {'analyzer_version': VERSION, 'base_commit': subprocess.check_output(
        ['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
        'python': platform.python_version(), 'seed_start': args.seed, 'count_per_configuration': args.count,
        'source_sha256': {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in
                          ['scripts/hashi_generator.gd', 'scripts/hashi_solver.gd']}, 'configurations': []}
    for width, height, islands in CONFIGS:
        name = f'{width}x{height}-{islands}'
        raw_path = args.output / f'{name}-raw.jsonl'
        command = ['tools/dev.sh', '--headless', '--script', 'tools/evaluate_generation.gd', '--',
                   f'--width={width}', f'--height={height}', f'--island_count={islands}',
                   f'--count={args.count}', f'--seed={args.seed}', f'--output={raw_path.resolve()}']
        result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=args.count * 2 + 60)
        if result.returncode not in (0, 1) or not raw_path.exists():
            raise RuntimeError(result.stderr)
        rows = [json.loads(line) for line in raw_path.read_text().splitlines()]
        assert rows[-1]['type'] == 'summary' and rows[-1]['count'] == args.count
        records, failures = [], Counter()
        with (args.output / f'{name}-analysis.jsonl').open('w') as out:
            for row in rows:
                if row['type'] != 'board':
                    continue
                if row['status'] != 'success':
                    failures[row['reason']] += 1
                    continue
                assert row['uniqueness'] == 'unique'
                started = time.perf_counter()
                analysis = Analyzer(row['puzzle']['islands']).analyze()
                analysis['analysis_ms'] = (time.perf_counter() - started) * 1000
                # Independent witness used only AFTER classification, as a soundness audit.
                for e, (i, j) in enumerate(analysis['edges']):
                    a, b = sorted([row['puzzle']['islands'][i]['id'], row['puzzle']['islands'][j]['id']])
                    value = row['solution'].get(a + ':' + b, 0)
                    assert value in analysis['domains'][e], (name, row['seed'], e)
                assert analysis['status'] != 'contradiction'
                record = {'seed': row['seed'], 'puzzle_id': row['puzzle']['id'],
                          'dimensions': row['dimensions'], 'island_count': islands,
                          'generation_ms': row['elapsed_ms'], 'attempts': row['attempts'],
                          'solver': row['metrics'], 'analysis': analysis}
                out.write(json.dumps(record, sort_keys=True, separators=(',', ':')) + '\n')
                records.append(record)
        profiles = Counter(r['analysis']['profile'] for r in records)
        entry = {'dimensions': [width, height], 'islands': islands,
                 'environment': rows[0], 'generation': rows[-1], 'failures': dict(failures),
                 'profiles': dict(profiles), 'profiles_detail': {}}
        for profile in profiles:
            group = [r for r in records if r['analysis']['profile'] == profile]
            entry['profiles_detail'][profile] = {
                'seeds_first_10': [r['seed'] for r in group[:10]],
                'acceptance_per_requested_seed': len(group) / args.count,
                'amortized_generation_ms': sum(r['elapsed_ms'] for r in rows if r['type'] == 'board') / len(group),
                **{field: {'mean': statistics.mean(values), 'p95': percentile(values, .95), 'max': max(values)}
                   for field, values in {
                       'solver_nodes': [r['solver']['search_nodes'] for r in group],
                       'solver_ms': [r['solver']['elapsed_ms'] for r in group],
                       'analysis_ms': [r['analysis']['analysis_ms'] for r in group],
                       'deductions': [r['analysis']['deductions'] for r in group],
                       'probe_tests': [r['analysis']['probe_tests'] for r in group]}.items()}}
        summary['configurations'].append(entry)
        print(name, dict(profiles), 'failures', dict(failures), flush=True)
    (args.output / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')


if __name__ == '__main__':
    main()
