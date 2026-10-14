#!/usr/bin/env python3
"""Generates reference golden files for all test fixtures using Python 3.13 uroman."""

import io
import os
from pathlib import Path
import subprocess
import sys

sys.path.insert(0, '/tmp/uroman-py/uroman')
from uroman import Uroman, RomFormat, Edge

def romanize_lines(uroman_obj, lines, lcode=None, rom_format=RomFormat.STR):
    """Romanizes a list of lines with exact logic matching romanize_file."""
    out_lines = []
    for line in lines:
        line_clean = line.rstrip('\r\n')
        # Check for ::lcode prefix
        import regex
        if m := regex.match(r'(::lcode\s+)([a-z]{3})(\s+)(.*)$', line_clean):
            lcode_kw, lcode2, space, snt = m.group(1, 2, 3, 4)
            res = uroman_obj.romanize_string(snt, lcode=lcode2 or lcode, rom_format=rom_format)
            if rom_format == RomFormat.STR:
                prefix = f"{lcode_kw}{lcode2}{space}"
                out_lines.append(prefix + res)
            else:
                meta = f'[0, 0, "", "lcode: {lcode2}"]'
                prefixed = [meta] + res
                out_lines.append(Edge.json_str(prefixed))
        else:
            res = uroman_obj.romanize_string(line_clean, lcode=lcode, rom_format=rom_format)
            out_lines.append(Edge.json_str(res))
    return out_lines

def main():
    repo_root = Path(__file__).resolve().parent.parent.parent
    data_dir = repo_root / 'data'
    fixtures_dir = repo_root / 'test' / 'fixtures'
    goldens_dir = repo_root / 'test' / 'goldens'

    print(f'Loading uroman from {data_dir}...')
    # Default instance (cache_size = 0, API mode)
    u_nocache = Uroman(data_dir, cache_size=0)
    # Cached instance (cache_size = 65536, CLI mode)
    u_cached = Uroman(data_dir, cache_size=65536)

    formats = [
        ('str', RomFormat.STR),
        ('edges', RomFormat.EDGES),
        ('alts', RomFormat.ALTS),
        ('lattice', RomFormat.LATTICE),
    ]

    for fmt_name, fmt_val in formats:
        fmt_dir = goldens_dir / fmt_name
        fmt_dir.mkdir(parents=True, exist_ok=True)

    print('Generating goldens for multi-script.txt...')
    multi_script_file = fixtures_dir / 'multi-script.txt'
    with open(multi_script_file, 'r', encoding='utf-8') as f:
        ms_lines = f.readlines()

    for fmt_name, fmt_val in formats:
        # cache=0
        out_lines = romanize_lines(u_nocache, ms_lines, lcode=None, rom_format=fmt_val)
        out_path = goldens_dir / fmt_name / f'multi-script.nocache.{fmt_name}'
        with open(out_path, 'w', encoding='utf-8') as f:
            f.write('\n'.join(out_lines) + '\n')

        # cache=65536
        u_cached.reset_cache(65536)
        out_lines = romanize_lines(u_cached, ms_lines, lcode=None, rom_format=fmt_val)
        out_path = goldens_dir / fmt_name / f'multi-script.cached.{fmt_name}'
        with open(out_path, 'w', encoding='utf-8') as f:
            f.write('\n'.join(out_lines) + '\n')

    text_files = sorted(list((fixtures_dir / 'text').glob('*.txt')))
    print(f'Generating goldens for {len(text_files)} language text files...')

    for tf in text_files:
        lcode = tf.stem
        with open(tf, 'r', encoding='utf-8') as f:
            tf_lines = f.readlines()

        for fmt_name, fmt_val in formats:
            # Generate with explicit lcode
            out_lines = romanize_lines(u_nocache, tf_lines, lcode=lcode, rom_format=fmt_val)
            out_path = goldens_dir / fmt_name / f'{lcode}.{fmt_name}'
            with open(out_path, 'w', encoding='utf-8') as f:
                f.write('\n'.join(out_lines) + '\n')

    print('Generating CLI test golden commands...')
    cli_goldens_dir = goldens_dir / 'cli'
    cli_goldens_dir.mkdir(parents=True, exist_ok=True)

    cli_tests = [
        ('direct_single', ['Игорь Стравинский'], {}),
        ('direct_with_lcode', ['Игорь'], {'-l': 'ukr'}),
        ('direct_greek', ['Ντέιβις Καπ'], {'-l': 'ell'}),
        ('direct_unicode_decode', [r'\u03C0\u03B9'], {'-d': ''}),
        ('direct_edges', ['ちょっとまってください'], {'-f': 'edges'}),
        ('direct_alts', ['ちょっとまってください'], {'-f': 'alts'}),
        ('direct_lattice', ['महात्मा गांधी'], {'-f': 'lattice'}),
        ('file_hindi_max_lines', [], {'-i': str(fixtures_dir / 'text' / 'hin.txt'), '-l': 'hin', '--max_lines': '5'}),
        ('file_multi_script', [], {'-i': str(multi_script_file)}),
    ]

    import json
    cli_results = {}
    uroman_script = '/tmp/uroman-py/uroman/uroman.py'

    for test_name, pos_args, flags in cli_tests:
        cmd = [sys.executable, uroman_script, '--data_dir', str(data_dir)]
        for k, v in flags.items():
            cmd.append(k)
            if v:
                cmd.append(v)
        cmd.extend(pos_args)

        proc = subprocess.run(cmd, capture_output=True, text=True, encoding='utf-8')
        cli_results[test_name] = {
            'args': pos_args,
            'flags': flags,
            'stdout': proc.stdout,
            'exit_code': proc.returncode,
        }

    with open(cli_goldens_dir / 'cli_cases.json', 'w', encoding='utf-8') as f:
        json.dump(cli_results, f, ensure_ascii=False, indent=2)

    print('Finished generating all goldens!')

if __name__ == '__main__':
    main()
