-- OG Rivals Script | Roblox
-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera

local LocalPlayer = Players.LocalPlayer

-- Settings
local Settings = {
    -- ESP
    ESP = true,
    ESPBoxes = true,
    ESPNames = true,
    ESPDistance = true,
    ESPHealth = true,
    -- Chams
    Chams = true,
    ChamsVisibleColor = Color3.fromRGB(150, 200, 60),
    ChamsOccludedColor = Color3.fromRGB(200, 50, 50),
    ChamsAlpha = 0.4,
    -- Aimbot
    Aimbot = true,
    Smoothness = 1,
    FOV = 150,
    ShowFOV = true,
    AimbotKey = Enum.UserInputType.MouseButton2,
    -- Viewmodel FOV
    ViewmodelFOV = 70,
    -- Movement
    Noclip = false,
    InfiniteJump = false,
    -- Visuals removal
    NoFlash = true,
    NoSmoke = true,
}

-- Accent color
local ACCENT = Color3.fromRGB(150, 200, 60)

-- Utility
local function isAlive(player)
    return player.Character
        and player.Character:FindFirstChild("Humanoid")
        and player.Character.Humanoid.Health > 0
end

local function getTargetPart(character)
    if Settings.SilentAimTarget == "Head" then
        return character:FindFirstChild("Head")
    end
    return character:FindFirstChild("HumanoidRootPart")
end

local function worldToViewport(pos)
    local screenPos, onScreen = Camera:WorldToViewportPoint(pos)
    return Vector2.new(screenPos.X, screenPos.Y), onScreen, screenPos.Z
end

local function isOccluded(character)
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return true end
    local origin = Camera.CFrame.Position
    local dir = (hrp.Position - origin)
    local ray = Ray.new(origin, dir)
    local hit = workspace:FindPartOnRayWithIgnoreList(ray, {character, LocalPlayer.Character})
    return hit ~= nil
end

-- FOV Circle
local fovCircle = Drawing.new("Circle")
fovCircle.Thickness = 2
fovCircle.Filled = false
fovCircle.Color = Color3.fromRGB(150, 200, 60)
fovCircle.Transparency = 0.6

-- Aimbot target finder
local function getAimbotTarget()
    local mouse = UserInputService:GetMouseLocation()
    local best, bestDist = nil, Settings.FOV

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer
            and player.Character
            and player.Character:FindFirstChild("Humanoid")
            and player.Character.Humanoid.Health > 0
        then
            local part = player.Character:FindFirstChild("HeadHB")
                      or player.Character:FindFirstChild("Head")
                      or player.Character:FindFirstChild("UpperTorso")
            if part then
                local pos, onScreen = Camera:WorldToViewportPoint(part.Position)
                if onScreen then
                    local dist = (Vector2.new(pos.X, pos.Y) - mouse).Magnitude
                    if dist < bestDist then
                        bestDist = dist
                        best = part
                    end
                end
            end
        end
    end
    return best
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "OGRivalsGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = game:GetService("CoreGui")

local DrawingFolder = Instance.new("Folder")
DrawingFolder.Name = "Drawings"
DrawingFolder.Parent = ScreenGui

-- ESP Storage
local espObjects = {}

local function removeESP(player)
    if espObjects[player] then
        for _, obj in pairs(espObjects[player]) do
            obj:Destroy()
        end
        espObjects[player] = nil
    end
end

