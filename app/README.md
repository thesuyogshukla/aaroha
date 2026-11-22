# Aaroha app

Flutter app (Android first). For milestone M0 it is a single debug screen:
live pitch readout, tanpura drone, Sa calibration and raw recording for
fixtures. See [docs/08-roadmap.md](../docs/08-roadmap.md).

```bash
flutter run            # with an Android phone connected
flutter build apk --debug
```

`android/gradle.properties` pins Gradle to the Homebrew JDK 17
(decisions.md D18).
