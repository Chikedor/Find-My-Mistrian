# Technical research notes

Research date: 2026-08-08.

## Verified targets

- Fields of Mistria 1.0.2 (`FieldsOfMistria.exe` product/file version 1.0.2, Steam build 24619420).
- MOMI stable 0.15.1, tag `v0.15.1`, commit `c57d90b785cd8546b512c1a4cc99946fd04e5318`.
- MOMI `main` was also inspected at `b451d4ae52d688be2199613a61ccd6657de0e211`; stable-only APIs were chosen where `main` was ahead of the release.

## Confirmed engine/API contracts

- `NPCS[npc_id].location_position` is a `LocationPosition` containing `location_id`, `dyn_index`, and `pos`.
- Vanilla `MapMenu.select_location()` iterates unlocked NPCs and passes that same `location_position` to `find_hub_for()` before creating their icons.
- `LOCATIONS[location_id]` exposes `name`, `building`, and `map_location`. `name` is a vanilla localization key when present.
- `npc_is_unlocked(id)` and `NPCS[id].has_met()` are the vanilla progression/knowledge gates reused by Relationships and Map.
- `ui.menu_opened` provides `{ menu, kind }` after the menu is constructed and registered with `ANCHOR`.
- `ui.menu_closed` provides the cleanup edge used to restore a highlighted icon.
- `ANCHOR.spawn_menu(Menu.Journal)` plus `journal.set_active_sub_menu(Menu.Map)` is the vanilla map-opening path.
- MOMI 0.15.1 supports single keyboard hotkeys through `mmapi_hotkey_vk_from_name()` and `mmapi_hotkey_register()`.

## Design consequence

No schedule table, weather rule, festival rule, or NPC-location cache is used. The location is read only when the selected relationship entry changes or the player activates Locate. The only persistent per-frame work is a cheap inactive early return; while highlighting, it updates one existing icon's alpha and stops after the configured timeout.

## Automated validation

The official MOMI 0.15.1 CLI was run with:

```powershell
ModsOfMistriaInstaller-cli.exe --lint .\find_my_mistrian C:\path\to\assets.zip --strict-lints --compile-check require
```

Result:

```text
lint chikedor.find_my_mistrian v0.1.0
  gml: 1 file(s) installing under scripts/chikedor_find_my_mistrian/
  RESULT: OK - the apply would install this mod
```

Runtime scenarios in the package README remain a manual in-game checklist; compile/install validation cannot prove input feel, overlap at every UI scale, or festival-specific game state without playing a save.
