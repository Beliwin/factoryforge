-- layout.lua
-- IR ProductionPlan --> liste de "parts" (placement en tuiles) : bus + blocs.
-- M3a increment 1 : cablage INTERNE des blocs (belts + inserters) + lanes de bus.
--                   Le routage bus<->bloc (splitters/undergrounds) = increment 2 (routing.lua).
-- Ne connait que l'IR (specs/01) + defines.direction. Voir specs/04.

local layout = {}

local MARGIN = 2       -- tuiles entre le bus et les blocs
local BLOCK_VGAP = 2   -- tuiles entre deux blocs
local M = 3            -- M3a : machines supposees 3x3

-- Roles des items + table producteur.
local function analyze(plan)
    local produced_by = {}
    local items = {}
    local function touch(it)
        if not items[it] then items[it] = { produced = false, consumed = false } end
    end
    for _, b in ipairs(plan.blocks) do
        for _, o in ipairs(b.outputs) do touch(o.item); items[o.item].produced = true; produced_by[o.item] = b.id end
        for _, i in ipairs(b.inputs) do touch(i.item); items[i.item].consumed = true end
    end
    return produced_by, items
end

-- Tri topologique des blocs : producteur au-dessus du consommateur. Deterministe (par id).
local function topo_order(plan, produced_by)
    local by_id, indeg, adj = {}, {}, {}
    for _, b in ipairs(plan.blocks) do by_id[b.id] = b; indeg[b.id] = 0; adj[b.id] = {} end

    local seen = {}
    for _, b in ipairs(plan.blocks) do
        for _, i in ipairs(b.inputs) do
            local pid = produced_by[i.item]
            if pid and pid ~= b.id then
                local key = pid .. "->" .. b.id
                if not seen[key] then
                    seen[key] = true
                    table.insert(adj[pid], b.id)
                    indeg[b.id] = indeg[b.id] + 1
                end
            end
        end
    end

    local order, queue = {}, {}
    for _, b in ipairs(plan.blocks) do if indeg[b.id] == 0 then table.insert(queue, b.id) end end
    table.sort(queue)
    while #queue > 0 do
        local id = table.remove(queue, 1)
        table.insert(order, by_id[id])
        for _, c in ipairs(adj[id]) do
            indeg[c] = indeg[c] - 1
            if indeg[c] == 0 then table.insert(queue, c) end
        end
        table.sort(queue)
    end
    -- Cycles eventuels : ajouter le reste dans l'ordre des id.
    if #order < #plan.blocks then
        local placed = {}
        for _, b in ipairs(order) do placed[b.id] = true end
        for _, b in ipairs(plan.blocks) do if not placed[b.id] then table.insert(order, b) end end
    end
    return order
end

-- Assignation des lanes de bus : base | intermediaire | final, chaque groupe trie par nom.
local function bus_lanes(items)
    local base, inter, final = {}, {}, {}
    for it, info in pairs(items) do
        if info.produced and info.consumed then table.insert(inter, it)
        elseif info.produced then table.insert(final, it)
        else table.insert(base, it) end
    end
    table.sort(base); table.sort(inter); table.sort(final)
    local lane_x, x = {}, 0
    for _, group in ipairs({ base, inter, final }) do
        for _, it in ipairs(group) do lane_x[it] = x; x = x + 1 end
    end
    return lane_x, x  -- x = largeur du bus (nb de lanes)
end

--- IR --> parts (+ warnings).
---@param plan table ProductionPlan
---@return table parts, table warnings
function layout.run(plan)
    local dir = defines.direction
    local produced_by, items = analyze(plan)
    local order = topo_order(plan, produced_by)
    local lane_x, bus_width = bus_lanes(items)

    local parts, warnings = {}, {}
    local block_x0 = bus_width + MARGIN
    local y = 0

    local function add(p) parts[#parts + 1] = p end

    for _, b in ipairs(order) do
        local routable = (b.machine.tile_w == M and b.machine.tile_h == M)
        if not routable then
            warnings[#warnings + 1] = b.recipe .. " : machine " ..
                b.machine.tile_w .. "x" .. b.machine.tile_h .. " non 3x3, I/O non routee"
        end
        if #b.inputs > 2 then
            warnings[#warnings + 1] = b.recipe .. " : " .. #b.inputs .. " ingredients (>2), I/O non routee"
        end

        local N = b.count
        local width = N * M
        local by = y

        -- Rangee de machines (y+3)
        for i = 0, N - 1 do
            add({ kind = "machine", name = b.machine.name,
                  x = block_x0 + i * M, y = by + 3,
                  tile_w = b.machine.tile_w, tile_h = b.machine.tile_h,
                  recipe = b.recipe, accepts_recipe = b.machine.accepts_recipe,
                  quality = b.machine.quality, modules = b.modules })
        end

        if routable then
            local I2 = b.inputs[2]  -- peut etre nil (1 seul ingredient)

            -- Belts d'entree (est) : I1 en y+1, I2 en y+0
            for cx = 0, width - 1 do
                add({ kind = "belt", name = plan.meta.belt, x = block_x0 + cx, y = by + 1, direction = dir.east })
                if I2 then
                    add({ kind = "belt", name = plan.meta.belt, x = block_x0 + cx, y = by + 0, direction = dir.east })
                end
            end

            -- Inserters NORD (y+2) : prennent au nord (belt), deposent au sud (machine).
            -- Verite terrain 2.0 : direction = COTE DE PRISE => direction nord.
            for i = 0, N - 1 do
                for col = 0, M - 1 do
                    local px = block_x0 + i * M + col
                    local name = (I2 and col == 1) and plan.meta.long_inserter or plan.meta.inserter
                    add({ kind = "inserter", name = name, x = px, y = by + 2, direction = dir.north })
                end
            end

            -- Inserters SUD (y+6) : prennent au nord (machine), deposent au sud (belt sortie).
            for i = 0, N - 1 do
                for col = 0, M - 1 do
                    add({ kind = "inserter", name = plan.meta.inserter,
                          x = block_x0 + i * M + col, y = by + 6, direction = dir.north })
                end
            end

            -- Belt de sortie (ouest) en y+7
            for cx = 0, width - 1 do
                add({ kind = "belt", name = plan.meta.belt, x = block_x0 + cx, y = by + 7, direction = dir.west })
            end
        end

        y = by + 8 + BLOCK_VGAP
    end

    -- Lanes de bus (sud), du haut jusqu'en bas des blocs
    local bus_bottom = math.max(y, 8)
    for _, lx in pairs(lane_x) do
        for yy = 0, bus_bottom - 1 do
            add({ kind = "belt", name = plan.meta.belt, x = lx, y = yy, direction = dir.south })
        end
    end

    return parts, warnings
end

return layout
