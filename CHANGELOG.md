# Changelog

All notable changes to **tunes**. Versions follow [semver](https://semver.org/).

## 2.2.0

### Added
- **Sleep timer** — `tunes sleep 30m|1h30m|90s|45`, `sleep status`, `sleep off`. The volume fades over the last 15 s, then playback stops.
- **Alarm** — `tunes alarm 07:30 [playlist|mix]`, `alarm status`, `alarm off`.
- **Smart playlists from stats** — `tunes top [period] [-n N] --save NAME` and `tunes forgotten [days] [--min-plays N] [--save NAME]` (favourites you haven't played lately).
- **Playlist import / export** — `tunes playlist export <name> [file.m3u]` and `tunes playlist import <file.m3u|.m3u8|list.txt> [name]` (relative paths, CRLF and comments handled).
- **ListenBrainz scrobbling** — `tunes scrobble [--dry-run] [--all]`; uses the same play-counting rule as reports and remembers where it stopped.
- **`tunes backup [dir]` / `tunes restore <archive>`** — keeps the newest 10 backups; restore refuses unsafe archive paths; config (API keys/tokens) is never archived.
- **`tunes update [--check] [-y]`** — downloads the published script, verifies it, keeps a `.bak`.
- **`tunes local [folder]`** — browse and play audio files from `MUSIC_DIR` (default `~/Music`).
- **`tunes report --card`** — short plain-text summary for sharing.
- **Custom audio chains** (`AUDIO_PRESET=custom` + `AUDIO_CUSTOM_AF`) and **`REPLAYGAIN=track|album`**.
- New config keys: `AUDIO_CUSTOM_AF`, `REPLAYGAIN`, `MUSIC_DIR`, `LISTENBRAINZ_TOKEN` (masked in `tunes config`), `LISTENBRAINZ_URL`.
- GitHub Actions workflow (syntax check, `shellcheck`, full integration suite).
- Tests for autoplay / Up Next, every enhancement preset, and all of the above (105 → 244 checks).

### Changed
- **Audio enhancement is now opt-in** (`AUDIO_ENHANCE` defaults to `off`). If you liked the old behaviour, run `tunes config set AUDIO_ENHANCE on`.
- `crystalizer`-based presets now end in a peak limiter (`alimiter`) so the added dynamics cannot clip.
- Enhancement wording is honest about what the filters do (the old "restoration"/"bit-perfect" claims are gone).
- README documents autoplay, audio quality/enhancement, download formats and every config key; the `YT_CLIENT` default is now listed correctly (empty).

### Removed
- mpv flags that had no effect for audio playback: `--audio-resample-linear`, `--audio-resample-cutoff`, `--audio-pitch-correction` (the latter two were already defaults). The 32-point resampler filter, gapless playback, `--volume-max=100` and the audio buffer stay.

## 2.1.0
- Autoplay / Up Next (`tunes autoplay`, `tunes upnext`).
- Audio enhancement presets and 48 kHz Opus streaming (`AUDIO_QUALITY`, `AUDIO_ENHANCE`, `AUDIO_PRESET`, `DOWNLOAD_FORMAT`).

## 2.0.0
- Play-count tracking, `stats` / `report` / `top` / `mix` / `ask`, home menu, `add`, local LLM support (Ollama and OpenAI-compatible), weekly report reminder, `doctor` / `config` / `ai`, and many bug fixes — see the README's "What changed in 2.0".
