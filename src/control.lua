local -- Forward declare functions
      reset_individual_global_per_player,
      on_player_created,
      on_player_respawned,
      on_player_removed,
      on_robot_built,
      on_robot_mined,
      on_built_entity,
      on_player_mined_entity,
      on_player_placed_equipment,
      on_player_removed_equipment,
      on_player_armor_inventory_changed,
      on_player_main_inventory_changed,
      spill_from_inventory_if_necessary,
      on_tick,
      has_disallowed_equipment,
      track_robot,
      untrack_robot,
      create_robot_death_effect,
      update_tick_handler,
      on_init,
      on_load,
      on_configuration_changed,
      on_configuration_changed_migrate_0_3_to_0_4,
      on_configuration_changed_migrate_0_5_to_0_6,
      on_configuration_changed_migrate_0_9_to_1_0,
      on_configuration_changed_handle_startup_setting_changes

reset_individual_global_per_player = function (player_index)
    local player = game.players[player_index]
    local character = player.character
    local grid = character and character.grid or nil
    global.per_player[player_index] = {
        last_armor_reclaimation_tick = 0,
        has_disallowed_equipment = grid and has_disallowed_equipment(grid),
    }
    spill_from_inventory_if_necessary(player_index)
end
on_player_created = function (event)
    reset_individual_global_per_player(event.player_index)
end
on_player_respawned = on_player_created
on_player_removed = function (event)
    global.per_player[event.player_index] = nil
end

on_robot_built = function (event)
    local robot = event.robot
    if robot.name ~= 'early-construction-robot' then return end
    track_robot(robot, event.tick + 1)
end

on_robot_mined = function (event)
    local robot = event.robot
    if robot.name ~= 'early-construction-robot' then return end
    track_robot(robot, event.tick + 1)
end

on_built_entity = function (event)
    local entity = event.created_entity
    if not entity or entity.name ~= 'early-construction-robot' then return end
    local player = game.players[event.player_index]

    entity.destroy()
    player.print({'early-construction-errors.placing'}, {r=1,g=0,b=0,a=1})
    player.insert({ name = 'early-construction-robot', count = 1 })
end

on_player_mined_entity = function (event)
    if not event.entity or not event.entity.valid or event.entity.name ~= 'early-construction-robot' then return end
    if global.tracked_robots[event.entity.unit_number] ~= nil then
        event.buffer.remove({ name = 'early-construction-robot', count = 1 })
        create_robot_death_effect(event.entity)
        untrack_robot(event.entity.unit_number)
    end
end

-- Prevents using early construction robots with regular personal roboports
has_disallowed_equipment = function (grid)
    for _, equipment in pairs(grid.equipment) do
        if equipment.type == 'roboport-equipment' and equipment.name ~= 'early-construction-equipment' then
            return true
        end
    end
    return false
end

local function on_player_modified_equipment_common(event)
    local grid = event.grid
    local player = game.players[event.player_index]

    local character = player.character
    local is_equipped = character ~= nil and character.grid == grid
    if not is_equipped then return end

    return player, character, grid
end

on_player_placed_equipment = function (event)
    local equipment = event.equipment
    if equipment.type ~= 'roboport-equipment' then return end
    if equipment.name == 'early-construction-equipment' then return end

    local player, character, grid = on_player_modified_equipment_common(event)
    if player == nil then return end

    local inventory = player.get_main_inventory()
    local robot_count = inventory.get_item_count('early-construction-robot')

    local per_player = global.per_player[player.index]
    if robot_count == 0 then
        per_player.has_disallowed_equipment = true
        return
    end

    player.print({'early-construction-errors.incompatible-equipment'}, {r=1,g=0,b=0,a=1})
    local item_stack = grid.take({ equipment = equipment, by_player = player })
    inventory.insert(item_stack)
end

on_player_removed_equipment = function (event)
    local player, character, grid = on_player_modified_equipment_common(event)
    if player == nil then return end

    local per_player = global.per_player[player.index]
    per_player.has_disallowed_equipment = has_disallowed_equipment(grid)
end

