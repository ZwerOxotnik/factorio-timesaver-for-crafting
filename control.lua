event_listener = require("__event-listener__/branch-2/stable-version")
local modules = {}
modules.timesaver_for_crafting = require('timesaver_for_crafting/control')

event_listener.add_events(modules)
