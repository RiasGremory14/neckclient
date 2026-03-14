--[[
    Premium Roblox Script: Aimbot, Silent Aim, ESP & Chams
    Created for educational purposes.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Configuration
local Hitboxes = {"Head", "HumanoidRootPart", "Torso", "UpperTorso", "LowerTorso"}
local HitboxIndex = 1

-- Chams color presets
local ChamsColors = {
    {fill = Color3.fromRGB(255, 50, 50),  outline = Color3.fromRGB(255,255,255)},  -- Red/White
    {fill = Color3.fromRGB(50, 200, 255), outline = Color3.fromRGB(0, 100, 200)},  -- Cyan/Blue
    {fill = Color3.fromRGB(50, 255, 100), outline = Color3.fromRGB(255,255,255)},  -- Green/White
    {fill = Color3.fromRGB(255, 150, 0),  outline = Color3.fromRGB(255,255,0)},    -- Orange/Yellow
    {fill = Color3.fromRGB(180, 0, 255),  outline = Color3.fromRGB(255,100,255)},  -- Purple/Pink
    {fill = Color3.fromRGB(255, 255, 255),outline = Color3.fromRGB(0, 0, 0)},      -- White/Black
}
local ChamsColorIndex = 1

local Config = {
    Aimbot = {
        Enabled = false,
        Key = Enum.UserInputType.MouseButton2,
        Radius = 150,
        Smoothness = 0.5,
        ShowFOV = true,
        TargetPart = Hitboxes[HitboxIndex]
    },
    SilentAim = { Enabled = false },
    ESP        = { Enabled = false, TeamCheck = true },
    Chams      = {
        Enabled = false,
        FillColor    = ChamsColors[ChamsColorIndex].fill,
        OutlineColor = ChamsColors[ChamsColorIndex].outline,
    },
    Fly        = { Enabled = false, Speed = 60 },
    Noclip     = { Enabled = false },
    TPAura     = { Enabled = false, Range = 20, Interval = 0.15 },
}

-- FOV Circle
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 2
FOVCircle.NumSides = 64
FOVCircle.Color = Color3.fromRGB(255, 255, 255)
FOVCircle.Filled = false
FOVCircle.Transparency = 0.5

-- Helper: get closest enemy part
local function GetClosestPlayer()
    local Target = nil
    local MaxDistance = Config.Aimbot.Radius

    for _, Player in pairs(Players:GetPlayers()) do
        if Player == LocalPlayer or not Player.Character then continue end
        local aimPart = Player.Character:FindFirstChild(Config.Aimbot.TargetPart)
            or Player.Character:FindFirstChild("HumanoidRootPart")
        local hum = Player.Character:FindFirstChild("Humanoid")
        if not aimPart or not hum or hum.Health <= 0 then continue end
        -- Team check only if teams are actually used in this game
        if Config.TeamCheck then
            local ok, sameTeam = pcall(function() return Player.Team == LocalPlayer.Team end)
            if ok and sameTeam then continue end
        end

        local ScreenPoint, OnScreen = Camera:WorldToScreenPoint(aimPart.Position)
        local MousePos = UserInputService:GetMouseLocation()
        local Dist = (Vector2.new(MousePos.X, MousePos.Y) - Vector2.new(ScreenPoint.X, ScreenPoint.Y)).Magnitude

        if OnScreen and Dist < MaxDistance then
            Target = aimPart
            MaxDistance = Dist
        end
    end
    return Target
end

-- ════════════════════════════════════════
--  SILENT AIM  (Universal - works in all games)
-- ════════════════════════════════════════

-- Method 1: mousemoverel (works in Arsenal, Phantom Forces, etc.)
local function ApplySilentAim()
    if not Config.SilentAim.Enabled then return end
    local target = GetClosestPlayer()
    if not target then return end
    local screenPos, onScreen = Camera:WorldToScreenPoint(target.Position)
    if not onScreen then return end
    local mouse = UserInputService:GetMouseLocation()
    local dx = screenPos.X - mouse.X
    local dy = screenPos.Y - mouse.Y
    mousemoverel(dx, dy)
    task.defer(function()
        mousemoverel(-dx, -dy)
    end)
end

-- Method 2: namecall hook covering ALL ray methods used by Roblox games
pcall(function()
    local mt = getrawmetatable(game)
    local oldNamecall = mt.__namecall
    setreadonly(mt, false)

    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()

        if Config.SilentAim.Enabled then
            local target = GetClosestPlayer()
            if target then
                local args = {...}

                -- Covers legacy ray methods (most old FPS games)
                if method == "FindPartOnRay" or method == "FindPartOnRayWithIgnoreList" or method == "FindPartOnRayWithWhitelist" then
                    local ray = args[1]
                    if ray then
                        local newDir = (target.Position - Camera.CFrame.Position).Unit * ray.Direction.Magnitude
                        args[1] = Ray.new(Camera.CFrame.Position, newDir)
                        return oldNamecall(self, table.unpack(args))
                    end

                -- Covers modern Raycast (newer FPS games like Strucid, Bad Business)
                elseif method == "Raycast" then
                    local newDir = (target.Position - Camera.CFrame.Position).Unit
                    local len = args[2] and args[2].Magnitude or 1000
                    args[1] = Camera.CFrame.Position
                    args[2] = newDir * len
                    return oldNamecall(self, table.unpack(args))

                -- Covers ScreenPointToRay / ViewportPointToRay (some simulators)
                elseif method == "ScreenPointToRay" or method == "ViewportPointToRay" then
                    local sp = Camera:WorldToScreenPoint(target.Position)
                    args[1] = sp.X
                    args[2] = sp.Y
                    return oldNamecall(self, table.unpack(args))
                end
            end
        end

        return oldNamecall(self, ...)
    end)

    setreadonly(mt, true)
end)


-- ════════════════════════════════════════
--  ESP  (Highlight boxes)
-- ════════════════════════════════════════
local function UpdateESP()
    for _, Player in pairs(Players:GetPlayers()) do
        if Player == LocalPlayer or not Player.Character then continue end
        local Char = Player.Character
        local Highlight = Char:FindFirstChild("ESPHighlight")

        if Config.ESP.Enabled then
            if not Highlight then
                Highlight = Instance.new("Highlight")
                Highlight.Name = "ESPHighlight"
                Highlight.Parent = Char
            end
            Highlight.FillTransparency = 1          -- boxes only, no fill
            Highlight.OutlineTransparency = 0
            if Player.Team ~= LocalPlayer.Team then
                Highlight.OutlineColor = Color3.fromRGB(255, 50, 50)
            else
                Highlight.OutlineColor = Color3.fromRGB(50, 255, 100)
            end
        else
            if Highlight then Highlight:Destroy() end
        end
    end
end

-- ════════════════════════════════════════
--  CHAMS  (Highlight with fill + custom color)
-- ════════════════════════════════════════
local function UpdateChams()
    for _, Player in pairs(Players:GetPlayers()) do
        if Player == LocalPlayer or not Player.Character then continue end
        local Char = Player.Character
        local Chams = Char:FindFirstChild("ChamsHighlight")

        if Config.Chams.Enabled then
            if not Chams then
                Chams = Instance.new("Highlight")
                Chams.Name = "ChamsHighlight"
                Chams.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop -- see through walls
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
end

-- ════════════════════════════════════════
--  MAIN LOOP
-- ════════════════════════════════════════
RunService.RenderStepped:Connect(function()
    FOVCircle.Visible = Config.Aimbot.Enabled and Config.Aimbot.ShowFOV
    FOVCircle.Radius = Config.Aimbot.Radius
    FOVCircle.Position = UserInputService:GetMouseLocation()

    -- Camera Aimbot
    if Config.Aimbot.Enabled and UserInputService:IsMouseButtonPressed(Config.Aimbot.Key) then
        local Target = GetClosestPlayer()
        if Target then
            local CurrentCF = Camera.CFrame
            local NewLookAt = CFrame.new(CurrentCF.Position, Target.Position)
            Camera.CFrame = CurrentCF:Lerp(NewLookAt, Config.Aimbot.Smoothness)
        end
    end

    -- Silent Aim: apply on left click
    if Config.SilentAim.Enabled and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
        ApplySilentAim()
    end

    UpdateESP()
    UpdateChams()
end)

-- ════════════════════════════════════════
--  FLY
-- ════════════════════════════════════════
local FlyBodyVel, FlyBodyGyro

local function EnableFly()
    local Char = LocalPlayer.Character
    if not Char then return end
    local Root = Char:FindFirstChild("HumanoidRootPart")
    if not Root then return end

    FlyBodyVel = Instance.new("BodyVelocity")
    FlyBodyVel.Velocity = Vector3.zero
    FlyBodyVel.MaxForce = Vector3.new(1e5,1e5,1e5)
    FlyBodyVel.Parent = Root

    FlyBodyGyro = Instance.new("BodyGyro")
    FlyBodyGyro.MaxTorque = Vector3.new(1e5,1e5,1e5)
    FlyBodyGyro.P = 1e4
    FlyBodyGyro.CFrame = Root.CFrame
    FlyBodyGyro.Parent = Root
end

local function DisableFly()
    if FlyBodyVel  then FlyBodyVel:Destroy();  FlyBodyVel  = nil end
    if FlyBodyGyro then FlyBodyGyro:Destroy(); FlyBodyGyro = nil end
    local Char = LocalPlayer.Character
    if Char then
        local hum = Char:FindFirstChild("Humanoid")
        if hum then hum.PlatformStand = false end
    end
end

RunService.RenderStepped:Connect(function()
    if not Config.Fly.Enabled or not FlyBodyVel or not FlyBodyGyro then return end
    local Char = LocalPlayer.Character
    if not Char then return end
    local Root = Char:FindFirstChild("HumanoidRootPart")
    local hum  = Char:FindFirstChild("Humanoid")
    if not Root or not hum then return end
    hum.PlatformStand = true

    local dir = Vector3.zero
    local cf  = Camera.CFrame
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cf.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cf.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cf.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cf.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0,1,0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.new(0,1,0) end

    FlyBodyVel.Velocity = dir.Magnitude > 0 and dir.Unit * Config.Fly.Speed or Vector3.zero
    FlyBodyGyro.CFrame = cf
end)

-- ════════════════════════════════════════
--  NOCLIP
-- ════════════════════════════════════════
RunService.Stepped:Connect(function()
    if not Config.Noclip.Enabled then return end
    local Char = LocalPlayer.Character
    if not Char then return end
    for _, part in ipairs(Char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
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
        if dist < closestDist then
            closestDist = dist
            closestRoot = enemyRoot
        end
    end

    if closestRoot then
        -- Teleport slightly behind target to hit them
        Root.CFrame = closestRoot.CFrame * CFrame.new(0, 0, -2.5)
    end
end)

-- ════════════════════════════════════════
--  GUI
-- ════════════════════════════════════════
local ScreenGui = Instance.new("ScreenGui")
local MainFrame = Instance.new("Frame")
local UICorner  = Instance.new("UICorner")
local UIGradient = Instance.new("UIGradient")

-- Safe GUI parent (gethui works on most executors, fallback to CoreGui)
local guiParent = (typeof(gethui) == "function" and gethui()) or game:GetService("CoreGui")
ScreenGui.Parent = guiParent
ScreenGui.Name = "PremiumScriptUI"
ScreenGui.ResetOnSpawn = false

MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
MainFrame.Position = UDim2.new(0.5, -115, 0.5, -145)
MainFrame.Size = UDim2.new(0, 230, 0, 490)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true

local MainCorner = UICorner:Clone()
MainCorner.CornerRadius = UDim.new(0, 12)
MainCorner.Parent = MainFrame

local Gradient = UIGradient:Clone()
Gradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(40, 40, 40)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(15, 15, 15))
})
Gradient.Rotation = 45
Gradient.Parent = MainFrame

