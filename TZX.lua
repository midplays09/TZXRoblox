-- TZX.lua · v1
-- LocalScript → StarterPlayerScripts

local Players              = game:GetService("Players")
local TweenService         = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService     = game:GetService("UserInputService")
local RunService           = game:GetService("RunService")
local HttpService          = game:GetService("HttpService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ════════════════════════════════════════════
--  PALETTE
-- ════════════════════════════════════════════
local C = {
	bg         = Color3.fromRGB(20,  20,  20),
	panel      = Color3.fromRGB(14,  14,  14),
	section    = Color3.fromRGB(14,  14,  14),
	rowHover   = Color3.fromRGB(36,  36,  46),
	divider    = Color3.fromRGB(40,  40,  52),
	topBar     = Color3.fromRGB(14,  14,  14),
	accent     = Color3.fromRGB(120, 80,  255),
	accentDim  = Color3.fromRGB(50,  35,  110),
	accentPill = Color3.fromRGB(32,  32,  32),
	textBright = Color3.fromRGB(225, 225, 235),
	textMid    = Color3.fromRGB(150, 150, 165),
	textDim    = Color3.fromRGB(75,  75,  95),
	toggleOn   = Color3.fromRGB(100, 60,  220),
	toggleOff  = Color3.fromRGB(45,  45,  60),
	toggleKnob = Color3.fromRGB(220, 220, 235),
	sliderFill = Color3.fromRGB(100, 60,  220),
	sliderBg   = Color3.fromRGB(45,  45,  60),
	scriptBtn  = Color3.fromRGB(32,  28,  50),
}

local ACCENT_PRESETS = {
	Color3.fromRGB(120, 80,  255),
	Color3.fromRGB(255, 80,  120),
	Color3.fromRGB(80,  180, 255),
	Color3.fromRGB(80,  255, 160),
	Color3.fromRGB(255, 160, 40),
	Color3.fromRGB(255, 60,  60),
}

local function applyAccent(col)
	C.accent     = col
	C.accentDim  = col:Lerp(Color3.new(0,0,0), 0.6)
	C.toggleOn   = col:Lerp(Color3.new(0,0,0), 0.1)
	C.sliderFill = col
end

local NAVBAR_W = 620
local NAVBAR_H = 56
local WIN_W    = 620
local WIN_H    = 390
local CELL_W   = 298

-- ════════════════════════════════════════════
--  HELPERS
-- ════════════════════════════════════════════
local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	if parent then o.Parent = parent end
	return o
end
local function corner(p, r) new("UICorner", {CornerRadius = UDim.new(0, r or 6)}, p) end
local function tw(o, props, t)
	pcall(function()
		TweenService:Create(o,
			TweenInfo.new(t or .18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
			props):Play()
	end)
end

-- ════════════════════════════════════════════
--  FOLDERS + KEYBIND + CONFIG
-- ════════════════════════════════════════════
local KEYBIND_FILE = "TZX/keybind.txt"
local CONFIG_DIR   = "TZX/configs"

local currentKeybind = Enum.KeyCode.RightShift
local panicKey       = Enum.KeyCode.End
local espKey         = Enum.KeyCode.F1
local invisKey       = Enum.KeyCode.F2
local healKey        = Enum.KeyCode.F3

pcall(function() if not isfolder("TZX")              then makefolder("TZX")              end end)
pcall(function() if not isfolder("TZX/assets")       then makefolder("TZX/assets")       end end)
pcall(function() if not isfolder("TZX/assets/icons") then makefolder("TZX/assets/icons") end end)
pcall(function() if not isfolder("TZX/scripts")      then makefolder("TZX/scripts")      end end)
pcall(function() if not isfolder(CONFIG_DIR)         then makefolder(CONFIG_DIR)         end end)

pcall(function()
	if isfile(KEYBIND_FILE) then
		local kc = Enum.KeyCode[readfile(KEYBIND_FILE)]
		if kc then currentKeybind = kc end
	end
end)
local function saveKeybind(keyCode)
	pcall(function() writefile(KEYBIND_FILE, keyCode.Name) end)
end

-- ════════════════════════════════════════════
--  FRIENDS LIST
-- ════════════════════════════════════════════
_G.friendsList = {}
local function isFriend(target)
	return _G.friendsList[target.Name] == true
end

-- ════════════════════════════════════════════
--  TEAM CHECK HELPER
-- ════════════════════════════════════════════
local function isSameTeam(target)
	if not _G.ESP.teamCheck then return false end
	local myTeam = player.Team
	if myTeam == nil then return false end
	return target.Team == myTeam
end

-- ════════════════════════════════════════════
--  EXPLOIT STATE
-- ════════════════════════════════════════════
_G.flySpeed      = 50
_G.hitboxSize    = 8
_G.hitboxEnabled = false

local exploitConns   = {}
local noclipDefaults = {}
local hitboxData     = {}
local frozenAmmoVals = {}
local healthConn     = nil
local idledConn      = nil
local flyBV, flyBG

local function clearConn(name)
	if exploitConns[name] then exploitConns[name]:Disconnect(); exploitConns[name] = nil end
end

-- ── FLIGHT ──────────────────────────────────
local function enableFly()
	local char = player.Character
	local hum  = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not hum or not root then return end
	hum.PlatformStand = true
	flyBV = Instance.new("BodyVelocity")
	flyBV.Velocity = Vector3.zero; flyBV.MaxForce = Vector3.new(9e4,9e4,9e4); flyBV.P = 9e4
	flyBV.Parent = root
	flyBG = Instance.new("BodyGyro")
	flyBG.MaxTorque = Vector3.new(9e4,9e4,9e4); flyBG.P = 9e4; flyBG.D = 1e3
	flyBG.CFrame = root.CFrame; flyBG.Parent = root
	exploitConns["fly"] = RunService.RenderStepped:Connect(function()
		if not root or not root.Parent then return end
		local cf  = workspace.CurrentCamera.CFrame
		local dir = Vector3.zero
		if UserInputService:IsKeyDown(Enum.KeyCode.W)         then dir = dir + cf.LookVector  end
		if UserInputService:IsKeyDown(Enum.KeyCode.S)         then dir = dir - cf.LookVector  end
		if UserInputService:IsKeyDown(Enum.KeyCode.A)         then dir = dir - cf.RightVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.D)         then dir = dir + cf.RightVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.Space)     then dir = dir + Vector3.yAxis  end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.yAxis  end
		flyBV.Velocity = dir.Magnitude > 0 and dir.Unit * _G.flySpeed or Vector3.zero
		flyBG.CFrame   = cf
	end)
end
local function disableFly()
	clearConn("fly")
	if flyBV then flyBV:Destroy(); flyBV = nil end
	if flyBG then flyBG:Destroy(); flyBG = nil end
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then hum.PlatformStand = false end
end

-- ── NOCLIP ──────────────────────────────────
local function enableNoclip()
	noclipDefaults = {}
	local char = player.Character
	if char then
		for _, p in ipairs(char:GetDescendants()) do
			if p:IsA("BasePart") then noclipDefaults[p] = p.CanCollide end
		end
	end
	exploitConns["noclip"] = RunService.Stepped:Connect(function()
		local c = player.Character; if not c then return end
		for _, p in ipairs(c:GetDescendants()) do
			if p:IsA("BasePart") then p.CanCollide = false end
		end
	end)
end
local function disableNoclip()
	clearConn("noclip")
	local char = player.Character
	if char then
		for _, p in ipairs(char:GetDescendants()) do
			if p:IsA("BasePart") then
				p.CanCollide = noclipDefaults[p] ~= nil and noclipDefaults[p] or true
			end
		end
	end
	noclipDefaults = {}
end

-- ── INF JUMP ────────────────────────────────
local function enableInfJump()
	exploitConns["infjump"] = UserInputService.JumpRequest:Connect(function()
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
	end)
end
local function disableInfJump() clearConn("infjump") end

-- ── ANTI-VOID ───────────────────────────────
local function enableAntiVoid()
	exploitConns["antivoid"] = RunService.Heartbeat:Connect(function()
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and root.Position.Y < -200 then
			root.CFrame = CFrame.new(root.Position.X, 100, root.Position.Z)
		end
	end)
end
local function disableAntiVoid() clearConn("antivoid") end

-- ── GOD MODE ────────────────────────────────
local function enableGodMode()
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	hum.MaxHealth = math.huge; hum.Health = math.huge
	healthConn = hum.HealthChanged:Connect(function()
		if hum.Health < hum.MaxHealth then hum.Health = math.huge end
	end)
end
local function disableGodMode()
	if healthConn then healthConn:Disconnect(); healthConn = nil end
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then hum.MaxHealth = 100; hum.Health = 100 end
end

-- ── HEAL ────────────────────────────────────
local function doHeal()
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then hum.Health = hum.MaxHealth end
end

-- ── ANTI-AFK ────────────────────────────────
local function enableAntiAFK()
	idledConn = player.Idled:Connect(function()
		pcall(function()
			game:GetService("VirtualInputManager"):SendKeyEvent(true,  "LeftShift", false, game)
			game:GetService("VirtualInputManager"):SendKeyEvent(false, "LeftShift", false, game)
		end)
	end)
end
local function disableAntiAFK()
	if idledConn then idledConn:Disconnect(); idledConn = nil end
end

-- ── INVISIBLE ───────────────────────────────
local invisEnabled = false
local function enableInvisible()
	invisEnabled = true
	local char = player.Character
	if not char then return end
	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") or part:IsA("Decal") then
			part.LocalTransparencyModifier = 1
		end
	end
	for _, obj in ipairs(char:GetDescendants()) do
		if obj:IsA("Accessory") then
			local h = obj:FindFirstChildOfClass("Part") or obj:FindFirstChildOfClass("MeshPart")
			if h then h.LocalTransparencyModifier = 1 end
		end
	end
end
local function disableInvisible()
	invisEnabled = false
	local char = player.Character
	if not char then return end
	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") or part:IsA("Decal") then
			part.LocalTransparencyModifier = 0
		end
	end
end
player.CharacterAdded:Connect(function(char)
	task.wait(0.1)
	if invisEnabled then
		for _, part in ipairs(char:GetDescendants()) do
			if part:IsA("BasePart") or part:IsA("Decal") then
				part.LocalTransparencyModifier = 1
			end
		end
	end
end)

-- ── SPINBOT ─────────────────────────────────
local function enableSpinBot()
	exploitConns["spinbot"] = RunService.Heartbeat:Connect(function()
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(20), 0) end
	end)
end
local function disableSpinBot() clearConn("spinbot") end

-- ── NO RELOAD ───────────────────────────────
local function enableNoReload()
	exploitConns["noreload"] = RunService.Heartbeat:Connect(function()
		local char = player.Character; if not char then return end
		local bp   = player.Backpack
		for _, src in ipairs({char, bp}) do
			for _, tool in ipairs(src:GetChildren()) do
				for _, v in ipairs(tool:GetDescendants()) do
					if v:IsA("IntValue") or v:IsA("NumberValue") then
						local n = v.Name:lower()
						if n:find("ammo") or n:find("clip") or n:find("magazine") or n:find("bullets") then
							if v.Value < 9999 then v.Value = 9999 end
						end
					end
				end
			end
		end
	end)
end
local function disableNoReload() clearConn("noreload") end

-- ── FREEZE AMMO ─────────────────────────────
local function enableFreezeAmmo()
	frozenAmmoVals = {}
	local function hookTool(tool)
		for _, v in ipairs(tool:GetDescendants()) do
			if v:IsA("IntValue") or v:IsA("NumberValue") then
				local n = v.Name:lower()
				if n:find("ammo") or n:find("clip") or n:find("magazine") or n:find("bullets") then
					local frozen = v.Value
					table.insert(frozenAmmoVals, v.Changed:Connect(function(val)
						if val < frozen then v.Value = frozen end
					end))
				end
			end
		end
	end
	local char = player.Character; local bp = player.Backpack
	if char then for _, t in ipairs(char:GetChildren()) do if t:IsA("Tool") then hookTool(t) end end end
	if bp   then for _, t in ipairs(bp:GetChildren())   do if t:IsA("Tool") then hookTool(t) end end end
end
local function disableFreezeAmmo()
	for _, c in ipairs(frozenAmmoVals) do c:Disconnect() end
	frozenAmmoVals = {}
end

-- ── HITBOX EXPAND ───────────────────────────
local function applyHitbox(target)
	if target == player then return end
	local char = target.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	if not hitboxData[target] then hitboxData[target] = root.Size end
	root.Size = Vector3.new(_G.hitboxSize, _G.hitboxSize, _G.hitboxSize)
end
local function removeHitbox(target)
	local orig = hitboxData[target]; if not orig then return end
	local char = target.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root then root.Size = orig end
	hitboxData[target] = nil
end
local function enableHitboxExpand()
	_G.hitboxEnabled = true
	for _, t in ipairs(Players:GetPlayers()) do applyHitbox(t) end
	exploitConns["hitbox"] = RunService.Heartbeat:Connect(function()
		for _, t in ipairs(Players:GetPlayers()) do
			if t ~= player then
				local char = t.Character
				local root = char and char:FindFirstChild("HumanoidRootPart")
				if root and root.Size.X ~= _G.hitboxSize then
					if not hitboxData[t] then hitboxData[t] = Vector3.new(2,2,1) end
					root.Size = Vector3.new(_G.hitboxSize, _G.hitboxSize, _G.hitboxSize)
				end
			end
		end
	end)
end
local function disableHitboxExpand()
	_G.hitboxEnabled = false; clearConn("hitbox")
	for _, t in ipairs(Players:GetPlayers()) do removeHitbox(t) end
	hitboxData = {}
end

-- ════════════════════════════════════════════
--  ESP STATE
-- ════════════════════════════════════════════
_G.ESP = {
	enabled      = true,   -- on by default
	teamCheck    = true,
	showBoxes    = true,   -- on by default
	showOutline  = false,
	showChams    = false,
	showSkeleton = false,
	showHealth   = false,
	showArmor    = false,
	showName     = false,
	showDistance = false,
	showLines    = false,
	showWeapon   = false,
	drawDead     = false,
	maxDist      = 741,
	lineOrigin   = "bottom",
}

local espData    = {}
local espRunConn = nil

local espFolder = Instance.new("Folder")
espFolder.Name  = "TZX_ESP"; espFolder.Parent = workspace

local espGui = Instance.new("ScreenGui")
espGui.Name             = "TZX_ESPGui"
espGui.ResetOnSpawn     = false
espGui.ZIndexBehavior   = Enum.ZIndexBehavior.Sibling
espGui.IgnoreGuiInset   = true
espGui.DisplayOrder     = 1000000000
espGui.Parent           = playerGui

local COL_BOX      = Color3.fromRGB(180, 80,  255)
local COL_HL_OUTL  = Color3.fromRGB(180, 80,  255)
local COL_FILL     = Color3.fromRGB(120, 40,  200)
local COL_HP_BG    = Color3.fromRGB(20,  20,  20)
local COL_HP_FULL  = Color3.fromRGB(80,  220, 80)
local COL_HP_LOW   = Color3.fromRGB(220, 60,  60)
local COL_ARMOR    = Color3.fromRGB(80,  160, 255)
local COL_LINE     = Color3.fromRGB(180, 80,  255)
local COL_SKELETON = Color3.fromRGB(200, 200, 255)

