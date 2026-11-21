#!/usr/bin/env bash
set -eu
REPO="${D3FACE_REPO:-USER/d3face}"
BRANCH="${D3FACE_BRANCH:-main}"
RAW="https://raw.githubusercontent.com/$REPO/$BRANCH"

say() { printf '\033[96m[*]\033[0m %s\n' "$*"; }
die() { printf '\033[91m[!]\033[0m %s\n' "$*" >&2; exit 1; }

command -v curl >/dev/null 2>&1 || {
  if [ -n "${PREFIX:-}" ]; then say "memasang curl..."; pkg install curl -y
  else die "curl tidak ada, pasang dulu"; fi
}

if [ -n "${PREFIX:-}" ]; then BIN="$PREFIX/bin"; else BIN="$HOME/.local/bin"; fi
mkdir -p "$BIN"

say "mengunduh d3face..."
curl -fsSL "$RAW/d3face.sh" -o "$BIN/d3face" || die "unduhan gagal, cek REPO/BRANCH"
chmod +x "$BIN/d3face"

case ":$PATH:" in
  *":$BIN:"*) ;;
  *) RC="$HOME/.bashrc"
     printf '\nexport PATH="%s:$PATH"\n' "$BIN" >>"$RC"
     say "PATH ditambahkan ke $RC, jalankan: source $RC" ;;
esac

say "terpasang di $BIN/d3face"
say "mulai dengan: d3face"
[ "${1:-}" = "-r" ] && exec "$BIN/d3face"