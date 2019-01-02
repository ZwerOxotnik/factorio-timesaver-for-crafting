-- Event listener
-- Copyright (c) 2019 ZwerOxotnik <zweroxotnik@gmail.com>
-- License: MIT
-- Version: 0.1.0 (2019.02.01)
-- Source: https://gitlab.com/ZwerOxotnik/event-listener
-- Homepage: https://mods.factorio.com/mod/event-listener

local mod = {}

local function create_container(list, name_event)
  local container = {}
  for _name_mod, _ in pairs( list ) do
    if type(list[_name_mod]) == 'table' and type(list[_name_mod].events) == 'table' and list[_name_mod].events[name_event] then
      table.insert(container, list[_name_mod].events[name_event])
    end
  end
  return container
end

local function handle_events(list)
  local is_used = {}
  for name_mod, _ in pairs( list ) do
    if type(list[name_mod]) == 'table' and type(list[name_mod].events) == 'table' then
      for name_event, _ in pairs( list[name_mod].events ) do
        local target_event = defines.events[name_event]
        if target_event and not is_used[name_event] then
          is_used[name_event] = true
          if script.get_event_handler(target_event) == nil then
            script.on_event(target_event, function(event)
              for _, _event in pairs( create_container(list, name_event) ) do
                _event(event)
              end
            end)
          else
            log("event '" .. name_event .. "' can't be handle")
          end
        end
      end
    end
  end

  is_used = {}
  for _, name_event in pairs( {'on_init', 'on_configuration_changed', 'on_load'} ) do
    local add_func = script[name_event]
    if add_func then
      for name_mod, _ in pairs( list ) do
        if type(list[name_mod]) == 'table' and type(list[name_mod].events) == 'table' then
          for name, _ in pairs( list[name_mod].events ) do
            if not is_used[name_event] and name == name_event then
              is_used[name_event] = true
              add_func(function()
                for _, _event in pairs( create_container(list, name_event) ) do
                  _event()
                end
              end)
            end
          end
        end
      end
    else
      log("event '" .. name_event .. "' can't be handle")
    end
  end
end

-- Handle all possible events from list for the game
mod.add_events = function(list)
  if type(list) == 'table' then
    handle_events(list)
  else
    log('Type of list is not table!')
  end
end

return mod
