-- monkey tag
local Players = game:GetService("Players")
local RS = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local hs = game:GetService("HttpService")
local plr = Players.LocalPlayer
local cam = workspace.CurrentCamera

local Rex = loadstring(game:HttpGet("https://raw.githubusercontent.com/Companion/owenn/refs/heads/main/owennui.lua"))()

plr.Idled:Connect(function()
	local vu = game:GetService("VirtualUser")
	vu:Button2Down(Vector2.zero, cam.CFrame)
	task.wait(0.5)
	vu:Button2Up(Vector2.zero, cam.CFrame)
end)

local cfgdir = "owenn/monkeytag"
local function cfgpath(n) return cfgdir .. "/" .. n .. ".json" end
local cfgstore = {
	list = function()
		if not makefolder or not listfiles then return {} end
		pcall(makefolder, cfgdir)
		local out, seen = {}, {}
		for k, v in pairs(listfiles(cfgdir) or {}) do
			local f = type(v) == "string" and v or tostring(k)
			if f:find("%.json$") then local n = f:match("([^/\\]+)%.json$") or f:gsub("%.json$", "") if n and not seen[n] then seen[n] = true table.insert(out, n) end end
		end
		table.sort(out)
		return out
	end,
	get = function(n) if not readfile then return nil end local ok, raw = pcall(readfile, cfgpath(n)) return ok and type(raw) == "string" and raw or nil end,
	set = function(n, d) if not makefolder or not writefile then return end pcall(makefolder, cfgdir) writefile(cfgpath(n), hs:JSONEncode(d)) end,
}

local getdataFn
local ui = Rex:window("Monkey Tag", 380, 460, {
	skipLoader = true,
	notifyOnLoad = "Loaded",
	listConfigs = cfgstore.list,
	getConfig = cfgstore.get,
	saveConfigAs = cfgstore.set,
	saveConfig = function()
		if getdataFn then
			local ok, d = pcall(getdataFn)
			if ok and d then cfgstore.set("last", d) end
		end
		ui.toast("Saved", 1.5, "bottom", "success")
	end,
})
ui.watermark("owenn.wtf", { position = "bottomright" })

ui.tab("Combat")
ui.tab("Auto")
ui.tab("Player")
ui.tab("Visuals")
ui.tab("Config")

----------------------------------------------------------------
-- shared helpers
----------------------------------------------------------------
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local function getRemote(name)
	local ok, r = pcall(function()
		return ReplicatedStorage:WaitForChild("ClientSource", 5)
			:WaitForChild("Shared", 5)
			:WaitForChild("Net", 5)
			:WaitForChild("RE/" .. name, 5)
	end)
	return ok and r or nil
end

local R = {
	Movement   = getRemote("Movement"),
	Vine       = getRemote("Vine"),
	WallJump   = getRemote("WallJump"),
	Trampoline = getRemote("Trampoline"),
	Zipline    = getRemote("Zipline"),
	BombTag    = getRemote("BombTag"),
	Codes      = getRemote("Codes"),
	DailyReward= getRemote("DailyReward"),
	GroupReward= getRemote("GroupReward"),
	MapVote    = getRemote("MapVote"),
	Quest      = getRemote("Quest"),
	Respawn    = getRemote("Respawn"),
	Cases      = getRemote("Cases"),
	LobbyCases = getRemote("LobbyCases"),
	Inventory  = getRemote("Inventory"),
	Emotes     = getRemote("Emotes"),
}

local function getChar() return plr.Character end
local function getHRP()
	local c = getChar()
	return c and c:FindFirstChild("HumanoidRootPart")
end
local function getHum()
	local c = getChar()
	return c and c:FindFirstChildOfClass("Humanoid")
end

local function isAlive(p)
	local c = p.Character
	local h = c and c:FindFirstChildOfClass("Humanoid")
	return h and h.Health > 0
end

