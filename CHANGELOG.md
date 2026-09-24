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
