# ChunkHP implementation matrix

- Requirements: [REQUIREMENTS.md](REQUIREMENTS.md)
- Integration owner: Claude (sessions in this folder)
- Updated: 2026-11-10

## Implementation coverage

| Row | REQ IDs | Slice | Files | Status | Validation |
|---|---|---|---|---|---|
| IMP-001 | REQ-001, 002, 004 | Target-frame flash + trail overlay | ChunkHP.lua | implemented | V-001 static pass; V-002 in-game not run |
| IMP-002 | REQ-003, 004 | Nameplate attach/detach | ChunkHP.lua | implemented | V-003 informal pass |
| IMP-003 | REQ-005, 008 | Options > AddOns page (checkboxes and sliders) | ChunkHP.lua | implemented | V-004 informal pass |
| IMP-004 | REQ-006 | Slash command incl. `options` | ChunkHP.lua | implemented | V-004 informal pass |
| IMP-006 | REQ-009 | Options preview: fake bar, Hit/Big hit/Heal/Auto | ChunkHP.lua, ChunkHPPreview.xml, Locales/Base.lua | implemented | V-006 not run |
| IMP-007 | REQ-010 | Style presets: dropdown, apply/Custom logic, colors re-applied on Reset, slash `preset` | ChunkHP.lua, Locales/Base.lua | implemented | V-007 not run |
| IMP-008 | REQ-011 | Preview rebuilt as a default-nameplate copy (style/size aware), row height 150 | ChunkHP.lua, ChunkHPPreview.xml, Locales/Base.lua | implemented | V-008 not run |
| IMP-009 | REQ-011 | Preview fix after user screenshot: name text/font/anchor, level box, live sizes | ChunkHP.lua, Locales/Base.lua | implemented | V-008 (rerun) not run |
| IMP-010 | REQ-012 | Damage Numbers section: header, 3 CVar checkboxes, runtime-guarded size slider, restore-defaults button | ChunkHP.lua, Locales/Base.lua | implemented | V-009 not run |
| IMP-011 | REQ-013 | Rename to ChunkHP (code, files, folder, settings migration) + release zip + CurseForge listing draft | all files, docs/CURSEFORGE.md, ../ChunkHP-1.5.0.zip | implemented | V-010 not run |
| IMP-005 | REQ-007 | English catalog, loaded first in TOC | Locales/Base.lua, ChunkHP.toc | implemented | V-001 key check pass |

## Validation evidence

| ID | Mode | Procedure / expected | Result |
|---|---|---|---|
| V-001 | static | Lua 5.1 parse of both files with luaparse 0.3.1; every `L.KEY` used exists in Base.lua; Settings signatures compared with the Forever pin | pass (2026-11-10) |
| V-002 | in-game | Enable the addon and `/reload`. Attack a training dummy or mob with it targeted. Expect a white flash on the lost slice and an orange trail that drains, with no Lua errors. Then heal a friendly target and expect no effect. | pass, informal (user: "looks good", 2026-11-10; items not confirmed one by one) |
| V-003 | in-game | With nameplates on, hit a mob: its plate shows the effect. Swap targets and let plates leave the screen: no errors and no stuck orange bars. | pass, informal (user: "looks good", 2026-11-10; items not confirmed one by one) |
| V-004 | in-game | Esc > Options > AddOns > ChunkHP: 4 checkboxes and 2 sliders are present with tooltips. Untick "Flash the lost health" and hit a mob: no flash. Set trail hold to 1.0 and the trail visibly waits longer. Check that it persists after `/reload` and after a relog. `/chunkhp options` opens the page. Controller: the page is reachable and adjustable with a gamepad. | pass, informal (user: "looks good", 2026-11-10; items not confirmed one by one) |
| V-006 | in-game | Open Options > AddOns > ChunkHP. Expect the preview at the top. Click Hit and Big hit: the flash and trail appear with the slider timings. Heal shows no effect. Untick Flash and the preview shows only the trail. Auto keeps hitting and refills when low, and stops when you close the page. Gamepad: check whether the buttons are reachable. | not run |
| V-007 | in-game | Options > AddOns > ChunkHP: the Style dropdown lists 5 presets plus Custom, each with a tooltip. Picking each one changes the checkboxes, sliders and preview colors right away. Hits on a real target use the new colors. Moving a slider switches Style to Custom. `/chunkhp preset fighting` works. The choice persists through `/reload`. | not run |
| V-008 | in-game / visual | Put the ChunkHP preview next to Esc > Options > Nameplates' own preview (screenshots). Expect the same framed box and "Preview" label, the same bar art, height and width, and the name above the bar. Change Nameplate Style (Thin, Modern, Block) and Size, reopen the ChunkHP page, and the preview matches each. The flash and trail still show past the fill, and the buttons sit below the box without overlapping. | Rerun after IMP-009: not run. First run, 2026-11-10 (user screenshot): fail. The name read "Target Name" and was small and left-aligned, there was no level box, and the bar was thinner than the real plate; fixed in IMP-009, needs a rerun. |
| V-009 | in-game | The ChunkHP page shows a "Damage Numbers" header with 3 checkboxes. Untick "Show damage on targets", then hit a mob: no numbers appear, and Blizzard's Combat > floating combat text menu shows Damage off too. If a "Number size" slider appears, 2.0x makes the numbers clearly bigger. Restore defaults turns everything back on with size 1.0, and nothing is lost after `/reload`. Record whether the size slider appeared. | not run |
| V-010 | in-game | Fully exit and restart the game (not `/reload`). The AddOns list shows ChunkHP and not HitTrail. Options > AddOns shows "ChunkHP", the Style still says Classic MMO, and `/chunkhp` and `/hittrail` both print help. No Lua errors. | not run |
| V-005 | in-game | Look at the frame art: the overlay must not draw over the target-frame border or nameplate border. | pass, informal (user: "looks good", 2026-11-10; items not confirmed one by one) |

## Resume checkpoint

- Repository: git, https://github.com/dmackerman/wow-addon-chunkhp, branch `main` (first commit 3e6ab4a, 2026-11-10), checked out at `AddOns/ChunkHP`. Release zip `AddOns/ChunkHP-1.5.0.zip` sits outside the repo.
- Last completed slice: IMP-011 (rename to ChunkHP, release zip, CurseForge draft), 2026-11-10.
- Next executable action: the user fully restarts the game and runs V-010, then V-009. The user uploads `ChunkHP-1.5.0.zip` to CurseForge (Forever flavor) using docs/CURSEFORGE.md. Possible next work: color pickers (DEC-003), translations, a GitHub repo + packager for automatic releases.
- Open questions: whether to add color pickers (DEC-003); whether to add translations.
- Testing choice: Witchcraft in-game (user, 2026-11-10). It isn't installed, so the user chose to test by hand ("I'll test by hand", 2026-11-10). Record their reported results under V-002 to V-005.
- Controller: overlays are passive. The options page uses stock controls, and a gamepad check is pending (V-004).
- Options/localization: REQ-005/007 implemented. English only, no translations reviewed.