on_player_armor_inventory_changed = function (event)
    local player = game.players[event.player_index]

    local character = player.character
    if character == nil then return end

    local armor_slot = character.get_inventory(defines.inventory.character_armor)[1]
    local grid = armor_slot.valid and armor_slot.valid_for_read and armor_slot.grid or nil

    local per_player = global.per_player[player.index]
    if grid == nil or not has_disallowed_equipment(grid) then
        per_player.has_disallowed_equipment = false
        return
    end

    local inventory = player.get_main_inventory()
    local robot_count = inventory.get_item_count('early-construction-robot')
    if robot_count == 0 then
        per_player.has_disallowed_equipment = true
        return
    end
    
    player.print({'early-construction-errors.incompatible-equipment'}, {r=1,g=0,b=0,a=1})

    -- Put in inventory or drop on ground

    -- Clearing the player's hand location is necessary for properly swapping
    -- out armors. If you do not have this, then the game will "re-insert" the
    -- armor in the armor slot, causing an endless loop, and spilling them item
    -- instead.
    player.hand_location = nil

    -- Even with the previous line, there are still scenarios where there will
    -- be an "infinite loop" of the game picking up the item, and inserting it
    -- into the armor slot. If we already attempted to insert the armor into the
    -- inventory in the last 125ms, it falls back to spilling the armor into the
    -- world.
    local empty_stack = inventory.find_empty_stack(armor_slot.name)
    local per_player = global.per_player[player.index]
    if per_player.last_armor_reclaimation_tick + 8 < event.tick and
        empty_stack ~= nil and
        empty_stack.set_stack(armor_slot)
    then
        per_player.last_armor_reclaimation_tick = event.tick
        armor_slot.clear()
        return
    end

    character.surface.spill_item_stack(
        character.position, armor_slot,
        --[[enable_looted]] false, --[[force]] nil, --[[allow_belts]] false)
    armor_slot.clear()
end

on_player_main_inventory_changed = function (event)
    spill_from_inventory_if_necessary(event.player_index)
end

spill_from_inventory_if_necessary = function (player_index)
    local per_player = global.per_player[player_index]
    if not per_player.has_disallowed_equipment then return end

    local player = game.players[player_index]
    local character = player.character
    -- In theory, has_disallowed_equipment should always be false when there is
    -- no character, since a lack of character means a lack of equipment grid.
    -- In practice, there's probably some scenarios, such as right after a
    -- player dies, where this could occur, so better safeguard.
    if character == nil then return end

    local inventory = player.get_main_inventory()
    local robot_count = inventory.get_item_count('early-construction-robot')

    if robot_count == 0 then return end

    player.print({'early-construction-errors.robots-in-inventory'}, {r=1,g=0,b=0,a=1})
    local item_stack = { name = 'early-construction-robot', count = robot_count }
    character.surface.spill_item_stack(
        character.position, item_stack,
        --[[enable_looted]] false, --[[force]] nil, --[[allow_belts]] false)
    inventory.remove(item_stack)
end

on_tick = function (event)
    for unit_number, entry in pairs(global.tracked_robots) do
        if not entry.robot.valid then
            untrack_robot(unit_number)
        elseif event.tick >= entry.no_destruction_before_tick then
            local holds_items = false
            if entry.cargo_inventory.valid and not entry.cargo_inventory.is_empty() then holds_items = true end
            if entry.repair_inventory.valid and not entry.repair_inventory.is_empty() then holds_items = true end

            if not holds_items then
                untrack_robot(unit_number)
                create_robot_death_effect(entry.robot)
                entry.robot.destroy({
                    do_cliff_correction = false,
                    raise_destroy = true,
                })
            end
        end
    end
end

track_robot = function (robot, no_destruction_before_tick)
    if global.tracked_robots[robot.unit_number] then
        untrack_robot(robot.unit_number)
    end

    global.tracked_robots[robot.unit_number] = {
        robot = robot,
        no_destruction_before_tick = no_destruction_before_tick,
        cargo_inventory = robot.get_inventory(defines.inventory.robot_cargo),
        repair_inventory = robot.get_inventory(defines.inventory.robot_repair),
    }
    update_tick_handler()
end

untrack_robot = function (unit_number)
    if global.tracked_robots[unit_number] == nil then return end
    global.tracked_robots[unit_number] = nil
    update_tick_handler()
end

create_robot_death_effect = function (robot)
    robot.surface.create_entity({
        name = 'explosion-hit',
        position = robot.position,
        force = robot.force,
    })
end

update_tick_handler = function ()
    local should_be_ticking = table_size(global.tracked_robots) > 0
    global.is_ticking = should_be_ticking
    script.on_event(defines.events.on_tick, should_be_ticking and on_tick or nil)
