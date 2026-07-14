-- routing.lua
-- Increment 2 : relie le bus aux blocs et emet le bus lui-meme.
--   - Entree de bloc : SPLITTER inline sur la lane (rangee R-1), sortie droite -> belt est
--     jusqu'a la belt d'entree du bloc.
--   - Sortie de fin de chaine : belt ouest depuis le bloc, SIDE-LOAD sur la lane cible.
--   - Croisements : la LANE passe en souterrain (hop vertical), la belt horizontale reste
--     continue en surface.
-- Recoit les "net" du layout (lanes, entrees/sorties, block_x0, bus_bottom).
-- Voir specs/04 §6.

local routing = {}

--- Mute parts (ajoute bus + routes) ; renvoie les warnings.
---@param plan table ProductionPlan (pour meta)
---@param parts table liste de parts du layout (mutee)
---@param net table { lanes, inputs, outputs, block_x0, bus_bottom }
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

    -- Occupation des cellules de la zone bus/marge (hors blocs).
    local occ = {}
    local function free(x, y) return not occ[x .. "," .. y] end
    local function take(x, y) occ[x .. "," .. y] = true end

    -- Chemin horizontal [x1..x2] a la rangee R : verifie, puis pose belts + marque les croisements.
    local function route_ok(x1, x2, R)
        for x = x1, x2 do
            if not free(x, R) then return false end
        end
        return true
    end
    local function route_commit(x1, x2, R, direction)
        for x = x1, x2 do
            take(x, R)
            if is_bus_col[x] then lane_events[x][R] = "cross" end
            add({ kind = "belt", name = plan.meta.belt, x = x, y = R, direction = direction })
        end
    end

    -- 1. Entrees : splitter sur la lane + belt est jusqu'au bloc ------------
    for _, inp in ipairs(net.inputs) do
        local L = lane_by_item[inp.item]
        if not L then
            warnings[#warnings + 1] = inp.item .. " : pas de lane sur le bus, entree non connectee"
        else
            local R = inp.row
            local ok = (R >= 1)
                and free(L.x, R - 1) and free(L.x + 1, R - 1)
                and not lane_events[L.x][R - 1]
                and route_ok(L.x + 1, net.block_x0 - 1, R)
            if ok then
                take(L.x, R - 1); take(L.x + 1, R - 1)
                lane_events[L.x][R - 1] = "splitter"
                route_commit(L.x + 1, net.block_x0 - 1, R, dir.east)
            else
                warnings[#warnings + 1] = inp.item .. " (rangee " .. R ..
                    ") : conflit de routage, entree non connectee"
            end
        end
    end

    -- 2. Sorties de fin de chaine : belt ouest + side-load sur la lane ------
    for _, out in ipairs(net.outputs) do
        local L = lane_by_item[out.item]
        if not L then
            warnings[#warnings + 1] = out.item .. " : pas de lane sur le bus, sortie non connectee"
        else
            local R = out.row
            local ok = (not lane_events[L.x][R])   -- la cellule cible doit rester une belt sud
                and route_ok(L.x + 1, net.block_x0 - 1, R)
            if ok then
                lane_events[L.x][R] = "merge"       -- reserve (emise comme belt sud normale)
                route_commit(L.x + 1, net.block_x0 - 1, R, dir.west)
            else
                warnings[#warnings + 1] = out.item .. " (rangee " .. R ..
                    ") : conflit de routage, sortie non connectee"
            end
        end
    end

    -- 3. Hops : passer les lanes en souterrain aux rangees croisees ---------
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
            if a - 1 < 0 or ev[a - 1] or ev[b + 1]
                or span > (plan.meta.underground_max + 1) then
                warnings[#warnings + 1] = l.item .. " : croisement non pontable (rangees "
                    .. a .. "-" .. b .. "), lane coupee"
            else
                ev[a - 1] = "ug_in"
                ev[b + 1] = "ug_out"
            end
        end
    end

    -- 4. Emission des lanes ---------------------------------------------------
    for _, l in ipairs(net.lanes) do
        local ev = lane_events[l.x]
        for r = 0, net.bus_bottom - 1 do
            local e = ev[r]
            if e == "splitter" then
                add({ kind = "splitter", name = plan.meta.splitter, x = l.x, y = r,
                      tile_w = 2, tile_h = 1, direction = dir.south })
            elseif e == "cross" then
                -- la belt horizontale occupe la cellule, la lane passe dessous
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
