-- generator.lua
-- Orchestre : FP remote --> extract --> emit --> blueprint dans la main du joueur.

local extract = require("scripts.extract")
local layout = require("scripts.layout")
local emit = require("scripts.emit")

local generator = {}

local FP_INTERFACE = "fp-interface"

local function fp_available()
    return remote.interfaces[FP_INTERFACE]
        and remote.interfaces[FP_INTERFACE]["export_current_factory"]
end

--- Genere un blueprint pour le factory FP courant du joueur et le met dans sa main.
---@param player LuaPlayer
function generator.run(player)
    if not fp_available() then
        player.print("[FactoryForge] Factory Planner (>= 2.1.1) est requis et introuvable.")
        return
    end

    local packed = remote.call(FP_INTERFACE, "export_current_factory", player.index)
    if not packed then
        player.print("[FactoryForge] Aucun factory selectionne dans Factory Planner.")
        return
    end

    local plan, dropped_fluids = extract.run(packed)
    if #plan.blocks == 0 then
        player.print("[FactoryForge] Le factory ne contient aucune ligne exploitable.")
        return
    end

    local parts, warnings = layout.run(plan)
    local entities = emit.run(parts)
    if #entities == 0 then
        player.print("[FactoryForge] Rien a poser (0 entite generee).")
        return
    end

    -- Compte les machines pour le message.
    local machines = 0
    for _, p in ipairs(parts) do if p.kind == "machine" then machines = machines + 1 end end

    -- Met un blueprint dans le curseur du joueur.
    local stack = player.cursor_stack
    if not stack then
        player.print("[FactoryForge] Curseur indisponible.")
        return
    end
    stack.clear()
    stack.set_stack({ name = "blueprint" })
    stack.set_blueprint_entities(entities)
    stack.label = plan.meta.name

    player.print(string.format("[FactoryForge] Blueprint genere : %d machines, %d blocs, %d entites.",
        machines, #plan.blocks, #entities))

    -- Avertissements de layout (recettes hors perimetre M3a).
    for _, w in ipairs(warnings or {}) do
        player.print("[FactoryForge] " .. w)
    end

    -- Avertit si des fluides ont ete ignores (non routes en v1).
    local fluids = {}
    for name in pairs(dropped_fluids) do fluids[#fluids + 1] = name end
    if #fluids > 0 then
        player.print("[FactoryForge] Fluides non routes (v1) : " .. table.concat(fluids, ", "))
    end
end

return generator
