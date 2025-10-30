#!/usr/bin/env bash
# scrolling ANSI MOTD helper (PuTTY-safe, tmux-friendly)

set -euo pipefail

ART_SOURCE="${ANSI_ART_DIR:-/usr/local/share/scrolling-motd/ansiart}"
RATE="${RATE_LIMIT:-7000}"
CLEAR_FIRST=1
MODE="auto"   # auto | putty | margins | tmux

ROWS=$(tput lines 2>/dev/null || printf '24')
case "$ROWS" in
  ''|*[!0-9]*) ROWS=24 ;;
  0) ROWS=24 ;;
esac
export LINES=$ROWS

usage() {
  cat <<'EOF' >&2
Usage: scrolling-motd.sh [--ansipath PATH|-f PATH] [--rate-limit N] [--no-clear] [--mode auto|putty|margins|tmux]
Options:
  --ansipath, -f   Path to an ANSI/ANS file or directory (default: /usr/local/share/scrolling-motd/ansiart)
  --rate-limit     Bytes/sec throttle for pv (default: env RATE_LIMIT or 7000)
  --no-clear       Do not clear the screen before drawing
  --mode           Force renderer: auto (default), putty (DECCOLM), margins (DECLRMM), tmux (popup)
  -h, --help       Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ansipath|-f) ART_SOURCE="${2:?}"; shift 2 ;;
    --rate-limit)  RATE="${2:?}"; shift 2 ;;
    --no-clear)    CLEAR_FIRST=0; shift ;;
    --mode)        MODE="${2:?}"; shift 2 ;;
    -h|--help)     usage; exit 0 ;;
    *)             echo "Ignoring unknown option: $1" >&2; shift ;;
  esac
done

move_cursor_bottom() {
  printf '\e[%s;1H' "$ROWS"
}

pick_random_art() {
  local path=$1
  if [[ -d "$path" ]]; then
    local selection
    selection=$(find "$path" -type f ! -name '.*' -print 2>/dev/null |
                awk 'BEGIN{srand();} { files[NR]=$0 } END { if (NR>0) { idx=int(rand()*NR)+1; print files[idx]; } }')
    if [[ -n "$selection" && -r "$selection" ]]; then
      printf '%s' "$selection"
      return 0
    fi
    return 1
  fi
  if [[ -f "$path" && -r "$path" ]]; then
    printf '%s' "$path"
    return 0
  fi
  return 1
}

ART_FILE=$(pick_random_art "$ART_SOURCE") || exit 0

if [[ "$MODE" == "auto" ]]; then
  if [[ -n "${TMUX-}" ]]; then
    MODE="tmux"
  else
    MODE="putty"
  fi
fi

render_putty() {
  printf '\e7'
  printf '\e[?3l'
  printf '\e[r\e[H'
  (( CLEAR_FIRST == 0 )) || tput clear || true
  iconv -f 437 -t UTF-8 "$ART_FILE" | pv --quiet --rate-limit "$RATE"
  printf '\e8'
  move_cursor_bottom
}

render_margins() {
  printf '\e[?69h'
  printf '\e[1;80s'
  printf '\e[?7h'
  printf '\e[H'
  (( CLEAR_FIRST == 0 )) || tput clear || true
  iconv -f 437 -t UTF-8 "$ART_FILE" | pv --quiet --rate-limit "$RATE"
  printf '\e[?69l'
  printf '\e[r'
  move_cursor_bottom
}