end

on_init = function ()
    global.tracked_robots = {}
    global.tracked_robots_count = 0
    global.robots_pending_destruction = {}
    global.forces = {}
    for _, force in pairs(game.forces) do
        global.forces[force.name] = {}
    end
end

on_load = function ()
    if global.is_ticking then
        script.on_event(defines.events.on_tick, on_tick)
    end
end

on_configuration_changed = function (changes)
    if global.version == nil then
        on_configuration_changed_migrate_0_3_to_0_4()
        on_configuration_changed_migrate_0_5_to_0_6()
    end
    if global.version == 1 then
        on_configuration_changed_migrate_0_9_to_1_0()
    end

    if changes.mod_startup_settings_changed or changes.mod_changes['early_construction'] then
        on_configuration_changed_handle_startup_setting_changes()
    end
end

on_configuration_changed_migrate_0_3_to_0_4 = function ()
    -- Renamed global.tracked_robot_count to global.tracked_robots_count
    if global.tracked_robot_count then
        global.tracked_robot_count = nil
    end

    -- Previously, this variable wasn't initialized upon init, and was instead nil-checked
    -- now it is initialized. This variable can be safely derived from global.tracked_robots.
    if global.tracked_robots_count == nil then
        local count = 0
        for _ in pairs(global.tracked_robots) do
            count = count + 1
        end
        global.tracked_robots_count = count
    end

    -- Renamed global.ticking to global.is_ticking
    -- update_tick_handler invoked later will take care of initializing the global variable,
    -- and setting up the event handler if necessary.
    global.ticking = nil

    -- Newly introduced variables
    if global.robots_pending_destruction == nil then
        global.robots_pending_destruction = {}
    end

    update_tick_handler()
end

on_configuration_changed_migrate_0_5_to_0_6 = function ()
    local old_tracked_robots = global.tracked_robots
    for k, _ in pairs(global) do
        global[k] = nil
    end

    global.version = 1
    global.tracked_robots = {}
    for _, entry in pairs(old_tracked_robots) do
        local robot = entry.robot
        if (robot and
            robot.valid and
            robot.name == 'early-construction-robot' and
            global.tracked_robots[robot.unit_number] == nil) then

            global.tracked_robots[robot.unit_number] = {
                robot = robot,
                cargo_inventory = robot.get_inventory(defines.inventory.robot_cargo),
                repair_inventory = robot.get_inventory(defines.inventory.robot_repair),
                no_destruction_before_tick = game.tick + 1,
            }
        end
    end

    update_tick_handler()
end

on_configuration_changed_migrate_0_9_to_1_0 = function ()
    global.version = 2
    global.per_player = {}
    for _, player in pairs(game.players) do
        reset_individual_global_per_player(player.index)
    end
end

on_configuration_changed_handle_startup_setting_changes = function ()
    for _, force in pairs(game.forces) do
        if force.technologies['early-construction-light-armor'].researched then
            log(('[early_construction] resetting technology effects for force %q'):format(force.name))
            force.reset_technology_effects()
        end
    end
end

script.on_event(defines.events.on_player_created, on_player_created)
script.on_event(defines.events.on_player_respawned, on_player_respawned)
script.on_event(defines.events.on_player_removed, on_player_removed)
script.on_event(defines.events.on_robot_built_entity, on_robot_built)
script.on_event(defines.events.on_robot_built_tile, on_robot_built)
script.on_event(defines.events.on_robot_mined, on_robot_mined)
script.on_event(defines.events.on_built_entity, on_built_entity)
script.on_event(defines.events.on_player_mined_entity, on_player_mined_entity)
script.on_event(defines.events.on_player_placed_equipment, on_player_placed_equipment)
script.on_event(defines.events.on_player_removed_equipment, on_player_removed_equipment)
script.on_event(defines.events.on_player_armor_inventory_changed, on_player_armor_inventory_changed)
script.on_event(defines.events.on_player_main_inventory_changed, on_player_main_inventory_changed)

script.on_init(on_init)
script.on_load(on_load)
script.on_configuration_changed(on_configuration_changed)

-- commands.add_command('early_construction_dump_global', nil, function (command)
--     game.print('Global table for early_construction:')
--     game.print(serpent.block(global))
-- end)
