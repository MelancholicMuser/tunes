#!/usr/bin/env bash
# Integration tests for tunes. Needs: mpv, fzf, jq, python3, curl (everything else is mocked).
#   tests/run.sh [path/to/tunes]
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TUNES="${1:-$HERE/../tunes}"
TUNES="$(cd "$(dirname "$TUNES")" && pwd)/$(basename "$TUNES")"
T="$(mktemp -d)"
LLM_PIDS=()
cleanup() { for p in "${LLM_PIDS[@]:-}"; do kill "$p" 2>/dev/null; done; pkill -f "$T/" 2>/dev/null; rm -rf "$T"; }
trap cleanup EXIT

pass=0; fail=0
ok()   { pass=$((pass + 1)); printf '  \033[32m✓\033[0m %s\n' "$1"; }
bad()  { fail=$((fail + 1)); printf '  \033[31m✗ %s\033[0m\n' "$1"; [[ -n "${2:-}" ]] && printf '      %s\n' "$2" | head -8; }
check() { local name="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$name"; else bad "$name"; fi; }
section() { printf '\n\033[1m%s\033[0m\n' "$1"; }
contains() { grep -qF -- "$2" <<<"$1"; }
assert_contains() { if contains "$2" "$3"; then ok "$1"; else bad "$1" "expected to find: $3 | got: ${2:0:300}"; fi; }
assert_not_contains() { if contains "$2" "$3"; then bad "$1" "did not expect: $3"; else ok "$1"; fi; }

# ---------------------------------------------------------------- sandbox
mkdir -p "$T/bin" "$T/home/.config/mpv" "$T/data" "$T/run" "$T/media"
printf 'ao=null\nvo=null\nreally-quiet=yes\n' > "$T/home/.config/mpv/mpv.conf"

python3 - "$T/media" <<'EOF'
import wave, struct, math, sys
def mk(name, secs, freq):
    w = wave.open(sys.argv[1] + '/' + name, 'w'); w.setnchannels(1); w.setsampwidth(2); w.setframerate(8000)
    w.writeframes(b''.join(struct.pack('<h', int(6000 * math.sin(2 * math.pi * freq * i / 8000))) for i in range(int(8000 * secs))))
    w.close()
mk('songA.wav', 6, 440); mk('songB.wav', 6, 550); mk('long.wav', 60, 330)
EOF

# mock fzf: first line (or all lines with --multi); MOCK_FZF_PATTERN picks a matching line
cat > "$T/bin/fzf" <<'EOF'
#!/usr/bin/env bash
multi=0
for a in "$@"; do
  [[ "$a" == --multi ]] && multi=1
  [[ "$a" == --header=* && -n "${MOCK_FZF_LOG:-}" ]] && printf '%s\n' "${a#--header=}" >> "$MOCK_FZF_LOG"
done
input=$(cat)
[[ -n "${MOCK_FZF_PATTERN:-}" ]] && input=$(grep -- "$MOCK_FZF_PATTERN" <<<"$input" | head -n1)
[[ -z "$input" ]] && exit 1
if ((multi)); then printf '%s\n' "$input"; else head -n1 <<<"$input"; fi
EOF
# mock yt-dlp: search results point at local wav files
cat > "$T/bin/yt-dlp" <<'EOF'
#!/usr/bin/env python3
import sys, os, json
media, a = os.environ["MOCK_MEDIA"], (sys.argv[1] if len(sys.argv) > 1 else "")
if a.startswith("ytsearch"):
    if a.split(":", 1)[1] == "nothing":
        sys.exit(0)
    print(json.dumps({"title": "Song A\tTabbed", "url": media + "/songA.wav", "channel": "Chan A", "duration_string": "0:06", "id": "aaa"}))
    print(json.dumps({"title": r"Back\slash \n Song B", "url": media + "/songB.wav", "channel": "Chan B", "duration_string": "0:06", "id": "bbb"}))
elif a == "-g":
    print(media + "/songA.wav")
EOF
chmod +x "$T/bin/"*

export MOCK_FZF_LOG="$T/fzf_header.log" MOCK_MEDIA="$T/media" HOME="$T/home" TUNES_DATA_DIR="$T/data" TUNES_CONFIG="$T/config" XDG_RUNTIME_DIR="$T/run" \
       TUNES_DOWNLOAD_DIR="$T/dl" PATH="$T/bin:$PATH" NO_COLOR=1
unset OLLAMA_URL OLLAMA_MODEL LLM_BACKEND LLM_URL LLM_MODEL LLM_API_KEY
tunes() { bash "$TUNES" "$@"; }
plays() { grep -c . "$T/data/plays.tsv" 2>/dev/null || echo 0; }
wait_for() { local n=0; until "$@" >/dev/null 2>&1; do sleep 0.2; n=$((n + 1)); if ((n > 40)); then return 1; fi; done; return 0; }

