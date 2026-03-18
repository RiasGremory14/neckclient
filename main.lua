-- OG Rivals Script | Roblox
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local Settings = {
    ESP = true,
    ESPBoxes = true,
    ESPNames = true,
    ESPDistance = true,
    ESPHealth = true,
    Chams = true,
    ChamsVisibleColor = Color3.fromRGB(150, 200, 60),
    ChamsOccludedColor = Color3.fromRGB(200, 50, 50),
    ChamsAlpha = 0.4,
    Aimbot = true,
    Smoothness = 1,
    FOV = 150,
    ShowFOV = true,
    AimbotKey = Enum.UserInputType.MouseButton2,
    ViewmodelFOV = 70,
    Noclip = false,
    InfiniteJump = false,
    NoFlash = true,
    NoSmoke = true,
}

local ACCENT = Color3.fromRGB(150, 200, 60)

-- Utility
local function isAlive(player)
    return player.Character
        and player.Character:FindFirstChild("Humanoid")
        and player.Character.Humanoid.Health > 0
end

local function worldToViewport(pos)
    local s, on = Camera:WorldToViewportPoint(pos)
    return Vector2.new(s.X, s.Y), on, s.Z
end

-- Occluded check throttled per player (not every frame)
local occludeCache = {}
local occludeTick = {}
local OCCLUDE_INTERVAL = 0.1

local function isOccluded(character)
    local now = tick()
    if occludeTick[character] and (now - occludeTick[character]) < OCCLUDE_INTERVAL then
        return occludeCache[character]
    end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return true end
    local origin = Camera.CFrame.Position
    local ray = Ray.new(origin, hrp.Position - origin)
    local hit = workspace:FindPartOnRayWithIgnoreList(ray, {character, LocalPlayer.Character})
    occludeCache[character] = hit ~= nil
    occludeTick[character] = now
    return occludeCache[character]
end

-- FOV Circle
local fovCircle = Drawing.new("Circle")
fovCircle.Thickness = 2
fovCircle.Filled = false
fovCircle.Color = ACCENT
fovCircle.Transparency = 0.6

-- Aimbot
local function getAimbotTarget()
    local mouse = UserInputService:GetMouseLocation()
    local best, bestDist = nil, Settings.FOV
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character
            and p.Character:FindFirstChild("Humanoid")
            and p.Character.Humanoid.Health > 0
        then
            local part = p.Character:FindFirstChild("HeadHB")
                      or p.Character:FindFirstChild("Head")
                      or p.Character:FindFirstChild("UpperTorso")
            if part then
                local pos, on = Camera:WorldToViewportPoint(part.Position)
                if on then
                    local d = (Vector2.new(pos.X, pos.Y) - mouse).Magnitude
                    if d < bestDist then bestDist = d; best = part end
                end
            end
        end
    end
    return best
end

-- ScreenGui
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "OGRivalsGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = game:GetService("CoreGui")

local DrawingFolder = Instance.new("Folder", ScreenGui)

-- ESP
local espObjects = {}

local function removeESP(player)
    if espObjects[player] then
        for _, o in pairs(espObjects[player]) do pcall(function() o:Destroy() end) end
        espObjects[player] = nil
    end
    occludeCache[player.Character] = nil
    occludeTick[player.Character] = nil
end

