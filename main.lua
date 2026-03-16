--[[
    OG's Tuff script Roblox Script: Aimbot, Silent Aim, ESP & Chams
    Created for educational purposes.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local Hitboxes = {"Head", "HumanoidRootPart", "Torso", "UpperTorso", "LowerTorso"}
local HitboxIndex = 1

local ChamsColors = {
    {fill = Color3.fromRGB(255, 50, 50),  outline = Color3.fromRGB(255,255,255)},
    {fill = Color3.fromRGB(50, 200, 255), outline = Color3.fromRGB(0, 100, 200)},
    {fill = Color3.fromRGB(50, 255, 100), outline = Color3.fromRGB(255,255,255)},
    {fill = Color3.fromRGB(255, 150, 0),  outline = Color3.fromRGB(255,255,0)},
    {fill = Color3.fromRGB(180, 0, 255),  outline = Color3.fromRGB(255,100,255)},
    {fill = Color3.fromRGB(255, 255, 255),outline = Color3.fromRGB(0, 0, 0)},
}
local ChamsColorIndex = 1

local Config = {
    Aimbot = {
        Enabled = false,
        Key = Enum.UserInputType.MouseButton2,
        KeyName = "RMB",
        Mode = "Hold",
        Radius = 150,
        Smoothness = 5,
        ShowFOV = true,
        TargetPart = Hitboxes[HitboxIndex],
        Prediction = 0.12,
        AimOffset = Vector3.new(0, 0, 0)
    },
    SilentAim = { Enabled = false },
    ESP       = { Enabled = false },
    TeamCheck = true,
    Chams     = {
        Enabled = false,
        FillColor    = ChamsColors[ChamsColorIndex].fill,
        OutlineColor = ChamsColors[ChamsColorIndex].outline,
    },
    Fly           = { Enabled = false, Speed = 60, Mode = "Normal" },
    Noclip        = { Enabled = false },
    TPAura        = { Enabled = false, Range = 20, Interval = 0.15 },
    InfiniteJump  = { Enabled = false },
    InfiniteAmmo  = { Enabled = false },
    RapidFire     = { Enabled = false },
    MagicBullet   = { Enabled = false },
    EnemyTPAura   = { Enabled = false, Interval = 0.15 },
    KnifeAura     = { Enabled = false, Range = 15 },
}

-- FOV Circle
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 2
FOVCircle.NumSides = 64
FOVCircle.Color = Color3.fromRGB(255, 255, 255)
FOVCircle.Filled = false
FOVCircle.Transparency = 0.5

-- Aimbot key state
local isAimKeyDown = false
local aimbotToggled = false

-- ════════════════════════════════════════
--  AIMBOT CORE
-- ════════════════════════════════════════
local _cachedTarget  = nil
local _cachedPlayer  = nil
local _stickyTimer   = 0
local STICKY_DURATION = 0.3

-- Smoothed velocity per player (reduces jitter from AssemblyLinearVelocity noise)
local _velSmooth = {}  -- [Player] = Vector3

local function GetSmoothedVelocity(player, root, dt)
    local raw = root.AssemblyLinearVelocity
    local prev = _velSmooth[player] or raw
    -- Low-pass filter: alpha 0.35 = responsive but not jittery
    local smoothed = prev:Lerp(raw, math.min(1, dt * 18))
    _velSmooth[player] = smoothed
    return smoothed
end

-- Predict target position: velocity + ping compensation
local function PredictPosition(aimPart, player, dt)
    local ping = LocalPlayer:GetNetworkPing()
    local totalTime = Config.Aimbot.Prediction + ping

    local vel = Vector3.zero
    local root = aimPart.Parent and aimPart.Parent:FindFirstChild("HumanoidRootPart")
    if root then
        vel = GetSmoothedVelocity(player, root, dt)
        -- Suppress vertical velocity when grounded (no over-prediction on jumps)
        local hum = aimPart.Parent:FindFirstChild("Humanoid")
        if hum and hum.FloorMaterial ~= Enum.Material.Air then
            vel = Vector3.new(vel.X, 0, vel.Z)
        end
    end

    return aimPart.Position + (vel * totalTime) + Config.Aimbot.AimOffset
end

-- Compute closest player using predicted screen position
local function ComputeClosestPlayer(dt)
    local bestPart    = nil
    local bestPlayer  = nil
    local closestDist = math.huge
    local mouseLoc    = UserInputService:GetMouseLocation()
    local camPos      = Camera.CFrame.Position

    for _, Player in pairs(Players:GetPlayers()) do
        if Player == LocalPlayer or not Player.Character then continue end
        local hum = Player.Character:FindFirstChild("Humanoid")
        if not hum or hum.Health <= 0 then continue end
        if Config.TeamCheck and Player.Team == LocalPlayer.Team then continue end

        local aimPart = Player.Character:FindFirstChild("HeadHB")
            or Player.Character:FindFirstChild(Config.Aimbot.TargetPart)
            or Player.Character:FindFirstChild("HumanoidRootPart")
        if not aimPart then continue end

        -- Use predicted position for target selection (more accurate lock-on)
        local predictedPos = PredictPosition(aimPart, Player, dt)
        local screenPt, onScreen = Camera:WorldToViewportPoint(predictedPos)
        if not onScreen then continue end

        local screenDist = (Vector2.new(screenPt.X, screenPt.Y) - mouseLoc).Magnitude
        if screenDist > Config.Aimbot.Radius then continue end

        -- Weighted: screen dist is primary, world dist is tiebreaker
        local worldDist = (predictedPos - camPos).Magnitude
        local weighted  = screenDist + (worldDist * 0.006)

        if weighted < closestDist then
            bestPart    = aimPart
            bestPlayer  = Player
            closestDist = weighted
        end
    end

    if bestPart then
        -- New target found: reset sticky
        if bestPlayer ~= _cachedPlayer then
            _stickyTimer = STICKY_DURATION
        end
        _cachedTarget = bestPart
        _cachedPlayer = bestPlayer
        _stickyTimer  = STICKY_DURATION
    else
        -- No target in FOV: count down sticky timer
        _stickyTimer = _stickyTimer - dt
        if _stickyTimer <= 0 then
            _cachedTarget = nil
            _cachedPlayer = nil
            _velSmooth[_cachedPlayer] = nil
        else
            -- Validate sticky target is still alive
            if _cachedPlayer and _cachedPlayer.Character then
                local h = _cachedPlayer.Character:FindFirstChild("Humanoid")
                if not h or h.Health <= 0 then
                    _cachedTarget = nil
                    _cachedPlayer = nil
                end
            end
        end
    end
end

-- ════════════════════════════════════════
--  SILENT AIM (BulletModule hook)
-- ════════════════════════════════════════
local function SA_IsVisible(part)
    local char = LocalPlayer.Character
    if not char then return false end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {char, Camera}
    local result = workspace:Raycast(Camera.CFrame.Position, part.Position - Camera.CFrame.Position, params)
    return result == nil or result.Instance:IsDescendantOf(part.Parent)
end

local function SA_GetTarget()
    local closest = nil
    local shortestDist = Config.Aimbot.Radius
    local mousePos = UserInputService:GetMouseLocation()
    for _, p in ipairs(Players:GetPlayers()) do
        if p == LocalPlayer or not p.Character then continue end
        local hum = p.Character:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then continue end
        if Config.TeamCheck and p.Team == LocalPlayer.Team then continue end
        local part = p.Character:FindFirstChild(Config.Aimbot.TargetPart)
            or p.Character:FindFirstChild("Head")
        if not part then continue end
        local pos, onScreen = Camera:WorldToViewportPoint(part.Position)
        if not onScreen then continue end
        local dist = (Vector2.new(pos.X, pos.Y) - mousePos).Magnitude
        if dist < shortestDist then
            shortestDist = dist
            closest = p.Character
        end
    end
    return closest
end

pcall(function()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local BulletModule = ReplicatedStorage:WaitForChild("Components", 5)
        and ReplicatedStorage.Components:WaitForChild("Weapon", 5)
        and ReplicatedStorage.Components.Weapon:WaitForChild("Classes", 5)
        and ReplicatedStorage.Components.Weapon.Classes:WaitForChild("Bullet", 5)
    if not BulletModule then return end

    local Bullet = require(BulletModule)
    local realMath = math

    getfenv(Bullet._performRaycast).math = setmetatable({}, {
        __index = function(_, index)
            if index == "min" and Config.SilentAim.Enabled then
                local target = SA_GetTarget()
                if target then
                    if math.random(1, 100) <= 100 then
                        local part = target:FindFirstChild(Config.Aimbot.TargetPart)
                            or target:FindFirstChild("Head")
                        if part then
                            debug.setstack(2, 5, Ray.new(
                                Camera.CFrame.Position,
                                (part.Position - Camera.CFrame.Position).Unit
                            ))
                            return function() return 0 end
                        end
                    end
                end
            end
            return realMath[index]
        end
    })
end)

-- ════════════════════════════════════════
--  MAGIC BULLET
-- ════════════════════════════════════════
pcall(function()
    local mt = getrawmetatable(game)
    local oldNamecall = mt.__namecall
    setreadonly(mt, false)

    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if Config.MagicBullet.Enabled and method == "FireServer" then
            local target = _cachedTarget
            if target then
                local args = {...}
                local modified = false
                for i, v in ipairs(args) do
                    if typeof(v) == "CFrame" then
                        args[i] = CFrame.new(target.Position); modified = true
                    elseif typeof(v) == "Vector3" and v.Magnitude > 1 then
                        args[i] = target.Position; modified = true
                    elseif typeof(v) == "Instance" and v:IsA("BasePart") then
                        args[i] = target; modified = true
                    end
                end
                if modified then return oldNamecall(self, table.unpack(args)) end
            end
        end
        return oldNamecall(self, ...)
    end)

    setreadonly(mt, true)
end)

-- ════════════════════════════════════════
--  ESP  (event-driven, not per-frame)
-- ════════════════════════════════════════
local function ApplyESP(Player)
    if Player == LocalPlayer or not Player.Character then return end
    local Char = Player.Character
    local Highlight = Char:FindFirstChild("ESPHighlight")
    if Config.ESP.Enabled then
        if not Highlight then
            Highlight = Instance.new("Highlight")
            Highlight.Name = "ESPHighlight"
            Highlight.Parent = Char
        end
        Highlight.FillTransparency = 1
        Highlight.OutlineTransparency = 0
        Highlight.OutlineColor = (Player.Team ~= LocalPlayer.Team)
            and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(50, 255, 100)
    else
        if Highlight then Highlight:Destroy() end
    end
end

local function ApplyChams(Player)
    if Player == LocalPlayer or not Player.Character then return end
    local Char = Player.Character
    local Chams = Char:FindFirstChild("ChamsHighlight")
    if Config.Chams.Enabled then
        if not Chams then
            Chams = Instance.new("Highlight")
            Chams.Name = "ChamsHighlight"
            Chams.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            Chams.Parent = Char
        end
        Chams.FillColor = Config.Chams.FillColor
        Chams.OutlineColor = Config.Chams.OutlineColor
        Chams.FillTransparency = 0.35
        Chams.OutlineTransparency = 0
    else
        if Chams then Chams:Destroy() end
    end
end

local function RefreshAllVisuals()
    for _, Player in pairs(Players:GetPlayers()) do
        ApplyESP(Player)
        ApplyChams(Player)
    end
end

Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function()
        task.wait(0.1)
        ApplyESP(p)
        ApplyChams(p)
    end)
