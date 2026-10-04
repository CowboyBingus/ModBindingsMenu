# v2.2

- For mod authors: `ModBindingsMenu.poll(ids, out)` answers several bindings in one call, with each one's state and whether it was pressed or released since your previous poll. Check for it with `type(ModBindingsMenu.poll) == 'function'`.
- One `poll` of six bindings reads game memory 8 times, where six `is_down` calls read it 18 times, and allocates nothing.
- For mod authors: `ModBindingsMenu.revision` grows whenever a binding registers, native input becomes ready or the bindings' texts change, so a mod can retry a failed registration when it changes.
- When no automatic action is free, `register_binding` returns `false` with a reason that tells actions reserved by mods not loaded this session from all 29 automatic actions in use.
- Automatic bindings keep their native action and keys across sessions, whatever order mods load in: a mod that loads late or skips a session no longer loses them to another mod.
- An automatic action goes to another binding only after its own binding has not registered for 30 sessions in which a mod asked for an automatic binding; its old keys are then cleared.
- Keys you set on the MODS tab are never deleted, even ones equal to a developer default the action shipped with.
- Developer defaults are cleared once per action, when a binding first uses it, and again only when the game restores them (Revert, a config reload, an old saved settings file).
- Native actions that no mod binding uses this session are left alone, so another mod that uses those developer actions keeps its keys.
- The assignments file is saved through a temporary file and a backup, and restored from the backup after an interrupted save or damage. Unchanged assignments are not rewritten, and a failed save is retried instead of lost.
- The background check of the bindings reads only the actions bindings use, once every 2 seconds, and allocates nothing while nothing changed. Before, it read every developer action's mappings (about 250 reads and 30 KB of garbage per check).
- `is_down` and the per-frame binding page check allocate nothing and read less: 3 reads per `is_down` call instead of 4, and 2 per frame outside a binding page instead of 4.
- Frames with a binding page open allocate nothing and read less: 5 reads instead of 6 on a native tab, and 6 instead of 15 on the MODS tab.
- A malformed translation pack is skipped instead of breaking the MODS tab's texts, and a pack forces its language only with `force = true`.
- Windows functions are declared under private names, so another mod's declarations (such as a textbook `VirtualQuery`) can no longer break the MODS tab.
- On a game build it does not support, the update stops for the session (status `stopped: unsupported game build`) and the bindings stay inert. The log warns that the input.config replacement is still deployed and says to remove or update the mod.
- The update runs through Bingus Shared Runtime's update guard, like the family's other mods, and its status, first failure included, survives the game's shutdown.
- After 8 errors in one burst the update stops and logs the burst's first error instead of failing every frame; 3600 error-free frames (about a minute) end a burst.
- On such a stop the MODS title and borrowed text slots go back to the game as when a binding page closes, or stay borrowed while a page is open.
- When the update of a mod below this one fails, the menu pauses and resumes after 60 frames without such an error; 8 such errors in a burst stop it. Your saved keys are never touched.
- The update passes every argument and return value through to the update it wraps, and no longer builds a new function every frame.
- The game's module files are hashed once per session for every mod together, through Bingus Shared Runtime, instead of once more by this mod.
- Measured in live play: 0.008 ms per frame in missions and 0.007 on the ship.

# v2.1

- Translatable: the MODS tab's own texts follow the game's Text Language when a translation is installed (see TRANSLATING.md).
- For mod authors (version 3): `label` and `options.category` may be functions that return the text in the current language.
- Text limits count characters instead of bytes, so Chinese or Cyrillic text gets the same room as English.
- Section and binding names are upper-cased in every script the game's fonts carry.
- Measured in live play: 0.013 ms per frame on the ship and 0.014 ms in missions, unchanged from v2.0.

# v2.0

- Move mod bindings to a native MODS tab beside General, Combat and Communication on both the Mouse & Keyboard and Controller binding pages.
- Group bindings under one native section header per mod. `register_binding` accepts `{category = 'Name'}`; otherwise the header is derived from the addon's entry name.
- Raise capacity from 2 third-party slots to 36 bindings across all mods. Registering without a slot assigns a free native action and keeps it for that binding in later sessions.
- Support every activation type (Press, Hold, Double Tap, Long Press and others) and controller buttons: `is_down` now reads the game's own evaluated input state. v1 recognized Press only, so other types disabled the binding.
- Remove the developer default mappings the reserved actions shipped with, including left click and controller buttons on the map slot, and use Press for the Ship Station Hotkeys defaults.
- Allow text row labels on any binding and let two mods share a key.
- Keep v1.1 compatible: `api` stays 1, slots 1–7 and saved keys are unchanged, and a second addon asking for slot 2 is assigned automatically.
- Live tests confirmed the MODS tab, per-mod headers, automatic bindings, Double Tap, duplicate keys and restart persistence. Controller activation is verified offline only.

# v1.1

- Update the shifted native binding addresses for Steam build 25480438.
- Preserve the MODS binding page and reserved addon slots.
- Offline builds and package checks pass; live gameplay validation remains pending.

# Changelog

## v1.0

- Add a MODS section to the native keyboard and controller binding pages.
- Let Galactic Menu Hotkey use a saved keyboard binding, with Tab as its default.
- Provide two reserved binding slots for separately installed addons.
- Package as a separate Bingus Shared Loader dependency with banner and thumbnail artwork.

Controller binding capture is available; controller button activation is not yet supported.