local function createESP(player)
    if player == LocalPlayer then return end
    removeESP(player)
    local c = Instance.new("Folder", DrawingFolder)
    local t = {}

    local nameLabel = Instance.new("TextLabel", c)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3 = Color3.new(1,1,1)
    nameLabel.TextStrokeTransparency = 0.5
    nameLabel.TextSize = 13
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.Text = player.Name
    nameLabel.Size = UDim2.new(0, 100, 0, 16)
    nameLabel.Visible = false
    t.nameLabel = nameLabel

    local distLabel = Instance.new("TextLabel", c)
    distLabel.BackgroundTransparency = 1
    distLabel.TextColor3 = Color3.fromRGB(200,200,200)
    distLabel.TextStrokeTransparency = 0.5
    distLabel.TextSize = 11
    distLabel.Font = Enum.Font.Gotham
    distLabel.Size = UDim2.new(0, 100, 0, 14)
    distLabel.Visible = false
    t.distLabel = distLabel

    local healthBG = Instance.new("Frame", c)
    healthBG.BackgroundColor3 = Color3.fromRGB(30,30,30)
    healthBG.BorderSizePixel = 0
    healthBG.Visible = false
    t.healthBG = healthBG

    local healthFill = Instance.new("Frame", healthBG)
    healthFill.BackgroundColor3 = Color3.fromRGB(100,220,60)
    healthFill.BorderSizePixel = 0
    t.healthFill = healthFill

    -- ESP box via Drawing (reliable)
    local box = Drawing.new("Square")
    box.Thickness = 1.5
    box.Filled = false
    box.Color = ACCENT
    box.Visible = false
    t.box = box

    local chams = Instance.new("Highlight", c)
    chams.FillColor = Settings.ChamsVisibleColor
    chams.OutlineColor = Settings.ChamsVisibleColor
    chams.FillTransparency = 1 - Settings.ChamsAlpha
    chams.OutlineTransparency = 0
    chams.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    chams.Enabled = false
    t.chams = chams

    espObjects[player] = t
end

local function updateESP(player)
    local objs = espObjects[player]
    if not objs then return end

    local char = player.Character
    if not char or not isAlive(player) then
        if objs.nameLabel then objs.nameLabel.Visible = false end
        if objs.distLabel then objs.distLabel.Visible = false end
        if objs.healthBG then objs.healthBG.Visible = false end
        if objs.box then objs.box.Visible = false end
        if objs.chams then objs.chams.Enabled = false end
        return
    end

    local hrp = char:FindFirstChild("HumanoidRootPart")
    local head = char:FindFirstChild("Head")
    local humanoid = char:FindFirstChild("Humanoid")
    if not hrp or not head then return end

    local topPos, topOn = worldToViewport(head.Position + Vector3.new(0, 0.7, 0))
    local botPos, botOn = worldToViewport(hrp.Position - Vector3.new(0, 3, 0))
    local visible = topOn or botOn
    local occluded = isOccluded(char)

    -- Box (Drawing)
    if objs.box then
        objs.box.Visible = Settings.ESP and Settings.ESPBoxes and visible
        if visible then
            local h = math.abs(botPos.Y - topPos.Y)
            local w = h * 0.6
            objs.box.Size = Vector2.new(w, h)
            objs.box.Position = Vector2.new((topPos.X + botPos.X)/2 - w/2, topPos.Y)
            objs.box.Color = occluded and Color3.fromRGB(200,50,50) or ACCENT
        end
    end

    if objs.nameLabel then
        objs.nameLabel.Visible = Settings.ESP and Settings.ESPNames and visible
        if visible then
            objs.nameLabel.Position = UDim2.new(0, topPos.X - 50, 0, topPos.Y - 18)
        end
    end

    if objs.distLabel then
        objs.distLabel.Visible = Settings.ESP and Settings.ESPDistance and visible
        if visible then
            objs.distLabel.Text = math.floor((hrp.Position - Camera.CFrame.Position).Magnitude) .. "m"
            objs.distLabel.Position = UDim2.new(0, botPos.X - 50, 0, botPos.Y + 2)
        end
    end

    if objs.healthBG and humanoid then
        local h = math.abs(botPos.Y - topPos.Y)
        local w = h * 0.6
        local cx = (topPos.X + botPos.X) / 2
        objs.healthBG.Visible = Settings.ESP and Settings.ESPHealth and visible
        objs.healthBG.Position = UDim2.new(0, cx - w/2 - 6, 0, topPos.Y)
        objs.healthBG.Size = UDim2.new(0, 4, 0, h)
        local pct = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
        objs.healthFill.Size = UDim2.new(1, 0, pct, 0)
        objs.healthFill.Position = UDim2.new(0, 0, 1 - pct, 0)
        objs.healthFill.BackgroundColor3 = Color3.fromRGB(math.floor(255*(1-pct)), math.floor(255*pct), 0)
    end

    if objs.chams then
        objs.chams.Enabled = Settings.Chams
        if Settings.Chams then
            objs.chams.Adornee = char
            local col = occluded and Settings.ChamsOccludedColor or Settings.ChamsVisibleColor
            objs.chams.FillColor = col
            objs.chams.OutlineColor = col
            objs.chams.FillTransparency = occluded and (1 - Settings.ChamsAlpha*0.5) or (1 - Settings.ChamsAlpha)
        else
            objs.chams.Adornee = nil
        end
    end
