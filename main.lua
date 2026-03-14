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
        KeyName = "RMB",
        Mode = "Hold",
        Radius = 150,
        Smoothness = 5,
        ShowFOV = true,
        TargetPart = Hitboxes[HitboxIndex]
    },
    SilentAim     = { Enabled = false },
    ESP           = { Enabled = false },
    TeamCheck     = true,  -- skip teammates in ALL features
    Chams         = {
        Enabled = false,
        FillColor    = ChamsColors[ChamsColorIndex].fill,
        OutlineColor = ChamsColors[ChamsColorIndex].outline,
    },
    Fly           = { Enabled = false, Speed = 60 },
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

local function GetClosestPlayer()
    local Target = nil
    local MaxDistance = Config.Aimbot.Radius
    local MousePos = UserInputService:GetMouseLocation()
    local center = Vector2.new(MousePos.X, MousePos.Y - 36)

    for _, Player in pairs(Players:GetPlayers()) do
        if Player == LocalPlayer or not Player.Character then continue end
        local aimPart = Player.Character:FindFirstChild(Config.Aimbot.TargetPart)
            or Player.Character:FindFirstChild("HumanoidRootPart")
        if not aimPart then continue end
        
        local hum = Player.Character:FindFirstChild("Humanoid")
        if not hum or hum.Health <= 0 then continue end
        
        -- Global team check (optimized, no pcall)
        if Config.TeamCheck and Player.Team == LocalPlayer.Team then continue end

        local ScreenPoint, OnScreen = Camera:WorldToViewportPoint(aimPart.Position)
        if OnScreen then
            local pos = Vector2.new(ScreenPoint.X, ScreenPoint.Y)
            local Dist = (center - pos).Magnitude

            if Dist < MaxDistance then
                Target = aimPart
                MaxDistance = Dist
            end
        end
    end
    return Target
end

-- ════════════════════════════════════════
--  SILENT AIM  (Universal - works in all games)
-- ════════════════════════════════════════

-- Namecall hook covering ALL ray methods used by Roblox games
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

-- Magic Bullet: hook FireServer to redirect CFrame/Vector3 hit args to enemy
pcall(function()
    local mt = getrawmetatable(game)
    local oldNamecall = mt.__namecall
    setreadonly(mt, false)

    local existing = mt.__namecall
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if Config.MagicBullet.Enabled and method == "FireServer" then
            local target = GetClosestPlayer()
            if target then
                local args = {...}
                local modified = false
                for i, v in ipairs(args) do
                    -- Redirect any CFrame argument pointing somewhere
                    if typeof(v) == "CFrame" then
                        args[i] = CFrame.new(target.Position)
                        modified = true
                    -- Redirect any Vector3 that looks like a world position (not zero)
                    elseif typeof(v) == "Vector3" and v.Magnitude > 1 then
                        args[i] = target.Position
                        modified = true
                    -- Spoof Hitbox (Wallbang): substitute wall parts with the enemy's part
                    elseif typeof(v) == "Instance" and v:IsA("BasePart") then
                        args[i] = target
                        modified = true
                    end
                end
                if modified then
                    return existing(self, table.unpack(args))
                end
            end
        end
        return existing(self, ...)
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
    local aimbotActive = false
    if Config.Aimbot.Mode == "Hold" then
        aimbotActive = isAimKeyDown
    else
        aimbotActive = aimbotToggled
    end
    if Config.Aimbot.Enabled and aimbotActive then
        local Target = GetClosestPlayer()
        if Target then
            local CurrentCF = Camera.CFrame
            local NewLookAt = CFrame.new(CurrentCF.Position, Target.Position)
            local lerpFactor = Config.Aimbot.Smoothness == 0 and 1 or (0.5 / Config.Aimbot.Smoothness)
            Camera.CFrame = CurrentCF:Lerp(NewLookAt, lerpFactor)
        end
    end

    UpdateESP()
    UpdateChams()
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

    local bodyVel = Root:FindFirstChild("FlyBodyVel")
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

        bodyVel.Velocity = dir.Magnitude > 0 and dir.Unit * Config.Fly.Speed or Vector3.zero
        bodyGyro.CFrame = cf
    else
        if bodyVel then bodyVel:Destroy() end
        if bodyGyro then bodyGyro:Destroy() end
        if hum.PlatformStand then hum.PlatformStand = false end
    end
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
--  ENEMY TP AURA (pull enemies to you)
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
        -- Team check
        if Config.TeamCheck then
            local ok, sameTeam = pcall(function() return Player.Team == LocalPlayer.Team end)
            if ok and sameTeam then continue end
        end
        -- Pull enemy right in front of player
        pcall(function()
            enemyRoot.CFrame = Root.CFrame * CFrame.new(0, 0, -2)
            -- Auto attack / kill the target instantly if possible
            if hum then
                hum.Health = 0
            end
            -- Also try to damage them physically or break joints
            enemyRoot.AssemblyLinearVelocity = Vector3.new(0, -1000, 0)
            enemyRoot:BreakJoints()
        end)
    end
end)

