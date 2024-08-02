-- Unlock robotics/blueprint-related shortcuts when the first tier
-- early construction technology is researched. Particularly useful
-- for personal roboport toggle shortcut.

local robotics_shortcuts = {
    "copy",
    "cut",
    "give-blueprint",
    "give-blueprint-book",
    "give-deconstruction-planner",
    "give-upgrade-planner",
    "import-string",
    "paste",
    "toggle-personal-roboport",
    "undo",
}

for _, shortcut in ipairs(robotics_shortcuts) do
    data.raw["shortcut"][shortcut].technology_to_unlock = "early-construction-light-armor"
end
