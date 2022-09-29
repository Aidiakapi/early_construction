local -- Forward declare functions
      on_robot_built,
      on_robot_mined,
      on_built_entity,
      on_player_mined_entity,
      on_tick,
      track_robot,
      untrack_robot,
      create_robot_death_effect,
      update_tick_handler,
      on_init,
      on_load,
      on_configuration_changed,
      on_configuration_changed_migrate_0_3_to_0_4,
      on_configuration_changed_migrate_0_5_to_0_6,
      on_configuration_changed_handle_startup_setting_changes

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
    player.print('Early construction robots cannot be deployed manually, use an early construction equipment in the basic schall suit instead.', {r=1,g=0,b=0,a=1})
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
        game.print('[Early Construction] Migrated to version 0.7.')
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

on_configuration_changed_handle_startup_setting_changes = function ()
    for _, force in pairs(game.forces) do
        if force.technologies['early-construction'].researched then
            log(('[early_construction] resetting technology effects for force %q'):format(force.name))
            force.reset_technology_effects()
        end
    end
end

script.on_event(defines.events.on_robot_built_entity, on_robot_built)
script.on_event(defines.events.on_robot_built_tile, on_robot_built)
script.on_event(defines.events.on_robot_mined, on_robot_mined)
script.on_event(defines.events.on_built_entity, on_built_entity)
script.on_event(defines.events.on_player_mined_entity, on_player_mined_entity)

script.on_init(on_init)
script.on_load(on_load)
script.on_configuration_changed(on_configuration_changed)
