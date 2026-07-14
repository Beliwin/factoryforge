-- extract.lua
-- PackedFactory (interface remote de Factory Planner) --> IR ProductionPlan.
-- SEULE couche autorisee a connaitre le format de FP (cf. specs/01-data-model.md).

local extract = {}

-- Config par defaut (belt/inserter/underground). Non utilisee en M2 (pas de belts),
-- mais placee ici pour M3/M4. Voir Q5 (choix auto selon debit).
local DEFAULT_META = {
    belt = "transport-belt",
    inserter = "inserter",
    long_inserter = "long-handed-inserter",
    underground = "underground-belt",
    splitter = "splitter",
    underground_max = 4,  -- portee du underground jaune
}

-- Infos machine lues du prototype (jamais hardcodees) : dimensions + type.
-- accepts_recipe = false pour les fours (recette auto, refusee dans un blueprint).
local function machine_proto_info(entity_name)
    local proto = prototypes.entity[entity_name]
    if not proto then return 3, 3, "assembling-machine", true end  -- fallback defensif
    local w = math.ceil(proto.tile_width or 1)
    local h = math.ceil(proto.tile_height or 1)
    if w < 1 then w = 1 end
    if h < 1 then h = 1 end
    local accepts_recipe = (proto.type ~= "furnace")
    return w, h, proto.type, accepts_recipe
end

-- Convertit une liste de PackedItem en {item, quality, rate}, en filtrant les fluides.
---@param packed_items table|nil
---@param dropped_fluids table accumulateur des noms de fluides ignores
local function map_items(packed_items, dropped_fluids)
    local out = {}
    if not packed_items then return out end
    for _, it in pairs(packed_items) do
        local proto = it.proto
        if proto.category == "item" then
            out[#out + 1] = {
                item = proto.name,
                quality = "normal",  -- les items packes ne portent pas de quality (cf. 01 §3)
                rate = it.amount or 0,  -- items/seconde
            }
        elseif proto.category == "fluid" then
            dropped_fluids[proto.name] = true
        end
        -- autres categories (entity/electricite, ex. custom-electric-power) : ignorees
    end
    return out
end

-- Mappe une PackedLine (feuille) vers un bloc IR. Renvoie nil si la ligne doit etre ignoree.
local function map_line(line, next_id, dropped_fluids)
    if line.active == false then return nil end  -- Q10 : ignorer les lignes desactivees

    local count_exact = (line.machine and line.machine.amount) or 0
    local count = math.ceil(count_exact - 1e-9)
    if count < 1 then return nil end  -- ligne sans machine effective

    local mname = line.machine.proto.name
    local w, h, mtype, accepts_recipe = machine_proto_info(mname)

    local modules = {}
    local mset = line.machine.module_set
    if mset and mset.modules then
        for _, m in pairs(mset.modules) do
            modules[#modules + 1] = {
                name = m.proto.name,
                quality = (m.quality_proto and m.quality_proto.name) or "normal",
                count = m.amount or 1,  -- nb par machine
            }
        end
    end

    return {
        id = next_id,
        recipe = line.recipe.proto.name,
        recipe_quality = "normal",
        machine = {
            name = mname,
            quality = (line.machine.quality_proto and line.machine.quality_proto.name) or "normal",
            tile_w = w,
            tile_h = h,
            type = mtype,
            accepts_recipe = accepts_recipe,
        },
        count = count,
        count_exact = count_exact,
        modules = modules,
        inputs = map_items(line.ingredients, dropped_fluids),
        outputs = map_items(line.products, dropped_fluids),
    }
end

-- Aplatit l'arbre de floors : recurse dans les sous-floors, collecte les Lines feuilles.
local function flatten(floor, blocks, id_counter, dropped_fluids)
    if not floor or not floor.lines then return end
    for _, entry in pairs(floor.lines) do
        if entry.class == "Floor" then
            flatten(entry, blocks, id_counter, dropped_fluids)
        elseif entry.class == "Line" then
            local block = map_line(entry, id_counter.n + 1, dropped_fluids)
            if block then
                id_counter.n = id_counter.n + 1
                blocks[#blocks + 1] = block
            end
        end
    end
end

--- Point d'entree : PackedFactory --> ProductionPlan (IR).
---@param packed table Resultat de export_current_factory
---@return table plan
---@return table dropped_fluids noms des fluides non routes (pour avertir l'utilisateur)
function extract.run(packed)
    local blocks = {}
    local id_counter = { n = 0 }
    local dropped_fluids = {}

    flatten(packed.top_floor, blocks, id_counter, dropped_fluids)

    local meta = {
        name = packed.name or "factory",
        belt = DEFAULT_META.belt,
        inserter = DEFAULT_META.inserter,
        long_inserter = DEFAULT_META.long_inserter,
        underground = DEFAULT_META.underground,
        underground_max = DEFAULT_META.underground_max,
    }

    -- Invariants (assertions douces : on ne veut pas crasher en prod)
    for _, b in pairs(blocks) do
        assert(b.count >= 1, "block count must be >= 1")
        assert(b.machine.tile_w > 0 and b.machine.tile_h > 0, "machine tile size must be > 0")
    end

    return { meta = meta, blocks = blocks }, dropped_fluids
end

return extract