local function createESP(player)
    if player == LocalPlayer then return end
    removeESP(player)

    local container = Instance.new("Folder", DrawingFolder)
    espObjects[player] = {}

    -- Box
    local box = Instance.new("Frame")
    box.Name = "Box"
    box.BackgroundTransparency = 1
    box.BorderSizePixel = 2
    box.BorderColor3 = ACCENT
    box.Size = UDim2.new(0, 0, 0, 0)
    box.Parent = container
    espObjects[player].box = box

    -- Name label
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "NameLabel"
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3 = Color3.new(1,1,1)
    nameLabel.TextStrokeTransparency = 0.5
    nameLabel.TextSize = 13
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.Text = player.Name
    nameLabel.Size = UDim2.new(0, 100, 0, 16)
    nameLabel.Parent = container
    espObjects[player].nameLabel = nameLabel

    -- Distance label
    local distLabel = Instance.new("TextLabel")
    distLabel.Name = "DistLabel"
    distLabel.BackgroundTransparency = 1
    distLabel.TextColor3 = Color3.fromRGB(200,200,200)
    distLabel.TextStrokeTransparency = 0.5
    distLabel.TextSize = 11
    distLabel.Font = Enum.Font.Gotham
    distLabel.Size = UDim2.new(0, 100, 0, 14)
    distLabel.Parent = container
    espObjects[player].distLabel = distLabel

    -- Health bar background
    local healthBG = Instance.new("Frame")
    healthBG.Name = "HealthBG"
    healthBG.BackgroundColor3 = Color3.fromRGB(30,30,30)
    healthBG.BorderSizePixel = 0
    healthBG.Parent = container
    espObjects[player].healthBG = healthBG

    -- Health bar fill
    local healthFill = Instance.new("Frame")
    healthFill.Name = "HealthFill"
    healthFill.BackgroundColor3 = Color3.fromRGB(100, 220, 60)
    healthFill.BorderSizePixel = 0
    healthFill.Parent = healthBG
    espObjects[player].healthFill = healthFill

    -- Chams (Highlight)
    local chams = Instance.new("Highlight")
    chams.Name = "Chams"
    chams.FillColor = Settings.ChamsVisibleColor
    chams.OutlineColor = Settings.ChamsVisibleColor
    chams.FillTransparency = 1 - Settings.ChamsAlpha
    chams.OutlineTransparency = 0
    chams.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    chams.Enabled = false
    chams.Parent = container
    espObjects[player].chams = chams
end


-- Update ESP each frame
local function updateESP(player)
    local objs = espObjects[player]
    if not objs then return end

    local char = player.Character
    if not char or not isAlive(player) then
        for _, obj in pairs(objs) do
            if obj:IsA("GuiObject") then obj.Visible = false
            elseif obj:IsA("Highlight") then obj.Enabled = false end
        end
        return
    end

    local hrp = char:FindFirstChild("HumanoidRootPart")
    local head = char:FindFirstChild("Head")
    local humanoid = char:FindFirstChild("Humanoid")
    if not hrp or not head then return end

    local topPos, topOnScreen = worldToViewport(head.Position + Vector3.new(0, 0.7, 0))
    local botPos, botOnScreen, depth = worldToViewport(hrp.Position - Vector3.new(0, 3, 0))

    local visible = topOnScreen or botOnScreen
    local occluded = isOccluded(char)

    -- Box
    if objs.box then
        objs.box.Visible = Settings.ESP and Settings.ESPBoxes and visible
        if visible then
            local h = math.abs(botPos.Y - topPos.Y)
            local w = h * 0.6
            local cx = (topPos.X + botPos.X) / 2
            objs.box.Position = UDim2.new(0, cx - w/2, 0, topPos.Y)
            objs.box.Size = UDim2.new(0, w, 0, h)
            objs.box.BorderColor3 = occluded and Color3.fromRGB(200,50,50) or ACCENT
        end
    end

    -- Name
    if objs.nameLabel then
        objs.nameLabel.Visible = Settings.ESP and Settings.ESPNames and visible
        if visible then
            objs.nameLabel.Position = UDim2.new(0, topPos.X - 50, 0, topPos.Y - 18)
        end
    end

    -- Distance
    if objs.distLabel then
        local dist = math.floor((hrp.Position - Camera.CFrame.Position).Magnitude)
        objs.distLabel.Visible = Settings.ESP and Settings.ESPDistance and visible
        if visible then
            objs.distLabel.Text = dist .. "m"
            objs.distLabel.Position = UDim2.new(0, botPos.X - 50, 0, botPos.Y + 2)
        end
    end

    -- Health bar
    if objs.healthBG and humanoid then
        local h = math.abs(botPos.Y - topPos.Y)
        local w = h * 0.6
        local cx = (topPos.X + botPos.X) / 2
        objs.healthBG.Visible = Settings.ESP and Settings.ESPHealth and visible
        objs.healthBG.Position = UDim2.new(0, cx - w/2 - 6, 0, topPos.Y)
        objs.healthBG.Size = UDim2.new(0, 4, 0, h)
        local pct = humanoid.Health / humanoid.MaxHealth
        objs.healthFill.Size = UDim2.new(1, 0, pct, 0)
        objs.healthFill.Position = UDim2.new(0, 0, 1 - pct, 0)
        objs.healthFill.BackgroundColor3 = Color3.fromRGB(
            math.floor(255 * (1 - pct)),
            math.floor(255 * pct),
            0
        )
    end

    -- Chams
    if objs.chams then
        objs.chams.Enabled = Settings.Chams
        if Settings.Chams then
            objs.chams.Adornee = char
            local occluded = isOccluded(char)
            local col = occluded and Settings.ChamsOccludedColor or Settings.ChamsVisibleColor
            objs.chams.FillColor = col
            objs.chams.OutlineColor = col
            objs.chams.FillTransparency = occluded and (1 - Settings.ChamsAlpha * 0.5) or (1 - Settings.ChamsAlpha)
        else
            objs.chams.Adornee = nil
        end
    end
