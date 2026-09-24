> Current local compatibility candidate for Steam build 25480438 / EXE 1.8.46015.0. Offline checks passed; live gameplay verification is pending.

![Mod Bindings Menu](assets/banner.png)

# Mod Bindings Menu v1.1

Adds a **MODS** section to the General tab of both the Mouse & Keyboard and Controller binding pages. Rows use Helldivers 2's own capture widgets and saved input settings. The first slot is used by Galactic Menu Hotkey and defaults to Tab on a keyboard. A controller button can be assigned on the Controller page.

This mod is a separate install from Galactic Menu Hotkey. Install [the release ZIP](https://github.com/CowboyBingus/ModBindingsMenu/releases/latest), [Galactic Menu Hotkey](https://github.com/CowboyBingus/GalacticMenuHotkey/releases/latest) (or its Megapack option), and [Bingus Shared Loader v17 or newer](https://github.com/CowboyBingus/BingusSharedLoader/releases/latest). Mod Bindings Menu is a separate dependency and is not bundled in Vanilla Plus Megapack. Enable and deploy all three, then restart the game. Keep the shared loader as the winning Wwise startup replacement. The bindings mod ships its own `content/input.config` override; another mod that replaces that resource must be merged with it.

The native offsets and input resource are for Steam build **25480438** only. The addon checks the executable and DLL hashes before editing the bindings UI. The packaged input resource itself is version specific and must be rebuilt after a game update. This revision uses two dormant Debugmenu input actions as slots, so it conflicts with mods that use those actions.

The MODS header uses a runtime localization override only while the bindings page is active. Keyboard input polling reads the game's current native binding. Controller input activation is not yet supported.

## For mod authors

Make Mod Bindings Menu and Bingus Shared Loader requirements of your own separately packaged addon. Its entry script can register slot 2 and read its current keyboard binding:

```lua
-- HD2-Addon: mods/example/your_mod
local BINDING_ID = 'example.your_mod.toggle_hud'
local LABEL_ID = 0x3EF7F7AD -- Existing game text: "TOGGLE HUD"
local registered, was_down = false, false
local hud_visible = true

local function step()
    local menu = rawget(_G, 'ModBindingsMenu')
    if not menu or menu.api ~= 1 then return end

    -- The two addons may load in either order. Retry until registration works.
    if not registered then
        local ok = menu.register_binding(BINDING_ID, LABEL_ID, 2)
        if not ok then return end
        registered = true
    end

    local down = menu.is_down(BINDING_ID)
    if down == nil then return end -- Native input is still loading.
    if down and not was_down then
        hud_visible = not hud_visible
        -- Apply hud_visible to your mod's UI here.
    end
    was_down = down
end

local previous_update = rawget(_G, 'update')
update = function(dt)
    step()
    if type(previous_update) == 'function' then return previous_update(dt) end
end
```

`register_binding(id, label_id, slot)` takes a stable unique ID, a **game localization ID** for the row text, and a slot number. Slot 1 belongs to Galactic Menu Hotkey; slot 2 is currently the only available third-party slot. Registration fails if another addon already owns it. The MODS row appears on both binding pages when registration succeeds. `is_down(id)` returns `nil` while native input is unavailable, then a boolean for the current keyboard mapping. Read the boolean as a key edge as above, and apply any gameplay or focus guards your mod needs.

The host does not currently accept arbitrary row label strings or allocate more slots. Controller rows and capture are visible, but `is_down` does not yet report controller button presses. Slot 2 inherits a dormant game action's default bindings, so tell users to choose their own key in the MODS section.

## Validation

Clone BingusSharedLoader beside this repository. Set `HD2_INPUT_CONFIG` to your locally extracted, unmodified `content/input.config` from Steam build 25480438; its checksum is validated before use. Game captures are not included in the source repository. Run `python -B tests/test_build.py` from this repository to validate the resource and build `releases/Mod-Bindings-Menu-v1.1.zip`.

[Artwork and generation prompts](assets/ARTWORK.md). AI-assisted development with GPT-6 Astra.

Current version: **v1.1**, for game build **25480438**. See [changes](CHANGELOG.md) and [validation coverage](docs/MIGRATION_VALIDATION.md).
