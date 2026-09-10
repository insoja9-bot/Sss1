-- ============================================
-- سكربت: قفل التصويب (هدف ثابت) + الانتقال خلف الخصم
-- للجوال - واجهة عربية - أزرار قابلة للسحب
-- ============================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- ========== الإعدادات ==========
local CONFIG = {
    MaxDistance = 500,        -- أقصى مسافة للبحث عن خصم
    AimSmoothness = 0.3,      -- نعومة التصويب (0 = ثابت، 1 = فوري)
    TeleportOffset = 3,       -- المسافة خلف الخصم
    ButtonSize = 60,
    AimButtonColor = Color3.fromRGB(200, 50, 50),
    AimActiveColor = Color3.fromRGB(50, 200, 50),
    TpButtonColor = Color3.fromRGB(50, 150, 200),
}

-- ========== الحالة ==========
local isAiming = false
local lockedTarget = nil     -- الهدف المثبّت (لا يتغير إلا لما تشيله)
local aimConnection = nil

-- ==========================================
-- 1. إيجاد أقرب خصم (يُستخدم فقط لحظة الضغط)
-- ==========================================
local function getClosestPlayer()
    local closest = nil
    local shortestDist = CONFIG.MaxDistance
    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end

    for _, player in pairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        local char = player.Character
        if not char then continue end
        local root = char:FindFirstChild("HumanoidRootPart")
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if not root or not humanoid or humanoid.Health <= 0 then continue end

        local dist = (myRoot.Position - root.Position).Magnitude
        if dist < shortestDist then
            shortestDist = dist
            closest = player
        end
    end
    return closest
end

-- تحقق إذا الهدف لا يزال موجود ويصلح
local function isTargetValid()
    if not lockedTarget then return false end
    local char = lockedTarget.Character
    if not char then return false end
    local root = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid or humanoid.Health <= 0 then return false end
    return true
end

-- ==========================================
-- 2. قفل التصويب على الهدف المثبّت
-- ==========================================
local function startAimLock()
    if aimConnection then return end

    aimConnection = RunService.RenderStepped:Connect(function()
        if not isAiming or not lockedTarget then return end

        -- إذا مات الهدف أو خرج، نوقف القفل
        if not isTargetValid() then
            return
        end

        local targetRoot = lockedTarget.Character:FindFirstChild("HumanoidRootPart")
        if not targetRoot then return end

        local targetPos = targetRoot.Position
        local cameraPos = Camera.CFrame.Position

        local direction = (targetPos - cameraPos).Unit
        local targetCFrame = CFrame.new(cameraPos, cameraPos + direction)

        Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, CONFIG.AimSmoothness)
    end)
end

local function stopAimLock()
    isAiming = false
    lockedTarget = nil
    if aimConnection then
        aimConnection:Disconnect()
        aimConnection = nil
    end
end

-- ==========================================
-- 3. الانتقال خلف الهدف المثبّت
-- ==========================================
local function teleportBehindTarget()
    if not isTargetValid() then
        -- إذا ما في هدف مثبّت، نثبّت أقرب واحد
        lockedTarget = getClosestPlayer()
        if not lockedTarget then return end
    end

    local myChar = LocalPlayer.Character
    local targetRoot = lockedTarget.Character:FindFirstChild("HumanoidRootPart")
    if not myChar or not targetRoot then return end

    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end

    local targetPos = targetRoot.Position
    local targetLook = targetRoot.CFrame.LookVector
    local behindPos = targetPos - (targetLook * CONFIG.TeleportOffset)
    behindPos = Vector3.new(behindPos.X, targetPos.Y, behindPos.Z)

    local newCFrame = CFrame.lookAt(behindPos, targetPos)
    myChar:PivotTo(newCFrame)
end

-- ==========================================
-- 4. إنشاء واجهة المستخدم
-- ==========================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AimLockGUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
screenGui.DisplayOrder = 999

