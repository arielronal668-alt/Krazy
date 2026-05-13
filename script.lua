-- ============================================================
--  capitan Hub  |  by deluxe
-- ============================================================

local Success, Rayfield = pcall(function()
    return loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
end)

if not Success or not Rayfield then return end

-- ============================================================
--  SERVICES
-- ============================================================

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local CoreGui           = game:GetService("CoreGui")

local lp     = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- ============================================================
--  GLOBAL STATE
-- ============================================================

getgenv().SelectedPlayer    = nil
getgenv().TrackingActive    = false
getgenv().KillTrackerActive = false
getgenv().TPDirectActive    = false
getgenv().FastAttackEnabled = false
getgenv().FastAttackRange   = 5000
getgenv().SkyTrackerActive  = false
getgenv().TrackerHeight     = 300
getgenv().InstaTPSkyHeight  = 15
getgenv().InstaTPSkyActive  = false
getgenv().onenabledshotho   = false
getgenv().AutoSkillsEnabled = false
getgenv().OneShotEnabled    = false
getgenv().WalkOnWater       = false
getgenv().AntiArrest        = false
getgenv().NoclipEnabled     = false
getgenv().SpinEnabled       = false
getgenv().SpinSpeed         = 50
getgenv().MagnetEnabled     = false
getgenv().MagnetRange       = 800
getgenv().MagnetDistance    = 6
getgenv().PullForce         = 0.7

_G.WalkSpeedValue     = 40
_G.WalkSpeedEnabled   = false
_G.JumpPowerValue     = 50
_G.JumpPowerEnabled   = false
_G.AntiStunConnection = nil

-- ============================================================
--  LOCAL STATE
-- ============================================================

local skyConnection        = nil
local DashEnabled          = false
local DashConnection       = nil
local DashLenghDistance420 = 1
local autoV4               = false
local v4Connection         = nil
local GhostTpEnabled       = false
local GhostTpConnection    = nil
local ghostFrameCounter    = 0
local GHOST_RATIO          = 2
local GhostCFrame          = nil
local BlinkMode            = false
local TrackTargetPart      = "HumanoidRootPart"
local XOffset, YOffset, ZOffset = 0, 1.5, 3.5
local flying               = false
local flySpeed             = 60
local bv, bg
local ESPEnabled   = false
local ESPObjects   = {}
local ESPColor     = Color3.new(0, 1, 1)   -- cyan por defecto

-- ============================================================
--  UTILITY
-- ============================================================

local function TpTo(cframe)
    local root = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
    if root then root.CFrame = cframe end
end

local function GetNearestPlayer()
    local nearest, dist = nil, math.huge
    if not lp.Character or not lp.Character:FindFirstChild("HumanoidRootPart") then return nil end
    for _, v in pairs(Players:GetPlayers()) do
        if v ~= lp and v.Character and v.Character:FindFirstChild("HumanoidRootPart") then
            local d = (lp.Character.HumanoidRootPart.Position - v.Character.HumanoidRootPart.Position).Magnitude
            if d < dist then dist = d; nearest = v end
        end
    end
    return nearest
end

local function UpdatePlayerList()
    local n = {}
    for _, v in pairs(Players:GetPlayers()) do
        if v ~= lp then table.insert(n, v.Name) end
    end
    return #n == 0 and {"None"} or n
end

local function ToggleSpectate(state)
    if state and getgenv().SelectedPlayer then
        local target = Players:FindFirstChild(getgenv().SelectedPlayer)
        if target and target.Character and target.Character:FindFirstChild("Humanoid") then
            Camera.CameraSubject = target.Character.Humanoid
        end
    else
        if lp.Character and lp.Character:FindFirstChild("Humanoid") then
            Camera.CameraSubject = lp.Character.Humanoid
        end
    end
end

-- ============================================================
--  ESP
-- ============================================================

local function ClearESP()
    for _, obj in pairs(ESPObjects) do
        if obj then obj:Destroy() end
    end
    ESPObjects = {}
end

