# 🎵 tunes

> **A very lightweight, terminal-based "Spotify": search, stream, queue, download, and manage music & podcasts — and see exactly what you listen to.**
> One bash script. Powered by `mpv`, `yt-dlp`, `fzf` and `python3`. Optional local AI (Ollama, llama.cpp, LM Studio, …) that never leaves your machine.

```
$ tunes                      # interactive menu
$ tunes search "nils frahm"  # find & play
$ tunes report --ai          # your week in music, plus a written take from your local LLM
```

---

## ✨ Features

**Play**
- 🎧 Instant YouTube audio streaming — no browser, no bloat
- 🎛 Interactive **home menu** (`tunes` with no arguments) — browse everything with fuzzy search
- 🔀 Multi-select queues (`TAB`), shuffle, loop, **add to the running queue** (`tunes add`)
- 🎲 **Personal mix** built from your favourites and most-played tracks (`tunes mix`)
- 🚀 Background playback with a full remote control (`tunes ctl …`) — new playback replaces the old
- 📁 Playlists, favourites, history, mp3 downloads with cover art & tags, synced lyrics (via `sptlrx`)
- 🎙 Podcasts: iTunes directory search or any RSS URL, auto-resume, offline downloads
- 🔔 GNOME / desktop integration: MPRIS2 widget, media keys, actionable notifications
- ♾ **Autoplay / Up Next** — when the queue runs out, tunes appends similar tracks (`tunes autoplay`, `tunes upnext`)
- 😴 **Sleep timer** (fades out, then stops) and ⏰ **alarm** (wakes you with a playlist or your mix)
- 📁 **Local library**: `tunes local` browses and plays audio files from your music folder

