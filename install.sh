#!/usr/bin/env bash
# d3face installer - tahan 404, CDN mati, dan jaringan jelek
# pakai: bash install.sh [-r] [--repo owner/name] [--branch BR] [--mirror URL]
set -uo pipefail

APP="d3face"
FILE="d3face.sh"
DEF_REPO="skyyror/d3face"
DEF_BRANCH="main"

RUN_NOW=0
MIRROR=""
REPO_IN=""
BRANCH_IN=""

say()  { printf '\033[96m[*]\033[0m %s\n' "$*"; }
ok()   { printf '\033[92m[+]\033[0m %s\n' "$*"; }
warn() { printf '\033[93m[!]\033[0m %s\n' "$*"; }
die()  { printf '\033[91m[x]\033[0m %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

help() {
  cat <<EOF
$APP installer

  bash install.sh                 pasang
  bash install.sh -r              pasang lalu langsung jalankan
  bash install.sh --repo o/r      repo lain
  bash install.sh --branch dev    branch lain
  bash install.sh --mirror URL    paksa satu sumber unduhan
EOF
}

while [ $# -gt 0 ]; do
  case $1 in
    -r|--run)   RUN_NOW=1; shift ;;
    --mirror)   MIRROR=${2:-};   shift 2 2>/dev/null || shift ;;
    --repo)     REPO_IN=${2:-};  shift 2 2>/dev/null || shift ;;
    --branch)   BRANCH_IN=${2:-}; shift 2 2>/dev/null || shift ;;
    -h|--help)  help; exit 0 ;;
    *)          warn "argumen tak dikenal: $1"; shift ;;
  esac
done