local SKEL_PAIRS = {
	{"Head","UpperTorso"},
	{"UpperTorso","LowerTorso"},
	{"LowerTorso","LeftUpperLeg"},   {"LowerTorso","RightUpperLeg"},
	{"LeftUpperLeg","LeftLowerLeg"}, {"RightUpperLeg","RightLowerLeg"},
	{"LeftLowerLeg","LeftFoot"},     {"RightLowerLeg","RightFoot"},
	{"UpperTorso","LeftUpperArm"},   {"UpperTorso","RightUpperArm"},
	{"LeftUpperArm","LeftLowerArm"}, {"RightUpperArm","RightLowerArm"},
	{"LeftLowerArm","LeftHand"},     {"RightLowerArm","RightHand"},
}
local SKEL_PAIRS_R6 = {
	{"Head","Torso"},
	{"Torso","Left Arm"},{"Torso","Right Arm"},
	{"Torso","Left Leg"},{"Torso","Right Leg"},
}

local function w2s(worldPos)
	local cam = workspace.CurrentCamera
	local v3  = cam:WorldToViewportPoint(worldPos)
	return Vector2.new(v3.X, v3.Y), (v3.Z > 0)
end

-- ── LINE helpers (skeleton + tracer only now) ──
local function makeLine(parent, col, thick)
	local f = Instance.new("Frame")
	f.AnchorPoint      = Vector2.new(0.5, 0.5)
	f.BackgroundColor3 = col or COL_SKELETON
	f.BorderSizePixel  = 0
	f.Size             = UDim2.new(0, 0, 0, thick or 1)
	f.Visible = false; f.ZIndex = 2; f.Parent = parent
	return f
end
local function setLine(f, a, b)
	local dx = b.X-a.X; local dy = b.Y-a.Y
	local len = math.sqrt(dx*dx+dy*dy)
	f.Position = UDim2.new(0,(a.X+b.X)/2, 0,(a.Y+b.Y)/2)
	f.Size     = UDim2.new(0,len, 0, f.Size.Y.Offset)
	f.Rotation = math.deg(math.atan2(dy,dx))
	f.Visible  = true
end

-- ── SQUARE BOX helper ────────────────────────
-- Returns a single Frame with UIStroke acting as a proper rectangle outline.
local function makeSquareBox(parent)
	local box = Instance.new("Frame")
	box.BackgroundTransparency = 1        -- hollow centre
	box.BorderSizePixel        = 0
	box.Visible                = false
	box.ZIndex                 = 6
	box.Parent                 = parent

	local stroke = Instance.new("UIStroke")
	stroke.Color             = COL_BOX
	stroke.Thickness         = 2          -- 2 px outline looks clean
	stroke.ApplyStrokeMode   = Enum.ApplyStrokeMode.Border
	stroke.Transparency      = 0
	stroke.Parent            = box

	return box, stroke
end

-- Position/size the square box from two screen-space corners.
local function setSquareBox(box, tl, br)
	local w = br.X - tl.X
	local h = br.Y - tl.Y
	box.Position = UDim2.new(0, tl.X, 0, tl.Y)
	box.Size     = UDim2.new(0, w,    0, h)
	box.Visible  = true
end

-- ── OPTIMIZED getCharBounds ──────────────────
local KEY_PARTS = {
	"Head","UpperTorso","LowerTorso","HumanoidRootPart",
	"LeftFoot","RightFoot","LeftHand","RightHand",
	"Torso","Left Arm","Right Arm","Left Leg","Right Leg",
}
local function getCharBounds(char)
	local cam = workspace.CurrentCamera
	local minX,minY,maxX,maxY = math.huge,math.huge,-math.huge,-math.huge
	local anyOn = false
	local parts = {}
	for _, name in ipairs(KEY_PARTS) do
		local p = char:FindFirstChild(name)
		if p and p:IsA("BasePart") then table.insert(parts, p) end
	end
	if #parts == 0 then
		for _, p in ipairs(char:GetDescendants()) do
			if p:IsA("BasePart") then table.insert(parts, p) end
		end
	end
	for _, part in ipairs(parts) do
		local cf, sz = part.CFrame, part.Size * 0.5
		local checks = {
			cf * Vector3.new( sz.X,  sz.Y,  sz.Z),
			cf * Vector3.new(-sz.X,  sz.Y,  sz.Z),
			cf * Vector3.new( sz.X, -sz.Y, -sz.Z),
			cf * Vector3.new(-sz.X, -sz.Y, -sz.Z),
		}
		for _, c in ipairs(checks) do
			local sv = cam:WorldToViewportPoint(c)
			if sv.Z > 0 then
				if sv.X < minX then minX = sv.X end
				if sv.Y < minY then minY = sv.Y end
				if sv.X > maxX then maxX = sv.X end
				if sv.Y > maxY then maxY = sv.Y end
				anyOn = true
			end
		end
	end
	if not anyOn then return nil end
	return Vector2.new(minX-4, minY-4), Vector2.new(maxX+4, maxY+4)
end

local function getArmor(target)
	local char = target.Character; if not char then return nil end
	for _, n in ipairs({"Armor","Armour","Shield","ArmorValue","ArmourValue"}) do
		local v = char:FindFirstChild(n,true) or target:FindFirstChild(n,true)
		if v and (v:IsA("NumberValue") or v:IsA("IntValue")) then return v.Value end
	end
	return nil
end
local function getWeaponName(target)
	local char = target.Character; if not char then return nil end
	for _, c in ipairs(char:GetChildren()) do
		if c:IsA("Tool") then return c.Name end
	end
	return nil
end

