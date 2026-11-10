# ChunkHP

<img src="media/logo.svg" alt="ChunkHP logo" width="160">

A World of Warcraft: **Forever** addon that makes damage *feel* like damage. When your target or a nameplate takes a hit, the lost health flashes, then lingers as a "ghost" chunk that drains away: the delayed health bar from fighting games, Soulslikes and JRPGs, on WoW's own frames.

## Features

- Works on the **target frame** and **nameplates**.
- **Flash** on the lost health, then a **draining trail** behind it.
- **Styles:** Classic MMO, Soulslike, Fighting Game, JRPG, Arcade, or Custom.
- **Live preview** in the options, drawn like a real nameplate in your Nameplate Style and Size.
- **Damage Numbers** shortcuts for the game's floating combat text on targets.
- Safe with Forever's secret health values: health only ever goes into `StatusBar:SetValue`, never into math.

## Install

Copy the `ChunkHP` folder into `World of Warcraft/_forever_/Interface/AddOns/`, then restart the game.

## Use

Esc > Options > AddOns > ChunkHP, or `/chunkhp` (`/chunkhp options`, `/chunkhp preset fighting`, `/chunkhp delay 0.5`, …).

## Compatibility

- WoW Forever, interface 16001 (build 1.60.1).
- Enemy nameplates inside instances are restricted by the game, so only the target frame shows the effect there.

## Development

- Requirements, decisions and test status: [docs/REQUIREMENTS.md](docs/REQUIREMENTS.md) and [docs/IMPLEMENTATION-MATRIX.md](docs/IMPLEMENTATION-MATRIX.md).
- Release zips contain only the `ChunkHP` folder without `docs/` (see `.pkgmeta`).

## Releasing

Pushing a tag like `v1.5.1` runs [.github/workflows/release.yml](.github/workflows/release.yml), which uses the [BigWigs packager](https://github.com/BigWigsMods/packager) to build `ChunkHP-v1.5.1.zip`, write a changelog from the commits, and publish a GitHub release.

1. Set `## Version` in `ChunkHP.toc` to the new version and commit.
2. `git tag v1.5.1` and `git push origin v1.5.1`.

To also upload to CurseForge (one-time setup):

1. Create the CurseForge project, then add its id (from the "About Project" box) to `ChunkHP.toc` as `## X-Curse-Project-ID: <id>`.
2. Create an API token at <https://legacy.curseforge.com/account/api-tokens> and add it to this repo under Settings > Secrets and variables > Actions as `CF_API_KEY`.

Tags with `alpha` or `beta` in the name (e.g. `v1.6.0-beta1`) are uploaded as Alpha/Beta files.
