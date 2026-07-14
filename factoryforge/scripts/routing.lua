-- routing.lua
-- Relie le bus aux blocs et emet le bus lui-meme (specs/04 §6).
--   - Entree : splitter inline sur la lane (rangee R-1), virage, belts est jusqu'au bloc.
--   - Sortie : belts ouest depuis le bloc, side-load sur la lane cible.
--   - Croisement d'une lane : la LANE passe en souterrain (hop vertical).
--   - Obstacle sur une route horizontale (splitter/belt d'une autre connexion) :
--     PONT souterrain horizontal par-dessus.
-- Ordre : entrees triees par rangee DECROISSANTE (une route posee ne bloque jamais un
-- splitter futur, toujours plus haut), puis sorties.

local routing = {}

function routing.run(plan, parts, net)
    local dir = defines.direction
    local warnings = {}
    local function add(p) parts[#parts + 1] = p end

    local lane_by_item, lane_events, is_bus_col = {}, {}, {}
    for _, l in ipairs(net.lanes) do
        lane_by_item[l.item] = l
        lane_events[l.x] = {}   -- row -> "splitter"|"cross"|"merge"|"ug_in"|"ug_out"
        is_bus_col[l.x] = true
    end

    local occ = {}
    local function free(x, y) return not occ[x .. "," .. y] end
    local function take(x, y) occ[x .. "," .. y] = true end

    local UG_MAX = plan.meta.underground_max + 1  -- distance max entree->sortie

    -- Planifie un chemin horizontal [x1..x2] rangee R. Renvoie une liste d'actions ou nil.
    -- "cross" = colonne de bus (la lane plongera) ; "ug_a"/"ug_b" = pont horizontal.
    local function plan_hrun(x1, x2, R)
        local actions = {}
        local x = x1
        while x <= x2 do
            if free(x, R) then
                if is_bus_col[x] and lane_events[x][R] then return nil end
                actions[#actions + 1] = { type = is_bus_col[x] and "cross" or "belt", x = x }
                x = x + 1
            else
                -- obstacle [a..b] : pont souterrain de (a-1) a (b+1)
                local a = x
                local b = a
                while b <= x2 and not free(b, R) do b = b + 1 end
                b = b - 1
                local ein, eout = a - 1, b + 1
                if ein < x1 or eout > x2 then return nil end
                if (eout - ein) > UG_MAX then return nil end
                if not free(ein, R) or not free(eout, R) then return nil end
                if is_bus_col[ein] or is_bus_col[eout] then return nil end
                if #actions > 0 and actions[#actions].x == ein then table.remove(actions) end
                actions[#actions + 1] = { type = "ug_a", x = ein }
                actions[#actions + 1] = { type = "ug_b", x = eout }
                x = eout + 1
            end
        end
        return actions
    end

    local function commit_hrun(actions, R, direction)
        for _, a in ipairs(actions) do
            take(a.x, R)
            if a.type == "belt" or a.type == "cross" then
                if a.type == "cross" then lane_events[a.x][R] = "cross" end
                add({ kind = "belt", name = plan.meta.belt, x = a.x, y = R, direction = direction })
            else
                -- ug_a = extremite ouest, ug_b = extremite est ; l'amont depend du sens du flux
                local upstream = (a.type == "ug_a") == (direction == dir.east)
                add({ kind = "underground", name = plan.meta.underground, x = a.x, y = R,
                      direction = direction, ug_type = upstream and "input" or "output" })
            end
        end
    end

    -- 1. Entrees, rangees decroissantes --------------------------------------
    local inputs = {}
    for i, inp in ipairs(net.inputs) do inputs[i] = inp end
    table.sort(inputs, function(a, b)
        if a.row ~= b.row then return a.row > b.row end
        return a.item < b.item
    end)

    for _, inp in ipairs(inputs) do
        local L = lane_by_item[inp.item]
        if not L then
            warnings[#warnings + 1] = inp.item .. " : pas de lane sur le bus, entree non connectee"
        else
            local R = inp.row
            local S = R - 1  -- rangee du splitter
            local ok = (S >= 0)
                and free(L.x, S) and free(L.x + 1, S) and not lane_events[L.x][S]
                and free(L.x + 1, R)  -- virage
            local actions = ok and plan_hrun(L.x + 2, net.block_x0 - 1, R) or nil
            if actions then
                take(L.x, S); take(L.x + 1, S)
                lane_events[L.x][S] = "splitter"
                take(L.x + 1, R)
                add({ kind = "belt", name = plan.meta.belt, x = L.x + 1, y = R, direction = dir.east })
                commit_hrun(actions, R, dir.east)
            else
                warnings[#warnings + 1] = inp.item .. " (rangee " .. R ..
                    ") : conflit de routage, entree non connectee"
            end
        end
    end

    -- 2. Sorties : belts ouest + side-load sur la lane ------------------------
    for _, out in ipairs(net.outputs) do
        local L = lane_by_item[out.item]
        if not L then
            warnings[#warnings + 1] = out.item .. " : pas de lane sur le bus, sortie non connectee"
        else
            local R = out.row
            local actions = (not lane_events[L.x][R])
                and plan_hrun(L.x + 1, net.block_x0 - 1, R) or nil
            if actions then
                lane_events[L.x][R] = "merge"  -- reste une belt sud (cible du side-load)
                commit_hrun(actions, R, dir.west)
            else
                warnings[#warnings + 1] = out.item .. " (rangee " .. R ..
                    ") : conflit de routage, sortie non connectee"
            end
        end
    end

    -- 3. Hops : passer les lanes en souterrain aux rangees croisees -----------
    for _, l in ipairs(net.lanes) do
        local ev = lane_events[l.x]
        local rows = {}
        for r, e in pairs(ev) do
            if e == "cross" then rows[#rows + 1] = r end
        end
        table.sort(rows)
        local i = 1
        while i <= #rows do
            local a, b = rows[i], rows[i]
            while i + 1 <= #rows and rows[i + 1] == b + 1 do i = i + 1; b = rows[i] end
            i = i + 1
            local span = (b + 1) - (a - 1)
            if a - 1 < 0 or ev[a - 1] or ev[b + 1] or span > UG_MAX then
                warnings[#warnings + 1] = l.item .. " : croisement non pontable (rangees "
                    .. a .. "-" .. b .. "), lane coupee"
            else
                ev[a - 1] = "ug_in"
                ev[b + 1] = "ug_out"
            end
        end
    end

    -- 4. Emission des lanes ----------------------------------------------------
    for _, l in ipairs(net.lanes) do
        local ev = lane_events[l.x]
        for r = 0, net.bus_bottom - 1 do
            local e = ev[r]
            if e == "splitter" then
                add({ kind = "splitter", name = plan.meta.splitter, x = l.x, y = r,
                      tile_w = 2, tile_h = 1, direction = dir.south })
            elseif e == "cross" then
                -- belt horizontale en surface, la lane passe dessous
            elseif e == "ug_in" then
                add({ kind = "underground", name = plan.meta.underground, x = l.x, y = r,
                      direction = dir.south, ug_type = "input" })
            elseif e == "ug_out" then
                add({ kind = "underground", name = plan.meta.underground, x = l.x, y = r,
                      direction = dir.south, ug_type = "output" })
            else
                add({ kind = "belt", name = plan.meta.belt, x = l.x, y = r, direction = dir.south })
            end
        end
    end

    return parts, warnings
end

return routing
