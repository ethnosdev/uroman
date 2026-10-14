#!/usr/bin/env python3
"""Dumps loaded uroman data tables to test/goldens/tables.json.gz for Phase 2 verification."""

from collections import defaultdict
import gzip
import json
import os
from pathlib import Path
import sys

# Ensure uroman from /tmp/uroman-py can be imported
sys.path.insert(0, '/tmp/uroman-py/uroman')
from uroman import Uroman

def main():
    repo_root = Path(__file__).resolve().parent.parent.parent
    data_dir = repo_root / 'data'
    out_dir = repo_root / 'test' / 'goldens'
    out_dir.mkdir(parents=True, exist_ok=True)
    out_file = out_dir / 'tables.json.gz'

    print(f'Loading uroman from {data_dir}...')
    u = Uroman(data_dir)

    bool_grouped = defaultdict(list)
    for (k, s), v in u.dict_bool.items():
        if v:
            bool_grouped[k].append(s)
    for k in bool_grouped:
        bool_grouped[k].sort()

    str_grouped = defaultdict(dict)
    for (k, s), v in u.dict_str.items():
        if v:
            str_grouped[k][s] = v

    set_grouped = defaultdict(list)
    for (k, s), v in u.dict_set.items():
        set_grouped[f'{k}:{s}'] = sorted(list(v))

    data = {
        'rom_rules': {k: [r.__dict__ for r in v] for k, v in u.rom_rules.items()},
        'scripts': {k: v.__dict__ for k, v in u.scripts.items()},
        'num_props': dict(u.num_props),
        'dict_bool': bool_grouped,
        'dict_str': str_grouped,
        'dict_int': dict(u.dict_int),
        'dict_set': set_grouped,
        'fraction_connectors': sorted(list(u.fraction_connectors.keys())),
        'minus_signs': sorted(list(u.minus_signs.keys())),
        'plus_signs': sorted(list(u.plus_signs.keys())),
    }

    raw_json = json.dumps(data, ensure_ascii=False, indent=None)
    with gzip.open(out_file, 'wb') as f:
        f.write(raw_json.encode('utf-8'))

    print(f'Wrote {len(raw_json):,d} bytes (compressed: {out_file.stat().st_size:,d} bytes) to {out_file}')

if __name__ == '__main__':
    main()