-- ════════════════════════════════════════
--  KNIFE AURA (Auto Melee)
-- ════════════════════════════════════════
RunService.Heartbeat:Connect(function()
    if not Config.KnifeAura.Enabled then return end
    local Char = LocalPlayer.Character
    if not Char then return end
    local Root = Char:FindFirstChild("HumanoidRootPart")
    if not Root then return end

    local targetInRange = false
    for _, Player in pairs(Players:GetPlayers()) do
        if Player == LocalPlayer or not Player.Character then continue end
        local enemyRoot = Player.Character:FindFirstChild("HumanoidRootPart")
        local hum = Player.Character:FindFirstChild("Humanoid")
        if not enemyRoot or not hum or hum.Health <= 0 then continue end
        if Config.TeamCheck then
            local ok, sameTeam = pcall(function() return Player.Team == LocalPlayer.Team end)
            if ok and sameTeam then continue end
        end
        if (enemyRoot.Position - Root.Position).Magnitude <= Config.KnifeAura.Range then
            targetInRange = true
            break
        end
    end

    if targetInRange then
        local tool = Char:FindFirstChildWhichIsA("Tool")
        if tool then
            pcall(function() tool:Activate() end)
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
        if type(v) == "table" then
            local isGun = rawget(v, "Ammo") or rawget(v, "ammo") or rawget(v, "Mag") or rawget(v, "Bullets") or rawget(v, "FireRate") or rawget(v, "fireRate") or rawget(v, "Delay")
            if isGun then
                if Config.InfiniteAmmo.Enabled then
                    pcall(function()
                        if rawget(v, "Ammo") and type(v.Ammo) == "number" then rawset(v, "Ammo", 999) end
                        if rawget(v, "ammo") and type(v.ammo) == "number" then rawset(v, "ammo", 999) end
                        if rawget(v, "Mag") and type(v.Mag) == "number" then rawset(v, "Mag", 999) end
                        if rawget(v, "Bullets") and type(v.Bullets) == "number" then rawset(v, "Bullets", 999) end
                        if rawget(v, "MaxAmmo") and type(v.MaxAmmo) == "number" then rawset(v, "MaxAmmo", 999) end
                    end)
                end
                if Config.RapidFire.Enabled then
                    pcall(function()
                        if rawget(v, "FireRate") and type(v.FireRate) == "number" then rawset(v, "FireRate", 0.01) end
                        if rawget(v, "fireRate") and type(v.fireRate) == "number" then rawset(v, "fireRate", 0.01) end
                        if rawget(v, "Delay") and type(v.Delay) == "number" then rawset(v, "Delay", 0.01) end
                        if rawget(v, "Cooldown") and type(v.Cooldown) == "number" then rawset(v, "Cooldown", 0.01) end
                    end)
                end
            end
        end
    end
end

RunService.Heartbeat:Connect(function()
    if not (Config.InfiniteAmmo.Enabled or Config.RapidFire.Enabled) then return end
    
    -- Periodic ModuleScript/Table Patching (supports ACS, CarbonEngine, etc.)
    if tick() - lastGCPatch > 2 then
        lastGCPatch = tick()
        task.spawn(GCWeaponPatch)
    end

    local Char = LocalPlayer.Character
    if not Char then return end
    local tool = Char:FindFirstChildWhichIsA("Tool") or LocalPlayer.Backpack:FindFirstChildWhichIsA("Tool")
    if not tool then return end

    -- Brute-force local IntValues and Attributes
    for _, v in ipairs(tool:GetDescendants()) do
        if Config.InfiniteAmmo.Enabled then
            if v:IsA("IntValue") or v:IsA("NumberValue") then
                local n = string.lower(v.Name)
                if n:find("ammo") or n:find("mag") or n:find("clip") then
                    pcall(function() if v.Value < 999 then v.Value = 999 end end)
                end
            end
            for attrName, _ in pairs(v:GetAttributes()) do
                local n = string.lower(attrName)
                if n:find("ammo") or n:find("mag") or n:find("clip") then
                    pcall(function() v:SetAttribute(attrName, 999) end)
                end
            end
        end
        if Config.RapidFire.Enabled then
            if v:IsA("NumberValue") then
                local n = string.lower(v.Name)
                if n:find("firerate") or n:find("delay") or n:find("cooldown") or n:find("debounce") then
                    pcall(function() v.Value = 0.01 end)
                end
            end
            for attrName, attrValue in pairs(v:GetAttributes()) do
                if type(attrValue) == "number" then
                    local n = string.lower(attrName)
                    if n:find("firerate") or n:find("delay") or n:find("cooldown") or n:find("debounce") then
                        pcall(function() v:SetAttribute(attrName, 0.01) end)
                    end
                end
            end
        end
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
Title.Text = "OG'S TUFF SCRIPT"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 20

-- Separator line under title
local Sep = Instance.new("Frame")
Sep.Parent = MainFrame
Sep.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
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

-- Helper to create a toggle button
local function MakeButton(text, color)
    local btn = Instance.new("TextButton")
    btn.Parent = ContentContainer
    btn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    btn.Font = Enum.Font.GothamMedium
    btn.Text = text
    btn.TextColor3 = color or Color3.fromRGB(150, 150, 150)
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
    label.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    label.Size = UDim2.new(0.48, 0, 1, 0)
    label.Font = Enum.Font.GothamMedium
    label.Text = text
    label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.TextSize = 13
    label.BorderSizePixel = 0
    UICorner:Clone().Parent = label

    local minus = Instance.new("TextButton")
    minus.Parent = frame
    minus.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    minus.Position = UDim2.new(0.5, 0, 0, 0)
    minus.Size = UDim2.new(0.24, 0, 1, 0)
    minus.Font = Enum.Font.GothamBold
    minus.Text = "–"
    minus.TextColor3 = Color3.fromRGB(255, 100, 100)
    minus.TextSize = 18
    minus.BorderSizePixel = 0
    UICorner:Clone().Parent = minus

    local plus = Instance.new("TextButton")
    plus.Parent = frame
    plus.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    plus.Position = UDim2.new(0.76, 0, 0, 0)
    plus.Size = UDim2.new(0.24, 0, 1, 0)
    plus.Font = Enum.Font.GothamBold
    plus.Text = "+"
    plus.TextColor3 = Color3.fromRGB(100, 255, 100)
    plus.TextSize = 18
    plus.BorderSizePixel = 0
    UICorner:Clone().Parent = plus
    
    return label, minus, plus
end

local function AnimateButton(button, state)
    local on  = Color3.fromRGB(0, 170, 255)
    local off = Color3.fromRGB(35, 35, 35)
    TweenService:Create(button, TweenInfo.new(0.25), {BackgroundColor3 = state and on or off}):Play()
    TweenService:Create(button, TweenInfo.new(0.25), {TextColor3 = state and Color3.new(1,1,1) or Color3.fromRGB(150,150,150)}):Play()
end

-- Buttons
local AimbotToggle   = MakeButton("Aimbot [OFF]")
local AimModeBtn     = MakeButton("Aim Mode: Hold", Color3.fromRGB(255, 200, 50))
local AimbotKeyBtn   = MakeButton("Aim Key: RMB", Color3.fromRGB(255, 200, 50))
local SilentToggle   = MakeButton("Silent Aim [OFF]")
local ESPToggle      = MakeButton("ESP [OFF]")
local ChamsToggle    = MakeButton("Chams [OFF]")
local ChamsColorBtn  = MakeButton("Chams Color: Red/White", Color3.fromRGB(255, 200, 50))
local HitboxToggle   = MakeButton("Hitbox: Head", Color3.fromRGB(255, 200, 50))
local TPAuraToggle   = MakeButton("TP Aura [OFF]")
local EnemyTPToggle  = MakeButton("Enemy TP Aura [OFF]")
local KnifeAuraToggle = MakeButton("Knife Aura [OFF]")
local FlyToggle      = MakeButton("Fly [OFF]")
local NoclipToggle   = MakeButton("Noclip [OFF]")
local InfJumpToggle  = MakeButton("Inf. Jump [OFF]")
local InfAmmoToggle  = MakeButton("Inf. Ammo [OFF]")
local RapidFireToggle = MakeButton("Rapid Fire [OFF]")
local MagicBulletToggle = MakeButton("Magic Bullet [OFF]")
local TeamCheckToggle = MakeButton("Team Check [ON]", Color3.fromRGB(50, 255, 100))

local FOVLabel, FOVMinus, FOVPlus = MakeSliderRow("FOV: 150")
local SmoothLabel, SmoothMinus, SmoothPlus = MakeSliderRow("Smooth: 5")
local SpeedLabel, SpeedMinus, SpeedPlus = MakeSliderRow("Speed: 16")
local FlySpeedLabel, FlySpeedMinus, FlySpeedPlus = MakeSliderRow("Fly Spd: 60")

-- Aimbot
AimbotToggle.MouseButton1Click:Connect(function()
    Config.Aimbot.Enabled = not Config.Aimbot.Enabled
    AimbotToggle.Text = "Aimbot [" .. (Config.Aimbot.Enabled and "ON" or "OFF") .. "]"
    AnimateButton(AimbotToggle, Config.Aimbot.Enabled)
end)

-- Aim Mode
AimModeBtn.MouseButton1Click:Connect(function()
    if Config.Aimbot.Mode == "Hold" then
        Config.Aimbot.Mode = "Toggle"
    else
        Config.Aimbot.Mode = "Hold"
    end
    AimModeBtn.Text = "Aim Mode: " .. Config.Aimbot.Mode
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

-- Infinite Jump
InfJumpToggle.MouseButton1Click:Connect(function()
    Config.InfiniteJump.Enabled = not Config.InfiniteJump.Enabled
    InfJumpToggle.Text = "Inf. Jump [" .. (Config.InfiniteJump.Enabled and "ON" or "OFF") .. "]"
    AnimateButton(InfJumpToggle, Config.InfiniteJump.Enabled)
end)

-- Infinite Ammo
InfAmmoToggle.MouseButton1Click:Connect(function()
    Config.InfiniteAmmo.Enabled = not Config.InfiniteAmmo.Enabled
    InfAmmoToggle.Text = "Inf. Ammo [" .. (Config.InfiniteAmmo.Enabled and "ON" or "OFF") .. "]"
    AnimateButton(InfAmmoToggle, Config.InfiniteAmmo.Enabled)
end)

-- Rapid Fire
RapidFireToggle.MouseButton1Click:Connect(function()
    Config.RapidFire.Enabled = not Config.RapidFire.Enabled
    RapidFireToggle.Text = "Rapid Fire [" .. (Config.RapidFire.Enabled and "ON" or "OFF") .. "]"
    AnimateButton(RapidFireToggle, Config.RapidFire.Enabled)
end)

-- Magic Bullet
MagicBulletToggle.MouseButton1Click:Connect(function()
    Config.MagicBullet.Enabled = not Config.MagicBullet.Enabled
    MagicBulletToggle.Text = "Magic Bullet [" .. (Config.MagicBullet.Enabled and "ON" or "OFF") .. "]"
    AnimateButton(MagicBulletToggle, Config.MagicBullet.Enabled)
end)

-- Enemy TP Aura
EnemyTPToggle.MouseButton1Click:Connect(function()
    Config.EnemyTPAura.Enabled = not Config.EnemyTPAura.Enabled
    EnemyTPToggle.Text = "Enemy TP Aura [" .. (Config.EnemyTPAura.Enabled and "ON" or "OFF") .. "]"
    AnimateButton(EnemyTPToggle, Config.EnemyTPAura.Enabled)
end)

-- Knife Aura
KnifeAuraToggle.MouseButton1Click:Connect(function()
    Config.KnifeAura.Enabled = not Config.KnifeAura.Enabled
    KnifeAuraToggle.Text = "Knife Aura [" .. (Config.KnifeAura.Enabled and "ON" or "OFF") .. "]"
    AnimateButton(KnifeAuraToggle, Config.KnifeAura.Enabled)
end)

-- Team Check
TeamCheckToggle.MouseButton1Click:Connect(function()
    Config.TeamCheck = not Config.TeamCheck
    TeamCheckToggle.Text = "Team Check [" .. (Config.TeamCheck and "ON" or "OFF") .. "]"
    local col = Config.TeamCheck and Color3.fromRGB(50,200,80) or Color3.fromRGB(200,50,50)
    TweenService:Create(TeamCheckToggle, TweenInfo.new(0.25), {BackgroundColor3 = col}):Play()
end)
-- Start green (ON by default)
TweenService:Create(TeamCheckToggle, TweenInfo.new(0), {BackgroundColor3 = Color3.fromRGB(50,200,80)}):Play()

-- FOV controls
FOVMinus.MouseButton1Click:Connect(function()
    Config.Aimbot.Radius = math.max(10, Config.Aimbot.Radius - 10)
    FOVLabel.Text = "FOV: " .. Config.Aimbot.Radius
end)

FOVPlus.MouseButton1Click:Connect(function()
    Config.Aimbot.Radius = math.min(1500, Config.Aimbot.Radius + 10)
    FOVLabel.Text = "FOV: " .. Config.Aimbot.Radius
end)

-- Smooth controls
SmoothMinus.MouseButton1Click:Connect(function()
    Config.Aimbot.Smoothness = math.max(0, Config.Aimbot.Smoothness - 1)
    SmoothLabel.Text = "Smooth: " .. Config.Aimbot.Smoothness
end)

SmoothPlus.MouseButton1Click:Connect(function()
    Config.Aimbot.Smoothness = math.min(10, Config.Aimbot.Smoothness + 1)
    SmoothLabel.Text = "Smooth: " .. Config.Aimbot.Smoothness
end)

-- Speed controls
local currentSpeed = 16
SpeedMinus.MouseButton1Click:Connect(function()
    currentSpeed = math.max(2, currentSpeed - 2)
    SpeedLabel.Text = "Speed: " .. currentSpeed
    local Char = LocalPlayer.Character
    if Char and Char:FindFirstChild("Humanoid") then
        Char.Humanoid.WalkSpeed = currentSpeed
    end
end)

SpeedPlus.MouseButton1Click:Connect(function()
    currentSpeed = math.min(200, currentSpeed + 2)
    SpeedLabel.Text = "Speed: " .. currentSpeed
    local Char = LocalPlayer.Character
    if Char and Char:FindFirstChild("Humanoid") then
        Char.Humanoid.WalkSpeed = currentSpeed
    end
end)

-- Ensure WalkSpeed stays when respawning or state changes
RunService.Heartbeat:Connect(function()
    local Char = LocalPlayer.Character
    if Char and Char:FindFirstChild("Humanoid") then
        if Char.Humanoid.WalkSpeed ~= currentSpeed and currentSpeed ~= 16 then
            Char.Humanoid.WalkSpeed = currentSpeed
        end
    end
end)

-- Fly Speed controls
FlySpeedMinus.MouseButton1Click:Connect(function()
    Config.Fly.Speed = math.max(10, Config.Fly.Speed - 10)
    FlySpeedLabel.Text = "Fly Spd: " .. Config.Fly.Speed
end)

FlySpeedPlus.MouseButton1Click:Connect(function()
    Config.Fly.Speed = math.min(300, Config.Fly.Speed + 10)
    FlySpeedLabel.Text = "Fly Spd: " .. Config.Fly.Speed
end)

local bindingKey = false
AimbotKeyBtn.MouseButton1Click:Connect(function()
    if bindingKey then return end
    bindingKey = true
    AimbotKeyBtn.Text = "Press any key..."
    TweenService:Create(AimbotKeyBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(180,100,0)}):Play()
end)

local isAimKeyDown = false
local aimbotToggled = false

UserInputService.InputBegan:Connect(function(input, gpe)
    -- Toggle menu
    if not gpe and input.KeyCode == Enum.KeyCode.P then
        MainFrame.Visible = not MainFrame.Visible
        return
    end
    -- Key binding
    if bindingKey then
        bindingKey = false
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            Config.Aimbot.Key = Enum.UserInputType.MouseButton1
            Config.Aimbot.KeyName = "LMB"
        elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
            Config.Aimbot.Key = Enum.UserInputType.MouseButton2
            Config.Aimbot.KeyName = "RMB"
        elseif input.UserInputType == Enum.UserInputType.MouseButton3 then
            Config.Aimbot.Key = Enum.UserInputType.MouseButton3
            Config.Aimbot.KeyName = "MMB"
        elseif string.find(tostring(input.UserInputType), "MouseButton") then
            Config.Aimbot.Key = input.UserInputType
            Config.Aimbot.KeyName = tostring(input.UserInputType):gsub("Enum.UserInputType.", "")
        elseif input.KeyCode ~= Enum.KeyCode.Unknown then
            Config.Aimbot.Key = input.KeyCode
            Config.Aimbot.KeyName = tostring(input.KeyCode):gsub("Enum.KeyCode.","")
        end
        AimbotKeyBtn.Text = "Aim Key: " .. Config.Aimbot.KeyName
        TweenService:Create(AimbotKeyBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(35,35,35)}):Play()
        return
    end

    if not gpe then
        if input.UserInputType == Config.Aimbot.Key or input.KeyCode == Config.Aimbot.Key then
            isAimKeyDown = true
            if Config.Aimbot.Mode == "Toggle" then
                aimbotToggled = not aimbotToggled
            end
        end
    end
end)

UserInputService.InputEnded:Connect(function(input, gpe)
    if input.UserInputType == Config.Aimbot.Key or input.KeyCode == Config.Aimbot.Key then
        isAimKeyDown = false
    end
end)

print("---------------------------")
print("OG's Tuff script Loaded!")
print("Press 'P' to toggle menu")
print("---------------------------")
