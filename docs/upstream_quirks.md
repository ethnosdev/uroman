# Upstream Python uroman Quirks and Findings

This document logs known upstream Python behaviors, bugs, and edge cases discovered during the Dart port.

## 1. Upstream Python Bugs Identified in Source Code

| Line in `uroman.py` | Code snippet | Issue Description | Impact on Behavior |
|---|---|---|---|
| 1436 | `chr_script_name(prev_char) == chr_script_name(prev_char)` | Comparison of variable with itself | Always evaluates to `True`; Gurmukhi addak / Japanese small tsu condition does not verify script matching correctly. |
| 1720 | `not regex.search('r[aeiou]', rom)` | Missing `r` raw-string prefix | Searches for literal character `'r'` followed by a vowel instead of standard word boundary or vowel check. |
| 1613 | `if n_letters == 2: cost = 0 if i == 0 else 0.1` | Uses absolute position `i` instead of relative position | Syllable-initial check in Tibetan vowel picker uses loop variable `i` (global index) instead of `rel_pos == 0`. |
| 1519 | `if rom.endswith(' ') and ((end == len(full_string)+1) ...)` | Impossible boundary condition | `end` is bounded by `len(full_string)`, so `end == len(full_string)+1` is unreachable. |
| 2108 | `right_edge.value` in G5 fraction combination | Null dereference risk | `right_edge` can be `None` or not have `value`, causing unhandled Python `AttributeError`. |

## 2. Set-Order Ambiguity Analysis

- **Total spans analyzed across test fixtures**: 26,056
- **Multi-edge spans**: 43
- **Same-tier competing edges with differing romanizations**: 0

No ambiguous same-tier spans with differing texts were found across the standard test fixtures!
