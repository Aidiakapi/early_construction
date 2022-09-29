require("util")

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

local light_armor_ingredients = {
    {"light-armor", 1},
    {"iron-plate", 10},
    {"iron-gear-wheel", 5},
    {"electronic-circuit", 40}
}
local heavy_armor_ingredients = {
    {"early-construction-light-armor", 1},
    {"heavy-armor", 1},
    {"electronic-circuit", 200},
    {"steel-plate", 20}
}
local equipment_ingredients = {
    {"electronic-circuit", 10}
}
local robot_ingredients = {
    {"repair-pack", 1 },
    {"coal", 2 }
}

local function patch_strings(from, to, table)
    for k, v in pairs(table) do
        if v == from then
            table[k] = to
        elseif type(v) == "table" then
            patch_strings(from, to, v)
        end
    end
end
--[[
    Bob's Electronics compatibility patch
]]
if data.raw.item["basic-circuit-board"] ~= nil then
    patch_strings("electronic-circuit", "basic-circuit-board", light_armor_ingredients)
    patch_strings("electronic-circuit", "basic-circuit-board", equipment_ingredients)
end

--[[
    Industrial Revolution compatibility patch
]]
if data.raw.technology["deadlock-bronze-age"] ~= nil then
    light_armor_ingredients = {
        {"light-armor", 1},
        {"copper-plate", 10},
        {"tin-gear-wheel", 5},
        {"copper-motor", 10}
    }
    heavy_armor_ingredients = {
        {"early-construction-light-armor", 1},
        {"heavy-armor", 1},
        {"copper-motor", 50},
        {"bronze-chassis-small", 1}
    }
    equipment_ingredients = {
        {"copper-motor", 5}
    }
    robot_ingredients = {
        {"tin-plate", 1},
        {"copper-gear-wheel", 1},
        {"coal", 2}
    }
end

local base_robot = data.raw['construction-robot']['construction-robot']
local function robot_clone_and_modify(value)
    local t = type(value)
    if t == 'table' then
        local new_value = {}
        for k, v in pairs(value) do
            new_value[robot_clone_and_modify(k)] = robot_clone_and_modify(v)
        end
        return new_value
    elseif t == 'string' then
        if value:find('__base__/graphics/entity/construction-robot/', 1, true) == 1
            and value:find('/', 45, true) == nil then
            return '__early_construction__/graphics/early-construction-robot/' .. value:sub(45)
        else
            return value
        end
    else
        return value
    end
end
local function robot_property(name)
    return robot_clone_and_modify(base_robot[name])
end

-- Apply armor type to character animation, borrowed from Simply Power Armor MK3
-- Contributed by millerlarson
for _, animation in ipairs(data.raw['character']['character']['animations']) do
    if animation.armors then
        for _, armor in ipairs(animation.armors) do
            if armor == 'light-armor' then
                animation.armors[#animation.armors + 1] = 'early-construction-light-armor'
            elseif armor == 'heavy-armor' then
                animation.armors[#animation.armors + 1] = 'early-construction-heavy-armor'
            end
        end
    end
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
            order = "a[light-armor][early-construction]",
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
            order = "b[heavy-armor][early-construction]",
            stack_size = 1,
            infinite = true
        },
        -- Robot
        {
            type = "item",
            name = "early-construction-robot",
            icon = "__early_construction__/graphics/early-construction-robot.png",
            icon_size = 64, icon_mipmaps = 4,
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
            icon_size = 64, icon_mipmaps = 4,
            flags = {"placeable-player", "player-creation", "placeable-off-grid", "not-on-map"},
            minable = {hardness = 0.1, mining_time = 0.1, result = "early-construction-robot"},
            resistances = {{type = "fire", percent = 85}},
            max_health = 50,
            collision_box = {{0, 0}, {0, 0}},
            selection_box = {{-0.5, -1.5}, {0.5, -0.5}},
            hit_visualization_box = {{-0.1, -1.1}, {0.1, -1.0}},
            damaged_trigger_effect = robot_property('damaged_trigger_effect'),
            max_payload_size = 5,
            speed = 0.06,
            max_energy = "1MJ",
            energy_per_tick = "0kJ",
            speed_multiplier_when_out_of_energy = 1,
            energy_per_move = "0kJ",
            min_to_charge = 0.1,
            max_to_charge = 0.2,
            working_light = {intensity = 0.8, size = 3, color = {r = 0.85, g = 0.75, b = 0.75}},
            dying_explosion = "explosion",
            sparks = robot_property('sparks'),
            working_sound = robot_property('working_sound'),
            cargo_centered = {0.0, 0.2},
            construction_vector = {0.30, 0.22},
            water_reflection = robot_property('water_reflection'),
            idle = robot_property('idle'),
            idle_with_cargo = robot_property('idle_with_cargo'),
            in_motion = robot_property('in_motion'),
            in_motion_with_cargo = robot_property('in_motion_with_cargo'),
            shadow_idle = robot_property('shadow_idle'),
            shadow_idle_with_cargo = robot_property('shadow_idle_with_cargo'),
            shadow_in_motion = robot_property('shadow_in_motion'),
            shadow_in_motion_with_cargo = robot_property('shadow_in_motion_with_cargo'),
            working = robot_property('working'),
            shadow_working = robot_property('shadow_working'),
        },
        -- Recipes
        {
            type = "recipe",
            name = "early-construction-light-armor",
            enabled = false,
            energy_required = 3,
            ingredients = light_armor_ingredients,
            result = "early-construction-light-armor"
        },
        {
            type = "recipe",
            name = "early-construction-heavy-armor",
            enabled = false,
            energy_required = 8,
            ingredients = heavy_armor_ingredients,
            result = "early-construction-heavy-armor"
        },
        {
            type = "recipe",
            enabled = false,
            name = "early-construction-equipment",
            energy_required = 1,
            ingredients = equipment_ingredients,
            result = "early-construction-equipment"
        },
        {
            type = "recipe",
            name = "early-construction-robot",
            enabled = false,
            energy_required = 3,
            ingredients = robot_ingredients,
            result = "early-construction-robot",
            result_count = settings.startup["early-construction-robot-by-craft"].value
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
            prerequisites = {"heavy-armor", "early-construction-light-armor", "logistic-science-pack"},
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
