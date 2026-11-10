# ChunkHP

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
