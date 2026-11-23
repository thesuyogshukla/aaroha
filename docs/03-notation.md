# 03 — Notation

Aaroha stores music as plain text in an ASCII form of Bhatkhande sargam. The same text is used in content files, in user-entered tunes and in tests. The app renders it in proper Bhatkhande style (Latin or Devanagari).

## Swars

```
S r R g G m M P d D n N
```

Lowercase = lower form: komal Re/Ga/Dha/Ni, and **shuddha** Ma (`m`). Uppercase `M` = tivra Ma. `S` and `P` have no variants.

## Octave

| Written | Meaning |
|---|---|
| `.N` | mandra Ni (dot prefix) |
| `N` | madhya Ni |
| `N'` | taar Ni (apostrophe suffix) |

The prefix/suffix applies to one swar only. `..` and `''` (two octaves away) parse, but are rejected for any flute whose range excludes them.

## Time: matras

Whitespace separates **matras** (beats). Each whitespace-separated group is exactly one matra.

Inside a matra, every character position (a swar or `-`) takes an **equal share** of the matra:

| Written | Meaning |
|---|---|
| `S R G m` | four notes, one matra each |
| `S - R -` | S for 2 matras, R for 2 matras |
| `SR G` | S and R half a matra each, then G one matra |
| `SRG` | three notes, a third of a matra each |
| `S-R` | S for 2/3, R for 1/3 of the matra |
| `SRGm` | four quarter-matra notes |

Octave markers don't take positions: `.N.D` is two half-matra notes (mandra Ni, mandra Dha).

| Symbol | Meaning |
|---|---|
| `-` | hold the previous note (Bhatkhande avagraha ऽ) for one position |
| `_` | rest (silence) for one position |
| `\|` | vibhag (section) boundary — layout and validation only |
| `\|\|` | end of avartan (cycle) |
| `,` | phrase break for pitch-only modes; no time value |

In **pitch-only modes** (v0.1–v0.2) the durations are parsed but not judged. Writing `S R G m` is enough.

## Ornaments (reserved, v0.4)

Parsed from the start so content can include them. Pitch-only modes ignore them until v0.4.

| Written | Meaning |
|---|---|
| `{N}S` | kan swar: grace note N touched just before S, takes no position |
| `G~R` | meend: glide from G to R; the two share the positions they occupy |

## Header and comments

A notation block can start with `key: value` header lines. `#` starts a comment.

```
title: Yaman — pakad
raga: yaman
taal: keherwa
tempo: 80
source: traditional
---
.N R G R | S .N R S ||
```

Known keys: `title`, `raga`, `taal`, `tempo` (matras per minute), `source`, `license`. Unknown keys are kept and ignored.

If `taal` is given, the parser checks that matras per avartan match the taal (16 for teentaal, 8 keherwa, 6 dadra, 7 rupak). Vibhag bars are checked against the taal's divisions. A mismatch is a parse error with line/column.

## Examples

```
# Alankar 1 (madhya)
S R G m P D N S'

# Bhupali aaroh, avaroh
S R G P D S' , S' D P G R S

# Bhairav fragment with komal Re and Dha
G m d - , d P , G m r - , r S

# Keherwa line with mixed durations
S - RG m | P - DP mG ||
```

## Grammar (informal)

```
block     := header* ('---')? body
header    := key ':' value NEWLINE
body      := (matra | bar | ',' | comment)*  separated by whitespace
matra     := position+
position  := ornament? (pitch | '-' | '_')
pitch     := '.'* swar "'"*
swar      := 'S'|'r'|'R'|'g'|'G'|'m'|'M'|'P'|'d'|'D'|'n'|'N'
ornament  := '{' pitch '}'
glide     := pitch '~' pitch        (counts as two positions)
bar       := '|' | '||'
comment   := '#' to end of line
```

The parser lives in `aaroha_core` (`parseNotation` / `parsePhrase`) and returns a `Phrase` (docs/02) or a list of errors with line and column. A printer (`printNotation`) turns a `Phrase` back into canonical text; `parse(print(p)) == p` is a property test over random notation. Times are exact fractions of a matra.

Rules the parser enforces beyond the grammar:
- `~` (meend) must follow a note (not a rest) and lead into a note **in the same matra**.
- A `,` phrase break can't be followed by a `-` hold. A rest right after a break starts a new rest instead of extending the one before it.
- `{…}` holds exactly one swar and must come right before a note.
- With a `taal` header, every avartan ending in `||` must have the taal's matras, and `|` bars must fall on its vibhag boundaries. Known taals: teentaal, keherwa, dadra, rupak, jhaptaal, ektaal.

## Rendering in the app

- Komal: underline. Tivra Ma: short vertical line above. Mandra: dot below. Taar: dot above.
- Each matra is one group, with a gap between groups; multi-position matras get an arc underneath (Bhatkhande convention).
- Holds render as `ऽ` (Devanagari) or `-` (Latin), in the colour of the note they hold. Rests are a faint `_`. Bars are `|` and `||`, breaks `,`.
- A phrase of one-matra notes with no rests or bars draws exactly as a plain row of swars (docs/08 M3-A). Kan and meend are not drawn yet (v0.4).
- The layout (`layoutNotation` in `aaroha_core`) is shared by the printer and the app, so text and screen always agree.
- Display modes (setting): shown, shown after attempt, hidden.