-- Title
local Title = Instance.new("TextLabel")
Title.Parent = MainFrame
Title.BackgroundTransparency = 1
Title.Size = UDim2.new(1, 0, 0, 45)
Title.Font = Enum.Font.GothamBold
Title.Text = "PREMIUM LUA"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 20

-- Separator line under title
local Sep = Instance.new("Frame")
Sep.Parent = MainFrame
Sep.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
Sep.BorderSizePixel = 0
Sep.Position = UDim2.new(0.05, 0, 0, 44)
Sep.Size = UDim2.new(0.9, 0, 0, 1)

-- Helper to create a toggle button
local function MakeButton(text, yPos, color)
    local btn = Instance.new("TextButton")
    btn.Parent = MainFrame
    btn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    btn.Position = UDim2.new(0.05, 0, 0, yPos)
    btn.Size = UDim2.new(0.9, 0, 0, 34)
    btn.Font = Enum.Font.GothamMedium
    btn.Text = text
    btn.TextColor3 = color or Color3.fromRGB(150, 150, 150)
    btn.TextSize = 13
    btn.BorderSizePixel = 0
    UICorner:Clone().Parent = btn
    return btn
end

local function AnimateButton(button, state)
    local on  = Color3.fromRGB(0, 170, 255)
    local off = Color3.fromRGB(35, 35, 35)
    TweenService:Create(button, TweenInfo.new(0.25), {BackgroundColor3 = state and on or off}):Play()
    TweenService:Create(button, TweenInfo.new(0.25), {TextColor3 = state and Color3.new(1,1,1) or Color3.fromRGB(150,150,150)}):Play()