end

-- GUI (ScreenGui)
local gui = ScreenGui

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 520, 0, 380)
mainFrame.Position = UDim2.new(0, 100, 0, 100)
mainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = gui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 8)

-- Accent border
local border = Instance.new("UIStroke", mainFrame)
border.Color = ACCENT
border.Thickness = 1.5
border.Transparency = 0.5

-- Title
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 36)
title.BackgroundColor3 = Color3.fromRGB(12,12,12)
title.BorderSizePixel = 0
title.Text = "OG RIVALS"
title.TextColor3 = ACCENT
title.TextSize = 16
title.Font = Enum.Font.GothamBold
title.Parent = mainFrame
Instance.new("UICorner", title).CornerRadius = UDim.new(0, 8)

-- Sidebar
local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0, 120, 1, -36)
sidebar.Position = UDim2.new(0, 0, 0, 36)
sidebar.BackgroundColor3 = Color3.fromRGB(22,22,22)
sidebar.BorderSizePixel = 0
sidebar.Parent = mainFrame

-- Content
local content = Instance.new("Frame")
content.Size = UDim2.new(1, -130, 1, -46)
content.Position = UDim2.new(0, 125, 0, 41)
content.BackgroundTransparency = 1
content.Parent = mainFrame

local tabs = {}
local tabButtons = {}
local currentTab = "Visuals"

local function makeTab(name)
    local f = Instance.new("ScrollingFrame")
    f.Name = name
    f.Size = UDim2.new(1, 0, 1, 0)
    f.BackgroundTransparency = 1
    f.BorderSizePixel = 0
    f.ScrollBarThickness = 3
    f.ScrollBarImageColor3 = ACCENT
    f.Visible = false
    f.Parent = content
    local layout = Instance.new("UIListLayout", f)
    layout.Padding = UDim.new(0, 8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    tabs[name] = f
    return f
end

local function makeTabBtn(name, order)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -10, 0, 32)
    btn.Position = UDim2.new(0, 5, 0, 10 + (order-1)*38)
    btn.BackgroundColor3 = Color3.fromRGB(30,30,30)
    btn.BorderSizePixel = 0
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(180,180,180)
    btn.TextSize = 13
    btn.Font = Enum.Font.GothamSemibold
    btn.Parent = sidebar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
    tabButtons[name] = btn

    btn.MouseButton1Click:Connect(function()
        currentTab = name
        for n, f in pairs(tabs) do f.Visible = n == name end
        for n, b in pairs(tabButtons) do
            b.BackgroundColor3 = n == name
                and Color3.fromRGB(40,55,20)
                or Color3.fromRGB(30,30,30)
            b.TextColor3 = n == name and ACCENT or Color3.fromRGB(180,180,180)
        end
    end)
end

-- Helper: toggle row
local function makeToggle(parent, labelText, setting, order)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -10, 0, 28)
    row.BackgroundTransparency = 1
    row.LayoutOrder = order
    row.Parent = parent

    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(0.7, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.TextColor3 = Color3.new(1,1,1)
    lbl.TextSize = 13
    lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local btn = Instance.new("TextButton", row)
    btn.Size = UDim2.new(0, 44, 0, 22)
    btn.Position = UDim2.new(1, -44, 0.5, -11)
    btn.BorderSizePixel = 0
    btn.TextSize = 11
    btn.Font = Enum.Font.GothamBold
    Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)

    local function refresh()
        local on = Settings[setting]
        btn.BackgroundColor3 = on and ACCENT or Color3.fromRGB(50,50,50)
        btn.TextColor3 = on and Color3.fromRGB(20,20,20) or Color3.fromRGB(150,150,150)
        btn.Text = on and "ON" or "OFF"
    end
    refresh()
    btn.MouseButton1Click:Connect(function()
        Settings[setting] = not Settings[setting]
        refresh()
    end)
end

