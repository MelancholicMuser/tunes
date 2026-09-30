# 🎵 tunes

> **Search, play, queue, download, and manage music & podcasts directly from your terminal with native GNOME integration.**  
> Powered by `mpv`, `yt-dlp`, `fzf`, `python3`, and optional local AI with Ollama (`llama3.2:3b`).

---

## ✨ Features

- 🎧 **Instant Audio Streaming**: Search and stream YouTube audio seamlessly without bloat.
- 🔔 **Native GNOME & Desktop Notifications**:
  - **MPRIS2 D-Bus Controls**: Full interactive media widget in GNOME's top-bar calendar/notification drawer and on the Lock Screen.
  - **System Media Keys**: Control playback (Play/Pause, Next, Prev, Stop) using keyboard hotkeys and Bluetooth headsets.
  - **Actionable Notifications**: Native desktop popups on track start/change with interactive **`⏯ Play/Pause`** and **`⏭ Next`** buttons.
  - **On-Screen Volume Feedback**: Volume changes display native GNOME volume slider notifications.
- 🔀 **Interactive Queues & Playlists**: Multi-select tracks using `fzf` (Tab to select) and play continuous queues with optional shuffle (`-s`).
- 📁 **Custom Named Playlists**: Create, manage, and play saved playlists (`tunes playlist`).
- 🚀 **Background / Detached Playback**: Run playback in the background (`tunes bg [query]` or `-d`) to immediately free your terminal prompt.
- 🎙️ **Podcast Player with Auto-Resume**:
  - Search the Apple iTunes podcast directory or subscribe directly via RSS feed URL.
  - Automatically remembers exact playback position so you can resume long episodes right where you left off.
  - Download podcast episodes directly as MP3 files for offline listening.
- 🤖 **AI-Powered Vibe & Mood Search**: Describe a vibe (e.g., *"rainy day lofi for coding"*) and let local Ollama (`llama3.2:3b`) generate tailored queues.
- 🧠 **Smart Recommendations**: Suggest new music tracks and surface unplayed podcast episodes based on your listening history.
- 📊 **Listening Statistics**: Track your total plays, favorite keywords, top repeated tracks, and feed subscriptions (`tunes stats`).
- 📥 **Offline MP3 Downloader**: Download tracks with embedded metadata and cover thumbnails to `~/Music/tunes-downloads`.
- 📜 **History & Favorites**: Bookmark favorite tracks, remove favorites, and replay recent tracks.
- 🎤 **Synchronized Lyrics**: Live terminal lyrics support via `sptlrx`.
- ⏯️ **Extended Transport Controls**: Seek relative time (`seek +15`), adjust speed (`speed 1.5`), set direct volume (`vol 80`), toggle mute, and stop cleanly via IPC.
- 🎬 **Video & VLC Mode**: Stream with a full video window or launch in `vlc`.

---

## 📋 Dependencies

### Core Requirements
Make sure the following dependencies are installed on your system:

| Dependency | Purpose | Fedora | Ubuntu / Debian | Arch | macOS |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`bash`** (4.0+) | Shell runtime environment | Pre-installed | Pre-installed | Pre-installed | `brew install bash` |
| **`mpv`** | Core media player backend | `sudo dnf install mpv` | `sudo apt install mpv` | `pacman -S mpv` | `brew install mpv` |
| **`yt-dlp`** | Audio stream extraction | `sudo dnf install yt-dlp` | `sudo apt install yt-dlp` | `pacman -S yt-dlp` | `brew install yt-dlp` |
| **`fzf`** | Terminal interactive picker | `sudo dnf install fzf` | `sudo apt install fzf` | `pacman -S fzf` | `brew install fzf` |
| **`python3`** | RSS & IPC communication | Pre-installed | Pre-installed | Pre-installed | `brew install python3` |
| **`curl`** | HTTP network fetching | Pre-installed | Pre-installed | Pre-installed | `brew install curl` |
| **`jq`** | JSON stream formatting | `sudo dnf install jq` | `sudo apt install jq` | `pacman -S jq` | `brew install jq` |

### Optional Enhancements