local function CreateESP(target)
    if not target or not target:FindFirstChild("Head") or target.Head:FindFirstChild("YeoESP") then return end

    local billboard       = Instance.new("BillboardGui", target.Head)
    billboard.Name        = "YeoESP"
    billboard.Adornee     = target.Head
    billboard.Size        = UDim2.new(0, 100, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true

    local label                  = Instance.new("TextLabel", billboard)
    label.BackgroundTransparency = 1
    label.Size                   = UDim2.new(1, 0, 1, 0)
    label.Font                   = "GothamBold"
    label.TextSize               = 13
    label.TextStrokeTransparency = 0.5
    label.TextColor3             = ESPColor

    task.spawn(function()
        while billboard and billboard.Parent and ESPEnabled do
            pcall(function()
                local dist = math.floor(
                    (Players.LocalPlayer.Character.HumanoidRootPart.Position
                     - target.HumanoidRootPart.Position).Magnitude
                )
                label.Text = target.Name .. "\n[" .. dist .. "s]"
            end)
            task.wait(0.5)
        end
        if billboard then billboard:Destroy() end
    end)

    table.insert(ESPObjects, billboard)
end

local function UpdateESP()
    ClearESP()
    if not ESPEnabled then return end
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= Players.LocalPlayer and p.Character then CreateESP(p.Character) end
    end
    local enemies = workspace:FindFirstChild("Enemies")
    if enemies then
        for _, npc in pairs(enemies:GetChildren()) do CreateESP(npc) end
    end
end

-- ============================================================
--  FLIGHT
-- ============================================================

local function stopFlying()
    flying = false
    if bv then bv:Destroy(); bv = nil end
    if bg then bg:Destroy(); bg = nil end
    pcall(function()
        if lp.Character then
            local hum = lp.Character:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.PlatformStand = false
                hum:ChangeState(Enum.HumanoidStateType.GettingUp)
            end
            local anim = lp.Character:FindFirstChild("Animate")
            if anim then anim.Disabled = false end
        end
    end)
end

local function startFlying()
    local char = lp.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end

    getgenv().InstaTPSkyActive = false
    stopFlying()
    flying = true

    local root = char.HumanoidRootPart
    local hum  = char:FindFirstChildOfClass("Humanoid")

    -- NO usamos PlatformStand â€” es lo que causaba que cayeras al piso
    -- Desactivamos la animacion para evitar glitches visuales
    local anim = char:FindFirstChild("Animate")
    if anim then anim.Disabled = true end

    -- BodyGyro: mantiene la orientacion en el aire sin que el personaje caiga
    bg             = Instance.new("BodyGyro", root)
    bg.D           = 100
    bg.P           = 9e4
    bg.MaxTorque   = Vector3.new(9e9, 9e9, 9e9)
    bg.CFrame      = root.CFrame

    -- BodyVelocity: mueve el personaje, MaxForce alto para anular gravedad
    bv             = Instance.new("BodyVelocity", root)
    bv.Velocity    = Vector3.zero
    bv.MaxForce    = Vector3.new(9e9, 9e9, 9e9)

    task.spawn(function()
        while flying and char.Parent and root.Parent do
            local cam    = workspace.CurrentCamera
            local camCF  = cam.CFrame

            -- Calcula velocidad horizontal segun WASD + direccion de camara
            local fwd   = Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z).Unit
            local right = Vector3.new(camCF.RightVector.X, 0, camCF.RightVector.Z).Unit
            local vel   = Vector3.zero

            if UserInputService:IsKeyDown(Enum.KeyCode.W) then vel = vel + fwd  * flySpeed end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then vel = vel - fwd  * flySpeed end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then vel = vel + right * flySpeed end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then vel = vel - right * flySpeed end

            local yVel = 0
            if UserInputService:IsKeyDown(Enum.KeyCode.Space)     then yVel =  flySpeed end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then yVel = -flySpeed end

            bv.Velocity = Vector3.new(vel.X, yVel, vel.Z)

            -- Orienta el cuerpo hacia donde mira la camara (eje Y)
            bg.CFrame = CFrame.new(root.Position)
                * CFrame.Angles(0, math.atan2(-camCF.LookVector.X, -camCF.LookVector.Z), 0)

            task.wait()
        end
        stopFlying()
    end)
end

-- ============================================================
--  GHOST-TP
-- ============================================================

