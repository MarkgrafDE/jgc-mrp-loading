#!/usr/bin/env bash
# Manual sync fallback until GH Actions workflow can be pushed (needs workflow scope).
set -euo pipefail
: "${GMOD_SFTP_PASSWORD:?}"
HOST="${GMOD_SFTP_HOST:-159.195.60.189}"
PORT="${GMOD_SFTP_PORT:-2022}"
USER="${GMOD_SFTP_USER:-markgraf.4eed8c94}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP=$(mktemp -d)
export SSHPASS="$GMOD_SFTP_PASSWORD"
sshpass -e sftp -oStrictHostKeyChecking=no -P "$PORT" "$USER@$HOST" <<SFTP
get garrysmod/data/jgc_rp/joinscreen.json $TMP/joinscreen.json
get garrysmod/data/jgc_rp/joinscreen_staff.json $TMP/joinscreen_staff.json
bye
SFTP
python3 - "$TMP" "$ROOT" <<'PY'
import json,sys,datetime,pathlib
tmp=pathlib.Path(sys.argv[1])
root=pathlib.Path(sys.argv[2])
cfg=json.loads((tmp/"joinscreen.json").read_text(encoding="utf-8"))
staff=json.loads((tmp/"joinscreen_staff.json").read_text(encoding="utf-8"))
out={
  "title": cfg.get("title") or "JGC M:RP",
  "subtitle_prefix": cfg.get("subtitle_prefix") or "YOU ARE NOW JOINING ",
  "about": cfg.get("about") or "",
  "rules": cfg.get("rules") or [],
  "show_staff": cfg.get("show_staff", True),
  "staff": staff if isinstance(staff, list) else [],
  "hostname_default": "JGC M:RP",
  "updated_at": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
}
(root/"config.json").write_text(json.dumps(out,indent=2,ensure_ascii=False)+"\n", encoding="utf-8")
print("wrote config.json staff=", len(out["staff"]))
PY
