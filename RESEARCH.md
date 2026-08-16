# Technical research notes

Initial research date: 2026-08-08. Compatibility refresh: 2026-08-16.

## Verified targets

- Fields of Mistria 1.0.2 (`FieldsOfMistria.exe` product/file version 1.0.2, Steam build 24619420).
- MOMI stable 0.15.1, tag `v0.15.1`, commit `c57d90b785cd8546b512c1a4cc99946fd04e5318`.
- MOMI `main` was also inspected at `b451d4ae52d688be2199613a61ccd6657de0e211`; stable-only APIs were chosen where `main` was ahead of the release.

### Compatibility refresh (0.2.3)

- Fields of Mistria 1.0.3 (`FieldsOfMistria.exe` product/file version 1.0.3, Steam build 24742087).
- MOMI/MMAPI stable 0.15.5, tag `v0.15.5`, commit `9b90ee213309e7aaca5870ac43272682b6f595ad`.
- MOMI 0.15.4 explicitly carries the 1.0.3 atlas and seam updates. The 0.15.5 hotfix changes only the `combat.damage` receiver surface; Find My Mistrian does not use that hook.
- MOMI 0.15.2 introduced device-agnostic and compound hotkey bindings. Version 0.2.3 now validates with `mmapi_hotkey_binding_from_name()` and registers with `mmapi_hotkey_register_binding()`, retaining `F6` as the default while accepting controller buttons and chords. The manifest requires 0.15.5 because its re-anchored catalog is the minimum safe installer for the current 1.0.3 hotfix.

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

## Iteration 2: UI and quest targets

- `RelationshipsMenu` exposes `polaroid.background`, whose vanilla size is 68×85 (64×81 for the alternate Spanish/French/Russian layout). The compact locator is aligned to that node's bottom edge. `field_zone` remains the untouched lower 61-pixel region and `detail_zone` remains the untouched gift area.
- The exact met state is `NPCS[npc_id].has_met()`. It reads the persistent T2R key `"{NpcId}_has_met"`; vanilla calls `set_has_met()` after a valid conversation and uses `has_met()` to reveal Relationship names and enable their entries.
- The active quest model is `QUEST_LOG.active.get(key) -> ActiveQuest.current_stage -> QuestTask.query_targets`. A parsed `QuestQueryType.Npc` contains the structured target in `npc_name`; `Quest.npc_for_icon` is presentation data and is not used.
- Vanilla's NPC interaction path also requires `fulfills_all_requirements(task.requirements, active.blackboard)`. The mod applies the same gate, so a collection phase does not expose a locator before its talk/delivery interaction is actionable.
- Across the Fields of Mistria 1.0.2 quest data, 312 stages contain exactly one NPC query and 89 contain none. No stage contains multiple NPC queries. The implementation nevertheless rejects future ambiguous stages conservatively.
- MOMI 0.15.1's `ui.menu_refreshed` emit sites are limited to Toolbar and Vitals. Quest Log rebuilds are therefore tracked by an idempotent node outside `right_body`; each new `right_scroller` receives at most one locator element.

## Automated validation

### Diagnostic logging contract

- MOMI/MMAPI 0.15.1 defaults its shared logging threshold to `Info`; `Debug` lines are discarded unless `log_level` is changed globally in `mod_data/mmapi/mmapi.json`.
- `Info` and `Debug` lines are buffered until 20 pending lines unless the mod calls `mmapi_log_flush(mod_name)`; `Warn` and `Error` flush immediately.
- Find My Mistrian 0.2.1 therefore treats its own `debug_logging` option as explicit opt-in, emits diagnostic transactions at `Info`, and flushes once after each locate/highlight boundary. It does not alter MMAPI's global logging level or affect other mods.

### Duplicate map-icon lifecycle

- A live 0.2.1 trace captured three Juniper failures with `matches=2`; the chosen node was freed 7–10 ms after highlighting began.
- Vanilla `MapMenu.select_location()` calls `ANCHOR.free_children(self.map)` before rebuilding the selected region. Freed children remain discoverable until the following frame, so an immediate sprite search can select the stale copy when the NPC exists in both the initial and rebuilt map tree.
- Version 0.2.2 avoids rebuilding an already-selected region. After any selection it resolves on subsequent MMAPI ticks, ignores freed nodes, requires exactly one stable match, and retries for at most 30 frames. If vanilla invalidates the selected node later, the remaining pulse duration is transferred to a newly resolved live icon.
- The final in-game Juniper reproduction resolved one stable match on the first deferred attempt and completed the configured pulse in 10,014 ms with `node_freed=false`.

The official MOMI 0.15.5 CLI was run against the pristine 1.0.3 archive with:

```powershell
ModsOfMistriaInstaller-cli.exe --lint C:\absolute\path\to\find_my_mistrian C:\path\to\assets.bak.zip --strict-lints --compile-check require
```

Result:

```text
lint chikedor.find_my_mistrian v0.2.3
  gml: 1 file(s) installing under scripts/chikedor_find_my_mistrian/
  RESULT: OK - the apply would install this mod
```

MOMI 0.15.5's folder lint currently needs an absolute mod path to detect the `gml/` tree reliably. With a relative path, `FolderMod.GetAllFiles()` returns absolute file names while `GetBasePath()` remains relative, so `GmlModCollector.RelativePath()` fails to reduce them to `gml/...` and reports a manifest-only false positive. This was reproduced with the release CLI and confirmed against tag `v0.15.5` source.

Runtime scenarios in the package README remain a manual in-game checklist; compile/install validation cannot prove input feel, overlap at every UI scale, or festival-specific game state without playing a save.
