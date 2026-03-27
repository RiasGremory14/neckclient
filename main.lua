-- OG Rivals Script | Roblox
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local Settings = {
    ESP = true, ESPBoxes = true, ESPNames = true, ESPDistance = true, ESPHealth = true,
    Chams = true,
    ChamsVisibleColor = Color3.fromRGB(150, 200, 60),
    ChamsOccludedColor = Color3.fromRGB(200, 50, 50),
    ChamsAlpha = 0.4,
    Aimbot = true, Smoothness = 1, FOV = 150, ShowFOV = true,
    AimbotKey = Enum.UserInputType.MouseButton2,
    ViewmodelFOV = 70,
    MenuKey = Enum.KeyCode.Insert,
    Noclip = false, InfiniteJump = false,
    Fly = false, FlySpeed = 50,
    NoFlash = true, NoSmoke = true,
}

local ACCENT = Color3.fromRGB(150, 200, 60)

-- Helpers
local function isAlive(p)
    local c = p.Character
    if not c then return false end
    local h = c:FindFirstChildWhichIsA("Humanoid")
    return h and h.Health > 0
end

local function getHRP(c)
    return c:FindFirstChild("HumanoidRootPart") or c:FindFirstChildWhichIsA("BasePart")
end

local function getHead(c)
    return c:FindFirstChild("HeadHB") or c:FindFirstChild("Head") or getHRP(c)
end

local function toScreen(pos)
    local ok, s, on = pcall(Camera.WorldToViewportPoint, Camera, pos)
    if not ok then return Vector2.new(), false end
    return Vector2.new(s.X, s.Y), on
end

-- Occlude cache
local occCache, occTime = {}, {}
local function isOccluded(c)
    local now = tick()
    if occTime[c] and now - occTime[c] < 0.1 then return occCache[c] end
    local hrp = getHRP(c)
    if not hrp then return true end
    local ok, hit = pcall(function()
        return workspace:FindPartOnRayWithIgnoreList(
            Ray.new(Camera.CFrame.Position, hrp.Position - Camera.CFrame.Position),
            {c, LocalPlayer.Character}
        )
    end)
    occCache[c] = ok and hit ~= nil or false
    occTime[c] = now
    return occCache[c]
end

-- FOV circle
local fovCircle = Drawing.new("Circle")
fovCircle.Thickness = 2; fovCircle.Filled = false
fovCircle.Color = ACCENT; fovCircle.Transparency = 0.6

-- Aimbot
local function getTarget()
    local mouse = UserInputService:GetMouseLocation()
    local best, bd = nil, Settings.FOV
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and isAlive(p) then
            local part = getHead(p.Character)
            if part then
                local ok, s, on = pcall(Camera.WorldToViewportPoint, Camera, part.Position)
                if ok and on then
                    local d = (Vector2.new(s.X, s.Y) - mouse).Magnitude
                    if d < bd then bd = d; best = part end
                end
            end
        end
    end
    return best
end

-- ScreenGui
local gui = Instance.new("ScreenGui")
gui.Name = "OGRivals"; gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = game:GetService("CoreGui")

local drawFolder = Instance.new("Folder", gui)

-- ESP
local espObjs = {}

local function removeESP(p)
    if not espObjs[p] then return end
    for _, o in pairs(espObjs[p]) do pcall(function() o:Destroy() end) end
    espObjs[p] = nil
end