end)
for _, p in pairs(Players:GetPlayers()) do
    p.CharacterAdded:Connect(function()
        task.wait(0.1)
        ApplyESP(p)
        ApplyChams(p)
    end)
end

-- ════════════════════════════════════════
--  MAIN RENDER LOOP (aimbot + FOV)
-- ════════════════════════════════════════
RunService.RenderStepped:Connect(function(dt)
    -- 1. Refresh target cache (includes sticky aim logic)
    ComputeClosestPlayer(dt)

    -- 2. FOV circle
    FOVCircle.Visible  = Config.Aimbot.Enabled and Config.Aimbot.ShowFOV
    FOVCircle.Radius   = Config.Aimbot.Radius
    FOVCircle.Position = UserInputService:GetMouseLocation()

    -- 3. mousemoverel aimbot
    local aimbotActive = (Config.Aimbot.Mode == "Hold") and isAimKeyDown or aimbotToggled
    if Config.Aimbot.Enabled and aimbotActive and _cachedTarget and _cachedPlayer and mousemoverel then
        local predictedPos = PredictPosition(_cachedTarget, _cachedPlayer, dt)
        local screenPos, onScreen = Camera:WorldToViewportPoint(predictedPos)
        if onScreen then
            local mouseLoc = UserInputService:GetMouseLocation()
            local dx = screenPos.X - mouseLoc.X
            local dy = screenPos.Y - mouseLoc.Y

            -- Exponential smooth, frame-rate independent via dt
            -- smooth=0 → instant, smooth=10 → very slow
            local smooth = Config.Aimbot.Smoothness
            local factor = smooth <= 0 and 1 or (1 - math.exp(-dt * (11 - smooth) * 6))

            -- Dead zone: skip tiny corrections to avoid micro-jitter
            local dist = math.sqrt(dx*dx + dy*dy)
            if dist > 0.5 then
                mousemoverel(dx * factor, dy * factor)
            end
        end
    end
end)