----------------------------------------------------------------
-- Player tab
----------------------------------------------------------------
local pl = ui.section(3, "Movement")
local speedOn, speed = false, 50
local jumpOn, jumpV = false, 60
local infJump, noclip, flyOn = false, false, false
local flySpd = 60
ui.toggle(pl, "Walkspeed", false, function(v) speedOn = v end)
local speedSl = ui.sliderInput(pl, "Walkspeed value", 16, 200, 50, function(v) speed = v end)
ui.toggle(pl, "Jump power", false, function(v) jumpOn = v end)
local jumpSl = ui.sliderInput(pl, "Jump power value", 50, 500, 60, function(v) jumpV = v end)
ui.toggle(pl, "Infinite jump", false, function(v) infJump = v end)
ui.toggle(pl, "Noclip", false, function(v) noclip = v end)
ui.toggle(pl, "Fly", false, function(v) flyOn = v end)
local flySl = ui.sliderInput(pl, "Fly speed", 10, 300, 60, function(v) flySpd = v end)

-- Movement.lua re-sets WalkSpeed every RenderStepped, so overriding on Heartbeat is too late.
-- Hook each new humanoid's WalkSpeed change and snap it back instantly, AND bind a render-step
-- callback at Last priority so we win after Movement.lua's Sprint update each frame.
local function attachSpeedHook(h)
	if not h then return end
	h:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
		if speedOn and h.WalkSpeed ~= speed then h.WalkSpeed = speed end
	end)
	h:GetPropertyChangedSignal("JumpPower"):Connect(function()
		if jumpOn and h.JumpPower ~= jumpV then h.JumpPower = jumpV end
	end)
end
local function onChar(c)
	local h = c:WaitForChild("Humanoid", 5)
	attachSpeedHook(h)
end
if plr.Character then onChar(plr.Character) end
plr.CharacterAdded:Connect(onChar)

RS:BindToRenderStep("OwennSpeedOverride", Enum.RenderPriority.Last.Value, function()
	local h = getHum()
	if not h then return end
	if speedOn then h.WalkSpeed = speed end
	if jumpOn then
		h.UseJumpPower = true
		h.JumpPower = jumpV
	end
end)

UIS.JumpRequest:Connect(function()
	if infJump then
		local h = getHum()
		if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
	end
end)

RS.Stepped:Connect(function()
	if noclip then
		local c = getChar()
		if c then
			for _, p in pairs(c:GetDescendants()) do
				if p:IsA("BasePart") then p.CanCollide = false end
			end
		end
	end
end)

local flyBV, flyBG
local function killFly()
	if flyBV then flyBV:Destroy() flyBV = nil end
	if flyBG then flyBG:Destroy() flyBG = nil end
end
task.spawn(function()
	while true do
		task.wait()
		local hrp = getHRP()
		local h = getHum()
		if flyOn and hrp and h then
			if not flyBV then
				flyBV = Instance.new("BodyVelocity")
				flyBV.MaxForce = Vector3.new(1e9,1e9,1e9)
				flyBV.Velocity = Vector3.zero
				flyBV.Parent = hrp
				flyBG = Instance.new("BodyGyro")
				flyBG.MaxTorque = Vector3.new(1e9,1e9,1e9)
				flyBG.P = 1e4
				flyBG.Parent = hrp
			end
			flyBG.CFrame = cam.CFrame
			local dir = Vector3.zero
			if UIS:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
			if UIS:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
			if UIS:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
			if UIS:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
			if UIS:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0,1,0) end
			if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.new(0,1,0) end
			flyBV.Velocity = dir * flySpd
		else
			killFly()
		end
	end
end)

----------------------------------------------------------------
-- Combat tab
----------------------------------------------------------------
local cb = ui.section(1, "Tag")
local autoTag, antiTag = false, false
local tagDist = 30
local antiDist = 35
local antiTagDistSl
ui.toggle(cb, "Auto tag", false, function(v) autoTag = v end)
ui.toggle(cb, "Anti tag", false, function(v) antiTag = v end)
local tagDistSl = ui.sliderInput(cb, "Auto tag max distance", 5, 200, 100, function(v) tagDist = v end)
local tagLead = 0.07
local tagLeadSl = ui.sliderInput(cb, "Auto tag prediction", 0, 0.5, 0.07, function(v) tagLead = v end)
antiTagDistSl = ui.sliderInput(cb, "Anti tag range", 10, 100, 50, function(v) antiDist = v end)

