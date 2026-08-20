# Find My Mistrian

> Find villagers without memorizing their schedules.

**Find My Mistrian** is a bilingual quality-of-life mod for **Fields of Mistria 1.0.x**. It shows the live location of a character you have already met and can open the correct map region while briefly highlighting that character's existing map icon.

[English](#english) · [Español](#español)

![Find My Mistrian showing Juniper's live location in the Spanish Relationships menu](docs/images/relationships-locator-spanish.png)

*Compact location control in Relationships / Control compacto de ubicación en Relaciones.*

![Find My Mistrian showing the Locate Celine action in an active Spanish quest](docs/images/quest-locator-spanish.png)

*The locator also appears for actionable NPC quest objectives / El localizador también aparece en objetivos ejecutables de Misiones que apuntan a un NPC.*

---

## English

### Features

- Shows a compact, clickable **location button beneath the portrait** on the Relationships page.
- Adds a **Locate NPC** button to an active quest when its current, actionable objective targets a known character.
- Opens the correct map region from either Relationships or Quests.
- Pulses the character's vanilla map icon for a few seconds so it is easy to spot.
- Adds a configurable shortcut to open Relationships quickly (`F6` by default), with keyboard, controller, and compound-binding support.
- Supports mouse, keyboard, and controller navigation.
- Includes English and Spanish interface text.
- Uses live game state—the same location data used by the vanilla map—instead of bundled or predicted schedules.
- Does not alter saves, schedules, relationships, inventory, NPC positions, or progression.

### Requirements

- [Fields of Mistria](https://www.fieldsofmistria.com/) 1.0.x
- [Mods of Mistria Installer (MOMI/MMAPI)](https://github.com/Garethp/Mods-of-Mistria-Installer) 0.15.6 or newer

Version 0.2.4 was validated against Fields of Mistria 1.0.4 (Steam build 24820767) with MOMI 0.15.6.

### Installation

1. Install MOMI and follow its setup instructions for Fields of Mistria.
2. Download this repository with **Code → Download ZIP**, then extract it.
3. Copy only the extracted [`find_my_mistrian`](find_my_mistrian) folder into the game's `mods` directory.
4. Confirm that the resulting layout is:

   ```text
   Fields of Mistria/
   ├── FieldsOfMistria.exe
   ├── mods/
   │   └── find_my_mistrian/
   │       ├── manifest.json
   │       ├── gml/
   │       ├── fiddle/
   │       └── localization/
   ```

5. Run MOMI, select **Find My Mistrian**, and install/apply the mod.
6. Start Fields of Mistria normally through Steam.

Do not copy the repository's outer `Find-My-Mistrian` folder into `mods`. MOMI must find `manifest.json` directly inside `mods/find_my_mistrian/`.

### How to use

The mod is active automatically after MOMI installs it and the game starts; **pressing `F6` is not required and does not toggle the mod**. `F6` is only a shortcut that opens **Journal → Relationships**. Set `enabled` to `false` in the configuration file if you want to disable all mod features without uninstalling it.

1. Load a save.
2. Press `F6`, or open **Journal → Relationships**.
3. Select a character you have met.
4. Their current location appears as a compact pin button beneath the portrait.
5. Select the location button. The appropriate map opens and the character's icon pulses for approximately four seconds.

The Relationships button refreshes whenever the selected character changes. For named interiors it shows the room name; unnamed subrooms fall back to another named room in the same building and then to the containing map region.

For quests, open **Journal → Quests** and select an active quest. A compact **Locate _name_** button appears after the current objectives and before rewards when the active objective has an actionable NPC conversation or delivery target. It updates when the quest or stage changes. Collection-only and location/cutscene objectives do not show a button, and ambiguous stages with multiple different NPC targets are deliberately ignored.

Characters you have not met remain hidden according to the game's normal progression rules. For a known character with no usable display location, Relationships shows a disabled **Unknown location** button and a quest locator is disabled. If the live position becomes unavailable after activation, the mod shows **Cannot locate this character right now**. If the map opens but vanilla draws no reusable icon, the location can still be correct even though no pulse appears.

If `open_map_after_locating` is `false`, selecting a locator displays an on-screen notification containing the character and current location instead. The map does not open and no icon pulse is attempted.

### Configuration

The configuration file is created after the mod first needs it:

```text
%LOCALAPPDATA%\FieldsOfMistria\mod_data\find_my_mistrian\find_my_mistrian.json
```

Default configuration:

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

| Option | Description |
| --- | --- |
| `enabled` | Enables or disables every mod feature without uninstalling it. The mod is enabled automatically by default. |
| `highlight_duration` | Icon pulse duration, from 1 to 10 seconds. It applies only when the map is opened. |
| `open_map_after_locating` | When `true`, opens the correct map region and pulses the icon. When `false`, shows the live location in a notification instead. |
| `hotkey` | Shortcut that opens Relationships; it does not activate or toggle the mod. Accepts an MMAPI keyboard, controller, or compound binding such as `F6`, `GAMEPAD_Y`, `SHIFT+F6`, or `GAMEPAD_LEFT_SHOULDER+GAMEPAD_A`. |
| `debug_logging` | Immediately writes each locate attempt and highlight lifecycle to the mod log when set to `true`. |

Close the game before editing the configuration file. Invalid types, out-of-range durations, and unknown hotkey names fall back to safe defaults when the configuration is loaded.

### Troubleshooting

**The mod does not appear in MOMI**

Check for an accidentally nested folder. This is correct:

```text
mods/find_my_mistrian/manifest.json
```

This is incorrect:

```text
mods/Find-My-Mistrian/find_my_mistrian/manifest.json
```

**The location does not appear**

- Confirm that the character has been met and is unlocked in the current save.
- Reapply the mod with MOMI after updating the game or installer.
- Check that both required hooks, `ui.menu_opened` and `ui.menu_closed`, are available.

**The map opens but no icon pulses**

The vanilla game does not draw every NPC icon in every state or subroom. The location readout may still be correct even when no reusable map icon is available.

**I need a diagnostic log**

Set `debug_logging` to `true`, reproduce the problem, and inspect:

```text
%LOCALAPPDATA%\FieldsOfMistria\mod_data\find_my_mistrian\logs\find_my_mistrian.log
```

The log records whether the action came from Relationships or Quests, the NPC and live map region, the number of matching icon nodes, whether highlighting started, and why it ended. Find My Mistrian logs these opt-in diagnostics at MMAPI's default `Info` level and flushes after every locate attempt, so editing MMAPI's global `mmapi.json` is neither required nor recommended.

### Compatibility

The mod decorates the vanilla Relationships, Quests, and Map menus through MMAPI hooks rather than replacing their constructors. Mods that completely replace those menu internals may still conflict.

MOMI 0.15.2 introduced keyboard, controller, and compound hotkey bindings; this release requires 0.15.6 because it re-anchors MMAPI for Fields of Mistria 1.0.4. `GAMEPAD_A/B/X/Y` follow Xbox button positions, so the printed label may differ on other controller layouts. Controller users can also focus the location button by moving right from the Relationships list and navigate quest locator buttons normally.

### Uninstallation

1. Remove `mods/find_my_mistrian`.
2. Run MOMI again and reapply your remaining mods.
3. Optionally remove the configuration and logs from:

   ```text
   %LOCALAPPDATA%\FieldsOfMistria\mod_data\find_my_mistrian
   ```

The mod does not modify save data, so no save cleanup is required.

### Technical notes

The location readout uses `NPCS[npc_id].location_position`, which is also consumed by the vanilla map. Display names come from vanilla localization: the exact room name is preferred, followed by a named room in the same building and then the containing map region. Spoiler protection uses the game's persistent `NPCS[npc_id].has_met()` state, set by vanilla after a valid first conversation—not heart level or mere presence in Relationships.

Quest targets come from `QUEST_LOG.active[quest].quest.tasks[current_stage].query_targets`. Only structured `QuestQueryType.Npc` targets whose vanilla requirements currently pass are eligible; the mod never parses localized objective text and never assumes that `npc_for_icon` is the current target. The map highlight reuses the character's existing small NPC icon and temporarily changes only its alpha; the original value is restored when the timer expires or the map closes.

After a map-region change, icon resolution is deferred until vanilla's replacement tree contains exactly one stable, non-freed match. The mod retries for up to 30 frames, avoids rebuilding a region that is already selected, and reacquires the live icon if vanilla replaces it during the pulse. This prevents stale duplicate icons from terminating the highlight immediately.

Automated validation against Fields of Mistria 1.0.4 (Steam build 24820767) completed successfully with strict linting and required compile checks using MOMI 0.15.6.

---

## Español

### Características

- Muestra un **botón compacto de ubicación bajo el retrato** en la página de Relaciones.
- Añade un botón **Localizar NPC** a una misión activa cuando su objetivo actual y ejecutable apunta a un personaje conocido.
- Abre la región correcta del mapa desde Relaciones o Misiones.
- Hace parpadear durante unos segundos el icono original del personaje para encontrarlo fácilmente.
- Añade un atajo configurable para abrir Relaciones rápidamente (`F6` de forma predeterminada), compatible con teclado, mando y combinaciones.
- Admite navegación con ratón, teclado y mando.
- Incluye textos de interfaz en inglés y español.
- Utiliza el estado actual del juego —los mismos datos de ubicación que emplea el mapa original— en vez de horarios incluidos o estimados.
- No modifica partidas, horarios, relaciones, inventario, posiciones de NPC ni progreso.

### Requisitos

- [Fields of Mistria](https://www.fieldsofmistria.com/) 1.0.x
- [Mods of Mistria Installer (MOMI/MMAPI)](https://github.com/Garethp/Mods-of-Mistria-Installer) 0.15.6 o posterior

La versión 0.2.4 se validó con Fields of Mistria 1.0.4 (compilación 24820767 de Steam) y MOMI 0.15.6.

### Instalación

1. Instala MOMI y sigue sus instrucciones de configuración para Fields of Mistria.
2. Descarga este repositorio mediante **Code → Download ZIP** y descomprímelo.
3. Copia únicamente la carpeta extraída [`find_my_mistrian`](find_my_mistrian) dentro de la carpeta `mods` del juego.
4. Comprueba que la estructura resultante sea:

   ```text
   Fields of Mistria/
   ├── FieldsOfMistria.exe
   ├── mods/
   │   └── find_my_mistrian/
   │       ├── manifest.json
   │       ├── gml/
   │       ├── fiddle/
   │       └── localization/
   ```

5. Ejecuta MOMI, selecciona **Find My Mistrian** e instala/aplica el mod.
6. Inicia Fields of Mistria normalmente desde Steam.

No copies la carpeta exterior `Find-My-Mistrian` del repositorio dentro de `mods`. MOMI debe encontrar `manifest.json` directamente en `mods/find_my_mistrian/`.

### Cómo utilizarlo

El mod se activa automáticamente después de instalarlo con MOMI e iniciar el juego; **no hace falta pulsar `F6` y esa tecla no activa ni desactiva el mod**. `F6` solo es un atajo para abrir **Diario → Relaciones**. Cambia `enabled` a `false` en la configuración si quieres desactivar todas sus funciones sin desinstalarlo.

1. Carga una partida.
2. Pulsa `F6` o abre **Diario → Relaciones**.
3. Selecciona un personaje que ya hayas conocido.
4. Su ubicación actual aparecerá como un botón compacto con pin bajo el retrato.
5. Selecciona el botón de ubicación. Se abrirá el mapa correspondiente y el icono del personaje parpadeará durante unos cuatro segundos.

El botón de Relaciones se actualiza cada vez que cambia el personaje seleccionado. En interiores con nombre muestra la habitación exacta; las subhabitaciones sin nombre usan otra habitación con nombre del mismo edificio y, como último recurso, la región del mapa que lo contiene.

Para las misiones, abre **Diario → Misiones** y selecciona una misión activa. Aparecerá un botón compacto **Localizar a _nombre_** después de los objetivos actuales y antes de las recompensas cuando el objetivo activo tenga una conversación o entrega ejecutable con un NPC. Se actualiza cuando cambia la misión o avanza su fase. Los objetivos que solo requieren recolectar objetos o acudir a una ubicación/cutscene no muestran el botón, y las fases ambiguas con varios NPC diferentes se ignoran deliberadamente.

Los personajes que aún no conoces permanecen ocultos conforme a las reglas normales de progreso. Para un personaje conocido sin ubicación mostrable, Relaciones enseña el botón **Ubicación desconocida** desactivado y el localizador de la misión queda desactivado. Si la posición deja de estar disponible después de activar el botón, aparece **No se puede localizar a este personaje en este momento**. Si el mapa se abre pero vanilla no dibuja un icono reutilizable, la ubicación puede seguir siendo correcta aunque no haya parpadeo.

Si `open_map_after_locating` está en `false`, el localizador muestra una notificación en pantalla con el personaje y su ubicación actual. No abre el mapa ni intenta hacer parpadear el icono.

### Configuración

El archivo de configuración se crea cuando el mod lo necesita por primera vez:

```text
%LOCALAPPDATA%\FieldsOfMistria\mod_data\find_my_mistrian\find_my_mistrian.json
```

Configuración predeterminada:

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

| Opción | Descripción |
| --- | --- |
| `enabled` | Activa o desactiva todas las funciones sin desinstalar el mod. Está activado automáticamente de forma predeterminada. |
| `highlight_duration` | Duración del parpadeo del icono, entre 1 y 10 segundos. Solo se aplica cuando se abre el mapa. |
| `open_map_after_locating` | En `true`, abre la región correcta y hace parpadear el icono. En `false`, muestra la ubicación actual como notificación. |
| `hotkey` | Atajo que abre Relaciones; no activa ni desactiva el mod. Admite una tecla, botón de mando o combinación MMAPI, como `F6`, `GAMEPAD_Y`, `SHIFT+F6` o `GAMEPAD_LEFT_SHOULDER+GAMEPAD_A`. |
| `debug_logging` | Escribe inmediatamente cada intento de localización y el ciclo del resaltado cuando su valor es `true`. |

Cierra el juego antes de editar el archivo de configuración. Los tipos incorrectos, duraciones fuera del intervalo y nombres de atajo desconocidos vuelven a valores predeterminados seguros al cargarla.

### Solución de problemas

**El mod no aparece en MOMI**

Comprueba que no haya una carpeta adicional. Esta ruta es correcta:

```text
mods/find_my_mistrian/manifest.json
```

Esta ruta es incorrecta:

```text
mods/Find-My-Mistrian/find_my_mistrian/manifest.json
```

**No aparece la ubicación**

- Confirma que ya conoces al personaje y que está desbloqueado en la partida actual.
- Vuelve a aplicar el mod con MOMI después de actualizar el juego o el instalador.
- Comprueba que estén disponibles los hooks `ui.menu_opened` y `ui.menu_closed`.

**El mapa se abre, pero el icono no parpadea**

El juego original no dibuja todos los iconos de NPC en todos los estados o habitaciones. La ubicación mostrada puede seguir siendo correcta aunque no haya un icono reutilizable en el mapa.

**Necesito un registro de diagnóstico**

Cambia `debug_logging` a `true`, reproduce el problema y revisa:

```text
%LOCALAPPDATA%\FieldsOfMistria\mod_data\find_my_mistrian\logs\find_my_mistrian.log
```

El registro indica si la acción procede de Relaciones o Misiones, el NPC y la región actual, cuántos nodos de icono coinciden, si comenzó el resaltado y por qué terminó. Find My Mistrian registra estos diagnósticos voluntarios con el nivel `Info` predeterminado de MMAPI y fuerza el guardado tras cada intento, por lo que no es necesario ni recomendable editar el `mmapi.json` global de MMAPI.

### Compatibilidad

El mod decora los menús originales de Relaciones, Misiones y Mapa mediante hooks de MMAPI, sin reemplazar sus constructores. Aun así, puede entrar en conflicto con mods que sustituyan por completo el funcionamiento interno de esos menús.

MOMI 0.15.2 introdujo atajos de teclado, mando y combinaciones; esta versión requiere 0.15.6 porque reancla MMAPI para Fields of Mistria 1.0.4. `GAMEPAD_A/B/X/Y` siguen las posiciones de los botones de Xbox, por lo que la etiqueta física puede ser distinta en otros mandos. También se puede enfocar el botón de ubicación moviéndose a la derecha desde la lista de Relaciones y navegar normalmente por los localizadores de Misiones.

### Desinstalación

1. Elimina `mods/find_my_mistrian`.
2. Ejecuta MOMI de nuevo y vuelve a aplicar los demás mods.
3. Opcionalmente, elimina la configuración y los registros de:

   ```text
   %LOCALAPPDATA%\FieldsOfMistria\mod_data\find_my_mistrian
   ```

El mod no modifica las partidas guardadas, por lo que no es necesario limpiarlas.

### Notas técnicas

La ubicación utiliza `NPCS[npc_id].location_position`, el mismo estado que consulta el mapa original. Los nombres proceden de la localización de vanilla: se prefiere la habitación exacta, después otra habitación con nombre del mismo edificio y finalmente la región del mapa que la contiene. La protección contra spoilers usa el estado persistente `NPCS[npc_id].has_met()`, que vanilla activa después de una primera conversación válida; no usa los corazones ni la mera presencia en Relaciones.

Los objetivos de misión proceden de `QUEST_LOG.active[quest].quest.tasks[current_stage].query_targets`. Solo se admiten objetivos estructurados `QuestQueryType.Npc` cuyos requisitos vanilla ya se cumplen; el mod nunca analiza el texto traducido del objetivo ni presupone que `npc_for_icon` sea el personaje actual. El resaltado reutiliza el icono pequeño existente del personaje y solo modifica temporalmente su opacidad; el valor original se restaura al terminar el tiempo o cerrar el mapa.

Después de cambiar la región del mapa, la resolución del icono se aplaza hasta que el árbol nuevo de vanilla contenga una sola coincidencia estable y no liberada. El mod reintenta durante un máximo de 30 fotogramas, evita reconstruir una región que ya está seleccionada y vuelve a adquirir el icono vigente si vanilla lo reemplaza durante el pulso. Así se impide que los duplicados obsoletos terminen el resaltado inmediatamente.

La validación automatizada contra Fields of Mistria 1.0.4 (compilación 24820767 de Steam) terminó correctamente con linting estricto y comprobación de compilación obligatoria mediante MOMI 0.15.6.

---

## Project layout / Estructura del proyecto

```text
find_my_mistrian/   Installable mod / Mod instalable
RESEARCH.md         Compatibility research / Investigación de compatibilidad
```

Bug reports should include the game version, MOMI version, other installed mods, reproduction steps, and the diagnostic log when available.

Los informes de errores deben incluir la versión del juego, la versión de MOMI, los demás mods instalados, los pasos para reproducir el problema y el registro de diagnóstico cuando esté disponible.