end


-- GUI
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 520, 0, 380)
mainFrame.Position = UDim2.new(0, 100, 0, 100)
mainFrame.BackgroundColor3 = Color3.fromRGB(18,18,18)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = ScreenGui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 8)
local border = Instance.new("UIStroke", mainFrame)
border.Color = ACCENT; border.Thickness = 1.5; border.Transparency = 0.5

local title = Instance.new("TextLabel", mainFrame)
title.Size = UDim2.new(1, 0, 0, 36)
title.BackgroundColor3 = Color3.fromRGB(12,12,12)
title.BorderSizePixel = 0
title.Text = "OG RIVALS"
title.TextColor3 = ACCENT
title.TextSize = 16
title.Font = Enum.Font.GothamBold
Instance.new("UICorner", title).CornerRadius = UDim.new(0, 8)

local sidebar = Instance.new("Frame", mainFrame)
sidebar.Size = UDim2.new(0, 120, 1, -36)
sidebar.Position = UDim2.new(0, 0, 0, 36)
sidebar.BackgroundColor3 = Color3.fromRGB(22,22,22)
sidebar.BorderSizePixel = 0

local content = Instance.new("Frame", mainFrame)
content.Size = UDim2.new(1, -130, 1, -46)
content.Position = UDim2.new(0, 125, 0, 41)
content.BackgroundTransparency = 1

local tabs, tabButtons = {}, {}

local function makeTab(name)
    local f = Instance.new("ScrollingFrame", content)
    f.Name = name; f.Size = UDim2.new(1,0,1,0)
    f.BackgroundTransparency = 1; f.BorderSizePixel = 0
    f.ScrollBarThickness = 3; f.ScrollBarImageColor3 = ACCENT
    f.Visible = false
    local l = Instance.new("UIListLayout", f)
    l.Padding = UDim.new(0, 8); l.SortOrder = Enum.SortOrder.LayoutOrder
    tabs[name] = f
end

local function makeTabBtn(name, order)
    local btn = Instance.new("TextButton", sidebar)
    btn.Size = UDim2.new(1,-10,0,32)
    btn.Position = UDim2.new(0,5,0,10+(order-1)*38)
    btn.BackgroundColor3 = Color3.fromRGB(30,30,30)
    btn.BorderSizePixel = 0; btn.Text = name
    btn.TextColor3 = Color3.fromRGB(180,180,180)
    btn.TextSize = 13; btn.Font = Enum.Font.GothamSemibold
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,5)
    tabButtons[name] = btn
    btn.MouseButton1Click:Connect(function()
        for n,f in pairs(tabs) do f.Visible = n==name end
        for n,b in pairs(tabButtons) do
            b.BackgroundColor3 = n==name and Color3.fromRGB(40,55,20) or Color3.fromRGB(30,30,30)
            b.TextColor3 = n==name and ACCENT or Color3.fromRGB(180,180,180)
        end
    end)
end