-- ════════════════════════════════════════
--  FLY
-- ════════════════════════════════════════
RunService.RenderStepped:Connect(function()
    local Char = LocalPlayer.Character
    if not Char then return end
    local Root = Char:FindFirstChild("HumanoidRootPart")
    local hum  = Char:FindFirstChild("Humanoid")
    if not Root or not hum then return end

    local bodyVel  = Root:FindFirstChild("FlyBodyVel")
    local bodyGyro = Root:FindFirstChild("FlyBodyGyro")

    if Config.Fly.Enabled then
        if not bodyVel then
            bodyVel = Instance.new("BodyVelocity")
            bodyVel.Name = "FlyBodyVel"
            bodyVel.MaxForce = Vector3.new(1e5, 1e5, 1e5)
            bodyVel.Parent = Root
        end
        if not bodyGyro then
            bodyGyro = Instance.new("BodyGyro")
            bodyGyro.Name = "FlyBodyGyro"
            bodyGyro.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
            bodyGyro.P = 1e4
            bodyGyro.Parent = Root
        end
        hum.PlatformStand = true
        local dir = Vector3.zero
        local cf  = Camera.CFrame
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cf.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cf.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cf.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cf.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.new(0,1,0) end
        local targetVel = dir.Magnitude > 0 and dir.Unit * Config.Fly.Speed or Vector3.zero
        if Config.Fly.Mode == "Slide" then
            bodyVel.Velocity = bodyVel.Velocity:Lerp(targetVel, 0.1)
        else
            bodyVel.Velocity = targetVel
        end
        bodyGyro.CFrame = cf
    else
        if bodyVel  then bodyVel:Destroy() end
        if bodyGyro then bodyGyro:Destroy() end
        if hum.PlatformStand then hum.PlatformStand = false end
    end
end)

