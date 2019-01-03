-- Timesaver for crafting
-- Copyright (c) 2019 ZwerOxotnik <zweroxotnik@gmail.com>
-- License: MIT
-- Version: 0.1.0 (2019.02.01)
-- Description: Lost crafting time is compensated.
-- Your craft speeds up depending on your craft activity.
-- Source: https://gitlab.com/ZwerOxotnik/timesaver-for-crafting
-- Homepage: https://mods.factorio.com/mod/timesaver-for-crafting

local BUILD = 1000 -- Always to increment the number when change the code
local MAX_ACCUMULATED = 60 * 60
local SPEED_BONUS = 8
local config = require('timesaver_for_crafting/config')
local mod = {}

local function calc_new_crafting_speed(accumulated)
  return SPEED_BONUS * (accumulated / MAX_ACCUMULATED)
end

local function check_completed_craft(player)
  local player_data = global.timesaver_for_crafting.players[player.index]
  player.character_crafting_speed_modifier = calc_new_crafting_speed(player_data.accumulated)
  player_data.last_craft_tick = player.online_time

  -- player.print(player.character_crafting_speed_modifier)
end

local function on_player_crafted_item(event)
  -- Validation of data
  local player = game.players[event.player_index]
  if not (player and player.valid) then return end

  local player_data = global.timesaver_for_crafting.players[event.player_index]

  -- "on_player_cancelled_crafting" event does not have count of crafting items
  if #player.crafting_queue == 1 and player.crafting_queue[1].count == 1 then
    player_data.crafting_state = false
  end

  if player_data.accumulated > 0 then
    player_data.accumulated = player_data.accumulated - (event.recipe.energy * SPEED_BONUS)
  end

  -- another variant of work
  --[[
  if player_data.accumulated > 0 then
    player_data.accumulated = player_data.accumulated - (event.recipe.energy * (1 + calc_new_crafting_speed(player_data.accumulated)))
  else
    player_data.accumulated = player_data.accumulated - event.recipe.energy
  end
  ]]--

  check_completed_craft(player)
end

local function on_player_cancelled_crafting(event)
  -- Validation of data
  local player = game.players[event.player_index]
  if not (player and player.valid) then return end

  -- "on_player_cancelled_crafting" event does not have count of crafting items
  local player_data = global.timesaver_for_crafting.players[event.player_index]
  player_data.crafting_state = (player.crafting_queue_size ~= 0)

  check_completed_craft(player)
end

local function on_pre_player_crafted_item(event)
  -- Validation of data
  local player = game.players[event.player_index]
  if not (player and player.valid) then return end

  local player_data = global.timesaver_for_crafting.players[event.player_index]
  if not player_data.crafting_state then
    player_data.crafting_state = true
    player_data.accumulated = player_data.accumulated + (player.online_time - player_data.last_craft_tick)
    if player_data.accumulated > MAX_ACCUMULATED then
      player_data.accumulated = MAX_ACCUMULATED
    end
  end
  player.character_crafting_speed_modifier = calc_new_crafting_speed(player_data.accumulated)
end

local function on_player_removed(event)
  global.timesaver_for_crafting.players[event.player_index] = nil
end

local function on_player_joined_game(event)
  -- Validation of data
  local player = game.players[event.player_index]
  if not (player and player.valid) then return end

  if script.mod_name == 'level' and global.timesaver_for_crafting.build ~= BUILD then
    config.init()
    global.timesaver_for_crafting.build = BUILD
  end

  if not global.timesaver_for_crafting.players[event.player_index] then
    config.update_player(player)
  end
end

local function on_init(event)
  config.init()
  global.timesaver_for_crafting.build = BUILD
end

local function on_load()
  if not game then
    if global.timesaver_for_crafting == nil then
      config.init()
    end
  end
end

mod.events = {
  on_load = on_load,
  on_init = on_init,
  on_pre_player_crafted_item = on_pre_player_crafted_item,
  on_player_cancelled_crafting = on_player_cancelled_crafting,
  on_player_crafted_item = on_player_crafted_item,
  on_player_joined_game = on_player_joined_game,
  on_player_removed = on_player_removed
}

return mod
