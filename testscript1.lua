-- Test script 1 (no key - loaded after loader passes)
local plr = game:GetService("Players").LocalPlayer
local rexurl = "https://raw.githubusercontent.com/Companion/owenn/refs/heads/main/owennui.lua"
local Rex = loadstring(game:HttpGet(rexurl))()

local ui = Rex:window("Test Script 1", 360, 200, { notifyOnLoad = "Test 1 loaded" })
ui.watermark("game 1", { position = "bottomright" })
ui.tab("Main")
local main = ui.section(1, "Test 1", "PlaceId: " .. game.PlaceId, "main")
ui.button(main, "Test 1 Button", function() ui.toast("Test script 1 works!", 2, "bottom", "success") end)
ui.setToggleKey(Enum.KeyCode.RightShift)