-- ════════════════════════════════════════
--  NOCLIP
-- ════════════════════════════════════════
local noclipParts = {}
LocalPlayer.CharacterAdded:Connect(function(char)
    noclipParts = {}
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then noclipParts[#noclipParts+1] = p end
    end
    char.DescendantAdded:Connect(function(p)
        if p:IsA("BasePart") then noclipParts[#noclipParts+1] = p end
    end)
end)
RunService.Stepped:Connect(function()
    if not Config.Noclip.Enabled then return end
    for _, part in ipairs(noclipParts) do
        if part and part.Parent then part.CanCollide = false end
    end
end)

-- ════════════════════════════════════════
--  TP AURA
-- ════════════════════════════════════════
local lastTP = 0
RunService.Heartbeat:Connect(function()
    if not Config.TPAura.Enabled then return end
    if (tick() - lastTP) < Config.TPAura.Interval then return end
    lastTP = tick()
    local Char = LocalPlayer.Character
    if not Char then return end
    local Root = Char:FindFirstChild("HumanoidRootPart")
    if not Root then return end
    local closestDist = math.huge
    local closestRoot = nil
    for _, Player in pairs(Players:GetPlayers()) do
        if Player == LocalPlayer or not Player.Character then continue end
        local enemyRoot = Player.Character:FindFirstChild("HumanoidRootPart")
        local hum = Player.Character:FindFirstChild("Humanoid")
        if not enemyRoot or not hum or hum.Health <= 0 then continue end
        local dist = (enemyRoot.Position - Root.Position).Magnitude
        if dist < closestDist then closestDist = dist; closestRoot = enemyRoot end
    end
    if closestRoot then Root.CFrame = closestRoot.CFrame * CFrame.new(0, 0, -2.5) end
end)

-- ════════════════════════════════════════
--  ENEMY TP AURA
-- ════════════════════════════════════════
local lastEnemyTP = 0
RunService.Heartbeat:Connect(function()
    if not Config.EnemyTPAura.Enabled then return end
    if (tick() - lastEnemyTP) < Config.EnemyTPAura.Interval then return end
    lastEnemyTP = tick()
    local Char = LocalPlayer.Character
    if not Char then return end
    local Root = Char:FindFirstChild("HumanoidRootPart")
    if not Root then return end
    for _, Player in pairs(Players:GetPlayers()) do
        if Player == LocalPlayer or not Player.Character then continue end
        local enemyRoot = Player.Character:FindFirstChild("HumanoidRootPart")
        local hum = Player.Character:FindFirstChild("Humanoid")
        if not enemyRoot or not hum or hum.Health <= 0 then continue end
        if Config.TeamCheck and Player.Team == LocalPlayer.Team then continue end
        pcall(function()
            enemyRoot.CFrame = Root.CFrame * CFrame.new(0, 0, -2)
            enemyRoot.AssemblyLinearVelocity = Vector3.zero
        end)
    end
end)

-- ════════════════════════════════════════
--  KNIFE AURA
-- ════════════════════════════════════════
RunService.Heartbeat:Connect(function()
    if not Config.KnifeAura.Enabled then return end
    local Char = LocalPlayer.Character
    if not Char then return end
    local Root = Char:FindFirstChild("HumanoidRootPart")
    if not Root then return end
    for _, Player in pairs(Players:GetPlayers()) do
        if Player == LocalPlayer or not Player.Character then continue end
        local enemyRoot = Player.Character:FindFirstChild("HumanoidRootPart")
        local hum = Player.Character:FindFirstChild("Humanoid")
        if not enemyRoot or not hum or hum.Health <= 0 then continue end
        if Config.TeamCheck and Player.Team == LocalPlayer.Team then continue end
        if (enemyRoot.Position - Root.Position).Magnitude <= Config.KnifeAura.Range then
            local tool = Char:FindFirstChildWhichIsA("Tool")
            if tool then pcall(function() tool:Activate() end) end
            break
        end
    end
end)

-- ════════════════════════════════════════
--  INFINITE JUMP
-- ════════════════════════════════════════
UserInputService.JumpRequest:Connect(function()
    if not Config.InfiniteJump.Enabled then return end
    local Char = LocalPlayer.Character
    if not Char then return end
    local hum = Char:FindFirstChild("Humanoid")
    if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
end)

-- ════════════════════════════════════════
--  INFINITE AMMO + RAPID FIRE
-- ════════════════════════════════════════
local lastGCPatch = 0
local function GCWeaponPatch()
    if typeof(getgc) ~= "function" then return end
    for _, v in pairs(getgc(true)) do
        if type(v) ~= "table" then continue end
        local isGun = rawget(v,"Ammo") or rawget(v,"ammo") or rawget(v,"Mag") or rawget(v,"mag")
            or rawget(v,"Bullets") or rawget(v,"bullets") or rawget(v,"FireRate") or rawget(v,"fireRate")
            or rawget(v,"Delay") or rawget(v,"Clip") or rawget(v,"clip") or rawget(v,"MaxAmmo") or rawget(v,"maxAmmo")
        if not isGun then continue end
        if Config.InfiniteAmmo.Enabled then
            pcall(function()
                for _, key in ipairs({"Ammo","ammo","Mag","mag","Bullets","bullets","Clip","clip","MaxAmmo","maxAmmo","CurrentAmmo","currentAmmo"}) do
                    if rawget(v, key) and type(v[key]) == "number" then rawset(v, key, 999) end
                end
            end)
        end
        if Config.RapidFire.Enabled then
            pcall(function()
                for _, key in ipairs({"FireRate","fireRate","Delay","Cooldown"}) do
                    if rawget(v, key) and type(v[key]) == "number" then rawset(v, key, 0.01) end
                end
            end)
        end
    end
end

local ammoKeys    = {"ammo","mag","clip","bullet","round","cartridge"}
local rateKeys    = {"firerate","delay","cooldown","debounce"}

local function matchesKeys(name, keys)
    local n = string.lower(name)
    for _, k in ipairs(keys) do if n:find(k) then return true end end
    return false
end

RunService.Heartbeat:Connect(function()
    if not (Config.InfiniteAmmo.Enabled or Config.RapidFire.Enabled) then return end
    if tick() - lastGCPatch > 2 then
        lastGCPatch = tick()
        task.spawn(GCWeaponPatch)
    end
    local Char = LocalPlayer.Character
    if not Char then return end
    local tools = {}
    local eq = Char:FindFirstChildWhichIsA("Tool")
    if eq then tools[1] = eq end
    for _, t in pairs(LocalPlayer.Backpack:GetChildren()) do
        if t:IsA("Tool") then tools[#tools+1] = t end
    end
    for _, tool in pairs(tools) do
        for _, v in ipairs(tool:GetDescendants()) do
            if Config.InfiniteAmmo.Enabled and (v:IsA("IntValue") or v:IsA("NumberValue")) and matchesKeys(v.Name, ammoKeys) then
                pcall(function() if v.Value < 999 then v.Value = 999 end end)
            end
            if Config.RapidFire.Enabled and v:IsA("NumberValue") and matchesKeys(v.Name, rateKeys) then
                pcall(function() v.Value = 0.01 end)
            end
            if Config.InfiniteAmmo.Enabled then
                for a, av in pairs(v:GetAttributes()) do
                    if type(av) == "number" and matchesKeys(a, ammoKeys) then
                        pcall(function() if av < 999 then v:SetAttribute(a, 999) end end)
                    end
                end
            end
            if Config.RapidFire.Enabled then
                for a, av in pairs(v:GetAttributes()) do
                    if type(av) == "number" and matchesKeys(a, rateKeys) then
                        pcall(function() v:SetAttribute(a, 0.01) end)
                    end
                end
            end
        end
    end
end)

-- ════════════════════════════════════════
--  GUI
-- ════════════════════════════════════════
local ScreenGui  = Instance.new("ScreenGui")
local MainFrame  = Instance.new("Frame")
local UICorner   = Instance.new("UICorner")
local UIGradient = Instance.new("UIGradient")

local guiParent = (typeof(gethui) == "function" and gethui()) or game:GetService("CoreGui")
ScreenGui.Parent = guiParent
ScreenGui.Name = "OgsTuffScriptUI"
ScreenGui.ResetOnSpawn = false

MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
MainFrame.Position = UDim2.new(0.5, -300, 0, 20)
MainFrame.Size = UDim2.new(0, 600, 0, 360)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true

local MainCorner = UICorner:Clone()
MainCorner.CornerRadius = UDim.new(0, 12)
MainCorner.Parent = MainFrame

local Gradient = UIGradient:Clone()
Gradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(40,40,40)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(15,15,15))
})
Gradient.Rotation = 45
Gradient.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Parent = MainFrame
Title.BackgroundTransparency = 1
Title.Size = UDim2.new(1, 0, 0, 45)
Title.Font = Enum.Font.GothamBold
Title.Text = "OG'S TUFF SCRIPT"
Title.TextColor3 = Color3.fromRGB(255,255,255)
Title.TextSize = 20

