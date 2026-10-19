-- Mod Bindings Menu: English texts, the source of every translation.
-- Translators: see TRANSLATING.md. Binding names and section names come from
-- the mods that register them and are translated with those mods.
return {
    mod = 'mod_bindings_menu',
    title = 'Mod Bindings Menu',
    language = 'zh-Hant',
    strings = {
        -- The fourth tab of the key and controller binding pages, after the game's own
        -- three. Upper case like theirs, and about as short.
        ['tab.mods'] = '模組按鍵',
        -- The only row of the MODS tab when no mod has registered a binding.
        ['section.none'] = '無可綁定的模組按鍵',
        -- Section name for bindings of a mod that gave no name.
        ['section.unnamed'] = '模組按鍵',
        -- The fifth tab, shown only when mods registered more bindings than the
        -- MODS tab can hold. Upper case and short, like the other tabs.
        ['tab.more'] = '其他模組按鍵',
        -- The heading at the top of the MORE MODS tab.
        ['section.more'] = '其他可綁定的模組按鍵',
        -- In place of the keys of a binding that has none on this page.
        ['binding.none'] = '未綁定',
        -- In place of the keys while the player chooses new ones on the keyboard page.
        ['binding.capture'] = '按下按鍵',
        -- In place of the binding's name meanwhile: the keys that cancel and clear.
        ['binding.capture_hint'] = 'ESC：取消 DELETE：清除',
        -- The same two on the controller page.
        ['binding.capture_pad'] = '按下按鍵',
        ['binding.capture_hint_pad'] = 'B：取消 X：清除',
        -- In place of the keys of a binding saved by a newer Mod Bindings Menu,
        -- which this version leaves untouched.
        ['binding.inactive'] = '已由新版本保存',
    },
    -- Rough room in ems (the tool warns when a translation looks wider).
    widths = {['tab.mods'] = 8, ['tab.more'] = 12},
}
