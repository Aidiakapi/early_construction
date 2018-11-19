local -- Forward declare functions
      on_robot_built,
      on_robot_pre_mined,
      on_built_entity,
      on_tick,
      track_robot,
      untrack_robot,
      global_force,
      get_associated_player,
      warn_force_of_incorrect_usage


on_robot_built = function (event)
    local robot = event.robot
    if robot.name ~= 'early-construction-robot' then return end
    local player = get_associated_player(robot)
    if player then
        robot.die(robot.force, player)
    else
        robot.die(robot.force)
    end
end

on_robot_pre_mined = function (event)
    local robot = event.robot
    if robot.name ~= 'early-construction-robot' then return end
    local player = get_associated_player(robot)
    if not player then
        warn_force_of_incorrect_usage(robot.force, event.tick)
        robot.die(robot.force)
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
    for unit_number, entry in pairs(global.tracked_robots) do
        if not entry.player.valid or not entry.robot.valid then
            untrack_robot(unit_number)
            if entry.robot.valid then
                entry.robot.die(entry.robot.force)
            end
        else
            if entry.cargo_inventory.is_empty() then
                untrack_robot(unit_number)
                entry.robot.die(entry.player.force, entry.player)
            end
        end
    end
end

script.on_event(defines.events.on_robot_built_entity, on_robot_built)
script.on_event(defines.events.on_robot_built_tile, on_robot_built)

script.on_event(defines.events.on_robot_pre_mined, on_robot_pre_mined)

script.on_event(defines.events.on_built_entity, on_built_entity)

script.on_init(function ()
    global.tracked_robots = {}
    global.forces = {}
    for _, force in pairs(game.forces) do
        global.forces[force.name] = {}
    end
end)
script.on_load(function ()
    if global.ticking then
        script.on_event(defines.events.on_tick, on_tick)
    end
end)
script.on_event(defines.events.on_force_created, function (event)
    global.forces[event.force.name] = {}
end)
script.on_event(defines.events.on_forces_merged, function (event)
    global.forces[event.source_name] = nil
end)

track_robot = function (robot, player, cargo_inventory)
    if not global.ticking then
        global.ticking = true
        script.on_event(defines.events.on_tick, on_tick)
    end
    global.tracked_robot_count = ((global.tracked_robot_count or 0) + 1)
    global.tracked_robots[robot.unit_number] = {
        robot = robot,
        player = player,
        cargo_inventory = cargo_inventory,
    }
end

untrack_robot = function (unit_number)
    local tracked_robot_count = global.tracked_robot_count
    global.tracked_robot_count = tracked_robot_count - 1
    if tracked_robot_count == 1 then
        global.ticking = false
        script.on_event(defines.events.on_tick, nil)
    end
    global.tracked_robots[unit_number] = nil
end

global_force = function (force)
    return global.forces[force.name]
end

get_associated_player = function (robot)
    local logistic_network = robot.logistic_network
    if logistic_network then
        local logistic_cell = logistic_network.cells[1]
        if logistic_cell then
            local owner = logistic_cell.owner
            if owner and owner.type == 'player' then
                return owner
            end
        end
    end
end

warn_force_of_incorrect_usage = function (force, tick)
    local global = global_force(force)
    local previous_warn_tick = global.previous_warn_tick
    if previous_warn_tick == nil or previous_warn_tick + 3600 <= tick then
        force.print('Early construction robots must only be used with personal roboport equipment.', {r=1, g=0, b=0, a=1})
        global.previous_warn_tick = tick
    end
end