local Sep = Instance.new("Frame")
Sep.Parent = MainFrame
Sep.BackgroundColor3 = Color3.fromRGB(0,170,255)
Sep.BorderSizePixel = 0
Sep.Position = UDim2.new(0.05, 0, 0, 44)
Sep.Size = UDim2.new(0.9, 0, 0, 1)

local ContentContainer = Instance.new("ScrollingFrame")
ContentContainer.Parent = MainFrame
ContentContainer.Position = UDim2.new(0, 5, 0, 50)
ContentContainer.Size = UDim2.new(1, -10, 1, -55)
ContentContainer.BackgroundTransparency = 1
ContentContainer.ScrollBarThickness = 4
ContentContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
ContentContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y

local Grid = Instance.new("UIGridLayout")
Grid.Parent = ContentContainer
Grid.CellSize = UDim2.new(0, 185, 0, 34)
Grid.CellPadding = UDim2.new(0, 8, 0, 8)
Grid.SortOrder = Enum.SortOrder.LayoutOrder

local function MakeButton(text, color)
    local btn = Instance.new("TextButton")
    btn.Parent = ContentContainer
    btn.BackgroundColor3 = Color3.fromRGB(35,35,35)
    btn.Font = Enum.Font.GothamMedium
    btn.Text = text
    btn.TextColor3 = color or Color3.fromRGB(150,150,150)
    btn.TextSize = 13
    btn.BorderSizePixel = 0
    UICorner:Clone().Parent = btn
    return btn
end

