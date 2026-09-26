# jgc-mrp-loading

Public Garry's Mod loading screen for **JGC M:RP** (Nato vs Russland).

- Live URL: https://markgrafde.github.io/jgc-mrp-loading/
- `index.html` reads `config.json` (cache-busted) and implements GMod `GameDetails(...)`.
- Columns: **Über uns** (inkl. Regeln/Links) | **Updates** | **Team** | **Info**.
- Default subtitle: `DU BETRITTST JETZT `.
- GitHub Actions (`sync-loading.yml`) pulls `joinscreen.json` + `joinscreen_staff.json` from the gameserver via SFTP every 5 minutes and updates `config.json`.

## Server

```
sv_loadingurl "https://markgrafde.github.io/jgc-mrp-loading/?steamid=%s&map=%m"
```

In-game source of truth: `jgc_rp` JoinScreen module (`!joinscreen_edit`).


## Actions sync note

The file `.github/workflows/sync-loading.yml` is prepared locally and SFTP secrets are set on the repo.
Pushing workflow files requires a GitHub token with the `workflow` scope (current `gh` OAuth app lacks it).
Until that is granted, run `scripts/sync-from-sftp.sh` periodically and `git push`, or re-auth `gh` with workflow scope and push the workflow.