local function makeToggle(parent, label, setting, order)
    local row = Instance.new("Frame", parent)
    row.Size = UDim2.new(1,-10,0,28); row.BackgroundTransparency = 1; row.LayoutOrder = order
    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(0.7,0,1,0); lbl.BackgroundTransparency = 1
    lbl.Text = label; lbl.TextColor3 = Color3.new(1,1,1)
    lbl.TextSize = 13; lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    local btn = Instance.new("TextButton", row)
    btn.Size = UDim2.new(0,44,0,22); btn.Position = UDim2.new(1,-44,0.5,-11)
    btn.BorderSizePixel = 0; btn.TextSize = 11; btn.Font = Enum.Font.GothamBold
    Instance.new("UICorner", btn).CornerRadius = UDim.new(1,0)
    local function refresh()
        local on = Settings[setting]
        btn.BackgroundColor3 = on and ACCENT or Color3.fromRGB(50,50,50)
        btn.TextColor3 = on and Color3.fromRGB(20,20,20) or Color3.fromRGB(150,150,150)
        btn.Text = on and "ON" or "OFF"
    end
    refresh()
    btn.MouseButton1Click:Connect(function() Settings[setting] = not Settings[setting]; refresh() end)
end

local function makeSlider(parent, label, setting, min, max, order)
    local row = Instance.new("Frame", parent)
    row.Size = UDim2.new(1,-10,0,44); row.BackgroundTransparency = 1; row.LayoutOrder = order
    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(1,0,0,16); lbl.BackgroundTransparency = 1
    lbl.Text = label..": "..math.floor(Settings[setting])
    lbl.TextColor3 = Color3.new(1,1,1); lbl.TextSize = 12; lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    local track = Instance.new("Frame", row)
    track.Size = UDim2.new(1,0,0,10); track.Position = UDim2.new(0,0,0,22)
    track.BackgroundColor3 = Color3.fromRGB(40,40,40); track.BorderSizePixel = 0
    Instance.new("UICorner", track).CornerRadius = UDim.new(1,0)
    local fill = Instance.new("Frame", track)
    fill.BackgroundColor3 = ACCENT; fill.BorderSizePixel = 0
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1,0)
    local function setVal(v)
        v = math.clamp(v, min, max)
        Settings[setting] = v
        lbl.Text = label..": "..math.floor(v)
        fill.Size = UDim2.new((v-min)/(max-min),0,1,0)
    end
    setVal(Settings[setting])
    local dragging = false
    track.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true end end)
    UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
            local pct = math.clamp((i.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
            setVal(min + (max-min)*pct)
        end
    end)
end

makeTab("Visuals"); makeTab("Combat"); makeTab("Misc")
makeTabBtn("Visuals",1); makeTabBtn("Combat",2); makeTabBtn("Misc",3)

local vt = tabs["Visuals"]
makeToggle(vt,"ESP","ESP",1); makeToggle(vt,"ESP Boxes","ESPBoxes",2)
makeToggle(vt,"ESP Names","ESPNames",3); makeToggle(vt,"ESP Distance","ESPDistance",4)
makeToggle(vt,"ESP Health","ESPHealth",5); makeToggle(vt,"Chams","Chams",6)
makeSlider(vt,"Chams Alpha","ChamsAlpha",0.1,1.0,7)
makeSlider(vt,"Viewmodel FOV","ViewmodelFOV",60,120,8)

local ct = tabs["Combat"]
makeToggle(ct,"Aimbot","Aimbot",1); makeToggle(ct,"Show FOV","ShowFOV",2)
makeSlider(ct,"FOV","FOV",10,600,3); makeSlider(ct,"Smoothness","Smoothness",0.1,5,4)

local mt = tabs["Misc"]
makeToggle(mt,"Noclip","Noclip",1); makeToggle(mt,"Infinite Jump","InfiniteJump",2)
makeToggle(mt,"No Flash","NoFlash",3); makeToggle(mt,"No Smoke","NoSmoke",4)

tabs["Visuals"].Visible = true
tabButtons["Visuals"].BackgroundColor3 = Color3.fromRGB(40,55,20)
tabButtons["Visuals"].TextColor3 = ACCENT

UserInputService.InputBegan:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.Insert then
        mainFrame.Visible = not mainFrame.Visible
    end
end)

