if script.active_mods["switchable_mods"] then
	require("__switchable_mods__/event_handler_vSM").add_lib(require("models/timesaver_for_crafting"))
else
	require("event_handler").add_lib(require("models/timesaver_for_crafting"))
end
