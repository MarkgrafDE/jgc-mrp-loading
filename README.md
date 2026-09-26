# jgc-mrp-loading

Public Garry's Mod loading screen for **JGC M:RP** (Nato vs Russland).

- Live URL: https://markgrafde.github.io/jgc-mrp-loading/
- `index.html` reads `config.json` with cache-bust (`?_=` + timestamp, `cache: 'no-store'`) and implements GMod `GameDetails(...)`.
- Columns: **Über uns** (inkl. Regeln/Links) | **Updates** | **Team** | **Info**.
- Default subtitle: `DU BETRITTST JETZT `.
- Layout is **fullscreen** (viewport-pinned) for GMod CEF loading screens.

## Server

```
sv_loadingurl "https://markgrafde.github.io/jgc-mrp-loading/?steamid=%s&map=%m"
```

In-game source of truth: `jgc_rp` JoinScreen module (`!jsedit` / `!joinscreen_edit`).
On Speichern the server writes `data/jgc_rp/joinscreen.json`, `joinscreen_staff.json`, and `joinscreen_dirty.txt`.

## Sync (Speichern → Pages)

GitHub Actions workflow push needs `workflow` OAuth scope (not available on the current `gh` token). Until then:

```bash
export GMOD_SFTP_PASSWORD=...
./scripts/sync-from-sftp.sh --push          # always pull + commit/push
./scripts/sync-from-sftp.sh --if-dirty --push  # only if dirty.txt changed
./scripts/push-config-from-sftp.sh         # alias for --push
```

**Recommended:** create a Grok Bot routine `@every 5m` that runs:

```bash
cd /workspace/jgc-mrp-loading && ./scripts/sync-from-sftp.sh --if-dirty --push
```

That picks up `!jsedit` Speichern within ~5 minutes (often sooner after a manual sync).
