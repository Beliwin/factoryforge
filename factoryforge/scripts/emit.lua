-- emit.lua
-- parts (placement en tuiles, cf. layout.lua/specs 04 §9) --> array[BlueprintEntity].
-- Ne connait que le format "parts", jamais Factory Planner.

local emit = {}

-- Construit le champ `items` (modules) au format BlueprintInsertPlan 2.0.
-- Q4 : format a valider par verite terrain sur un plan modulе.
local function build_module_items(modules)
    if not modules or #modules == 0 then return nil end

    local inv = (defines.inventory.assembling_machine_modules)
        or (defines.inventory.furnace_modules)
        or 4

    local items, slot = {}, 0  -- slot 0-based
    for _, m in ipairs(modules) do
        local in_inventory = {}
        for _ = 1, (m.count or 1) do
            in_inventory[#in_inventory + 1] = { inventory = inv, stack = slot, count = 1 }
            slot = slot + 1
        end
        items[#items + 1] = {
            id = { name = m.name, quality = m.quality or "normal" },
            items = { in_inventory = in_inventory },
        }
    end
    return items
end

--- parts --> liste d'entites de blueprint.
---@param parts table
---@return table entities
function emit.run(parts)
    local north = defines.direction.north
    local entities = {}
    local n = 0

    for _, p in ipairs(parts) do
        n = n + 1
        local e = { entity_number = n, name = p.name }

        if p.kind == "machine" then
            local w, h = p.tile_w, p.tile_h
            e.position = { x = p.x + w / 2, y = p.y + h / 2 }
            if p.accepts_recipe ~= false then e.recipe = p.recipe end
            if p.quality and p.quality ~= "normal" then e.quality = p.quality end
            local mods = build_module_items(p.modules)
            if mods then e.items = mods end
        else
            -- Entites 1x1 (belt, underground, inserter)
            e.position = { x = p.x + 0.5, y = p.y + 0.5 }
        end

        if p.direction and p.direction ~= north then e.direction = p.direction end
        if p.kind == "underground" then e.type = p.ug_type end

        entities[n] = e
    end

    return entities
end

return emit
