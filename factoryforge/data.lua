-- Raccourci clavier pour declencher la generation.
-- Le handler est dans control.lua (event defines.events.on_lua_shortcut / custom-input).

data:extend({
    {
        type = "custom-input",
        name = "factoryforge-generate",
        key_sequence = "CONTROL + SHIFT + G",
        consuming = "none"
    },
    -- Bouton dans la barre de raccourcis (shortcut bar).
    {
        type = "shortcut",
        name = "factoryforge-generate",
        order = "b[blueprints]-z[factoryforge]",
        action = "lua",
        associated_control_input = "factoryforge-generate",  -- affiche/lie le hotkey
        icon = "__base__/graphics/icons/assembling-machine-2.png",
        icon_size = 64,
        small_icon = "__base__/graphics/icons/assembling-machine-2.png",
        small_icon_size = 64
    }
})
