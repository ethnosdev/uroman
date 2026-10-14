#!/usr/bin/env python3
"""Instruments uroman lattice to find spans with multiple competing edges of the same class."""

from collections import defaultdict
from pathlib import Path
import re
import sys

sys.path.insert(0, '/tmp/uroman-py/uroman')
from uroman import Uroman, Lattice, Edge, NumEdge, RomFormat

def main():
    repo_root = Path(__file__).resolve().parent.parent.parent
    data_dir = repo_root / 'data'
    fixtures_dir = repo_root / 'test' / 'fixtures'

    print(f'Loading uroman from {data_dir}...')
    u = Uroman(data_dir)

    ambiguous_spans = []
    total_spans_checked = 0
    multi_edge_spans = 0

    fixture_files = list(fixtures_dir.glob('*.txt')) + list((fixtures_dir / 'text').glob('*.txt'))
    print(f'Scanning {len(fixture_files)} fixture files...')

    for file_path in sorted(fixture_files):
        if 'ref' in file_path.name:
            continue
        lcode = file_path.stem if file_path.parent.name == 'text' else None
        with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
            for line_no, line in enumerate(f, 1):
                line = line.rstrip('\r\n')
                if not line:
                    continue
                # Strip ::lcode prefix if present
                m = re.match(r'::lcode\s+([a-z]{3})\s+(.*)$', line)
                if m:
                    line_lcode, text = m.group(1), m.group(2)
                else:
                    line_lcode, text = lcode, line

                lat = Lattice(text, uroman=u, lcode=line_lcode)
                lat.pick_tibetan_vowel_edge()
                lat.prep_braille()
                lat.add_romanization()
                lat.add_numbers(u)
                lat.add_braille_numbers()
                lat.add_rom_fall_back_singles()

                for (key, edges) in list(lat.lattice.items()):
                    if isinstance(key, tuple) and len(key) == 2 and isinstance(key[0], int) and isinstance(key[1], int):
                        start, end = key
                        total_spans_checked += 1
                        if len(edges) > 1:
                            multi_edge_spans += 1
                            # Check if multiple edges share the same priority tier
                            rom_edges = []
                            decomp_edges = []
                            num_edges = []
                            other_edges = []
                            for edge in edges:
                                if isinstance(edge, NumEdge) and edge.active:
                                    num_edges.append(edge)
                                elif edge.type and edge.type.startswith('rom decomp'):
                                    decomp_edges.append(edge)
                                elif edge.type and re.match(r'(?:rom|num)', edge.type):
                                    rom_edges.append(edge)
                                else:
                                    other_edges.append(edge)

                            for tier_name, tier_edges in [('num', num_edges), ('rom', rom_edges), ('decomp', decomp_edges), ('other', other_edges)]:
                                if len(tier_edges) > 1:
                                    # Different text?
                                    distinct_texts = set(e.txt for e in tier_edges)
                                    if len(distinct_texts) > 1:
                                        ambiguous_spans.append({
                                            'file': file_path.name,
                                            'line': line_no,
                                            'span': (start, end),
                                            'orig': text[start:end],
                                            'tier': tier_name,
                                            'edges': [(e.txt, e.type) for e in tier_edges],
                                        })

    print(f'Total spans checked: {total_spans_checked:,d}')
    print(f'Multi-edge spans: {multi_edge_spans:,d}')
    print(f'Ambiguous same-tier spans with different texts: {len(ambiguous_spans)}')
    if ambiguous_spans:
        print('Samples:')
        for item in ambiguous_spans[:10]:
            print(' ', item)

    quirks_file = repo_root / 'docs' / 'upstream_quirks.md'
    print(f'Writing report to {quirks_file}...')
    with open(quirks_file, 'w', encoding='utf-8') as f:
        f.write('# Upstream Python uroman Quirks and Findings\n\n')
        f.write('This document logs known upstream Python behaviors, bugs, and edge cases discovered during the Dart port.\n\n')
        f.write('## 1. Upstream Python Bugs Identified in Source Code\n\n')
        f.write('| Line in `uroman.py` | Code snippet | Issue Description | Impact on Behavior |\n')
        f.write('|---|---|---|---|\n')
        f.write('| 1436 | `chr_script_name(prev_char) == chr_script_name(prev_char)` | Comparison of variable with itself | Always evaluates to `True`; Gurmukhi addak / Japanese small tsu condition does not verify script matching correctly. |\n')
        f.write('| 1720 | `not regex.search(\'r[aeiou]\', rom)` | Missing `r` raw-string prefix | Searches for literal character `\'r\'` followed by a vowel instead of standard word boundary or vowel check. |\n')
        f.write('| 1613 | `if n_letters == 2: cost = 0 if i == 0 else 0.1` | Uses absolute position `i` instead of relative position | Syllable-initial check in Tibetan vowel picker uses loop variable `i` (global index) instead of `rel_pos == 0`. |\n')
        f.write('| 1519 | `if rom.endswith(\' \') and ((end == len(full_string)+1) ...)` | Impossible boundary condition | `end` is bounded by `len(full_string)`, so `end == len(full_string)+1` is unreachable. |\n')
        f.write('| 2108 | `right_edge.value` in G5 fraction combination | Null dereference risk | `right_edge` can be `None` or not have `value`, causing unhandled Python `AttributeError`. |\n\n')
        f.write('## 2. Set-Order Ambiguity Analysis\n\n')
        f.write(f'- **Total spans analyzed across test fixtures**: {total_spans_checked:,d}\n')
        f.write(f'- **Multi-edge spans**: {multi_edge_spans:,d}\n')
        f.write(f'- **Same-tier competing edges with differing romanizations**: {len(ambiguous_spans)}\n\n')
        if ambiguous_spans:
            f.write('### Details of Ambiguous Spans\n\n')
            f.write('| File | Line | Span | Original Text | Tier | Competing Edges |\n')
            f.write('|---|---|---|---|---|---|\n')
            for item in ambiguous_spans:
                edges_str = ', '.join([f'"{txt}" ({typ})' for txt, typ in item['edges']])
                f.write(f"| {item['file']} | {item['line']} | {item['span']} | {item['orig']} | {item['tier']} | {edges_str} |\n")
        else:
            f.write('No ambiguous same-tier spans with differing texts were found across the standard test fixtures!\n')

    print('Done!')

if __name__ == '__main__':
    main()