end

-- Buttons
local AimbotToggle   = MakeButton("Aimbot [OFF]",     58)
local SilentToggle   = MakeButton("Silent Aim [OFF]", 100)
local ESPToggle      = MakeButton("ESP [OFF]",        142)
local ChamsToggle    = MakeButton("Chams [OFF]",      184)
local ChamsColorBtn  = MakeButton("Chams Color: Red/White", 226, Color3.fromRGB(255, 200, 50))
local HitboxToggle   = MakeButton("Hitbox: Head",     272, Color3.fromRGB(255, 200, 50))

-- Movement seperator line
local Sep2 = Instance.new("Frame")
Sep2.Parent = MainFrame
Sep2.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
Sep2.BorderSizePixel = 0
Sep2.Position = UDim2.new(0.05, 0, 0, 314)
Sep2.Size = UDim2.new(0.9, 0, 0, 1)

local FlyToggle    = MakeButton("Fly [OFF]",      320)
local NoclipToggle = MakeButton("Noclip [OFF]",   362)
local TPAuraToggle = MakeButton("TP Aura [OFF]",  404)

-- Aimbot
AimbotToggle.MouseButton1Click:Connect(function()
    Config.Aimbot.Enabled = not Config.Aimbot.Enabled
    AimbotToggle.Text = "Aimbot [" .. (Config.Aimbot.Enabled and "ON" or "OFF") .. "]"
    AnimateButton(AimbotToggle, Config.Aimbot.Enabled)
end)

