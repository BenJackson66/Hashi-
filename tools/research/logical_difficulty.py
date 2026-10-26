#!/usr/bin/env python3
"""Offline, deterministic research analyzer h03a-1; no production imports.
Domains describe bridge counts. No solution/witness is consulted by analyze().
"""
from collections import Counter
from copy import deepcopy

VERSION = 'h03a-1'


def topology(islands):
    edges = []
    for i, a in enumerate(islands):
        for j in range(i + 1, len(islands)):
            b = islands[j]
            if a['x'] != b['x'] and a['y'] != b['y']:
                continue
            if any(k not in (i, j) and
                   ((a['x'] == b['x'] == c['x'] and min(a['y'], b['y']) < c['y'] < max(a['y'], b['y'])) or
                    (a['y'] == b['y'] == c['y'] and min(a['x'], b['x']) < c['x'] < max(a['x'], b['x'])))
                   for k, c in enumerate(islands)):
                continue
            edges.append((i, j))
    crossings = []
    for e, (i, j) in enumerate(edges):
        for f in range(e + 1, len(edges)):
            k, l = edges[f]
            if len({i, j, k, l}) < 4:
                continue
            a, b, c, d = (islands[v] for v in (i, j, k, l))
            if a['x'] == b['x']:
                a, b, c, d = c, d, a, b
            if (a['y'] == b['y'] and c['x'] == d['x'] and
                    min(a['x'], b['x']) < c['x'] < max(a['x'], b['x']) and
                    min(c['y'], d['y']) < a['y'] < max(c['y'], d['y'])):
                crossings.append((e, f))
    return edges, crossings


class Analyzer:
    def __init__(self, islands):
        self.islands = islands
        self.edges, self.crossings = topology(islands)
        self.incident = [[e for e, pair in enumerate(self.edges) if i in pair]
                         for i in range(len(islands))]

    def reachable(self, domains, omit=-1):
        seen, pending = {0}, [0]
        while pending:
            i = pending.pop()
            for e in self.incident[i]:
                if e == omit or max(domains[e]) == 0:
                    continue
                a, b = self.edges[e]
                j = b if i == a else a
                if j not in seen:
                    seen.add(j)
                    pending.append(j)
        return sorted(seen)

    def step(self, domains, cuts):
        if any(not d for d in domains):
            raise ValueError('empty_domain')
        for i, incident in enumerate(self.incident):
            lower = sum(min(domains[e]) for e in incident)
            upper = sum(max(domains[e]) for e in incident)
            target = self.islands[i]['target']
            if not lower <= target <= upper:
                raise ValueError('island_capacity')
            for e in incident:
                kept = [v for v in domains[e] if
                        v + lower - min(domains[e]) <= target <= v + upper - max(domains[e])]
                if kept != domains[e]:
                    return e, kept, {'technique': 'local_capacity', 'island': self.islands[i]['id'],
                                     'target': target, 'lower_sum': lower, 'upper_sum': upper}
        for e, f in self.crossings:
            for a, b in ((e, f), (f, e)):
                if min(domains[a]) > 0:
                    if 0 not in domains[b]:
                        raise ValueError('crossing')
                    if domains[b] != [0]:
                        return b, [0], {'technique': 'crossing_exclusion', 'positive_edge': a}
        if cuts:
            if len(self.reachable(domains)) != len(self.islands):
                raise ValueError('disconnected_possible_graph')
            for e, domain in enumerate(domains):
                if len(domain) > 1 and max(domain) > 0:
                    side = self.reachable(domains, e)
                    if len(side) != len(self.islands):
                        if 0 in domain:
                            return e, [v for v in domain if v > 0], {
                                'technique': 'connectivity_cut', 'cut_side': side}
                        # Internal bridges contribute twice to the sum of clues.
                        # With one possible exit, its count has that sum's parity.
                        target_sum = sum(self.islands[i]['target'] for i in side)
                        kept = [v for v in domain if v % 2 == target_sum % 2]
                        if not kept:
                            raise ValueError('cut_parity')
                        if kept != domain:
                            return e, kept, {'technique': 'cut_parity', 'cut_side': side,
                                             'target_sum': target_sum}
        return None

    def close(self, domains, cuts, trace):
        while True:
            change = self.step(domains, cuts)
            if change is None:
                return
            e, kept, reason = change
            trace.append(dict(reason, edge=e, before=domains[e][:], after=kept[:]))
            domains[e] = kept

    def analyze(self, max_probes=10000):
        domains = [[0, 1, 2] for _ in self.edges]
        trace, probes, highest = [], 0, 1
        try:
            while True:
                self.close(domains, False, trace)
                if all(len(d) == 1 for d in domains):
                    # Local degrees alone could finish a disconnected graph.
                    if len(self.reachable(domains)) != len(self.islands):
                        raise ValueError('disconnected_final_graph')
                    status = 'solved'
                    break
                change = self.step(domains, True)
                if change:
                    e, kept, reason = change
                    trace.append(dict(reason, edge=e, before=domains[e][:], after=kept[:]))
                    domains[e] = kept
                    highest = max(highest, 2)
                    continue
                rejected = False
                for e, domain in enumerate(domains):
                    if len(domain) == 1:
                        continue
                    for value in domain:
                        if probes >= max_probes:
                            return self.result('probe_limit', highest, domains, trace, probes)
                        probes += 1
                        trial, proof = deepcopy(domains), []
                        trial[e] = [value]
                        try:
                            self.close(trial, True, proof)
                        except ValueError as error:
                            kept = [v for v in domain if v != value]
                            trace.append({'technique': 'single_assumption_contradiction', 'edge': e,
                                          'before': domain[:], 'after': kept, 'assumed': value,
                                          'contradiction': str(error), 'proof': proof})
                            domains[e] = kept
                            highest, rejected = 3, True
                            break
                    if rejected:
                        break
                if not rejected:
                    status = 'unresolved'
                    break
        except ValueError as error:
            return dict(self.result('contradiction', highest, domains, trace, probes), reason=str(error))
        return self.result(status, highest, domains, trace, probes)

    def result(self, status, highest, domains, trace, probes):
        return {'analyzer_version': VERSION, 'status': status,
                'profile': ['local', 'connectivity', 'contradiction1'][highest - 1] if status == 'solved' else 'unclassified',
                'techniques': dict(Counter(t['technique'] for t in trace)), 'deductions': len(trace),
                'probe_tests': probes, 'domains': domains, 'edges': self.edges,
                'possible_connections': len(self.edges), 'crossing_pairs': len(self.crossings), 'trace': trace}
