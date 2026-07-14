-- control.lua
-- Point d'entree runtime. Cable le declencheur (hotkey + commande) vers le generateur.

local generator = require("scripts.generator")

local function trigger(player)
    if not player or not player.valid then return end
    local ok, err = pcall(generator.run, player)
    if not ok then
        player.print("[FactoryForge] Erreur : " .. tostring(err))
    end
end

-- Hotkey (CONTROL + SHIFT + G, defini dans data.lua)
script.on_event("factoryforge-generate", function(event)
    trigger(game.get_player(event.player_index))
end)

-- Bouton de la barre de raccourcis
script.on_event(defines.events.on_lua_shortcut, function(event)
    if event.prototype_name == "factoryforge-generate" then
        trigger(game.get_player(event.player_index))
    end
end)

-- Commande console de secours : /ff-generate
commands.add_command("ff-generate", "Genere un blueprint depuis le factory Factory Planner courant.",
    function(command)
        trigger(game.get_player(command.player_index))
    end)