local function buildESP(target)
	if target == player or espData[target] then return end
	local d = {}
	local con = Instance.new("Frame")
	con.Name = "ESP_"..target.UserId
	con.Size = UDim2.new(1,0,1,0)
	con.BackgroundTransparency = 1; con.BorderSizePixel = 0; con.ZIndex = 1
	con.Parent = espGui
	d.container = con

	local hl = Instance.new("Highlight")
	hl.Name = "TZX_HL"; hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.OutlineColor = COL_HL_OUTL; hl.FillColor = COL_FILL
	hl.OutlineTransparency = 1; hl.FillTransparency = 1
	hl.Enabled = false; hl.Parent = espFolder
	d.highlight = hl

	-- ── Single square box Frame + UIStroke ──
	local box, boxStroke = makeSquareBox(con)
	d.box       = box
	d.boxStroke = boxStroke

	-- BillboardGui
	local bb = Instance.new("BillboardGui")
	bb.Name          = "TZX_BB"
	bb.AlwaysOnTop   = true
	bb.Size          = UDim2.new(0,160, 0,40)
	bb.StudsOffset   = Vector3.new(0, 1.2, 0)
	bb.ResetOnSpawn  = false
	bb.Enabled       = false
	bb.Parent        = espFolder

	local nameL = Instance.new("TextLabel")
	nameL.Size = UDim2.new(1,0,0,14); nameL.Position = UDim2.new(0,0,0,0)
	nameL.BackgroundTransparency = 1; nameL.TextColor3 = COL_BOX; nameL.TextSize = 11
	nameL.Font = Enum.Font.GothamBold
	nameL.TextStrokeColor3 = Color3.new(0,0,0); nameL.TextStrokeTransparency = 0.3
	nameL.Text = ""; nameL.Visible = false; nameL.Parent = bb

	local distL = Instance.new("TextLabel")
	distL.Size = UDim2.new(1,0,0,12); distL.Position = UDim2.new(0,0,0,15)
	distL.BackgroundTransparency = 1; distL.TextColor3 = Color3.fromRGB(190,190,210); distL.TextSize = 9
	distL.Font = Enum.Font.Gotham
	distL.TextStrokeColor3 = Color3.new(0,0,0); distL.TextStrokeTransparency = 0.4
	distL.Text = ""; distL.Visible = false; distL.Parent = bb

	local weapL = Instance.new("TextLabel")
	weapL.Size = UDim2.new(1,0,0,11); weapL.Position = UDim2.new(0,0,0,28)
	weapL.BackgroundTransparency = 1; weapL.TextColor3 = Color3.fromRGB(255,200,100); weapL.TextSize = 8
	weapL.Font = Enum.Font.Gotham
	weapL.TextStrokeColor3 = Color3.new(0,0,0); weapL.TextStrokeTransparency = 0.4
	weapL.Text = ""; weapL.Visible = false; weapL.Parent = bb

	d.billboard = bb; d.nameLabel = nameL; d.distLabel = distL; d.weapLabel = weapL

	-- HP bar
	local hpBorder = Instance.new("Frame")
	hpBorder.BackgroundColor3 = Color3.new(0,0,0); hpBorder.BorderSizePixel = 0
	hpBorder.Visible = false; hpBorder.ZIndex = 3; hpBorder.Parent = con
	local hpBg = Instance.new("Frame")
	hpBg.BackgroundColor3 = COL_HP_BG; hpBg.BorderSizePixel = 0
	hpBg.Visible = false; hpBg.ZIndex = 4; hpBg.Parent = con
	local hpFill = Instance.new("Frame")
	hpFill.BackgroundColor3 = COL_HP_FULL; hpFill.BorderSizePixel = 0
	hpFill.Visible = false; hpFill.ZIndex = 5; hpFill.Parent = con
	d.hpBorder = hpBorder; d.hpBg = hpBg; d.hpFill = hpFill

	-- Armor bar
	local arBorder = Instance.new("Frame")
	arBorder.BackgroundColor3 = Color3.new(0,0,0); arBorder.BorderSizePixel = 0
	arBorder.Visible = false; arBorder.ZIndex = 3; arBorder.Parent = con
	local arBg = Instance.new("Frame")
	arBg.BackgroundColor3 = COL_HP_BG; arBg.BorderSizePixel = 0
	arBg.Visible = false; arBg.ZIndex = 4; arBg.Parent = con
	local arFill = Instance.new("Frame")
	arFill.BackgroundColor3 = COL_ARMOR; arFill.BorderSizePixel = 0
	arFill.Visible = false; arFill.ZIndex = 5; arFill.Parent = con
	d.arBorder = arBorder; d.arBg = arBg; d.arFill = arFill

	d.skelLines = {}
	for i = 1, math.max(#SKEL_PAIRS, #SKEL_PAIRS_R6) do
		d.skelLines[i] = makeLine(con, COL_SKELETON, 1)
	end
	d.tracer = makeLine(con, COL_LINE, 2)
	espData[target] = d
end

local function destroyESP(target)
	local d = espData[target]; if not d then return end
	pcall(function() d.highlight:Destroy() end)
	pcall(function() d.billboard:Destroy() end)
	pcall(function() d.container:Destroy() end)
	espData[target] = nil
end

local function attachToChar(d, char)
	if not d then return end
	if d.highlight then d.highlight.Adornee = char end
	if d.billboard then
		d.billboard.Adornee = char:FindFirstChild("Head") or char:FindFirstChildOfClass("BasePart")
	end
end

-- ── OPTIMIZED ESP UPDATE ─────────────────────
local _cachedPlayers = {}
local _playerCacheTime = 0
local function getCachedPlayers()
	local t = tick()
	if t - _playerCacheTime > 2 then
		_cachedPlayers = Players:GetPlayers()
		_playerCacheTime = t
	end
	return _cachedPlayers
end

local function espUpdate()
	local cam    = workspace.CurrentCamera
	local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local vp     = cam.ViewportSize

	local tracerOrigin
	if     _G.ESP.lineOrigin == "top"    then tracerOrigin = Vector2.new(vp.X/2, 0)
	elseif _G.ESP.lineOrigin == "middle" then tracerOrigin = Vector2.new(vp.X/2, vp.Y/2)
	else                                      tracerOrigin = Vector2.new(vp.X/2, vp.Y) end

	for _, target in ipairs(getCachedPlayers()) do
		if target == player then continue end

		-- Team check
		if isSameTeam(target) then
			local d = espData[target]
			if d then
				if d.box then d.box.Visible = false end
				if d.highlight then d.highlight.Enabled = false end
				if d.billboard then d.billboard.Enabled = false end
				d.hpBorder.Visible = false; d.hpBg.Visible = false; d.hpFill.Visible = false
				d.arBorder.Visible = false; d.arBg.Visible = false; d.arFill.Visible = false
				for _, ln in ipairs(d.skelLines) do ln.Visible = false end
				d.tracer.Visible = false
			end
			continue
		end

		local d = espData[target]; local char = target.Character
		if not d or not char then continue end

		local root = char:FindFirstChild("HumanoidRootPart")
		local hum  = char:FindFirstChildOfClass("Humanoid")
		local dist = 9999
		if root and myRoot then
			dist = (root.Position - myRoot.Position).Magnitude
		end
		local isDead = (not hum) or (hum.Health <= 0)
		local show   = _G.ESP.enabled
			and (dist <= _G.ESP.maxDist)
			and (not isDead or _G.ESP.drawDead)

		-- Bounding box (computed once, reused)
		local tl, br
		if show and (_G.ESP.showBoxes or _G.ESP.showHealth or _G.ESP.showArmor) then
			tl, br = getCharBounds(char)
		end

		-- ── SQUARE BOX ──────────────────────
		if show and _G.ESP.showBoxes and tl and br then
			setSquareBox(d.box, tl, br)
		else
			if d.box then d.box.Visible = false end
		end

		-- Highlight / Chams
		if d.highlight then
			local needHL = show and (_G.ESP.showOutline or _G.ESP.showChams)
			d.highlight.Enabled = needHL
			d.highlight.Adornee = needHL and char or nil
			d.highlight.OutlineTransparency = (show and _G.ESP.showOutline) and 0 or 1
			d.highlight.FillTransparency    = (show and _G.ESP.showChams)   and 0.5 or 1
		end

		-- Billboard
		local bbOn = show and (_G.ESP.showName or _G.ESP.showDistance or _G.ESP.showWeapon)
		if d.billboard  then d.billboard.Enabled = bbOn end
		if d.nameLabel  then
			d.nameLabel.Visible = bbOn and _G.ESP.showName
			if bbOn and _G.ESP.showName then d.nameLabel.Text = target.Name end
		end
		if d.distLabel  then
			d.distLabel.Visible = bbOn and _G.ESP.showDistance
			if bbOn and _G.ESP.showDistance then
				d.distLabel.Text = string.format("%.0f studs", dist)
			end
		end
		if d.weapLabel  then
			d.weapLabel.Visible = bbOn and _G.ESP.showWeapon
			if bbOn and _G.ESP.showWeapon then
				local wn = getWeaponName(target)
				d.weapLabel.Text = wn and ("\xF0\x9F\x94\xAB "..wn) or ""
			end
		end

		-- HP bar
		if show and _G.ESP.showHealth and tl and br then
			local charH = br.Y - tl.Y
			local barW  = math.max(2, math.floor(charH * 0.04))
			local pct   = hum and math.clamp(hum.Health / math.max(hum.MaxHealth,1), 0, 1) or 1
			local fillH = math.max(1, math.floor(charH * pct))
			local leftX = tl.X - barW - 3
			d.hpBorder.Position = UDim2.new(0,leftX-1, 0,tl.Y-1)
			d.hpBorder.Size     = UDim2.new(0,barW+2,  0,charH+2); d.hpBorder.Visible = true
			d.hpBg.Position     = UDim2.new(0,leftX,   0,tl.Y)
			d.hpBg.Size         = UDim2.new(0,barW,    0,charH);   d.hpBg.Visible = true
			d.hpFill.BackgroundColor3 = pct > 0.5 and COL_HP_FULL or COL_HP_LOW
			d.hpFill.Position = UDim2.new(0,leftX, 0,tl.Y+charH-fillH)
			d.hpFill.Size     = UDim2.new(0,barW,  0,fillH);       d.hpFill.Visible = true
		else
			d.hpBorder.Visible = false; d.hpBg.Visible = false; d.hpFill.Visible = false
		end

		-- Armor bar
		if show and _G.ESP.showArmor and tl and br then
			local arVal = getArmor(target)
			if arVal then
				local charH = br.Y - tl.Y
				local barW  = math.max(2, math.floor(charH * 0.04))
				local pct   = math.clamp(arVal/100, 0, 1)
				local fillH = math.max(1, math.floor(charH * pct))
				local rightX = br.X + 3
				d.arBorder.Position = UDim2.new(0,rightX-1, 0,tl.Y-1)
				d.arBorder.Size     = UDim2.new(0,barW+2,   0,charH+2); d.arBorder.Visible = true
				d.arBg.Position     = UDim2.new(0,rightX,   0,tl.Y)
				d.arBg.Size         = UDim2.new(0,barW,     0,charH);   d.arBg.Visible = true
				d.arFill.Position   = UDim2.new(0,rightX,   0,tl.Y+charH-fillH)
				d.arFill.Size       = UDim2.new(0,barW,     0,fillH);   d.arFill.Visible = true
			else
				d.arBorder.Visible = false; d.arBg.Visible = false; d.arFill.Visible = false
			end
		else
			d.arBorder.Visible = false; d.arBg.Visible = false; d.arFill.Visible = false
		end

		-- Skeleton
		local skelOn = show and _G.ESP.showSkeleton
		local isR15  = hum and hum.RigType == Enum.HumanoidRigType.R15
		local pairs_ = isR15 and SKEL_PAIRS or SKEL_PAIRS_R6
		for i, ln in ipairs(d.skelLines) do
			local pair = pairs_[i]
			if skelOn and pair then
				local pA = char:FindFirstChild(pair[1])
				local pB = char:FindFirstChild(pair[2])
				if pA and pB then
					local sA, onA = w2s(pA.Position)
					local sB, onB = w2s(pB.Position)
					if onA and onB then setLine(ln, sA, sB) else ln.Visible = false end
				else ln.Visible = false end
			else ln.Visible = false end
		end

		-- Tracer
		if show and _G.ESP.showLines and root then
			local sPos, onScreen = w2s(root.Position)
			if onScreen then
				setLine(d.tracer, tracerOrigin, sPos)
				d.tracer.BackgroundColor3 = COL_LINE
			else d.tracer.Visible = false end
		else d.tracer.Visible = false end
	end
end

local function startESPLoop()
	if espRunConn then return end
	espRunConn = RunService.RenderStepped:Connect(espUpdate)
end
local function stopESPLoop()
	if espRunConn then espRunConn:Disconnect(); espRunConn = nil end
end

local function refreshAllESP()
	if _G.ESP.enabled then
		for _, t in ipairs(Players:GetPlayers()) do
			if t ~= player then
				buildESP(t)
				if t.Character then attachToChar(espData[t], t.Character) end
			end
		end
		startESPLoop()
	else
		stopESPLoop()
		for _, t in ipairs(Players:GetPlayers()) do destroyESP(t) end
	end
end

local function recalcESPEnabled()
	_G.ESP.enabled = _G.ESP.showBoxes or _G.ESP.showOutline or _G.ESP.showChams or _G.ESP.showSkeleton
		or _G.ESP.showHealth or _G.ESP.showArmor or _G.ESP.showName or _G.ESP.showDistance
		or _G.ESP.showLines  or _G.ESP.showWeapon
	refreshAllESP()
end

Players.PlayerAdded:Connect(function(p)
	if p == player then return end
	if _G.ESP.enabled then buildESP(p) end
	p.CharacterAdded:Connect(function(char)
		if _G.ESP.enabled and espData[p] then task.wait(); attachToChar(espData[p], char) end
	end)
end)
Players.PlayerRemoving:Connect(function(p) destroyESP(p) end)
for _, p in ipairs(Players:GetPlayers()) do
	if p ~= player then
		p.CharacterAdded:Connect(function(char)
			if _G.ESP.enabled and espData[p] then task.wait(); attachToChar(espData[p], char) end
		end)
	end
end

-- ════════════════════════════════════════════
--  RADAR
-- ════════════════════════════════════════════
_G.RADAR = { enabled=false, range=200, showNames=false, size=160 }

local radarGui = Instance.new("ScreenGui")
radarGui.Name           = "TZX_Radar"
radarGui.ResetOnSpawn   = false
radarGui.IgnoreGuiInset = true
radarGui.DisplayOrder   = 1000000000
radarGui.Parent         = playerGui

local radarFrame = new("Frame", {
	Size = UDim2.new(0,_G.RADAR.size,0,_G.RADAR.size),
	Position = UDim2.new(1,-_G.RADAR.size-12, 1,-_G.RADAR.size-12),
	BackgroundColor3 = Color3.fromRGB(10,10,15), BackgroundTransparency = 0.3,
	BorderSizePixel = 0, Visible = false, ZIndex = 1,
}, radarGui)
corner(radarFrame, _G.RADAR.size/2)
new("UIStroke",{Color=C.accent,Thickness=1.5,ApplyStrokeMode=Enum.ApplyStrokeMode.Border,Transparency=0.5}, radarFrame)
new("Frame",{Size=UDim2.new(0,1,1,0),Position=UDim2.new(0.5,0,0,0),BackgroundColor3=Color3.fromRGB(60,60,80),BackgroundTransparency=0.5,BorderSizePixel=0,ZIndex=2}, radarFrame)
new("Frame",{Size=UDim2.new(1,0,0,1),Position=UDim2.new(0,0,0.5,0),BackgroundColor3=Color3.fromRGB(60,60,80),BackgroundTransparency=0.5,BorderSizePixel=0,ZIndex=2}, radarFrame)

local selfDot = new("Frame",{
	Size=UDim2.new(0,6,0,6), Position=UDim2.new(0.5,-3,0.5,-3),
	BackgroundColor3=Color3.fromRGB(100,200,255), BorderSizePixel=0, ZIndex=4,
}, radarFrame); corner(selfDot,4)

local radarDots = {}
local function getRadarDot(i)
	if not radarDots[i] then
		local dot = new("Frame",{Size=UDim2.new(0,6,0,6),BackgroundColor3=Color3.fromRGB(255,80,80),BorderSizePixel=0,ZIndex=4,Visible=false}, radarFrame)
		corner(dot,4)
		local lbl = new("TextLabel",{Size=UDim2.new(0,60,0,12),Position=UDim2.new(0,8,0,-3),BackgroundTransparency=1,TextColor3=Color3.fromRGB(255,200,200),TextSize=9,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,Text="",Visible=false,ZIndex=5}, dot)
		radarDots[i] = {dot=dot, label=lbl}
	end
	return radarDots[i]
end

local radarConn = nil
local function startRadar()
	if radarConn then return end
	radarConn = RunService.RenderStepped:Connect(function()
		if not _G.RADAR.enabled then return end
		local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not myRoot then return end
		local myCF = myRoot.CFrame; local half = _G.RADAR.size/2
		local others = {}
		for _, t in ipairs(Players:GetPlayers()) do
			if t ~= player and t.Character then
				local r = t.Character:FindFirstChild("HumanoidRootPart")
				if r then table.insert(others,{t=t,root=r}) end
			end
		end
		for i, entry in ipairs(others) do
			local slot = getRadarDot(i)
			local rel  = myCF:PointToObjectSpace(entry.root.Position)
			local rx   = math.clamp(rel.X/_G.RADAR.range,-1,1)
			local ry   = math.clamp(-rel.Z/_G.RADAR.range,-1,1)
			slot.dot.Position  = UDim2.new(0,half+rx*half-3, 0,half-ry*half-3)
			slot.dot.Visible   = true
			slot.label.Text    = _G.RADAR.showNames and entry.t.Name or ""
			slot.label.Visible = _G.RADAR.showNames
		end
		for i = #others+1, #radarDots do
			radarDots[i].dot.Visible = false; radarDots[i].label.Visible = false
		end
	end)
end
local function stopRadar()
	if radarConn then radarConn:Disconnect(); radarConn = nil end
	for _, slot in ipairs(radarDots) do slot.dot.Visible=false; slot.label.Visible=false end
end

-- ════════════════════════════════════════════
--  TELEPORT UI
-- ════════════════════════════════════════════
local tpGui = Instance.new("ScreenGui")
tpGui.Name="TZX_TPUI"; tpGui.ResetOnSpawn=false
tpGui.IgnoreGuiInset=true; tpGui.DisplayOrder=1000000000; tpGui.Parent=playerGui

local tpFrame = new("Frame",{
	Size=UDim2.new(0,240,0,300), Position=UDim2.new(0.5,-120,0.5,-150),
	BackgroundColor3=C.bg, BorderSizePixel=0, Visible=false, ZIndex=1,
}, tpGui); corner(tpFrame,10)
new("UIStroke",{Color=C.accent,Thickness=1.5,ApplyStrokeMode=Enum.ApplyStrokeMode.Border}, tpFrame)
new("TextLabel",{Size=UDim2.new(1,0,0,32),Position=UDim2.new(0,0,0,0),BackgroundColor3=C.panel,BorderSizePixel=0,Text="Teleport to Player",TextColor3=C.textBright,TextSize=12,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Center,ZIndex=2}, tpFrame)
local tpClose = new("TextButton",{Size=UDim2.new(0,24,0,24),Position=UDim2.new(1,-28,0,4),BackgroundTransparency=1,Text="✕",TextColor3=C.textDim,TextSize=14,Font=Enum.Font.GothamBold,ZIndex=3}, tpFrame)
tpClose.MouseButton1Click:Connect(function() tpFrame.Visible=false end)
local tpScroll = new("ScrollingFrame",{
	Size=UDim2.new(1,-12,1,-44), Position=UDim2.new(0,6,0,38),
	BackgroundTransparency=1, CanvasSize=UDim2.new(0,0,0,0),
	AutomaticCanvasSize=Enum.AutomaticSize.Y, ScrollBarThickness=3,
	ScrollBarImageColor3=C.accent, BorderSizePixel=0, ZIndex=2,
}, tpFrame)
new("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,4)}, tpScroll)

local tpRows = {}
local function refreshTPList()
	for _, r in ipairs(tpRows) do r:Destroy() end; tpRows = {}
	for _, t in ipairs(Players:GetPlayers()) do
		if t == player then continue end
		local hum   = t.Character and t.Character:FindFirstChildOfClass("Humanoid")
		local hp    = hum and math.floor(hum.Health) or "?"
		local armor = getArmor(t)
		local row   = new("Frame",{Size=UDim2.new(1,-6,0,44),BackgroundColor3=C.section,BorderSizePixel=0,ZIndex=3}, tpScroll); corner(row,6)
		new("TextLabel",{Size=UDim2.new(1,-12,0,18),Position=UDim2.new(0,8,0,4),BackgroundTransparency=1,Text=t.Name,TextColor3=C.textBright,TextSize=11,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=4}, row)
		local infoStr = "HP: "..tostring(hp)
		if armor then infoStr=infoStr.."  |  Armor: "..math.floor(armor) end
		new("TextLabel",{Size=UDim2.new(1,-70,0,14),Position=UDim2.new(0,8,0,23),BackgroundTransparency=1,Text=infoStr,TextColor3=C.textDim,TextSize=9,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=4}, row)
		local tpBtn = new("TextButton",{Size=UDim2.new(0,44,0,26),Position=UDim2.new(1,-52,0.5,-13),BackgroundColor3=C.toggleOn,Text="TP",TextColor3=Color3.new(1,1,1),TextSize=11,Font=Enum.Font.GothamBold,BorderSizePixel=0,ZIndex=4}, row); corner(tpBtn,5)
		row.MouseEnter:Connect(function() row.BackgroundColor3=C.rowHover end)
		row.MouseLeave:Connect(function() row.BackgroundColor3=C.section  end)
		local target = t
		tpBtn.MouseButton1Click:Connect(function()
			local myRoot    = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local theirRoot = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
			if myRoot and theirRoot then myRoot.CFrame = theirRoot.CFrame + Vector3.new(0,3,0) end
			tpFrame.Visible = false
		end)
		table.insert(tpRows, row)
	end
end

-- ════════════════════════════════════════════
--  PLAYER LIST UI
-- ════════════════════════════════════════════
local plGui = Instance.new("ScreenGui")
plGui.Name="TZX_PLGui"; plGui.ResetOnSpawn=false
plGui.IgnoreGuiInset=true; plGui.DisplayOrder=1000000000; plGui.Parent=playerGui

local plFrame = new("Frame",{
	Size=UDim2.new(0,320,0,340), Position=UDim2.new(0.5,-160,0.5,-170),
	BackgroundColor3=C.bg, BorderSizePixel=0, Visible=false, ZIndex=1,
}, plGui); corner(plFrame,10)
new("UIStroke",{Color=C.accent,Thickness=1.5,ApplyStrokeMode=Enum.ApplyStrokeMode.Border}, plFrame)
new("TextLabel",{Size=UDim2.new(1,0,0,32),Position=UDim2.new(0,0,0,0),BackgroundColor3=C.panel,BorderSizePixel=0,Text="Player List",TextColor3=C.textBright,TextSize=12,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Center,ZIndex=2}, plFrame)
local plClose = new("TextButton",{Size=UDim2.new(0,24,0,24),Position=UDim2.new(1,-28,0,4),BackgroundTransparency=1,Text="✕",TextColor3=C.textDim,TextSize=14,Font=Enum.Font.GothamBold,ZIndex=3}, plFrame)
plClose.MouseButton1Click:Connect(function() plFrame.Visible=false end)
local plScroll = new("ScrollingFrame",{
	Size=UDim2.new(1,-12,1,-44), Position=UDim2.new(0,6,0,38),
	BackgroundTransparency=1, CanvasSize=UDim2.new(0,0,0,0),
	AutomaticCanvasSize=Enum.AutomaticSize.Y, ScrollBarThickness=3,
	ScrollBarImageColor3=C.accent, BorderSizePixel=0, ZIndex=2,
}, plFrame)
new("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,4)}, plScroll)

local plRows = {}
local function refreshPlayerList()
	for _, r in ipairs(plRows) do r:Destroy() end; plRows = {}
	for _, t in ipairs(Players:GetPlayers()) do
		local hum   = t.Character and t.Character:FindFirstChildOfClass("Humanoid")
		local hp    = hum and math.floor(hum.Health) or "?"
		local maxHp = hum and math.floor(hum.MaxHealth) or "?"
		local armor = getArmor(t)
		local weap  = getWeaponName(t)
		local isFr  = _G.friendsList[t.Name] and "\xe2\x98\x85 " or ""
		local row = new("Frame",{
			Size=UDim2.new(1,-6,0,54),
			BackgroundColor3=(t==player) and C.accentDim or C.section,
			BorderSizePixel=0, ZIndex=3,
		}, plScroll); corner(row,6)
		new("TextLabel",{Size=UDim2.new(1,-80,0,18),Position=UDim2.new(0,8,0,4),BackgroundTransparency=1,Text=isFr..t.Name,TextColor3=(t==player) and C.accent or C.textBright,TextSize=11,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=4}, row)
		new("TextLabel",{Size=UDim2.new(0,60,0,14),Position=UDim2.new(1,-66,0,4),BackgroundTransparency=1,Text="ID: "..t.UserId,TextColor3=C.textDim,TextSize=8,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Right,ZIndex=4}, row)
		local info1="HP: "..hp.."/"..maxHp
		if armor then info1=info1.."  |  Armor: "..math.floor(armor) end
		new("TextLabel",{Size=UDim2.new(1,-12,0,13),Position=UDim2.new(0,8,0,23),BackgroundTransparency=1,Text=info1,TextColor3=Color3.fromRGB(100,220,100),TextSize=9,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=4}, row)
		new("TextLabel",{Size=UDim2.new(1,-80,0,13),Position=UDim2.new(0,8,0,37),BackgroundTransparency=1,Text=weap and ("\xF0\x9F\x94\xAB "..weap) or "No weapon",TextColor3=Color3.fromRGB(255,200,100),TextSize=9,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=4}, row)
		if t ~= player then
			local frBtn = new("TextButton",{
				Size=UDim2.new(0,26,0,22), Position=UDim2.new(1,-60,0.5,-11),
				BackgroundColor3=_G.friendsList[t.Name] and Color3.fromRGB(255,200,40) or C.toggleOff,
				Text="\xe2\x98\x85", TextColor3=Color3.new(1,1,1), TextSize=12, Font=Enum.Font.GothamBold, BorderSizePixel=0, ZIndex=4,
			}, row); corner(frBtn,5)
			local target = t
			frBtn.MouseButton1Click:Connect(function()
				if _G.friendsList[target.Name] then
					_G.friendsList[target.Name] = nil
					frBtn.BackgroundColor3 = C.toggleOff
				else
					_G.friendsList[target.Name] = true
					frBtn.BackgroundColor3 = Color3.fromRGB(255,200,40)
				end
				refreshPlayerList()
			end)
		end
		table.insert(plRows, row)
	end
end

-- ════════════════════════════════════════════
--  FPS COUNTER
-- ════════════════════════════════════════════
local fpsLabel   = nil
local fpsConn    = nil
local fpsSamples = {}

local function startFPS()
	if fpsConn then return end
	fpsConn = RunService.RenderStepped:Connect(function(dt)
		if dt <= 0 then return end
		table.insert(fpsSamples, 1/dt)
		if #fpsSamples > 20 then table.remove(fpsSamples,1) end
		if fpsLabel then
			local sum=0; for _,v in ipairs(fpsSamples) do sum=sum+v end
			local avg = math.min(999, math.floor(sum/#fpsSamples))
			local col = avg>=55 and Color3.fromRGB(100,230,100) or avg>=30 and Color3.fromRGB(230,180,40) or Color3.fromRGB(220,70,70)
			fpsLabel.Text=avg.." FPS"; fpsLabel.TextColor3=col
		end
	end)
end
local function stopFPS()
	if fpsConn then fpsConn:Disconnect(); fpsConn=nil end
	if fpsLabel then fpsLabel.Visible=false end
end

-- ════════════════════════════════════════════
--  AIMLOCK
-- ════════════════════════════════════════════
_G.AIM    = { enabled=true, hotkey=Enum.KeyCode.Q, smoothing=8, fov=150, showFov=false, prediction=0 }
_G.SILENT = { enabled=false, fov=100, hitchance=80 }
_G.TRIGGER = { enabled=false }

local aimConn       = nil
local aimHotkeyConn = nil
local aimEndConn    = nil
local aimActive     = false
local fovCircle     = nil

local function getClosestTarget(fovOverride)
	local cam    = workspace.CurrentCamera
	-- Use mouse position as FOV origin so the ring matches what's visible on screen
	local center = UserInputService:GetMouseLocation()
	local best, bestDist = nil, (fovOverride or _G.AIM.fov)

	for _, t in ipairs(Players:GetPlayers()) do
		if t == player or isFriend(t) or isSameTeam(t) then continue end
		local char = t.Character; if not char then continue end
		local head = char:FindFirstChild("Head")
		local hum  = char:FindFirstChildOfClass("Humanoid")
		if not head or (hum and hum.Health <= 0) then continue end

		local aimPos = head.Position
		if _G.AIM.prediction > 0 then
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if hrp then
				aimPos = aimPos + hrp.AssemblyLinearVelocity * (_G.AIM.prediction * 0.016)
			end
		end

		local sv = cam:WorldToViewportPoint(aimPos)
		if sv.Z <= 0 then continue end
		local d = (Vector2.new(sv.X,sv.Y) - center).Magnitude
		if d < bestDist then bestDist=d; best={head=head, aimPos=aimPos} end
	end
	return best
end

local function stopAimlock()
	if aimConn then aimConn:Disconnect(); aimConn=nil end
end

local function startAimlock()
	if aimConn then return end
	aimConn = RunService.RenderStepped:Connect(function(dt)
		-- Main aimlock (FOV circle update moved to its own loop below)
		if aimActive and _G.AIM.enabled then
			local result = getClosestTarget()
			if result then
				local cam    = workspace.CurrentCamera
				local sv     = cam:WorldToViewportPoint(result.aimPos)
				if sv.Z > 0 then
					local tPos   = Vector2.new(sv.X, sv.Y)
					local mouse  = UserInputService:GetMouseLocation()
					local dx = tPos.X - mouse.X
					local dy = tPos.Y - mouse.Y
					local smooth = math.max(1, _G.AIM.smoothing)
					local mx = dx / smooth
					local my = dy / smooth
					pcall(function() mousemoverel(mx, my) end)
				end
			end
		end

		-- Silent aim
		if _G.SILENT.enabled then
			local result = getClosestTarget(_G.SILENT.fov)
			if result and math.random(1,100) <= _G.SILENT.hitchance then
				local cam = workspace.CurrentCamera
				local sv  = cam:WorldToViewportPoint(result.aimPos)
				if sv.Z > 0 then
					local mouse = UserInputService:GetMouseLocation()
					pcall(function() mousemoverel(sv.X - mouse.X, sv.Y - mouse.Y) end)
				end
			end
		end

		-- Triggerbot
		if _G.TRIGGER.enabled then
			local cam    = workspace.CurrentCamera; local vp = cam.ViewportSize
			local center = Vector2.new(vp.X/2, vp.Y/2)
			local unitRay = cam:ViewportPointToRay(center.X, center.Y)
			local result  = workspace:Raycast(unitRay.Origin, unitRay.Direction*1000)
			if result then
				local hitChar   = result.Instance and result.Instance.Parent
				local hitPlayer = hitChar and Players:GetPlayerFromCharacter(hitChar)
				if hitPlayer and hitPlayer ~= player and not isFriend(hitPlayer) and not isSameTeam(hitPlayer) then
					local hum = hitChar:FindFirstChildOfClass("Humanoid")
					if hum and hum.Health > 0 then pcall(function() mouse1click() end) end
				end
			end
		end
	end)
end

local function bindAimHotkey(kc)
	_G.AIM.hotkey = kc
	if aimHotkeyConn then aimHotkeyConn:Disconnect() end
	if aimEndConn    then aimEndConn:Disconnect()    end
	aimHotkeyConn = UserInputService.InputBegan:Connect(function(inp, gp)
		if gp or not _G.AIM.enabled then return end
		if inp.KeyCode == _G.AIM.hotkey then aimActive = true end
	end)
	aimEndConn = UserInputService.InputEnded:Connect(function(inp)
		if inp.KeyCode == _G.AIM.hotkey then aimActive = false end
	end)
end

startAimlock(); bindAimHotkey(_G.AIM.hotkey)

-- ════════════════════════════════════════════
--  CONFIG SYSTEM
-- ════════════════════════════════════════════
local function getConfigState()
	return {
		ESP = {
			teamCheck    = _G.ESP.teamCheck,
			showBoxes    = _G.ESP.showBoxes,
			showOutline  = _G.ESP.showOutline,
			showChams    = _G.ESP.showChams,
			showSkeleton = _G.ESP.showSkeleton,
			showHealth   = _G.ESP.showHealth,
			showArmor    = _G.ESP.showArmor,
			showName     = _G.ESP.showName,
			showDistance = _G.ESP.showDistance,
			showLines    = _G.ESP.showLines,
			showWeapon   = _G.ESP.showWeapon,
			drawDead     = _G.ESP.drawDead,
			maxDist      = _G.ESP.maxDist,
			lineOrigin   = _G.ESP.lineOrigin,
		},
		AIM = {
			enabled    = _G.AIM.enabled,
			smoothing  = _G.AIM.smoothing,
			fov        = _G.AIM.fov,
			showFov    = _G.AIM.showFov,
			prediction = _G.AIM.prediction,
		},
		SILENT = {
			enabled    = _G.SILENT.enabled,
			fov        = _G.SILENT.fov,
			hitchance  = _G.SILENT.hitchance,
		},
		keybind    = currentKeybind.Name,
		panicKey   = panicKey.Name,
		espKey     = espKey.Name,
		invisKey   = invisKey.Name,
		healKey    = healKey.Name,
	}
end

local function saveConfig(name)
	local ok, json = pcall(function()
		return HttpService:JSONEncode(getConfigState())
	end)
	if ok then
		pcall(function() writefile(CONFIG_DIR.."/"..name..".json", json) end)
		return true
	end
	return false
end

local function loadConfig(name)
	local ok, data = pcall(function()
		local raw = readfile(CONFIG_DIR.."/"..name..".json")
		return HttpService:JSONDecode(raw)
	end)
	if not ok or not data then return false end
	if data.ESP then
		for k,v in pairs(data.ESP) do _G.ESP[k] = v end
		recalcESPEnabled()
	end
	if data.AIM then
		for k,v in pairs(data.AIM) do _G.AIM[k] = v end
	end
	if data.SILENT then
		for k,v in pairs(data.SILENT) do _G.SILENT[k] = v end
	end
	pcall(function()
		if data.keybind   then currentKeybind = Enum.KeyCode[data.keybind] or currentKeybind end
		if data.panicKey  then panicKey  = Enum.KeyCode[data.panicKey]  or panicKey  end
		if data.espKey    then espKey    = Enum.KeyCode[data.espKey]    or espKey    end
		if data.invisKey  then invisKey  = Enum.KeyCode[data.invisKey]  or invisKey  end
		if data.healKey   then healKey   = Enum.KeyCode[data.healKey]   or healKey   end
	end)
	return true
end

local function listConfigs()
	local files = {}
	pcall(function()
		local listed = listfiles(CONFIG_DIR)
		if listed then
			for _, f in ipairs(listed) do
				if type(f)=="string" and f:match("%.json$") then
					local name = f:match("([^/\\]+)%.json$")
					if name then table.insert(files, name) end
				end
			end
		end
	end)
	return files
end

-- ════════════════════════════════════════════
--  GLOBAL HOTKEYS
-- ════════════════════════════════════════════
local menuVisible = true

local function doPanic()
	for _, sg in ipairs(playerGui:GetChildren()) do
		if sg.Name:find("TZX") then sg.Enabled=false end
	end
	task.delay(0.5, function()
		for _, sg in ipairs(playerGui:GetChildren()) do
			if sg.Name:find("TZX") then sg.Enabled=true end
		end
	end)
end

UserInputService.InputBegan:Connect(function(inp, gp)
	if gp then return end
	if inp.KeyCode == panicKey  then doPanic() end
	if inp.KeyCode == espKey    then _G.ESP.enabled = not _G.ESP.enabled; refreshAllESP() end
	if inp.KeyCode == invisKey  then
		if invisEnabled then disableInvisible() else enableInvisible() end
	end
	if inp.KeyCode == healKey   then doHeal() end
end)

-- ════════════════════════════════════════════
--  ROOT GUI
-- ════════════════════════════════════════════
local gui = new("ScreenGui", {
	Name           = "TZXUI",
	ResetOnSpawn   = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	IgnoreGuiInset = true,
	DisplayOrder   = 1000000000,
}, playerGui)

-- ════════════════════════════════════════════
--  NAVBAR
-- ════════════════════════════════════════════
local navbar = new("Frame", {
	Size = UDim2.new(0,NAVBAR_W,0,NAVBAR_H),
	Position = UDim2.new(0.5,-NAVBAR_W/2,0,12),
	BackgroundColor3=C.topBar, BorderSizePixel=0, ZIndex=10,
}, gui); corner(navbar,12)
new("UIStroke",{Color=C.divider,Thickness=1.5,ApplyStrokeMode=Enum.ApplyStrokeMode.Border}, navbar)

local pageTitle = new("TextLabel",{
	Size=UDim2.new(0,160,0,22), Position=UDim2.new(0,16,0,8),
	BackgroundTransparency=1, Text="Visuals",
	TextColor3=C.textBright, TextSize=14, Font=Enum.Font.GothamBold,
	TextXAlignment=Enum.TextXAlignment.Left, ZIndex=12,
}, navbar)
local breadcrumb = new("TextLabel",{
	Size=UDim2.new(0,200,0,14), Position=UDim2.new(0,16,0,30),
	BackgroundTransparency=1, Text="Visuals > Esp",
	TextColor3=C.accent, TextSize=10, Font=Enum.Font.Gotham,
	TextXAlignment=Enum.TextXAlignment.Left, ZIndex=12,
}, navbar)

local NAV_PAGES = {
	{file="player.png",  label="Player",  sub="General", url="https://i.imgur.com/HwejTUI.png"},
	{file="visuals.png", label="Visuals", sub="Esp",     url="https://i.imgur.com/di32xk7.png"},
	{file="misc.png",    label="Misc",    sub="General", url="https://i.imgur.com/bf6hpQf.png"},
	{file="exploit.png", label="Exploit", sub="Aimbot",  url="https://i.imgur.com/CDskxjP.png"},
	{file="scripts.png", label="Scripts", sub="Scripts", url="https://i.imgur.com/ZSWIPzL.png"},
	{file="extra.png",   label="Extra",   sub="Settings",url="https://i.imgur.com/S7FqLp2.png"},
}

local NAV_BTN_W  = 46
local navTotalW  = #NAV_PAGES * NAV_BTN_W
local navBtns    = {}
local activeNav  = 2
local fallbackLetters = {"P","V","M","E","S","X"}

for i, nav in ipairs(NAV_PAGES) do
	local isActive = (i==activeNav)
	local xCenter  = -navTotalW/2 + (i-1)*NAV_BTN_W + NAV_BTN_W/2
	local pill = new("Frame",{
		Size=UDim2.new(0,36,0,34), Position=UDim2.new(0.5,xCenter-18,0.5,-17),
		BackgroundColor3=C.accentPill, BackgroundTransparency=isActive and 0 or 1,
		BorderSizePixel=0, ZIndex=11,
	}, navbar); corner(pill,8)
	local btn = new("TextButton",{
		Size=UDim2.new(0,NAV_BTN_W,1,0), Position=UDim2.new(0.5,xCenter-NAV_BTN_W/2,0,0),
		BackgroundTransparency=1, Text="", BorderSizePixel=0, ZIndex=13,
	}, navbar)
	local fallback = new("TextLabel",{
		Size=UDim2.new(1,0,1,0), BackgroundTransparency=1, Text=fallbackLetters[i],
		TextColor3=isActive and C.textBright or C.textDim,
		TextSize=11, Font=Enum.Font.GothamBold, ZIndex=14,
	}, btn)
	local img = new("ImageLabel",{
		Size=UDim2.new(0,20,0,20), Position=UDim2.new(0.5,-10,0.5,-10),
		BackgroundTransparency=1, Image="",
		ImageColor3=isActive and C.textBright or C.textDim, ZIndex=14,
	}, btn)
	navBtns[i] = {btn=btn, img=img, pill=pill, fallback=fallback}
end

task.defer(function()
	for i, nav in ipairs(NAV_PAGES) do
		local path = "TZX/assets/icons/"..nav.file
		pcall(function()
			if not isfile(path) then
				local ok,data = pcall(function() return game:HttpGet(nav.url,true) end)
				if ok and data and #data>100 then writefile(path,data); task.wait() end
			end
		end)
		pcall(function()
			if isfile(path) then
				local url = getcustomasset(path)
				if url and url~="" then
					local nb = navBtns[i]
					if nb then nb.img.Image=url; nb.fallback.Visible=false end
				end
			end
		end)
	end
end)

local avatarFrame = new("Frame",{
	Size=UDim2.new(0,32,0,32), Position=UDim2.new(1,-120,0.5,-16),
	BackgroundColor3=C.accentDim, BorderSizePixel=0, ZIndex=12,
}, navbar); corner(avatarFrame,16)
new("UIStroke",{Color=C.accent,Thickness=1.5,ApplyStrokeMode=Enum.ApplyStrokeMode.Border,Transparency=0.3}, avatarFrame)
local avatarImg = new("ImageLabel",{
	Size=UDim2.new(1,0,1,0), BackgroundTransparency=1,
	Image="rbxthumb://type=AvatarHeadShot&id="..player.UserId.."&w=48&h=48",
	ScaleType=Enum.ScaleType.Crop, ZIndex=13,
}, avatarFrame); corner(avatarImg,16)
new("TextLabel",{
	Size=UDim2.new(0,82,0,18), Position=UDim2.new(1,-84,0.5,-18),
	BackgroundTransparency=1, Text=player.Name,
	TextColor3=C.textBright, TextSize=11, Font=Enum.Font.GothamBold,
	TextXAlignment=Enum.TextXAlignment.Left, ZIndex=12,
}, navbar)
do
	local execName=""
	pcall(function() execName=identifyexecutor() end)
	new("TextLabel",{
		Size=UDim2.new(0,82,0,13), Position=UDim2.new(1,-84,0.5,2),
		BackgroundTransparency=1, Text=execName,
		TextColor3=C.accent, TextSize=13, Font=Enum.Font.GothamBold,
		TextXAlignment=Enum.TextXAlignment.Left, ZIndex=12,
	}, navbar)
end

-- ════════════════════════════════════════════
--  CONTENT WINDOW
-- ════════════════════════════════════════════
local WIN_START_Y = NAVBAR_H + 22

local winFrame = new("Frame",{
	Size=UDim2.new(0,WIN_W,0,WIN_H),
	Position=UDim2.new(0.5,-WIN_W/2,0,WIN_START_Y),
	BackgroundTransparency=1, BorderSizePixel=0, ZIndex=5,
}, gui)

local win = new("CanvasGroup",{
	Size=UDim2.new(1,0,1,0), Position=UDim2.new(0,0,0,0),
	BackgroundColor3=C.bg, GroupTransparency=0, BorderSizePixel=0, ZIndex=5,
}, winFrame); corner(win,10)
new("UIStroke",{Color=C.divider,Thickness=1.5,ApplyStrokeMode=Enum.ApplyStrokeMode.Border}, win)

local contentArea = new("Frame",{
	Size=UDim2.new(1,0,1,0), BackgroundTransparency=1, ClipsDescendants=false, ZIndex=2,
}, win)

do
	local dragging, dragStart, startPos
	winFrame.InputBegan:Connect(function(inp)
		if inp.UserInputType==Enum.UserInputType.MouseButton1 then
			dragging=true; dragStart=inp.Position; startPos=winFrame.Position
		end
	end)
	winFrame.InputChanged:Connect(function(inp)
		if dragging and inp.UserInputType==Enum.UserInputType.MouseMovement then
			local d = inp.Position-dragStart
			winFrame.Position = UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,
				startPos.Y.Scale,startPos.Y.Offset+d.Y)
		end
	end)
	winFrame.InputEnded:Connect(function(inp)
		if inp.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end
	end)
end

local function updateBreadcrumb(pageName, subName)
	pageTitle.Text=pageName; breadcrumb.Text=pageName.." > "..subName
end

-- ════════════════════════════════════════════
--  WIDGETS
-- ════════════════════════════════════════════
local function makeToggle(parent, yPos, label, onChange)
	local state = false
	local row = new("Frame",{Size=UDim2.new(1,0,0,30),Position=UDim2.new(0,0,0,yPos),BackgroundTransparency=1,ZIndex=4}, parent)
	new("TextLabel",{Size=UDim2.new(1,-52,1,0),Position=UDim2.new(0,10,0,0),BackgroundTransparency=1,Text=label,TextColor3=C.textMid,TextSize=11,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=5}, row)
	local track = new("Frame",{Size=UDim2.new(0,28,0,15),Position=UDim2.new(1,-36,0.5,-7.5),BackgroundColor3=C.toggleOff,BorderSizePixel=0,ZIndex=5}, row); corner(track,8)
	local knob  = new("Frame",{Size=UDim2.new(0,11,0,11),Position=UDim2.new(0,3,0.5,-5.5),BackgroundColor3=C.toggleKnob,BorderSizePixel=0,ZIndex=6}, track); corner(knob,6)
	local function setState(val)
		state=val
		tw(track,{BackgroundColor3=state and C.toggleOn or C.toggleOff},.15)
		tw(knob, {Position=state and UDim2.new(0,14,0.5,-5.5) or UDim2.new(0,3,0.5,-5.5)},.15)
		if onChange then onChange(state) end
	end
	local clickBtn = new("TextButton",{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text="",ZIndex=7}, row)
	clickBtn.MouseEnter:Connect(function() row.BackgroundTransparency=0; row.BackgroundColor3=C.rowHover end)
	clickBtn.MouseLeave:Connect(function() row.BackgroundTransparency=1 end)
	clickBtn.MouseButton1Click:Connect(function() setState(not state) end)
	return {row=row, set=setState, get=function() return state end}
end

local function makeToggleWithBind(parent, yPos, label, defaultKey, onChange, onKeyChange)
	local state = false
	local row = new("Frame",{Size=UDim2.new(1,0,0,30),Position=UDim2.new(0,0,0,yPos),BackgroundTransparency=1,ZIndex=4}, parent)
	new("TextLabel",{Size=UDim2.new(1,-90,1,0),Position=UDim2.new(0,10,0,0),BackgroundTransparency=1,Text=label,TextColor3=C.textMid,TextSize=11,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=5}, row)
	local pill = new("TextButton",{
		Size=UDim2.new(0,46,0,18), Position=UDim2.new(1,-82,0.5,-9),
		BackgroundColor3=C.accentDim, Text=defaultKey and defaultKey.Name or "None",
		TextColor3=C.accent, TextSize=8, Font=Enum.Font.GothamBold,
		BorderSizePixel=0, ZIndex=6,
	}, row); corner(pill,4)
	new("UIStroke",{Color=C.accent,Thickness=1,ApplyStrokeMode=Enum.ApplyStrokeMode.Border,Transparency=0.5}, pill)
	local track = new("Frame",{Size=UDim2.new(0,28,0,15),Position=UDim2.new(1,-32,0.5,-7.5),BackgroundColor3=C.toggleOff,BorderSizePixel=0,ZIndex=5}, row); corner(track,8)
	local knob  = new("Frame",{Size=UDim2.new(0,11,0,11),Position=UDim2.new(0,3,0.5,-5.5),BackgroundColor3=C.toggleKnob,BorderSizePixel=0,ZIndex=6}, track); corner(knob,6)
	local function setState(val)
		state=val
		tw(track,{BackgroundColor3=state and C.toggleOn or C.toggleOff},.15)
		tw(knob, {Position=state and UDim2.new(0,14,0.5,-5.5) or UDim2.new(0,3,0.5,-5.5)},.15)
		if onChange then onChange(state) end
	end
	local clickBtn = new("TextButton",{Size=UDim2.new(1,-86,1,0),BackgroundTransparency=1,Text="",ZIndex=7}, row)
	clickBtn.MouseEnter:Connect(function() row.BackgroundTransparency=0; row.BackgroundColor3=C.rowHover end)
	clickBtn.MouseLeave:Connect(function() row.BackgroundTransparency=1 end)
	clickBtn.MouseButton1Click:Connect(function() setState(not state) end)
	local trackBtn = new("TextButton",{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text="",ZIndex=8}, track)
	trackBtn.MouseButton1Click:Connect(function() setState(not state) end)

	local listening = false
	local ignoreKeys={[Enum.KeyCode.LeftShift]=true,[Enum.KeyCode.RightShift]=true,[Enum.KeyCode.LeftControl]=true,[Enum.KeyCode.RightControl]=true,[Enum.KeyCode.LeftAlt]=true,[Enum.KeyCode.RightAlt]=true}
	pill.MouseButton1Click:Connect(function()
		if listening then return end
		listening=true; pill.Text="..."; tw(pill,{BackgroundColor3=C.accent},.1)
		local conn
		conn = UserInputService.InputBegan:Connect(function(inp)
			if inp.UserInputType~=Enum.UserInputType.Keyboard then return end
			if ignoreKeys[inp.KeyCode] then return end
			conn:Disconnect(); listening=false
			pill.Text = inp.KeyCode.Name
			tw(pill,{BackgroundColor3=C.accentDim},.1)
			if onKeyChange then onKeyChange(inp.KeyCode) end
		end)
	end)
	return {row=row, set=setState, get=function() return state end}
end

local function makeSlider(parent, yPos, label, minV, maxV, default, onChange)
	local val = default or minV
	local row = new("Frame",{Size=UDim2.new(1,0,0,46),Position=UDim2.new(0,0,0,yPos),BackgroundTransparency=1,ZIndex=4}, parent)
	new("TextLabel",{Size=UDim2.new(1,-52,0,20),Position=UDim2.new(0,10,0,2),BackgroundTransparency=1,Text=label,TextColor3=C.textMid,TextSize=11,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=5}, row)
	local valLabel = new("TextLabel",{Size=UDim2.new(0,44,0,20),Position=UDim2.new(1,-48,0,2),BackgroundTransparency=1,Text=tostring(val),TextColor3=C.textDim,TextSize=10,Font=Enum.Font.GothamMedium,TextXAlignment=Enum.TextXAlignment.Right,ZIndex=5}, row)
	local trackBg  = new("Frame",{Size=UDim2.new(1,-20,0,4),Position=UDim2.new(0,10,0,30),BackgroundColor3=C.sliderBg,BorderSizePixel=0,ZIndex=5}, row); corner(trackBg,2)
	local pct  = (val-minV)/(maxV-minV)
	local fill = new("Frame",{Size=UDim2.new(pct,0,1,0),BackgroundColor3=C.sliderFill,BorderSizePixel=0,ZIndex=6}, trackBg); corner(fill,2)
	local thumb= new("Frame",{Size=UDim2.new(0,12,0,12),Position=UDim2.new(pct,-6,0.5,-6),BackgroundColor3=C.textBright,BorderSizePixel=0,ZIndex=7}, trackBg); corner(thumb,6)
	new("UIStroke",{Color=C.accent,Thickness=1.5,ApplyStrokeMode=Enum.ApplyStrokeMode.Border,Transparency=0.3}, thumb)
	local dragging=false
	local dragBtn = new("TextButton",{Size=UDim2.new(1,0,2,0),Position=UDim2.new(0,0,0.5,-6),BackgroundTransparency=1,Text="",ZIndex=8}, trackBg)
	local function setValue(p)
		p=math.clamp(p,0,1); fill.Size=UDim2.new(p,0,1,0); thumb.Position=UDim2.new(p,-6,0.5,-6)
		val=math.floor(minV+p*(maxV-minV)); valLabel.Text=tostring(val)
		if onChange then onChange(val) end
	end
	local function fromMouse()
		local m=UserInputService:GetMouseLocation()
		local a=trackBg.AbsolutePosition; local s=trackBg.AbsoluteSize
		setValue((m.X-a.X)/s.X)
	end
	dragBtn.MouseButton1Down:Connect(function() dragging=true; fromMouse() end)
	dragBtn.MouseButton1Up:Connect(function()   dragging=false end)
	dragBtn.MouseLeave:Connect(function()       dragging=false end)
	dragBtn.MouseMoved:Connect(function() if dragging then fromMouse() end end)
	return {row=row, set=function(n) setValue((n-minV)/(maxV-minV)) end, get=function() return val end}
end

local function makeSectionHeader(parent, yPos, label)
	new("TextLabel",{Size=UDim2.new(1,-16,0,26),Position=UDim2.new(0,8,0,yPos),BackgroundTransparency=1,Text=label,TextColor3=C.textMid,TextSize=11,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Center,ZIndex=5}, parent)
	new("Frame",    {Size=UDim2.new(0,32,0,1.5),Position=UDim2.new(0.5,-16,0,yPos+24),BackgroundColor3=C.accent,BorderSizePixel=0,ZIndex=5}, parent)
end

-- ════════════════════════════════════════════
--  GRID
-- ════════════════════════════════════════════
local function makeGrid(parent, sectionsData)
	local PAD=6; local colW=CELL_W
	local function sectionH(sec)
		local h=36
		for _, item in ipairs(sec.items) do h=h+(item.type=="slider" and 46 or 30) end
		return h+PAD
	end
	local cols={{},{}}; local colH={0,0}
	for _, sec in ipairs(sectionsData) do
		local ci=(colH[1]<=colH[2]) and 1 or 2
		table.insert(cols[ci],{sec=sec,y=colH[ci]}); colH[ci]=colH[ci]+sectionH(sec)+PAD
	end
	local totalH=math.max(colH[1],colH[2])+PAD
	local scroll = new("ScrollingFrame",{
		Size=UDim2.new(1,0,1,0), BackgroundTransparency=1, CanvasSize=UDim2.new(0,0,0,totalH),
		AutomaticCanvasSize=Enum.AutomaticSize.Y, ScrollBarThickness=4,
		ScrollBarImageColor3=C.accent, ScrollBarImageTransparency=0.4, BorderSizePixel=0,
		ScrollingDirection=Enum.ScrollingDirection.Y, ClipsDescendants=true,
		ElasticBehavior=Enum.ElasticBehavior.Never, ZIndex=3,
	}, parent)
	local colXOffsets={PAD, PAD+colW+PAD}
	for ci, col in ipairs(cols) do
		for _, entry in ipairs(col) do
			local sec=entry.sec; local cellH=sectionH(sec)-PAD
			local cell = new("Frame",{Size=UDim2.new(0,colW,0,cellH),Position=UDim2.new(0,colXOffsets[ci],0,entry.y+PAD),BackgroundColor3=C.section,BorderSizePixel=0,ZIndex=3}, scroll); corner(cell,6)
			makeSectionHeader(cell,4,sec.title)
			local itemY=36
			for _, item in ipairs(sec.items) do
				if item.type=="toggle" then
					if item.bindKey then
						makeToggleWithBind(cell, itemY, item.label, item.bindKey, item.onChange, item.onKeyChange)
					else
						makeToggle(cell, itemY, item.label, item.onChange)
					end
					itemY=itemY+30
				elseif item.type=="slider" then
					makeSlider(cell, itemY, item.label, item.min or 0, item.max or 100, item.default or 0, item.onChange)
					itemY=itemY+46
				end
			end
		end
	end
	return scroll
end

-- ════════════════════════════════════════════
--  SUB-TAB BAR
-- ════════════════════════════════════════════
local function makeSubTabBar(parent, tabs, onSwitch)
	local bar = new("Frame",{Size=UDim2.new(1,0,0,36),BackgroundColor3=C.panel,BorderSizePixel=0,ZIndex=4}, parent)
	new("Frame",{Size=UDim2.new(1,0,0,1),Position=UDim2.new(0,0,1,-1),BackgroundColor3=C.divider,BorderSizePixel=0,ZIndex=5}, bar)
	local subPages={}; local btnRefs={}; local ulineRefs={}; local activeSub=1
	for ti, tabName in ipairs(tabs) do
		local subPage = new("Frame",{Size=UDim2.new(1,0,1,-36),Position=UDim2.new(0,0,0,36),BackgroundTransparency=1,ClipsDescendants=true,Visible=(ti==1),ZIndex=3}, parent)
		subPages[ti]=subPage
		local tabW=1/#tabs
		local btn  = new("TextButton",{Size=UDim2.new(tabW,0,1,0),Position=UDim2.new(tabW*(ti-1),0,0,0),BackgroundTransparency=1,Text=tabName,TextColor3=(ti==1) and C.textBright or C.textDim,TextSize=12,Font=Enum.Font.GothamSemibold,BorderSizePixel=0,ZIndex=5}, bar)
		local uline= new("Frame",     {Size=UDim2.new(0,36,0,2),Position=UDim2.new(tabW*(ti-1)+tabW/2,-18,1,-2),BackgroundColor3=C.accent,BackgroundTransparency=(ti==1) and 0 or 1,BorderSizePixel=0,ZIndex=6}, bar); corner(uline,1)
		btnRefs[ti]=btn; ulineRefs[ti]=uline
	end
	for ti=1,#tabs do
		btnRefs[ti].MouseButton1Click:Connect(function()
			if activeSub==ti then return end
			subPages[activeSub].Visible=false; btnRefs[activeSub].TextColor3=C.textDim
			tw(ulineRefs[activeSub],{BackgroundTransparency=1},.15)
			subPages[ti].Visible=true; btnRefs[ti].TextColor3=C.textBright
			tw(ulineRefs[ti],{BackgroundTransparency=0},.15)
			activeSub=ti; if onSwitch then onSwitch(tabs[ti]) end
		end)
	end
	return subPages
end

-- ════════════════════════════════════════════
--  PAGE SYSTEM
-- ════════════════════════════════════════════
local pages      = {}
local activePage = activeNav

local function makePage(isVisible)
	return new("Frame",{
		Size=UDim2.new(1,0,1,0), Position=UDim2.new(isVisible and 0 or 1,0,0,0),
		BackgroundTransparency=1, ZIndex=2,
	}, contentArea)
end

local function switchPage(idx)
	if idx==activePage then return end
	local dir = idx>activePage and 1 or -1
	tw(pages[activePage],{Position=UDim2.new(-dir,0,0,0)},.2)
	pages[idx].Position=UDim2.new(dir,0,0,0)
	tw(pages[idx],{Position=UDim2.new(0,0,0,0)},.2)
	activePage=idx
	for i,nb in ipairs(navBtns) do
		local col=(i==idx) and C.textBright or C.textDim
		tw(nb.img,     {ImageColor3=col},.15)
		tw(nb.pill,    {BackgroundTransparency=i==idx and 0 or 1},.15)
		tw(nb.fallback,{TextColor3=col},.15)
	end
	updateBreadcrumb(NAV_PAGES[idx].label, NAV_PAGES[idx].sub)
end

for i, nb in ipairs(navBtns) do
	nb.btn.MouseButton1Click:Connect(function() switchPage(i) end)
end

local function subSwitcher(pageLabel)
	return function(subName) updateBreadcrumb(pageLabel,subName) end
end

-- ════════════════════════════════════════════
--  PAGES
-- ════════════════════════════════════════════

-- ── PAGE 1: PLAYER ──────────────────────────
pages[1] = makePage(false)
do
	local s = makeSubTabBar(pages[1],{"General","Speed","Teleport"},subSwitcher("Player"))
	makeGrid(s[1],{
		{title="Movement", items={
			{type="toggle", label="Fly",           onChange=function(v) if v then enableFly()       else disableFly()       end end},
			{type="toggle", label="Noclip",        onChange=function(v) if v then enableNoclip()    else disableNoclip()    end end},
			{type="toggle", label="Infinite Jump", onChange=function(v) if v then enableInfJump()   else disableInfJump()   end end},
			{type="toggle", label="Anti-Void",     onChange=function(v) if v then enableAntiVoid()  else disableAntiVoid()  end end},
		}},
		{title="Protection", items={
			{type="toggle", label="God Mode",    onChange=function(v) if v then enableGodMode()   else disableGodMode()   end end},
			{type="toggle", label="Anti-AFK",    onChange=function(v) if v then enableAntiAFK()   else disableAntiAFK()   end end},
			{type="toggle", label="Invisible",   onChange=function(v) if v then enableInvisible() else disableInvisible() end end},
			{type="toggle", label="Chat Bypass", onChange=function(v) end},
		}},
		{title="Quick Actions", items={
			{type="toggle", label="Heal (max HP)", onChange=function(v) if v then doHeal() end end},
		}},
	})
	makeGrid(s[2],{
		{title="Speed", items={
			{type="slider", label="Walk Speed", min=16, max=300, default=16,
				onChange=function(v)
					local hum=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
					if hum then hum.WalkSpeed=v end
				end},
			{type="slider", label="Jump Power", min=50, max=300, default=50,
				onChange=function(v)
					local hum=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
					if hum then if hum.UseJumpPower then hum.JumpPower=v else hum.JumpHeight=v/5 end end
				end},
			{type="slider", label="Fly Speed", min=10, max=300, default=50,
				onChange=function(v) _G.flySpeed=v end},
		}},
		{title="Presets", items={
			{type="toggle", label="Sprint Mode",
				onChange=function(v)
					local hum=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
					if hum then hum.WalkSpeed=v and 60 or 16 end
				end},
		}},
	})
	do
		local sp=s[3]
		local cell=new("Frame",{Size=UDim2.new(0,CELL_W,0,130),Position=UDim2.new(0,6,0,6),BackgroundColor3=C.section,BorderSizePixel=0,ZIndex=3}, sp); corner(cell,6)
		makeSectionHeader(cell,4,"Teleport")
		local tpBtn=new("TextButton",{Size=UDim2.new(1,-20,0,32),Position=UDim2.new(0,10,0,38),BackgroundColor3=C.toggleOn,Text="Open Player List",TextColor3=Color3.new(1,1,1),TextSize=11,Font=Enum.Font.GothamBold,BorderSizePixel=0,ZIndex=4}, cell); corner(tpBtn,6)
		tpBtn.MouseButton1Click:Connect(function() refreshTPList(); tpFrame.Visible=true end)
		makeToggle(cell,80,"Safe TP (offset +3Y)",function(v) end)
	end
end

-- ── PAGE 2: VISUALS ─────────────────────────
pages[2] = makePage(true)
do
	local s = makeSubTabBar(pages[2],{"Esp","Radar","World"},subSwitcher("Visuals"))

	makeGrid(s[1],{
		{title="Boxes", items={
			{type="toggle", label="Boxes",
				bindKey=espKey,
				onChange=function(v) _G.ESP.showBoxes=v; recalcESPEnabled() end,
				onKeyChange=function(k) espKey=k end},
			{type="toggle", label="Thick Outline",
				onChange=function(v)
					-- Update UIStroke thickness on all existing ESP boxes
					for _,d in pairs(espData) do
						if d.boxStroke then
							d.boxStroke.Thickness = v and 3 or 2
						end
					end
				end},
			{type="toggle", label="Corners", onChange=function(v) end},
		}},
		{title="Overlay", items={
			{type="toggle", label="Outline (Body)", onChange=function(v) _G.ESP.showOutline=v;  recalcESPEnabled() end},
			{type="toggle", label="Chams",          onChange=function(v) _G.ESP.showChams=v;    recalcESPEnabled() end},
			{type="toggle", label="Skeleton",       onChange=function(v) _G.ESP.showSkeleton=v; recalcESPEnabled() end},
		}},
		{title="Info", items={
			{type="toggle", label="Username",   onChange=function(v) _G.ESP.showName=v;     recalcESPEnabled() end},
			{type="toggle", label="Distance",   onChange=function(v) _G.ESP.showDistance=v; recalcESPEnabled() end},
			{type="toggle", label="Weapon",     onChange=function(v) _G.ESP.showWeapon=v;   recalcESPEnabled() end},
			{type="toggle", label="Health Bar", onChange=function(v) _G.ESP.showHealth=v;   recalcESPEnabled() end},
			{type="toggle", label="Armor Bar",  onChange=function(v) _G.ESP.showArmor=v;    recalcESPEnabled() end},
		}},
		{title="Lines", items={
			{type="toggle", label="Lines",          onChange=function(v) _G.ESP.showLines=v; recalcESPEnabled() end},
			{type="toggle", label="Origin: Bottom", onChange=function(v) if v then _G.ESP.lineOrigin="bottom" end end},
			{type="toggle", label="Origin: Middle", onChange=function(v) if v then _G.ESP.lineOrigin="middle" end end},
			{type="toggle", label="Origin: Top",    onChange=function(v) if v then _G.ESP.lineOrigin="top"    end end},
		}},
		{title="Filters", items={
			{type="slider", label="Max Distance", min=0, max=1000, default=741, onChange=function(v) _G.ESP.maxDist=v end},
			{type="toggle", label="Draw Dead",    onChange=function(v) _G.ESP.drawDead=v end},
			{type="toggle", label="Team Check",   onChange=function(v) _G.ESP.teamCheck=v end},
		}},
	})

	makeGrid(s[2],{
		{title="Radar", items={
			{type="toggle", label="Show Radar",
				onChange=function(v) _G.RADAR.enabled=v; radarFrame.Visible=v
					if v then startRadar() else stopRadar() end end},
			{type="toggle", label="Show Names", onChange=function(v) _G.RADAR.showNames=v end},
			{type="slider", label="Range", min=50, max=1000, default=200, onChange=function(v) _G.RADAR.range=v end},
		}},
		{title="Style", items={
			{type="toggle", label="Show Self", onChange=function(v) selfDot.Visible=v end},
		}},
	})
	makeGrid(s[3],{
		{title="World", items={
			{type="toggle", label="Fullbright",
				onChange=function(v)
					local Lighting=game:GetService("Lighting")
					if v then Lighting.Brightness=10; Lighting.ClockTime=14
					else Lighting.Brightness=1; Lighting.ClockTime=14 end
				end},
			{type="toggle", label="Remove Fog",
				onChange=function(v)
					local Lighting=game:GetService("Lighting")
					if v then Lighting.FogEnd=1e6 else Lighting.FogEnd=100000 end
				end},
			{type="toggle", label="No Sky",
				onChange=function(v)
					local sky=game:GetService("Lighting"):FindFirstChildOfClass("Sky")
					if v and sky then sky.Parent=nil end
				end},
		}},
	})
end

-- ── PAGE 3: MISC ────────────────────────────
pages[3] = makePage(false)
do
	local s = makeSubTabBar(pages[3],{"General","Trolling","Players"},subSwitcher("Misc"))
	makeGrid(s[1],{
		{title="Network", items={
			{type="toggle", label="Ping Spoof",  onChange=function(v) end},
			{type="toggle", label="Auto-Rejoin", onChange=function(v) end},
		}},
		{title="Utility", items={
			{type="toggle", label="Auto-Collect", onChange=function(v) end},
			{type="toggle", label="Credit Spoof", onChange=function(v) end},
		}},
	})
	makeGrid(s[2],{
		{title="Troll", items={
			{type="toggle", label="Spin Bot",   onChange=function(v) if v then enableSpinBot() else disableSpinBot() end end},
			{type="toggle", label="Lag Others", onChange=function(v) end},
		}},
		{title="Tools", items={
			{type="toggle", label="Part Deleter", onChange=function(v) end},
			{type="toggle", label="Nuke Map",     onChange=function(v) end},
		}},
	})
	do
		local pp=s[3]
		local cell=new("Frame",{Size=UDim2.new(0,CELL_W,0,100),Position=UDim2.new(0,6,0,6),BackgroundColor3=C.section,BorderSizePixel=0,ZIndex=3}, pp); corner(cell,6)
		makeSectionHeader(cell,4,"Player List")
		local plBtn=new("TextButton",{Size=UDim2.new(1,-20,0,32),Position=UDim2.new(0,10,0,38),BackgroundColor3=C.toggleOn,Text="Open Player List",TextColor3=Color3.new(1,1,1),TextSize=11,Font=Enum.Font.GothamBold,BorderSizePixel=0,ZIndex=4}, cell); corner(plBtn,6)
		plBtn.MouseButton1Click:Connect(function() refreshPlayerList(); plFrame.Visible=true end)
	end
end

-- ── PAGE 4: EXPLOIT ─────────────────────────
pages[4] = makePage(false)
do
	local s = makeSubTabBar(pages[4],{"Aimbot","Combat","Weapon"},subSwitcher("Exploit"))

	local aimPage=s[1]
	local aimCell=new("Frame",{Size=UDim2.new(0,CELL_W,0,190),Position=UDim2.new(0,6,0,6),BackgroundColor3=C.section,BorderSizePixel=0,ZIndex=3}, aimPage); corner(aimCell,6)
	makeSectionHeader(aimCell,4,"Aim Lock")
	makeToggle(aimCell,36,"Aim Lock",function(v)
		_G.AIM.enabled=v
		if v then startAimlock(); bindAimHotkey(_G.AIM.hotkey)
		else aimActive=false; stopAimlock(); if fovCircle then fovCircle.Visible=false end end
	end)
	new("TextLabel",{Size=UDim2.new(1,-10,0,16),Position=UDim2.new(0,10,0,72),BackgroundTransparency=1,Text="Hold key to aim:",TextColor3=C.textMid,TextSize=10,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=5}, aimCell)
	local aimKeyBtn=new("TextButton",{Size=UDim2.new(1,-20,0,28),Position=UDim2.new(0,10,0,90),BackgroundColor3=C.toggleOff,Text=_G.AIM.hotkey.Name,TextColor3=C.textBright,TextSize=12,Font=Enum.Font.GothamBold,BorderSizePixel=0,ZIndex=5}, aimCell); corner(aimKeyBtn,6)
	new("UIStroke",{Color=C.accent,Thickness=1.5,ApplyStrokeMode=Enum.ApplyStrokeMode.Border,Transparency=0.5}, aimKeyBtn)
	local aimKeyStatus=new("TextLabel",{Size=UDim2.new(1,-20,0,14),Position=UDim2.new(0,10,0,122),BackgroundTransparency=1,Text="Click to change hotkey",TextColor3=C.textDim,TextSize=9,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true,ZIndex=5}, aimCell)
	makeToggle(aimCell,140,"Team Check",function(v)
		_G.ESP.teamCheck=v
	end)
	local listeningAim=false
	local ignoreAimKeys={[Enum.KeyCode.LeftShift]=true,[Enum.KeyCode.RightShift]=true,[Enum.KeyCode.LeftControl]=true,[Enum.KeyCode.RightControl]=true,[Enum.KeyCode.LeftAlt]=true,[Enum.KeyCode.RightAlt]=true}
	aimKeyBtn.MouseButton1Click:Connect(function()
		if listeningAim then return end
		listeningAim=true; aimKeyBtn.Text="Press a key..."
		tw(aimKeyBtn,{BackgroundColor3=C.accentDim},.1)
		aimKeyStatus.Text="Listening..."; aimKeyStatus.TextColor3=C.textMid
		local conn
		conn=UserInputService.InputBegan:Connect(function(inp)
			if inp.UserInputType~=Enum.UserInputType.Keyboard then return end
			if ignoreAimKeys[inp.KeyCode] then return end
			conn:Disconnect(); listeningAim=false
			_G.AIM.hotkey=inp.KeyCode; aimKeyBtn.Text=inp.KeyCode.Name
			tw(aimKeyBtn,{BackgroundColor3=C.toggleOff},.1)
			aimKeyStatus.Text="Hotkey: "..inp.KeyCode.Name; aimKeyStatus.TextColor3=C.accent
			if _G.AIM.enabled then bindAimHotkey(_G.AIM.hotkey) end
		end)
	end)

	local aimSetCell=new("Frame",{Size=UDim2.new(0,CELL_W,0,210),Position=UDim2.new(0,CELL_W+12,0,6),BackgroundColor3=C.section,BorderSizePixel=0,ZIndex=3}, aimPage); corner(aimSetCell,6)
	makeSectionHeader(aimSetCell,4,"Settings")
	makeSlider(aimSetCell,36, "FOV Radius",  10,500,150,function(v) _G.AIM.fov=v end)
	makeSlider(aimSetCell,82, "Smoothness",  1,20,8,    function(v) _G.AIM.smoothing=v end)
	makeSlider(aimSetCell,128,"Prediction",  0,10,0,    function(v) _G.AIM.prediction=v end)
	makeToggle(aimSetCell,174,"Show FOV",function(v)
		_G.AIM.showFov=v
		if fovCircle then fovCircle.Visible = v and _G.AIM.enabled end
	end)

	makeGrid(s[2],{
		{title="Combat", items={
			{type="toggle", label="Anti-Knockback", onChange=function(v) end},
			{type="toggle", label="Hitbox Expand",
				onChange=function(v) if v then enableHitboxExpand() else disableHitboxExpand() end end},
			{type="toggle", label="Silent Aim",  onChange=function(v) _G.SILENT.enabled=v end},
			{type="toggle", label="Triggerbot",  onChange=function(v) _G.TRIGGER.enabled=v end},
		}},
		{title="Silent Aim", items={
			{type="slider", label="SA FOV",       min=10,max=300,default=100, onChange=function(v) _G.SILENT.fov=v end},
			{type="slider", label="Hit Chance %", min=1, max=100,default=80,  onChange=function(v) _G.SILENT.hitchance=v end},
		}},
		{title="Hitbox", items={
			{type="slider", label="Hitbox Size", min=2,max=30,default=8,
				onChange=function(v)
					_G.hitboxSize=v
					if _G.hitboxEnabled then
						for _,t in ipairs(Players:GetPlayers()) do
							if t~=player then
								local root=t.Character and t.Character:FindFirstChild("HumanoidRootPart")
								if root then root.Size=Vector3.new(v,v,v) end
							end
						end
					end
				end},
		}},
	})
	makeGrid(s[3],{
		{title="Gun Mods", items={
			{type="toggle", label="Rapid Fire",     onChange=function(v) end},
			{type="toggle", label="No Spread",      onChange=function(v) end},
			{type="toggle", label="No Recoil",      onChange=function(v) end},
			{type="toggle", label="No Reload",      onChange=function(v) if v then enableNoReload()   else disableNoReload()   end end},
			{type="toggle", label="Freeze Ammo",    onChange=function(v) if v then enableFreezeAmmo() else disableFreezeAmmo() end end},
		}},
		{title="Vehicle", items={
			{type="toggle", label="Speed Boost", onChange=function(v) end},
			{type="toggle", label="No Flip",     onChange=function(v) end},
		}},
	})
end

-- ── PAGE 5: SCRIPTS ─────────────────────────
pages[5] = makePage(false)
do
	local header=new("Frame",{Size=UDim2.new(1,0,0,42),BackgroundTransparency=1,BorderSizePixel=0,ZIndex=4}, pages[5])
	new("TextLabel",{Size=UDim2.new(1,-100,1,0),Position=UDim2.new(0,12,0,0),BackgroundTransparency=1,Text="Scripts in  TZX/scripts/",TextColor3=C.textDim,TextSize=10,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,ZIndex=5}, header)
	local refreshBtn=new("TextButton",{Size=UDim2.new(0,82,0,26),Position=UDim2.new(1,-88,0.5,-13),BackgroundColor3=C.accentDim,Text="\xe2\x86\xba  Refresh",TextColor3=C.accent,TextSize=11,Font=Enum.Font.GothamBold,BorderSizePixel=0,ZIndex=5}, header); corner(refreshBtn,6)
	new("UIStroke",{Color=C.accent,Thickness=1,ApplyStrokeMode=Enum.ApplyStrokeMode.Border,Transparency=0.5}, refreshBtn)
	local emptyLabel=new("TextLabel",{Size=UDim2.new(1,0,1,-42),Position=UDim2.new(0,0,0,42),BackgroundTransparency=1,Text="No .lua files found.\n\nPlace scripts in  TZX/scripts/\nthen click Refresh.",TextColor3=C.textDim,TextSize=11,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Center,TextYAlignment=Enum.TextYAlignment.Center,TextWrapped=true,ZIndex=4}, pages[5])
	local scriptScroll=new("ScrollingFrame",{Size=UDim2.new(1,0,1,-42),Position=UDim2.new(0,0,0,42),BackgroundTransparency=1,CanvasSize=UDim2.new(0,0,0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=4,ScrollBarImageColor3=C.accent,ScrollBarImageTransparency=0.4,BorderSizePixel=0,ScrollingDirection=Enum.ScrollingDirection.Y,ClipsDescendants=true,ElasticBehavior=Enum.ElasticBehavior.Never,Visible=false,ZIndex=4}, pages[5])
	local scriptRows={}
	local function buildScriptList()
		for _,r in ipairs(scriptRows) do pcall(function() r:Destroy() end) end; scriptRows={}
		local files={}
		pcall(function()
			local listed=listfiles("TZX/scripts")
			if listed then for _,f in ipairs(listed) do
				if type(f)=="string" and f:match("%.[Ll][Uu][Aa]$") then table.insert(files,f) end
			end end
		end)
		if #files==0 then emptyLabel.Visible=true; scriptScroll.Visible=false; return end
		emptyLabel.Visible=false; scriptScroll.Visible=true
		local yOff=6
		for _,filepath in ipairs(files) do
			local fname=filepath:match("([^/\\]+)$") or filepath
			local row=new("Frame",{Size=UDim2.new(1,-12,0,42),Position=UDim2.new(0,6,0,yOff),BackgroundColor3=C.scriptBtn,BorderSizePixel=0,ZIndex=5}, scriptScroll); corner(row,6)
			table.insert(scriptRows,row)
			new("Frame",    {Size=UDim2.new(0,3,0,20),Position=UDim2.new(0,8,0.5,-10),BackgroundColor3=C.accent,BorderSizePixel=0,ZIndex=6}, row)
			new("TextLabel",{Size=UDim2.new(1,-80,1,0),Position=UDim2.new(0,18,0,0),BackgroundTransparency=1,Text=fname,TextColor3=C.textBright,TextSize=11,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,ZIndex=6}, row)
			local runBtn=new("TextButton",{Size=UDim2.new(0,54,0,26),Position=UDim2.new(1,-60,0.5,-13),BackgroundColor3=C.toggleOn,Text="Run",TextColor3=Color3.new(1,1,1),TextSize=11,Font=Enum.Font.GothamBold,BorderSizePixel=0,ZIndex=6}, row); corner(runBtn,5)
			local fp=filepath
			runBtn.MouseButton1Click:Connect(function()
				pcall(function()
					local code=readfile(fp); local fn,err=loadstring(code)
					if fn then
						task.spawn(fn)
						tw(runBtn,{BackgroundColor3=Color3.fromRGB(40,190,80)},.1)
						task.delay(0.8,function() tw(runBtn,{BackgroundColor3=C.toggleOn},.3) end)
					else
						warn("[TZX] "..fname..": "..(err or "?"))
						tw(runBtn,{BackgroundColor3=Color3.fromRGB(200,40,40)},.1)
						task.delay(0.8,function() tw(runBtn,{BackgroundColor3=C.toggleOn},.3) end)
					end
				end)
			end)
			yOff=yOff+50
		end
	end
	refreshBtn.MouseButton1Click:Connect(buildScriptList)
	task.defer(buildScriptList)
end

-- ── PAGE 6: EXTRA ───────────────────────────
pages[6] = makePage(false)
do
	local s = makeSubTabBar(pages[6],{"Settings","Binds","Colors","Configs","About"},subSwitcher("Extra"))
	local ACTION_NAME="TZXToggle"
	local PAD=6; local cW=math.floor((WIN_W-PAD*3)/2); local cH=math.floor((WIN_H-36-PAD*3)/2)
	local sp=s[1]

	local kbCell=new("Frame",{Size=UDim2.new(0,cW,0,cH),Position=UDim2.new(0,PAD,0,PAD),BackgroundColor3=C.section,BorderSizePixel=0,ZIndex=3}, sp); corner(kbCell,6)
	makeSectionHeader(kbCell,4,"Keybind")
	new("TextLabel",{Size=UDim2.new(1,-20,0,18),Position=UDim2.new(0,10,0,36),BackgroundTransparency=1,Text="Menu toggle key:",TextColor3=C.textMid,TextSize=10,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=5}, kbCell)
	local kbBtn=new("TextButton",{Size=UDim2.new(1,-20,0,28),Position=UDim2.new(0,10,0,56),BackgroundColor3=C.toggleOff,Text=currentKeybind.Name,TextColor3=C.textBright,TextSize=12,Font=Enum.Font.GothamBold,BorderSizePixel=0,ZIndex=5}, kbCell); corner(kbBtn,6)
	new("UIStroke",{Color=C.accent,Thickness=1.5,ApplyStrokeMode=Enum.ApplyStrokeMode.Border,Transparency=0.5}, kbBtn)
	local kbStatus=new("TextLabel",{Size=UDim2.new(1,-20,0,16),Position=UDim2.new(0,10,0,88),BackgroundTransparency=1,Text="Click button then press a key",TextColor3=C.textDim,TextSize=9,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true,ZIndex=5}, kbCell)
	local listeningForKey=false
	local ignoreKeys={[Enum.KeyCode.LeftShift]=true,[Enum.KeyCode.RightShift]=true,[Enum.KeyCode.LeftControl]=true,[Enum.KeyCode.RightControl]=true,[Enum.KeyCode.LeftAlt]=true,[Enum.KeyCode.RightAlt]=true,[Enum.KeyCode.LeftSuper]=true,[Enum.KeyCode.RightSuper]=true}

	local function applyKeybind(kc)
		currentKeybind=kc; kbBtn.Text=kc.Name; tw(kbBtn,{BackgroundColor3=C.toggleOff},.1)
		ContextActionService:UnbindAction(ACTION_NAME)
		ContextActionService:BindActionAtPriority(ACTION_NAME,function(_,state)
			if state==Enum.UserInputState.Begin then
				if menuVisible then hideMenu() else showMenu() end
			end
			return Enum.ContextActionResult.Sink
		end,false,2001,kc)
		saveKeybind(kc); kbStatus.Text="Saved: "..kc.Name; kbStatus.TextColor3=C.accent
	end
	kbBtn.MouseButton1Click:Connect(function()
		if listeningForKey then return end
		listeningForKey=true; kbBtn.Text="Press any key..."
		tw(kbBtn,{BackgroundColor3=C.accentDim},.1)
		kbStatus.Text="Listening..."; kbStatus.TextColor3=C.textMid
		local conn
		conn=UserInputService.InputBegan:Connect(function(inp)
			if inp.UserInputType~=Enum.UserInputType.Keyboard then return end
			if ignoreKeys[inp.KeyCode] then return end
			conn:Disconnect(); listeningForKey=false; applyKeybind(inp.KeyCode)
		end)
	end)

	local ifCell=new("Frame",{Size=UDim2.new(0,cW,0,cH),Position=UDim2.new(0,PAD*2+cW,0,PAD),BackgroundColor3=C.section,BorderSizePixel=0,ZIndex=3}, sp); corner(ifCell,6)
	makeSectionHeader(ifCell,4,"Interface")
	local fpsPill=new("Frame",{Size=UDim2.new(0,72,0,22),Position=UDim2.new(1,-80,1,-30),BackgroundColor3=Color3.fromRGB(18,18,22),BorderSizePixel=0,Visible=false,ZIndex=10}, espGui); corner(fpsPill,6)
	new("UIStroke",{Color=Color3.fromRGB(60,60,75),Thickness=1,ApplyStrokeMode=Enum.ApplyStrokeMode.Border}, fpsPill)
	fpsLabel=new("TextLabel",{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text="-- FPS",TextColor3=Color3.fromRGB(100,230,100),TextSize=11,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Center,Visible=true,ZIndex=11}, fpsPill)

	-- FOV circle — always-on loop updates position every frame
	fovCircle = new("Frame", {
		Size     = UDim2.new(0, _G.AIM.fov*2, 0, _G.AIM.fov*2),
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible  = false,
		ZIndex   = 8,
	}, espGui)
	corner(fovCircle, 999)
	new("UIStroke", {
		Color           = Color3.fromRGB(180, 80, 255),
		Thickness       = 1.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Transparency    = 0.25,
	}, fovCircle)

	-- ── FOV circle always follows mouse, independent of aimActive ──
	RunService.RenderStepped:Connect(function()
		if not fovCircle then return end
		local r     = _G.AIM.fov
		local mouse = UserInputService:GetMouseLocation()
		fovCircle.Size     = UDim2.new(0, r*2, 0, r*2)
		fovCircle.Position = UDim2.new(0, mouse.X - r, 0, mouse.Y - r)
		fovCircle.Visible  = _G.AIM.showFov and _G.AIM.enabled
	end)

	makeToggle(ifCell,36,"Show FPS",function(v)
		fpsPill.Visible=v; if v then startFPS() else stopFPS() end
	end)
	makeToggle(ifCell,66,"Streamproof",function(v)
		local doOrder = v and -999999 or 1000000000
		for _, sg in ipairs(playerGui:GetChildren()) do
			if sg:IsA("ScreenGui") and sg.Name:find("TZX") then
				pcall(function() sg.DisplayOrder = doOrder end)
			end
		end
		pcall(function()
			for _, sg in ipairs(playerGui:GetChildren()) do
				if sg:IsA("ScreenGui") and sg.Name:find("TZX") then
					sg.ScreenInsets = v and Enum.ScreenInsets.None or Enum.ScreenInsets.DeviceSafeInsets
				end
			end
		end)
	end)

	local dzCell=new("Frame",{Size=UDim2.new(0,cW,0,cH),Position=UDim2.new(0,PAD,0,PAD*2+cH),BackgroundColor3=C.section,BorderSizePixel=0,ZIndex=3}, sp); corner(dzCell,6)
	makeSectionHeader(dzCell,4,"Danger Zone")
	makeToggle(dzCell,36,"Unload TZX",function(v)
		if v then pcall(function() ContextActionService:UnbindAction(ACTION_NAME) end); gui:Destroy() end
	end)

	-- ── Binds tab ──────────────────────────
	do
		local bp=s[2]
		local bindsCell=new("Frame",{Size=UDim2.new(0,CELL_W,0,280),Position=UDim2.new(0,6,0,6),BackgroundColor3=C.section,BorderSizePixel=0,ZIndex=3}, bp); corner(bindsCell,6)
		makeSectionHeader(bindsCell,4,"Bind System")
		local bindDefs={
			{label="Panic Button",  key=panicKey, setter=function(k) panicKey=k  end},
			{label="ESP Toggle",    key=espKey,   setter=function(k) espKey=k    end},
			{label="Invisible",     key=invisKey, setter=function(k) invisKey=k  end},
			{label="Heal",          key=healKey,  setter=function(k) healKey=k   end},
		}
		for i, bd in ipairs(bindDefs) do
			local y=36+(i-1)*56
			new("TextLabel",{Size=UDim2.new(1,-12,0,14),Position=UDim2.new(0,10,0,y),BackgroundTransparency=1,Text=bd.label,TextColor3=C.textMid,TextSize=10,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=5}, bindsCell)
			local kBtn=new("TextButton",{Size=UDim2.new(1,-20,0,28),Position=UDim2.new(0,10,0,y+16),BackgroundColor3=C.toggleOff,Text=bd.key.Name,TextColor3=C.textBright,TextSize=11,Font=Enum.Font.GothamBold,BorderSizePixel=0,ZIndex=5}, bindsCell); corner(kBtn,5)
			new("UIStroke",{Color=C.accent,Thickness=1,ApplyStrokeMode=Enum.ApplyStrokeMode.Border,Transparency=0.6}, kBtn)
			local listening=false; local setter=bd.setter
			kBtn.MouseButton1Click:Connect(function()
				if listening then return end
				listening=true; kBtn.Text="..."; tw(kBtn,{BackgroundColor3=C.accentDim},.1)
				local conn
				conn=UserInputService.InputBegan:Connect(function(inp)
					if inp.UserInputType~=Enum.UserInputType.Keyboard then return end
					if ignoreKeys[inp.KeyCode] then return end
					conn:Disconnect(); listening=false
					setter(inp.KeyCode); kBtn.Text=inp.KeyCode.Name
					tw(kBtn,{BackgroundColor3=C.toggleOff},.1)
				end)
			end)
		end
	end

	-- ── Colors tab ─────────────────────────
	do
		local cp=s[3]
		local colCell=new("Frame",{Size=UDim2.new(0,CELL_W,0,160),Position=UDim2.new(0,6,0,6),BackgroundColor3=C.section,BorderSizePixel=0,ZIndex=3}, cp); corner(colCell,6)
		makeSectionHeader(colCell,4,"Accent Color")
		local presetY=38
		new("TextLabel",{Size=UDim2.new(1,-12,0,14),Position=UDim2.new(0,10,0,presetY),BackgroundTransparency=1,Text="Choose preset:",TextColor3=C.textMid,TextSize=10,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=5}, colCell)
		local swatchW=28; local swatchGap=6
		for idx, col in ipairs(ACCENT_PRESETS) do
			local sx=10+(idx-1)*(swatchW+swatchGap)
			local sw=new("TextButton",{Size=UDim2.new(0,swatchW,0,swatchW),Position=UDim2.new(0,sx,0,presetY+18),BackgroundColor3=col,BorderSizePixel=0,Text="",ZIndex=5}, colCell); corner(sw,6)
			new("UIStroke",{Color=Color3.new(1,1,1),Thickness=1,ApplyStrokeMode=Enum.ApplyStrokeMode.Border,Transparency=0.7}, sw)
			sw.MouseButton1Click:Connect(function()
				applyAccent(col); breadcrumb.TextColor3=col
			end)
		end
		new("TextLabel",{Size=UDim2.new(1,-12,0,14),Position=UDim2.new(0,10,0,presetY+54),BackgroundTransparency=1,Text="(Full live recolor requires re-inject)",TextColor3=C.textDim,TextSize=8,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=5}, colCell)
	end

	-- ── CONFIGS TAB ────────────────────────
	do
		local cfgPage = s[4]
		local saveCell=new("Frame",{Size=UDim2.new(0,CELL_W,0,110),Position=UDim2.new(0,6,0,6),BackgroundColor3=C.section,BorderSizePixel=0,ZIndex=3}, cfgPage); corner(saveCell,6)
		makeSectionHeader(saveCell,4,"Save Config")
		local nameBox=new("TextBox",{
			Size=UDim2.new(1,-20,0,26), Position=UDim2.new(0,10,0,38),
			BackgroundColor3=C.toggleOff, Text="default", TextColor3=C.textBright,
			TextSize=11, Font=Enum.Font.Gotham, PlaceholderText="config name",
			PlaceholderColor3=C.textDim, BorderSizePixel=0, ClearTextOnFocus=false,
			ZIndex=5,
		}, saveCell); corner(nameBox,5)
		local saveBtn=new("TextButton",{Size=UDim2.new(1,-20,0,26),Position=UDim2.new(0,10,0,68),BackgroundColor3=C.toggleOn,Text="Save",TextColor3=Color3.new(1,1,1),TextSize=11,Font=Enum.Font.GothamBold,BorderSizePixel=0,ZIndex=5}, saveCell); corner(saveBtn,5)
		saveBtn.MouseButton1Click:Connect(function()
			local name = nameBox.Text:gsub("[^%w_%-]","")
			if name=="" then name="default" end
			local ok=saveConfig(name)
			tw(saveBtn,{BackgroundColor3=ok and Color3.fromRGB(40,190,80) or Color3.fromRGB(200,40,40)},.1)
			task.delay(0.8,function() tw(saveBtn,{BackgroundColor3=C.toggleOn},.3) end)
			if ok then saveBtn.Text="Saved!"; task.delay(1,function() saveBtn.Text="Save" end) end
		end)

		local loadCell=new("Frame",{Size=UDim2.new(0,CELL_W,0,300),Position=UDim2.new(0,CELL_W+12,0,6),BackgroundColor3=C.section,BorderSizePixel=0,ZIndex=3}, cfgPage); corner(loadCell,6)
		makeSectionHeader(loadCell,4,"Load Config")
		local cfgRefreshBtn=new("TextButton",{Size=UDim2.new(0,60,0,20),Position=UDim2.new(1,-68,0,8),BackgroundColor3=C.accentDim,Text="\xe2\x86\xba Scan",TextColor3=C.accent,TextSize=9,Font=Enum.Font.GothamBold,BorderSizePixel=0,ZIndex=5}, loadCell); corner(cfgRefreshBtn,5)
		new("UIStroke",{Color=C.accent,Thickness=1,ApplyStrokeMode=Enum.ApplyStrokeMode.Border,Transparency=0.5}, cfgRefreshBtn)
		local cfgScroll=new("ScrollingFrame",{
			Size=UDim2.new(1,-12,1,-44), Position=UDim2.new(0,6,0,40),
			BackgroundTransparency=1, CanvasSize=UDim2.new(0,0,0,0),
			AutomaticCanvasSize=Enum.AutomaticSize.Y, ScrollBarThickness=3,
			ScrollBarImageColor3=C.accent, BorderSizePixel=0, ZIndex=4,
		}, loadCell)
		new("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,4)}, cfgScroll)
		local cfgEmptyLabel=new("TextLabel",{Size=UDim2.new(1,0,0,40),BackgroundTransparency=1,Text="No configs found.\nSave one first.",TextColor3=C.textDim,TextSize=10,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Center,TextYAlignment=Enum.TextYAlignment.Center,TextWrapped=true,ZIndex=5}, cfgScroll)
		local cfgRows={}

		local function refreshConfigList()
			for _,r in ipairs(cfgRows) do r:Destroy() end; cfgRows={}
			local configs=listConfigs()
			cfgEmptyLabel.Visible=(#configs==0)
			for _, cfgName in ipairs(configs) do
				local row=new("Frame",{Size=UDim2.new(1,-4,0,34),BackgroundColor3=C.scriptBtn,BorderSizePixel=0,ZIndex=5}, cfgScroll); corner(row,5)
				table.insert(cfgRows,row)
				new("TextLabel",{Size=UDim2.new(1,-80,1,0),Position=UDim2.new(0,8,0,0),BackgroundTransparency=1,Text=cfgName,TextColor3=C.textBright,TextSize=10,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,ZIndex=6}, row)
				local loadBtn=new("TextButton",{Size=UDim2.new(0,44,0,22),Position=UDim2.new(1,-76,0.5,-11),BackgroundColor3=C.toggleOn,Text="Load",TextColor3=Color3.new(1,1,1),TextSize=9,Font=Enum.Font.GothamBold,BorderSizePixel=0,ZIndex=6}, row); corner(loadBtn,4)
				local delBtn=new("TextButton",{Size=UDim2.new(0,24,0,22),Position=UDim2.new(1,-28,0.5,-11),BackgroundColor3=Color3.fromRGB(80,20,20),Text="✕",TextColor3=Color3.fromRGB(220,80,80),TextSize=11,Font=Enum.Font.GothamBold,BorderSizePixel=0,ZIndex=6}, row); corner(delBtn,4)
				local cn=cfgName
				loadBtn.MouseButton1Click:Connect(function()
					local ok=loadConfig(cn)
					tw(loadBtn,{BackgroundColor3=ok and Color3.fromRGB(40,190,80) or Color3.fromRGB(200,40,40)},.1)
					task.delay(0.8,function() tw(loadBtn,{BackgroundColor3=C.toggleOn},.3) end)
				end)
				delBtn.MouseButton1Click:Connect(function()
					pcall(function() delfile(CONFIG_DIR.."/"..cn..".json") end)
					task.delay(0.1,refreshConfigList)
				end)
			end
		end

		cfgRefreshBtn.MouseButton1Click:Connect(refreshConfigList)
		task.defer(refreshConfigList)
	end

	-- ── About tab ──────────────────────────
	new("TextLabel",{
		Size=UDim2.new(1,0,1,-36), Position=UDim2.new(0,0,0,36), BackgroundTransparency=1,
		Text="TZX v2.3\n\nKeybind  →  TZX/keybind.txt\nConfigs  →  TZX/configs/*.json\nScripts  →  TZX/scripts/*.lua\nIcons    →  TZX/assets/icons/\n\nPanic: End  |  ESP: F1\nInvis: F2   |  Heal: F3\n\nChanges: team check, invis fix,\naimbot prediction, streamproof,\nconfig system, UI over CoreGui",
		TextColor3=C.textDim, TextSize=11, Font=Enum.Font.Gotham,
		TextXAlignment=Enum.TextXAlignment.Center, TextYAlignment=Enum.TextYAlignment.Center,
		TextWrapped=true, ZIndex=4,
	}, s[5])
end

-- ════════════════════════════════════════════
--  SHOW / HIDE
-- ════════════════════════════════════════════
local function showMenu()
	menuVisible=true; _G.TZXVisible=true
	navbar.Visible=true; winFrame.Visible=true
	win.GroupTransparency=0; navbar.BackgroundTransparency=0
end
local function hideMenu()
	menuVisible=false; _G.TZXVisible=false
	win.GroupTransparency=1; navbar.BackgroundTransparency=1
	winFrame.Visible=false; navbar.Visible=false
end

_G.TZXShow    = showMenu
_G.TZXHide    = hideMenu
_G.TZXVisible = true

ContextActionService:BindActionAtPriority("TZXToggle",function(_,state)
	if state==Enum.UserInputState.Begin then
		if menuVisible then hideMenu() else showMenu() end
	end
	return Enum.ContextActionResult.Sink
end, false, 2001, currentKeybind)

-- Boot ESP immediately since boxes are on by default
recalcESPEnabled()

updateBreadcrumb(NAV_PAGES[activeNav].label, NAV_PAGES[activeNav].sub)
print("[TZX] v1 Ready · Keybind = "..currentKeybind.Name)
