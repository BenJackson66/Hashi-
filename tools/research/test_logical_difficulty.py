#!/usr/bin/env python3
"""Independent exhaustive oracle: every deduction must preserve EVERY solution."""
import itertools
import unittest
from logical_difficulty import Analyzer, topology


def fixture(points, targets):
    return [dict(id=f'i{i}', x=x, y=y, target=t) for i, ((x, y), t) in enumerate(zip(points, targets))]


def solutions(islands):
    analyzer = Analyzer(islands)
    for values in itertools.product(range(3), repeat=len(analyzer.edges)):
        if any(sum(values[e] for e in es) != islands[i]['target'] for i, es in enumerate(analyzer.incident)):
            continue
        if any(values[e] and values[f] for e, f in analyzer.crossings):
            continue
        if len(analyzer.reachable([[v] for v in values])) == len(islands):
            yield values


class Tests(unittest.TestCase):
    def test_exhaustive_preservation_and_reproducibility(self):
        # All 256 square clue combinations + 256 crossing-topology clues.
        for points in [[(0, 0), (2, 0), (0, 2), (2, 2)],
                       [(1, 0), (0, 1), (2, 1), (1, 2)]]:
            for targets in itertools.product(range(1, 5), repeat=4):
                islands = fixture(points, targets)
                witnesses = list(solutions(islands))
                a = Analyzer(islands).analyze()
                self.assertEqual(a, Analyzer(islands).analyze())
                if a['status'] == 'solved':
                    self.assertEqual(1, len(witnesses))
                if witnesses:
                    self.assertNotEqual('contradiction', a['status'])
                for witness in witnesses:
                    for e, v in enumerate(witness):
                        self.assertIn(v, a['domains'][e])
                if witnesses:
                    domains = [[0, 1, 2] for _ in a['edges']]
                    for event in a['trace']:
                        self.assertEqual(domains[event['edge']], event['before'])
                        domains[event['edge']] = event['after']
                        for witness in witnesses:
                            self.assertIn(witness[event['edge']], event['after'])

    def test_crossing_and_intermediate_island(self):
        islands = fixture([(0, 1), (2, 1), (1, 0), (1, 2)], [1] * 4)
        self.assertEqual(len(topology(islands)[1]), 1)
        self.assertEqual(Analyzer(islands).analyze()['status'], 'contradiction')
        edges, _ = topology(fixture([(0, 0), (1, 0), (2, 0)], [1, 2, 1]))
        self.assertNotIn((0, 2), edges)

    def test_connectivity_cut(self):
        # Two cyclic groups joined by one possible edge: a genuine group cut.
        islands = fixture([(0, 0), (2, 0), (0, 2), (2, 2),
                           (4, 2), (6, 2), (4, 4), (6, 4)], [3, 3, 3, 4, 4, 3, 3, 3])
        analyzer = Analyzer(islands)
        domains = [[0, 1, 2] for _ in analyzer.edges]
        analyzer.close(domains, False, [])
        e, kept, reason = analyzer.step(domains, True)
        self.assertEqual('connectivity_cut', reason['technique'])
        self.assertEqual([1, 2], kept)
        self.assertEqual([0, 1, 2, 3], reason['cut_side'])
        domains[e] = kept
        parity_edge, parity_kept, parity_reason = analyzer.step(domains, True)
        self.assertEqual(e, parity_edge)
        self.assertEqual([1], parity_kept)
        self.assertEqual('cut_parity', parity_reason['technique'])
        witnesses = list(solutions(islands))
        self.assertTrue(witnesses)
        for witness in witnesses:
            self.assertIn(witness[e], kept)
            self.assertIn(witness[e], parity_kept)

    def test_crossing_with_satisfiable_clues(self):
        points = [(0, 1), (2, 1), (1, 0), (1, 2), (0, 0), (2, 2)]
        base = fixture(points, [1] * 6)
        analyzer = Analyzer(base)
        self.assertTrue(analyzer.crossings)
        cases = set()
        for values in itertools.product(range(3), repeat=len(analyzer.edges)):
            if any(values[e] and values[f] for e, f in analyzer.crossings):
                continue
            if len(analyzer.reachable([[v] for v in values])) != 6:
                continue
            targets = tuple(sum(values[e] for e in incident) for incident in analyzer.incident)
            cases.add(targets)
        self.assertTrue(cases)
        for targets in sorted(cases):
            islands = fixture(points, targets)
            result = Analyzer(islands).analyze()
            for witness in solutions(islands):
                for e, value in enumerate(witness):
                    self.assertIn(value, result['domains'][e])

    def test_probe_budget_and_multiple(self):
        islands = fixture([(0, 0), (2, 0), (0, 2), (2, 2)], [3] * 4)
        self.assertEqual('probe_limit', Analyzer(islands).analyze(max_probes=0)['status'])
        self.assertEqual('unresolved', Analyzer(islands).analyze()['status'])
        self.assertGreater(len(list(solutions(islands))), 1)


if __name__ == '__main__':
    unittest.main()