local function createESP(p)
    if p == LocalPlayer then return end
    removeESP(p)
    local folder = Instance.new("Folder", drawFolder)
    local t = {}

    local nl = Instance.new("TextLabel", folder)
    nl.BackgroundTransparency=1; nl.TextColor3=Color3.new(1,1,1)
    nl.TextStrokeTransparency=0.5; nl.TextSize=13; nl.Font=Enum.Font.GothamBold
    nl.Text=p.Name; nl.Size=UDim2.new(0,100,0,16); nl.Visible=false
    t.nl = nl

    local dl = Instance.new("TextLabel", folder)
    dl.BackgroundTransparency=1; dl.TextColor3=Color3.fromRGB(200,200,200)
    dl.TextStrokeTransparency=0.5; dl.TextSize=11; dl.Font=Enum.Font.Gotham
    dl.Size=UDim2.new(0,100,0,14); dl.Visible=false
    t.dl = dl

    local hbg = Instance.new("Frame", folder)
    hbg.BackgroundColor3=Color3.fromRGB(30,30,30); hbg.BorderSizePixel=0; hbg.Visible=false
    t.hbg = hbg
    local hfill = Instance.new("Frame", hbg)
    hfill.BackgroundColor3=Color3.fromRGB(100,220,60); hfill.BorderSizePixel=0
    t.hfill = hfill

    local box = Drawing.new("Square")
    box.Thickness=1.5; box.Filled=false; box.Color=ACCENT; box.Visible=false
    t.box = box

    local hl = Instance.new("Highlight", folder)
    hl.FillColor=Settings.ChamsVisibleColor; hl.OutlineColor=Settings.ChamsVisibleColor
    hl.FillTransparency=1-Settings.ChamsAlpha; hl.OutlineTransparency=0
    hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop; hl.Enabled=false
    t.hl = hl

    espObjs[p] = t
end

local function updateESP(p)
    local t = espObjs[p]
    if not t then return end
    local char = p.Character
    local alive = char and isAlive(p)

    if not alive then
        t.nl.Visible=false; t.dl.Visible=false; t.hbg.Visible=false
        t.box.Visible=false; t.hl.Enabled=false
        return
    end

    local hrp = getHRP(char)
    local head = getHead(char)
    local hum = char:FindFirstChildWhichIsA("Humanoid")
    if not hrp then return end

    local headPos = head and head.Position or hrp.Position + Vector3.new(0,2,0)
    local top, topOn = toScreen(headPos + Vector3.new(0,0.7,0))
    local bot, botOn = toScreen(hrp.Position - Vector3.new(0,3,0))
    local vis = topOn or botOn
    local occ = isOccluded(char)

    -- box
    t.box.Visible = Settings.ESP and Settings.ESPBoxes and vis
    if vis then
        local h = math.abs(bot.Y - top.Y)
        local w = h * 0.6
        t.box.Size = Vector2.new(w, h)
        t.box.Position = Vector2.new((top.X+bot.X)/2 - w/2, top.Y)
        t.box.Color = occ and Color3.fromRGB(200,50,50) or ACCENT
    end

    -- name
    t.nl.Visible = Settings.ESP and Settings.ESPNames and vis
    if vis then t.nl.Position = UDim2.new(0, top.X-50, 0, top.Y-18) end

    -- dist
    t.dl.Visible = Settings.ESP and Settings.ESPDistance and vis
    if vis then
        t.dl.Text = math.floor((hrp.Position - Camera.CFrame.Position).Magnitude).."m"
        t.dl.Position = UDim2.new(0, bot.X-50, 0, bot.Y+2)
    end

    -- health
    if hum then
        local h = math.abs(bot.Y - top.Y)
        local w = h * 0.6
        local cx = (top.X+bot.X)/2
        t.hbg.Visible = Settings.ESP and Settings.ESPHealth and vis
        t.hbg.Position = UDim2.new(0, cx-w/2-6, 0, top.Y)
        t.hbg.Size = UDim2.new(0, 4, 0, h)
        local pct = math.clamp(hum.Health/hum.MaxHealth, 0, 1)
        t.hfill.Size = UDim2.new(1,0,pct,0)
        t.hfill.Position = UDim2.new(0,0,1-pct,0)
        t.hfill.BackgroundColor3 = Color3.fromRGB(math.floor(255*(1-pct)), math.floor(255*pct), 0)
    end

    -- chams
    t.hl.Enabled = Settings.Chams
    if Settings.Chams then
        t.hl.Adornee = char
        local col = occ and Settings.ChamsOccludedColor or Settings.ChamsVisibleColor
        t.hl.FillColor = col; t.hl.OutlineColor = col
        t.hl.FillTransparency = occ and (1-Settings.ChamsAlpha*0.5) or (1-Settings.ChamsAlpha)
    else
        t.hl.Adornee = nil
    end
end

