local M = {}


--#region storage data
local mod_data
local players_data
--#endregion


--#region Settings
local max_compensated_ticks = settings.global["TfC_max_compensated_ticks"].value
local min_speed_bonus = settings.global["TfC_minimum_speed_bonus"].value
local speed_bonus = settings.global["TfC_max_speed_bonus"].value
--#endregion


--#region Utils

---@param player LuaPlayer
---@param player_index number index of the player
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
---@return number >= min_speed_bonus
local function calc_new_crafting_speed(accumulated)
	local crafting_speed = speed_bonus * (accumulated / max_compensated_ticks)
	if crafting_speed < min_speed_bonus then return min_speed_bonus end
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
		player_data.accumulated = player_data.accumulated - (event.recipe.energy * (60 * game.speed) * speed_bonus)
	end

	-- another variant of work
	--[[
	if player_data.accumulated > 0 then
		player_data.accumulated = player_data.accumulated - (event.recipe.energy * (60 * game.speed) * (1 + calc_new_crafting_speed(player_data.accumulated)))
	else
		player_data.accumulated = player_data.accumulated - event.recipe.energy * (60 * game.speed)
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
		if player_data.accumulated > max_compensated_ticks then
			player_data.accumulated = max_compensated_ticks
		end
	end
	player.character_crafting_speed_modifier = calc_new_crafting_speed(player_data.accumulated)
end

local function on_player_removed(event)
	players_data[event.player_index] = nil
end

local function on_player_joined_game(event)
	local player_index = event.player_index
	local player = game.get_player(player_index)
	if not players_data[player_index] then
		check_player_data(player, player_index)
	end
end

local function on_player_left_game(event)
	local player_index = event.player_index
	game.get_player(player_index).character_crafting_speed_modifier = 1
	players_data[player_index] = nil
end

local function on_player_respawned(event)
	local player_index = event.player_index
	local player_data = players_data[player_index]
	player_data.accumulated = 0
	player_data.crafting_state = false
	local player = game.get_player(player_index)
	player_data.last_craft_tick = player.online_time
	player.character_crafting_speed_modifier = calc_new_crafting_speed(player_data.accumulated)
end

local mod_settings = {
	TfC_minimum_speed_bonus = function(value)
		min_speed_bonus = value
	end,
	TfC_max_speed_bonus = function(value)
		speed_bonus = value
	end,
	TfC_max_compensated_ticks = function(value)
		max_compensated_ticks = value
	end
}
local function on_runtime_mod_setting_changed(event)
	local f = mod_settings[event.setting]
	if f then f(settings.global[event.setting].value) end
end

--#endregion

local function link_data()
	mod_data = storage.timesaver_for_crafting
	players_data = mod_data.players
end

local function on_init()
	storage.timesaver_for_crafting = storage.timesaver_for_crafting or {}
	mod_data = storage.timesaver_for_crafting
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
	[defines.events.on_runtime_mod_setting_changed] = on_runtime_mod_setting_changed,
	[defines.events.on_player_removed] = on_player_removed,
	[defines.events.on_player_joined_game] = function(event)
		pcall(on_player_joined_game, event)
	end,
	[defines.events.on_player_left_game] = function(event)
		pcall(on_player_left_game, event)
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
	[defines.events.on_runtime_mod_setting_changed] = on_runtime_mod_setting_changed,
	[defines.events.on_player_left_game] = on_player_removed,
	[defines.events.on_player_removed] = on_player_removed,
	[defines.events.on_player_joined_game] = function(event)
		pcall(on_player_joined_game, event)
	end
}

return M
