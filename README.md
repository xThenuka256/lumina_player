# Lumina Player

Cross-platform **Liquid Glass** local music player targeting **Android 11+ (API 30+)** and **Linux (x86_64)**, built with Flutter, `media_kit`, `audio_service`, Riverpod, and SQLite.

## Highlights
- **Liquid Glass UI & Dynamic Mesh Background:** Extracts palette colors from active album artwork via `ColorScheme.fromImageProvider` to drive a multi-layered animated mesh gradient behind translucent `BackdropFilter` surfaces.
- **Audio Engine & OS Integration:**
  - `media_kit` (`libmpv`) gapless queue playback, speed control (`0.5x–2.0x`), shuffle, repeat (`off` / `all` / `one`), and sleep timer.
  - **Android 11–15+:** `READ_MEDIA_AUDIO` / scoped `READ_EXTERNAL_STORAGE` (`maxSdkVersion="32"`), `MediaStore` + SAF (`DocumentFile`) scanning, foreground `mediaPlayback` service, and Quick Settings media resumption.
  - **Linux x86_64:** `audio_service_mpris` D-Bus MPRIS integration and automatic `XDG_MUSIC_DIR` discovery.
- **CI/CD Packaging:** `.github/workflows/build-release.yml` automatically builds split & universal `.apk` files and a Debian `.deb` installer.