-- Noclip: sadece character değişince parts'ı cache'le
local noclipParts = {}
local function cacheNoclipParts()
    noclipParts = {}
    if LocalPlayer.Character then
        for _, p in ipairs(LocalPlayer.Character:GetDescendants()) do
            if p:IsA("BasePart") then noclipParts[#noclipParts+1] = p end
        end
    end
end
LocalPlayer.CharacterAdded:Connect(function() task.wait(0.5); cacheNoclipParts() end)
cacheNoclipParts()

RunService.Stepped:Connect(function()
    if Settings.Noclip then
        for _, p in ipairs(noclipParts) do
            if p and p.Parent then p.CanCollide = false end
        end
    end
end)

-- Infinite Jump
UserInputService.JumpRequest:Connect(function()
    if Settings.InfiniteJump and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

-- No Flash: event-based only, no per-frame scan
Lighting.ChildAdded:Connect(function(child)
    if not Settings.NoFlash then return end
    task.wait()
    if child:IsA("ColorCorrectionEffect") then
        child.Brightness=0; child.Contrast=0; child.Saturation=0; child.TintColor=Color3.new(1,1,1)
    elseif child:IsA("BlurEffect") then child.Size=0
    elseif child:IsA("SunRaysEffect") then child.Intensity=0 end
end)

local playerGui = LocalPlayer:WaitForChild("PlayerGui")
local function hookFlash(obj)
    if not Settings.NoFlash then return end
    if (obj:IsA("Frame") or obj:IsA("ImageLabel")) and obj.Size.X.Scale >= 0.8 and obj.Size.Y.Scale >= 0.8 then
        local c = obj.BackgroundColor3
        if (c.R+c.G+c.B)/3 > 0.6 and obj.BackgroundTransparency < 0.6 then
            obj.BackgroundTransparency = 1; obj.Visible = false
        end
    end
end
playerGui.DescendantAdded:Connect(function(obj) task.wait(); hookFlash(obj) end)

-- No Smoke: event-based only
local smokeKeywords = {"smoke","flash","grenade","nade","smk"}
local function handleSmoke(obj)
    if not Settings.NoSmoke then return end
    local name = obj.Name:lower()
    local match = false
    for _, kw in ipairs(smokeKeywords) do if name:find(kw) then match=true; break end end
    if not match and obj:IsA("BasePart") then
        for _, ch in ipairs(obj:GetChildren()) do
            if ch:IsA("Smoke") or ch:IsA("Fire") or ch:IsA("ParticleEmitter") then match=true; break end
        end
    end
    if match then
        for _, ch in ipairs(obj:GetDescendants()) do
            if ch:IsA("Smoke") then ch.Opacity=0; ch.Enabled=false
            elseif ch:IsA("ParticleEmitter") then ch.Enabled=false; ch.Transparency=NumberSequence.new(1)
            elseif ch:IsA("Fire") then ch.Enabled=false end
        end
        if obj:IsA("BasePart") then obj.Transparency=1; obj.CastShadow=false end
    end
end
workspace.DescendantAdded:Connect(function(obj) task.wait(); handleSmoke(obj) end)

-- Player hooks
local function onPlayerAdded(player)
    player.CharacterAdded:Connect(function() task.wait(1); createESP(player) end)
    if player.Character then task.wait(1); createESP(player) end
end
for _, p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer then onPlayerAdded(p) end end
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(removeESP)

-- Main loop (lean)
RunService.RenderStepped:Connect(function()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then updateESP(p) end
    end

    Camera.FieldOfView = Settings.ViewmodelFOV

    fovCircle.Visible = Settings.Aimbot and Settings.ShowFOV
    fovCircle.Radius = Settings.FOV
    fovCircle.Position = UserInputService:GetMouseLocation()

    if Settings.Aimbot and UserInputService:IsMouseButtonPressed(Settings.AimbotKey) then
        local target = getAimbotTarget()
        if target then
            local pos = Camera:WorldToViewportPoint(target.Position)
            local mouse = UserInputService:GetMouseLocation()
            if mousemoverel then
                mousemoverel((pos.X-mouse.X)*Settings.Smoothness, (pos.Y-mouse.Y)*Settings.Smoothness)
            end
        end
    end
end)
