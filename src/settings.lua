data:extend({
    {
        name = 'early-construction-enable-entity-ghosts-when-destroyed',
        type = 'bool-setting',
        setting_type = 'startup',
        order = 'a',
        default_value = true
    },
    {
      type = 'int-setting',
      name = 'early-construction-robots-per-craft',
      setting_type = 'startup',
      order = 'b',
      default_value = 6,
      minimum_value = 1,
      maximum_value = 50
    },
})