local hitboxOn, hitboxSize = false, 12
local hitboxOnlyBomb = false
ui.toggle(cb, "Enemy hitbox extender", false, function(v) hitboxOn = v end)
ui.toggle(cb, "Hitbox only when bomb", false, function(v) hitboxOnlyBomb = v end)
local hitboxSl = ui.sliderInput(cb, "Hitbox size", 4, 100, 12, function(v) hitboxSize = v end)

local origHitbox = {}
RS.Heartbeat:Connect(function()
	local active = hitboxOn and (not hitboxOnlyBomb or (plr.Team and plr.Team.Name == "Bomb") or (plr.Character and plr.Character.Parent and plr.Character.Parent.Name == "Bomb"))
	for _, p in pairs(Players:GetPlayers()) do
		if p == plr then continue end
		local c = p.Character
		local hrp = c and c:FindFirstChild("HumanoidRootPart")
		if not hrp then continue end
		if active then
			if not origHitbox[hrp] then
				origHitbox[hrp] = { size = hrp.Size, trans = hrp.Transparency }
			end
			hrp.Size = Vector3.new(hitboxSize, hitboxSize, hitboxSize)
			hrp.Transparency = 0.7
		else
			if origHitbox[hrp] then
				pcall(function()
					hrp.Size = origHitbox[hrp].size
					hrp.Transparency = origHitbox[hrp].trans
				end)
				origHitbox[hrp] = nil
			end
		end
	end
end)

local function isBombHolder(p)
	-- check team first, then fall back to workspace parenting
	if p.Team and p.Team.Name == "Bomb" then return true end
	local c = p.Character
	return c and c.Parent and c.Parent.Name == "Bomb"
end

local function isRunner(p)
	if p.Team and p.Team.Name == "Runners" then return true end
	local c = p.Character
	if not (c and c.Parent) then return false end
	return c.Parent.Name == "Runners"
end

local function nearestEnemy(wantBomb)
	local hrp = getHRP()
	if not hrp then return nil end
	local best, bd = nil, math.huge
	for _, p in pairs(Players:GetPlayers()) do
		if p == plr then continue end
		if not isAlive(p) then continue end
		local match = wantBomb and isBombHolder(p) or (not wantBomb and isRunner(p))
		if not match then continue end
		local php = p.Character.HumanoidRootPart
		local d = (php.Position - hrp.Position).Magnitude
		if d < bd then bd = d best = p end
	end
	return best, bd
end

task.spawn(function()
	while true do
		RS.Heartbeat:Wait()
		if autoTag and isBombHolder(plr) then
			pcall(function()
				local hrp = getHRP()
				if not hrp then return end
				local target, d = nearestEnemy(false)
				if target and d <= tagDist then
					local thrp = target.Character.HumanoidRootPart
					local vel = thrp.AssemblyLinearVelocity
					local lead = Vector3.new(vel.X, 0, vel.Z) * tagLead
					local fwd = thrp.CFrame.LookVector
					fwd = Vector3.new(fwd.X, 0, fwd.Z)
					if fwd.Magnitude > 0.1 then fwd = fwd.Unit else fwd = Vector3.zero end
					local landing = thrp.Position + lead + fwd * 2.5
					hrp.CFrame = CFrame.new(landing, landing + fwd) + Vector3.new(0, 0.5, 0)
				end
			end)
		end
	end
end)