-- GUI
local mainFrame = Instance.new("Frame", gui)
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0,520,0,380)
mainFrame.Position = UDim2.new(0,100,0,100)
mainFrame.BackgroundColor3 = Color3.fromRGB(18,18,18)
mainFrame.BorderSizePixel = 0; mainFrame.Active = true; mainFrame.Draggable = true
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0,8)
local bs = Instance.new("UIStroke", mainFrame)
bs.Color=ACCENT; bs.Thickness=1.5; bs.Transparency=0.5

local titleLbl = Instance.new("TextLabel", mainFrame)
titleLbl.Size=UDim2.new(1,0,0,36); titleLbl.BackgroundColor3=Color3.fromRGB(12,12,12)
titleLbl.BorderSizePixel=0; titleLbl.Text="OG RIVALS"; titleLbl.TextColor3=ACCENT
titleLbl.TextSize=16; titleLbl.Font=Enum.Font.GothamBold
Instance.new("UICorner", titleLbl).CornerRadius=UDim.new(0,8)

local sidebar = Instance.new("Frame", mainFrame)
sidebar.Size=UDim2.new(0,120,1,-36); sidebar.Position=UDim2.new(0,0,0,36)
sidebar.BackgroundColor3=Color3.fromRGB(22,22,22); sidebar.BorderSizePixel=0

local content = Instance.new("Frame", mainFrame)
content.Size=UDim2.new(1,-130,1,-46); content.Position=UDim2.new(0,125,0,41)
content.BackgroundTransparency=1

local tabs, tabBtns = {}, {}

local function makeTab(name)
    local f = Instance.new("ScrollingFrame", content)
    f.Name=name; f.Size=UDim2.new(1,0,1,0); f.BackgroundTransparency=1
    f.BorderSizePixel=0; f.ScrollBarThickness=3; f.ScrollBarImageColor3=ACCENT; f.Visible=false
    local l = Instance.new("UIListLayout", f)
    l.Padding=UDim.new(0,8); l.SortOrder=Enum.SortOrder.LayoutOrder
    tabs[name] = f
end

local function makeTabBtn(name, i)
    local b = Instance.new("TextButton", sidebar)
    b.Size=UDim2.new(1,-10,0,32); b.Position=UDim2.new(0,5,0,10+(i-1)*38)
    b.BackgroundColor3=Color3.fromRGB(30,30,30); b.BorderSizePixel=0
    b.Text=name; b.TextColor3=Color3.fromRGB(180,180,180)
    b.TextSize=13; b.Font=Enum.Font.GothamSemibold
    Instance.new("UICorner", b).CornerRadius=UDim.new(0,5)
    tabBtns[name] = b
    b.MouseButton1Click:Connect(function()
        for n,f in pairs(tabs) do f.Visible = n==name end
        for n,btn in pairs(tabBtns) do
            btn.BackgroundColor3 = n==name and Color3.fromRGB(40,55,20) or Color3.fromRGB(30,30,30)
            btn.TextColor3 = n==name and ACCENT or Color3.fromRGB(180,180,180)
        end
    end)
end

local function makeToggle(parent, label, setting, order)
    local row = Instance.new("Frame", parent)
    row.Size=UDim2.new(1,-10,0,28); row.BackgroundTransparency=1; row.LayoutOrder=order
    local lbl = Instance.new("TextLabel", row)
    lbl.Size=UDim2.new(0.7,0,1,0); lbl.BackgroundTransparency=1; lbl.Text=label
    lbl.TextColor3=Color3.new(1,1,1); lbl.TextSize=13; lbl.Font=Enum.Font.Gotham
    lbl.TextXAlignment=Enum.TextXAlignment.Left
    local btn = Instance.new("TextButton", row)
    btn.Size=UDim2.new(0,44,0,22); btn.Position=UDim2.new(1,-44,0.5,-11)
    btn.BorderSizePixel=0; btn.TextSize=11; btn.Font=Enum.Font.GothamBold
    Instance.new("UICorner", btn).CornerRadius=UDim.new(1,0)
    local function refresh()
        local on = Settings[setting]
        btn.BackgroundColor3 = on and ACCENT or Color3.fromRGB(50,50,50)
        btn.TextColor3 = on and Color3.fromRGB(20,20,20) or Color3.fromRGB(150,150,150)
        btn.Text = on and "ON" or "OFF"
    end
    refresh()
    btn.MouseButton1Click:Connect(function() Settings[setting]=not Settings[setting]; refresh() end)
