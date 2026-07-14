-- emit.lua
-- IR ProductionPlan --> array[BlueprintEntity] (M2 : grille brute, SANS belts).
-- Ne connait que l'IR (specs/01), jamais Factory Planner.

local emit = {}

local BLOCK_GAP = 2       -- tuiles entre deux blocs
local MACHINE_GAP = 1     -- tuiles entre machines (reservees aux inserters/belts en M3)

-- Construit le champ `items` (modules) au format BlueprintInsertPlan 2.0.
-- ⚠️ Q4 : format a VALIDER par verite terrain (poser une machine modulee a la main,
-- lire get_blueprint_entities). Isole ici pour n'avoir qu'une fonction a corriger.
local function build_module_items(block)
    if not block.modules or #block.modules == 0 then return nil end

    -- Index d'inventaire modules : varie selon le type de machine. On tente le define
    -- generique ; a ajuster si la verite terrain montre autre chose.
    local inv = (defines.inventory.assembling_machine_modules)
        or (defines.inventory.furnace_modules)
        or 4

    local items = {}
    local slot = 0  -- 0-based
    for _, m in pairs(block.modules) do
        local in_inventory = {}
        for _ = 1, (m.count or 1) do
            in_inventory[#in_inventory + 1] = {
                inventory = inv,
                stack = slot,
                count = 1,
            }
            slot = slot + 1
        end
        items[#items + 1] = {
            id = { name = m.name, quality = m.quality or "normal" },
            items = { in_inventory = in_inventory },
        }
    end
    return items
end

-- Une entree de blueprint pour une machine, centre calcule depuis le coin haut-gauche.
local function machine_entity(n, block, top_left_x, top_left_y)
    local w, h = block.machine.tile_w, block.machine.tile_h
    local e = {
        entity_number = n,
        name = block.machine.name,
        position = { x = top_left_x + w / 2, y = top_left_y + h / 2 },
    }
    -- Les fours (furnace) refusent une recette explicite dans un blueprint.
    if block.machine.accepts_recipe ~= false then
        e.recipe = block.recipe
    end
    if block.machine.quality and block.machine.quality ~= "normal" then
        e.quality = block.machine.quality
    end
    local items = build_module_items(block)
    if items then e.items = items end
    return e
end

--- IR --> liste d'entites de blueprint.
---@param plan table ProductionPlan
---@return table entities
function emit.run(plan)
    local entities = {}
    local n = 0
    local cursor_x = 0  -- coin gauche du prochain bloc

    for _, block in pairs(plan.blocks) do
        local w, h = block.machine.tile_w, block.machine.tile_h
        local cell_w = w + MACHINE_GAP
        local cell_h = h + MACHINE_GAP

        local cols = math.ceil(math.sqrt(block.count))
        local rows = math.ceil(block.count / cols)

        for i = 0, block.count - 1 do
            local col = i % cols
            local row = math.floor(i / cols)
            local tlx = cursor_x + col * cell_w
            local tly = row * cell_h
            n = n + 1
            entities[n] = machine_entity(n, block, tlx, tly)
        end

        cursor_x = cursor_x + cols * cell_w + BLOCK_GAP
    end

    return entities
end

return emit