trim() {
  local s=$1
  s=${s#"${s%%[![:space:]]*}"}
  s=${s%"${s##*[![:space:]]}"}
  printf '%s' "$s"
}

REPO=$(trim "${REPO_IN:-${D3FACE_REPO:-$DEF_REPO}}")
BRANCH=$(trim "${BRANCH_IN:-${D3FACE_BRANCH:-$DEF_BRANCH}}")

# bersihkan sisa tempelan yang bikin 404
REPO=${REPO#https://github.com/}
REPO=${REPO#http://github.com/}
REPO=${REPO#github.com/}
REPO=${REPO%%\?*}
REPO=${REPO%/}
REPO=${REPO%.git}
BRANCH=${BRANCH%%\?*}
BRANCH=${BRANCH#refs/heads/}
BRANCH=${BRANCH%/}

printf '%s' "$REPO" | grep -Eq '^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$' \
  || die "REPO tidak valid: '$REPO' (harus owner/nama, tanpa spasi/slash di ujung)"
printf '%s' "$BRANCH" | grep -Eq '^[A-Za-z0-9._-]+$' \
  || die "BRANCH tidak valid: '$BRANCH'"

say "repo: $REPO   branch: $BRANCH"

# ---------- dependensi ----------
if ! have curl && ! have wget; then
  if [ -n "${PREFIX:-}" ]; then
    say "memasang curl..."
    if have pkg; then pkg install curl -y || die "gagal memasang curl"
    elif have apt; then apt install curl -y || die "gagal memasang curl"
    else die "pasang curl dulu"; fi
  else
    die "curl dan wget tidak ada, pasang salah satu dulu"
  fi
fi

# ---------- tujuan ----------
if [ -n "${PREFIX:-}" ]; then BIN="$PREFIX/bin"; else BIN="$HOME/.local/bin"; fi
mkdir -p "$BIN" 2>/dev/null || die "tidak bisa membuat $BIN"
[ -w "$BIN" ] || die "$BIN tidak bisa ditulis"

# ---------- sumber ----------
TB="?t=$(date +%s)"
if [ -n "$MIRROR" ]; then
  SRC=("${MIRROR%/}/$FILE")
else
  SRC=(
    "https://raw.githubusercontent.com/$REPO/$BRANCH/$FILE$TB"
    "https://cdn.jsdelivr.net/gh/$REPO@$BRANCH/$FILE$TB"
    "https://raw.gitmirror.com/$REPO/$BRANCH/$FILE$TB"
    "https://ghproxy.net/https://raw.githubusercontent.com/$REPO/$BRANCH/$FILE$TB"
    "https://raw.githack.com/$REPO/$BRANCH/$FILE$TB"
    "https://github.com/$REPO/raw/$BRANCH/$FILE$TB"
  )
fi

fetch() { # url dest -> 0 sukses
  local u=$1 d=$2 code
  if have curl; then
    code=$(curl -fsSL --connect-timeout 10 -m 90 --retry 2 --retry-delay 2 \
                -A "d3face-installer" -w '%{http_code}' -o "$d" "$u" 2>/dev/null)
    [ -s "$d" ] && return 0
    [ -n "${code:-}" ] && [ "$code" != "000" ] && printf '%s' "$code" >&2
    return 1
  fi
  have wget && wget -q -T 25 -U "d3face-installer" -O "$d" "$u" 2>/dev/null && [ -s "$d" ]
}

valid() { # file -> 0 kalau memang skrip d3face
  local f=$1
  [ -s "$f" ] || return 1
  [ "$(wc -c <"$f" | tr -d ' ')" -ge 1000 ] || return 1
  head -c 300 "$f" | grep -qi '<html' && return 1
  head -n 1 "$f" | grep -q '^#!' || return 1
  grep -q 'd3face' "$f" || return 1
  have bash && ! bash -n "$f" 2>/dev/null && return 1
  return 0
}

# ---------- unduh ----------
TMP="$BIN/.$APP.part.$$"
trap 'rm -f "$TMP"' EXIT INT TERM

GOT=""
for u in "${SRC[@]}"; do
  say "coba ${u%%\?*}"
  if fetch "$u" "$TMP" && valid "$TMP"; then
    GOT=$u
    ok "berhasil dari ${u%%\?*}"
    break
  fi
  warn "gagal: ${u%%\?*}"
done

# jalan terakhir: git
if [ -z "$GOT" ] && have git; then
  say "coba lewat git clone..."
  CLONE="$BIN/.$APP.clone.$$"
  rm -rf "$CLONE"
  if git clone -q --depth 1 --branch "$BRANCH" "https://github.com/$REPO.git" "$CLONE" 2>/dev/null \
     && [ -f "$CLONE/$FILE" ] && cp "$CLONE/$FILE" "$TMP" && valid "$TMP"; then
    GOT="git"
    ok "berhasil dari git clone"
  fi
  rm -rf "$CLONE"
fi

[ -n "$GOT" ] || die "semua sumber gagal. cek koneksi, atau pakai: bash install.sh --mirror <URL>"
[ -s "$TMP" ] && valid "$TMP" || die "file hasil unduhan tidak valid"

chmod +x "$TMP" 2>/dev/null
mv -f "$TMP" "$BIN/$APP" || die "gagal memasang ke $BIN/$APP"
trap - EXIT INT TERM

ok "terpasang: $BIN/$APP"

# ---------- PATH ----------
case ":$PATH:" in
  *":$BIN:"*) ;;
  *)
    RC="$HOME/.bashrc"
    if ! grep -qsF "$BIN" "$RC" 2>/dev/null; then
      printf '\nexport PATH="%s:$PATH"\n' "$BIN" >>"$RC" 2>/dev/null \
        && { warn "PATH belum aktif di sesi ini"; say "jalankan: source $RC"; }
    fi
    ;;
esac

if have timeout; then
  V=$(timeout 10 "$BIN/$APP" --version 2>/dev/null) && [ -n "$V" ] && ok "cek jalan: $V"
fi

say "mulai dengan: $APP"
if [ "$RUN_NOW" = 1 ]; then
  exec "$BIN/$APP"
fi
exit 0
