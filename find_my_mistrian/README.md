# Find My Mistrian

Find My Mistrian is a small quality-of-life mod for Fields of Mistria. It adds a compact live-location button beneath the Relationships portrait and a locator for actionable NPC objectives in the Quest Log.

The mod reads `NPCS[npc_id].location_position`, the same current-state data used by the vanilla map. It does not calculate or ship NPC schedules.

Map highlighting waits for the selected region's icon tree to become stable, ignores stale nodes, and reacquires the live icon if vanilla rebuilds the tree during the pulse. This prevents dense maps from terminating the highlight on an obsolete duplicate icon.

## Requirements

- Fields of Mistria 1.0.x
- MOMI/MMAPI 0.15.6 or newer

Version 0.2.4 was validated against Fields of Mistria 1.0.4 (Steam build 24820767) and MOMI 0.15.6.

Full documentation is available in English and Spanish in the [project README](../README.md).

## Installation

1. Install the current release of [Mods of Mistria Installer (MOMI)](https://github.com/Garethp/Mods-of-Mistria-Installer).
2. Place the `find_my_mistrian` folder directly inside the game's `mods` folder.
3. Run MOMI and install the mod.

The folder containing this README must also contain `manifest.json`, `gml/`, `fiddle/`, and `localization/`.

## Usage

The mod activates automatically when the game starts after installation. `F6` does not enable or toggle it; it only opens **Journal → Relationships**. Set `enabled` to `false` in the config to disable all features without uninstalling.

1. Open the Journal and select **Relationships**. Alternatively, press `F6`.
2. Select a character you have met.
3. Select the compact location button beneath their portrait to open the correct map region and blink the character's existing map icon for a few seconds.
4. In **Quests**, select an active quest. A locator appears when the current objective has an actionable structured NPC target.

The Relationships location refreshes with the selected character. Quest controls refresh when the quest or stage changes and sit after objectives, before rewards. Collection-only, location/cutscene, and ambiguous multi-NPC phases do not show a locator.

Unknown or progression-locked characters are not made selectable by the mod and never reveal a location. A known character without a displayable live location gets a disabled control; a position that disappears after activation produces a cannot-locate notification. If vanilla draws no reusable map icon, the location can still be correct even though no pulse appears. When `open_map_after_locating` is `false`, activating a locator shows the character and live location in a notification instead of opening or pulsing the map.

## Configuration

The config is created lazily at:

`%LOCALAPPDATA%/FieldsOfMistria/mod_data/find_my_mistrian/find_my_mistrian.json`

Defaults:

```json
{
  "__config_version": 1,
  "enabled": true,
  "highlight_duration": 4,
  "open_map_after_locating": true,
  "hotkey": "F6",
  "debug_logging": false
}
```

`highlight_duration` accepts 1–10 seconds and applies only to map highlighting. `open_map_after_locating=false` switches to notification-only mode. `hotkey` opens Relationships and accepts a keyboard, controller, or compound MMAPI binding such as `F6`, `GAMEPAD_Y`, `SHIFT+F6`, or `GAMEPAD_LEFT_SHOULDER+GAMEPAD_A`; it never toggles the mod. Set `debug_logging` to `true` to record the entry point, selected NPC, live location, map region, icon-match count, highlight lifecycle, and failure reason without logging every frame. Each locate attempt is flushed immediately to `mod_data/find_my_mistrian/logs/find_my_mistrian.log`; no global MMAPI log-level change is required. Close the game before editing. Invalid values fall back to safe defaults when loaded.

## Localization

The mod includes English and Spanish (`spa`) UI text. Character and location names come from the game's own localization keys, so they follow the selected game language whenever a vanilla translation exists.

## Compatibility and limitations

- Read-only QoL/UI mod: it does not modify saves, relationships, routines, inventory, NPC positions, or gameplay.
- Location resolution uses the exact live state used by the 1.0.4 vanilla map.
- Named subrooms use their own localized name when available. Otherwise the mod falls back to another named room in the same building, then the containing map region.
- The highlight reuses and temporarily changes only the alpha of the vanilla NPC icon. It is restored after the configured duration and when the map closes.
- Mods that completely replace the Relationships, Quest Log, or Map menu internals may conflict. Event-based decoration is used instead of replacing vanilla constructors.
- A controller can move right from Relationships to the portrait locator and navigate quest locator buttons normally. MOMI 0.15.2 introduced controller and compound hotkey bindings; this release requires 0.15.6 for Fields of Mistria 1.0.4. Xbox button names describe physical positions on other controller layouts.

## Uninstallation

Remove the mod folder from `mods` and run MOMI again. Optionally delete `%LOCALAPPDATA%/FieldsOfMistria/mod_data/find_my_mistrian` to remove its config and logs.

## Manual validation checklist

- Exterior NPC and interior NPC.
- NPC changes building; rain; Saturday market; festival/event.
- Unknown and temporarily unavailable NPC.
- Repeated map open/close and several NPCs in succession.
- Save/load, sleep/day change, language switch, mouse/keyboard/controller.
- Reopen Relationships repeatedly and verify that no duplicate controls or callbacks appear.
- Quest without an NPC target; talk target; delivery target different from giver; objective progression; quest completion.
