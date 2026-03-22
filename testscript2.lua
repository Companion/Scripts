-- Test script 2 (no key - loaded after loader passes)
local plr = game:GetService("Players").LocalPlayer
local rexurl = "https://raw.githubusercontent.com/Companion/owenn/refs/heads/main/owennui.lua"
local Rex = loadstring(game:HttpGet(rexurl))()

local ui = Rex:window("Test Script 2", 360, 200, { notifyOnLoad = "Test 2 loaded" })
ui.watermark("game 2", { position = "bottomright" })
ui.tab("Main")
local main = ui.section(1, "Test 2", "PlaceId: " .. game.PlaceId, "main")
ui.button(main, "Test 2 Button", function() ui.toast("Test script 2 works!", 2, "bottom", "success") end)
ui.setToggleKey(Enum.KeyCode.RightShift)
