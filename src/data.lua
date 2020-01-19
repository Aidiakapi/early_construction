require("util")

local electronic_circuit = "electronic-circuit"
if data.raw.item["basic-circuit-board"] ~= nil then
    electronic_circuit = "basic-circuit-board"
end

local function combine_effects(...)
    local n = select("#", ...)
    local effects = {}
    for i = 1, n do
        local current = select(i, ...)
        if type(current) == "table" then
            for _, v in pairs(current) do
                effects[#effects + 1] = v
            end
        end
    end
    return effects
end

local ghosts_when_destroyed_effects
if settings.startup["early-construction-enable-entity-ghosts-when-destroyed"].value then
    ghosts_when_destroyed_effects = { {
        type = "ghost-time-to-live",
        modifier = 60 * 60 * 60 * 24 * 7
    } }
end

data:extend(
    {
        -- Equipment
        {
            type = "equipment-category",
            name = "early-construction-armor"
        },
        {
            type = "item",
            name = "early-construction-equipment",
            icon = "__early_construction__/graphics/early-construction-equipment.png",
            icon_size = 32,
            placed_as_equipment_result = "early-construction-equipment",
            flags = {},
            subgroup = "equipment",
            order = "e[robotics]-a[early-construction-equipment]",
            stack_size = 5
        },
        {
            type = "roboport-equipment",
            name = "early-construction-equipment",
            take_result = "early-construction-equipment",
            sprite = {
                filename = "__early_construction__/graphics/early-construction-equipment.png",
                width = 32,
                height = 32,
                priority = "medium"
            },
            shape = {
                width = 1,
                height = 1,
                type = "full"
            },
            energy_source = {
                type = "electric",
                buffer_capacity = "0MJ",
                input_flow_limit = "0kW",
                usage_priority = "secondary-input"
            },
            charging_energy = "0kW",
            robot_limit = 15,
            construction_radius = 12,
            spawn_and_station_height = 0.4,
            charge_approach_distance = 2.6,
            recharging_animation = {
                filename = "__base__/graphics/entity/roboport/roboport-recharging.png",
                priority = "high",
                width = 37,
                height = 35,
                frame_count = 16,
                scale = 0.75,
                animation_speed = 0.5
            },
            recharging_light = {intensity = 0.4, size = 5},
            stationing_offset = {0, -0.6},
            charging_station_shift = {0, 0.5},
            charging_station_count = 0,
            charging_distance = 1.6,
            charging_threshold_distance = 5,
            categories = {"early-construction-armor"}
        },
        -- Armor
        {
            type = "equipment-grid",
            name = "small-early-construction-equipment-grid",
            width = 1,
            height = 1,
            equipment_categories = {"early-construction-armor"}
        },
        {
            type = "equipment-grid",
            name = "medium-early-construction-equipment-grid",
            width = 2,
            height = 1,
            equipment_categories = {"early-construction-armor"}
        },
        {
            type = "armor",
            name = "early-construction-light-armor",
            icon = "__early_construction__/graphics/light-armor.png",
            icon_size = 32,
            flags = {},
            resistances = {
                {
                    type = "physical",
                    decrease = 3,
                    percent = 20
                },
                {
                    type = "acid",
                    decrease = 0,
                    percent = 20
                },
                {
                    type = "explosion",
                    decrease = 2,
                    percent = 20
                },
                {
                    type = "fire",
                    decrease = 0,
                    percent = 10
                }
            },
            subgroup = "armor",
            equipment_grid = "small-early-construction-equipment-grid",
            order = "a[light-armozr][early-construction]",
            stack_size = 1,
            infinite = true
        },
        {
            type = "armor",
            name = "early-construction-heavy-armor",
            icon = "__early_construction__/graphics/heavy-armor.png",
            icon_size = 32,
            flags = {},
            resistances = {
                {
                    type = "physical",
                    decrease = 6,
                    percent = 30
                },
                {
                    type = "explosion",
                    decrease = 20,
                    percent = 30
                },
                {
                    type = "acid",
                    decrease = 0,
                    percent = 40
                },
                {
                    type = "fire",
                    decrease = 0,
                    percent = 30
                }
            },
            subgroup = "armor",
            equipment_grid = "medium-early-construction-equipment-grid",
            order = "b[heavy-armozr][early-construction]",
            stack_size = 1,
            infinite = true
        },
        -- Robot
        {
            type = "item",
            name = "early-construction-robot",
            icon = "__early_construction__/graphics/early-construction-robot.png",
            icon_size = 32,
            flags = {},
            subgroup = "logistic-network",
            order = "a[robot]-b[early-construction-robot]",
            place_result = "early-construction-robot",
            stack_size = 200
        },
        {
            type = "construction-robot",
            name = "early-construction-robot",
            icon = "__early_construction__/graphics/early-construction-robot.png",
            icon_size = 32,
            flags = {"placeable-player", "player-creation", "placeable-off-grid", "not-on-map"},
            minable = {hardness = 0.1, mining_time = 0.1, result = "early-construction-robot"},
            resistances = {{type = "fire", percent = 85}},
            max_health = 100,
            collision_box = {{0, 0}, {0, 0}},
            selection_box = {{-0.5, -1.5}, {0.5, -0.5}},
            max_payload_size = 5,
            speed = 0.06,
            transfer_distance = 0.5,
            max_energy = "1MJ",
            energy_per_tick = "0kJ",
            speed_multiplier_when_out_of_energy = 1,
            energy_per_move = "0kJ",
            min_to_charge = 0.1,
            max_to_charge = 0.2,
            working_light = {intensity = 0.8, size = 3, color = {r = 0.8, g = 0.8, b = 0.8}},
            dying_explosion = "explosion",
            idle = {
                filename = "__early_construction__/graphics/early-construction-robot/construction-robot.png",
                priority = "high",
                line_length = 16,
                width = 32,
                height = 36,
                frame_count = 1,
                shift = {0, -0.15625},
                direction_count = 16,
                hr_version = {
                    filename = "__early_construction__/graphics/early-construction-robot/hr-construction-robot.png",
                    priority = "high",
                    line_length = 16,
                    width = 66,
                    height = 76,
                    frame_count = 1,
                    shift = util.by_pixel(0, -4.5),
                    direction_count = 16,
                    scale = 0.5
                }
            },
            in_motion = {
                filename = "__early_construction__/graphics/early-construction-robot/construction-robot.png",
                priority = "high",
                line_length = 16,
                width = 32,
                height = 36,
                frame_count = 1,
                shift = {0, -0.15625},
                direction_count = 16,
                y = 36,
                hr_version = {
                    filename = "__early_construction__/graphics/early-construction-robot/hr-construction-robot.png",
                    priority = "high",
                    line_length = 16,
                    width = 66,
                    height = 76,
                    frame_count = 1,
                    shift = util.by_pixel(0, -4.5),
                    direction_count = 16,
                    y = 76,
                    scale = 0.5
                }
            },
            shadow_idle = {
                filename = "__early_construction__/graphics/early-construction-robot/construction-robot-shadow.png",
                priority = "high",
                line_length = 16,
                width = 50,
                height = 24,
                frame_count = 1,
                shift = {1.09375, 0.59375},
                direction_count = 16,
                hr_version = {
                    filename = "__early_construction__/graphics/early-construction-robot/hr-construction-robot-shadow.png",
                    priority = "high",
                    line_length = 16,
                    width = 104,
                    height = 49,
                    frame_count = 1,
                    shift = util.by_pixel(33.5, 18.75),
                    direction_count = 16,
                    scale = 0.5
                }
            },
            shadow_in_motion = {
                filename = "__early_construction__/graphics/early-construction-robot/construction-robot-shadow.png",
                priority = "high",
                line_length = 16,
                width = 50,
                height = 24,
                frame_count = 1,
                shift = {1.09375, 0.59375},
                direction_count = 16,
                hr_version = {
                    filename = "__early_construction__/graphics/early-construction-robot/hr-construction-robot-shadow.png",
                    priority = "high",
                    line_length = 16,
                    width = 104,
                    height = 49,
                    frame_count = 1,
                    shift = util.by_pixel(33.5, 18.75),
                    direction_count = 16,
                    scale = 0.5
                }
            },
            working = {
                filename = "__early_construction__/graphics/early-construction-robot/construction-robot-working.png",
                priority = "high",
                line_length = 2,
                width = 28,
                height = 36,
                frame_count = 2,
                shift = {0, -0.15625},
                direction_count = 16,
                animation_speed = 0.3,
                hr_version = {
                    filename = "__early_construction__/graphics/early-construction-robot/hr-construction-robot-working.png",
                    priority = "high",
                    line_length = 2,
                    width = 57,
                    height = 74,
                    frame_count = 2,
                    shift = util.by_pixel(-0.25, -5),
                    direction_count = 16,
                    animation_speed = 0.3,
                    scale = 0.5
                }
            },
            shadow_working = {
                stripes = util.multiplystripes(
                    2,
                    {
                        {
                            filename = "__early_construction__/graphics/early-construction-robot/construction-robot-shadow.png",
                            width_in_frames = 16,
                            height_in_frames = 1
                        }
                    }
                ),
                priority = "high",
                width = 50,
                height = 24,
                frame_count = 2,
                shift = {1.09375, 0.59375},
                direction_count = 16
            },
            smoke = {
                filename = "__base__/graphics/entity/smoke-construction/smoke-01.png",
                width = 39,
                height = 32,
                frame_count = 19,
                line_length = 19,
                shift = {0.078125, -0.15625},
                animation_speed = 0.3
            },
            sparks = {
                {
                    filename = "__base__/graphics/entity/sparks/sparks-01.png",
                    width = 39,
                    height = 34,
                    frame_count = 19,
                    line_length = 19,
                    shift = {-0.109375, 0.3125},
                    tint = {r = 1.0, g = 0.9, b = 0.0, a = 1.0},
                    animation_speed = 0.3
                },
                {
                    filename = "__base__/graphics/entity/sparks/sparks-02.png",
                    width = 36,
                    height = 32,
                    frame_count = 19,
                    line_length = 19,
                    shift = {0.03125, 0.125},
                    tint = {r = 1.0, g = 0.9, b = 0.0, a = 1.0},
                    animation_speed = 0.3
                },
                {
                    filename = "__base__/graphics/entity/sparks/sparks-03.png",
                    width = 42,
                    height = 29,
                    frame_count = 19,
                    line_length = 19,
                    shift = {-0.0625, 0.203125},
                    tint = {r = 1.0, g = 0.9, b = 0.0, a = 1.0},
                    animation_speed = 0.3
                },
                {
                    filename = "__base__/graphics/entity/sparks/sparks-04.png",
                    width = 40,
                    height = 35,
                    frame_count = 19,
                    line_length = 19,
                    shift = {-0.0625, 0.234375},
                    tint = {r = 1.0, g = 0.9, b = 0.0, a = 1.0},
                    animation_speed = 0.3
                },
                {
                    filename = "__base__/graphics/entity/sparks/sparks-05.png",
                    width = 39,
                    height = 29,
                    frame_count = 19,
                    line_length = 19,
                    shift = {-0.109375, 0.171875},
                    tint = {r = 1.0, g = 0.9, b = 0.0, a = 1.0},
                    animation_speed = 0.3
                },
                {
                    filename = "__base__/graphics/entity/sparks/sparks-06.png",
                    width = 44,
                    height = 36,
                    frame_count = 19,
                    line_length = 19,
                    shift = {0.03125, 0.3125},
                    tint = {r = 1.0, g = 0.9, b = 0.0, a = 1.0},
                    animation_speed = 0.3
                }
            },
            working_sound = {
                sound = {
                    {filename = "__base__/sound/flying-robot-1.ogg", volume = 0.6},
                    {filename = "__base__/sound/flying-robot-2.ogg", volume = 0.6},
                    {filename = "__base__/sound/flying-robot-3.ogg", volume = 0.6},
                    {filename = "__base__/sound/flying-robot-4.ogg", volume = 0.6},
                    {filename = "__base__/sound/flying-robot-5.ogg", volume = 0.6}
                },
                max_sounds_per_type = 3,
                audible_distance_modifier = 0.5,
                probability = 1 / (3 * 60) -- average pause between the sound is 3 seconds
            },
            cargo_centered = {0.0, 0.2},
            construction_vector = {0.30, 0.22}
        },
        -- Recipes
        {
            type = "recipe",
            name = "early-construction-light-armor",
            enabled = false,
            energy_required = 3,
            ingredients = {
                {"light-armor", 1},
                {"iron-plate", 10},
                {"iron-gear-wheel", 5},
                {electronic_circuit, 40}
            },
            result = "early-construction-light-armor"
        },
        {
            type = "recipe",
            name = "early-construction-heavy-armor",
            enabled = false,
            energy_required = 8,
            ingredients = {
                {"early-construction-light-armor", 1},
                {"heavy-armor", 1},
                {"electronic-circuit", 200},
                {"steel-plate", 20}
            },
            result = "early-construction-heavy-armor"
        },
        {
            type = "recipe",
            enabled = false,
            name = "early-construction-equipment",
            energy_required = 1,
            ingredients = {{electronic_circuit, 10}},
            result = "early-construction-equipment"
        },
        {
            type = "recipe",
            name = "early-construction-robot",
            enabled = false,
            energy_required = 3,
            ingredients = {
                {"repair-pack", 1 },
                {"coal", 2 }
            },
            result = "early-construction-robot",
            result_count = 6
        },
        -- Technologies
        {
            type = "technology",
            name = "early-construction-light-armor",
            icon_size = 128,
            icon = "__early_construction__/graphics/technology.png",
            effects = combine_effects({
                {
                    type = "unlock-recipe",
                    recipe = "early-construction-robot"
                },
                {
                    type = "unlock-recipe",
                    recipe = "early-construction-light-armor"
                },
                {
                    type = "unlock-recipe",
                    recipe = "early-construction-equipment"
                },
            }, ghosts_when_destroyed_effects),
            unit = {
                count = 25,
                ingredients = {{"automation-science-pack", 1}},
                time = 5
            },
            order = "a-c-a"
        },
        {
            type = "technology",
            name = "early-construction-heavy-armor",
            icon_size = 128,
            icon = "__early_construction__/graphics/technology.png",
            effects = {
                {
                    type = "unlock-recipe",
                    recipe = "early-construction-heavy-armor"
                }
            },
            prerequisites = {"heavy-armor", "early-construction-light-armor"},
            unit = {
                count = 200,
                ingredients = {
                    {"automation-science-pack", 1},
                    {"logistic-science-pack", 1}
                },
                time = 30
            },
            order = "a-c-b"
        }
    }
)