end

local function makeSlider(parent, label, setting, mn, mx, order)
    local row = Instance.new("Frame", parent)
    row.Size=UDim2.new(1,-10,0,44); row.BackgroundTransparency=1; row.LayoutOrder=order
    local lbl = Instance.new("TextLabel", row)
    lbl.Size=UDim2.new(1,0,0,16); lbl.BackgroundTransparency=1
    lbl.Text=label..": "..math.floor(Settings[setting])
    lbl.TextColor3=Color3.new(1,1,1); lbl.TextSize=12; lbl.Font=Enum.Font.Gotham
    lbl.TextXAlignment=Enum.TextXAlignment.Left
    local track = Instance.new("Frame", row)
    track.Size=UDim2.new(1,0,0,10); track.Position=UDim2.new(0,0,0,22)
    track.BackgroundColor3=Color3.fromRGB(40,40,40); track.BorderSizePixel=0
    Instance.new("UICorner", track).CornerRadius=UDim.new(1,0)
    local fill = Instance.new("Frame", track)
    fill.BackgroundColor3=ACCENT; fill.BorderSizePixel=0
    Instance.new("UICorner", fill).CornerRadius=UDim.new(1,0)
    local function setVal(v)
        v = math.clamp(v, mn, mx)
        Settings[setting] = v
        lbl.Text = label..": "..math.floor(v)
        fill.Size = UDim2.new((v-mn)/(mx-mn),0,1,0)
    end
    setVal(Settings[setting])
    local drag = false
    track.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=true end end)
    UserInputService.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=false end end)
    UserInputService.InputChanged:Connect(function(i)
        if drag and i.UserInputType==Enum.UserInputType.MouseMovement then
            setVal(mn+(mx-mn)*math.clamp((i.Position.X-track.AbsolutePosition.X)/track.AbsoluteSize.X,0,1))
        end
    end)
end

makeTab("Visuals"); makeTab("Combat"); makeTab("Misc")
makeTabBtn("Visuals",1); makeTabBtn("Combat",2); makeTabBtn("Misc",3)

local vt = tabs["Visuals"]
makeToggle(vt,"ESP","ESP",1); makeToggle(vt,"Boxes","ESPBoxes",2)
makeToggle(vt,"Names","ESPNames",3); makeToggle(vt,"Distance","ESPDistance",4)
makeToggle(vt,"Health","ESPHealth",5); makeToggle(vt,"Chams","Chams",6)
makeSlider(vt,"Chams Alpha","ChamsAlpha",0.1,1.0,7)
makeSlider(vt,"Viewmodel FOV","ViewmodelFOV",60,120,8)

local ct = tabs["Combat"]
makeToggle(ct,"Aimbot","Aimbot",1); makeToggle(ct,"Show FOV","ShowFOV",2)
makeSlider(ct,"FOV","FOV",10,600,3); makeSlider(ct,"Smoothness","Smoothness",0.1,5,4)

local mt = tabs["Misc"]
makeToggle(mt,"Noclip","Noclip",1); makeToggle(mt,"Infinite Jump","InfiniteJump",2)
makeToggle(mt,"Fly","Fly",3); makeSlider(mt,"Fly Speed","FlySpeed",10,200,4)
makeToggle(mt,"No Flash","NoFlash",5); makeToggle(mt,"No Smoke","NoSmoke",6)

