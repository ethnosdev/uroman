# Upstream Python uroman Quirks and Findings

This document logs known upstream Python behaviors, bugs, and edge cases discovered during the Dart port.

## 1. Upstream Python Bugs Identified in Source Code

| Line in `uroman.py` | Code snippet | Issue Description | Impact on Behavior |
|---|---|---|---|
| 1436 | `chr_script_name(prev_char) == chr_script_name(prev_char)` | Comparison of variable with itself | Always evaluates to `True`; Gurmukhi addak / Japanese small tsu condition does not verify script matching correctly. |
| 1720 | `not regex.search('r[aeiou]', rom)` | Missing `r` raw-string prefix | Searches for literal character `'r'` followed by a vowel instead of standard word boundary or vowel check. |
| 1613 | `if n_letters == 2: cost = 0 if i == 0 else 0.1` | Uses absolute position `i` instead of relative position | Syllable-initial check in Tibetan vowel picker uses loop variable `i` (global index) instead of `rel_pos == 0`. |
| 1519 | `if rom.endswith(' ') and ((end == len(full_string)+1) ...)` | Impossible boundary condition | `end` is bounded by `len(full_string)`, so `end == len(full_string)+1` is unreachable. |
| 174 | `if not (value in (None, [], False)):` | Python `bool` is subclass of `int`, so `0 == False` is True | Drops `num: 0` from `self.__dict__` on `RomRule` (e.g. Klingon 0, Chinese 0). |
| 358 | `any_not_none(t, num, is_minus_sign, ...)` | `is_minus_sign` is boolean `False` (not `None`) | `any_not_none` is unconditionally `True` for every line with `s`. Combined with line 746 `:::t W` (3 colons typo, causing `t` to be `None`), creates `RomRule(s='Ⴣ', t=None, prov='man')` overwriting the valid `ud` rule. Same for lines 708, 759, 778. |
| 861 | `if name := self.dict_str[('name', char)]:` | `defaultdict(str)` creates missing keys with value `''` | Inserting dummy `('name', '፡ '): ''` and `('name', ''): ''` keys during `second_rom_filter`. |
| 2314 | `if old_end2 >= end2: end2 -= 1` | `end2` is `new_edge.start <= old_end2` | In `find_rom_edge_path_backwards`, `old_end2 >= end2` is unconditionally true when an edge is found, which extra-decrements `end2` by 1 at each step, causing it to skip the immediate left vertex. |

## 2. Set-Order Ambiguity Analysis

- **Total spans analyzed across test fixtures**: 26,056
- **Multi-edge spans**: 43
- **Same-tier competing edges with differing romanizations**: 0

No ambiguous same-tier spans with differing texts were found across the standard test fixtures!
