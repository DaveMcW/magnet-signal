local signal = table.deepcopy(data.raw["rail-signal"]["rail-signal"])
signal.name = "magnet-signal"
signal.icon = "__magnet-signal__/graphics/magnet-signal.png"
signal.icon_size = 32
signal.icons = nil
signal.orange_light.color = signal.green_light.color
signal.red_light.color = signal.green_light.color
signal.circuit_wire_max_distance = 0
signal.circuit_wire_connection_points = {}
signal.circuit_connector_sprites = {}
signal.animation.filename = "__magnet-signal__/graphics/rail-signal.png"
signal.animation.hr_version.filename = "__magnet-signal__/graphics/hr-rail-signal.png"
data:extend{signal}

local item = {
  type = "item",
  name = "magnet-signal",
  place_result = "magnet-signal",
  stack_size = 50,
  icon = "__magnet-signal__/graphics/magnet-signal.png",
  icon_size = 32,
  subgroup = "transport",
  order = "a[train-system]-d[rail-signal]-magnet",
}
data:extend{item}

local recipe = {
  type = "recipe",
  name = "magnet-signal",
  result = "magnet-signal",
  ingredients = table.deepcopy(data.raw.recipe["rail-signal"].ingredients),
  enabled = false,
}
data:extend{recipe}

table.insert(data.raw.technology["rail-signals"].effects, {
  type = "unlock-recipe",
  recipe = "magnet-signal"
})

local driver = table.deepcopy(data.raw.character.character)
driver.name = "magnet-signal-driver"
driver.collision_mask = {}
driver.flags = {"placeable-off-grid", "not-on-map", "not-repairable", "not-flammable"}
data:extend{driver}
