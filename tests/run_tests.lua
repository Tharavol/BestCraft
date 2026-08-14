-- run_tests.lua
-- SPDX-License-Identifier: MIT
--
-- Loads the addon into a stubbed WoW API (stub_api.lua) and runs the regression suite in
-- the sibling *_spec.lua files. Catches runtime shape errors luacheck cannot -- a nil
-- where a value was expected, a renamed field, a typo'd table key.
--
-- Usage: lua tests/run_tests.lua   (run from the repository root)

local T = dofile("tests/test_helpers.lua")
local stub = dofile("tests/stub_api.lua")

dofile("tests/core_spec.lua")(stub, T)
dofile("tests/order_screen_spec.lua")(stub, T)
dofile("tests/order_reagents_spec.lua")(stub, T)
dofile("tests/order_recipe_data_spec.lua")(stub, T)
dofile("tests/recraft_shopping_list_spec.lua")(stub, T)
dofile("tests/order_queue_button_spec.lua")(stub, T)

os.exit(T.Summary() and 0 or 1)
