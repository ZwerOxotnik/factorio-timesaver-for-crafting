--[[
Copyright (c) 2019-2020 ZwerOxotnik <zweroxotnik@gmail.com>
Licensed under the MIT licence;

You can write and receive any information on the links below.
Source: https://gitlab.com/ZwerOxotnik/timesaver-for-crafting
Mod portal: https://mods.factorio.com/mod/timesaver-for-crafting
Homepage: https://forums.factorio.com/viewtopic.php?f=190&t=64620

]]--

local BUILD = 1900 -- Always to increment the number when change the code
local MAX_ACCUMULATED = 60 * 50 -- TODO: create settings for this
local SPEED_BONUS = 7 -- TODO: create settings for this
local config = require('timesaver_for_crafting/config')
local module = {}
module.events = {}
-- TODO: change checking and to add mod interface


local function get_event(event)
	if type(event) == "number" then
		return event
	else
		return defines.events[event] --or event
	end
end

-- This function for compatibility with "Event listener" module and into other modules
local function put_event(event, func)
	event = get_event(event)
	if event then
		module.events[event] = func
		if Event then
			Event.register(event, func)
		end
		return true
	else
		log("The event is nil")
		-- error("The event is nil")
	end
	return false
end


local function calc_new_crafting_speed(accumulated)
    local crafting_speed = SPEED_BONUS * (accumulated / MAX_ACCUMULATED)
    if crafting_speed < 0 then crafting_speed = 1 end
	return crafting_speed
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
	if not (player and player.valid) or player.cheat_mode then return end

	local player_data = global.timesaver_for_crafting.players[event.player_index]

	-- TODO: optimizate!
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

local function on_player_respawned(event)
	-- Validation of data
	local player = game.players[event.player_index]
	if not (player and player.valid) then return end

	local player_data = global.timesaver_for_crafting.players[player.index]
	player_data.accumulated = 0
	player_data.crafting_state = false
	player_data.last_craft_tick = player.online_time
	player.character_crafting_speed_modifier = calc_new_crafting_speed(player_data.accumulated)
end

module.on_init = function(event)
	config.init()
	global.timesaver_for_crafting.build = BUILD
end

module.on_load = function()
	if not game then
		if global.timesaver_for_crafting == nil then
			config.init()
		end
	end
end

local function on_runtime_mod_setting_changed(event)
	if event.setting ~= "tfc_state" then return end

	if settings.global[event.setting].value then
		put_event("on_player_cancelled_crafting", on_player_cancelled_crafting)
		event_listener.update_event("on_player_cancelled_crafting")
		put_event("on_pre_player_crafted_item", on_pre_player_crafted_item)
		event_listener.update_event("on_pre_player_crafted_item")
		put_event("on_player_crafted_item", on_player_crafted_item)
		event_listener.update_event("on_player_crafted_item")
		put_event("on_player_respawned", on_player_respawned)
		event_listener.update_event("on_player_respawned")

		game.print({"", {"loading-mods"}, " ", {"mod-name.timesaver-for-crafting"}, " - ✓"})
	else
		local events = {"on_player_cancelled_crafting", "on_pre_player_crafted_item", "on_player_crafted_item", "on_player_respawned"}
		for _, event_name in pairs( events ) do
			event_listener.update_event(event_name)
			put_event(event_name, function() end)
		end

		for _, player in pairs( game.players ) do
			local player_data = global.timesaver_for_crafting.players[player.index]
			player_data.accumulated = 0
			player_data.crafting_state = false
			player_data.last_craft_tick = player.online_time
			if player.character then
				player.character_crafting_speed_modifier = calc_new_crafting_speed(player_data.accumulated)
			end
		end
		game.print({"", {"gui-mod-load-error.to-be-disabled"}, " ", {"mod-name.timesaver-for-crafting"}})
	end
end

put_event("on_player_joined_game", on_player_joined_game)
put_event("on_player_removed", on_player_removed)
put_event("on_runtime_mod_setting_changed", on_runtime_mod_setting_changed)
if script.mod_name == 'level' or settings.global["tfc_state"].value then
	put_event("on_player_cancelled_crafting", on_player_cancelled_crafting)
	put_event("on_pre_player_crafted_item", on_pre_player_crafted_item)
	put_event("on_player_crafted_item", on_player_crafted_item)
	put_event("on_player_respawned", on_player_respawned)
else
	put_event("on_player_cancelled_crafting", function() end)
	put_event("on_pre_player_crafted_item", function() end)
	put_event("on_player_crafted_item", function() end)
	put_event("on_player_respawned", function() end)
end

return module