**Know your listening**
- 📈 **Every listening session is logged locally** — a *play* counts after 30 s (or half of a short track), shorter sessions count as *skips*
- 🔥 **Per-track play counts**, top artists, skip rate, listening time, streaks, busiest day, time-of-day & weekday patterns, new-vs-familiar discovery
- 📰 **Reports for any period** — last week (default), month, year, a custom range — with change vs. the previous period
- 🤖 **AI take on your report** and **"ask anything" about your habits** via your own local LLM
- 🏆 `tunes top` — browse and replay your most-played tracks, ranked by plays
- 💾 Save reports, get a desktop notification, export raw JSON, or schedule it weekly
- 🧠 **Smart playlists from your stats**: `tunes top month --save "October favs"`, `tunes forgotten` (old favourites you haven't played in 90 days)
- 📣 **Shareable report card**: `tunes report --card` prints a short text summary you can paste anywhere
- 🔄 **ListenBrainz scrobbling** (`tunes scrobble`) — keep your history if you ever switch players

**Library & upkeep**
- 📤 Playlist **export / import** as M3U (`tunes playlist export|import`)
- 💼 `tunes backup` / `tunes restore` for your play log, favourites, playlists and podcasts
- ⬆️ `tunes update` fetches the latest script from GitHub (checks it first, keeps a `.bak`)

**AI (all optional, all local)**
- 🌦 `tunes mood "rainy day lofi for coding"` → the model writes search queries and builds a queue
- ✨ Recommendations from your most-played + recent tracks; podcast episode ranking
- Works with **Ollama** *or* any **OpenAI-compatible** server (llama.cpp `llama-server`, LM Studio, vLLM, …)

---

## 🚀 Install

```bash
git clone https://github.com/MelancholicMuser/tunes.git
cd tunes
./install.sh          # installs to ~/.local/bin and checks your setup
```

Manual: `cp tunes ~/.local/bin/ && chmod +x ~/.local/bin/tunes` (make sure `~/.local/bin` is on your `PATH`).
Remove with `./install.sh --uninstall` (your data is kept).

Optional tab-completion: `echo 'eval "$(tunes completion)"' >> ~/.bashrc`

Run **`tunes doctor`** any time to see what's installed and what's missing (with install commands for your package manager).

### Dependencies

| Required | Used for |
| :--- | :--- |
| `bash` 4.4+ | the script itself |
| `mpv` | playback engine |
| `yt-dlp` | search & stream extraction |
| `fzf` | all pickers and the menu |
| `python3` | stats engine, IPC, RSS (standard library only) |
| `curl`, `jq` | network calls, JSON |

| Optional | Used for |
| :--- | :--- |
| `ffmpeg` | mp3 downloads |
| `notify-send` (libnotify), `mpv-mpris` | desktop notifications / MPRIS widget |
| `playerctl` | hardware media keys |
| `sptlrx` | synced lyrics |
| `vlc` | `tunes vlc` |
| a local LLM server | AI features |

`tunes help`, `tunes stats`, `tunes report` and `tunes config` work even if the playback tools aren't installed.

---

## 📈 Listening stats & reports

Tracking is automatic: a tiny mpv script records each listening session (when it started, how many seconds you *actually* listened — seeks don't inflate it — and the track) to `~/.local/share/tunes/plays.tsv`. Looping a track counts each loop as a new play. Different URL forms of the same YouTube video are merged.

```
$ tunes report
🎧 Tunes Weekly Report  last 7 days  ·  Oct 04 → Oct 11, 2026

 ▸ 23 plays · 1h 33m listened · 6 unique tracks · 5 artists
 ▸ Skip rate 15% (4 of 27 starts)
 ▸ vs previous period: plays +0% · time -9%
 ▸ Streak: 11 days (best: 11)

🔥 Most played
  1. lofi hip hop radio — Lofi Girl                                ×6 · 22m
  2. Kesariya — Arijit Singh                                       ×5 · 21m
  3. Blinding Lights — The Weeknd                                  ×5 · 15m
  …
🎤 Top artists
  1. Arijit Singh                                         ×9 · 2 tracks
  …
📅 By weekday   🕒 Time of day   ✨ Discovery   ⏭ Often skipped   🎙 Podcasts
```

| Command | What it does |
| :--- | :--- |
| `tunes stats [period]` | Dashboard: totals, top tracks & artists, skip rate, streak, library size (default: all time) |
| `tunes report [period]` | Full report with patterns, discovery and comparison to the previous period (default: last 7 days) |
| `tunes report --ai` | …plus a short written analysis from your local LLM |
| `tunes report --save` | …and keep a copy in `~/.local/share/tunes/reports/` |
| `tunes report --notify` | …and send a desktop notification with the headline numbers |
| `tunes report --json` / `tunes stats --json` | Raw numbers for your own scripts |
| `tunes ask "…"` | Ask the LLM about your habits: *"what do I listen to late at night?"* |
| `tunes top [period]` | Browse & play your most-played tracks (`TAB` to queue several) |
| `tunes top [period] --save NAME [-n N]` | Save your most-played tracks as a playlist instead of playing them |
| `tunes forgotten [days]` | Tracks you played ≥3 times but not in the last N days (default 90) · `--min-plays N` · `--save NAME` |
| `tunes report --card` | A short plain-text summary (plays, time, top track & artist, streak) to share |
| `tunes mix [N]` | Shuffle N tracks (default 25) from favourites + most played |

**Periods:** `today` · `yesterday` · `week` · `month` · `year` · `all` · `14d` · `8w` · `2026-10-01` (since) · `2026-09` (that month)

The AI never does the maths: numbers are computed by the stats engine and only a compact digest is sent to the model, with instructions to use nothing else.

### Weekly reports, automatically

- **Nudge:** the home menu shows *"📰 Your weekly report is ready"* when a week has passed since you last looked (turn off: `tunes config set REPORT_REMINDER off`).
- **Scheduled** (cron, every Monday 09:00 — the `DBUS` variable lets the notification reach your desktop):
  ```cron
  0 9 * * 1  DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus tunes report --ai --save --notify
  ```
- **systemd user timer:** a `tunes-report.service` running `tunes report --ai --save --notify` plus a `tunes-report.timer` with `OnCalendar=Mon 09:00` and `Persistent=true`.

---

## ♾ Autoplay & Up Next

When the last track of a queue starts, tunes asks YouTube for a radio mix of that track (falling back to a keyword search) and appends a handful of new tracks, skipping anything already queued.

```bash
tunes autoplay on|off|toggle|status   # works live, even while something is playing
tunes upnext                          # see and interact with the upcoming queue
```

## 🎚 Audio quality & optional enhancement

- `AUDIO_QUALITY` chooses the stream format: `highest` (prefers Opus, 48 kHz — the default), `high`, or `standard` (≤128 kbps).
- `DOWNLOAD_FORMAT` (`best` = keep the original stream untouched, or `flac` / `opus` / `mp3` / `m4a` / `wav`) controls `tunes download`.
- **Enhancement is off by default.** Turn it on with `tunes enhance on`, pick a preset with `tunes enhance <preset>`, or toggle it live from the menu:

| Preset | What it does |
| :--- | :--- |
| `crystalizer` | Sharpens transients and widens dynamics (ffmpeg `crystalizer`); can sound harsh on already-loud masters |
| `clarity` | Crystalizer plus a presence boost around 3 kHz |
| `warm` / `bass` | Crystalizer plus a low-shelf boost |
| `spatial` | Crystalizer plus mild stereo widening |
| `norm` | EBU R128 loudness normalisation (no more volume jumps between tracks) |
| `studio` | No filters |
| `custom` | Your own chain: `tunes config set AUDIO_CUSTOM_AF 'equalizer=f=100:t=q:w=1:g=3'` |

All crystalizer-based presets end in a peak limiter so the extra dynamics can't clip. `REPLAYGAIN=track|album` makes mpv honour ReplayGain tags (local files and downloads).

## 😴 Timers

```bash
tunes sleep 30m            # also: 1h30m, 90s, or a bare number of minutes
tunes sleep status | off   # the volume fades over the last 15 s, then playback stops
tunes alarm 07:30          # starts your mix at 07:30 (tomorrow if that time has passed)
tunes alarm 07:30 Morning  # …or the playlist called "Morning"
tunes alarm status | off
```

The timers run as small background helpers, so they only fire while your machine is awake and logged in.

## 📤 Playlists: import, export & smart playlists

```bash
tunes playlist export Morning ~/morning.m3u     # extended M3U with titles
tunes playlist import ~/morning.m3u Morning     # also accepts .m3u8 or a plain list of URLs/paths
tunes top month --save "October favs"           # playlists built from your own stats
tunes forgotten 60 --save "Bring these back"
```

## 🔄 ListenBrainz scrobbling

```bash
tunes config set LISTENBRAINZ_TOKEN <your token>   # from https://listenbrainz.org/settings/
tunes scrobble --dry-run                           # see what would be sent
tunes scrobble                                     # submit new plays (only those that count as plays)
```

Only music plays that pass the same 30-second / half-a-track rule as your reports are sent (podcasts and plays without an artist are skipped). tunes remembers where it stopped, so re-running is safe; `--all` re-sends everything. Run it from cron if you want it automatic. `LISTENBRAINZ_URL` can point at a compatible server.

## 💼 Backup, restore & update

```bash
tunes backup [dir]          # tar.gz of play log, history, favourites, playlists, podcasts, reports (newest 10 kept)
tunes restore <archive>     # asks first; refuses archives with unsafe paths
tunes update --check        # compare with the published version
tunes update                # download, sanity-check, install (previous version kept as tunes.bak)
```

Backups never include your config file, so API keys and tokens stay out of archives. `tunes update` downloads over HTTPS from this repository and verifies the file looks like a valid tunes script before replacing anything; if you prefer, update with `git pull && ./install.sh` instead.

---

## 🤖 Connect a local LLM

```bash
tunes ai setup      # guided: backend, URL, model → tests the connection
tunes ai test       # check server, model, and a tiny test prompt
tunes ai models     # list models on the server
```

| Backend | Typical URL | Notes |
| :--- | :--- | :--- |
| `ollama` (default) | `http://localhost:11434` | `ollama pull llama3.2:3b` |
| `openai` | `http://localhost:8080` (llama.cpp) · `:1234` (LM Studio) | any OpenAI-compatible `/v1/chat/completions` server; optional API key |

Reasoning models that emit `<think>…</think>` are handled (the thinking is stripped). Small models on CPU can be slow — raise `LLM_TIMEOUT` (default 120 s). If no model is reachable, everything still works: `mood` falls back to plain search, reports print without the AI section.

---

## ⚙️ Configuration

`tunes config` shows the current settings; `tunes config set KEY VALUE` changes one; `tunes config edit` opens the file (`~/.config/tunes/config`, plain `KEY=VALUE`, never executed, kept private with mode 600). Environment variables override the file.

| Setting | Default | Meaning |
| :--- | :--- | :--- |
| `LLM_BACKEND` | `ollama` | `ollama` or `openai` (any OpenAI-compatible server) |
| `LLM_URL` | per backend | server address (a trailing `/v1` is fine) |
| `LLM_MODEL` | `llama3.2:3b` | model name |
| `LLM_API_KEY` | *(empty)* | bearer token for servers that need one |
| `LLM_TIMEOUT` | `120` | seconds to wait for the model |
| `PLAY_THRESHOLD` | `30` | seconds of listening that count as a play |
| `REPORT_REMINDER` | `on` | weekly nudge in the home menu |
| `DEFAULT_VOLUME` | *(mpv default)* | start volume, e.g. `70` |
| `YT_CLIENT` | *(empty)* | YouTube client passed to yt-dlp; leave empty to let yt-dlp choose, or set e.g. `android` if streams ever fail |
| `AUTOPLAY` | `on` | append similar tracks when a queue ends |
| `AUDIO_QUALITY` | `highest` | `highest` · `high` · `standard` |
| `AUDIO_ENHANCE` | `off` | `on` applies the `AUDIO_PRESET` filters |
| `AUDIO_PRESET` | `crystalizer` | `crystalizer` · `clarity` · `warm` · `bass` · `spatial` · `norm` · `studio` · `custom` |
| `AUDIO_CUSTOM_AF` | *(empty)* | filter chain used by the `custom` preset |
| `REPLAYGAIN` | `off` | `track` or `album` to use ReplayGain tags |
| `DOWNLOAD_FORMAT` | `best` | `best` · `flac` · `opus` · `mp3` · `m4a` · `wav` |
| `MUSIC_DIR` | `~/Music` | folder browsed by `tunes local` |
| `LISTENBRAINZ_TOKEN` | *(empty)* | user token for `tunes scrobble` (masked in `tunes config`) |
| `LISTENBRAINZ_URL` | `https://api.listenbrainz.org` | scrobbling endpoint |

The legacy `OLLAMA_URL` / `OLLAMA_MODEL` variables still work.

---

## 📖 Command reference

Run `tunes help` for the full list. Highlights:

```
tunes                       interactive menu
tunes search|bg|queue|video [query]     (multi-word queries need no quotes)
tunes play <url|path>       tunes add [query]        tunes mix [N]        tunes top [period] [--save NAME]
tunes local [folder]        tunes forgotten [days]   tunes autoplay|upnext
tunes history | favorites | fav-add | fav-remove
tunes playlist {list|create|add|play|view|remove|delete|export|import} [name]   ('add <name> --now' = save what's playing)
tunes ctl pause|play|stop|next|prev|mute|loop-toggle|vol <0-100>|seek <±sec>|speed <rate>|queue|jump <n>
tunes status | np | notify
tunes pod | pod-add | pod-add-url | pod-feeds | pod-history | pod-download | pod-remove
tunes mood [vibe] | recommend music|podcast
tunes stats | report [--card] | ask | ai | config | doctor
tunes sleep <30m|off|status>   tunes alarm <HH:MM> [playlist]   tunes scrobble   tunes backup|restore   tunes update

Flags (before the command):  -d/--bg  background · -l/--loop · -s/--shuffle · -v/--version
```

---

## 🗂 Where things live

| Path | Contents |
| :--- | :--- |
| `~/.local/share/tunes/plays.tsv` | **play log**: `epoch ⇥ kind ⇥ seconds_listened ⇥ duration ⇥ title ⇥ artist ⇥ url` |
| `…/history.tsv`, `favorites.tsv` | recent (unique) tracks, favourites (`title ⇥ url`) |
| `…/playlists/*.tsv` | saved playlists |
| `…/feeds.tsv`, `podcast_history.tsv` | podcast subscriptions & history |
| `…/reports/` | reports saved with `--save` |
| `…/backups/` | archives made by `tunes backup` |
| `…/.listenbrainz_cursor` | timestamp of the last scrobbled play |
| `~/.config/tunes/config` | settings |
| `~/Music/tunes-downloads/` | downloads |
| `$XDG_RUNTIME_DIR/tunes-mpv-<uid>.sock` | mpv control socket |

**Privacy:** everything stays on your machine. The play log is a plain text file you can read, back up, edit, or delete; the only network traffic is the music/podcast fetching itself and, if you enable it, requests to *your own* LLM server. Plays in VLC (`tunes vlc`) are not tracked.

Override locations with `TUNES_DATA_DIR`, `TUNES_CONFIG`, `TUNES_DOWNLOAD_DIR`.

---

## 🧪 Tests

```bash
tests/run.sh            # ~4 minutes; needs mpv, fzf, jq, python3, curl
```

The suite plays real audio through `mpv` (null output) and uses mock `yt-dlp`, mock `fzf`, a fake LLM server (Ollama + OpenAI protocols) and a fake ListenBrainz server — no network or TTY needed. It runs on every push via GitHub Actions together with `shellcheck`.

---

## 🆕 What's new in 2.2

Sleep timer & alarm, smart playlists (`top --save`, `forgotten`), M3U import/export, ListenBrainz scrobbling, `backup`/`restore`/`update`, `tunes local`, `report --card`, custom EQ chains and ReplayGain. Audio enhancement is now **opt-in** and its presets end in a limiter. See [CHANGELOG.md](CHANGELOG.md) for details.

## 🆕 What changed in 2.0

**New:** running `tunes` with no arguments now opens the menu (`tunes help` for the help text), play-count tracking, `stats`/`report`/`top`/`mix`/`ask`, home menu, `add`, `ctl queue|jump`, `playlist remove` / `add --now`, `ai`/`config`/`doctor`, OpenAI-compatible LLM backend, weekly reminder, multi-word queries without quotes.

**Fixed:**
- `stats` showed "1×" for everything (history was de-duplicated, so counts were meaningless) — now backed by a real play log.
- `tunes help` / `tunes completion` failed when any dependency was missing, and every run created files and folders. Checks and state are now lazy; `eval "$(tunes completion)"` in `.bashrc` is safe.
- History titles containing `\n`, `\t` or backslashes were corrupted (`echo -e`); fields are now written with `printf` and sanitised.
- `tunes ctl seek +15` never worked (a leading `+` is invalid JSON); `ctl` arguments are validated; `ctl` says so when nothing is playing.
- IPC replies could be confused with mpv's asynchronous events — replies are now matched by request id.
- Search with no results or a yt-dlp failure silently killed the script; empty-model-output, "all caught up" and similar paths no longer abort under `set -e`.
- mpv arguments are arrays (paths with spaces), no more word-splitting; the shell-quoting notes from `shellcheck` are gone.
- Playlist / podcast-folder names could escape their directory (`../`); they are sanitised.
- `video` mode asked yt-dlp for audio-only formats; `dedupe` could empty a file if `awk` failed or the URL contained backslashes; queue temp files leaked; `pod-feeds` required the `column` binary; and starting a second player left two mpv instances fighting over one socket.
- The completion list had bogus `pod` sub-commands; unknown commands/flags now exit with an error instead of silently printing help.

---

## 🤝 Contributing

Issues and PRs welcome on [GitHub](https://github.com/MelancholicMuser/tunes). Please run `shellcheck tunes` and `tests/run.sh` first.

## 📄 License

[MIT](LICENSE)
