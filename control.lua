-- Constant tables
-- Indexing a constant table is faster than creating a new one
local IS_CARRIAGE = {
  ["locomotive"] = true,
  ["cargo-wagon"] = true,
  ["fluid-wagon"] = true,
  ["artillery-wagon"] = true,
}
local ACCELERATING_STRAIGHT = {
  [defines.rail_direction.front] = {
    acceleration = defines.riding.acceleration.accelerating,
    direction = defines.riding.direction.straight,
  },
  [defines.rail_direction.back] = {
    acceleration = defines.riding.acceleration.reversing,
    direction = defines.riding.direction.straight,
  },
}
local ACCELERATING_LEFT = {
  [defines.rail_direction.front] = {
    acceleration = defines.riding.acceleration.accelerating,
    direction = defines.riding.direction.left,
  },
  [defines.rail_direction.back] = {
    acceleration = defines.riding.acceleration.reversing,
    direction = defines.riding.direction.left,
  },
}
local ACCELERATING_RIGHT = {
  [defines.rail_direction.front] = {
    acceleration = defines.riding.acceleration.accelerating,
    direction = defines.riding.direction.right,
  },
  [defines.rail_direction.back] = {
    acceleration = defines.riding.acceleration.reversing,
    direction = defines.riding.direction.right,
  },
}
local RAIL_STRAIGHT = {
  [defines.rail_direction.front] = {
    rail_direction = defines.rail_direction.front,
    rail_connection_direction = defines.rail_connection_direction.straight,
  },
  [defines.rail_direction.back] = {
    rail_direction = defines.rail_direction.back,
    rail_connection_direction = defines.rail_connection_direction.straight,
  },
}
local RAIL_RIGHT = {
  [defines.rail_direction.front] = {
    rail_direction = defines.rail_direction.front,
    rail_connection_direction = defines.rail_connection_direction.right,
  },
  [defines.rail_direction.back] = {
    rail_direction = defines.rail_direction.back,
    rail_connection_direction = defines.rail_connection_direction.right,
  },
}
local RAIL_LEFT = {
  [defines.rail_direction.front] = {
    rail_direction = defines.rail_direction.front,
    rail_connection_direction = defines.rail_connection_direction.left,
  },
  [defines.rail_direction.back] = {
    rail_direction = defines.rail_direction.back,
    rail_connection_direction = defines.rail_connection_direction.left,
  },
}

function on_init()
  global.trains = {}

  -- Unlock recipe
  for _, force in pairs(game.forces) do
    if force.technologies["rail-signals"].researched then
      force.recipes["magnet-signal"].enabled = true
    end
  end
end

function on_train_changed_state(event)
  local train = event.train
  if train.state == defines.train_state.arrive_signal then
    if train.signal and train.signal.name == "magnet-signal" then
      start_control(train)
    end
  end
end

function on_killed(event)
  if IS_CARRIAGE[event.prototype.type] then
    -- Clean up any dummy drivers that fell out of a destroyed train
    local pos = event.position
    for _, driver in pairs(game.surfaces[event.surface_index].find_entities_filtered{
      name = "underground-rail-driver",
      area = {{pos.x - 10, pos.y - 10}, {pos.x + 10, pos.y + 10}}
    }) do
      driver.destroy()
    end
  end
end

function on_tick()
  for i = #global.trains, 1, -1 do
    local train = global.trains[i].train
    local path = global.trains[i].path
    local path_index = global.trains[i].path_index

    -- Do we still have control of the train?
    if train and train.valid and train.manual_mode and path_index <= #path and train.speed ~= 0 then

      -- Find the driver
      local driver = global.trains[i].driver
      if driver and driver.valid and driver.vehicle and driver.vehicle.train == train then
        -- Use cached driver
      else
        -- Get a new driver
        driver = get_driver(train)
        global.trains[i].driver = driver
      end

      -- Find the front rail and direction
      local rail
      local rail_direction
      local acceleration_direction
      if train.speed > 0 then
        rail = train.front_rail
        rail_direction = train.rail_direction_from_front_rail
        acceleration_direction = defines.rail_direction.front
      else
        rail = train.back_rail
        rail_direction = 1 - train.rail_direction_from_back_rail
        acceleration_direction = defines.rail_direction.back
      end

      -- Follow the path
      if path[path_index] == rail then
        path_index = path_index + 1
        global.trains[i].path_index = path_index
      end
      if not rail or not rail.valid then
        -- Dead end track
        stop_control(train)
        table.remove(global.trains, i)
      elseif path[path_index] == rail.get_connected_rail(RAIL_STRAIGHT[rail_direction]) then
        -- Go straight
        driver.riding_state = ACCELERATING_STRAIGHT[acceleration_direction]
      elseif path[path_index] == rail.get_connected_rail(RAIL_RIGHT[rail_direction]) then
        -- Go left
        driver.riding_state = ACCELERATING_RIGHT[acceleration_direction]
      elseif path[path_index] == rail.get_connected_rail(RAIL_LEFT[rail_direction]) then
        -- Go right
        driver.riding_state = ACCELERATING_LEFT[acceleration_direction]
      else
        -- Lost the path
        stop_control(train)
        table.remove(global.trains, i)
      end

    else
      -- Lost control
      stop_control(train)
      table.remove(global.trains, i)
    end
  end
end

function start_control(train)
  -- Copy the path
  local path = {}
  local destinations = train.signal.get_connected_rails()
  local final_loop = false
  for _, rail in pairs(train.path.rails) do
    table.insert(path, rail)
    if final_loop then
      break
    end
    for _, destination in pairs(destinations) do
      if rail == destination then
        -- Add one more rail after the signal
        final_loop = true
      end
    end
  end

  -- Turn off automatic mode
  train.manual_mode = true

  -- Add to list of controlled trains
  table.insert(global.trains, {
    train = train,
    path = path,
    path_index = 1,
    driver = get_driver(train),
  })
end

function stop_control(train)
  -- Remove dummy driver
  for _, carriage in pairs(train.carriages) do
    driver = carriage.get_driver()
    if driver and driver.prototype.name == "magnet-signal-driver" then
      driver.destroy()
    end
  end

  -- Toggle automatic mode
  train.manual_mode = not train.manual_mode
end

function get_driver(train)
  -- Find an existing driver
  local driver = nil
  for _, carriage in pairs(train.carriages) do
    driver = carriage.get_driver()
    if driver then return driver end
  end

  -- Create a dummy driver
  local carriage = train.carriages[1]
  local driver = carriage.surface.create_entity{
    name = "magnet-signal-driver",
    position = {0, 0},
    force = carriage.force,
  }
  carriage.set_driver(driver)
  return driver
end

script.on_init(on_init)
script.on_event(defines.events.on_train_changed_state, on_train_changed_state)
script.on_event(defines.events.on_post_entity_died, on_killed)
script.on_event(defines.events.on_tick, on_tick)