local function createDraggableButton(name, text, color, position)
    local frame = Instance.new("Frame")
    frame.Name = name
    frame.Size = UDim2.new(0, CONFIG.ButtonSize, 0, CONFIG.ButtonSize)
    frame.Position = position
    frame.BackgroundColor3 = color
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.5, 0)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 255, 255)
    stroke.Thickness = 2
    stroke.Transparency = 0.4
    stroke.Parent = frame

    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.Text = text
    textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    textLabel.TextScaled = true
    textLabel.Font = Enum.Font.GothamBold
    textLabel.Parent = frame

    local textConstraint = Instance.new("UITextSizeConstraint")
    textConstraint.MaxTextSize = 24
    textConstraint.MinTextSize = 10
    textConstraint.Parent = textLabel

    -- زر السحب (خلفي)
    local dragButton = Instance.new("TextButton")
    dragButton.Size = UDim2.new(1, 0, 1, 0)
    dragButton.BackgroundTransparency = 1
    dragButton.Text = ""
    dragButton.Parent = frame

    -- زر النقر (أمامي)
    local clickButton = Instance.new("TextButton")
    clickButton.Size = UDim2.new(1, 0, 1, 0)
    clickButton.BackgroundTransparency = 1
    clickButton.Text = ""
    clickButton.ZIndex = 2
    clickButton.Parent = frame

    -- ====== منطق السحب ======
    local dragging = false
    local dragStart = nil
    local startPos = nil
    local moved = false

    clickButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            moved = false
            dragStart = input.Position
            startPos = frame.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    clickButton.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
           or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            if math.abs(delta.X) > 5 or math.abs(delta.Y) > 5 then
                moved = true
            end
            if moved then
                frame.Position = UDim2.new(
                    startPos.X.Scale,
                    startPos.X.Offset + delta.X,
                    startPos.Y.Scale,
                    startPos.Y.Offset + delta.Y
                )
            end
        end
    end)

    return frame, clickButton, function() return moved end
end

-- ==========================================
-- 5. إنشاء الأزرار
-- ==========================================
local aimFrame, aimClick, aimMoved = createDraggableButton(
    "AimButton", "قفل", CONFIG.AimButtonColor, UDim2.new(0, 20, 0.4, 0)
)

local tpFrame, tpClick, tpMoved = createDraggableButton(
    "TpButton", "خلف", CONFIG.TpButtonColor, UDim2.new(0, 20, 0.6, 0)
)

-- ========== ربط زر القفل ==========
aimClick.InputEnded:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1
       and input.UserInputType ~= Enum.UserInputType.Touch then return end
    if aimMoved() then return end  -- إذا كان سحب، لا تنفذ

    if isAiming then
        -- إيقاف
        stopAimLock()
        aimFrame.BackgroundColor3 = CONFIG.AimButtonColor
        aimFrame:FindFirstChildOfClass("UIStroke").Color = Color3.fromRGB(255, 255, 255)
    else
        -- تثبيت الهدف الحالي
        lockedTarget = getClosestPlayer()
        if not lockedTarget then
            -- ما في خصم قريب
            return
        end
        isAiming = true
        startAimLock()
        aimFrame.BackgroundColor3 = CONFIG.AimActiveColor
        aimFrame:FindFirstChildOfClass("UIStroke").Color = Color3.fromRGB(0, 255, 0)
    end
end)

-- ========== ربط زر خلف ==========
tpClick.InputEnded:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1
       and input.UserInputType ~= Enum.UserInputType.Touch then return end
    if tpMoved() then return end

    teleportBehindTarget()
end)

-- ==========================================
-- 6. عند تغيير الشخصية نوقف القفل
-- ==========================================
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    stopAimLock()
    if aimFrame then
        aimFrame.BackgroundColor3 = CONFIG.AimButtonColor
        aimFrame:FindFirstChildOfClass("UIStroke").Color = Color3.fromRGB(255, 255, 255)
    end
end)

print("✅ تم تشغيل السكربت - الهدف يبقى ثابت لين تشيله")
