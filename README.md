# jgc-mrp-loading

Public Garry's Mod loading screen for **JGC M:RP** (Nato vs Russland).

- Live URL: https://markgrafde.github.io/jgc-mrp-loading/
- `index.html` reads `config.json` (cache-busted) and implements GMod `GameDetails(...)`.
- GitHub Actions (`sync-loading.yml`) pulls `joinscreen.json` + `joinscreen_staff.json` from the gameserver via SFTP every 5 minutes and updates `config.json`.

## Server

```
sv_loadingurl "https://markgrafde.github.io/jgc-mrp-loading/?steamid=%s&map=%m"
```

In-game source of truth: `jgc_rp` JoinScreen module (`!joinscreen_edit`).