local function StartGhostInstaTp()
    if GhostTpConnection then GhostTpConnection:Disconnect() end
    ghostFrameCounter = 0
    pcall(function()
        if not GhostCFrame then
            local hrp   = Players.LocalPlayer.Character
                and Players.LocalPlayer.Character:FindFirstChild(TrackTargetPart)
            GhostCFrame = hrp and hrp.CFrame or CFrame.new(0, 0, 0)
        end
    end)
    GhostTpConnection = RunService.Heartbeat:Connect(function()
        if not GhostTpEnabled or not getgenv().SelectedPlayer then return end
        pcall(function()
            local char      = Players.LocalPlayer.Character
            local target    = Players:FindFirstChild(getgenv().SelectedPlayer)
            if not (char and target and target.Character) then return end
            local hrp       = char:FindFirstChild("HumanoidRootPart")
            local targetHRP = target.Character:FindFirstChild(TrackTargetPart)
                or target.Character:FindFirstChild("HumanoidRootPart")
            if not (hrp and targetHRP) then return end
            ghostFrameCounter = ghostFrameCounter + 1
            local targetCF    = targetHRP.CFrame * CFrame.new(XOffset, YOffset, ZOffset)
            if BlinkMode then
                hrp.CFrame = targetCF
            elseif ghostFrameCounter % GHOST_RATIO == 0 then
                hrp.CFrame = GhostCFrame or targetCF
            else
                hrp.CFrame = targetCF
            end
        end)
    end)
end

-- ============================================================
--  DASH
-- ============================================================

local function EnableDash()
    DashEnabled    = true
    DashConnection = task.spawn(function()
        while DashEnabled do
            task.wait(0.1)
            local character = Players.LocalPlayer.Character
            if character then
                if character:GetAttribute("DashLength") ~= DashLenghDistance420 then
                    character:SetAttribute("DashLength",    DashLenghDistance420)
                    character:SetAttribute("DashLengthAir", DashLenghDistance420)
                end
            end
        end
    end)
end

local function DisableDash()
    DashEnabled = false
    if DashConnection then task.cancel(DashConnection); DashConnection = nil end
    local character = Players.LocalPlayer.Character
    if character then
        character:SetAttribute("DashLength",    1)
        character:SetAttribute("DashLengthAir", 1)
    end
end

-- ============================================================
--  MAGNET
-- ============================================================

local function IniciarMagneto()
    task.spawn(function()
        while true do
            task.wait(0.02)
            if getgenv().MagnetEnabled then
                local myHRP = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
                if not myHRP then continue end
                local function Atraer(entidad)
                    local eHRP = entidad:FindFirstChild("HumanoidRootPart")
                    local eHum = entidad:FindFirstChild("Humanoid")
                    if eHRP and eHum and eHum.Health > 0 then
                        local dist = (eHRP.Position - myHRP.Position).Magnitude
                        if dist <= getgenv().MagnetRange then
                            local targetPos = myHRP.CFrame * CFrame.new(0, 0, -getgenv().MagnetDistance)
                            eHRP.CFrame     = eHRP.CFrame:Lerp(targetPos, getgenv().PullForce)
                            eHRP.CanCollide = false
                        end
                    end
                end
                local enemies = workspace:FindFirstChild("Enemies")
                if enemies then
                    for _, npc in pairs(enemies:GetChildren()) do Atraer(npc) end
                end
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= lp and p.Character then Atraer(p.Character) end
                end
            end
        end
    end)
end

task.spawn(function()
    while true do
        task.wait(0.02)
        if getgenv().MagnetEnabled then
            local myHRP = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
            if not myHRP then continue end
            local function Atraer(entidad)
                local eHRP = entidad:FindFirstChild("HumanoidRootPart")
                local eHum = entidad:FindFirstChild("Humanoid")
                if eHRP and eHum and eHum.Health > 0 then
                    local dist = (eHRP.Position - myHRP.Position).Magnitude
                    if dist <= 800 then
                        local targetPos = myHRP.CFrame * CFrame.new(0, 0, -6)
                        eHRP.CFrame     = eHRP.CFrame:Lerp(targetPos, 0.7)
                        eHRP.CanCollide = false
                    end
                end
            end
            local enemies = workspace:FindFirstChild("Enemies")
            if enemies then
                for _, npc in pairs(enemies:GetChildren()) do Atraer(npc) end
            end
            for _, p in pairs(Players:GetPlayers()) do
                if p ~= lp and p.Character then Atraer(p.Character) end
            end
        end
    end
end)

IniciarMagneto()

-- ============================================================
--  TELEPORT ALL PLAYERS
-- ============================================================