task.spawn(function()
	while true do
		RS.Heartbeat:Wait()
		if antiTag and not isBombHolder(plr) then
			pcall(function()
				local hrp = getHRP()
				local hum = getHum()
				if not (hrp and hum) then return end
				local bomb, bd = nearestEnemy(true)
				if not (bomb and bd < antiDist) then return end
				local bhrp = bomb.Character.HumanoidRootPart
				-- predict where the bomb-holder will be shortly
				local bvel = bhrp.AssemblyLinearVelocity
				local bfuture = bhrp.Position + Vector3.new(bvel.X, 0, bvel.Z) * 0.3
				-- flee from the predicted position, not current
				local diff = hrp.Position - bfuture
				local flat = Vector3.new(diff.X, 0, diff.Z)
				if flat.Magnitude < 0.1 then flat = Vector3.new(1,0,0) end
				local away = flat.Unit
				-- scale push by closeness — closer = harder shove
				local urgency = math.clamp((antiDist - bd) / antiDist, 0.2, 1)
				local push = 8 + urgency * 14
				-- find a safe landing: try flee dir, then perpendicular sidesteps; if blocked, climb on top of obstacle
				local params = RaycastParams.new()
				params.FilterDescendantsInstances = { getChar() }
				params.FilterType = Enum.RaycastFilterType.Exclude

				-- collect map barriers to keep landings inside the play area
				local barriers = {}
				local mapFolder = workspace:FindFirstChild("Map")
				if mapFolder then
					for _, child in pairs(mapFolder:GetChildren()) do
						local bf = child:FindFirstChild("Barriers")
						if bf then
							for _, b in pairs(bf:GetDescendants()) do
								if b:IsA("BasePart") then table.insert(barriers, b) end
							end
						end
					end
				end
				local barrierParams = RaycastParams.new()
				barrierParams.FilterDescendantsInstances = barriers
				barrierParams.FilterType = Enum.RaycastFilterType.Include
				local function crossesBarrier(fromPos, toPos)
					if #barriers == 0 then return false end
					local dir = toPos - fromPos
					if dir.Magnitude < 0.01 then return false end
					return workspace:Raycast(fromPos, dir, barrierParams) ~= nil
				end

				local function hasGround(pos)
					-- there must be solid ground within 30 studs below candidate
					local downRc = workspace:Raycast(pos + Vector3.new(0, 2, 0), Vector3.new(0, -30, 0), params)
					return downRc and downRc.Normal.Y > 0.4, downRc
				end

				local function findLanding(dir)
					-- horizontal cast at hip height
					local origin = hrp.Position
					local rc = workspace:Raycast(origin, dir * push, params)
					local candidate
					if not rc then
						candidate = origin + dir * push
					else
						-- blocked: try to mount the top of the obstacle
						local hitInst = rc.Instance
						local mounted = nil
						if hitInst then
							local sz = hitInst.Size
							local topY = hitInst.Position.Y + sz.Y * 0.5 + 3
							local castStart = rc.Position + dir * 1.5 + Vector3.new(0, math.max(topY - rc.Position.Y, 4) + 6, 0)
							local downRc = workspace:Raycast(castStart, Vector3.new(0, -50, 0), params)
							if downRc and downRc.Normal.Y > 0.5 then
								mounted = downRc.Position + Vector3.new(0, 3, 0)
							end
						end
						candidate = mounted or (rc.Position - dir * 1.5)
					end
					-- snap candidate to the ground if there is any, reject otherwise
					local ok, downRc = hasGround(candidate)
					if not ok then return nil end
					local landing = Vector3.new(candidate.X, downRc.Position.Y + 3, candidate.Z)
					-- reject if going there crosses a map barrier (out of bounds)
					if crossesBarrier(hrp.Position, landing) then return nil end
					return landing
				end

				-- try primary, then 45deg either side, then perpendiculars
				local function rotY(v, deg)
					local r = math.rad(deg)
					local cos, sin = math.cos(r), math.sin(r)
					return Vector3.new(v.X * cos - v.Z * sin, 0, v.X * sin + v.Z * cos)
				end
				local options = { away, rotY(away, 45), rotY(away, -45), rotY(away, 90), rotY(away, -90), rotY(away, 135), rotY(away, -135) }
				local target, bestScore = nil, -math.huge
				for _, dir in ipairs(options) do
					local land = findLanding(dir.Unit)
					if land then
						local score = (land - bfuture).Magnitude - (hrp.Position - bfuture).Magnitude
						if score > bestScore then
							bestScore = score
							target = land
						end
					end
				end
				-- if every direction is over a void, don't teleport at all (better to risk tag than fall out)
				if not target then return end
				hrp.CFrame = CFrame.new(target, target + away)
				-- nudge upward + jump if very close to bait whiffs
				if bd < 12 then
					hrp.AssemblyLinearVelocity = away * 80 + Vector3.new(0, 50, 0)
					hum.Jump = true
				end
			end)
		end
	end
end)