-- Helper: slider row
local function makeSlider(parent, labelText, setting, min, max, order)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -10, 0, 44)
    row.BackgroundTransparency = 1
    row.LayoutOrder = order
    row.Parent = parent

    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(1, 0, 0, 16)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText .. ": " .. tostring(math.floor(Settings[setting]))
    lbl.TextColor3 = Color3.new(1,1,1)
    lbl.TextSize = 12
    lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local track = Instance.new("Frame", row)
    track.Size = UDim2.new(1, 0, 0, 10)
    track.Position = UDim2.new(0, 0, 0, 22)
    track.BackgroundColor3 = Color3.fromRGB(40,40,40)
    track.BorderSizePixel = 0
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local fill = Instance.new("Frame", track)
    fill.BackgroundColor3 = ACCENT
    fill.BorderSizePixel = 0
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    local function setVal(v)
        v = math.clamp(v, min, max)
        Settings[setting] = v
        lbl.Text = labelText .. ": " .. tostring(math.floor(v))
        fill.Size = UDim2.new((v - min) / (max - min), 0, 1, 0)
    end
    setVal(Settings[setting])

    local dragging = false
    track.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
            local abs = track.AbsolutePosition
            local w = track.AbsoluteSize.X
            local pct = math.clamp((i.Position.X - abs.X) / w, 0, 1)
            setVal(min + (max - min) * pct)
        end
    end)
end

-- Build tabs
makeTab("Visuals")
makeTab("Combat")
makeTab("Misc")
makeTabBtn("Visuals", 1)
makeTabBtn("Combat", 2)
makeTabBtn("Misc", 3)

-- Visuals tab
local vt = tabs["Visuals"]
makeToggle(vt, "ESP",          "ESP",          1)
makeToggle(vt, "ESP Boxes",    "ESPBoxes",     2)
makeToggle(vt, "ESP Names",    "ESPNames",     3)
makeToggle(vt, "ESP Distance", "ESPDistance",  4)
makeToggle(vt, "ESP Health",   "ESPHealth",    5)
makeToggle(vt, "Chams",        "Chams",        6)
makeSlider(vt, "Chams Alpha",  "ChamsAlpha",   0.1, 1.0, 7)
makeSlider(vt, "Viewmodel FOV","ViewmodelFOV", 60, 120,  8)

-- Combat tab
local ct = tabs["Combat"]
makeToggle(ct, "Aimbot",         "Aimbot",       1)
makeToggle(ct, "Show FOV",       "ShowFOV",      2)
makeSlider(ct, "FOV",            "FOV",          10, 600, 3)
makeSlider(ct, "Smoothness",     "Smoothness",   0.1, 5,  4)

-- Misc tab
local mt = tabs["Misc"]
makeToggle(mt, "Noclip",         "Noclip",        1)
makeToggle(mt, "Infinite Jump",  "InfiniteJump",  2)
makeToggle(mt, "No Flash",       "NoFlash",       3)
makeToggle(mt, "No Smoke",       "NoSmoke",       4)

-- Noclip logic
RunService.Stepped:Connect(function()
    if Settings.Noclip and LocalPlayer.Character then
        for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end
end)

-- Infinite Jump logic
UserInputService.JumpRequest:Connect(function()
    if Settings.InfiniteJump
        and LocalPlayer.Character
        and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    then
        LocalPlayer.Character:FindFirstChildOfClass("Humanoid"):ChangeState(Enum.HumanoidStateType.Jumping)
    end
end)

-- No Flash: hem Lighting efektlerini hem de ScreenGui flash frame'lerini engelle
local Lighting = game:GetService("Lighting")

local function clearLightingEffects()
    for _, effect in ipairs(Lighting:GetChildren()) do
        if Settings.NoFlash then
            if effect:IsA("ColorCorrectionEffect") then
                effect.Brightness = 0
                effect.Contrast = 0
                effect.Saturation = 0
                effect.TintColor = Color3.new(1,1,1)
            elseif effect:IsA("BlurEffect") then
                effect.Size = 0
            elseif effect:IsA("SunRaysEffect") then
                effect.Intensity = 0
            end
        end
    end
end

Lighting.ChildAdded:Connect(function(child)
    task.wait()
    if not Settings.NoFlash then return end
    if child:IsA("ColorCorrectionEffect") then
        child.Brightness = 0; child.Contrast = 0
        child.Saturation = 0; child.TintColor = Color3.new(1,1,1)
    elseif child:IsA("BlurEffect") then
        child.Size = 0
    end
end)

-- Flash frame detector: PlayerGui/CoreGui içindeki beyaz/sarı tam ekran frame'leri yakala
local function isFlashFrame(obj)
    if not obj:IsA("Frame") and not obj:IsA("ImageLabel") then return false end
    local size = obj.Size
    -- tam ekran veya büyük boyutlu
    if size.X.Scale >= 0.8 and size.Y.Scale >= 0.8 then
        local c = obj.BackgroundColor3
        local brightness = (c.R + c.G + c.B) / 3
        -- beyaz, sarı veya açık renk flash
        if brightness > 0.6 and obj.BackgroundTransparency < 0.6 then
            return true
        end
    end
    return false