-- Menu keybind
do
    local row = Instance.new("Frame", mt)
    row.Size=UDim2.new(1,-10,0,50); row.BackgroundTransparency=1; row.LayoutOrder=7
    local lbl = Instance.new("TextLabel", row)
    lbl.Size=UDim2.new(1,0,0,16); lbl.BackgroundTransparency=1
    lbl.Text="Menu Key: "..Settings.MenuKey.Name
    lbl.TextColor3=Color3.new(1,1,1); lbl.TextSize=13; lbl.Font=Enum.Font.Gotham
    lbl.TextXAlignment=Enum.TextXAlignment.Left
    local bb = Instance.new("TextButton", row)
    bb.Size=UDim2.new(1,0,0,26); bb.Position=UDim2.new(0,0,0,20)
    bb.BackgroundColor3=Color3.fromRGB(35,35,35); bb.BorderSizePixel=0
    bb.Text=Settings.MenuKey.Name; bb.TextColor3=Color3.fromRGB(180,180,180)
    bb.TextSize=12; bb.Font=Enum.Font.Gotham
    Instance.new("UICorner", bb).CornerRadius=UDim.new(0,4)
    local binding = false
    bb.MouseButton1Click:Connect(function()
        if binding then return end
        binding=true; bb.Text="[ Press any key ]"; bb.TextColor3=ACCENT
        local conn
        conn = UserInputService.InputBegan:Connect(function(inp)
            if inp.UserInputType ~= Enum.UserInputType.Keyboard then return end
            local skip = {Enum.KeyCode.LeftShift,Enum.KeyCode.RightShift,
                Enum.KeyCode.LeftControl,Enum.KeyCode.RightControl,
                Enum.KeyCode.LeftAlt,Enum.KeyCode.RightAlt}
            for _,k in ipairs(skip) do if inp.KeyCode==k then return end end
            Settings.MenuKey=inp.KeyCode
            lbl.Text="Menu Key: "..inp.KeyCode.Name
            bb.Text=inp.KeyCode.Name; bb.TextColor3=Color3.fromRGB(180,180,180)
            binding=false; conn:Disconnect()
        end)
    end)
end

tabs["Visuals"].Visible=true
tabBtns["Visuals"].BackgroundColor3=Color3.fromRGB(40,55,20)
tabBtns["Visuals"].TextColor3=ACCENT

-- Toggle menu
UserInputService.InputBegan:Connect(function(inp)
    if inp.KeyCode == Settings.MenuKey then
        mainFrame.Visible = not mainFrame.Visible
    end
end)

