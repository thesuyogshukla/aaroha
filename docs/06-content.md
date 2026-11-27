# 06 — Content

Training material, stored as data files in `content/` and bundled as Flutter assets. All of it is written in sargam relative to Sa (docs/03), so it works on every flute. Generators must keep output within the selected flute's range.

## Sources and licensing

| Kind | Shipped with app? | Rule |
|---|---|---|
| Alankars / paltas | Yes | Generated; traditional exercises |
| Raga facts (aaroh, avaroh, pakad, vadi…) | Yes | Traditional musical knowledge, written in our own words/format |
| Traditional bandish / gat | Yes, if public domain | Old published notation (e.g. Bhatkhande's Kramik Pustak Malika, out of copyright) — record the source in the file |
| Film songs, modern compositions, other people's arrangements | **No** | Only ever user-entered, stored locally |

Every content file has `source` and `license` fields. A CI check (M5) fails if any shipped file lacks them.

## Alankars

Defined as a pattern applied to a scale, not as fixed notes, so one definition works for any swar set (shuddha, a raga's aaroh, etc.).

```yaml
# content/alankars/basic.yaml
- id: alankar-1
  name: Straight
  pattern: [0]                 # each scale degree once, up then down
- id: alankar-2
  name: Pairs
  pattern: [0, 0]              # S S, R R, G G …
- id: alankar-3
  name: Groups of three
  pattern: [0, 1, 2]           # S R G, R G m, G m P …
- id: alankar-4
  name: Up two, back one
  pattern: [0, 1, 0]           # S R S, R G R …
- id: alankar-5
  name: Groups of four
  pattern: [0, 1, 2, 3]
```

As built (M2-D), `content/alankars/basic.yaml` has seven: Straight `[0]`, Pairs `[0, 0]`, Skip one `[0, 2]`, Step and back `[0, 1, 0]`, Groups of three `[0, 1, 2]`, Three and back `[0, 1, 2, 1]`, Groups of four `[0, 1, 2, 3]`.

`pattern` holds offsets in scale degrees from each starting degree. The generator walks the starting degree up the scale (aaroh) and mirrors the pattern on the way down (avaroh), stopping at the flute's range. Optional `rhythm` field later (e.g. `[1/2, 1/2]` per group).

As built: the degrees are the scale's swars in the chosen saptaks plus the Sa above the top one, clipped to the flute's range. On a raga, the walk goes up the aaroh's swars and down the avaroh's. Only the notes that keep rising (or falling) between Sa and taar Sa count, so a vakra turn such as Des's `R G .N S` doesn't add Ni to the descent. Each round holds whole groups, up to the phrase level's length (4 notes at level 1), spread evenly, and never mixes the way up with the way down. One walk up and down is the session, so the Rounds setting doesn't apply.

## Raga definitions

```yaml
# content/ragas/yaman.yaml
id: yaman
name: Yaman
name_dev: यमन
thaat: kalyan
swars: [S, R, G, M, P, D, N]    # M = tivra Ma
aaroh: ".N R G M D N S'"
avaroh: "S' N D P M G R S"
pakad: [".N R G R , S , P M G R , S"]
vadi: G
samvadi: N
nyas: [G, P, N, R]
avoid: []                     # vivadi swars / forbidden movements, see below
drone: P                      # tanpura first string: P | m | N
time: "first quarter of the night"
chalan:                        # characteristic phrases, used for drills and as generator seeds
  - ".N R G"
  - "G M D N"
  - "M D N S'"
  - "N D P , M G R S"
source: traditional
license: public-domain
```

**Phrase rules for generation (v0.4)** extend this with:
- `allowedTransitions`: which swar may follow which, ascending and descending separately (raga movement is often different up vs down).
- `avoidPhrases`: phrases that would make it sound like another raga.
- `weights`: preferred notes (vadi/samvadi/nyas) and preferred resting points.

The generator is a constrained random walk (a Markov chain built from `chalan` + transitions), ending on a nyas swar, length within the requested range, inside flute range. Every generated phrase is checked against `avoidPhrases`. Output is ordinary notation, so it is judged like any other phrase.

### Starter set (v0.2)

Chosen to cover common thaats and be easy to verify:

| Raga | Why |
|---|---|
| Bhupali | Pentatonic, all shuddha — easiest start |
| Yaman | Tivra Ma, foundational |
| Bilawal | All shuddha (major scale) |
| Kafi | Komal Ga and Ni |
| Bhairav | Komal Re and Dha |
| Durga | Pentatonic, different shape from Bhupali |
| Khamaj | Both Ni |
| Des | Common light-classical raga, different aaroh and avaroh |

**Raga practice as built (M2-D):** a session opens with the aaroh, then the avaroh, then plays the pakad and chalan phrases (and the aaroh and avaroh again) at random, never the same phrase twice in a row. Phrases are cut to the phrase level's length (docs/05 §9): at its `,` breaks first, then into near-equal pieces that share a note. Phrases outside the flute's range are left out. Phrases may be written with durations (docs/03); the call then plays them as written, and cut pieces keep their timing (M3-A, D43). The tanpura's first string follows the raga's `drone`, also when an alankar is walked on that raga.

**Bundling:** Flutter only bundles assets inside the app's folder and silently skips `../` paths, so `app/content` is a symlink to this `content/` folder. Core tests read the files directly. Both parse every raga file, and the core tests check that each phrase fits a medium flute (mandra Pa to taar Pa).

The owner reviews each raga file before it ships. Raga facts vary slightly between gharanas; the file records the chosen version in `notes`.

## Compositions

```yaml
# content/compositions/yaman-gat-1.yaml
id: yaman-gat-1
title: Yaman — madhya laya gat
raga: yaman
taal: teentaal
tempo: 120
source: "<book, page>"
license: public-domain
lines:
  - "…"      # one avartan per line, notation per docs/03
```

User-entered tunes use the same shape, stored in the database rather than files, with `license: user-private`.

## Rhythm lessons

```yaml
# content/rhythm/keherwa.yaml
taal: keherwa
source: original, written for Aaroha
license: original
lessons:
  - id: keherwa-1
    name: Steps and holds
    phrases:
      - "S R G m"
      - "S - R -"
      …
```

As built (M3-E, D53): one file per taal, `keherwa.yaml` (steps and holds, holds across the avartan, two swars in a matra, rests, repeated swars, alankars in rhythm) and `dadra.yaml` (steps and holds, two swars in a matra), 60 phrases in all, written for Aaroha. Each phrase is one vibhag or one avartan, ends on a vibhag (checked against the taal), and has at least two notes. They move mostly by step between madhya Sa and Pa, so the attention goes on the timing. A session plays its lesson's phrases in order, then at random without the same one twice in a row. Phrases aren't cut to the phrase level: their length is part of the rhythm. Teentaal and rupak lessons come next.

## Content for each mode

| Mode | Content |
|---|---|
| Single swar | allowed swar set (from preset or raga) + range |
| Short phrase | random walk over the swar set with small steps, or raga chalan fragments |
| Alankar | alankar × swar set |
| Raga | aaroh, avaroh, pakad, chalan; then generated phrases |
| Rhythm | rhythm lessons (keherwa, dadra), including alankars in rhythm; composition lines later |
| Composition | full lines, one at a time, then whole avartans |
