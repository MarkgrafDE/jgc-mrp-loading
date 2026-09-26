#!/usr/bin/env bash
# Sync JoinScreen config from live GMod DATA → config.json (+ optional git push).
# Usage:
#   GMOD_SFTP_PASSWORD=... ./scripts/sync-from-sftp.sh
#   GMOD_SFTP_PASSWORD=... ./scripts/sync-from-sftp.sh --push
#   GMOD_SFTP_PASSWORD=... ./scripts/sync-from-sftp.sh --if-dirty   # skip if no dirty flag / unchanged mtime stamp
set -euo pipefail
: "${GMOD_SFTP_PASSWORD:?set GMOD_SFTP_PASSWORD}"
HOST="${GMOD_SFTP_HOST:-159.195.60.189}"
PORT="${GMOD_SFTP_PORT:-2022}"
USER="${GMOD_SFTP_USER:-markgraf.4eed8c94}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DO_PUSH=0
IF_DIRTY=0
for arg in "$@"; do
  case "$arg" in
    --push) DO_PUSH=1 ;;
    --if-dirty) IF_DIRTY=1 ;;
    -h|--help)
      echo "Usage: $0 [--push] [--if-dirty]"
      exit 0
      ;;
  esac
done

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export SSHPASS="$GMOD_SFTP_PASSWORD"

sshpass -e sftp -oStrictHostKeyChecking=no -P "$PORT" "$USER@$HOST" <<SFTP
get garrysmod/data/jgc_rp/joinscreen.json $TMP/joinscreen.json
get garrysmod/data/jgc_rp/joinscreen_staff.json $TMP/joinscreen_staff.json
bye
SFTP
# Dirty flag is optional (created after first Speichern / WriteExportFiles)
sshpass -e sftp -oStrictHostKeyChecking=no -P "$PORT" "$USER@$HOST" <<SFTP || true
get garrysmod/data/jgc_rp/joinscreen_dirty.txt $TMP/joinscreen_dirty.txt
bye
SFTP

STATE_DIR="$ROOT/.sync-state"
mkdir -p "$STATE_DIR"
LAST_FLAG="$STATE_DIR/last_dirty.flag"

if [[ "$IF_DIRTY" == "1" ]]; then
  if [[ ! -f "$TMP/joinscreen_dirty.txt" ]]; then
    echo "no dirty flag on server — skip"
    exit 0
  fi
  if [[ -f "$LAST_FLAG" ]] && cmp -s "$TMP/joinscreen_dirty.txt" "$LAST_FLAG"; then
    echo "dirty flag unchanged ($(cat "$TMP/joinscreen_dirty.txt")) — skip"
    exit 0
  fi
fi

# Prefer repo logo; also pull from server materials if present
if [[ -f "$ROOT/logo.png" ]]; then
  cp -f "$ROOT/logo.png" "$TMP/logo.png"
fi
sshpass -e sftp -oStrictHostKeyChecking=no -P "$PORT" "$USER@$HOST" <<SFTP || true
get garrysmod/materials/jgc_rp/logo.png $TMP/logo.png
bye
SFTP
if [[ -f "$TMP/logo.png" ]]; then
  cp -f "$TMP/logo.png" "$ROOT/logo.png"
fi

python3 - "$TMP" "$ROOT" <<'PY'
import json, sys, datetime, pathlib, re, urllib.request, time

tmp = pathlib.Path(sys.argv[1])
root = pathlib.Path(sys.argv[2])
cfg = json.loads((tmp / "joinscreen.json").read_text(encoding="utf-8"))
staff = json.loads((tmp / "joinscreen_staff.json").read_text(encoding="utf-8"))
if not isinstance(staff, list):
    staff = []

STEAM_ID_RE = re.compile(r"^STEAM_\d+:\d+:\d+$", re.I)
S64_RE = re.compile(r"^7656119\d{10,}$")