end

local function hookFlashFrame(obj)
    if not Settings.NoFlash then return end
    if isFlashFrame(obj) then
        obj.BackgroundTransparency = 1
        obj.Visible = false
    end
    -- ImageLabel için
    if obj:IsA("ImageLabel") and obj.Size.X.Scale >= 0.8 then
        obj.ImageTransparency = 1
    end
end

-- PlayerGui'yi izle
local playerGui = LocalPlayer:WaitForChild("PlayerGui")
playerGui.DescendantAdded:Connect(function(obj)
    task.wait()
    hookFlashFrame(obj)
end)
for _, obj in ipairs(playerGui:GetDescendants()) do
    hookFlashFrame(obj)
end

-- RenderStepped'de sürekli kontrol (bazı flash'lar transparency'yi reset'ler)
RunService.RenderStepped:Connect(function()
    if not Settings.NoFlash then return end
    for _, obj in ipairs(playerGui:GetDescendants()) do
        if isFlashFrame(obj) then
            obj.BackgroundTransparency = 1
            obj.Visible = false
        end
    end
    clearLightingEffects()
end)

-- No Smoke: workspace'e eklenen smoke/fire/spark part'larını kaldır
local smokeKeywords = {"smoke", "flash", "grenade", "nade", "smk"}

local function isSmokeObject(obj)
    if not Settings.NoSmoke then return false end
    local name = obj.Name:lower()
    for _, kw in ipairs(smokeKeywords) do
        if name:find(kw) then return true end
    end
    -- Smoke/Fire instance içeriyorsa
    if obj:IsA("BasePart") then
        for _, child in ipairs(obj:GetChildren()) do
            if child:IsA("Smoke") or child:IsA("Fire") or child:IsA("ParticleEmitter") then
                return true
            end
        end
    end
    return false
end

local function handleSmokeObj(obj)
    if isSmokeObject(obj) then
        -- Particle'ları kapat, görünürlüğü sıfırla
        for _, child in ipairs(obj:GetDescendants()) do
            if child:IsA("Smoke") then
                child.Opacity = 0
                child.Enabled = false
            elseif child:IsA("ParticleEmitter") then
                child.Enabled = false
                child.Transparency = NumberSequence.new(1)
            elseif child:IsA("Fire") then
                child.Enabled = false
            end
        end
        if obj:IsA("BasePart") then
            obj.Transparency = 1
            obj.CastShadow = false
        end
    end
end

workspace.DescendantAdded:Connect(function(obj)
    task.wait()
    handleSmokeObj(obj)
end)

-- scan existing
for _, obj in ipairs(workspace:GetDescendants()) do
    handleSmokeObj(obj)
end

tabs["Visuals"].Visible = true
tabButtons["Visuals"].BackgroundColor3 = Color3.fromRGB(40,55,20)
tabButtons["Visuals"].TextColor3 = ACCENT

-- Toggle GUI with INSERT
UserInputService.InputBegan:Connect(function(input, gpe)
    if input.KeyCode == Enum.KeyCode.Insert then
        mainFrame.Visible = not mainFrame.Visible
    end
end)

-- Player hooks
local function onPlayerAdded(player)
    player.CharacterAdded:Connect(function()
        task.wait(1)
        createESP(player)
    end)
    if player.Character then
        task.wait(1)
        createESP(player)
    end
end

for _, player in ipairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then onPlayerAdded(player) end
end
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(removeESP)

-- Main loop
RunService.RenderStepped:Connect(function()
    -- ESP update
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            updateESP(player)
        end
    end

    -- Viewmodel FOV
    if Camera then
        Camera.FieldOfView = Settings.ViewmodelFOV
    end

    -- FOV Circle
    fovCircle.Visible = Settings.Aimbot and Settings.ShowFOV
    fovCircle.Radius = Settings.FOV
    fovCircle.Position = UserInputService:GetMouseLocation()

    -- Aimbot
    if Settings.Aimbot and UserInputService:IsMouseButtonPressed(Settings.AimbotKey) then
        local target = getAimbotTarget()
        if target then
            local pos = Camera:WorldToViewportPoint(target.Position)
            local mouse = UserInputService:GetMouseLocation()
            local x = (pos.X - mouse.X) * Settings.Smoothness
            local y = (pos.Y - mouse.Y) * Settings.Smoothness
            if mousemoverel then
                mousemoverel(x, y)
            end
        end
    end
end)
