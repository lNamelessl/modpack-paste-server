# Modpack Paste Server

Paste a Modrinth modpack page URL and get a running modded Minecraft server, with the
world on a persistent volume, a live status page, and a healthcheck that never fails
because a 400 MB pack is still downloading.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/modpack-paste-server)

## Why this exists

Running a modpack server normally means picking a loader, matching a Forge or Fabric
build to a Minecraft version, downloading the pack, fixing client-only mods, and only
then inviting friends. This template collapses that into one variable: set
`MODPACK_URL` to a pack page and the container installs the pack, boots the server, and
tells you when it is actually accepting players.

## Quickstart

1. Deploy the template. It boots with Cobblemon Fabric (Minecraft 1.21.1) as a working default.
2. Open the service domain. The status page shows the current phase and the pack in use.
3. In Railway, open the service, then Settings, then Networking, and create a TCP proxy on port `25565`.
4. Copy the RCON password from the deploy log banner (it is also on the volume at `/data/.rcon-password`).
5. Put that host and port into Minecraft, install the same pack version on your client, and join.

To change packs, set `MODPACK_URL` to any other Modrinth pack page and Railway redeploys.
CurseForge page URLs also work once you add your own `CF_API_KEY`.

## Variables

| Variable | Default | What it does |
| --- | --- | --- |
| `MODPACK_URL` | `https://modrinth.com/modpack/cobblemon-fabric` | Modrinth pack page, bare Modrinth slug, or CurseForge pack page |
| `MEMORY` | `6G` | Java heap ceiling handed to the server |
| `MODPACK_VERSION` | unset | Optional Modrinth version pin, for example `1.8.4` |
| `CF_API_KEY` | unset | Your own CurseForge API key, only needed for CurseForge URLs |
| `RCON_PASSWORD` | generated | Overrides the per-deploy generated RCON password |
| `MC_VERSION` | unset | Optional Minecraft version override passed to the loader |

Nothing else has to be filled in. `EULA`, ports, `TYPE`, and the pack resolver are all
baked into the image and the entrypoint.

## HTTP surface

| Route | Status | Meaning |
| --- | --- | --- |
| `health` | always 200 while the supervisor runs | Platform healthcheck. Static file, zero external calls |
| `ready` | 200 after the JVM logs its `Done (` line, otherwise 404 | Real game readiness |
| `/` | 200 | Human status page, polls the two routes above |

## Layout

```
Dockerfile             itzg/minecraft-server pinned by digest, plus busybox httpd
scripts/entrypoint.sh  supervisor: pack resolver, RCON seed, health surface, exec
www/index.html         status page
www/health             seed for the liveness route
railway.json           DOCKERFILE build, dotless healthcheck, ON_FAILURE restarts
```

## Honest limits

* `health` proves the supervisor is alive, not that Minecraft booted. Use `ready` for that.
  The split is deliberate: a large pack takes minutes to install and the platform
  healthcheck should not kill a good deploy because of it.
* One replica only. The world volume at `/data` cannot be shared between replicas.
* Modded servers are memory hungry. Below 4 GB many packs crash on world load; this
  default is 6 GB and Railway bills by the minute while the server runs.
* Cold starts download the pack again only when it changes, but the first boot of a big
  pack can take several minutes.
* The Minecraft EULA is accepted for you (`EULA=TRUE`). Deploying means you accept it
  for your own server.
* No automated world backups. Snapshots are your job.
* The TCP proxy for port 25565 is a one-time manual step in the dashboard.

## Image provenance

| Image | Reference | Why pinned |
| --- | --- | --- |
| `itzg/minecraft-server` | `java21@sha256:96d1da46d7b59bce34e86d527fdcfdc92a9636e83fbf94a3bb279de6ae07c17c` | Upstream project that performs pack install and server boot |
| `busybox` | `1.36@sha256:73aaf090f3d85aa34ee199857f03fa3a95c8ede2ffd4cc2cdb5b94e566b11662` | Static httpd for the status surface, copied as a single binary |

Licence note: the Minecraft server software is governed by the Minecraft EULA, and
CurseForge API keys are issued per account and may not be shared. Neither is bundled here.
