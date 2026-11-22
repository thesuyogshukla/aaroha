# 02 — Music model

Everything musical in Aaroha is expressed relative to Sa. Hz appears only at the audio boundary (synthesis, pitch tracking) and in flute calibration.

## Swars

Twelve swars per octave. The ASCII letter is what the notation uses (see [03-notation.md](03-notation.md)).

| Swar | ASCII | Devanagari | Equal temperament (cents) | Just intonation | Just (cents) |
|---|---|---|---|---|---|
| Sa | `S` | सा | 0 | 1/1 | 0.0 |
| komal Re | `r` | <u>रे</u> | 100 | 16/15 | 111.7 |
| shuddha Re | `R` | रे | 200 | 9/8 | 203.9 |
| komal Ga | `g` | <u>ग</u> | 300 | 6/5 | 315.6 |
| shuddha Ga | `G` | ग | 400 | 5/4 | 386.3 |
| shuddha Ma | `m` | म | 500 | 4/3 | 498.0 |
| tivra Ma | `M` | म॑ | 600 | 45/32 | 590.2 |
| Pa | `P` | प | 700 | 3/2 | 702.0 |
| komal Dha | `d` | <u>ध</u> | 800 | 8/5 | 813.7 |
| shuddha Dha | `D` | ध | 900 | 5/3 | 884.4 |
| komal Ni | `n` | <u>नि</u> | 1000 | 9/5 | 1017.6 |
| shuddha Ni | `N` | नि | 1100 | 15/8 | 1088.3 |

Notes:
- Lowercase means the lower form. For Ma that is shuddha Ma (`m`); uppercase `M` is tivra Ma.
- Just intonation has more than one common value for some swars (komal Ni is also used as 16/9 = 996.1 cents). The tuning table is data, not code, so alternatives can be added.
- Ragas sometimes shade a swar (Bhairav's komal Re sits lower than Marwa's). v0.x does not model this per raga; the tolerance absorbs it. A per-raga cents override is a possible later feature.
- **Default tuning is just intonation** (a setting; equal temperament is the other choice). The call is played and attempts are judged in the chosen tuning. Just intonation fits how the owner actually plays Dha and Ni and matches the tanpura's natural intervals (decisions.md D31, superseding D9).

## Saptak (octave)

| Saptak | Notation | Cents offset |
|---|---|---|
| Mandra (lower) | prefix `.` → `.P` | −1200 |
| Madhya (middle) | none → `P` | 0 |
| Taar (upper) | suffix `'` → `P'` | +1200 |

A **pitch** in the model is `(swar, saptak)`. Its cents from Sa = `swarCents + 1200 × saptak` where saptak ∈ {−1, 0, +1}.

Converting: `hz = saHz × 2^(cents/1200)`, and `cents = 1200 × log2(hz / saHz)`.

## Flute profiles

```
FluteProfile
  id               uuid
  name             "G medium"            user-editable
  nominalKey       G                     pitch class of Sa (C, C#, … B)
  nominalSaHz      392.00                derived from key + size convention, for sanity checks only
  calibratedSaHz   389.7                 measured; this is what everything uses
  calibratedAt     timestamp
  rangeLow         .P                    lowest playable pitch
  rangeHigh        P'                    highest playable pitch
  notes            free text
```

- **Calibration** asks the player to hold Sa for ~2 seconds. The median of the stable part becomes `calibratedSaHz`. Sanity check: the pitch class must be within ±100 cents of `nominalKey`, otherwise warn ("this sounds like A, not G — wrong flute selected?"). The octave is taken from the measurement, not assumed.
- **No per-hole correction.** Individual holes on a real flute are slightly off. Correcting for that would hide intonation errors the player should hear about. Per-flute intonation is reported as stats instead (docs/05).
- **Range** defaults to `.P` → `P'` and is editable. Content generators must never ask for a pitch outside the selected flute's range.

### The owner's flutes

Nominal Sa assumes the common convention that medium flutes sit in the 4th–5th octave. Calibration measures the real value, so this table is only a starting point.

| Flute | Nominal Sa | ≈ Hz | Mandra Pa (≈ Hz) | Taar Pa (≈ Hz) |
|---|---|---|---|---|
| G medium | G4 | 392.0 | 293.7 | 1174.7 |
| A medium | A4 | 440.0 | 329.6 | 1318.5 |
| A# medium | A#4 | 466.2 | 349.2 | 1396.9 |
| B medium | B4 | 493.9 | 370.0 | 1480.0 |
| C medium | C5 | 523.3 | 392.0 | 1568.0 |
| C# medium | C#5 | 554.4 | 415.3 | 1661.2 |
| D medium | D5 | 587.3 | 440.0 | 1760.0 |
| D# medium | D#5 | 622.3 | 466.2 | 1864.7 |

So the pitch tracker needs to cover roughly **290–1900 Hz** for this set. Allow 150–2500 Hz to cover other flutes (bass flutes go lower) and calibration error.

## Drone (tanpura)

- Pitched to the flute's calibrated Sa, **one octave below** by default (the usual tanpura register relative to a medium flute). This also keeps most drone energy below the flute's range.
- First string: **Pa** by default; **Ma** for ragas without Pa or with a strong Ma; **Ni** for ragas like Marwa. Taken from raga data when a raga is selected.
- Pattern: first string, Sa, Sa, lower Sa, repeating, about one pluck per second, slightly varied timing.
- v0.1 drone is synthesized (no licensing questions). Better synthesis or licensed samples later.

## Phrases

```
Note
  pitch       (swar, saptak) or Rest
  start       in matras from phrase start (fraction)
  duration    in matras (fraction)
  ornament    none | kan(pitch) | meend(toPitch)     v0.4

Phrase
  notes       [Note]
  taal        optional: keherwa | dadra | teentaal | rupak | …
  tempo       matras per minute (optional; session setting overrides)
  source      where it came from (raga id, alankar id, composition id, generated)
```

Time inside a phrase is in matras. Converting to seconds uses the tempo: `seconds = matras × 60 / tempo`.