local function MakeSliderRow(text)
    local frame = Instance.new("Frame")
    frame.Parent = ContentContainer
    frame.BackgroundTransparency = 1
    local label = Instance.new("TextLabel")
    label.Parent = frame
    label.BackgroundColor3 = Color3.fromRGB(35,35,35)
    label.Size = UDim2.new(0.48, 0, 1, 0)
    label.Font = Enum.Font.GothamMedium
    label.Text = text
    label.TextColor3 = Color3.fromRGB(200,200,200)
    label.TextSize = 13
    label.BorderSizePixel = 0
    UICorner:Clone().Parent = label
    local minus = Instance.new("TextButton")
    minus.Parent = frame
    minus.BackgroundColor3 = Color3.fromRGB(50,50,50)
    minus.Position = UDim2.new(0.5, 0, 0, 0)
    minus.Size = UDim2.new(0.24, 0, 1, 0)
    minus.Font = Enum.Font.GothamBold
    minus.Text = "–"
    minus.TextColor3 = Color3.fromRGB(255,100,100)
    minus.TextSize = 18
    minus.BorderSizePixel = 0
    UICorner:Clone().Parent = minus
    local plus = Instance.new("TextButton")
    plus.Parent = frame
    plus.BackgroundColor3 = Color3.fromRGB(50,50,50)
    plus.Position = UDim2.new(0.76, 0, 0, 0)
    plus.Size = UDim2.new(0.24, 0, 1, 0)
    plus.Font = Enum.Font.GothamBold
    plus.Text = "+"
    plus.TextColor3 = Color3.fromRGB(100,255,100)
    plus.TextSize = 18
    plus.BorderSizePixel = 0
    UICorner:Clone().Parent = plus
    return label, minus, plus
end

local function AnimateButton(button, state)
    local on  = Color3.fromRGB(0,170,255)
    local off = Color3.fromRGB(35,35,35)
    TweenService:Create(button, TweenInfo.new(0.25), {BackgroundColor3 = state and on or off}):Play()
    TweenService:Create(button, TweenInfo.new(0.25), {TextColor3 = state and Color3.new(1,1,1) or Color3.fromRGB(150,150,150)}):Play()
end

-- Buttons
local AimbotToggle      = MakeButton("Aimbot [OFF]")
local AimModeBtn        = MakeButton("Aim Mode: Hold",       Color3.fromRGB(255,200,50))
local AimbotKeyBtn      = MakeButton("Aim Key: RMB",         Color3.fromRGB(255,200,50))
local SilentToggle      = MakeButton("Silent Aim [OFF]")
local ESPToggle         = MakeButton("ESP [OFF]")
local ChamsToggle       = MakeButton("Chams [OFF]")
local ChamsColorBtn     = MakeButton("Chams Color: Red/White",Color3.fromRGB(255,200,50))
local HitboxToggle      = MakeButton("Hitbox: Head",         Color3.fromRGB(255,200,50))
local TPAuraToggle      = MakeButton("TP Aura [OFF]")
local EnemyTPToggle     = MakeButton("Enemy TP Aura [OFF]")
local KnifeAuraToggle   = MakeButton("Knife Aura [OFF]")
local FlyToggle         = MakeButton("Fly [OFF]")
local FlyModeBtn        = MakeButton("Fly Mode: Normal",     Color3.fromRGB(255,200,50))
local NoclipToggle      = MakeButton("Noclip [OFF]")
local InfJumpToggle     = MakeButton("Inf. Jump [OFF]")
local InfAmmoToggle     = MakeButton("Inf. Ammo [OFF]")
local RapidFireToggle   = MakeButton("Rapid Fire [OFF]")
local MagicBulletToggle = MakeButton("Magic Bullet [OFF]")
local TeamCheckToggle   = MakeButton("Team Check [ON]", Color3.fromRGB(50,255,100))

local FOVLabel,      FOVMinus,      FOVPlus      = MakeSliderRow("FOV: 150")
local SmoothLabel,   SmoothMinus,   SmoothPlus   = MakeSliderRow("Smooth: 5")
local SpeedLabel,    SpeedMinus,    SpeedPlus     = MakeSliderRow("Speed: 16")
local FlySpeedLabel, FlySpeedMinus, FlySpeedPlus = MakeSliderRow("Fly Spd: 60")
local PredLabel,     PredMinus,     PredPlus      = MakeSliderRow("Predict: 12")

-- Button logic
AimbotToggle.MouseButton1Click:Connect(function()
    Config.Aimbot.Enabled = not Config.Aimbot.Enabled
    AimbotToggle.Text = "Aimbot [" .. (Config.Aimbot.Enabled and "ON" or "OFF") .. "]"
    AnimateButton(AimbotToggle, Config.Aimbot.Enabled)
end)

AimModeBtn.MouseButton1Click:Connect(function()
    Config.Aimbot.Mode = Config.Aimbot.Mode == "Hold" and "Toggle" or "Hold"
    AimModeBtn.Text = "Aim Mode: " .. Config.Aimbot.Mode
end)

SilentToggle.MouseButton1Click:Connect(function()
    Config.SilentAim.Enabled = not Config.SilentAim.Enabled
    SilentToggle.Text = "Silent Aim [" .. (Config.SilentAim.Enabled and "ON" or "OFF") .. "]"
    AnimateButton(SilentToggle, Config.SilentAim.Enabled)
end)

ESPToggle.MouseButton1Click:Connect(function()
    Config.ESP.Enabled = not Config.ESP.Enabled
    ESPToggle.Text = "ESP [" .. (Config.ESP.Enabled and "ON" or "OFF") .. "]"
    AnimateButton(ESPToggle, Config.ESP.Enabled)
    RefreshAllVisuals()
end)

