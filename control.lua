event_listener = require("__zk-lib__/event-listener/branch-1/stable-version")
local modules = {}
modules.timesaver_for_crafting = require('timesaver_for_crafting/control')

event_listener.add_libraries(modules)