local function TeleportToAllPlayers()
    local players = Players:GetPlayers()
    local char    = lp.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then
        Rayfield:Notify({Title = "Error", Content = "No se encontro tu personaje.", Duration = 3})
        return
    end
    Rayfield:Notify({
        Title    = "Iniciando Secuencia",
        Content  = "Teletransportando a " .. #players .. " jugadores.",
        Duration = 2,
    })
    task.spawn(function()
        for _, target in pairs(players) do
            if target ~= lp and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                char.HumanoidRootPart.CFrame = target.Character.HumanoidRootPart.CFrame
                task.wait(0.5)
            end
        end
        Rayfield:Notify({Title = "Completado", Content = "Has visitado a todos los jugadores.", Duration = 3})
    end)
end

-- ============================================================
--  RUNTIME LOOPS
-- ============================================================

-- Aplica speed/jump al personaje actual
local function ApplyMovementStats(char)
    local hum = char and char:WaitForChild("Humanoid", 5)
    if not hum then return end
    if _G.WalkSpeedEnabled then hum.WalkSpeed = _G.WalkSpeedValue end
    if _G.JumpPowerEnabled then
        hum.JumpPower    = _G.JumpPowerValue
        hum.UseJumpPower = true
    end
    if _G.MaxSlopeEnabled then hum.MaxSlopeAngle = 89 end
end

-- Loop continuo para mantenerlo aunque el servidor lo reestablezca
task.spawn(function()
    while true do
        task.wait(0.1)
        pcall(function()
            local char = lp.Character
            if not char then return end
            local hum = char:FindFirstChildOfClass("Humanoid")
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if not hum then return end
            if _G.WalkSpeedEnabled then hum.WalkSpeed = _G.WalkSpeedValue end
            if _G.JumpPowerEnabled then
                hum.JumpPower    = _G.JumpPowerValue
                hum.UseJumpPower = true
            else
                hum.UseJumpPower = false
            end
            if _G.MaxSlopeEnabled then hum.MaxSlopeAngle = 89 end
            -- Anti-friccion: Velocity directa igual que fly_external
            if _G.AntiFriccionEnabled and hrp and hum.MoveDirection.Magnitude > 0 then
                hrp.Velocity = Vector3.new(
                    hum.MoveDirection.X * _G.WalkSpeedValue,
                    hrp.Velocity.Y,
                    hum.MoveDirection.Z * _G.WalkSpeedValue
                )
            end
        end)
    end
end)

-- Tambien aplica al respawnear
lp.CharacterAdded:Connect(function(char)
    task.wait(0.5)   -- espera a que el humanoid exista
    ApplyMovementStats(char)
end)

RunService.Heartbeat:Connect(function()
    if not lp.Character then return end
    local root = lp.Character:FindFirstChild("HumanoidRootPart")
    if getgenv().WalkOnWater and root and root.Position.Y < 20 then
        local pos   = root.Position
        root.CFrame = CFrame.new(pos.X, 21, pos.Z) * (root.CFrame - root.Position)
    end
    if getgenv().NoclipEnabled then
        for _, v in pairs(lp.Character:GetDescendants()) do
            if v:IsA("BasePart") then v.CanCollide = false end
        end
    end
    if getgenv().SpinEnabled and root then
        root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(getgenv().SpinSpeed), 0)
    end
end)

task.spawn(function()
    while true do
        task.wait(0.01)
        pcall(function()
            local root = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
            if not root or lp.Character.Humanoid.Health <= 0 or GhostTpEnabled then return end
            if getgenv().SkyTrackerActive then
                root.CFrame = root.CFrame + Vector3.new(0, 9999, 0)
            elseif getgenv().SelectedPlayer then
                local targetPlayer = Players:FindFirstChild(getgenv().SelectedPlayer)
                if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    local tRoot = targetPlayer.Character.HumanoidRootPart
                    if getgenv().TPDirectActive then
                        root.CFrame = tRoot.CFrame * CFrame.new(0, 1.5, 3.5)
                    elseif getgenv().KillTrackerActive then
                        root.CFrame = tRoot.CFrame + Vector3.new(0, getgenv().TrackerHeight, 0)
                        task.wait(0.05)
                    end
                end
            end
        end)
    end
end)

task.spawn(function()
    while task.wait(1) do
        if ESPEnabled then UpdateESP() else ClearESP() end
    end
end)

task.spawn(function()
    while task.wait(3) do
        if ESPEnabled then UpdateESP() end
    end
end)

-- ============================================================
--  INPUT BINDS
-- ============================================================

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    