ChamsToggle.MouseButton1Click:Connect(function()
    Config.Chams.Enabled = not Config.Chams.Enabled
    ChamsToggle.Text = "Chams [" .. (Config.Chams.Enabled and "ON" or "OFF") .. "]"
    AnimateButton(ChamsToggle, Config.Chams.Enabled)
    RefreshAllVisuals()
end)

local ChamsColorNames = {"Red/White","Cyan/Blue","Green/White","Orange/Yellow","Purple/Pink","White/Black"}
ChamsColorBtn.MouseButton1Click:Connect(function()
    ChamsColorIndex = (ChamsColorIndex % #ChamsColors) + 1
    local c = ChamsColors[ChamsColorIndex]
    Config.Chams.FillColor    = c.fill
    Config.Chams.OutlineColor = c.outline
    ChamsColorBtn.Text = "Chams Color: " .. ChamsColorNames[ChamsColorIndex]
    TweenService:Create(ChamsColorBtn, TweenInfo.new(0.2), {BackgroundColor3 = c.fill}):Play()
    task.delay(0.4, function()
        TweenService:Create(ChamsColorBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(35,35,35)}):Play()
    end)
    RefreshAllVisuals()
end)

HitboxToggle.MouseButton1Click:Connect(function()
    HitboxIndex = (HitboxIndex % #Hitboxes) + 1
    Config.Aimbot.TargetPart = Hitboxes[HitboxIndex]
    HitboxToggle.Text = "Hitbox: " .. Hitboxes[HitboxIndex]
end)

FlyModeBtn.MouseButton1Click:Connect(function()
    Config.Fly.Mode = Config.Fly.Mode == "Normal" and "Slide" or "Normal"
    FlyModeBtn.Text = "Fly Mode: " .. Config.Fly.Mode
end)

FlyToggle.MouseButton1Click:Connect(function()
    Config.Fly.Enabled = not Config.Fly.Enabled
    FlyToggle.Text = "Fly [" .. (Config.Fly.Enabled and "ON" or "OFF") .. "]"
    AnimateButton(FlyToggle, Config.Fly.Enabled)
end)

NoclipToggle.MouseButton1Click:Connect(function()
    Config.Noclip.Enabled = not Config.Noclip.Enabled
    NoclipToggle.Text = "Noclip [" .. (Config.Noclip.Enabled and "ON" or "OFF") .. "]"
    AnimateButton(NoclipToggle, Config.Noclip.Enabled)
end)

TPAuraToggle.MouseButton1Click:Connect(function()
    Config.TPAura.Enabled = not Config.TPAura.Enabled
    TPAuraToggle.Text = "TP Aura [" .. (Config.TPAura.Enabled and "ON" or "OFF") .. "]"
    AnimateButton(TPAuraToggle, Config.TPAura.Enabled)
end)

EnemyTPToggle.MouseButton1Click:Connect(function()
    Config.EnemyTPAura.Enabled = not Config.EnemyTPAura.Enabled
    EnemyTPToggle.Text = "Enemy TP Aura [" .. (Config.EnemyTPAura.Enabled and "ON" or "OFF") .. "]"
    AnimateButton(EnemyTPToggle, Config.EnemyTPAura.Enabled)
end)

KnifeAuraToggle.MouseButton1Click:Connect(function()
    Config.KnifeAura.Enabled = not Config.KnifeAura.Enabled
    KnifeAuraToggle.Text = "Knife Aura [" .. (Config.KnifeAura.Enabled and "ON" or "OFF") .. "]"
    AnimateButton(KnifeAuraToggle, Config.KnifeAura.Enabled)
end)

InfJumpToggle.MouseButton1Click:Connect(function()
    Config.InfiniteJump.Enabled = not Config.InfiniteJump.Enabled
    InfJumpToggle.Text = "Inf. Jump [" .. (Config.InfiniteJump.Enabled and "ON" or "OFF") .. "]"
    AnimateButton(InfJumpToggle, Config.InfiniteJump.Enabled)
end)

InfAmmoToggle.MouseButton1Click:Connect(function()
    Config.InfiniteAmmo.Enabled = not Config.InfiniteAmmo.Enabled
    InfAmmoToggle.Text = "Inf. Ammo [" .. (Config.InfiniteAmmo.Enabled and "ON" or "OFF") .. "]"
    AnimateButton(InfAmmoToggle, Config.InfiniteAmmo.Enabled)
end)

RapidFireToggle.MouseButton1Click:Connect(function()
    Config.RapidFire.Enabled = not Config.RapidFire.Enabled
    RapidFireToggle.Text = "Rapid Fire [" .. (Config.RapidFire.Enabled and "ON" or "OFF") .. "]"
    AnimateButton(RapidFireToggle, Config.RapidFire.Enabled)
end)

MagicBulletToggle.MouseButton1Click:Connect(function()
    Config.MagicBullet.Enabled = not Config.MagicBullet.Enabled
    MagicBulletToggle.Text = "Magic Bullet [" .. (Config.MagicBullet.Enabled and "ON" or "OFF") .. "]"
    AnimateButton(MagicBulletToggle, Config.MagicBullet.Enabled)
end)

TeamCheckToggle.MouseButton1Click:Connect(function()
    Config.TeamCheck = not Config.TeamCheck
    TeamCheckToggle.Text = "Team Check [" .. (Config.TeamCheck and "ON" or "OFF") .. "]"
    local col = Config.TeamCheck and Color3.fromRGB(50,200,80) or Color3.fromRGB(200,50,50)
    TweenService:Create(TeamCheckToggle, TweenInfo.new(0.25), {BackgroundColor3 = col}):Play()
end)
TweenService:Create(TeamCheckToggle, TweenInfo.new(0), {BackgroundColor3 = Color3.fromRGB(50,200,80)}):Play()

-- Sliders
FOVMinus.MouseButton1Click:Connect(function()
    Config.Aimbot.Radius = math.max(10, Config.Aimbot.Radius - 10)
    FOVLabel.Text = "FOV: " .. Config.Aimbot.Radius
end)
FOVPlus.MouseButton1Click:Connect(function()
    Config.Aimbot.Radius = math.min(1500, Config.Aimbot.Radius + 10)
    FOVLabel.Text = "FOV: " .. Config.Aimbot.Radius
end)

SmoothMinus.MouseButton1Click:Connect(function()
    Config.Aimbot.Smoothness = math.max(0, Config.Aimbot.Smoothness - 1)
    SmoothLabel.Text = "Smooth: " .. Config.Aimbot.Smoothness
end)
SmoothPlus.MouseButton1Click:Connect(function()
    Config.Aimbot.Smoothness = math.min(10, Config.Aimbot.Smoothness + 1)
    SmoothLabel.Text = "Smooth: " .. Config.Aimbot.Smoothness
end)

local currentSpeed = 16
SpeedMinus.MouseButton1Click:Connect(function()
    currentSpeed = math.max(2, currentSpeed - 2)
    SpeedLabel.Text = "Speed: " .. currentSpeed
    local Char = LocalPlayer.Character
    if Char and Char:FindFirstChild("Humanoid") then Char.Humanoid.WalkSpeed = currentSpeed end
end)
SpeedPlus.MouseButton1Click:Connect(function()
    currentSpeed = math.min(200, currentSpeed + 2)
    SpeedLabel.Text = "Speed: " .. currentSpeed
    local Char = LocalPlayer.Character
    if Char and Char:FindFirstChild("Humanoid") then Char.Humanoid.WalkSpeed = currentSpeed end
end)

-- Keep WalkSpeed on respawn
LocalPlayer.CharacterAdded:Connect(function(char)
    char:WaitForChild("Humanoid").WalkSpeed = currentSpeed
end)

FlySpeedMinus.MouseButton1Click:Connect(function()
    Config.Fly.Speed = math.max(10, Config.Fly.Speed - 10)
    FlySpeedLabel.Text = "Fly Spd: " .. Config.Fly.Speed
end)
FlySpeedPlus.MouseButton1Click:Connect(function()
    Config.Fly.Speed = math.min(300, Config.Fly.Speed + 10)
    FlySpeedLabel.Text = "Fly Spd: " .. Config.Fly.Speed
end)

-- Prediction slider (0.01 steps, displayed as integer x100)
PredMinus.MouseButton1Click:Connect(function()
    Config.Aimbot.Prediction = math.max(0, math.round((Config.Aimbot.Prediction - 0.01) * 100) / 100)
    PredLabel.Text = "Predict: " .. math.round(Config.Aimbot.Prediction * 100)
end)
PredPlus.MouseButton1Click:Connect(function()
    Config.Aimbot.Prediction = math.min(0.5, math.round((Config.Aimbot.Prediction + 0.01) * 100) / 100)
    PredLabel.Text = "Predict: " .. math.round(Config.Aimbot.Prediction * 100)
end)

-- Key binding
local bindingKey = false
AimbotKeyBtn.MouseButton1Click:Connect(function()
    if bindingKey then return end
    bindingKey = true
    AimbotKeyBtn.Text = "Press any key..."
    TweenService:Create(AimbotKeyBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(180,100,0)}):Play()
end)

