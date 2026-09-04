# 🎵 tunes

> **Search, play, queue, download, and manage music & podcasts directly from your terminal.**  
> Powered by `mpv`, `yt-dlp`, `fzf`, and optional local AI with Ollama (`llama3.2:3b`).

---

## ✨ Features

- 🎧 **Instant Streaming**: Search and stream audio seamlessly without bloat.
- 🔀 **Interactive Queues & Playlists**: Multi-select tracks using `fzf` and play continuous queues.
- 🎙️ **Podcast Player & Directory**: Search the Apple iTunes podcast directory, subscribe to RSS feeds, and stream episodes.
- 🤖 **AI-Powered Vibe & Mood Search**: Describe a vibe (e.g., *"rainy day lofi for coding"*) and let a local LLM generate tailored playlists.
- 🧠 **Smart Recommendations**: Smart track and podcast episode recommendations based on your listening history.
- 📥 **MP3 Downloader**: Save audio files directly to your music folder for offline listening.
- 📜 **History & Favorites**: Effortlessly bookmark favorite tracks and revisit past listening history.
- 🎤 **Synchronized Lyrics**: Integrated support for live terminal lyrics via `sptlrx`.
- ⏯️ **Playback Controls**: Control volume, pause, skip, and loop mode on running streams via IPC (`socat`/`playerctl`).
- 🎬 **Video & Alternative Player Support**: Switch between terminal audio, full video playback, or launch in `vlc`.

---

## 📋 Dependencies

### Core Requirements
Make sure the following dependencies are installed on your system:

| Dependency | Purpose | Recommended Installation (Ubuntu/Debian / Arch / macOS) |
| :--- | :--- | :--- |
| **`bash`** (4.0+) | Shell runtime environment | Pre-installed |
| **`mpv`** | Core media player backend | `sudo apt install mpv` / `pacman -S mpv` / `brew install mpv` |
| **`yt-dlp`** | Audio stream extraction | `sudo apt install yt-dlp` / `pacman -S yt-dlp` / `brew install yt-dlp` |
| **`fzf`** | Terminal interactive picker | `sudo apt install fzf` / `pacman -S fzf` / `brew install fzf` |
| **`python3`** | RSS & iTunes API parsing | Pre-installed / `sudo apt install python3` |
| **`curl`** | HTTP network fetching | Pre-installed / `sudo apt install curl` |
| **`jq`** | JSON stream formatting | `sudo apt install jq` / `pacman -S jq` / `brew install jq` |

### Optional Enhancements

- 🤖 **[Ollama](https://ollama.com)** (with `llama3.2:3b` model): Powers `tunes mood` vibe generation and intelligent history ranking.
  ```bash
  ollama run llama3.2:3b
  ```
- 🎛️ **`socat`** or **`playerctl`**: Enables transport controls (`pause`, `next`, `prev`, volume adjust, looping).
  ```bash
  sudo apt install socat playerctl
  ```
- 🎤 **`sptlrx`**: Real-time synchronized lyrics display.
  ```bash
  curl -sSL https://raw.githubusercontent.com/raitonoberu/sptlrx/main/install.sh | bash
  ```
- 📺 **`vlc`**: Optional external player engine for `tunes vlc`.

---

## 🚀 Quick Start & Installation

### Option 1: Using the Installer Script
Clone the repository and run `install.sh`:
```bash
git clone https://github.com/MelancholicMuser/tunes.git
cd tunes
chmod +x install.sh
./install.sh
```

### Option 2: Manual Installation
Make the script executable and copy it to a directory in your `$PATH`:
```bash
chmod +x tunes
mkdir -p ~/.local/bin
cp tunes ~/.local/bin/tunes
```

Ensure `~/.local/bin` is in your environment `PATH` (in `~/.bashrc` or `~/.zshrc`):
```bash
export PATH="$HOME/.local/bin:$PATH"
```

---

## 📖 Usage Guide

```
tunes — free terminal music player (yt-dlp + mpv + fzf)

Usage:
  tunes search [query]       Search and play a track
  tunes queue  [query]       Search, multi-select (Tab), and play continuous queue
  tunes video  [query]       Search and stream with video window
  tunes vlc    [query]       Search and launch in VLC media player
  tunes history              Browse and replay recent tracks
  tunes fav-add              Save a recent track to favorites
  tunes favorites            Browse and play favorite tracks
  tunes download [query]     Download track as high-quality MP3
  tunes lyrics               Display real-time synchronized lyrics (sptlrx)

Playback Controls:
  tunes ctl {pause|next|prev|vol-up|vol-down|loop-on|loop-off|loop-toggle}

Podcasts:
  tunes pod-add [name]       Search iTunes podcast directory & subscribe
  tunes pod-feeds            List subscribed podcast feeds
  tunes pod                  Browse episodes from subscribed podcasts & play
  tunes pod-history          Browse podcast listening history

AI & Recommendations:
  tunes mood [description]   AI-generated queue based on vibe (e.g. "late night ambient synth")
  tunes recommend music      Recommend new music tracks based on listening history
  tunes recommend podcast    Surface & rank unplayed podcast episodes

Global Flags:
  -l, --loop                 Start playback with looping enabled
                             (e.g., tunes -l search "blinding lights")
```

### Key Workflows & Examples

#### 1. Quick Search & Stream
```bash
tunes search "daft punk one more time"
```

#### 2. Queue Multiple Songs
```bash
tunes queue "lofi hip hop"
```
*Use `Tab` to select multiple tracks in `fzf`, then press `Enter` to start the playlist.*

#### 3. AI Vibe Search
```bash
tunes mood "relaxing jazz for a rainy evening"
```

#### 4. Play Podcasts
```bash
# Search & Subscribe
tunes pod-add "syntax fm"

# Play Episodes
tunes pod
```

#### 5. Download MP3 for Offline Listening
```bash
tunes download "synthwave mix 2024"
```
*Files are saved to `~/Music/tunes-downloads`.*

---

## ⚙️ Configuration & Storage

`tunes` stores user state, listening history, favorites, and podcast subscriptions under standard XDG paths:
- **Data directory**: `~/.local/share/tunes/`
  - `history.tsv` — Track play history
  - `favorites.tsv` — Saved favorite tracks
  - `feeds.tsv` — RSS podcast feed subscriptions
  - `podcast_history.tsv` — Podcast listening history
- **Download directory**: `~/Music/tunes-downloads/`
- **Socket file**: `/tmp/tunes-mpv.sock` (used for playback IPC controls)

---

## 🤝 Contributing

Contributions, bug reports, and feature requests are welcome!  
Feel free to open an issue or submit a Pull Request on [GitHub](https://github.com/MelancholicMuser/tunes).

---

## 📄 License

Distributed under the [MIT License](LICENSE).