render_tmux() {
  local tmp_file
  tmp_file=$(mktemp 2>/dev/null || printf '/tmp/scrolling-motd.%s' "$$")
  if ! iconv -f 437 -t UTF-8 "$ART_FILE" >"$tmp_file" 2>/dev/null; then
    cp "$ART_FILE" "$tmp_file"
  fi

  local art_lines art_width pane_height pane_width client_width tmux_version popup_height popup_width popup_delay min_width border_cols borderless
  art_lines=$(wc -l <"$tmp_file" 2>/dev/null || printf '24')
  art_width=$(awk '{
      line = $0
      gsub(/\r/, "", line)
      while (match(line, /\033\[[0-9;?]*[ -\/]*[@-~]/)) {
        line = substr(line, 1, RSTART - 1) substr(line, RSTART + RLENGTH)
      }
      if (length(line) > max) {
        max = length(line)
      }
    } END { if (max > 0) print max }' "$tmp_file")
  pane_height=$(tmux display-message -p '#{pane_height}' 2>/dev/null || printf '24')
  pane_width=$(tmux display-message -p '#{pane_width}' 2>/dev/null || printf '80')
  client_width=$(tmux display-message -p '#{client_width}' 2>/dev/null || printf '0')
  tmux_version=$(tmux display-message -p '#{version}' 2>/dev/null || printf '')

  [[ $pane_height =~ ^[0-9]+$ && $pane_height -gt 0 ]] || pane_height=24
  [[ $pane_width  =~ ^[0-9]+$ && $pane_width  -gt 0 ]] || pane_width=80
  [[ $art_width   =~ ^[0-9]+$ && $art_width   -gt 0 ]] || art_width=80
  [[ $client_width =~ ^[0-9]+$ && $client_width -gt 0 ]] || client_width=0

  borderless=0
  if [[ $tmux_version =~ ^([0-9]+)\.([0-9]+) ]]; then
    local version_major=${BASH_REMATCH[1]}
    local version_minor=${BASH_REMATCH[2]}
    if (( version_major > 3 || (version_major == 3 && version_minor >= 4) )); then
      borderless=1
    fi
  fi

  popup_height=$((art_lines + 2))
  if (( popup_height > pane_height - 2 )); then
    popup_height=$((pane_height > 4 ? pane_height - 2 : pane_height))
  fi
  if (( popup_height > pane_height )); then
    popup_height=pane_height
  fi
  if (( popup_height < 3 )); then
    popup_height=$((pane_height > 3 ? pane_height : 3))
  fi
  if (( popup_height < 1 )); then
    popup_height=1
  fi

  border_cols=$(( borderless ? 0 : 2 ))
  popup_width=$((art_width + border_cols))
  if (( client_width > 0 && popup_width > client_width )); then
    popup_width=$client_width
  fi
  if (( popup_width > pane_width )); then
    popup_width=pane_width
  fi
  if (( popup_width > 200 )); then
    popup_width=200
  fi
  min_width=10
  if (( pane_width < min_width )); then
    min_width=$pane_width
  fi
  if (( popup_width < min_width )); then
    popup_width=$min_width
  fi
  if (( popup_width < 1 )); then
    popup_width=1
  fi

  popup_delay=${TMUX_POPUP_DELAY:-0}
  (( popup_delay < 0 )) && popup_delay=0

  local popup_shell=(bash -c "iconv -f 437 -t UTF-8 '$ART_FILE' | pv --quiet --rate-limit '$RATE'; read -r _ < /dev/tty")
  local popup_opts=()
  (( borderless )) && popup_opts+=(-B)
  popup_opts+=(-E -w "$popup_width" -h "$popup_height")
  if (( popup_delay > 0 )); then
    popup_opts+=(-d "$popup_delay")
  fi

  if ! tmux display-popup "${popup_opts[@]}" "${popup_shell[@]}"; then
    if (( borderless )); then
      borderless=0
      border_cols=2
      popup_width=$((art_width + border_cols))
      if (( client_width > 0 && popup_width > client_width )); then
        popup_width=$client_width
      fi
      if (( popup_width > pane_width )); then
        popup_width=pane_width
      fi
      if (( popup_width > 200 )); then
        popup_width=200
      fi
      if (( popup_width < min_width )); then
        popup_width=$min_width
      fi
      if (( popup_width < 1 )); then
        popup_width=1
      fi
      popup_opts=(-E -w "$popup_width" -h "$popup_height")
      if (( popup_delay > 0 )); then
        popup_opts+=(-d "$popup_delay")
      fi
      tmux display-popup "${popup_opts[@]}" "${popup_shell[@]}" || true
    fi
  fi

  rm -f "$tmp_file"
}

case "$MODE" in
  putty)   render_putty ;;
  margins) render_margins ;;
  tmux)    render_tmux ;;
  *)       echo "Unknown mode: $MODE" >&2 ;;
esac
