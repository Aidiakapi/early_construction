local -- Forward declare functions
      on_robot_built,
      on_robot_mined,
      on_built_entity,
      on_tick,
      on_tick_tracked_robots,
      on_tick_pending_destruction,
      update_tick_handler,
      track_robot,
      untrack_robot,
      queue_robot_destruction,
      get_associated_player,
      global_force,
      warn_force_of_incorrect_usage,
      on_configuration_changed_migrate_0_3_to_0_4,
      on_configuration_changed_handle_startup_setting_changes

on_robot_built = function (event)
    local robot = event.robot
    if robot.name ~= 'early-construction-robot' then return end
    queue_robot_destruction(robot)
end

on_robot_mined = function (event)
    local robot = event.robot
    if robot.name ~= 'early-construction-robot' then return end
    local player = get_associated_player(robot)
    if not player then
        warn_force_of_incorrect_usage(robot.force, event.tick)
        queue_robot_destruction(robot)
        return
    end

    local inventory = robot.get_inventory(defines.inventory.robot_cargo)
    track_robot(robot, player, inventory)
end

on_built_entity = function (event)
    local entity = event.created_entity
    if entity.name ~= 'early-construction-robot' then return end
    local player = game.players[event.player_index]

    entity.destroy()
    player.print('Early construction robots cannot be deployed manually, use an early construction equipment in the armor instead.', {r=1,g=0,b=0,a=1})
    player.insert({ name = 'early-construction-robot', count = 1 })
end

on_tick = function (event)
    if global.tracked_robots_count > 0 then
        on_tick_tracked_robots()
    end
    if #global.robots_pending_destruction > 0 then
        on_tick_pending_destruction(event)
    end
end

on_tick_tracked_robots = function ()
    for unit_number, entry in pairs(global.tracked_robots) do
        if not entry.player.valid or
           not entry.robot.valid or
           not entry.cargo_inventory.valid or
           entry.cargo_inventory.is_empty() then
            queue_robot_destruction(entry.robot)
            untrack_robot(unit_number)
        end
    end
end

on_tick_pending_destruction = function (event)
    for _, robot in ipairs(global.robots_pending_destruction) do
        if robot.valid then
            local inventory = robot.get_inventory(defines.inventory.robot_cargo)
            local should_destroy = true

            local player = get_associated_player(robot)
            if not player then
                warn_force_of_incorrect_usage(robot.force, event.tick)
            elseif inventory and not inventory.is_empty() then
                track_robot(robot, player, inventory)
                should_destroy = false
            end

            if should_destroy then
                -- When robots both repair and destroy/build an item, they'd normally
                -- lose the repair packs. This moves those repair packs back into the
                -- players' inventory.
                local player_inventory = player.get_main_inventory()
                local repair_inventory = robot.get_inventory(defines.inventory.robot_repair)
                if repair_inventory and not repair_inventory.is_empty() then
                    for i = 1, #repair_inventory do
                        local item_stack = repair_inventory[i]
                        if item_stack.valid_for_read then
                            player_inventory.insert(item_stack)
                        end
                    end
                end

                robot.surface.create_entity({
                    name = 'explosion-hit',
                    position = robot.position,
                    force = robot.force,
                })
                robot.destroy({
                    do_cliff_correction = false,
                    raise_destroy = true,
                })
            end
        end
    end
    global.robots_pending_destruction = {}
    update_tick_handler()
end

script.on_event(defines.events.on_robot_built_entity, on_robot_built)
script.on_event(defines.events.on_robot_built_tile, on_robot_built)

script.on_event(defines.events.on_robot_mined, on_robot_mined)

script.on_event(defines.events.on_built_entity, on_built_entity)

script.on_init(function ()
    global.tracked_robots = {}
    global.tracked_robots_count = 0
    global.robots_pending_destruction = {}
    global.forces = {}
    for _, force in pairs(game.forces) do
        global.forces[force.name] = {}
    end
end)
script.on_load(function ()
    if global.is_ticking then
        script.on_event(defines.events.on_tick, on_tick)
    end
end)

script.on_configuration_changed(function (changes)
    on_configuration_changed_migrate_0_3_to_0_4()

    if changes.mod_startup_settings_changed or changes.mod_changes['early_construction'] then
        on_configuration_changed_handle_startup_setting_changes()
    end
end)

script.on_event(defines.events.on_force_created, function (event)
    global.forces[event.force.name] = {}
end)
script.on_event(defines.events.on_forces_merged, function (event)
    global.forces[event.source_name] = nil
end)

update_tick_handler = function ()
    local should_be_ticking = false
    if global.tracked_robots_count > 0 then
        should_be_ticking = true
    end
    if #global.robots_pending_destruction > 0 then
        should_be_ticking = true
    end

    global.is_ticking = should_be_ticking
    if should_be_ticking then
        script.on_event(defines.events.on_tick, on_tick)
    else
        script.on_event(defines.events.on_tick, nil)
    end
end

track_robot = function (robot, player, cargo_inventory)
    if global.tracked_robots[robot.unit_number] then
        untrack_robot(robot.unit_number)
    end
    global.tracked_robots_count = global.tracked_robots_count + 1
    global.tracked_robots[robot.unit_number] = {
        robot = robot,
        player = player,
        cargo_inventory = cargo_inventory,
    }
    update_tick_handler()
end

untrack_robot = function (unit_number)
    if global.tracked_robots[unit_number] == nil then return end
    global.tracked_robots_count = global.tracked_robots_count - 1
    global.tracked_robots[unit_number] = nil
    update_tick_handler()
end

queue_robot_destruction = function (robot)
    if not robot.valid then return end
    
    table.insert(global.robots_pending_destruction, robot)
    update_tick_handler()
end

get_associated_player = function (robot)
    local logistic_network = robot.logistic_network
    if logistic_network then
        local logistic_cell = logistic_network.cells[1]
        if logistic_cell then
            local owner = logistic_cell.owner
            if owner and owner.type == 'character' then
                return owner
            end
        end
    end
end

global_force = function (force)
    return global.forces[force.name]
end

warn_force_of_incorrect_usage = function (force, tick)
    local global = global_force(force)
    local previous_warn_tick = global.previous_warn_tick
    if previous_warn_tick == nil or previous_warn_tick + 3600 <= tick then
        force.print('Early construction robots must only be used with personal roboport equipment.', {r=1, g=0, b=0, a=1})
        global.previous_warn_tick = tick
    end
end

on_configuration_changed_migrate_0_3_to_0_4 = function ()
    --[[
        Migration from 0.3 to 0.4
    --]]
    
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

on_configuration_changed_handle_startup_setting_changes = function ()
    for _, force in pairs(game.forces) do
        if force.technologies['early-construction-light-armor'].researched then
            log(('[early_construction] resetting technology effects for force %q'):format(force.name))
            force.reset_technology_effects()
        end
    end
end
