data:extend({
    {
        name = 'early-construction-enable-entity-ghosts-when-destroyed',
        type = 'bool-setting',
        setting_type = 'startup',
        order = 'a',
        default_value = true
    },
    {
      type = "int-setting",
      name = "early-construction-robot-by-craft",
      setting_type = "startup",
      default_value = 6,
      minimum_value = 1,
      order = "a"
    },
})