#!/usr/bin/env python3
"""Extracts required Unicode tables from Python 3.13 unicodedata into lib/src/unicode/unicode_tables.g.dart."""

import json
from pathlib import Path
import re
import sys
import unicodedata as ud

sys.path.insert(0, '/private/tmp/uroman-py/uroman')
from uroman import Uroman

def build_ranges(pred):
    ranges = []
    start = None
    for cp in range(0x110000):
        if pred(chr(cp)):
            if start is None:
                start = cp
        else:
            if start is not None:
                ranges.extend([start, cp - 1])
                start = None
    if start is not None:
        ranges.extend([start, 0x10FFFF])
    return ranges

def main():
    repo_root = Path(__file__).resolve().parent.parent.parent
    out_dir = repo_root / 'lib' / 'src' / 'unicode'
    out_dir.mkdir(parents=True, exist_ok=True)
    out_file = out_dir / 'unicode_tables.g.dart'

    uroman_obj = Uroman((repo_root / 'data').resolve(), cache_size=0)

    print('Extracting general category ranges...')
    mn_ranges = build_ranges(lambda c: ud.category(c) == 'Mn')
    cf_ranges = build_ranges(lambda c: ud.category(c) == 'Cf')
    zs_ranges = build_ranges(lambda c: ud.category(c) == 'Zs')
    co_ranges = build_ranges(lambda c: ud.category(c) == 'Co')
    letter_cat_ranges = build_ranges(lambda c: ud.category(c).startswith('L'))
    mark_cat_ranges = build_ranges(lambda c: ud.category(c).startswith('M'))
    upper_cat_ranges = build_ranges(lambda c: ud.category(c) == 'Lu')
    lower_cat_ranges = build_ranges(lambda c: ud.category(c) == 'Ll')

    print('Extracting character name flags...')
    def get_name(c):
        try:
            return ud.name(c)
        except ValueError:
            return ''

    name_letter_ranges = build_ranges(lambda c: 'LETTER' in get_name(c))
    name_digit_ranges = build_ranges(lambda c: 'DIGIT' in get_name(c))

    name_subjoined = [cp for cp in range(0x110000) if 'SUBJOINED LETTER' in get_name(chr(cp))]
    name_nukta = [cp for cp in range(0x110000) if 'NUKTA' in get_name(chr(cp))]
    name_vocalic = [cp for cp in range(0x110000) if 'VOCALIC' in get_name(chr(cp))]
    name_myanmar_kayah = [cp for cp in range(0x110000) if 'MYANMAR VOWEL SIGN KAYAH' in get_name(chr(cp))]
    name_mende_kikakui = [cp for cp in range(0x110000) if 'MENDE KIKAKUI SYLLABLE' in get_name(chr(cp))]

    print('Extracting ud.numeric...')
    numeric_ints = {}
    numeric_floats = {}
    for cp in range(0x110000):
        try:
            v = ud.numeric(chr(cp))
            if v.is_integer():
                numeric_ints[cp] = int(v)
            else:
                numeric_floats[cp] = v
        except (ValueError, TypeError):
            pass

    print('Extracting decomposition tables...')
    decomp_rom = {}
    fraction_map = {}
    for cp in range(0x110000):
        c = chr(cp)
        d = ud.decomposition(c)
        if not d:
            continue
        elems = d.split()
        format_comps = []
        other_comps = []
        decomp_s = ''
        for elem in elems:
            if elem.startswith('<'):
                format_comps.append(elem)
            else:
                try:
                    decomp_s += chr(int(elem, 16))
                except ValueError:
                    other_comps.append(elem)
        if format_comps and (format_comps[0] not in ('<super>', '<sub>', '<noBreak>', '<compat>')) and not other_comps and decomp_s:
            decomp_rom[cp] = uroman_obj.romanize_string(decomp_s)

        if '<fraction>' in d:
            s = ''
            for elem in elems:
                try:
                    s += chr(int(elem, 16))
                except ValueError:
                    s += elem
            m = re.match(r'<fraction>(\d+)⁄(\d+)$', s)
            if m:
                fraction_map[cp] = [int(m.group(1)), int(m.group(2))]

    print(f'Writing {out_file}...')
    with open(out_file, 'w', encoding='utf-8') as f:
        f.write('// GENERATED FILE - DO NOT EDIT MANUALLY.\n')
        f.write('// Generated from Python 3.13 (Unicode 15.1.0) via tool/python/extract_unicode.py\n\n')
        f.write("import 'dart:typed_data';\n\n")

        def write_ranges(name, r):
            f.write(f'/// Sorted [start0, end0, start1, end1, ...] range pairs ({len(r)//2} ranges)\n')
            f.write(f'final Uint32List {name} = Uint32List.fromList([\n')
            for i in range(0, len(r), 2):
                f.write(f'  0x{r[i]:04X}, 0x{r[i+1]:04X},\n')
            f.write(']);\n\n')

        def write_set(name, items):
            f.write(f'final Set<int> {name} = {{\n')
            for item in sorted(items):
                f.write(f'  0x{item:04X},\n')
            f.write('};\n\n')

        write_ranges('mnRanges', mn_ranges)
        write_ranges('cfRanges', cf_ranges)
        write_ranges('zsRanges', zs_ranges)
        write_ranges('coRanges', co_ranges)
        write_ranges('letterCatRanges', letter_cat_ranges)
        write_ranges('markCatRanges', mark_cat_ranges)
        write_ranges('upperCatRanges', upper_cat_ranges)
        write_ranges('lowerCatRanges', lower_cat_ranges)
        write_ranges('nameLetterRanges', name_letter_ranges)
        write_ranges('nameDigitRanges', name_digit_ranges)

        write_set('nameSubjoinedSet', name_subjoined)
        write_set('nameNuktaSet', name_nukta)
        write_set('nameVocalicSet', name_vocalic)
        write_set('nameMyanmarKayahSet', name_myanmar_kayah)
        write_set('nameMendeKikakuiSet', name_mende_kikakui)

        f.write('/// Numeric int values for codepoints where ud.numeric is an integer\n')
        f.write('final Map<int, int> numericIntMap = {\n')
        for cp, v in sorted(numeric_ints.items()):
            f.write(f'  0x{cp:04X}: {v},\n')
        f.write('};\n\n')

        f.write('/// Numeric float values for codepoints where ud.numeric is non-integer\n')
        f.write('final Map<int, double> numericFloatMap = {\n')
        for cp, v in sorted(numeric_floats.items()):
            f.write(f'  0x{cp:04X}: {v},\n')
        f.write('};\n\n')

        f.write('/// Decomposition strings for decomp_rom\n')
        f.write('final Map<int, String> decompRomMap = {\n')
        for cp, s in sorted(decomp_rom.items()):
            esc = json.dumps(s).replace('$', r'\$')
            f.write(f'  0x{cp:04X}: {esc},\n')
        f.write('};\n\n')

        f.write('/// Fractions for fraction_char2fraction [numerator, denominator]\n')
        f.write('final Map<int, List<int>> fractionMap = {\n')
        for cp, pair in sorted(fraction_map.items()):
            f.write(f'  0x{cp:04X}: [{pair[0]}, {pair[1]}],\n')
        f.write('};\n')

    print(f'Done! Created {out_file} ({out_file.stat().st_size:,d} bytes)')

if __name__ == '__main__':
    main()