def looks_like_steamid(s: str) -> bool:
    s = str(s or "").strip()
    return bool(STEAM_ID_RE.match(s) or S64_RE.match(s))

def fetch_steam_xml(s64: str) -> str:
    s64 = str(s64 or "").strip()
    if not s64.isdigit() or len(s64) < 15:
        return ""
    url = f"https://steamcommunity.com/profiles/{s64}/?xml=1"
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "JGC-MRP-LoadingSync/1.1"})
        with urllib.request.urlopen(req, timeout=12) as resp:
            return resp.read().decode("utf-8", errors="replace")
    except Exception as e:
        print("steam xml fail", s64, e)
        return ""

def parse_avatar(body: str) -> str:
    for tag in ("avatarMedium", "avatarFull", "avatarIcon"):
        m = re.search(rf"<{tag}><!\[CDATA\[(.*?)\]\]></{tag}>", body)
        if m and m.group(1).startswith("http"):
            return m.group(1).strip()
    return ""

def parse_persona(body: str) -> str:
    m = re.search(r"<steamID><!\[CDATA\[(.*?)\]\]></steamID>", body)
    if not m:
        m = re.search(r"<steamID>([^<]+)</steamID>", body)
    if not m:
        return ""
    nick = m.group(1).strip()
    if not nick or looks_like_steamid(nick):
        return ""
    return nick

out_staff = []
for s in staff:
    row = dict(s) if isinstance(s, dict) else {}
    s64 = str(row.get("steamid64") or "").strip()
    sid = str(row.get("steamid") or "").strip()
    name = str(row.get("name") or "").strip()
    av = str(row.get("avatar") or "").strip()

    if "steamstatic.com/" in av and s64 and av.rstrip("/").endswith(f"{s64}.jpg"):
        av = ""

    need_name = (not name) or looks_like_steamid(name) or name == sid
    need_av = not av

    body = ""
    if s64 and (need_name or need_av):
        body = fetch_steam_xml(s64)
        time.sleep(0.35)

    if need_av and body:
        av = parse_avatar(body)
    if need_name and body:
        persona = parse_persona(body)
        if persona:
            name = persona
            print("resolved name", s64, "->", name)
        else:
            name = "Unbekannt"
            print("name fallback Unbekannt for", s64 or sid)
    elif need_name:
        name = "Unbekannt"

    row["name"] = name
    row["avatar"] = av
    if s64:
        row["steamid64"] = s64
    out_staff.append(row)

out = {
    "title": cfg.get("title") or "JGC M:RP",
    "subtitle_prefix": cfg.get("subtitle_prefix") or "DU BETRITTST JETZT ",
    "about": cfg.get("about") or "",
    "rules": cfg.get("rules") or [],
    "updates": cfg.get("updates") or [],
    "show_staff": cfg.get("show_staff", True),
    "autoshow": cfg.get("autoshow", cfg.get("autoshow_hint", True)),
    "staff": out_staff,
    "hostname_default": "JGC M:RP",
    "updated_at": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
}
(root / "config.json").write_text(json.dumps(out, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print("wrote config.json staff=", len(out_staff), "with_avatar=", sum(1 for s in out_staff if s.get("avatar")))
PY

# Remember dirty stamp so --if-dirty can skip next time
if [[ -f "$TMP/joinscreen_dirty.txt" ]]; then
  cp -f "$TMP/joinscreen_dirty.txt" "$LAST_FLAG"
fi

if [[ "$DO_PUSH" == "1" ]]; then
  cd "$ROOT"
  git add config.json index.html logo.png 2>/dev/null || true
  if git diff --cached --quiet; then
    echo "nothing to commit (config already up to date)"
  else
    git -c user.name="JGC Sync" -c user.email="joinscreen-sync@jgc.local" \
      commit -m "sync: JoinScreen config from gameserver DATA"
    git push origin HEAD:main
    echo "pushed to origin/main"
  fi
fi
