-- generator.lua
-- Orchestre : FP remote --> extract --> emit --> blueprint dans la main du joueur.

local extract = require("scripts.extract")
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

    local entities = emit.run(plan)
    if #entities == 0 then
        player.print("[FactoryForge] Rien a poser (0 entite generee).")
        return
    end

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

    local msg = string.format("[FactoryForge] Blueprint genere : %d machines, %d blocs.",
        #entities, #plan.blocks)
    player.print(msg)

    -- Avertit si des fluides ont ete ignores (non routes en v1).
    local fluids = {}
    for name in pairs(dropped_fluids) do fluids[#fluids + 1] = name end
    if #fluids > 0 then
        player.print("[FactoryForge] Fluides non routes (v1) : " .. table.concat(fluids, ", "))
    end
end

return generator
