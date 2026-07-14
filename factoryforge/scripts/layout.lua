-- layout.lua
-- IR ProductionPlan --> "parts" (placement en tuiles) + "net" (points de connexion pour routing).
-- Layout hybride "chaines + mini-bus" :
--   - item mono-producteur/mono-consommateur => alimentation directe (blocs empiles, belt partagee)
--   - base / partages / finaux => lanes de bus (espacees de 2 pour les splitters, elaguees si
--     aucune extremite routable)
-- Cablage interne des blocs ; le bus lui-meme et le routage bus<->bloc sont emis par routing.lua.
-- Ne connait que l'IR (specs/01) + defines.direction. Voir specs/04.

local layout = {}

local MARGIN = 2       -- tuiles entre le bus et les blocs
local CHAIN_GAP = 2    -- tuiles entre deux chaines
local M = 3            -- M3a : machines supposees 3x3

-- Copie des inputs triee par debit decroissant (puis nom) : ins[1] = plus gros debit.
local function sorted_inputs(b)
    local ins = {}
    for _, i in ipairs(b.inputs) do ins[#ins + 1] = i end
    table.sort(ins, function(a, c)
        if (a.rate or 0) ~= (c.rate or 0) then return (a.rate or 0) > (c.rate or 0) end
        return a.item < c.item
    end)
    return ins
end

--- IR --> parts, warnings, net.
function layout.run(plan)
    local dir = defines.direction
    local warnings = {}
    local by_id = {}
    for _, b in ipairs(plan.blocks) do by_id[b.id] = b end

    -- 1. Producteurs / consommateurs par item -------------------------------
    local produced_by, multi_produced, consumers = {}, {}, {}
    for _, b in ipairs(plan.blocks) do
        for _, o in ipairs(b.outputs) do
            if produced_by[o.item] then multi_produced[o.item] = true
            else produced_by[o.item] = b.id end
        end
    end
    for _, b in ipairs(plan.blocks) do
        for _, i in ipairs(b.inputs) do
            consumers[i.item] = consumers[i.item] or {}
            table.insert(consumers[i.item], b.id)
        end
    end

    -- 2. Blocs routables (perimetre M3a : 3x3, <=2 ingredients, 1 produit) --
    local routable = {}
    for _, b in ipairs(plan.blocks) do
        local ok = true
        if b.machine.tile_w ~= M or b.machine.tile_h ~= M then
            ok = false
            warnings[#warnings + 1] = b.recipe .. " : machine " ..
                b.machine.tile_w .. "x" .. b.machine.tile_h .. " non 3x3, I/O non routee"
        end
        if #b.inputs > 2 then
            ok = false
            warnings[#warnings + 1] = b.recipe .. " : " .. #b.inputs .. " ingredients (>2), I/O non routee"
        end
        if #b.outputs ~= 1 then
            ok = false
            warnings[#warnings + 1] = b.recipe .. " : " .. #b.outputs .. " produits (!=1), I/O non routee"
        end
        routable[b.id] = ok
    end

    -- 3. Aretes d'alimentation directe --------------------------------------
    local direct_in, direct_out, direct_item = {}, {}, {}
    for _, b in ipairs(plan.blocks) do
        if routable[b.id] then
            local cands = {}
            for _, inp in ipairs(b.inputs) do
                local pid = produced_by[inp.item]
                if pid and pid ~= b.id and not multi_produced[inp.item]
                    and #consumers[inp.item] == 1
                    and routable[pid] and not direct_out[pid] then
                    cands[#cands + 1] = { item = inp.item, from = pid, rate = inp.rate or 0 }
                end
            end
            table.sort(cands, function(a, c)
                if a.rate ~= c.rate then return a.rate > c.rate end
                return a.item < c.item
            end)
            if cands[1] then
                direct_in[b.id] = cands[1]
                direct_out[cands[1].from] = b.id
                direct_item[cands[1].item] = true
            end
        end
    end

    -- 4. Chaines (chemins de blocs relies en direct) ------------------------
    local chains, in_chain = {}, {}
    local function follow(head)
        local chain, cur = {}, head
        while cur and not in_chain[cur.id] do
            in_chain[cur.id] = true
            chain[#chain + 1] = cur
            cur = direct_out[cur.id] and by_id[direct_out[cur.id]] or nil
        end
        chains[#chains + 1] = chain
    end
    for _, b in ipairs(plan.blocks) do
        if not direct_in[b.id] and not in_chain[b.id] then follow(b) end
    end
    for _, b in ipairs(plan.blocks) do  -- cycles residuels : casser
        if not in_chain[b.id] then
            direct_in[b.id] = nil
            warnings[#warnings + 1] = "cycle de recettes casse a " .. b.recipe
            follow(b)
        end
    end

    -- 5. Tri topologique des chaines (dependances via items de bus) ---------
    local chain_of = {}
    for ci, chain in ipairs(chains) do
        for _, b in ipairs(chain) do chain_of[b.id] = ci end
    end
    local indeg, adj = {}, {}
    for ci = 1, #chains do indeg[ci] = 0; adj[ci] = {} end
    local seen_edge = {}
    for _, b in ipairs(plan.blocks) do
        for _, inp in ipairs(b.inputs) do
            local pid = produced_by[inp.item]
            if pid and not direct_item[inp.item] then
                local from, to = chain_of[pid], chain_of[b.id]
                if from and to and from ~= to then
                    local k = from .. ">" .. to
                    if not seen_edge[k] then
                        seen_edge[k] = true
                        table.insert(adj[from], to)
                        indeg[to] = indeg[to] + 1
                    end
                end
            end
        end
    end
    local ordered, queue = {}, {}
    for ci = 1, #chains do if indeg[ci] == 0 then table.insert(queue, ci) end end
    table.sort(queue)
    while #queue > 0 do
        local ci = table.remove(queue, 1)
        table.insert(ordered, chains[ci])
        for _, to in ipairs(adj[ci]) do
            indeg[to] = indeg[to] - 1
            if indeg[to] == 0 then table.insert(queue, to) end
        end
        table.sort(queue)
    end
    if #ordered < #chains then
        local placed = {}
        for _, c in ipairs(ordered) do placed[c] = true end
        for ci = 1, #chains do
            if not placed[chains[ci]] then table.insert(ordered, chains[ci]) end
        end
    end

    -- 6. Lanes de bus : base | partages | finaux, elaguees, espacees de 2 ---
    local roles = {}
    for item in pairs(consumers) do
        if not direct_item[item] then
            roles[item] = produced_by[item] and "inter" or "base"
        end
    end
    for item in pairs(produced_by) do
        if not consumers[item] and not direct_item[item] then roles[item] = "final" end
    end
    -- elagage : lane utile seulement si >=1 extremite routable
    local function lane_useful(item)
        local pid = produced_by[item]
        if pid and routable[pid] then return true end
        for _, cid in ipairs(consumers[item] or {}) do
            if routable[cid] then return true end
        end
        return false
    end
    local groups = { base = {}, inter = {}, final = {} }
    for item, role in pairs(roles) do
        if lane_useful(item) then
            table.insert(groups[role], item)
        else
            warnings[#warnings + 1] = item .. " : aucune extremite routable, pas de lane"
        end
    end
    table.sort(groups.base); table.sort(groups.inter); table.sort(groups.final)
    local lanes = {}
    for _, g in ipairs({ groups.base, groups.inter, groups.final }) do
        for _, item in ipairs(g) do
            lanes[#lanes + 1] = { item = item, x = 2 * #lanes }  -- espacement 2 (splitters)
        end
    end

    -- 7. Emission des blocs ---------------------------------------------------
    local parts = {}
    local function add(p) parts[#parts + 1] = p end
    local block_x0 = (#lanes > 0) and (2 * #lanes + MARGIN) or MARGIN
    local net = { lanes = lanes, inputs = {}, outputs = {}, block_x0 = block_x0 }
    local y = 1  -- rangee 0 reservee (splitter d'une entree en rangee 1)

    local function emit_belt_row(x0, row, width, direction)
        for cx = 0, width - 1 do
            add({ kind = "belt", name = plan.meta.belt, x = x0 + cx, y = row, direction = direction })
        end
    end

    for _, chain in ipairs(ordered) do
        local prev_width = 0
        for idx, b in ipairs(chain) do
            local head = (idx == 1)
            local width = b.count * M
            local by = y

            for i = 0, b.count - 1 do
                add({ kind = "machine", name = b.machine.name,
                      x = block_x0 + i * M, y = by + 3,
                      tile_w = b.machine.tile_w, tile_h = b.machine.tile_h,
                      recipe = b.recipe, accepts_recipe = b.machine.accepts_recipe,
                      quality = b.machine.quality, modules = b.modules })
            end

            if routable[b.id] then
                local ins = sorted_inputs(b)
                local far_pick, near_pick

                if head then
                    if ins[1] then
                        emit_belt_row(block_x0, by + 1, width, dir.east)
                        net.inputs[#net.inputs + 1] = { item = ins[1].item, row = by + 1 }
                    end
                    if ins[2] then
                        emit_belt_row(block_x0, by + 0, width, dir.east)
                        net.inputs[#net.inputs + 1] = { item = ins[2].item, row = by + 0 }
                    end
                    near_pick = ins[1] and (by + 1) or nil
                    far_pick = ins[2] and (by + 0) or nil
                else
                    if width > prev_width then
                        emit_belt_row(block_x0 + prev_width, by, width - prev_width, dir.west)
                    end
                    local bus_input = nil
                    for _, inp in ipairs(ins) do
                        if inp.item ~= direct_in[b.id].item then bus_input = inp end
                    end
                    if bus_input then
                        emit_belt_row(block_x0, by + 1, width, dir.east)
                        net.inputs[#net.inputs + 1] = { item = bus_input.item, row = by + 1 }
                    end
                    far_pick = by + 0
                    near_pick = bus_input and (by + 1) or nil
                end

                -- Inserters d'entree (y+2), direction = cote de prise (nord).
                for i = 0, b.count - 1 do
                    for col = 0, M - 1 do
                        local px = block_x0 + i * M + col
                        local pick
                        if head then
                            pick = (col == 1) and (far_pick or near_pick) or near_pick
                        else
                            pick = (col == 1) and (near_pick or far_pick) or far_pick
                        end
                        if pick then
                            local long = (by + 2 - pick) == 2
                            add({ kind = "inserter",
                                  name = long and plan.meta.long_inserter or plan.meta.inserter,
                                  x = px, y = by + 2, direction = dir.north })
                        end
                    end
                end

                -- Sortie : inserters (y+6) + belt (y+7, vers l'ouest).
                for i = 0, b.count - 1 do
                    for col = 0, M - 1 do
                        add({ kind = "inserter", name = plan.meta.inserter,
                              x = block_x0 + i * M + col, y = by + 6, direction = dir.north })
                    end
                end
                emit_belt_row(block_x0, by + 7, width, dir.west)

                -- Fin de chaine : la sortie doit rejoindre le bus.
                if not direct_out[b.id] then
                    net.outputs[#net.outputs + 1] = { item = b.outputs[1].item, row = by + 7 }
                end
            end

            prev_width = width
            y = by + 7
        end
        y = y + 1 + CHAIN_GAP
    end

    net.bus_bottom = math.max(y - CHAIN_GAP + 2, 10)

    return parts, warnings, net
end

return layout
