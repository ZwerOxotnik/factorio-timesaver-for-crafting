local M = {}


--#region Global data
local mod_data
local players_data
--#endregion


--#region Constants
local MAX_ACCUMULATED = 60 * 60 * 2 -- TODO: create a setting for this
local SPEED_BONUS = 6 -- TODO: create a setting for this
--#endregion


--#region Utils

---@param player PlayerIdentification
---@param player_index number index of player
local function check_player_data(player, player_index)
	players_data[player_index] = players_data[player_index] or {}

	local player_data = players_data[player_index]
	player_data.accumulated = player_data.accumulated or 0
	player_data.last_craft_tick = player_data.last_craft_tick or player.online_time
	if player.character and not player.cheat_mode then
		player_data.crafting_state = player_data.crafting_state or (player.crafting_queue ~= nil)
	else
		player_data.crafting_state = false
	end
end

---@param accumulated number
---@return number >= 1
local function calc_new_crafting_speed(accumulated)
	local crafting_speed = SPEED_BONUS * (accumulated / MAX_ACCUMULATED)
	if crafting_speed < 0 then crafting_speed = 1 end
	return crafting_speed
end

local function check_completed_craft(player)
	local player_data = players_data[player.index]
	player.character_crafting_speed_modifier = calc_new_crafting_speed(player_data.accumulated)
	player_data.last_craft_tick = player.online_time
end

--#endregion


--#region Events

local function on_player_crafted_item(event)
	local player_index = event.player_index
	local player = game.get_player(player_index)
	if player.cheat_mode then return end

	local player_data = players_data[player_index]

	-- TODO: optimizate!
	-- "on_player_cancelled_crafting" event does not have count of crafting items
	local crafting_queue = player.crafting_queue
	if #crafting_queue == 1 and crafting_queue[1].count == 1 then
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
	local player_index = event.player_index
	local player = game.get_player(player_index)

	-- "on_player_cancelled_crafting" event does not have count of crafting items
	local player_data = players_data[player_index]
	player_data.crafting_state = (player.crafting_queue_size ~= 0)

	check_completed_craft(player)
end

local function on_pre_player_crafted_item(event)
	local player_index = event.player_index
	local player = game.get_player(player_index)

	local player_data = players_data[player_index]
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
	players_data[event.player_index] = nil
end

local function on_player_joined_game(event)
	-- Validation of data
	local player_index = event.player_index
	local player = game.get_player(player_index)

	if not players_data[player_index] then
		check_player_data(player, player_index)
	end
end

local function on_player_respawned(event)
	local player_index = event.player_index
	local player = game.get_player(player_index)

	local player_data = players_data[player_index]
	player_data.accumulated = 0
	player_data.crafting_state = false
	player_data.last_craft_tick = player.online_time
	player.character_crafting_speed_modifier = calc_new_crafting_speed(player_data.accumulated)
end

--#endregion

local function link_data()
	mod_data = global.timesaver_for_crafting
	players_data = mod_data.players
end

local function on_init()
	global.timesaver_for_crafting = global.timesaver_for_crafting or {}
	mod_data = global.timesaver_for_crafting
	mod_data.players = mod_data.players or {}

	link_data()

	for _, player in pairs(game.players) do
		check_player_data(player, player.index)
	end
end

M.on_init = on_init
M.on_load = link_data

M.on_mod_disabled = function()
	for _, player in pairs(game.players) do
		if player.valid then
			local player_data = players_data[player.index]
			player_data.accumulated = 0
			player_data.crafting_state = false
			player_data.last_craft_tick = player.online_time
			if player.character then
				player.character_crafting_speed_modifier = calc_new_crafting_speed(player_data.accumulated)
			end
		end
	end
end

M.events = {
	[defines.events.on_player_removed] = on_player_removed,
	[defines.events.on_player_joined_game] = function(event)
		pcall(on_player_joined_game, event)
	end,
	[defines.events.on_player_cancelled_crafting] = function(event)
		pcall(on_player_cancelled_crafting, event)
	end,
	[defines.events.on_pre_player_crafted_item] = function(event)
		pcall(on_pre_player_crafted_item, event)
	end,
	[defines.events.on_player_crafted_item] = function(event)
		pcall(on_player_crafted_item, event)
	end,
	[defines.events.on_player_respawned] = function(event)
		pcall(on_player_respawned, event)
	end
}

M.events_when_off = {
	[defines.events.on_player_removed] = on_player_removed,
	[defines.events.on_player_joined_game] = function(event)
		pcall(on_player_joined_game, event)
	end
}

return M
