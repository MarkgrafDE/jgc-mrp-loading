#!/usr/bin/env bash
# Sync JoinScreen config from live GMod DATA + resolve Steam avatars via community XML.
set -euo pipefail
: "${GMOD_SFTP_PASSWORD:?}"
HOST="${GMOD_SFTP_HOST:-159.195.60.189}"
PORT="${GMOD_SFTP_PORT:-2022}"
USER="${GMOD_SFTP_USER:-markgraf.4eed8c94}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export SSHPASS="$GMOD_SFTP_PASSWORD"
sshpass -e sftp -oStrictHostKeyChecking=no -P "$PORT" "$USER@$HOST" <<SFTP
get garrysmod/data/jgc_rp/joinscreen.json $TMP/joinscreen.json
get garrysmod/data/jgc_rp/joinscreen_staff.json $TMP/joinscreen_staff.json
bye
SFTP

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

def resolve_avatar(s64: str) -> str:
    s64 = str(s64 or "").strip()
    if not s64.isdigit() or len(s64) < 15:
        return ""
    url = f"https://steamcommunity.com/profiles/{s64}/?xml=1"
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "JGC-MRP-LoadingSync/1.0"})
        with urllib.request.urlopen(req, timeout=12) as resp:
            body = resp.read().decode("utf-8", errors="replace")
    except Exception as e:
        print("avatar xml fail", s64, e)
        return ""
    for tag in ("avatarMedium", "avatarFull", "avatarIcon"):
        m = re.search(rf"<{tag}><!\[CDATA\[(.*?)\]\]></{tag}>", body)
        if m and m.group(1).startswith("http"):
            return m.group(1).strip()
    return ""

out_staff = []
for s in staff:
    row = dict(s) if isinstance(s, dict) else {}
    s64 = str(row.get("steamid64") or "").strip()
    if not s64 and row.get("steamid"):
        # leave steamid64 empty if not provided; sync expects server export
        pass
    av = str(row.get("avatar") or "").strip()
    # Drop broken steamid64.jpg CDN pattern if present
    if "steamstatic.com/" in av and av.rstrip("/").endswith(f"{s64}.jpg"):
        av = ""
    if not av and s64:
        av = resolve_avatar(s64)
        time.sleep(0.35)
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
