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

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[[ $fail -eq 0 ]]