----------------------------------------------------------------
-- Visuals tab
----------------------------------------------------------------
local vs = ui.section(4, "ESP")
local bombEsp, playerEsp, specEsp = false, false, false
local bombColor   = Color3.fromRGB(255, 80, 80)
local playerColor = Color3.fromRGB(80, 200, 255)
local specColor   = Color3.fromRGB(180, 180, 180)
ui.toggle(vs, "Bomb ESP", false, function(v) bombEsp = v end)
ui.colorPicker(vs, "Bomb color", bombColor, function(c) bombColor = c end)
ui.toggle(vs, "Player ESP", false, function(v) playerEsp = v end)
ui.colorPicker(vs, "Player color", playerColor, function(c) playerColor = c end)
ui.toggle(vs, "Spectator ESP", false, function(v) specEsp = v end)
ui.colorPicker(vs, "Spectator color", specColor, function(c) specColor = c end)

local function classify(p)
	if isBombHolder(p) then return "bomb" end
	if p.Team and p.Team.Name == "Spectating" then return "spec" end
	if isRunner(p) then return "player" end
	return nil
end

local espTags = {}
local function clearESP(p)
	if espTags[p] then
		for _, x in pairs(espTags[p]) do pcall(function() x:Destroy() end) end
		espTags[p] = nil
	end
end
local function makeESP(p)
	if espTags[p] or p == plr then return end
	local c = p.Character
	if not c then return end
	local hl = Instance.new("Highlight")
	hl.Adornee = c
	hl.FillTransparency = 0.7
	hl.OutlineTransparency = 0
	hl.Parent = c
	local bb = Instance.new("BillboardGui")
	bb.Adornee = c:FindFirstChild("Head") or c:FindFirstChild("HumanoidRootPart")
	bb.Size = UDim2.new(0, 120, 0, 24)
	bb.StudsOffset = Vector3.new(0, 3, 0)
	bb.AlwaysOnTop = true
	bb.Parent = c
	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.fromScale(1,1)
	lbl.TextStrokeTransparency = 0
	lbl.TextScaled = true
	lbl.Font = Enum.Font.GothamBold
	lbl.Parent = bb
	espTags[p] = { hl = hl, bb = bb, lbl = lbl }
end

RS.Heartbeat:Connect(function()
	local hrp = getHRP()
	for _, p in pairs(Players:GetPlayers()) do
		if p == plr then continue end
		if not isAlive(p) then clearESP(p) continue end
		local kind = classify(p)
		local enabled = (kind == "bomb" and bombEsp) or (kind == "player" and playerEsp) or (kind == "spec" and specEsp)
		if not enabled then clearESP(p) continue end
		makeESP(p)
		local t = espTags[p]
		if t and t.hl.Parent then
			local color = (kind == "bomb" and bombColor) or (kind == "spec" and specColor) or playerColor
			t.hl.FillColor = color
			t.hl.OutlineColor = color
			t.lbl.TextColor3 = color
			if hrp and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
				local d = math.floor((p.Character.HumanoidRootPart.Position - hrp.Position).Magnitude)
				t.lbl.Text = p.Name .. " [" .. d .. "m]"
			else
				t.lbl.Text = p.Name
			end
		else
			clearESP(p)
		end
	end
end)
Players.PlayerRemoving:Connect(clearESP)

----------------------------------------------------------------
-- Auto tab
----------------------------------------------------------------
local au = ui.section(2, "Bananas")
local bananaVacuum = false
local vacuumDist = 200
ui.toggle(au, "Auto collect bananas", false, function(v) bananaVacuum = v end)
ui.sliderInput(au, "Range", 20, 1000, 200, function(v) vacuumDist = v end)

task.spawn(function()
	while true do
		task.wait(0.1)
		if bananaVacuum then
			pcall(function()
				local hrp = getHRP()
				local folder = workspace:FindFirstChild("Bananas")
				if not (hrp and folder) then return end
				local fti = (typeof(firetouchinterest) == "function") and firetouchinterest or nil
				for _, b in pairs(folder:GetChildren()) do
					if b:IsA("BasePart") and (b.Position - hrp.Position).Magnitude <= vacuumDist then
						if fti then
							fti(hrp, b, 0)
							fti(hrp, b, 1)
						else
							-- fallback: brief teleport
							local saved = hrp.CFrame
							hrp.CFrame = CFrame.new(b.Position)
							task.wait(0.05)
							hrp.CFrame = saved
						end
					end
				end
			end)
		end
	end
end)