-- Silent Aim
SilentToggle.MouseButton1Click:Connect(function()
    Config.SilentAim.Enabled = not Config.SilentAim.Enabled
    SilentToggle.Text = "Silent Aim [" .. (Config.SilentAim.Enabled and "ON" or "OFF") .. "]"
    AnimateButton(SilentToggle, Config.SilentAim.Enabled)
end)

-- ESP
ESPToggle.MouseButton1Click:Connect(function()
    Config.ESP.Enabled = not Config.ESP.Enabled
    ESPToggle.Text = "ESP [" .. (Config.ESP.Enabled and "ON" or "OFF") .. "]"
    AnimateButton(ESPToggle, Config.ESP.Enabled)
end)

-- Chams toggle
ChamsToggle.MouseButton1Click:Connect(function()
    Config.Chams.Enabled = not Config.Chams.Enabled
    ChamsToggle.Text = "Chams [" .. (Config.Chams.Enabled and "ON" or "OFF") .. "]"
    AnimateButton(ChamsToggle, Config.Chams.Enabled)
end)

-- Chams color cycle
local ChamsColorNames = {"Red/White","Cyan/Blue","Green/White","Orange/Yellow","Purple/Pink","White/Black"}
ChamsColorBtn.MouseButton1Click:Connect(function()
    ChamsColorIndex = (ChamsColorIndex % #ChamsColors) + 1
    local c = ChamsColors[ChamsColorIndex]
    Config.Chams.FillColor    = c.fill
    Config.Chams.OutlineColor = c.outline
    ChamsColorBtn.Text = "Chams Color: " .. ChamsColorNames[ChamsColorIndex]
    -- flash the button with the new fill color
    TweenService:Create(ChamsColorBtn, TweenInfo.new(0.2), {BackgroundColor3 = c.fill}):Play()
    task.delay(0.4, function()
        TweenService:Create(ChamsColorBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(35,35,35)}):Play()
    end)
end)

-- Hitbox cycle
HitboxToggle.MouseButton1Click:Connect(function()
    HitboxIndex = (HitboxIndex % #Hitboxes) + 1
    Config.Aimbot.TargetPart = Hitboxes[HitboxIndex]
    HitboxToggle.Text = "Hitbox: " .. Hitboxes[HitboxIndex]
end)

-- Fly
FlyToggle.MouseButton1Click:Connect(function()
    Config.Fly.Enabled = not Config.Fly.Enabled
    FlyToggle.Text = "Fly [" .. (Config.Fly.Enabled and "ON" or "OFF") .. "]"
    AnimateButton(FlyToggle, Config.Fly.Enabled)
    if Config.Fly.Enabled then EnableFly() else DisableFly() end
end)

-- Noclip
NoclipToggle.MouseButton1Click:Connect(function()
    Config.Noclip.Enabled = not Config.Noclip.Enabled
    NoclipToggle.Text = "Noclip [" .. (Config.Noclip.Enabled and "ON" or "OFF") .. "]"
    AnimateButton(NoclipToggle, Config.Noclip.Enabled)
end)

-- TP Aura
TPAuraToggle.MouseButton1Click:Connect(function()
    Config.TPAura.Enabled = not Config.TPAura.Enabled
    TPAuraToggle.Text = "TP Aura [" .. (Config.TPAura.Enabled and "ON" or "OFF") .. "]"
    AnimateButton(TPAuraToggle, Config.TPAura.Enabled)
end)

-- Insert key to toggle menu
UserInputService.InputBegan:Connect(function(input, gpe)
    if not gpe and input.KeyCode == Enum.KeyCode.Insert then
        MainFrame.Visible = not MainFrame.Visible
    end
end)

print("---------------------------")
print("Premium Lua Loaded!")
print("Press 'Insert' to toggle menu")
print("---------------------------")