# ---------------------------------------------------------------- tests
section "No dependencies / no side effects"
NOBIN="$T/nobin"; mkdir -p "$NOBIN"
for f in /usr/bin/* /bin/*; do b=$(basename "$f"); [[ "$b" == mpv ]] || ln -sf "$f" "$NOBIN/$b" 2>/dev/null; done
rm -rf "$T/clean"; mkdir -p "$T/clean"
out=$(HOME="$T/clean" TUNES_DATA_DIR="$T/clean/data" PATH="$NOBIN" bash "$TUNES" help 2>&1); rc=$?
check "help works without mpv installed" test $rc -eq 0
assert_contains "help mentions the new report command" "$out" "tunes report"
out=$(HOME="$T/clean" TUNES_DATA_DIR="$T/clean/data" PATH="$NOBIN" bash "$TUNES" completion 2>&1); rc=$?
check "completion works without mpv installed" test $rc -eq 0
check "help/completion create no files or folders" test -z "$(ls -A "$T/clean")"
out=$(HOME="$T/clean" TUNES_DATA_DIR="$T/clean/data" PATH="$NOBIN" bash "$TUNES" search x 2>&1); rc=$?
check "search without mpv fails cleanly (rc 1)" test $rc -eq 1
assert_contains "…and names the missing dependency" "$out" "Missing dependency: mpv"
out=$(tunes bogus 2>&1); rc=$?; check "unknown command exits 1" test $rc -eq 1
out=$(tunes -x 2>&1); rc=$?;    check "unknown flag exits 1" test $rc -eq 1
assert_contains "version" "$(tunes --version)" "tunes 2."
out=$(tunes doctor 2>&1); assert_contains "doctor lists mpv" "$out" "✓ mpv"

section "Foreground playback is tracked"
tunes play "$T/media/songA.wav" >/dev/null 2>&1
check "play log gets a line" test "$(plays)" -eq 1
line=$(head -n1 "$T/data/plays.tsv")
assert_contains "line records kind=music" "$line" $'\tmusic\t'
assert_contains "line records the file path as URL" "$line" "$T/media/songA.wav"
secs=$(cut -f3 <<<"$line"); check "listened ≈ track length (>5s)" python3 -c "import sys; sys.exit(0 if float('$secs') > 5 else 1)"
check "history records the track" grep -q songA "$T/data/history.tsv"
tunes play "$T/media/songA.wav" >/dev/null 2>&1
out=$(tunes stats 2>&1)
assert_contains "same track played twice shows ×2 (old stats always showed 1)" "$out" "×2"
assert_contains "stats shows total plays" "$out" "2 plays"
check "history stays de-duplicated" test "$(grep -c songA "$T/data/history.tsv")" -eq 1

section "Background playback & remote control"
tunes -d play "$T/media/long.wav" >/dev/null 2>&1
if wait_for bash -c "bash '$TUNES' status | grep -q Playing"; then ok "background session starts"; else bad "background session starts" "$(ls -la "$XDG_RUNTIME_DIR" 2>&1; pgrep -a mpv)"; fi
sleep 3.5
assert_contains "status shows Playing" "$(tunes status)" "Playing"
tunes ctl pause >/dev/null 2>&1; assert_contains "pause" "$(tunes status)" "Paused"
tunes ctl pause >/dev/null 2>&1
check "ctl vol 40" tunes ctl vol 40
assert_contains "volume applied" "$(tunes status)" "40%"
check "ctl seek +5 works (leading + used to break the JSON)" tunes ctl seek +5
check "ctl seek -2 works" tunes ctl seek -2
out=$(tunes ctl vol abc 2>&1); rc=$?; check "ctl vol abc is rejected" test $rc -ne 0
out=$(tunes ctl speed fast 2>&1); rc=$?; check "ctl speed fast is rejected" test $rc -ne 0
assert_contains "ctl queue lists the track" "$(tunes ctl queue)" "long.wav"
tunes ctl stop >/dev/null 2>&1; sleep 0.8
check "play stopped early (≥3s) is still logged" test "$(plays)" -eq 3
last=$(tail -n1 "$T/data/plays.tsv"); lsecs=$(cut -f3 <<<"$last")
check "…as a skip (listened < 30s of a 60s track)" python3 -c "import sys; sys.exit(0 if float('$lsecs') < 30 else 1)"
out=$(tunes ctl vol 50 2>&1); assert_contains "ctl with nothing playing says so" "$out" "Nothing is playing"

section "Playlists (safe names, queue playback, jump)"
tunes playlist create "../evil" >/dev/null 2>&1
check "path traversal blocked (no file outside playlists/)" test ! -e "$T/data/evil.tsv"
check "…name was sanitised into playlists/" ls "$T/data/playlists"/*evil.tsv
tunes playlist create Mine >/dev/null 2>&1
printf 'Song A\t%s\nSong B\t%s\n' "$T/media/songA.wav" "$T/media/songB.wav" >> "$T/data/playlists/Mine.tsv"
assert_contains "playlist view" "$(tunes playlist view Mine)" "Song B"
tunes -d playlist play Mine >/dev/null 2>&1; sleep 1.5
q=$(tunes ctl queue); assert_contains "queue has both tracks" "$q" "2. Song B"
tunes ctl jump 2 >/dev/null 2>&1; sleep 4; assert_contains "jump moved to track 2" "$(tunes ctl queue)" "▶  2."
tunes ctl stop >/dev/null 2>&1; sleep 0.8
check "playlist plays are logged" grep -q "Song B" "$T/data/plays.tsv"
tunes playlist add Mine --now >/dev/null 2>&1; rc=$?; check "add --now with nothing playing fails politely" test $rc -ne 0

section "Search, queue, add-to-queue (mocked yt-dlp + fzf)"
out=$(tunes search nothing 2>&1); rc=$?
assert_contains "no results → helpful message" "$out" "No results"
before=$(plays)
tunes search "anything" >/dev/null 2>&1
check "search → play → logged" test "$(plays)" -eq $((before + 1))
check "tab in a title is sanitised (history still 2 columns)" bash -c "awk -F'\t' 'NF != 2 {exit 1}' '$T/data/history.tsv'"
tunes queue "anything" >/dev/null 2>&1
check "queue plays both selected tracks" test "$(plays)" -eq $((before + 3))
check "backslashes in titles survive (echo -e used to eat them)" grep -qF 'Back\slash \n Song B' "$T/data/history.tsv"
tunes -d search "anything" >/dev/null 2>&1; sleep 1.2
out=$(tunes add "more" 2>&1); assert_contains "add queues tracks on the running player" "$out" "Queued"
assert_contains "queue now has 3 entries" "$(tunes ctl queue)" " 3."
tunes ctl stop >/dev/null 2>&1; sleep 0.8
tunes -d bg "anything" >/dev/null 2>&1; sleep 1; check "starting new playback replaces the running one" test "$(pgrep -fc "$T/media/songA.wav")" -le 1
tunes ctl stop >/dev/null 2>&1; sleep 0.5

section "Stats, report, top, mix (synthetic history)"
now=$(date +%s); : > "$T/data/plays.tsv"
for i in 1 2 3 4 5; do printf '%s\tmusic\t6.0\t6.0\tSong A\tChan A\t%s\n' $((now - i * 3600)) "$T/media/songA.wav" >> "$T/data/plays.tsv"; done
for i in 1 2;       do printf '%s\tmusic\t6.0\t6.0\tSong B\tChan B\t%s\n' $((now - i * 7200)) "$T/media/songB.wav" >> "$T/data/plays.tsv"; done
printf '%s\tmusic\t3.1\t200\tSkipped Song\tNobody\thttps://x/skip\n' $((now - 100)) >> "$T/data/plays.tsv"
printf '%s\tmusic\t3.2\t200\tSkipped Song\tNobody\thttps://x/skip\n' $((now - 90)) >> "$T/data/plays.tsv"
out=$(tunes report 2>&1)
assert_contains "report: header" "$out" "Tunes Weekly Report"
assert_contains "report: play total" "$out" "7 plays"
assert_contains "report: top track with count" "$out" "Song A"
assert_contains "report: skip rate" "$out" "Skip rate 22%"
assert_contains "report: often skipped section" "$out" "Skipped Song"
check "report --json is valid JSON" bash -c "bash '$TUNES' report --json | python3 -c 'import sys,json; d=json.load(sys.stdin); assert d[\"plays\"]==7'"
out=$(tunes report month 2>&1); assert_contains "report month" "$out" "last 30 days"
out=$(tunes report banana 2>&1); rc=$?; check "bad period → error" test $rc -ne 0
assert_contains "…with a helpful message" "$out" "Unknown period"
out=$(tunes report --save 2>&1); assert_contains "--save reports the path" "$out" "Saved:"
check "saved report exists and has no colour codes" bash -c "f=\$(ls '$T/data/reports'/*.txt | head -1); [ -s \"\$f\" ] && ! grep -q \$'\\033' \"\$f\""
check "--notify doesn't crash without notify-send" tunes report --notify
before=$(plays); tunes top >/dev/null 2>&1
check "top → plays selection (logged)" test "$(plays)" -gt "$before"
before=$(plays); tunes mix 1 >/dev/null 2>&1
check "mix 1 plays one track" test "$(plays)" -eq $((before + 1))
out=$(tunes mix abc 2>&1); rc=$?; check "mix rejects non-numeric count" test $rc -ne 0

section "Config"
out=$(tunes config show); assert_contains "config show lists settings" "$out" "LLM_BACKEND"
tunes config set LLM_MODEL "mock:1b" >/dev/null; assert_contains "config set persists" "$(cat "$TUNES_CONFIG")" "LLM_MODEL=mock:1b"
check "config file is private (600)" test "$(stat -c %a "$TUNES_CONFIG")" = "600"
out=$(LLM_MODEL=envwins tunes config show); assert_contains "environment overrides file" "$out" "envwins"
assert_contains "…and says so" "$out" "overridden by environment"
out=$(tunes config set LLM_BACKEND nope 2>&1); rc=$?; check "invalid backend rejected" test $rc -ne 0
out=$(tunes config set NOT_A_KEY 1 2>&1); rc=$?; check "unknown key rejected" test $rc -ne 0
printf 'LLM_URL=http://x\n$(touch %s/pwned)\nEVIL=1\n' "$T" >> "$TUNES_CONFIG"; tunes config show >/dev/null 2>&1
check "config file is never executed" test ! -e "$T/pwned"
tunes config unset LLM_MODEL >/dev/null; check "config unset" bash -c "! grep -q LLM_MODEL '$TUNES_CONFIG'"
tunes config set LLM_URL "" >/dev/null 2>&1; tunes config unset LLM_URL >/dev/null 2>&1

section "Local LLM — Ollama protocol"
OPORT=$((20000 + RANDOM % 10000)); python3 "$HERE/mock_llm.py" "$OPORT" & LLM_PIDS+=($!); sleep 0.6
export LLM_URL="http://127.0.0.1:$OPORT"
out=$(tunes ai test 2>&1); rc=$?
assert_contains "ai test: reachable" "$out" "✓ Server reachable"
assert_contains "ai test: model present" "$out" "Model 'llama3.2:3b' is available"
check "ai test passes" test $rc -eq 0
out=$(LLM_MODEL=nope:7b tunes ai test 2>&1); rc=$?; check "ai test flags a missing model" test $rc -ne 0
out=$(tunes report --ai 2>&1)
assert_contains "report --ai prints the AI take" "$out" "AI-REPORT"
assert_contains "digest handed to the model is non-trivial" "$out" "digest chars="
out=$(tunes ask "which song is my favourite?" 2>&1); assert_contains "ask relays the question" "$out" "AI-ANSWER: which song is my favourite?"
out=$(LLM_MODEL=missing:1b tunes report --ai 2>&1); rc=$?
check "model error never breaks the report (rc 0)" test $rc -eq 0
assert_contains "…report still printed" "$out" "Most played"
assert_contains "…and the failure is explained" "$out" "AI take unavailable"
before=$(plays); out=$(tunes mood "rainy evening" 2>&1)
assert_contains "mood: model queries are cleaned (numbering/quotes stripped)" "$out" "• rainy day jazz"
check "mood plays the chosen tracks" test "$(plays)" -gt "$before"
out=$(tunes recommend music 2>&1); assert_contains "recommend uses the model" "$out" "Based on:"
before=$(plays); LLM_URL="http://127.0.0.1:1" tunes mood "x" >/dev/null 2>&1
check "mood falls back to plain search when the LLM is down" test "$(plays)" -gt "$before"
out=$(LLM_URL="http://127.0.0.1:1" tunes report --ai 2>&1); rc=$?; check "report --ai with LLM down → rc 0" test $rc -eq 0
assert_contains "…with setup hint" "$out" "tunes ai setup"

section "Local LLM — OpenAI-compatible protocol"
out=$(LLM_BACKEND=openai LLM_MODEL=local-model LLM_API_KEY=sekret tunes report --ai 2>&1)
assert_contains "openai backend works" "$out" "AI-REPORT"
assert_contains "API key is sent as a bearer token" "$out" "auth:Bearer sekret"
assert_not_contains "<think> blocks are stripped" "$out" "<think>"
out=$(LLM_BACKEND=openai LLM_URL="$LLM_URL/v1" LLM_MODEL=local-model tunes ai test 2>&1); assert_contains "a trailing /v1 in the URL is tolerated" "$out" "✓ Model 'local-model'"
tunes config set LLM_API_KEY topsecret >/dev/null; assert_not_contains "api key is masked in config show" "$(tunes config show)" "topsecret"
tunes config unset LLM_API_KEY >/dev/null

section "Podcasts (local RSS feed)"
cat > "$T/feed.xml" <<RSS
<?xml version="1.0"?><rss version="2.0"><channel><title>Test Cast</title>
<item><title>Episode One</title><enclosure url="file://$T/media/songA.wav" type="audio/wav"/><pubDate>Mon, 05 Oct 2026 10:00:00 GMT</pubDate></item>
</channel></rss>
RSS
tunes pod-add-url "file://$T/feed.xml" "Test/Cast" >/dev/null 2>&1
assert_contains "pod-feeds lists the subscription (no \`column\` binary needed)" "$(tunes pod-feeds)" "Test/Cast"
before=$(plays); tunes pod >/dev/null 2>&1
check "podcast episode plays and is logged as kind=podcast" bash -c "tail -n1 '$T/data/plays.tsv' | cut -f2 | grep -qx podcast"
check "podcast history recorded" grep -q "Episode One" "$T/data/podcast_history.tsv"
out=$(tunes recommend podcast 2>&1); assert_contains "recommend podcast says all caught up" "$out" "all caught up"
tunes pod-download >/dev/null 2>&1
check "podcast download lands in a sanitised folder" ls "$T/dl/Podcasts/Test-Cast"/*.mp3
out=$(tunes report all 2>&1); assert_not_contains "podcast sessions don't pollute music stats" "$out" "Episode One"
NOFF="$T/noff"; mkdir -p "$NOFF"; for f in /usr/bin/* /bin/*; do b=$(basename "$f"); [[ "$b" == ffmpeg || "$b" == ffprobe ]] || ln -sf "$f" "$NOFF/$b" 2>/dev/null; done; cp "$T/bin/"* "$NOFF/"
out=$(PATH="$NOFF" tunes download x 2>&1); rc=$?; check "download without ffmpeg explains itself" test $rc -ne 0
assert_contains "…with an install hint" "$out" "ffmpeg"

section "Weekly report reminder (home menu header)"
rm -f "$T/data/.last_report" "$T/fzf_header.log"
MOCK_FZF_PATTERN="Quit" script -qec "bash '$TUNES'" /dev/null >/dev/null 2>&1 </dev/null
assert_contains "reminder shown when a week has passed" "$(cat "$T/fzf_header.log" 2>/dev/null)" "weekly report is ready"
tunes report >/dev/null 2>&1; rm -f "$T/fzf_header.log"
MOCK_FZF_PATTERN="Quit" script -qec "bash '$TUNES'" /dev/null >/dev/null 2>&1 </dev/null
assert_not_contains "…and gone right after viewing a report" "$(cat "$T/fzf_header.log" 2>/dev/null)" "weekly report is ready"
echo "REPORT_REMINDER=off" >> "$TUNES_CONFIG"; rm -f "$T/data/.last_report" "$T/fzf_header.log"
MOCK_FZF_PATTERN="Quit" script -qec "bash '$TUNES'" /dev/null >/dev/null 2>&1 </dev/null
assert_not_contains "…and can be switched off" "$(cat "$T/fzf_header.log" 2>/dev/null)" "weekly report is ready"
tunes config unset REPORT_REMINDER >/dev/null

section "Home menu (pty) & misc"
out=$(MOCK_FZF_PATTERN="Quit" script -qec "bash '$TUNES'" /dev/null 2>&1 </dev/null | tr -d '\r'); rc=$?
check "bare 'tunes' opens the menu and Quit exits cleanly" test $rc -eq 0
: > "$T/data/feeds.tsv"
out=$(tunes recommend podcast 2>&1); assert_contains "recommend podcast with no feeds is graceful" "$out" "No subscriptions"
rm -f "$T/data/history.tsv"; : > "$T/data/history.tsv"
out=$(tunes history 2>&1); assert_contains "empty history is graceful" "$out" "No history"

# ================================================================= v2.1 / v2.2 features
tunes_in() { local d="$1"; shift; TUNES_DATA_DIR="$d" bash "$TUNES" "$@"; }
bg_play() { tunes -d play "$T/media/long.wav" >/dev/null 2>&1; wait_for bash -c "bash '$TUNES' status | grep -q Playing"; sleep 1.5; }
is_idle() { local o; o=$(bash "$TUNES" status 2>/dev/null); [[ "$o" != *Playing* ]]; }   # no `grep -q` pipe: SIGPIPE + pipefail gives false results
stop_all() { tunes ctl stop >/dev/null 2>&1; sleep 0.6; }

section "Autoplay & Up Next (v2.1)"
tunes autoplay on >/dev/null 2>&1
assert_contains "autoplay status says ON" "$(tunes autoplay status)" "ON"
tunes autoplay off >/dev/null 2>&1
assert_contains "autoplay off is remembered" "$(tunes autoplay status)" "OFF"
tunes autoplay toggle >/dev/null 2>&1
assert_contains "autoplay toggle turns it back on" "$(tunes autoplay status)" "ON"
out=$(tunes autoplay bogus 2>&1); rc=$?; check "autoplay rejects unknown argument" test $rc -ne 0
assert_contains "upnext with nothing playing says so" "$(tunes upnext 2>&1)" "Nothing is playing"

section "Audio enhancement (opt-in, safe filter chains)"
assert_contains "enhancement is off by default" "$(tunes enhance)" "Off (untouched audio)"
for p in crystalizer clarity warm bass spatial norm; do
  AUDIO_ENHANCE=on AUDIO_PRESET=$p bg_play
  st=$(tunes status 2>&1)
  if contains "$st" "Active ("; then ok "preset '$p' is accepted by mpv and shows as active"; else bad "preset '$p' is accepted by mpv and shows as active" "$st"; fi
  [[ $p == crystalizer ]] && assert_contains "crystalizer chain ends in a limiter" "$st" "alimiter"
  stop_all
done
AUDIO_ENHANCE=on AUDIO_PRESET=studio bg_play
assert_contains "studio preset applies no filters" "$(tunes status 2>&1)" "Off (no filters)"
stop_all
AUDIO_ENHANCE=on AUDIO_PRESET=custom AUDIO_CUSTOM_AF='equalizer=f=100:t=q:w=1:g=3' bg_play
assert_contains "custom preset uses your own filter chain" "$(tunes status 2>&1)" "equalizer"
stop_all
REPLAYGAIN=track bg_play
assert_contains "REPLAYGAIN=track is accepted by mpv" "$(tunes status 2>&1)" "Playing"
stop_all
out=$(tunes ctl enhance on 2>&1); assert_contains "ctl enhance with nothing playing says so" "$out" "Nothing is playing"
out=$(tunes config set AUDIO_PRESET nonsense 2>&1); rc=$?; check "invalid AUDIO_PRESET rejected" test $rc -ne 0
out=$(tunes config set REPLAYGAIN loud 2>&1); rc=$?; check "invalid REPLAYGAIN rejected" test $rc -ne 0
out=$(tunes config set AUDIO_CUSTOM_AF 'bad"quote' 2>&1); rc=$?; check "AUDIO_CUSTOM_AF with a quote rejected" test $rc -ne 0
out=$(tunes config set AUDIO_CUSTOM_AF 'back\slash' 2>&1); rc=$?; check "AUDIO_CUSTOM_AF with a backslash rejected" test $rc -ne 0
check "valid AUDIO_CUSTOM_AF accepted" tunes config set AUDIO_CUSTOM_AF 'equalizer=f=100:t=q:w=1:g=3'
tunes config unset AUDIO_CUSTOM_AF >/dev/null 2>&1

section "Sleep timer"
out=$(tunes sleep status 2>&1);      assert_contains "no timer by default" "$out" "No sleep timer"
out=$(tunes sleep banana 2>&1); rc=$?; check "garbage duration rejected" test $rc -ne 0
out=$(tunes sleep 0 2>&1); rc=$?;      check "zero duration rejected" test $rc -ne 0
bg_play
out=$(tunes sleep 1h30m 2>&1);       assert_contains "sleep 1h30m is accepted" "$out" "1h 30m"
assert_contains "status shows the countdown" "$(tunes sleep status)" "stops in"
assert_contains "…and playback is still going" "$(tunes status)" "Playing"
out=$(tunes sleep off 2>&1);         assert_contains "sleep off cancels" "$out" "cancelled"
assert_contains "…and status agrees" "$(tunes sleep status)" "No sleep timer"
out=$(tunes sleep 90 2>&1);           assert_contains "bare number means minutes (90 → 1h 30m)" "$out" "1h 30m"
tunes sleep off >/dev/null 2>&1
tunes sleep 3s >/dev/null 2>&1
if wait_for is_idle; then ok "short timer fades out and stops playback"; else bad "short timer fades out and stops playback" "$(tunes status)"; fi
assert_contains "…and clears itself afterwards" "$(tunes sleep status)" "No sleep timer"
stop_all

section "Alarm"
out=$(tunes alarm 25:99 2>&1); rc=$?;            check "invalid time rejected" test $rc -ne 0
out=$(tunes alarm 07:30 nosuchlist 2>&1); rc=$?;  check "unknown playlist rejected" test $rc -ne 0
printf 'Song A\t%s\nSong B\t%s\n' "$T/media/songA.wav" "$T/media/songB.wav" > "$T/data/playlists/AlarmList.tsv"
out=$(tunes alarm 07:30 AlarmList 2>&1);          assert_contains "alarm is armed" "$out" "Alarm set"
assert_contains "status shows the countdown" "$(tunes alarm status)" "rings in"
out=$(tunes alarm off 2>&1);                      assert_contains "alarm off cancels" "$out" "cancelled"
assert_contains "…and status agrees" "$(tunes alarm status)" "No alarm set"
bash "$TUNES" __alarm_run 1 AlarmList >/dev/null 2>&1
if wait_for bash -c "bash '$TUNES' status | grep -q Playing"; then ok "alarm starts the playlist when it rings"; else bad "alarm starts the playlist when it rings"; fi
assert_contains "…and it is the alarm playlist" "$(tunes ctl queue)" "Song A"
stop_all

section "Smart playlists from stats (top --save, forgotten)"
SD="$T/smart"; mkdir -p "$SD"
now=$(date +%s); old=$((now - 120 * 86400))
{
  for i in 1 2 3 4 5; do printf '%s\tmusic\t200\t210\tOld Fave\tArtist O\t%s\n' $((old + i * 60)) "$T/media/songA.wav"; done
  for i in 1 2 3 4 5; do printf '%s\tmusic\t200\t210\tRecent Hit\tArtist R\t%s\n' $((now - i * 3600)) "$T/media/songB.wav"; done
  printf '%s\tmusic\t200\t210\tRare\tArtist X\t%s\n' $((old + 9000)) "$T/media/rare.wav"
} > "$SD/plays.tsv"
out=$(tunes_in "$SD" top all --save Favs 2>&1);     assert_contains "top --save reports what it saved" "$out" "Saved 3 tracks"
check "playlist file has 3 tracks" test "$(grep -c . "$SD/playlists/Favs.tsv")" -eq 3
tunes_in "$SD" top all --save Favs >/dev/null 2>&1
check "saving again does not duplicate tracks" test "$(grep -c . "$SD/playlists/Favs.tsv")" -eq 3
tunes_in "$SD" top week --save W >/dev/null 2>&1
check "period filter applies (only the recent track)" test "$(grep -c . "$SD/playlists/W.tsv")" -eq 1
assert_contains "…and it is the right one" "$(cat "$SD/playlists/W.tsv")" "Recent Hit"
tunes_in "$SD" top all -n 1 --save One >/dev/null 2>&1
check "-n limits the number of tracks" test "$(grep -c . "$SD/playlists/One.tsv")" -eq 1
out=$(tunes_in "$SD" top --save 2>&1); rc=$?;       check "top --save without a name is rejected" test $rc -ne 0
out=$(tunes_in "$SD" top -n abc 2>&1); rc=$?;       check "top -n abc is rejected" test $rc -ne 0
tunes_in "$SD" forgotten --save F >/dev/null 2>&1
check "forgotten: only the long-missing favourite" test "$(grep -c . "$SD/playlists/F.tsv")" -eq 1
assert_contains "…it is the old favourite" "$(cat "$SD/playlists/F.tsv")" "Old Fave"
tunes_in "$SD" forgotten 30 --min-plays 1 --save F2 >/dev/null 2>&1
check "forgotten --min-plays 1 also finds the rare track" test "$(grep -c . "$SD/playlists/F2.tsv")" -eq 2
assert_not_contains "…but never the track played recently" "$(cat "$SD/playlists/F2.tsv")" "Recent Hit"
out=$(tunes_in "$SD" forgotten 500 2>&1);           assert_contains "nothing forgotten within 500 days" "$out" "Nothing forgotten"
out=$(tunes_in "$SD" forgotten banana 2>&1); rc=$?; check "forgotten rejects a bad argument" test $rc -ne 0

section "Playlist import / export (M3U)"
tunes playlist export Mine "$T/out.m3u" >/dev/null 2>&1
m3u=$(cat "$T/out.m3u" 2>/dev/null)
assert_contains "export writes an extended M3U" "$m3u" "#EXTM3U"
assert_contains "…with titles" "$m3u" "#EXTINF:-1,Song A"
assert_contains "…and locations" "$m3u" "$T/media/songA.wav"
out=$(tunes playlist import "$T/out.m3u" Copy 2>&1); assert_contains "import reports the count" "$out" "Imported 2 tracks"
assert_contains "titles survive the round trip" "$(cat "$T/data/playlists/Copy.tsv")" "Song B"
tunes playlist import "$T/out.m3u" Copy >/dev/null 2>&1
check "importing twice does not duplicate" test "$(grep -c . "$T/data/playlists/Copy.tsv")" -eq 2
mkdir -p "$T/lists"; printf '../media/songA.wav\r\n\r\n# a comment\r\nhttps://example.com/x.mp3\r\n' > "$T/lists/rel.m3u"
tunes playlist import "$T/lists/rel.m3u" Rel >/dev/null 2>&1
rel=$(cat "$T/data/playlists/Rel.tsv")
assert_contains "relative paths resolve against the m3u folder" "$rel" "$T/lists/../media/songA.wav"
assert_contains "URLs are kept as-is" "$rel" "https://example.com/x.mp3"
check "comments, blank lines and CRLF are handled" test "$(grep -c . "$T/data/playlists/Rel.tsv")" -eq 2
out=$(tunes playlist import "$T/nope.m3u" 2>&1); rc=$?; check "import of a missing file fails" test $rc -ne 0
out=$(tunes playlist export Nonexistent "$T/x.m3u" 2>&1); rc=$?; check "export of a missing playlist fails" test $rc -ne 0

section "ListenBrainz scrobbling (mock server)"
mkdir -p "$T/lb"
cat > "$T/lbsrv.py" <<'EOF'
import http.server, sys
d, n = sys.argv[1], [0]
class H(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        body = self.rfile.read(int(self.headers.get('Content-Length', 0)))
        auth = self.headers.get('Authorization', '')
        if self.path != '/1/submit-listens' or auth == 'Token bad':
            self.send_response(401); self.end_headers(); self.wfile.write(b'{"code":401}'); return
        n[0] += 1
        open('%s/req-%d.json' % (d, n[0]), 'wb').write(body)
        open('%s/auth-%d.txt' % (d, n[0]), 'w').write(auth)
        self.send_response(200); self.send_header('Content-Type', 'application/json'); self.end_headers(); self.wfile.write(b'{"status":"ok"}')
    def log_message(self, *a): pass
srv = http.server.HTTPServer(('127.0.0.1', 0), H)
open(d + '/port', 'w').write(str(srv.server_address[1]))
srv.serve_forever()
EOF
python3 "$T/lbsrv.py" "$T/lb" & LLM_PIDS+=($!)
wait_for test -s "$T/lb/port"; LBPORT=$(cat "$T/lb/port")
SB="$T/scrob"; mkdir -p "$SB"; b=$(date +%s)
{
  printf '%s\tmusic\t200\t210\tSong One\tArtist A - Topic\thttp://x/1\n' $((b - 3000))
  printf '%s\tmusic\t5\t210\tSkipped\tArtist B\thttp://x/2\n'         $((b - 2900))
  printf '%s\tpodcast\t3000\t3600\tEpisode\tSome Pod\thttp://x/3\n'  $((b - 2800))
  printf '%s\tmusic\t200\t210\tNo Artist\t\thttp://x/4\n'             $((b - 2700))
  printf '%s\tmusic\t100\t200\tSong Two\tArtist C\t/music/two.mp3\n' $((b - 2600))
  printf '%s\tmusic\t200\t210\tSong Three\tArtist D\thttp://x/6\n'   $((b - 2500))
} > "$SB/plays.tsv"
LBENV=(LISTENBRAINZ_URL="http://127.0.0.1:$LBPORT")
out=$(env "${LBENV[@]}" TUNES_DATA_DIR="$SB" bash "$TUNES" scrobble 2>&1); rc=$?
check "no token → fails" test $rc -ne 0
assert_contains "…and tells you where to get one" "$out" "listenbrainz.org/settings"
out=$(env "${LBENV[@]}" TUNES_DATA_DIR="$SB" bash "$TUNES" scrobble --dry-run 2>&1)
assert_contains "dry run counts only real music plays" "$out" "3 listens would be submitted"
check "…and sends nothing" test ! -e "$T/lb/req-1.json"
out=$(env "${LBENV[@]}" LISTENBRAINZ_TOKEN=tok123 TUNES_DATA_DIR="$SB" bash "$TUNES" scrobble 2>&1)
assert_contains "scrobble submits the 3 counted plays" "$out" "Submitted 3 listens"
assert_contains "token is sent in the Authorization header" "$(cat "$T/lb/auth-1.txt" 2>/dev/null)" "Token tok123"
req="$T/lb/req-1.json"
check "payload is an import of 3 listens" jq -e '.listen_type == "import" and (.payload | length) == 3' "$req"
check "'- Topic' suffix is stripped from artists" jq -e '.payload[0].track_metadata.artist_name == "Artist A"' "$req"
check "track names and timestamps are sent" jq -e '.payload[0].track_metadata.track_name == "Song One" and (.payload[0].listened_at | type) == "number"' "$req"
check "local files get no origin_url" jq -e '.payload[1].track_metadata.additional_info | has("origin_url") | not' "$req"
check "client is identified as tunes" jq -e '.payload[0].track_metadata.additional_info.submission_client == "tunes"' "$req"
out=$(env "${LBENV[@]}" LISTENBRAINZ_TOKEN=tok123 TUNES_DATA_DIR="$SB" bash "$TUNES" scrobble 2>&1)
assert_contains "second run has nothing new (cursor saved)" "$out" "Nothing new"
out=$(env "${LBENV[@]}" LISTENBRAINZ_TOKEN=tok123 TUNES_DATA_DIR="$SB" bash "$TUNES" scrobble --all 2>&1)
assert_contains "--all re-sends the whole history" "$out" "Submitted 3 listens"
out=$(env "${LBENV[@]}" LISTENBRAINZ_TOKEN=bad TUNES_DATA_DIR="$SB" bash "$TUNES" scrobble --all 2>&1); rc=$?
check "a rejected token fails" test $rc -ne 0
assert_contains "…with a helpful message" "$out" "rejected"
out=$(LISTENBRAINZ_TOKEN=secret123 tunes config show 2>&1)
assert_not_contains "token is masked in config show" "$out" "secret123"
out=$(tunes config set LISTENBRAINZ_URL ftp://nope 2>&1); rc=$?; check "LISTENBRAINZ_URL must be http(s)" test $rc -ne 0

section "Backup & restore"
BK="$T/bk"; mkdir -p "$BK/playlists"
printf 'x\n' > "$BK/plays.tsv"; printf 'Fav\thttp://f\n' > "$BK/favorites.tsv"; printf 'T\thttp://t\n' > "$BK/playlists/X.tsv"
mkdir -p "$T/bkout"
for i in 01 02 03 04 05 06 07 08 09 10 11; do : > "$T/bkout/tunes-backup-2020010100$i.tar.gz"; touch -d "2020-01-$i" "$T/bkout/tunes-backup-2020010100$i.tar.gz"; done
out=$(tunes_in "$BK" backup "$T/bkout" 2>&1); assert_contains "backup reports the archive" "$out" "Backup saved"
arc=$(ls -1t "$T/bkout"/tunes-backup-2*.tar.gz | head -n1)
listing=$(tar -tzf "$arc" 2>&1)
assert_contains "archive holds the play log" "$listing" "plays.tsv"
assert_contains "…favourites" "$listing" "favorites.tsv"
assert_contains "…and playlists" "$listing" "playlists/X.tsv"
assert_not_contains "…but never settings or API keys" "$listing" "config"
check "only the newest 10 backups are kept" test "$(ls -1 "$T/bkout"/tunes-backup-*.tar.gz | wc -l)" -eq 10
rm -f "$BK/plays.tsv" "$BK/playlists/X.tsv"
out=$(tunes_in "$BK" restore "$arc" -y 2>&1); assert_contains "restore reports success" "$out" "Restored"
check "play log is back" test -s "$BK/plays.tsv"
check "playlist is back" test -s "$BK/playlists/X.tsv"
out=$(echo n | tunes_in "$BK" restore "$arc" 2>&1); assert_contains "restore asks first and honours 'n'" "$out" "Cancelled"
python3 - "$T/evil.tar.gz" <<'EOF'
import tarfile, io, sys
with tarfile.open(sys.argv[1], 'w:gz') as t:
    i = tarfile.TarInfo('../evil.txt'); i.size = 2; t.addfile(i, io.BytesIO(b'hi'))
EOF
out=$(tunes_in "$BK" restore "$T/evil.tar.gz" -y 2>&1); rc=$?
check "archive with a ../ path is refused" test $rc -ne 0
check "…and nothing was written outside the data dir" test ! -e "$T/evil.txt"
out=$(tunes_in "$BK" restore "$T/missing.tar.gz" 2>&1); rc=$?; check "restore of a missing file fails" test $rc -ne 0

section "Self-update (local file:// source)"
cp "$TUNES" "$T/tunes_copy"
sed 's/^TUNES_VERSION=.*/TUNES_VERSION="99.0.0"/' "$TUNES" > "$T/tunes_newer"
sed 's/^TUNES_VERSION=.*/TUNES_VERSION="0.0.1"/' "$TUNES" > "$T/tunes_older"
echo 'rm -rf /' > "$T/tunes_junk"
out=$(TUNES_UPDATE_URL="file://$T/tunes_newer" bash "$T/tunes_copy" update --check 2>&1)
assert_contains "--check sees the newer version" "$out" "99.0.0"
assert_contains "--check never installs it" "$(bash "$T/tunes_copy" --version)" "tunes 2."
out=$(TUNES_UPDATE_URL="file://$T/tunes_junk" bash "$T/tunes_copy" update -y 2>&1); rc=$?
check "a non-tunes file is refused" test $rc -ne 0
assert_contains "…with a clear reason" "$out" "does not look like a valid tunes script"
out=$(TUNES_UPDATE_URL="file://$T/tunes_older" bash "$T/tunes_copy" update -y 2>&1)
assert_contains "an older remote is not installed" "$out" "newer than the published"
out=$(echo n | TUNES_UPDATE_URL="file://$T/tunes_newer" bash "$T/tunes_copy" update 2>&1)
assert_contains "update asks first and honours 'n'" "$out" "Cancelled"
out=$(TUNES_UPDATE_URL="file://$T/tunes_newer" bash "$T/tunes_copy" update -y 2>&1)
assert_contains "update -y installs" "$out" "Updated to 99.0.0"
assert_contains "the script is now the new version" "$(bash "$T/tunes_copy" --version)" "99.0.0"
check "the previous version is kept as .bak" test -f "$T/tunes_copy.bak"
out=$(TUNES_UPDATE_URL="file://$T/tunes_newer" bash "$T/tunes_copy" update 2>&1)
assert_contains "running it again says up to date" "$out" "up to date"
out=$(TUNES_UPDATE_URL="file://$T/does_not_exist" bash "$T/tunes_copy" update 2>&1); rc=$?
check "an unreachable source fails cleanly" test $rc -ne 0