local au2 = ui.section(2, "Economy")
local autoCodes, autoDaily, autoQuest, autoVote = false, false, false, false
local voteFor = "1"
ui.toggle(au2, "Auto redeem known codes", false, function(v) autoCodes = v end)
ui.toggle(au2, "Auto daily reward", false, function(v) autoDaily = v end)
ui.toggle(au2, "Auto claim quests", false, function(v) autoQuest = v end)
ui.toggle(au2, "Auto map vote", false, function(v) autoVote = v end)
local voteDD = ui.dropdown(au2, "Vote slot", {"1","2","3","4"}, "1", function(o) voteFor = o end)

local KNOWN_CODES = { "M0NKE", "tripletmadness", "sixseven" }
-- pull current code list dynamically too
pcall(function()
	local mod = ReplicatedStorage:WaitForChild("ClientSource",5):WaitForChild("Shared",5):WaitForChild("Codes",5)
	local data = require(mod).Data
	for code, _ in pairs(data) do
		local found = false
		for _, c in ipairs(KNOWN_CODES) do if c == code then found = true break end end
		if not found then table.insert(KNOWN_CODES, code) end
	end
end)

task.spawn(function()
	if not R.Codes then return end
	task.wait(5)
	if autoCodes then
		for _, code in ipairs(KNOWN_CODES) do
			pcall(function() R.Codes:FireServer("Submit", { Code = code }) end)
			task.wait(1)
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(30)
		if autoDaily and R.DailyReward then
			pcall(function() R.DailyReward:FireServer("Claim") end)
		end
		if autoQuest and R.Quest then
			pcall(function() R.Quest:FireServer("Claim") end)
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(5)
		if autoVote then
			pcall(function()
				local remote = ReplicatedStorage:WaitForChild("ClientSource")
					:WaitForChild("Shared")
					:WaitForChild("Net")
					:WaitForChild("RE/MapVote")
				remote:FireServer("Vote", { Number = tonumber(voteFor) or 1 })
			end)
		end
	end
end)

local au4 = ui.section(2, "Cases")
local autoBuyCase = false
local buyQty = "Buy1"
local buyInterval = 5
local crateChoice = ""

-- Build crate list dynamically from the case modules: "Type / CaseName"
local crateList = {}
local crateMap = {} -- "Type / Name" -> { type = ..., case = ... }
do
	local typeMods = {
		Tail      = "TailCases",
		Bomb      = "BombCases",
		Emote     = "EmoteCases",
		TagEffect = "TagEffectsCases",
	}
	for tname, modname in pairs(typeMods) do
		pcall(function()
			local mod = ReplicatedStorage:WaitForChild("ClientSource",5):WaitForChild("Shared",5):WaitForChild(modname,5)
			local data = require(mod).Data or {}
			for caseName, _ in pairs(data) do
				local label = tname .. " / " .. caseName
				table.insert(crateList, label)
				crateMap[label] = { type = tname, case = caseName }
			end
		end)
	end
	table.sort(crateList)
	if #crateList == 0 then table.insert(crateList, "(none)") end
	crateChoice = crateList[1]
end

ui.toggle(au4, "Auto buy cases", false, function(v) autoBuyCase = v end)
local crateDD = ui.searchableDropdown(au4, "Crate", crateList, crateChoice, function(o) crateChoice = o end)
local buyQtyDD = ui.dropdown(au4, "Amount", {"Buy1","Buy3","Buy5"}, "Buy1", function(o) buyQty = o end)
local buyIntervalSl = ui.sliderInput(au4, "Buy interval (s)", 1, 60, 5, function(v) buyInterval = v end)
task.spawn(function()
	while true do
		task.wait(buyInterval)
		local pick = crateMap[crateChoice]
		if autoBuyCase and pick then
			pcall(function()
				local remote = ReplicatedStorage:WaitForChild("ClientSource")
					:WaitForChild("Shared")
					:WaitForChild("Net")
					:WaitForChild("RE/Cases")
				remote:FireServer(buyQty, { Type = pick.type, Case = pick.case })
			end)
		end
	end
end)