- 🔔 **GNOME / FreeDesktop Desktop Notifications**: `libnotify` (`notify-send`) and `mpv-mpris` (for MPRIS2 desktop widgets).
- 🤖 **[Ollama](https://ollama.com)** (with `llama3.2:3b` model): Powers `tunes mood` vibe generation and intelligent history ranking.
  ```bash
  ollama run llama3.2:3b
  ```
- 🎛️ **`playerctl`**: Hardware media key support for desktop environments.
  ```bash
  sudo dnf install playerctl   # or: sudo apt install playerctl
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
tunes — terminal music & podcast player with GNOME integration

Usage:
  tunes search [query]        Search YouTube and play one track
  tunes bg [query]            Search and play in background (frees terminal immediately)
  tunes play <url|path>       Play direct URL, YouTube link, or local audio file
  tunes queue [query]         Search, multi-select (TAB), play as queue
  tunes video [query]         Search and play with video window
  tunes vlc [query]           Search and open stream in VLC
  tunes history               Browse & replay recent tracks
  tunes fav-add               Save a track from history to favorites
  tunes favorites             Browse & play favorites
  tunes fav-remove            Remove a track from favorites
  tunes download [query]      Download a track as mp3 with tags & cover art
  tunes lyrics                Live lyrics via sptlrx (if installed)
  tunes stats                 View listening stats and top tracks

  --- GNOME & Playback Control ---
  tunes status / tunes np     Show current track, elapsed time, volume, and state
  tunes notify                Show desktop notification of current track
  tunes ctl {action} [args]   Control playback:
      pause                   Toggle play / pause
      play                    Resume playback
      stop                    Stop playback and close mpv
      next / prev             Skip to next / previous track in queue
      vol-up / vol-down       Increase / decrease volume (shows GNOME slider)
      vol <0-100>             Set volume level directly
      mute                    Toggle mute
      seek <+/-sec>           Seek position (e.g. tunes ctl seek +15)
      speed <rate>            Set playback speed (e.g. tunes ctl speed 1.5)
      loop-toggle             Toggle track looping
      loop-on / loop-off      Turn looping on or off

  --- Playlists ---
  tunes playlist list         List your saved playlists
  tunes playlist create <name>Create a new playlist
  tunes playlist add <name>   Add a track from search or history
  tunes playlist play <name>  Play a saved playlist
  tunes playlist view <name>  View tracks in a playlist
  tunes playlist delete <name>Delete a playlist

  --- Podcasts ---
  tunes pod                   Pick a subscribed feed, then an episode, and play
  tunes pod-add [name]        Search iTunes directory & subscribe to feed
  tunes pod-add-url <url>     Subscribe directly via RSS feed URL
  tunes pod-feeds             List your podcast subscriptions
  tunes pod-history           Browse & replay recent episodes (auto-resumes position!)
  tunes pod-download          Download podcast episode for offline listening
  tunes pod-remove            Unsubscribe from a feed

  --- AI & Smart Recommendations ---
  tunes recommend music       Suggest new tracks based on your listening history
  tunes recommend podcast     Surface & rank unplayed episodes from your feeds
  tunes mood [vibe]           Describe what you want to hear (e.g. "rainy lofi")
                              Uses Ollama + Llama 3.2 to craft search & build queue

Flags (place before the subcommand):
  -d, --bg, --detach          Run playback in background, return terminal immediately
  -l, --loop                  Start playback with looping enabled
  -s, --shuffle               Shuffle playlist or queue tracks randomly
  -h, --help                  Show this help message
```

---

## 💡 Workflows & Examples

### 1. GNOME Desktop Integration
When playing music or podcasts, `tunes` automatically:
- Registers on D-Bus via MPRIS2: interactive controls appear in GNOME's top-bar calendar menu and Lock Screen.
- Hardware keyboard media keys (Play/Pause, Next, Prev) work system-wide.
- Displays interactive desktop notifications with clickable `⏯ Play/Pause` and `⏭ Next` buttons.

### 2. Background Playback
Play music in the background without tying up your shell:
```bash
tunes bg "synthwave chill"
tunes status          # Check playback progress anytime
tunes ctl vol-up      # Increase volume with on-screen slider
tunes ctl pause       # Pause playback
```

### 3. Custom Named Playlists
```bash
tunes playlist create "Study Beats"
tunes playlist add "Study Beats" "chopin nocturne"
tunes -s playlist play "Study Beats"   # Play in shuffled order
```

### 4. Direct Playback
```bash
tunes play "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
tunes play ~/Music/song.mp3
```

### 5. Podcast Subscriptions & Resuming
```bash
# Subscribe via iTunes directory or direct RSS
tunes pod-add "lex fridman"
tunes pod-add-url "https://feeds.simplecast.com/kwWc0lhf" "Hidden Brain"

# Play episode (automatically resumes where you left off)
tunes pod
```

### 6. Shell Tab-Completion
Add this line to your `~/.bashrc` to enable full tab-completion:
```bash
eval "$(tunes completion)"
```

---

## ⚙️ Configuration & Storage

`tunes` stores user state, listening history, favorites, and podcast subscriptions under standard XDG paths:
- **Data directory**: `~/.local/share/tunes/`
  - `history.tsv` — Track play history
  - `favorites.tsv` — Saved favorite tracks
  - `feeds.tsv` — RSS podcast feed subscriptions
  - `podcast_history.tsv` — Podcast listening history
  - `playlists/` — Saved custom playlists
  - `scripts/` — mpv Lua notification and MPRIS integration scripts
- **Download directory**: `~/Music/tunes-downloads/`
- **IPC Socket**: `$XDG_RUNTIME_DIR/tunes-mpv-<UID>.sock`

---

## 🤝 Contributing

Contributions, bug reports, and feature requests are welcome!  
Feel free to open an issue or submit a Pull Request on [GitHub](https://github.com/MelancholicMuser/tunes).

---

## 📄 License

Distributed under the [MIT License](LICENSE).
