# Aaroha

An ear-training app for Hindustani bansuri players. **Train your ear. Master your notes.**

The app plays a note or a phrase over a tanpura drone. You play it back on your flute. The app listens, tells you whether you got it right (and how far off you were), and keeps track of which notes your ear confuses. As you improve, single notes become phrases, phrases gain rhythm, and random notes give way to real material: alankars, raga phrases and compositions.

*Aaroha* means ascent, the same root as *aaroh*, the rising line of a raga. The app is built as a climb: single swars, then phrases, then rhythm and real raga material, with the ear rising a step at a time.

## Status

Planning. No code yet. Android first, iOS later, web possibly after that.

## Documents

| Doc | What it covers |
|---|---|
| [CLAUDE.md](CLAUDE.md) | Guide for the coding agent: rules, layout, how to verify work |
| [docs/01-product.md](docs/01-product.md) | Vision, principles, training modes, screens, settings |
| [docs/02-music-model.md](docs/02-music-model.md) | Swars, octaves, tuning, flute profiles, drone |
| [docs/03-notation.md](docs/03-notation.md) | The text format for Bhatkhande-style sargam |
| [docs/04-architecture.md](docs/04-architecture.md) | Flutter app + native C++ audio core, data flow, storage |
| [docs/05-evaluation.md](docs/05-evaluation.md) | How attempts are judged: pitch, phrases, rhythm, stats |
| [docs/06-content.md](docs/06-content.md) | Alankars, raga definitions, compositions, licensing |
| [docs/07-test-fixtures.md](docs/07-test-fixtures.md) | The library of real flute recordings used as ground truth |
| [docs/08-roadmap.md](docs/08-roadmap.md) | Milestones with acceptance criteria |
| [docs/decisions.md](docs/decisions.md) | Log of decisions and the reasons behind them |
