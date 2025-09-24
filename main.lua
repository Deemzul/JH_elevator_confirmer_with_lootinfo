--TODO (maybe): truncate strings that may be too long, like a fully modded MDF item (truncate the name, not the suffixes)
--these tables get precompiled
dzec_compiled = false
dzec_type_to_index  =  {} --I don't know Lua well enough whether these need to exist
dzec_types  = {}
dzec_counts = {}
function ec_add(b,c,d,a)
    c[#c+1] = a
    b[a]=#c
    d[#c] = 0
end

function ec_compile_lists()
    dzec_type_to_index  =  {}
    dzec_types  = {}
    dzec_counts = {}
    --insertion complicates things, so two passes to get ammo prioritized on top
    for idx,b in ipairs( blueprints ) do
        if b.stack and b.blueprint and b.blueprint == "ammo_base" then
            ec_add(dzec_type_to_index,dzec_types,dzec_counts, b.id)
        end
    end

    --second pass for everything else
    for idx,b in ipairs( blueprints ) do
        if not dzec_type_to_index[b.id] and ((b.stack or (b.flags and (b.flags[1] == EF_CONSUMABLE or b.flags[2] == EF_CONSUMABLE or b.flags[3] == EF_CONSUMABLE or b.flags[1] == EF_POWERUP or b.flags[2] == EF_POWERUP or b.flags[3] == EF_POWERUP ))) and b.text and b.text.name)  then --TODO: maybe iterate through flags? by the way, blueprint.flags[EF_CONSUMABLE] doesn't work
            ec_add(dzec_type_to_index,dzec_types,dzec_counts, b.id)
        end
    end
    dzec_compiled = true
end


register_blueprint "elevator_confirmer"
{
	flags = { EF_NOPICKUP },
    
	data = {
    },
    callbacks = {
        on_enter_level = [=[
            function ( self, entity, reenter )
                self.data[world.data.current] = true
            end
        ]=],
        on_pre_command = [=[
function ( self, entity, command, a, b,c,d )
            if c and c ~= 0 then
                return 0
            end
            if not dzec_compiled then
                ec_compile_lists()
            end
            if core.command_dir[command] then
                local p = world:get_position(entity)
                local level = world:get_level()
                local exit_types = { exit= true, 
                                    elevator_01=true, 
                                    elevator_01_branch=true, 
                                    elevator_01_special=true, 
                                    elevator_01_mini=true, 
                                    elevator_01_mini_back=true, 
                                    elevator_01_special_back=true, 
                                    portal_01=true, 
                                    elevator_01_royal=true
                                    }
                p = p + core.command_dir[command]
                for ea in level:entities(p) do
                    if exit_types[world:get_id(ea)] then
                        local typ = world:get_id(ea)
                        local unopened = 0
                        local station_charges = 0
                        local unspecial = false
                        local unmini = false
                        local s
                        local s_lootbox = ""
                        local s_station_charge = ""
                        local s_unvisited_special = ""
                        local s_unvisited_mini = ""
                        local s_branch = ""
                        local s_entering = ""
                        local max_consumable_name_length = 0
                        local max_consumable_count = 0
                        local temp = 0
                        local assorted_loot = 0
                        local assorted_loot_s = ""
                        local assorted_loot_s_hori = 0
                        for e in level:entities() do
                            local cur_id = world:get_id(e)
                            
                            if level.level_info.cleared or (e.minimap and e.minimap.always) or level:is_explored(e:get_position()) then
                                --lootboxes
                                if e.data and e.data.lootbox and e.flags and e.flags.data[EF_ACTION] then
                                    unopened = unopened + 1
                                    if 9>max_consumable_name_length then -- "Lootboxes"
                                        max_consumable_name_length = 9
                                    end
                                end
                                --station charges
                                if e.data and e.data.terminal and e.attributes and e.attributes.charges then
                                    station_charges = station_charges + e.attributes.charges
                                    if 15>max_consumable_name_length then -- "Station charges"
                                        max_consumable_name_length = 15
                                    end
                                end
                                --consumables
                                if dzec_type_to_index[cur_id] then
                                    s = world:get_text(cur_id,"name")
                                    if s:sub(1,1) == "{" then
                                        temp = string.len(s) - 3
                                    else
                                        temp = string.len(s)
                                    end
                                    if temp>max_consumable_name_length then
                                        max_consumable_name_length = temp
                                    end
                                    if e.stack then
                                        dzec_counts[dzec_type_to_index[cur_id]] = (dzec_counts[dzec_type_to_index[cur_id]] or 0) + (e.stack.amount or 1)
                                    else
                                        dzec_counts[dzec_type_to_index[cur_id]] = (dzec_counts[dzec_type_to_index[cur_id]] or 0) + 1
                                    end
                                    if dzec_counts[dzec_type_to_index[cur_id]] > max_consumable_count then
                                        max_consumable_count = dzec_counts[dzec_type_to_index[cur_id]]
                                    end
                                end
                                --uniques, exotics, advanceds
                                if e.text and ((e.data and (e.data.exotic or e.data.relic or e.data.perk or (e.attributes and e.attributes.unique_tier))) or (e.attributes and e:attribute("mod_level") > 0) and e ~= entity) then
                                    local namen
                                    local namen_color = ""
                                    if e.data then
                                        -- if e.ascii then --there's inconsistency with the ascii definitions (because unused)
                                            -- if e.ascii.color == MAGENTA then
                                                -- namen_color = "{M"
                                            -- elseif e.ascii.color == CYAN or e.ascii.color == YELLOW then
                                                -- namen_color = "{C"
                                            -- elseif e.ascii.color == GREEN then
                                                -- namen_color = "{G"
                                            -- elseif e.ascii.color == RED then
                                                -- namen_color = "{R"
                                            -- end
                                        -- end
                                        if e.data.exotic then
                                            namen_color = "{M"
                                        elseif e.attributes and e.attributes.unique_tier then
                                            namen_color = "{G"
                                        elseif e.data.perk  then
                                            namen_color = "{C"
                                        elseif e.data.relic then
                                            if e.ascii and e.ascii.color == MAGENTA then --the color is in relic_minor and relic_major, so, unlikely to have inconsistency
                                                namen_color = "{M"
                                            else
                                                namen_color = "{R"
                                            end
                                        end
                                    else
                                        namen_color = "{"
                                    end
                                    if e.text.prefix ~= "" then
                                        namen = e.text.prefix.." "..e.text.name
                                    else
                                        namen = e.text.name
                                    end
                                    namen = string.sub(namen,1,17)
                                    if e.text.suffix ~= "" then
                                        namen = namen.." "..e.text.suffix
                                    end
                                    local horilen = string.len(namen)
                                    if namen_color ~= "" then
                                        namen = namen_color..namen.."}"
                                    end
                                    assorted_loot_s = assorted_loot_s..namen.."\n"
                                    if horilen>assorted_loot_s_hori then
                                        assorted_loot_s_hori = horilen
                                    end
                                    assorted_loot = assorted_loot + 1
                                end
                            end
                        end
                        
                        local vert = 0
                        local hori = 21
                        local cur_level = world.data.level[world.data.current]
                        
                        --BRANCH
                        if cur_level.branch and typ~="elevator_01_branch" then
                            vert = vert + 1
                            s_branch = world.data.level[cur_level.branch].name
                            s_branch = "Branch available: {!"..s_branch.."}\n"
                            hori = math.max(hori, #s_branch+2)
                        end
                        
                        --SPECIAL
                        --if cur_level.special and not world.data.level[cur_level.special].visited then
                        if cur_level.special and not self.data[cur_level.special] and typ~="elevator_01_special" then
                            unspecial = true
                            vert = vert + 1
                            s_unvisited_special = "Unvisited special level\n"
                            hori = math.max(hori, 27)
                        end
                        
                        --MINI
                        if cur_level.mini and not self.data[cur_level.mini] and typ~="elevator_01_mini" then
                            unmini = true
                            vert = vert + 1
                            s_unvisited_mini = "Unvisited mini level\n"
                            hori = math.max(hori, 24)
                        end
                        
                        --FINALLY: If any of the strings were set, display the info box
                        if vert > 0 then
                            ui:alert{
                                title    = "",
                                footer = " ",
                                teletype = 0,
                                content = s_unvisited_special..s_unvisited_mini..s_branch,
                                position = ivec2(30,25),
                                -- position = ivec2(1+math.floor((80-hori)/2),13-vert),
                                -- position = ivec2(1+math.floor((80-hori)/2),8-vert),
                                -- position = ivec2(21,15-vert),
                                modal = true,
                                size = ivec2(hori,vert+4),
                            }
                        end
                        
                        local format_string = "%"..tostring(max_consumable_name_length).."s"
                        --CONSUMBALE INFO
                        -- do
                            local s_ammo = ""
                            vert = 0
                            for _,count in ipairs(dzec_counts) do
                                local atyp = dzec_types[_]
                                if count > 0 then
                                    local cur_name = world:get_text(atyp,"name")
                                    local format_string_plus = "%"..tostring(max_consumable_name_length+3).."s"
                                    if cur_name:sub(1,1) == "{" then
                                        -- s_ammo = s_ammo..string.format(format_string_plus, cur_name:sub(1,max_consumable_name_length+3))..": {!"..tostring(count).."}\n"
                                        s_ammo = s_ammo..string.format(format_string_plus, cur_name)..": {!"..tostring(count).."}\n"
                                    else
                                        -- s_ammo = s_ammo..string.format(format_string, cur_name:sub(1,max_consumable_name_length))..": {!"..tostring(count).."}\n"
                                        s_ammo = s_ammo..string.format(format_string, cur_name)..": {!"..tostring(count).."}\n"
                                    end
                                    vert = vert + 1
                                end
                                dzec_counts[_] = 0
                            end
                            
                            local part_one = false
                            local part_two = false
                            if s_ammo ~= "" then
                                part_one = true
                            end
                            
                            --LOOTBOXES
                            if unopened > 0 then
                                vert = vert + 1
                                s_lootbox = string.format(format_string, "lootboxes")..": {!".. unopened .."}\n"
                                part_two = true
                            end
                            
                            --STATION CHARGES
                            if station_charges > 0 then
                                vert = vert + 1
                                s_station_charge = string.format(format_string, "station charges")..": {!".. station_charges .."}\n"
                                part_two = true
                            end 
                            
                            if vert > 0 then
                                if part_one and part_two then
                                    s_ammo = s_ammo.."\n"
                                    vert = vert + 1
                                end
                                s_ammo = s_ammo..s_lootbox
                                s_ammo = s_ammo..s_station_charge
                                local count_plus = 1
                                while max_consumable_count > 9 do
                                    max_consumable_count = max_consumable_count / 10
                                    count_plus = count_plus +1
                                end
                                hori = 6+max_consumable_name_length+count_plus --4 for borders, 2 for ": "
                                ui:alert{
                                    title    = "",
                                    footer = " ",
                                    teletype = 0,
                                    content = s_ammo,
                                    position = ivec2(math.max(1,30-hori),math.max(0,19-vert/2)),
                                    modal = true,
                                    size = ivec2(hori,math.min(40,4+vert)),
                                }
                            end
                        -- end
                        if not level.level_info.cleared then
                            ui:alert{
                                title    = "",
                                footer = " ",
                                teletype = 0,
                                content = "{RLevel not cleared}",
                                position = ivec2(30,13),
                                modal = true,
                                size = ivec2(21,5),
                            }
                        end
                        if assorted_loot > 0 then
                                ui:alert{
                                    title    = "",
                                    footer = " ",
                                    teletype = 0,
                                    content = assorted_loot_s,
                                    position = ivec2(51,math.max(0,21-assorted_loot)),
                                    modal = true,
                                    size = ivec2(math.min(assorted_loot_s_hori+4,29),math.min(40,4+assorted_loot)),
                                }
                        end
                        ui:confirm {
                            size    = ivec2( 21, 8 ),
                            content = "  Are you sure? \n",
                            actor   = entity,
                            command = command,
                        }
                        return -1
                    end
                end
                return 0
            end
            return 0
        end
]=]
    }
}


world.register_on_entity( function(x) if x.data and x.data.ai and x.data.ai.group == "player" and not x:child("elevator_confirmer") then x:attach("elevator_confirmer") end end)