UserInputService.InputBegan:Connect(function(input, gpe)
    if not gpe and input.KeyCode == Enum.KeyCode.P then
        MainFrame.Visible = not MainFrame.Visible
        return
    end
    if bindingKey then
        bindingKey = false
        if input.UserInputType ~= Enum.UserInputType.Keyboard then
            Config.Aimbot.Key = input.UserInputType
            Config.Aimbot.KeyName = tostring(input.UserInputType):gsub("Enum.UserInputType.","")
        elseif input.KeyCode ~= Enum.KeyCode.Unknown then
            Config.Aimbot.Key = input.KeyCode
            Config.Aimbot.KeyName = tostring(input.KeyCode):gsub("Enum.KeyCode.","")
        end
        AimbotKeyBtn.Text = "Aim Key: " .. Config.Aimbot.KeyName
        TweenService:Create(AimbotKeyBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(35,35,35)}):Play()
        return
    end
    if (Config.Aimbot.Key and input.UserInputType == Config.Aimbot.Key)
    or (Config.Aimbot.Key and input.KeyCode == Config.Aimbot.Key) then
        isAimKeyDown = true
        if Config.Aimbot.Mode == "Toggle" then
            aimbotToggled = not aimbotToggled
        end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if (Config.Aimbot.Key and input.UserInputType == Config.Aimbot.Key)
    or (Config.Aimbot.Key and input.KeyCode == Config.Aimbot.Key) then
        isAimKeyDown = false
    end
end)

print("---------------------------")
print("OG's Tuff script Loaded!")
print("Press 'P' to toggle menu")
print("---------------------------")