----------------------------------------------------------------
-- Config tab
----------------------------------------------------------------
local cfg = ui.section(5, "Config", nil, "config")
getdataFn = function()
	return {
		theme = ui.getTheme(),
		speedOn = speedOn, speed = speed, jumpOn = jumpOn, jumpV = jumpV,
		infJump = infJump, noclip = noclip, flyOn = flyOn, flySpd = flySpd,
		autoTag = autoTag, antiTag = antiTag, tagDist = tagDist, tagLead = tagLead, antiDist = antiDist,
		hitboxOn = hitboxOn, hitboxSize = hitboxSize, hitboxOnlyBomb = hitboxOnlyBomb,
		autoBuyCase = autoBuyCase, crateChoice = crateChoice, buyQty = buyQty, buyInterval = buyInterval,
		bombEsp = bombEsp, playerEsp = playerEsp, specEsp = specEsp,
		bombColor = {bombColor.R, bombColor.G, bombColor.B},
		playerColor = {playerColor.R, playerColor.G, playerColor.B},
		specColor = {specColor.R, specColor.G, specColor.B},
		bananaVacuum = bananaVacuum, vacuumDist = vacuumDist,
		autoCodes = autoCodes, autoDaily = autoDaily, autoQuest = autoQuest,
		autoVote = autoVote, voteFor = voteFor,
	}
end
local function applydata(data, silent)
	if type(data) ~= "table" then return end
	if data.theme then ui.setTheme(data.theme) end
	if data.speed and speedSl then speedSl.set(data.speed) end
	if data.jumpV and jumpSl then jumpSl.set(data.jumpV) end
	if data.flySpd and flySl then flySl.set(data.flySpd) end
	speedOn = data.speedOn or false
	jumpOn = data.jumpOn or false
	infJump = data.infJump or false
	noclip = data.noclip or false
	flyOn = data.flyOn or false
	if data.tagDist and tagDistSl then tagDistSl.set(data.tagDist) end
	if data.tagLead and tagLeadSl then tagLeadSl.set(data.tagLead) end
	if data.antiDist and antiTagDistSl then antiTagDistSl.set(data.antiDist) end
	if data.hitboxSize and hitboxSl then hitboxSl.set(data.hitboxSize) end
	hitboxOn = data.hitboxOn or false
	hitboxOnlyBomb = data.hitboxOnlyBomb or false
	if data.crateChoice and crateDD then crateDD.set(data.crateChoice) end
	if data.buyQty and buyQtyDD then buyQtyDD.set(data.buyQty) end
	if data.buyInterval and buyIntervalSl then buyIntervalSl.set(data.buyInterval) end
	autoBuyCase = data.autoBuyCase or false
	if data.voteFor and voteDD then voteDD.set(data.voteFor) end
	autoTag = data.autoTag or false
	antiTag = data.antiTag or false
	bombEsp = data.bombEsp or false
	playerEsp = data.playerEsp or false
	specEsp = data.specEsp or false
	if type(data.bombColor) == "table" then bombColor = Color3.new(data.bombColor[1], data.bombColor[2], data.bombColor[3]) end
	if type(data.playerColor) == "table" then playerColor = Color3.new(data.playerColor[1], data.playerColor[2], data.playerColor[3]) end
	if type(data.specColor) == "table" then specColor = Color3.new(data.specColor[1], data.specColor[2], data.specColor[3]) end
	bananaVacuum = data.bananaVacuum or false
	if data.vacuumDist then vacuumDist = data.vacuumDist end
	autoCodes = data.autoCodes or false
	autoDaily = data.autoDaily or false
	autoQuest = data.autoQuest or false
	autoVote = data.autoVote or false
	if not silent then ui.toast("Config loaded", 1.5, "bottom", "success") end
end
ui.button(cfg, "Export", function() ui.exportConfig(getdataFn) end)
ui.button(cfg, "Import", function() ui.importConfig(applydata) end)

task.defer(function()
	local raw = cfgstore.get("last")
	if raw and #raw > 0 then
		local ok, d = pcall(function() return hs:JSONDecode(raw) end)
		if ok and type(d) == "table" then applydata(d, true) end
	end
end)

ui.setToggleKey(Enum.KeyCode.RightShift)
