# fixture_runner

Runs the native pitch tracker (host build) and the `aaroha_core` segmenter over
synthetic signals and labelled recordings. See [docs/07-test-fixtures.md](../../docs/07-test-fixtures.md).

```bash
../build_native_host.sh                       # builds build/native-host/libaaroha_audio.dylib
dart run bin/fixture_runner.dart selftest     # synthetic flute notes, with and without drone
dart run bin/fixture_runner.dart analyze take.wav --flute "G medium" --highpass
dart run bin/fixture_runner.dart check        # every labelled take in fixtures/
```