-- Noclip
local noclipParts = {}
local function cacheNC()
    noclipParts = {}
    if LocalPlayer.Character then
        for _, p in ipairs(LocalPlayer.Character:GetDescendants()) do
            if p:IsA("BasePart") then noclipParts[#noclipParts+1]=p end
        end
    end
end
LocalPlayer.CharacterAdded:Connect(function() task.wait(0.5); cacheNC() end)
cacheNC()
RunService.Stepped:Connect(function()
    if not Settings.Noclip then return end
    for _, p in ipairs(noclipParts) do
        if p and p.Parent then p.CanCollide=false end
    end
end)

-- Infinite Jump
UserInputService.JumpRequest:Connect(function()
    if not Settings.InfiniteJump then return end
    local c = LocalPlayer.Character
    if c then
        local h = c:FindFirstChildOfClass("Humanoid")
        if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

-- Fly
local flyBV, flyBG
local function enableFly()
    local c = LocalPlayer.Character; if not c then return end
    local hrp = getHRP(c); if not hrp then return end
    local h = c:FindFirstChildOfClass("Humanoid")
    if h then h.PlatformStand=true end
    flyBV = Instance.new("BodyVelocity", hrp)
    flyBV.Velocity=Vector3.zero; flyBV.MaxForce=Vector3.new(1e5,1e5,1e5)
    flyBG = Instance.new("BodyGyro", hrp)
    flyBG.MaxTorque=Vector3.new(1e5,1e5,1e5); flyBG.D=100; flyBG.CFrame=hrp.CFrame
end
local function disableFly()
    if flyBV then flyBV:Destroy(); flyBV=nil end
    if flyBG then flyBG:Destroy(); flyBG=nil end
    local c = LocalPlayer.Character
    if c then local h=c:FindFirstChildOfClass("Humanoid"); if h then h.PlatformStand=false end end
end
local lastFly = false
RunService.Heartbeat:Connect(function()
    if Settings.Fly ~= lastFly then
        lastFly=Settings.Fly
        if Settings.Fly then enableFly() else disableFly() end
    end
    if not Settings.Fly or not flyBV or not flyBG then return end
    local c = LocalPlayer.Character; if not c then return end
    local hrp = getHRP(c); if not hrp then return end
    local cf = Camera.CFrame
    local dir = Vector3.zero
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir=dir+cf.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir=dir-cf.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir=dir-cf.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir=dir+cf.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir=dir+Vector3.new(0,1,0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir=dir-Vector3.new(0,1,0) end
    flyBV.Velocity = dir.Magnitude>0 and dir.Unit*Settings.FlySpeed or Vector3.zero
    flyBG.CFrame = CFrame.new(hrp.Position, hrp.Position+cf.LookVector)
end)
LocalPlayer.CharacterAdded:Connect(function()
    flyBV=nil; flyBG=nil; task.wait(1)
    if Settings.Fly then enableFly() end
    task.wait(0.5); cacheNC()
end)

-- No Flash
Lighting.ChildAdded:Connect(function(child)
    if not Settings.NoFlash then return end
    task.wait()
    if child:IsA("ColorCorrectionEffect") then
        child.Brightness=0;child.Contrast=0;child.Saturation=0;child.TintColor=Color3.new(1,1,1)
    elseif child:IsA("BlurEffect") then child.Size=0
    elseif child:IsA("SunRaysEffect") then child.Intensity=0 end
end)
local playerGui = LocalPlayer:WaitForChild("PlayerGui")
playerGui.DescendantAdded:Connect(function(obj)
    if not Settings.NoFlash then return end
    task.wait()
    if (obj:IsA("Frame") or obj:IsA("ImageLabel"))
        and obj.Size.X.Scale>=0.8 and obj.Size.Y.Scale>=0.8 then
        local c=obj.BackgroundColor3
        if (c.R+c.G+c.B)/3>0.6 and obj.BackgroundTransparency<0.6 then
            obj.BackgroundTransparency=1; obj.Visible=false
        end
    end
end)

-- No Smoke
local smokeKW = {"smoke","flash","grenade","nade","smk"}
workspace.DescendantAdded:Connect(function(obj)
    if not Settings.NoSmoke then return end
    task.wait()
    local name = obj.Name:lower()
    local hit = false
    for _,kw in ipairs(smokeKW) do if name:find(kw) then hit=true; break end end
    if not hit and obj:IsA("BasePart") then
        for _,ch in ipairs(obj:GetChildren()) do
            if ch:IsA("Smoke") or ch:IsA("Fire") or ch:IsA("ParticleEmitter") then hit=true; break end
        end
    end
    if hit then
        for _,ch in ipairs(obj:GetDescendants()) do
            if ch:IsA("Smoke") then ch.Opacity=0;ch.Enabled=false
            elseif ch:IsA("ParticleEmitter") then ch.Enabled=false;ch.Transparency=NumberSequence.new(1)
            elseif ch:IsA("Fire") then ch.Enabled=false end
        end
        if obj:IsA("BasePart") then obj.Transparency=1;obj.CastShadow=false end
    end
end)

-- Player hooks
local function onAdded(p)
    p.CharacterAdded:Connect(function() task.wait(1); createESP(p) end)
    if p.Character then task.wait(1); createESP(p) end
end
for _,p in ipairs(Players:GetPlayers()) do if p~=LocalPlayer then onAdded(p) end end
Players.PlayerAdded:Connect(onAdded)
Players.PlayerRemoving:Connect(removeESP)

-- Main loop
RunService.RenderStepped:Connect(function()
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LocalPlayer then updateESP(p) end
    end
    Camera.FieldOfView = Settings.ViewmodelFOV
    fovCircle.Visible = Settings.Aimbot and Settings.ShowFOV
    fovCircle.Radius = Settings.FOV
    fovCircle.Position = UserInputService:GetMouseLocation()
    if Settings.Aimbot and UserInputService:IsMouseButtonPressed(Settings.AimbotKey) then
        local tgt = getTarget()
        if tgt then
            local s = Camera:WorldToViewportPoint(tgt.Position)
            local m = UserInputService:GetMouseLocation()
            if mousemoverel then
                mousemoverel((s.X-m.X)*Settings.Smoothness, (s.Y-m.Y)*Settings.Smoothness)
            end
        end
    end
end)
