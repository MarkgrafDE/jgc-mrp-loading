#!/usr/bin/env bash
# Pull server DATA → config.json → git push (for Speichern → Pages near-instant sync).
exec "$(cd "$(dirname "$0")" && pwd)/sync-from-sftp.sh" --push "$@"