section "Local library"
tunes -d local "$T/media" >/dev/null 2>&1
if wait_for bash -c "bash '$TUNES' status | grep -q Playing"; then ok "local plays the audio files in a folder"; else bad "local plays the audio files in a folder"; fi
q=$(tunes ctl queue); assert_contains "…as a queue (songA)" "$q" "songA"; assert_contains "…as a queue (songB)" "$q" "songB"
stop_all
mkdir -p "$T/emptydir"
assert_contains "empty folder is graceful" "$(tunes local "$T/emptydir" 2>&1)" "No audio files"
out=$(tunes local "$T/not-a-folder" 2>&1); rc=$?; check "missing folder fails with a hint" test $rc -ne 0
assert_contains "…naming MUSIC_DIR" "$out" "MUSIC_DIR"

section "Shareable report card"
out=$(tunes_in "$SD" report --card week 2>&1)
assert_contains "card has a headline" "$out" "🎧 My listening"
assert_contains "…play count" "$out" "5 plays"
assert_contains "…top track" "$out" "Top track: Recent Hit — Artist R"
assert_contains "…top artist" "$out" "Top artist: Artist R"
assert_contains "…and a hashtag" "$out" "#tunes"
assert_not_contains "card is plain text (no ANSI colours)" "$out" $'\033'
mkdir -p "$T/emptystats"
assert_contains "empty period is graceful" "$(tunes_in "$T/emptystats" report --card 2>&1)" "No plays logged"

section "Help & completion list the new commands"
h=$(tunes help)
for w in "tunes sleep" "tunes alarm" "tunes scrobble" "tunes forgotten" "tunes backup" "tunes update" "tunes local" "playlist export" "--card" "--save NAME"; do assert_contains "help mentions: $w" "$h" "$w"; done
c=$(tunes completion)
for w in sleep alarm scrobble forgotten backup restore update local; do assert_contains "completion offers: $w" "$c" "$w"; done
assert_contains "config keys include the new settings" "$(tunes config show)" "LISTENBRAINZ_TOKEN"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[[ $fail -eq 0 ]]
