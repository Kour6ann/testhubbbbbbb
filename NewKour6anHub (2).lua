-- Kour6anHub - Modern Redesign v9.0 - FULLY PATCHED

local Kour6anHub = {}
Kour6anHub.__index = Kour6anHub

-- Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

-- Configuration
local ReducedMotion = false
local SHADOW_IMAGE = "rbxassetid://6014261993"
local GRADIENT_IMAGE = "rbxassetid://14204231522"

-- Active tweens tracker
local ActiveTweens = setmetatable({}, { __mode = "k" })
local _tweenTimestamps = {}

-- Safe call with recursion guard
local SAFE_CALL_MAX_DEPTH = 10
local _safe_call_depth = {}
local function safeCall(fn, ...)
    if type(fn) ~= "function" then return false, "not_function" end
    local depth = (_safe_call_depth[fn] or 0) + 1
    _safe_call_depth[fn] = depth
    if depth > SAFE_CALL_MAX_DEPTH then
        warn("[Kour6anHub] safeCall: recursion depth exceeded")
        _safe_call_depth[fn] = _safe_call_depth[fn] - 1
        if _safe_call_depth[fn] <= 0 then _safe_call_depth[fn] = nil end
        return false, "recursion_limit"
    end
    local ok, res = pcall(fn, ...)
    _safe_call_depth[fn] = _safe_call_depth[fn] - 1
    if _safe_call_depth[fn] <= 0 then _safe_call_depth[fn] = nil end
    return ok, res
end

-- Unicode arrow helper - FIXED ENCODING
local function getArrowChar(direction)
    -- Using proper unicode: down arrow (▼) U+25BC and up arrow (▲) U+25B2
    local unicode = direction == "down" and "▼" or "▲"
    local fallback = direction == "down" and "v" or "^"
    local success = pcall(function()
        local testLabel = Instance.new("TextLabel")
        testLabel.Text = unicode
        testLabel.Font = Enum.Font.Gotham
        testLabel.TextSize = 12
        testLabel:Destroy()
        return true
    end)
    return success and unicode or fallback
end

-- Enhanced tween creation
local function safeTweenCreate(obj, props, options)
    if not obj or not props then return nil end
    options = options or {}
    local dur = options.duration or 0.15
    local easingStyle = options.easingStyle or Enum.EasingStyle.Quad
    local easingDirection = options.easingDirection or Enum.EasingDirection.Out

    if ReducedMotion then
        for prop, value in pairs(props) do
            pcall(function() obj[prop] = value end)
        end
        return nil
    end

    if not ActiveTweens[obj] then ActiveTweens[obj] = {} end

    for prop, tweenObj in pairs(ActiveTweens[obj]) do
        if props[prop] ~= nil then
            if tweenObj and typeof(tweenObj) == "Tween" then
                pcall(function() 
                    if tweenObj.Cancel then tweenObj:Cancel() end
                end)
            end
            ActiveTweens[obj][prop] = nil
        end
    end

    local ti = TweenInfo.new(dur, easingStyle, easingDirection)
    local ok, t = pcall(function() return TweenService:Create(obj, ti, props) end)
    if not ok or not t then return nil end

    for prop in pairs(props) do
        ActiveTweens[obj][prop] = t
    end
    _tweenTimestamps[t] = tick()

    local conn
    conn = t.Completed:Connect(function()
        pcall(function()
            if ActiveTweens[obj] then
                for prop, tweenObj in pairs(ActiveTweens[obj]) do
                    if tweenObj == t then
                        ActiveTweens[obj][prop] = nil
                    end
                end
                if next(ActiveTweens[obj]) == nil then
                    ActiveTweens[obj] = nil
                end
            end
            if conn then
                conn:Disconnect()
                conn = nil
            end
            _tweenTimestamps[t] = nil
        end)
    end)

    local playSuccess = pcall(function() t:Play() end)
    if not playSuccess then
        for prop in pairs(props) do
            if ActiveTweens[obj] then
                ActiveTweens[obj][prop] = nil
            end
        end
        _tweenTimestamps[t] = nil
        if conn then
            pcall(function() conn:Disconnect() end)
        end
        return nil
    end

    return t
end

local function tween(obj, props, options)
    return safeTweenCreate(obj, props, options)
end

-- Connection tracker
local function makeConnectionTracker()
    local conns = {}
    local tweens = {}
    return {
        add = function(_, conn)
            if conn and typeof(conn) == "RBXScriptConnection" then
                table.insert(conns, conn)
            end
        end,
        addTween = function(_, tweenObj)
            if tweenObj and typeof(tweenObj) == "Tween" then
                table.insert(tweens, tweenObj)
            end
        end,
        disconnectAll = function()
            for _, c in ipairs(conns) do
                pcall(function() c:Disconnect() end)
            end
            conns = {}
            for _, t in ipairs(tweens) do
                pcall(function() t:Cancel() end)
            end
            tweens = {}
        end,
        list = function() return conns end,
        listTweens = function() return tweens end
    }
end

local _GLOBAL_CONN_REGISTRY = {}
local function trackGlobalConn(conn)
    if conn and typeof(conn) == "RBXScriptConnection" then
        table.insert(_GLOBAL_CONN_REGISTRY, conn)
    end
end

-- Hover helper
local HoverDebounce = {}
local function debouncedHover(obj, enterFunc, leaveFunc)
    if not obj then return end
    local key = tostring(obj)
    
    local ancConn
    ancConn = obj.AncestryChanged:Connect(function(_, parent)
        if not parent then
            HoverDebounce[key] = nil
            pcall(function() ancConn:Disconnect() end)
        end
    end)
    trackGlobalConn(ancConn)

    obj.MouseEnter:Connect(function()
        if HoverDebounce[key] then return end
        HoverDebounce[key] = true
        if enterFunc then pcall(enterFunc) end
    end)

    obj.MouseLeave:Connect(function()
        if not HoverDebounce[key] then return end
        HoverDebounce[key] = nil
        if leaveFunc then pcall(leaveFunc) end
    end)
end

-- Dragging helper (mobile compatible)
local function makeDraggable(frame, dragHandle)
    local connTracker = makeConnectionTracker()
    local dragging = false
    local dragInput
    local dragStart
    local startPos
    dragHandle = dragHandle or frame

    local ibConn = dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or 
           input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragInput = input
            dragStart = input.Position
            startPos = frame.Position
            
            local changedConn
            changedConn = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    dragInput = nil
                    pcall(function() changedConn:Disconnect() end)
                end
            end)
            connTracker:add(changedConn)
        end
    end)
    connTracker:add(ibConn)

    local imConn = UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        
        if input.UserInputType == Enum.UserInputType.MouseMovement or 
           input.UserInputType == Enum.UserInputType.Touch then
            if input.UserInputType == Enum.UserInputType.Touch and input ~= dragInput then
                return
            end
            
            local delta = input.Position - dragStart
            pcall(function()
                frame.Position = UDim2.new(
                    startPos.X.Scale, 
                    startPos.X.Offset + delta.X, 
                    startPos.Y.Scale, 
                    startPos.Y.Offset + delta.Y
                )
            end)
        end
    end)
    connTracker:add(imConn)
    
    local ieConn = UserInputService.InputEnded:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or 
                        input.UserInputType == Enum.UserInputType.Touch) then
            if input == dragInput or input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = false
                dragInput = nil
            end
        end
    end)
    connTracker:add(ieConn)

    return {
        disconnect = function()
            connTracker.disconnectAll()
        end,
        list = function() return connTracker.list() end
    }
end

-- Modern Theme System
local Themes = {
    ["Modern"] = {
        Background = Color3.fromRGB(243, 243, 243),
        TabBackground = Color3.fromRGB(249, 249, 249),
        SectionBackground = Color3.fromRGB(255, 255, 255),
        ButtonBackground = Color3.fromRGB(251, 251, 251),
        ButtonHover = Color3.fromRGB(245, 245, 245),
        ButtonBorder = Color3.fromRGB(225, 225, 225),
        InputBackground = Color3.fromRGB(255, 255, 255),
        InputBorder = Color3.fromRGB(225, 225, 225),
        Text = Color3.fromRGB(32, 32, 32),
        SubText = Color3.fromRGB(96, 96, 96),
        Accent = Color3.fromRGB(0, 120, 212),
        AccentHover = Color3.fromRGB(16, 110, 190),
        Shadow = Color3.fromRGB(0, 0, 0)
    },
    ["Dark"] = {
        Background = Color3.fromRGB(32, 32, 32),
        TabBackground = Color3.fromRGB(43, 43, 43),
        SectionBackground = Color3.fromRGB(45, 45, 45),
        ButtonBackground = Color3.fromRGB(58, 58, 58),
        ButtonHover = Color3.fromRGB(68, 68, 68),
        ButtonBorder = Color3.fromRGB(70, 70, 70),
        InputBackground = Color3.fromRGB(51, 51, 51),
        InputBorder = Color3.fromRGB(70, 70, 70),
        Text = Color3.fromRGB(255, 255, 255),
        SubText = Color3.fromRGB(180, 180, 180),
        Accent = Color3.fromRGB(96, 160, 255),
        AccentHover = Color3.fromRGB(116, 180, 255),
        Shadow = Color3.fromRGB(0, 0, 0)
    },
    ["Midnight"] = {
        Background = Color3.fromRGB(10, 12, 20),
        TabBackground = Color3.fromRGB(18, 20, 30),
        SectionBackground = Color3.fromRGB(22, 24, 36),
        ButtonBackground = Color3.fromRGB(35, 37, 50),
        ButtonHover = Color3.fromRGB(45, 47, 60),
        ButtonBorder = Color3.fromRGB(50, 52, 65),
        InputBackground = Color3.fromRGB(28, 30, 42),
        InputBorder = Color3.fromRGB(50, 52, 65),
        Text = Color3.fromRGB(235, 235, 245),
        SubText = Color3.fromRGB(150, 150, 170),
        Accent = Color3.fromRGB(120, 90, 255),
        AccentHover = Color3.fromRGB(140, 110, 255),
        Shadow = Color3.fromRGB(0, 0, 0)
    },
    ["Ocean"] = {
        Background = Color3.fromRGB(5, 20, 35),
        TabBackground = Color3.fromRGB(10, 30, 50),
        SectionBackground = Color3.fromRGB(15, 40, 65),
        ButtonBackground = Color3.fromRGB(25, 55, 85),
        ButtonHover = Color3.fromRGB(35, 65, 95),
        ButtonBorder = Color3.fromRGB(40, 70, 100),
        InputBackground = Color3.fromRGB(20, 45, 70),
        InputBorder = Color3.fromRGB(40, 70, 100),
        Text = Color3.fromRGB(220, 235, 245),
        SubText = Color3.fromRGB(140, 170, 190),
        Accent = Color3.fromRGB(0, 140, 255),
        AccentHover = Color3.fromRGB(20, 160, 255),
        Shadow = Color3.fromRGB(0, 0, 0)
    },
    ["Crimson"] = {
        Background = Color3.fromRGB(25, 10, 15),
        TabBackground = Color3.fromRGB(35, 15, 20),
        SectionBackground = Color3.fromRGB(45, 20, 25),
        ButtonBackground = Color3.fromRGB(60, 30, 40),
        ButtonHover = Color3.fromRGB(70, 40, 50),
        ButtonBorder = Color3.fromRGB(80, 45, 55),
        InputBackground = Color3.fromRGB(50, 25, 35),
        InputBorder = Color3.fromRGB(80, 45, 55),
        Text = Color3.fromRGB(245, 225, 230),
        SubText = Color3.fromRGB(180, 150, 160),
        Accent = Color3.fromRGB(220, 40, 80),
        AccentHover = Color3.fromRGB(240, 60, 100),
        Shadow = Color3.fromRGB(0, 0, 0)
    }
}

-- Helper to resolve GUI parent
local function resolveGuiParent()
    local parent = game:GetService("CoreGui")
    local success, playerGui = pcall(function()
        local plr = Players.LocalPlayer
        if plr and plr:FindFirstChild("PlayerGui") then
            return plr.PlayerGui
        end
        return nil
    end)
    if success and playerGui then parent = playerGui end
    return parent
end

-- Safe callback wrapper
local function safeCallback(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, err = pcall(fn, ...)
    if not ok then
        warn("[Kour6anHub] callback error:", err)
    end
end

-- Add shadow effect to element
local function addShadow(element, intensity)
    intensity = intensity or 0.7
    local shadow = Instance.new("ImageLabel")
    shadow.Name = "Shadow"
    shadow.Size = UDim2.new(1, 30, 1, 30)
    shadow.Position = UDim2.new(0, -15, 0, -15)
    shadow.BackgroundTransparency = 1
    shadow.Image = SHADOW_IMAGE
    shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
    shadow.ImageTransparency = intensity
    shadow.ScaleType = Enum.ScaleType.Slice
    shadow.SliceCenter = Rect.new(49, 49, 450, 450)
    shadow.ZIndex = element.ZIndex - 1
    shadow.Parent = element
    return shadow
end

-- Library creation
function Kour6anHub.CreateLib(title, themeName)
    local theme = Themes[themeName] or Themes["Modern"]
    local GuiParent = resolveGuiParent()

    -- Create or replace ScreenGui
    local ScreenGui = GuiParent:FindFirstChild("Kour6anHub")
    if ScreenGui then
        pcall(function() ScreenGui:Destroy() end)
    end
    ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "Kour6anHub"
    ScreenGui.DisplayOrder = 999999999
    ScreenGui.ResetOnSpawn = false
    ScreenGui.Parent = GuiParent
    
    -- Main frame with shadow
    local Main = Instance.new("Frame")
    Main.Size = UDim2.new(0, 620, 0, 420)
    Main.Position = UDim2.new(0.5, -310, 0.5, -210)
    Main.BackgroundColor3 = theme.Background
    Main.BorderSizePixel = 0
    Main.Active = true
    Main.ClipsDescendants = false
    Main.Parent = ScreenGui

    local MainCorner = Instance.new("UICorner")
    MainCorner.CornerRadius = UDim.new(0, 10)
    MainCorner.Parent = Main

    addShadow(Main, 0.65)

    -- Topbar with modern styling
    local Topbar = Instance.new("Frame")
    Topbar.Size = UDim2.new(1, 0, 0, 45)
    Topbar.BackgroundColor3 = theme.SectionBackground
    Topbar.Active = true
    Topbar.Parent = Main

    local TopbarCorner = Instance.new("UICorner")
    TopbarCorner.CornerRadius = UDim.new(0, 10)
    TopbarCorner.Parent = Topbar

    -- Subtle divider line under topbar
    local TopbarDivider = Instance.new("Frame")
    TopbarDivider.Size = UDim2.new(1, 0, 0, 1)
    TopbarDivider.Position = UDim2.new(0, 0, 1, -1)
    TopbarDivider.BackgroundColor3 = theme.ButtonBorder
    TopbarDivider.BackgroundTransparency = 0.7
    TopbarDivider.BorderSizePixel = 0
    TopbarDivider.Parent = Topbar

    -- Title with icon support
    local Title = Instance.new("TextLabel")
    Title.Text = title or "Kour6anHub"
    Title.Size = UDim2.new(1, -100, 1, 0)
    Title.Position = UDim2.new(0, 15, 0, 0)
    Title.BackgroundTransparency = 1
    Title.TextColor3 = theme.Text
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 16
    Title.Parent = Topbar

    -- Window controls with better styling - FIXED CHARACTER ENCODING
    local MinimizeBtn = Instance.new("TextButton")
    MinimizeBtn.Size = UDim2.new(0, 35, 0, 35)
    MinimizeBtn.Position = UDim2.new(1, -80, 0.5, -17.5)
    MinimizeBtn.BackgroundColor3 = theme.ButtonBackground
    MinimizeBtn.TextColor3 = theme.Text
    MinimizeBtn.Font = Enum.Font.GothamBold
    MinimizeBtn.TextSize = 16
    MinimizeBtn.Text = "−"  -- FIXED: Proper minus sign (U+2212)
    MinimizeBtn.AutoButtonColor = false
    MinimizeBtn.Parent = Topbar

    local MinimizeBtnCorner = Instance.new("UICorner")
    MinimizeBtnCorner.CornerRadius = UDim.new(0, 6)
    MinimizeBtnCorner.Parent = MinimizeBtn

    local MinimizeBtnStroke = Instance.new("UIStroke")
    MinimizeBtnStroke.Color = theme.ButtonBorder
    MinimizeBtnStroke.Thickness = 1
    MinimizeBtnStroke.Transparency = 0.7
    MinimizeBtnStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    MinimizeBtnStroke.Parent = MinimizeBtn

    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Size = UDim2.new(0, 35, 0, 35)
    CloseBtn.Position = UDim2.new(1, -40, 0.5, -17.5)
    CloseBtn.BackgroundColor3 = Color3.fromRGB(220, 53, 69)
    CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.TextSize = 16
    CloseBtn.Text = "×"  -- FIXED: Proper multiplication sign (U+00D7)
    CloseBtn.AutoButtonColor = false
    CloseBtn.Parent = Topbar

    local CloseBtnCorner = Instance.new("UICorner")
    CloseBtnCorner.CornerRadius = UDim.new(0, 6)
    CloseBtnCorner.Parent = CloseBtn

    local CloseBtnStroke = Instance.new("UIStroke")
    CloseBtnStroke.Color = Color3.fromRGB(180, 40, 55)
    CloseBtnStroke.Thickness = 1
    CloseBtnStroke.Transparency = 0.5
    CloseBtnStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    CloseBtnStroke.Parent = CloseBtn

    local globalConnTracker = makeConnectionTracker()

    -- Make draggable
    local dragTracker = makeDraggable(Main, Topbar)
    if dragTracker then
        for _, c in ipairs(dragTracker.list()) do globalConnTracker:add(c) end
    end
    
    for _, c in ipairs(_GLOBAL_CONN_REGISTRY) do
        globalConnTracker:add(c)
    end
    _GLOBAL_CONN_REGISTRY = {}

    -- Tab container with modern styling
    local TabContainer = Instance.new("Frame")
    TabContainer.Size = UDim2.new(0, 160, 1, -45)
    TabContainer.Position = UDim2.new(0, 0, 0, 45)
    TabContainer.BackgroundColor3 = theme.TabBackground
    TabContainer.Active = true
    TabContainer.Parent = Main

    local TabContainerCorner = Instance.new("UICorner")
    TabContainerCorner.CornerRadius = UDim.new(0, 10)
    TabContainerCorner.Parent = TabContainer

    -- Subtle border for tab container
    local TabContainerStroke = Instance.new("UIStroke")
    TabContainerStroke.Color = theme.ButtonBorder
    TabContainerStroke.Thickness = 1
    TabContainerStroke.Transparency = 0.85
    TabContainerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    TabContainerStroke.Parent = TabContainer

    local TabList = Instance.new("UIListLayout")
    TabList.SortOrder = Enum.SortOrder.LayoutOrder
    TabList.Padding = UDim.new(0, 8)
    TabList.HorizontalAlignment = Enum.HorizontalAlignment.Center
    TabList.Parent = TabContainer

    local TabPadding = Instance.new("UIPadding")
    TabPadding.PaddingTop = UDim.new(0, 10)
    TabPadding.PaddingBottom = UDim.new(0, 10)
    TabPadding.PaddingLeft = UDim.new(0, 10)
    TabPadding.PaddingRight = UDim.new(0, 10)
    TabPadding.Parent = TabContainer

    -- Content area
    local Content = Instance.new("Frame")
    Content.Size = UDim2.new(1, -170, 1, -45)
    Content.Position = UDim2.new(0, 170, 0, 45)
    Content.BackgroundTransparency = 1
    Content.Active = true
    Content.Parent = Main

    local Tabs = {}
    local Window = {}
    Window.ScreenGui = ScreenGui
    Window.Main = Main
    Window._connTracker = globalConnTracker
    Window.theme = theme

    Window._uiVisible = true
    Window._uiMinimized = false
    Window._toggleKey = Enum.KeyCode.RightControl
    Window._storedPosition = Main.Position
    Window._storedSize = Main.Size

    -- Notification system
    Window._notifications = {}
    Window._notifConfig = {
        width = 320,
        height = 70,
        spacing = 10,
        margin = 20,
        defaultDuration = 4
    }

    local function createNotificationHolder()
        local holder = Instance.new("Frame")
        holder.Name = "_NotificationHolder"
        holder.Size = UDim2.new(0, Window._notifConfig.width, 0, 1000)
        holder.AnchorPoint = Vector2.new(1,1)
        holder.Position = UDim2.new(1, -Window._notifConfig.margin, 1, -Window._notifConfig.margin)
        holder.BackgroundTransparency = 1
        holder.Parent = ScreenGui
        return holder
    end

    Window._notificationHolder = createNotificationHolder()

    local function repositionNotifications()
        for i, notif in ipairs(Window._notifications) do
            local targetY = - ( (i-1) * (Window._notifConfig.height + Window._notifConfig.spacing) ) - Window._notifConfig.height
            local finalPos = UDim2.new(0, 0, 1, targetY)
            pcall(function()
                if notif and notif.Parent then
                    tween(notif, {Position = finalPos}, {duration = 0.2})
                end
            end)
        end
    end

    local _notif_lock = false
    local _notif_queue = {}
    _repositionNotifications_original = repositionNotifications
    function repositionNotifications(...)
        if _notif_lock then
            _notif_queue[1] = true
            return
        end
        _notif_lock = true
        local ok, err = pcall(_repositionNotifications_original, ...)
        _notif_lock = false
        if not ok then warn('[Kour6anHub] repositionNotifications failed:', err) end
        if _notif_queue[1] then
            _notif_queue[1] = nil
            repositionNotifications(...)
        end
    end

    function Window:Notify(titleText, bodyText, duration)
        duration = duration or Window._notifConfig.defaultDuration
        if type(duration) ~= "number" or duration < 0 then 
            duration = Window._notifConfig.defaultDuration 
        end

        local width = Window._notifConfig.width
        local height = Window._notifConfig.height

        local notif = Instance.new("Frame")
        notif.Size = UDim2.new(0, width, 0, height)
        notif.BackgroundColor3 = theme.SectionBackground
        notif.BorderSizePixel = 0
        notif.AnchorPoint = Vector2.new(0,0)
        notif.Position = UDim2.new(0, 0, 1, 50)
        notif.Parent = Window._notificationHolder

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 10)
        corner.Parent = notif

        -- Add border stroke
        local notifStroke = Instance.new("UIStroke")
        notifStroke.Color = theme.ButtonBorder
        notifStroke.Thickness = 1
        notifStroke.Transparency = 0.7
        notifStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        notifStroke.Parent = notif

        -- Add subtle shadow
        addShadow(notif, 0.8)

        local accent = Instance.new("Frame")
        accent.Size = UDim2.new(0, 4, 1, 0)
        accent.Position = UDim2.new(0, 0, 0, 0)
        accent.BackgroundColor3 = theme.Accent
        accent.BorderSizePixel = 0
        accent.Parent = notif
        
        local acorner = Instance.new("UICorner")
        acorner.CornerRadius = UDim.new(0, 10)
        acorner.Parent = accent

        local ttl = Instance.new("TextLabel")
        ttl.Size = UDim2.new(1, -16, 0, 22)
        ttl.Position = UDim2.new(0, 12, 0, 8)
        ttl.BackgroundTransparency = 1
        ttl.TextXAlignment = Enum.TextXAlignment.Left
        ttl.TextYAlignment = Enum.TextYAlignment.Top
        ttl.Font = Enum.Font.GothamBold
        ttl.TextSize = 14
        ttl.TextColor3 = theme.Text
        ttl.Text = tostring(titleText or "Notification")
        ttl.Parent = notif

        local body = Instance.new("TextLabel")
        body.Size = UDim2.new(1, -16, 0, 38)
        body.Position = UDim2.new(0, 12, 0, 30)
        body.BackgroundTransparency = 1
        body.TextXAlignment = Enum.TextXAlignment.Left
        body.TextYAlignment = Enum.TextYAlignment.Top
        body.Font = Enum.Font.Gotham
        body.TextSize = 12
        body.TextColor3 = theme.SubText
        body.Text = tostring(bodyText or "")
        body.TextWrapped = true
        body.Parent = notif

        table.insert(Window._notifications, 1, notif)
        repositionNotifications()

        notif.BackgroundTransparency = 1
        ttl.TextTransparency = 1
        body.TextTransparency = 1
        accent.BackgroundTransparency = 1
        notifStroke.Transparency = 1
        
        pcall(function()
            if notif and notif.Parent then
                tween(notif, {BackgroundTransparency = 0}, {duration = 0.2})
                tween(ttl, {TextTransparency = 0}, {duration = 0.2})
                tween(body, {TextTransparency = 0}, {duration = 0.2})
                tween(accent, {BackgroundTransparency = 0}, {duration = 0.2})
                tween(notifStroke, {Transparency = 0.7}, {duration = 0.2})
            end
        end)

        local removed = false
        local function removeNow()
            if removed then return end
            removed = true
            for i, v in ipairs(Window._notifications) do
                if v == notif then
                    table.remove(Window._notifications, i)
                    break
                end
            end
            if notif and notif.Parent then
                pcall(function() notif:Destroy() end)
            end
            repositionNotifications()
        end

        task.delay(duration, function()
            pcall(function()
                if notif and notif.Parent then
                    local t1 = tween(notif, {
                        BackgroundTransparency = 1, 
                        Position = UDim2.new(0,0,1,50)
                    }, {duration = 0.2})
                    tween(ttl, {TextTransparency = 1}, {duration = 0.2})
                    tween(body, {TextTransparency = 1}, {duration = 0.2})
                    tween(accent, {BackgroundTransparency = 1}, {duration = 0.2})
                    tween(notifStroke, {Transparency = 1}, {duration = 0.2})
                    
                    if t1 then
                        local c
                        c = t1.Completed:Connect(function()
                            pcall(function() c:Disconnect() end)
                            removeNow()
                        end)
                    else
                        task.delay(0.2, removeNow)
                    end
                end
            end)
        end)

        return notif
    end

    function Window:GetThemeList()
        local out = {}
        for k,_ in pairs(Themes) do
            table.insert(out, k)
        end
        table.sort(out)
        return out
    end

    function Window:SetTheme(newThemeName)
        if not newThemeName then return end
        local foundTheme = nil
        
        if Themes[newThemeName] then
            foundTheme = Themes[newThemeName]
        else
            local lowerTarget = string.lower(tostring(newThemeName))
            for k,v in pairs(Themes) do
                if string.lower(k) == lowerTarget then
                    foundTheme = v
                    break
                end
            end
        end
        
        if not foundTheme then 
            warn("Theme not found:", newThemeName)
            return 
        end
        
        theme = foundTheme
        Window.theme = theme

        pcall(function()
            if Main and Main.Parent then 
                Main.BackgroundColor3 = theme.Background 
            end
            if Topbar and Topbar.Parent then 
                Topbar.BackgroundColor3 = theme.SectionBackground
            end
            if TopbarDivider and TopbarDivider.Parent then
                TopbarDivider.BackgroundColor3 = theme.ButtonBorder
            end
            if Title and Title.Parent then 
                Title.TextColor3 = theme.Text 
            end
            if TabContainer and TabContainer.Parent then 
                TabContainer.BackgroundColor3 = theme.TabBackground
            end
            if TabContainerStroke and TabContainerStroke.Parent then
                TabContainerStroke.Color = theme.ButtonBorder
            end
            if MinimizeBtn and MinimizeBtn.Parent then
                MinimizeBtn.BackgroundColor3 = theme.ButtonBackground
                MinimizeBtn.TextColor3 = theme.Text
            end
            if MinimizeBtnStroke and MinimizeBtnStroke.Parent then
                MinimizeBtnStroke.Color = theme.ButtonBorder
            end
        end)

        for _, entry in ipairs(Tabs) do
            local btn = entry.Button
            local frame = entry.Frame
            
            if btn and btn.Parent then
                local active = btn:GetAttribute("active") or false
                btn.BackgroundColor3 = active and theme.Accent or theme.ButtonBackground
                btn.TextColor3 = active and Color3.fromRGB(255,255,255) or theme.Text
                
                local stroke = btn:FindFirstChild("UIStroke")
                if stroke then
                    stroke.Color = active and theme.Accent or theme.ButtonBorder
                end
            end

            if frame and frame.Parent then
                if frame:IsA("ScrollingFrame") then
                    frame.ScrollBarImageColor3 = theme.Accent
                end
                
                for _, child in ipairs(frame:GetDescendants()) do
                    if not child or not child.Parent then continue end
                    
                    if child:IsA("Frame") then
                        if child.Name == "_section" then
                            child.BackgroundColor3 = theme.SectionBackground
                            local stroke = child:FindFirstChild("UIStroke")
                            if stroke then
                                stroke.Color = theme.ButtonBorder
                            end
                        elseif child.Name == "_dropdownOptions" then
                            child.BackgroundColor3 = theme.SectionBackground
                        end
                    elseif child:IsA("TextLabel") then
                        if child.Font == Enum.Font.GothamBold then
                            child.TextColor3 = theme.SubText
                        else
                            child.TextColor3 = theme.Text
                        end
                    elseif child:IsA("TextButton") then
                        if not child:GetAttribute("_isToggleState") then
                            child.BackgroundColor3 = theme.ButtonBackground
                            child.TextColor3 = theme.Text
                        else
                            local tog = child:GetAttribute("_toggle")
                            child.BackgroundColor3 = tog and theme.Accent or theme.ButtonBackground
                            child.TextColor3 = tog and Color3.fromRGB(255,255,255) or theme.Text
                        end
                        
                        local stroke = child:FindFirstChild("UIStroke")
                        if stroke then
                            stroke.Color = theme.ButtonBorder
                        end
                    elseif child:IsA("TextBox") then
                        child.BackgroundColor3 = theme.InputBackground
                        child.TextColor3 = theme.Text
                        
                        local stroke = child:FindFirstChild("UIStroke")
                        if stroke then
                            stroke.Color = theme.InputBorder
                        end
                    elseif child:IsA("UIStroke") then
                        if child.Parent and child.Parent:IsA("Frame") then
                            child.Color = theme.ButtonBorder
                        end
                    end
                end
            end
        end

        for _, notif in ipairs(Window._notifications) do
            if notif and notif.Parent then
                notif.BackgroundColor3 = theme.SectionBackground
                
                for _, c in ipairs(notif:GetChildren()) do
                    if c:IsA("Frame") and c.Size and c.Size.X.Offset == 4 then
                        c.BackgroundColor3 = theme.Accent
                    elseif c:IsA("TextLabel") then
                        if c.Font == Enum.Font.GothamBold then
                            c.TextColor3 = theme.Text
                        else
                            c.TextColor3 = theme.SubText
                        end
                    elseif c:IsA("UIStroke") then
                        c.Color = theme.ButtonBorder
                    end
                end
            end
        end
        
        if Window.ScreenGui then
            Window.ScreenGui.Enabled = false
            task.wait()
            Window.ScreenGui.Enabled = true
        end
    end

    -- UI Toggle methods
    function Window:Hide()
        if not Window._uiVisible then return end
        Window._storedPosition = Main.Position
        tween(Main, {Position = UDim2.new(0.5, -310, 0.5, -800)}, {duration = 0.2})
        task.delay(0.2, function()
            if ScreenGui then
                ScreenGui.Enabled = false
            end
        end)
        Window._uiVisible = false
    end

    function Window:Show()
        if Window._uiVisible then return end
        if ScreenGui then ScreenGui.Enabled = true end

        if Window._uiMinimized then
            Window:Restore()
        end

        local target = Window._storedPosition or UDim2.new(0.5, -310, 0.5, -210)
        tween(Main, {Position = target}, {duration = 0.2})
        Window._uiVisible = true
    end

    function Window:ToggleUI()
        if Window._uiVisible then
            Window:Hide()
        else
            Window:Show()
        end
    end

    function Window:SetToggleKey(keyEnum)
        if typeof(keyEnum) == "EnumItem" and keyEnum.EnumType == Enum.KeyCode then
            Window._toggleKey = keyEnum
            
            if Window._inputConn then
                pcall(function() Window._inputConn:Disconnect() end)
            end
            
            Window._inputConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
                if gameProcessed then return end
                if input.UserInputType == Enum.UserInputType.Keyboard and 
                   input.KeyCode == Window._toggleKey then
                    Window:ToggleUI()
                end
            end)
            globalConnTracker:add(Window._inputConn)
        end
    end

    function Window:Minimize()
        if self._uiMinimized then return end
        self._uiMinimized = true

        local header = (self.Topbar or Topbar)
        local headerHeight = (header and header.AbsoluteSize and header.AbsoluteSize.Y) or 45

        if self.Main then
            pcall(function()
                tween(self.Main, {
                    Size = UDim2.new(self._storedSize.X.Scale, self._storedSize.X.Offset, 0, headerHeight)
                }, {duration = 0.2})
            end)
        end

        if TabContainer then pcall(function() TabContainer.Visible = false end) end
        if Content then pcall(function() Content.Visible = false end) end

        if Tabs and type(Tabs) == "table" then
            for _, tab in ipairs(Tabs) do
                pcall(function() if tab and tab.Button then tab.Button.Visible = false end end)
            end
        end
    end

    function Window:Restore()
        if not self._uiMinimized then return end
        self._uiMinimized = false

        if self._storedSize and self.Main then
            pcall(function()
                tween(self.Main, {Size = self._storedSize}, {duration = 0.2})
            end)
        end

        if TabContainer then pcall(function() TabContainer.Visible = true end) end
        if Content then pcall(function() Content.Visible = true end) end

        if Tabs and type(Tabs) == "table" then
            for _, tab in ipairs(Tabs) do
                pcall(function() if tab and tab.Button then tab.Button.Visible = true end end)
            end
        end
    end

    function Window:ToggleMinimize()
        if self._uiMinimized then
            self:Restore()
        else
            self:Minimize()
        end
    end

    function Window:Destroy()
        for obj, props in pairs(ActiveTweens) do
            if not obj or (type(obj) == "userdata" and not obj.Parent) then
                ActiveTweens[obj] = nil
            else
                if type(props) == "table" then
                    for prop, tweenObj in pairs(props) do
                        pcall(function() 
                            if tweenObj and typeof(tweenObj) == "Tween" then
                                tweenObj:Cancel() 
                            end
                        end)
                    end
                end
                ActiveTweens[obj] = nil
            end
        end

        if self._inputConn then
            pcall(function() self._inputConn:Disconnect() end)
            self._inputConn = nil
        end

        if Window._currentOpenDropdown and type(Window._currentOpenDropdown) == "function" then
            pcall(function() Window._currentOpenDropdown() end)
            Window._currentOpenDropdown = nil
        end

        if self._connTracker then
            pcall(function() self._connTracker.disconnectAll() end)
            self._connTracker = nil
        end

        for k in pairs(HoverDebounce) do
            HoverDebounce[k] = nil
        end

        if self.ScreenGui then
            pcall(function() self.ScreenGui:Destroy() end)
            self.ScreenGui = nil
        end

        self._notifications = {}
        Tabs = {}

        setmetatable(self, nil)
        for k in pairs(self) do
            self[k] = nil
        end
    end

    -- Tab creation
    function Window:NewTab(tabName, icon)
        local TabButton = Instance.new("TextButton")
        TabButton.Size = UDim2.new(1, -20, 0, 42)
        TabButton.BackgroundColor3 = theme.ButtonBackground
        TabButton.TextColor3 = theme.Text
        TabButton.Font = Enum.Font.Gotham
        TabButton.TextSize = 14
        TabButton.Text = tabName or "Tab"
        TabButton.AutoButtonColor = false
        TabButton.Parent = TabContainer

        local TabButtonCorner = Instance.new("UICorner")
        TabButtonCorner.CornerRadius = UDim.new(0, 8)
        TabButtonCorner.Parent = TabButton

        local TabButtonStroke = Instance.new("UIStroke")
        TabButtonStroke.Color = theme.ButtonBorder
        TabButtonStroke.Thickness = 1
        TabButtonStroke.Transparency = 0.7
        TabButtonStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        TabButtonStroke.Parent = TabButton

        local TabButtonPadding = Instance.new("UIPadding")
        TabButtonPadding.PaddingTop = UDim.new(0, 10)
        TabButtonPadding.PaddingBottom = UDim.new(0, 10)
        TabButtonPadding.PaddingLeft = UDim.new(0, 12)
        TabButtonPadding.PaddingRight = UDim.new(0, 12)
        TabButtonPadding.Parent = TabButton

        debouncedHover(TabButton,
            function()
                if not TabButton:GetAttribute("active") then
                    tween(TabButton, {
                        BackgroundColor3 = theme.ButtonHover, 
                        Size = UDim2.new(1, -16, 0, 44)
                    }, {duration = 0.12})
                    tween(TabButtonStroke, {Transparency = 0.5}, {duration = 0.12})
                end
            end,
            function()
                if TabButton:GetAttribute("active") then
                    tween(TabButton, {
                        BackgroundColor3 = theme.Accent, 
                        Size = UDim2.new(1, -20, 0, 42)
                    }, {duration = 0.12})
                else
                    tween(TabButton, {
                        BackgroundColor3 = theme.ButtonBackground, 
                        Size = UDim2.new(1, -20, 0, 42)
                    }, {duration = 0.12})
                    tween(TabButtonStroke, {Transparency = 0.7}, {duration = 0.12})
                end
            end
        )

        local TabFrame = Instance.new("ScrollingFrame")
        TabFrame.Size = UDim2.new(1, 0, 1, 0)
        TabFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
        TabFrame.ScrollBarThickness = 6
        TabFrame.ScrollBarImageColor3 = theme.Accent
        TabFrame.BackgroundTransparency = 1
        TabFrame.BorderSizePixel = 0
        TabFrame.Visible = false
        TabFrame.Parent = Content

        local TabLayout = Instance.new("UIListLayout")
        TabLayout.SortOrder = Enum.SortOrder.LayoutOrder
        TabLayout.Padding = UDim.new(0, 12)
        TabLayout.Parent = TabFrame

        local TabFramePadding = Instance.new("UIPadding")
        TabFramePadding.PaddingTop = UDim.new(0, 10)
        TabFramePadding.PaddingLeft = UDim.new(0, 10)
        TabFramePadding.PaddingRight = UDim.new(0, 10)
        TabFramePadding.PaddingBottom = UDim.new(0, 10)
        TabFramePadding.Parent = TabFrame

        TabLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            local s = TabLayout.AbsoluteContentSize
            TabFrame.CanvasSize = UDim2.new(0, 0, 0, s.Y + 20)
        end)

        TabButton.MouseButton1Click:Connect(function()
            for _, t in ipairs(Tabs) do
                t.Button:SetAttribute("active", false)
                tween(t.Button, {BackgroundColor3 = theme.ButtonBackground}, {duration = 0.15})
                t.Button.TextColor3 = theme.Text
                t.Frame.Visible = false
                
                local stroke = t.Button:FindFirstChild("UIStroke")
                if stroke then
                    tween(stroke, {
                        Color = theme.ButtonBorder, 
                        Transparency = 0.7
                    }, {duration = 0.15})
                end
            end
            
            TabButton:SetAttribute("active", true)
            tween(TabButton, {BackgroundColor3 = theme.Accent}, {duration = 0.15})
            TabButton.TextColor3 = Color3.fromRGB(255,255,255)
            TabFrame.Visible = true
            
            tween(TabButtonStroke, {
                Color = theme.Accent, 
                Transparency = 0
            }, {duration = 0.15})
        end)

        table.insert(Tabs, {Button = TabButton, Frame = TabFrame})

        if not Window._currentTab then
            Window._currentTab = TabButton
            for _, t in ipairs(Tabs) do
                t.Button:SetAttribute("active", false)
                t.Button.BackgroundColor3 = theme.ButtonBackground
                t.Button.TextColor3 = theme.Text
                t.Frame.Visible = false
            end
            TabButton:SetAttribute("active", true)
            TabButton.BackgroundColor3 = theme.Accent
            TabButton.TextColor3 = Color3.fromRGB(255,255,255)
            TabButtonStroke.Color = theme.Accent
            TabButtonStroke.Transparency = 0
            TabFrame.Visible = true
        end

        local TabObj = {}

        function TabObj:NewSection(sectionName)
            local Section = Instance.new("Frame")
            Section.Size = UDim2.new(1, -10, 0, 50)
            Section.BackgroundColor3 = theme.SectionBackground
            Section.Parent = TabFrame
            Section.AutomaticSize = Enum.AutomaticSize.Y
            Section.Name = "_section"

            local SectionCorner = Instance.new("UICorner")
            SectionCorner.CornerRadius = UDim.new(0, 10)
            SectionCorner.Parent = Section

            local SectionStroke = Instance.new("UIStroke")
            SectionStroke.Color = theme.ButtonBorder
            SectionStroke.Thickness = 1
            SectionStroke.Transparency = 0.8
            SectionStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
            SectionStroke.Parent = Section

            local SectionLayout = Instance.new("UIListLayout")
            SectionLayout.SortOrder = Enum.SortOrder.LayoutOrder
            SectionLayout.Padding = UDim.new(0, 8)
            SectionLayout.Parent = Section

            local SectionPadding = Instance.new("UIPadding")
            SectionPadding.PaddingTop = UDim.new(0, 12)
            SectionPadding.PaddingBottom = UDim.new(0, 12)
            SectionPadding.PaddingLeft = UDim.new(0, 12)
            SectionPadding.PaddingRight = UDim.new(0, 12)
            SectionPadding.Parent = Section

            local Label = Instance.new("TextLabel")
            Label.Text = sectionName
            Label.Size = UDim2.new(1, 0, 0, 20)
            Label.BackgroundTransparency = 1
            Label.TextColor3 = theme.SubText
            Label.Font = Enum.Font.GothamBold
            Label.TextSize = 14
            Label.TextXAlignment = Enum.TextXAlignment.Left
            Label.Parent = Section

            local SectionObj = {}

            function SectionObj:NewLabel(text)
                local lbl = Instance.new("TextLabel")
                lbl.Text = text or ""
                lbl.Size = UDim2.new(1, 0, 0, 18)
                lbl.BackgroundTransparency = 1
                lbl.TextColor3 = theme.Text
                lbl.Font = Enum.Font.Gotham
                lbl.TextSize = 13
                lbl.TextXAlignment = Enum.TextXAlignment.Left
                lbl.Parent = Section
                return lbl
            end

            function SectionObj:NewSeparator()
                local sep = Instance.new("Frame")
                sep.Size = UDim2.new(1, 0, 0, 10)
                sep.BackgroundTransparency = 1
                sep.Parent = Section
                
                local line = Instance.new("Frame")
                line.Size = UDim2.new(1, -8, 0, 1)
                line.Position = UDim2.new(0, 4, 0, 5)
                line.BackgroundColor3 = theme.ButtonBorder
                line.BackgroundTransparency = 0.7
                line.BorderSizePixel = 0
                line.Parent = sep
                
                return line
            end

            function SectionObj:NewButton(text, desc, callback)
                if type(text) ~= "string" then text = tostring(text or "Button") end
                if callback ~= nil and type(callback) ~= "function" then 
                    warn("NewButton: callback is not a function") 
                end

                local Btn = Instance.new("TextButton")
                Btn.Text = text
                Btn.Size = UDim2.new(1, 0, 0, 36)
                Btn.BackgroundColor3 = theme.ButtonBackground
                Btn.TextColor3 = theme.Text
                Btn.Font = Enum.Font.Gotham
                Btn.TextSize = 13
                Btn.AutoButtonColor = false
                Btn.Parent = Section

                local BtnCorner = Instance.new("UICorner")
                BtnCorner.CornerRadius = UDim.new(0, 8)
                BtnCorner.Parent = Btn

                local BtnStroke = Instance.new("UIStroke")
                BtnStroke.Color = theme.ButtonBorder
                BtnStroke.Thickness = 1
                BtnStroke.Transparency = 0.7
                BtnStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                BtnStroke.Parent = Btn

                debouncedHover(Btn,
                    function()
                        tween(Btn, {
                            BackgroundColor3 = theme.ButtonHover, 
                            Size = UDim2.new(1, -4, 0, 38)
                        }, {duration = 0.1})
                        tween(BtnStroke, {Transparency = 0.5}, {duration = 0.1})
                    end,
                    function()
                        tween(Btn, {
                            BackgroundColor3 = theme.ButtonBackground, 
                            Size = UDim2.new(1, 0, 0, 36)
                        }, {duration = 0.1})
                        tween(BtnStroke, {Transparency = 0.7}, {duration = 0.1})
                    end
                )

                Btn.MouseButton1Click:Connect(function()
                    local t1 = tween(Btn, {
                        BackgroundColor3 = theme.Accent, 
                        Size = UDim2.new(1, -6, 0, 34)
                    }, {duration = 0.08})
                    tween(BtnStroke, {
                        Color = theme.Accent, 
                        Transparency = 0
                    }, {duration = 0.08})
                    tween(Btn, {TextColor3 = Color3.fromRGB(255,255,255)}, {duration = 0.08})
                    
                    if t1 then
                        local c
                        c = t1.Completed:Connect(function()
                            pcall(function() c:Disconnect() end)
                            tween(Btn, {
                                BackgroundColor3 = theme.ButtonBackground, 
                                Size = UDim2.new(1, 0, 0, 36)
                            }, {duration = 0.15})
                            tween(BtnStroke, {
                                Color = theme.ButtonBorder, 
                                Transparency = 0.7
                            }, {duration = 0.15})
                            tween(Btn, {TextColor3 = theme.Text}, {duration = 0.15})
                        end)
                    else
                        task.delay(0.09, function() 
                            tween(Btn, {
                                BackgroundColor3 = theme.ButtonBackground, 
                                Size = UDim2.new(1, 0, 0, 36)
                            }, {duration = 0.15})
                            tween(BtnStroke, {
                                Color = theme.ButtonBorder, 
                                Transparency = 0.7
                            }, {duration = 0.15})
                            tween(Btn, {TextColor3 = theme.Text}, {duration = 0.15})
                        end)
                    end
                    safeCallback(callback)
                end)

                return Btn
            end

            function SectionObj:NewToggle(text, desc, default, callback)
                if type(text) ~= "string" then text = tostring(text or "Toggle") end
                if callback ~= nil and type(callback) ~= "function" then 
                    warn("NewToggle: callback is not a function") 
                end

                local state = default == true

                local ToggleBtn = Instance.new("TextButton")
                ToggleBtn.Text = text .. (state and " [ON]" or " [OFF]")
                ToggleBtn.Size = UDim2.new(1, 0, 0, 36)
                ToggleBtn.BackgroundColor3 = state and theme.Accent or theme.ButtonBackground
                ToggleBtn.TextColor3 = state and Color3.fromRGB(255,255,255) or theme.Text
                ToggleBtn.Font = Enum.Font.Gotham
                ToggleBtn.TextSize = 13
                ToggleBtn.AutoButtonColor = false
                ToggleBtn.Parent = Section

                local ToggleCorner = Instance.new("UICorner")
                ToggleCorner.CornerRadius = UDim.new(0, 8)
                ToggleCorner.Parent = ToggleBtn

                local ToggleStroke = Instance.new("UIStroke")
                ToggleStroke.Color = state and theme.Accent or theme.ButtonBorder
                ToggleStroke.Thickness = 1
                ToggleStroke.Transparency = state and 0 or 0.7
                ToggleStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                ToggleStroke.Parent = ToggleBtn

                ToggleBtn:SetAttribute("_isToggleState", true)
                ToggleBtn:SetAttribute("_toggle", state)

                debouncedHover(ToggleBtn,
                    function()
                        if not state then
                            tween(ToggleBtn, {
                                BackgroundColor3 = theme.ButtonHover, 
                                Size = UDim2.new(1, -4, 0, 38)
                            }, {duration = 0.1})
                            tween(ToggleStroke, {Transparency = 0.5}, {duration = 0.1})
                        else
                            tween(ToggleBtn, {Size = UDim2.new(1, -4, 0, 38)}, {duration = 0.1})
                        end
                    end,
                    function()
                        tween(ToggleBtn, {Size = UDim2.new(1, 0, 0, 36)}, {duration = 0.1})
                        if not state then
                            tween(ToggleStroke, {Transparency = 0.7}, {duration = 0.1})
                        end
                    end
                )

                ToggleBtn.MouseButton1Click:Connect(function()
                    local t1 = tween(ToggleBtn, {Size = UDim2.new(1, -6, 0, 34)}, {duration = 0.08})
                    if t1 then
                        local c
                        c = t1.Completed:Connect(function()
                            pcall(function() c:Disconnect() end)
                            tween(ToggleBtn, {Size = UDim2.new(1, 0, 0, 36)}, {duration = 0.15})
                        end)
                    else
                        task.delay(0.09, function() 
                            tween(ToggleBtn, {Size = UDim2.new(1, 0, 0, 36)}, {duration = 0.15}) 
                        end)
                    end
                    
                    state = not state
                    ToggleBtn.Text = text .. (state and " [ON]" or " [OFF]")
                    
                    if state then
                        tween(ToggleBtn, {BackgroundColor3 = theme.Accent}, {duration = 0.15})
                        tween(ToggleBtn, {TextColor3 = Color3.fromRGB(255,255,255)}, {duration = 0.15})
                        tween(ToggleStroke, {
                            Color = theme.Accent, 
                            Transparency = 0
                        }, {duration = 0.15})
                    else
                        tween(ToggleBtn, {BackgroundColor3 = theme.ButtonBackground}, {duration = 0.15})
                        tween(ToggleBtn, {TextColor3 = theme.Text}, {duration = 0.15})
                        tween(ToggleStroke, {
                            Color = theme.ButtonBorder, 
                            Transparency = 0.7
                        }, {duration = 0.15})
                    end
                    
                    ToggleBtn:SetAttribute("_toggle", state)
                    safeCallback(callback, state)
                end)

                return {
                    Button = ToggleBtn,
                    GetState = function() return state end,
                    SetState = function(_, v)
                        state = not not v
                        ToggleBtn.Text = text .. (state and " [ON]" or " [OFF]")
                        
                        if state then
                            ToggleBtn.BackgroundColor3 = theme.Accent
                            ToggleBtn.TextColor3 = Color3.fromRGB(255,255,255)
                            ToggleStroke.Color = theme.Accent
                            ToggleStroke.Transparency = 0
                        else
                            ToggleBtn.BackgroundColor3 = theme.ButtonBackground
                            ToggleBtn.TextColor3 = theme.Text
                            ToggleStroke.Color = theme.ButtonBorder
                            ToggleStroke.Transparency = 0.7
                        end
                        
                        ToggleBtn:SetAttribute("_toggle", state)
                        safeCallback(callback, state)
                    end
                }
            end

            function SectionObj:NewSlider(text, min, max, default, callback)
                if type(min) ~= "number" then min = 0 end
                if type(max) ~= "number" then max = 100 end
                if min > max then local t = min; min = max; max = t end
                if default == nil then default = min end
                if type(default) ~= "number" then default = tonumber(default) or min end
                if default < min then default = min end
                if default > max then default = max end

                local currentValue = default
                local precision = 0
                
                local range = max - min
                if range <= 1 then
                    precision = 2
                elseif range <= 10 then
                    precision = 1
                else
                    precision = 0
                end

                local function roundValue(value)
                    local mult = 10 ^ precision
                    return math.floor(value * mult + 0.5) / mult
                end

                local wrap = Instance.new("Frame")
                wrap.Size = UDim2.new(1, 0, 0, 64)
                wrap.BackgroundTransparency = 1
                wrap.Parent = Section

                local lbl = Instance.new("TextLabel")
                lbl.Text = text
                lbl.Size = UDim2.new(0.7, -8, 0, 20)
                lbl.Position = UDim2.new(0, 0, 0, 0)
                lbl.BackgroundTransparency = 1
                lbl.TextColor3 = theme.SubText
                lbl.Font = Enum.Font.Gotham
                lbl.TextSize = 13
                lbl.TextXAlignment = Enum.TextXAlignment.Left
                lbl.Parent = wrap

                local valueLbl = Instance.new("TextLabel")
                valueLbl.Text = tostring(roundValue(currentValue))
                valueLbl.Size = UDim2.new(0.3, -8, 0, 20)
                valueLbl.Position = UDim2.new(0.7, 0, 0, 0)
                valueLbl.BackgroundTransparency = 1
                valueLbl.TextColor3 = theme.Accent
                valueLbl.Font = Enum.Font.GothamBold
                valueLbl.TextSize = 13
                valueLbl.TextXAlignment = Enum.TextXAlignment.Right
                valueLbl.Parent = wrap

                local sliderBg = Instance.new("Frame")
                sliderBg.Size = UDim2.new(1, -8, 0, 24)
                sliderBg.Position = UDim2.new(0, 4, 0, 36)
                sliderBg.BackgroundColor3 = theme.InputBackground
                sliderBg.Parent = wrap

                local bgCorner = Instance.new("UICorner")
                bgCorner.CornerRadius = UDim.new(0, 12)
                bgCorner.Parent = sliderBg

                local bgStroke = Instance.new("UIStroke")
                bgStroke.Color = theme.InputBorder
                bgStroke.Thickness = 1
                bgStroke.Transparency = 0.7
                bgStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                bgStroke.Parent = sliderBg

                local fill = Instance.new("Frame")
                local initialRel = 0
                if max > min then
                    initialRel = (currentValue - min) / (max - min)
                end
                fill.Size = UDim2.new(initialRel, 0, 1, 0)
                fill.BackgroundColor3 = theme.Accent
                fill.BorderSizePixel = 0
                fill.Parent = sliderBg
                fill.ZIndex = 2

                local fillCorner = Instance.new("UICorner")
                fillCorner.CornerRadius = UDim.new(0, 12)
                fillCorner.Parent = fill

                local knob = Instance.new("Frame")
                knob.Size = UDim2.new(0, 18, 0, 18)
                knob.Position = UDim2.new(initialRel, -9, 0.5, -9)
                knob.BackgroundColor3 = Color3.fromRGB(255,255,255)
                knob.BorderSizePixel = 0
                knob.Parent = sliderBg
                knob.ZIndex = 3

                local knobCorner = Instance.new("UICorner")
                knobCorner.CornerRadius = UDim.new(1, 0)
                knobCorner.Parent = knob

                local knobStroke = Instance.new("UIStroke")
                knobStroke.Color = theme.Accent
                knobStroke.Thickness = 2
                knobStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                knobStroke.Parent = knob

                local dragging = false

                local function updateSlider(inputPos)
                    local relativeX = inputPos.X - sliderBg.AbsolutePosition.X
                    local relativePos = math.clamp(relativeX / sliderBg.AbsoluteSize.X, 0, 1)
                    
                    local newValue = min + (max - min) * relativePos
                    newValue = roundValue(newValue)
                    newValue = math.clamp(newValue, min, max)
                    currentValue = newValue

                    local finalRel = (newValue - min) / (max - min)
                    tween(fill, {Size = UDim2.new(finalRel, 0, 1, 0)}, {duration = 0.05})
                    tween(knob, {Position = UDim2.new(finalRel, -9, 0.5, -9)}, {duration = 0.05})
                    valueLbl.Text = tostring(newValue)

                    if callback and type(callback) == "function" then
                        safeCallback(callback, newValue)
                    end
                end

                local beganConn = sliderBg.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or 
                       input.UserInputType == Enum.UserInputType.Touch then
                        dragging = true
                        updateSlider(input.Position)
                        
                        tween(knob, {
                            Size = UDim2.new(0, 22, 0, 22), 
                            Position = UDim2.new((currentValue - min) / (max - min), -11, 0.5, -11)
                        }, {duration = 0.1})
                        tween(knobStroke, {Thickness = 3}, {duration = 0.1})
                    end
                end)

                local changedConn = UserInputService.InputChanged:Connect(function(input)
                    if not dragging then return end
                    
                    if input.UserInputType == Enum.UserInputType.MouseMovement or
                       input.UserInputType == Enum.UserInputType.Touch then
                        updateSlider(input.Position)
                    end
                end)

                local endedConn = UserInputService.InputEnded:Connect(function(input)
                    if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or 
                                    input.UserInputType == Enum.UserInputType.Touch) then
                        dragging = false
                        
                        tween(knob, {
                            Size = UDim2.new(0, 18, 0, 18), 
                            Position = UDim2.new((currentValue - min) / (max - min), -9, 0.5, -9)
                        }, {duration = 0.1})
                        tween(knobStroke, {Thickness = 2}, {duration = 0.1})
                    end
                end)

                local hoverConn1 = sliderBg.MouseEnter:Connect(function()
                    if not dragging then
                        tween(bgStroke, {Transparency = 0.5}, {duration = 0.1})
                        tween(knobStroke, {Thickness = 3}, {duration = 0.1})
                    end
                end)

                local hoverConn2 = sliderBg.MouseLeave:Connect(function()
                    if not dragging then
                        tween(bgStroke, {Transparency = 0.7}, {duration = 0.1})
                        tween(knobStroke, {Thickness = 2}, {duration = 0.1})
                    end
                end)

                globalConnTracker:add(beganConn)
                globalConnTracker:add(changedConn) 
                globalConnTracker:add(endedConn)
                globalConnTracker:add(hoverConn1)
                globalConnTracker:add(hoverConn2)

                return {
                    Set = function(_, value)
                        if type(value) ~= "number" then
                            value = tonumber(value)
                            if not value then return end
                        end
                        
                        value = math.clamp(value, min, max)
                        currentValue = roundValue(value)
                        
                        local rel = (currentValue - min) / (max - min)
                        fill.Size = UDim2.new(rel, 0, 1, 0)
                        knob.Position = UDim2.new(rel, -9, 0.5, -9)
                        valueLbl.Text = tostring(currentValue)
                        
                        if callback and type(callback) == "function" then
                            safeCallback(callback, currentValue)
                        end
                    end,
                    Get = function()
                        return currentValue
                    end,
                    SetMin = function(_, newMin)
                        min = newMin
                        if currentValue < min then
                            currentValue = min
                            valueLbl.Text = tostring(currentValue)
                        end
                    end,
                    SetMax = function(_, newMax)
                        max = newMax
                        if currentValue > max then
                            currentValue = max
                            valueLbl.Text = tostring(currentValue)
                        end
                    end
                }
            end

            function SectionObj:NewTextbox(placeholder, defaultText, callback)
                local wrap = Instance.new("Frame")
                wrap.Size = UDim2.new(1, 0, 0, 36)
                wrap.BackgroundTransparency = 1
                wrap.Parent = Section

                local box = Instance.new("TextBox")
                box.Size = UDim2.new(1, 0, 1, 0)
                box.BackgroundColor3 = theme.InputBackground
                box.TextColor3 = theme.Text
                box.PlaceholderColor3 = theme.SubText
                box.ClearTextOnFocus = false
                box.Text = defaultText or ""
                box.PlaceholderText = placeholder or ""
                box.Font = Enum.Font.Gotham
                box.TextSize = 13
                box.TextXAlignment = Enum.TextXAlignment.Left
                box.Parent = wrap

                local boxCorner = Instance.new("UICorner")
                boxCorner.CornerRadius = UDim.new(0, 8)
                boxCorner.Parent = box

                local boxStroke = Instance.new("UIStroke")
                boxStroke.Color = theme.InputBorder
                boxStroke.Thickness = 1
                boxStroke.Transparency = 0.7
                boxStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                boxStroke.Parent = box

                local boxPadding = Instance.new("UIPadding")
                boxPadding.PaddingLeft = UDim.new(0, 10)
                boxPadding.PaddingRight = UDim.new(0, 10)
                boxPadding.Parent = box

                box.Focused:Connect(function()
                    tween(boxStroke, {
                        Color = theme.Accent, 
                        Transparency = 0
                    }, {duration = 0.15})
                end)

                box.FocusLost:Connect(function(enterPressed)
                    tween(boxStroke, {
                        Color = theme.InputBorder, 
                        Transparency = 0.7
                    }, {duration = 0.15})
                    
                    if enterPressed and type(callback) == "function" then
                        safeCallback(callback, box.Text)
                    end
                end)

                return {
                    TextBox = box,
                    Get = function() return box.Text end,
                    Set = function(_, v) box.Text = tostring(v) end,
                    Focus = function() box:CaptureFocus() end
                }
            end

            function SectionObj:NewKeybind(desc, defaultKey, callback)
                local wrap = Instance.new("Frame")
                wrap.Size = UDim2.new(1, 0, 0, 36)
                wrap.BackgroundTransparency = 1
                wrap.Parent = Section

                local btn = Instance.new("TextButton")
                local curKey = defaultKey and (tostring(defaultKey):gsub("^Enum.KeyCode%.","")) or "None"
                btn.Text = (desc and desc .. " : " or "") .. "[" .. curKey .. "]"
                btn.Size = UDim2.new(1, 0, 1, 0)
                btn.BackgroundColor3 = theme.InputBackground
                btn.TextColor3 = theme.Text
                btn.Font = Enum.Font.Gotham
                btn.TextSize = 13
                btn.AutoButtonColor = false
                btn.Parent = wrap

                local btnCorner = Instance.new("UICorner")
                btnCorner.CornerRadius = UDim.new(0, 8)
                btnCorner.Parent = btn

                local btnStroke = Instance.new("UIStroke")
                btnStroke.Color = theme.InputBorder
                btnStroke.Thickness = 1
                btnStroke.Transparency = 0.7
                btnStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                btnStroke.Parent = btn

                local capturing = false
                local boundKey = defaultKey

                local function updateDisplay()
                    local kName = boundKey and (tostring(boundKey):gsub("^Enum.KeyCode%.","")) or "None"
                    btn.Text = (desc and desc .. " : " or "") .. "[" .. kName .. "]"
                end

                btn.MouseButton1Click:Connect(function()
                    capturing = true
                    btn.Text = (desc and desc .. " : " or "") .. "[Press a key...]"
                    tween(btnStroke, {
                        Color = theme.Accent, 
                        Transparency = 0
                    }, {duration = 0.15})
                end)

                local listenerConn
                listenerConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
                    if gameProcessed then return end
                    if capturing then
                        if input.UserInputType == Enum.UserInputType.Keyboard then
                            boundKey = input.KeyCode
                            capturing = false
                            updateDisplay()
                            tween(btnStroke, {
                                Color = theme.InputBorder, 
                                Transparency = 0.7
                            }, {duration = 0.15})
                        end
                        return
                    end

                    if boundKey and input.UserInputType == Enum.UserInputType.Keyboard and 
                       input.KeyCode == boundKey then
                        safeCallback(callback)
                    end
                end)

                globalConnTracker:add(listenerConn)

                return {
                    Button = btn,
                    GetKey = function() return boundKey end,
                    SetKey = function(_, k) boundKey = k; updateDisplay() end,
                    Disconnect = function() 
                        if listenerConn then 
                            pcall(function() listenerConn:Disconnect() end) 
                        end 
                    end
                }
            end

            function SectionObj:NewDropdown(name, options, default, callback)
                options = options or {}
                if type(options) ~= "table" then 
                    options = {} 
                end
                
                local validOptions = {}
                for i, opt in ipairs(options) do
                    if opt ~= nil then
                        validOptions[i] = tostring(opt)
                    end
                end
                options = validOptions
                
                local current = default and tostring(default) or (options[1] or nil)
                local open = false
                local optionsFrame = nil
                local scrollFrame = nil
                local optionButtons = {}
                local selectedIndex = nil
                
                if current then
                    for i, opt in ipairs(options) do
                        if tostring(opt) == current then
                            selectedIndex = i
                            break
                        end
                    end
                end

                local wrap = Instance.new("Frame")
                wrap.Size = UDim2.new(1, 0, 0, 36)
                wrap.BackgroundTransparency = 1
                wrap.Parent = Section

                local btn = Instance.new("TextButton")
                local displayText = current or "Select..."
                btn.Text = (name and name .. ": " or "") .. displayText
                btn.Size = UDim2.new(1, 0, 1, 0)
                btn.BackgroundColor3 = theme.ButtonBackground
                btn.TextColor3 = theme.Text
                btn.Font = Enum.Font.Gotham
                btn.TextSize = 13
                btn.AutoButtonColor = false
                btn.TextXAlignment = Enum.TextXAlignment.Left
                btn.Parent = wrap

                local btnCorner = Instance.new("UICorner")
                btnCorner.CornerRadius = UDim.new(0, 8)
                btnCorner.Parent = btn

                local btnStroke = Instance.new("UIStroke")
                btnStroke.Color = theme.ButtonBorder
                btnStroke.Thickness = 1
                btnStroke.Transparency = 0.7
                btnStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                btnStroke.Parent = btn

                local btnPadding = Instance.new("UIPadding")
                btnPadding.PaddingLeft = UDim.new(0, 10)
                btnPadding.PaddingRight = UDim.new(0, 32)
                btnPadding.Parent = btn

                local arrow = Instance.new("TextLabel")
                arrow.Text = getArrowChar("down")
                arrow.Size = UDim2.new(0, 20, 1, 0)
                arrow.Position = UDim2.new(1, -24, 0, 0)
                arrow.BackgroundTransparency = 1
                arrow.TextColor3 = theme.SubText
                arrow.Font = Enum.Font.Gotham
                arrow.TextSize = 12
                arrow.TextXAlignment = Enum.TextXAlignment.Center
                arrow.Parent = btn

                local function getMaxDropdownHeight()
                    local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or 
                                     Vector2.new(800, 600)
                    return math.min(220, math.floor(viewport.Y * 0.3))
                end
                
                local function closeOptions()
                    if optionsFrame and optionsFrame.Parent and optionsFrame.Visible then
                        arrow.Text = getArrowChar("down")
                        tween(arrow, {Rotation = 0}, {duration = 0.15})
                        
                        local closeTween = tween(optionsFrame, {
                            Size = UDim2.new(1, 0, 0, 0),
                            BackgroundTransparency = 1
                        }, {duration = 0.15})
                        
                        if scrollFrame then
                            tween(scrollFrame, {ScrollBarImageTransparency = 1}, {duration = 0.1})
                        end
                        
                        for _, optBtn in pairs(optionButtons) do
                            if optBtn and optBtn.Parent then
                                tween(optBtn, {
                                    BackgroundTransparency = 1, 
                                    TextTransparency = 1
                                }, {duration = 0.1})
                            end
                        end
                        
                        if closeTween then
                            local conn
                            conn = closeTween.Completed:Connect(function()
                                pcall(function() conn:Disconnect() end)
                                if optionsFrame then optionsFrame.Visible = false end
                            end)
                        else
                            task.wait(0.15)
                            if optionsFrame then optionsFrame.Visible = false end
                        end
                    end
                    open = false
                    wrap.Size = UDim2.new(1, 0, 0, 36)
                    
                    if Window._currentOpenDropdown == closeOptions then
                        Window._currentOpenDropdown = nil
                    end
                end

                local function createOptionsFrame()
                    if optionsFrame then
                        pcall(function() optionsFrame:Destroy() end)
                    end
                    
                    optionsFrame = Instance.new("Frame")
                    optionsFrame.Name = "_dropdownOptions"
                    optionsFrame.BackgroundColor3 = theme.SectionBackground
                    optionsFrame.BorderSizePixel = 0
                    optionsFrame.Position = UDim2.new(0, 0, 0, 38)
                    optionsFrame.Size = UDim2.new(1, 0, 0, 0)
                    optionsFrame.Visible = false
                    optionsFrame.ClipsDescendants = true
                    optionsFrame.ZIndex = 100
                    optionsFrame.Parent = wrap

                    local corner = Instance.new("UICorner")
                    corner.CornerRadius = UDim.new(0, 8)
                    corner.Parent = optionsFrame

                    local border = Instance.new("UIStroke")
                    border.Color = theme.ButtonBorder
                    border.Thickness = 1
                    border.Transparency = 0.7
                    border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                    border.Parent = optionsFrame

                    scrollFrame = Instance.new("ScrollingFrame")
                    scrollFrame.Name = "_optionsScroll"
                    scrollFrame.Size = UDim2.new(1, -4, 1, -4)
                    scrollFrame.Position = UDim2.new(0, 2, 0, 2)
                    scrollFrame.BackgroundTransparency = 1
                    scrollFrame.BorderSizePixel = 0
                    scrollFrame.ScrollBarThickness = 4
                    scrollFrame.ScrollBarImageColor3 = theme.Accent
                    scrollFrame.ScrollBarImageTransparency = 0.3
                    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
                    scrollFrame.ZIndex = 101
                    scrollFrame.Parent = optionsFrame

                    return optionsFrame, scrollFrame
                end

                local function openOptions()
                    if #options == 0 then
                        Window:Notify("Dropdown Error", "No options available", 2)
                        return
                    end

                    if Window._currentOpenDropdown and Window._currentOpenDropdown ~= closeOptions then
                        pcall(function() Window._currentOpenDropdown() end)
                    end

                    createOptionsFrame()
                    open = true
                    arrow.Text = getArrowChar("up")
                    tween(arrow, {Rotation = 180}, {duration = 0.15})

                    optionButtons = {}

                    local itemHeight = 32
                    local maxHeight = getMaxDropdownHeight()
                    local totalContentHeight = #options * itemHeight
                    local frameHeight = math.min(maxHeight, totalContentHeight)

                    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, totalContentHeight)

                    for i, opt in ipairs(options) do
                        local optBtn = Instance.new("TextButton")
                        optBtn.Size = UDim2.new(1, -8, 0, itemHeight - 4)
                        optBtn.Position = UDim2.new(0, 4, 0, (i-1) * itemHeight + 2)
                        optBtn.BackgroundColor3 = theme.ButtonBackground
                        optBtn.Font = Enum.Font.Gotham
                        optBtn.TextSize = 12
                        optBtn.TextColor3 = theme.Text
                        optBtn.AutoButtonColor = false
                        optBtn.Text = tostring(opt)
                        optBtn.TextXAlignment = Enum.TextXAlignment.Left
                        optBtn.BackgroundTransparency = 1
                        optBtn.TextTransparency = 1
                        optBtn.ZIndex = 102
                        optBtn.Parent = scrollFrame

                        local optCorner = Instance.new("UICorner")
                        optCorner.CornerRadius = UDim.new(0, 6)
                        optCorner.Parent = optBtn

                        local optPadding = Instance.new("UIPadding")
                        optPadding.PaddingLeft = UDim.new(0, 10)
                        optPadding.PaddingRight = UDim.new(0, 10)
                        optPadding.Parent = optBtn

                        if current and tostring(opt) == tostring(current) then
                            selectedIndex = i
                            optBtn.BackgroundColor3 = theme.Accent
                            optBtn.TextColor3 = Color3.fromRGB(255,255,255)
                        end

                        local hoverConn1 = optBtn.MouseEnter:Connect(function()
                            if selectedIndex ~= i then
                                tween(optBtn, {
                                    BackgroundColor3 = theme.ButtonHover
                                }, {duration = 0.1})
                            end
                        end)

                        local hoverConn2 = optBtn.MouseLeave:Connect(function()
                            if selectedIndex ~= i then
                                tween(optBtn, {
                                    BackgroundColor3 = theme.ButtonBackground
                                }, {duration = 0.1})
                            end
                        end)

                        local clickConn = optBtn.MouseButton1Click:Connect(function()
                            selectedIndex = i
                            current = options[i]
                            btn.Text = (name and name .. ": " or "") .. tostring(current)
                            
                            for idx, button in pairs(optionButtons) do
                                if button and button.Parent then
                                    if idx == selectedIndex then
                                        tween(button, {
                                            BackgroundColor3 = theme.Accent
                                        }, {duration = 0.15})
                                        button.TextColor3 = Color3.fromRGB(255,255,255)
                                    else
                                        tween(button, {
                                            BackgroundColor3 = theme.ButtonBackground
                                        }, {duration = 0.15})
                                        button.TextColor3 = theme.Text
                                    end
                                end
                            end
                            
                            if callback and type(callback) == "function" then
                                safeCallback(callback, current)
                            end
                            
                            task.wait(0.1)
                            closeOptions()
                        end)

                        optionButtons[i] = optBtn
                    end

                    optionsFrame.Visible = true
                    optionsFrame.BackgroundTransparency = 1
                    scrollFrame.ScrollBarImageTransparency = 1

                    tween(optionsFrame, {
                        Size = UDim2.new(1, 0, 0, frameHeight + 4),
                        BackgroundTransparency = 0
                    }, {duration = 0.18})

                    tween(scrollFrame, {ScrollBarImageTransparency = 0.3}, {duration = 0.18})

                    for i, optBtn in pairs(optionButtons) do
                        task.delay(i * 0.02, function()
                            if optBtn and optBtn.Parent then
                                tween(optBtn, {
                                    BackgroundTransparency = 0,
                                    TextTransparency = 0
                                }, {duration = 0.12})
                            end
                        end)
                    end

                    wrap.Size = UDim2.new(1, 0, 0, 36 + frameHeight + 8)
                    Window._currentOpenDropdown = closeOptions
                end

                btn.MouseButton1Click:Connect(function()
                    if open then
                        closeOptions()
                    else
                        openOptions()
                    end
                end)

                debouncedHover(btn,
                    function()
                        if not open then
                            tween(btnStroke, {Transparency = 0.5}, {duration = 0.1})
                        end
                    end,
                    function()
                        if not open then
                            tween(btnStroke, {Transparency = 0.7}, {duration = 0.1})
                        end
                    end
                )

                local outsideClickConn
                outsideClickConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
                    if gameProcessed or not open then return end
                    
                    if input.UserInputType == Enum.UserInputType.MouseButton1 then
                        local mouse = UserInputService:GetMouseLocation()
                        local wrapPos = wrap.AbsolutePosition
                        local wrapSize = wrap.AbsoluteSize
                        
                        if mouse.X < wrapPos.X or mouse.X > wrapPos.X + wrapSize.X or
                           mouse.Y < wrapPos.Y or mouse.Y > wrapPos.Y + wrapSize.Y then
                            closeOptions()
                        end
                    end
                end)

                globalConnTracker:add(outsideClickConn)

                local ancestryConn
                ancestryConn = wrap.AncestryChanged:Connect(function()
                    if not wrap.Parent then
                        pcall(function() 
                            outsideClickConn:Disconnect()
                            ancestryConn:Disconnect()
                        end)
                    end
                end)
                globalConnTracker:add(ancestryConn)

                return {
                    Set = function(_, value)
                        local stringValue = tostring(value)
                        for i, opt in ipairs(options) do
                            if tostring(opt) == stringValue then
                                current = stringValue
                                selectedIndex = i
                                btn.Text = (name and name .. ": " or "") .. stringValue
                                if callback and type(callback) == "function" then
                                    safeCallback(callback, stringValue)
                                end
                                return true
                            end
                        end
                        current = stringValue
                        btn.Text = (name and name .. ": " or "") .. stringValue
                        if callback and type(callback) == "function" then
                            safeCallback(callback, stringValue)
                        end
                        return false
                    end,
                    Get = function()
                        return current
                    end,
                    SetOptions = function(_, newOptions)
                        newOptions = newOptions or {}
                        if type(newOptions) ~= "table" then
                            newOptions = {}
                        end
                        
                        local validNewOptions = {}
                        for i, opt in ipairs(newOptions) do
                            if opt ~= nil then
                                validNewOptions[i] = tostring(opt)
                            end
                        end
                        options = validNewOptions
                        
                        if #options > 0 then
                            current = options[1]
                            selectedIndex = 1
                            btn.Text = (name and name .. ": " or "") .. tostring(current)
                        else
                            current = nil
                            selectedIndex = nil
                            btn.Text = (name and name .. ": " or "") .. "Select..."
                        end
                        closeOptions()
                    end,
                    Close = closeOptions
                }
            end

            function SectionObj:NewMultiDropdown(name, options, defaults, callback)
                options = options or {}
                if type(options) ~= "table" then 
                    options = {} 
                end
                
                local validOptions = {}
                for i, opt in ipairs(options) do
                    if opt ~= nil then
                        validOptions[i] = tostring(opt)
                    end
                end
                options = validOptions
                
                -- Initialize selected items
                local selected = {}
                if defaults and type(defaults) == "table" then
                    for _, v in ipairs(defaults) do
                        selected[tostring(v)] = true
                    end
                end
                
                local open = false
                local optionsFrame = nil
                local scrollFrame = nil
                local optionButtons = {}

                local wrap = Instance.new("Frame")
                wrap.Size = UDim2.new(1, 0, 0, 36)
                wrap.BackgroundTransparency = 1
                wrap.Parent = Section

                local function getDisplayText()
                    local selectedList = {}
                    for opt, isSelected in pairs(selected) do
                        if isSelected then
                            table.insert(selectedList, opt)
                        end
                    end
                    
                    if #selectedList == 0 then
                        return "Select..."
                    elseif #selectedList == 1 then
                        return selectedList[1]
                    elseif #selectedList <= 3 then
                        return table.concat(selectedList, ", ")
                    else
                        return selectedList[1] .. ", " .. selectedList[2] .. " (+" .. (#selectedList - 2) .. " more)"
                    end
                end

                local btn = Instance.new("TextButton")
                btn.Text = (name and name .. ": " or "") .. getDisplayText()
                btn.Size = UDim2.new(1, 0, 1, 0)
                btn.BackgroundColor3 = theme.ButtonBackground
                btn.TextColor3 = theme.Text
                btn.Font = Enum.Font.Gotham
                btn.TextSize = 13
                btn.AutoButtonColor = false
                btn.TextXAlignment = Enum.TextXAlignment.Left
                btn.Parent = wrap

                local btnCorner = Instance.new("UICorner")
                btnCorner.CornerRadius = UDim.new(0, 8)
                btnCorner.Parent = btn

                local btnStroke = Instance.new("UIStroke")
                btnStroke.Color = theme.ButtonBorder
                btnStroke.Thickness = 1
                btnStroke.Transparency = 0.7
                btnStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                btnStroke.Parent = btn

                local btnPadding = Instance.new("UIPadding")
                btnPadding.PaddingLeft = UDim.new(0, 10)
                btnPadding.PaddingRight = UDim.new(0, 32)
                btnPadding.Parent = btn

                local arrow = Instance.new("TextLabel")
                arrow.Text = getArrowChar("down")
                arrow.Size = UDim2.new(0, 20, 1, 0)
                arrow.Position = UDim2.new(1, -24, 0, 0)
                arrow.BackgroundTransparency = 1
                arrow.TextColor3 = theme.SubText
                arrow.Font = Enum.Font.Gotham
                arrow.TextSize = 12
                arrow.TextXAlignment = Enum.TextXAlignment.Center
                arrow.Parent = btn

                local function getMaxDropdownHeight()
                    local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or 
                                     Vector2.new(800, 600)
                    return math.min(220, math.floor(viewport.Y * 0.3))
                end
                
                local function closeOptions()
                    if optionsFrame and optionsFrame.Parent and optionsFrame.Visible then
                        arrow.Text = getArrowChar("down")
                        tween(arrow, {Rotation = 0}, {duration = 0.15})
                        
                        local closeTween = tween(optionsFrame, {
                            Size = UDim2.new(1, 0, 0, 0),
                            BackgroundTransparency = 1
                        }, {duration = 0.15})
                        
                        if scrollFrame then
                            tween(scrollFrame, {ScrollBarImageTransparency = 1}, {duration = 0.1})
                        end
                        
                        for _, optBtn in pairs(optionButtons) do
                            if optBtn and optBtn.Parent then
                                tween(optBtn, {
                                    BackgroundTransparency = 1, 
                                    TextTransparency = 1
                                }, {duration = 0.1})
                            end
                        end
                        
                        if closeTween then
                            local conn
                            conn = closeTween.Completed:Connect(function()
                                pcall(function() conn:Disconnect() end)
                                if optionsFrame then optionsFrame.Visible = false end
                            end)
                        else
                            task.wait(0.15)
                            if optionsFrame then optionsFrame.Visible = false end
                        end
                    end
                    open = false
                    wrap.Size = UDim2.new(1, 0, 0, 36)
                    
                    if Window._currentOpenDropdown == closeOptions then
                        Window._currentOpenDropdown = nil
                    end
                end

                local function createOptionsFrame()
                    if optionsFrame then
                        pcall(function() optionsFrame:Destroy() end)
                    end
                    
                    optionsFrame = Instance.new("Frame")
                    optionsFrame.Name = "_dropdownOptions"
                    optionsFrame.BackgroundColor3 = theme.SectionBackground
                    optionsFrame.BorderSizePixel = 0
                    optionsFrame.Position = UDim2.new(0, 0, 0, 38)
                    optionsFrame.Size = UDim2.new(1, 0, 0, 0)
                    optionsFrame.Visible = false
                    optionsFrame.ClipsDescendants = true
                    optionsFrame.ZIndex = 100
                    optionsFrame.Parent = wrap

                    local corner = Instance.new("UICorner")
                    corner.CornerRadius = UDim.new(0, 8)
                    corner.Parent = optionsFrame

                    local border = Instance.new("UIStroke")
                    border.Color = theme.ButtonBorder
                    border.Thickness = 1
                    border.Transparency = 0.7
                    border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                    border.Parent = optionsFrame

                    scrollFrame = Instance.new("ScrollingFrame")
                    scrollFrame.Name = "_optionsScroll"
                    scrollFrame.Size = UDim2.new(1, -4, 1, -4)
                    scrollFrame.Position = UDim2.new(0, 2, 0, 2)
                    scrollFrame.BackgroundTransparency = 1
                    scrollFrame.BorderSizePixel = 0
                    scrollFrame.ScrollBarThickness = 4
                    scrollFrame.ScrollBarImageColor3 = theme.Accent
                    scrollFrame.ScrollBarImageTransparency = 0.3
                    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
                    scrollFrame.ZIndex = 101
                    scrollFrame.Parent = optionsFrame

                    return optionsFrame, scrollFrame
                end

                local function openOptions()
                    if #options == 0 then
                        Window:Notify("Dropdown Error", "No options available", 2)
                        return
                    end

                    if Window._currentOpenDropdown and Window._currentOpenDropdown ~= closeOptions then
                        pcall(function() Window._currentOpenDropdown() end)
                    end

                    createOptionsFrame()
                    open = true
                    arrow.Text = getArrowChar("up")
                    tween(arrow, {Rotation = 180}, {duration = 0.15})

                    optionButtons = {}

                    local itemHeight = 32
                    local maxHeight = getMaxDropdownHeight()
                    local totalContentHeight = #options * itemHeight
                    local frameHeight = math.min(maxHeight, totalContentHeight)

                    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, totalContentHeight)

                    for i, opt in ipairs(options) do
                        local optBtn = Instance.new("TextButton")
                        optBtn.Size = UDim2.new(1, -8, 0, itemHeight - 4)
                        optBtn.Position = UDim2.new(0, 4, 0, (i-1) * itemHeight + 2)
                        optBtn.BackgroundColor3 = theme.ButtonBackground
                        optBtn.Font = Enum.Font.Gotham
                        optBtn.TextSize = 12
                        optBtn.TextColor3 = theme.Text
                        optBtn.AutoButtonColor = false
                        optBtn.Text = tostring(opt)
                        optBtn.TextXAlignment = Enum.TextXAlignment.Left
                        optBtn.BackgroundTransparency = 1
                        optBtn.TextTransparency = 1
                        optBtn.ZIndex = 102
                        optBtn.Parent = scrollFrame

                        local optCorner = Instance.new("UICorner")
                        optCorner.CornerRadius = UDim.new(0, 6)
                        optCorner.Parent = optBtn

                        local optPadding = Instance.new("UIPadding")
                        optPadding.PaddingLeft = UDim.new(0, 10)
                        optPadding.PaddingRight = UDim.new(0, 30)
                        optPadding.Parent = optBtn

                        -- Checkbox indicator - FIXED CHECKMARK
                        local checkbox = Instance.new("TextLabel")
                        checkbox.Size = UDim2.new(0, 18, 0, 18)
                        checkbox.Position = UDim2.new(1, -22, 0.5, -9)
                        checkbox.BackgroundColor3 = theme.InputBackground
                        checkbox.TextColor3 = theme.Accent
                        checkbox.Font = Enum.Font.GothamBold
                        checkbox.TextSize = 14
                        checkbox.Text = selected[tostring(opt)] and "✓" or ""  -- FIXED: Proper checkmark (U+2713)
                        checkbox.ZIndex = 103
                        checkbox.Parent = optBtn

                        local checkCorner = Instance.new("UICorner")
                        checkCorner.CornerRadius = UDim.new(0, 4)
                        checkCorner.Parent = checkbox

                        local checkStroke = Instance.new("UIStroke")
                        checkStroke.Color = selected[tostring(opt)] and theme.Accent or theme.InputBorder
                        checkStroke.Thickness = 1
                        checkStroke.Transparency = 0.7
                        checkStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                        checkStroke.Parent = checkbox

                        if selected[tostring(opt)] then
                            optBtn.BackgroundColor3 = theme.ButtonHover
                        end

                        local hoverConn1 = optBtn.MouseEnter:Connect(function()
                            tween(optBtn, {
                                BackgroundColor3 = theme.ButtonHover
                            }, {duration = 0.1})
                        end)

                        local hoverConn2 = optBtn.MouseLeave:Connect(function()
                            if selected[tostring(opt)] then
                                tween(optBtn, {
                                    BackgroundColor3 = theme.ButtonHover
                                }, {duration = 0.1})
                            else
                                tween(optBtn, {
                                    BackgroundColor3 = theme.ButtonBackground
                                }, {duration = 0.1})
                            end
                        end)

                        local clickConn = optBtn.MouseButton1Click:Connect(function()
                            -- Toggle selection
                            selected[tostring(opt)] = not selected[tostring(opt)]
                            
                            if selected[tostring(opt)] then
                                checkbox.Text = "✓"
                                tween(checkbox, {BackgroundColor3 = theme.Accent}, {duration = 0.15})
                                tween(checkStroke, {
                                    Color = theme.Accent, 
                                    Transparency = 0
                                }, {duration = 0.15})
                                tween(optBtn, {
                                    BackgroundColor3 = theme.ButtonHover
                                }, {duration = 0.15})
                            else
                                checkbox.Text = ""
                                tween(checkbox, {BackgroundColor3 = theme.InputBackground}, {duration = 0.15})
                                tween(checkStroke, {
                                    Color = theme.InputBorder, 
                                    Transparency = 0.7
                                }, {duration = 0.15})
                                tween(optBtn, {
                                    BackgroundColor3 = theme.ButtonBackground
                                }, {duration = 0.15})
                            end
                            
                            -- Update button text
                            btn.Text = (name and name .. ": " or "") .. getDisplayText()
                            
                            -- Call callback with selected items
                            if callback and type(callback) == "function" then
                                local selectedList = {}
                                for o, isSelected in pairs(selected) do
                                    if isSelected then
                                        table.insert(selectedList, o)
                                    end
                                end
                                safeCallback(callback, selectedList)
                            end
                        end)

                        optionButtons[i] = optBtn
                    end

                    optionsFrame.Visible = true
                    optionsFrame.BackgroundTransparency = 1
                    scrollFrame.ScrollBarImageTransparency = 1

                    tween(optionsFrame, {
                        Size = UDim2.new(1, 0, 0, frameHeight + 4),
                        BackgroundTransparency = 0
                    }, {duration = 0.18})

                    tween(scrollFrame, {ScrollBarImageTransparency = 0.3}, {duration = 0.18})

                    for i, optBtn in pairs(optionButtons) do
                        task.delay(i * 0.02, function()
                            if optBtn and optBtn.Parent then
                                tween(optBtn, {
                                    BackgroundTransparency = 0,
                                    TextTransparency = 0
                                }, {duration = 0.12})
                            end
                        end)
                    end

                    wrap.Size = UDim2.new(1, 0, 0, 36 + frameHeight + 8)
                    Window._currentOpenDropdown = closeOptions
                end

                btn.MouseButton1Click:Connect(function()
                    if open then
                        closeOptions()
                    else
                        openOptions()
                    end
                end)

                debouncedHover(btn,
                    function()
                        if not open then
                            tween(btnStroke, {Transparency = 0.5}, {duration = 0.1})
                        end
                    end,
                    function()
                        if not open then
                            tween(btnStroke, {Transparency = 0.7}, {duration = 0.1})
                        end
                    end
                )

                local outsideClickConn
                outsideClickConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
                    if gameProcessed or not open then return end
                    
                    if input.UserInputType == Enum.UserInputType.MouseButton1 then
                        local mouse = UserInputService:GetMouseLocation()
                        local wrapPos = wrap.AbsolutePosition
                        local wrapSize = wrap.AbsoluteSize
                        
                        if mouse.X < wrapPos.X or mouse.X > wrapPos.X + wrapSize.X or
                           mouse.Y < wrapPos.Y or mouse.Y > wrapPos.Y + wrapSize.Y then
                            closeOptions()
                        end
                    end
                end)

                globalConnTracker:add(outsideClickConn)

                local ancestryConn
                ancestryConn = wrap.AncestryChanged:Connect(function()
                    if not wrap.Parent then
                        pcall(function() 
                            outsideClickConn:Disconnect()
                            ancestryConn:Disconnect()
                        end)
                    end
                end)
                globalConnTracker:add(ancestryConn)

                return {
                    Set = function(_, values)
                        if type(values) ~= "table" then
                            values = {values}
                        end
                        
                        selected = {}
                        for _, v in ipairs(values) do
                            selected[tostring(v)] = true
                        end
                        
                        btn.Text = (name and name .. ": " or "") .. getDisplayText()
                        
                        if callback and type(callback) == "function" then
                            local selectedList = {}
                            for o, isSelected in pairs(selected) do
                                if isSelected then
                                    table.insert(selectedList, o)
                                end
                            end
                            safeCallback(callback, selectedList)
                        end
                    end,
                    Get = function()
                        local selectedList = {}
                        for opt, isSelected in pairs(selected) do
                            if isSelected then
                                table.insert(selectedList, opt)
                            end
                        end
                        return selectedList
                    end,
                    SetOptions = function(_, newOptions)
                        newOptions = newOptions or {}
                        if type(newOptions) ~= "table" then
                            newOptions = {}
                        end
                        
                        local validNewOptions = {}
                        for i, opt in ipairs(newOptions) do
                            if opt ~= nil then
                                validNewOptions[i] = tostring(opt)
                            end
                        end
                        options = validNewOptions
                        selected = {}
                        btn.Text = (name and name .. ": " or "") .. getDisplayText()
                        closeOptions()
                    end,
                    Clear = function()
                        selected = {}
                        btn.Text = (name and name .. ": " or "") .. getDisplayText()
                        if callback and type(callback) == "function" then
                            safeCallback(callback, {})
                        end
                    end,
                    Close = closeOptions
                }
            end

            function SectionObj:NewColorpicker(name, defaultColor, callback)
                local currentColor = typeof(defaultColor) == "Color3" and defaultColor or 
                                     Color3.fromRGB(255, 255, 255)
                local currentH, currentS, currentV = Color3.toHSV(currentColor)
                local connections = {}
                
                local container = Instance.new("Frame")
                container.Size = UDim2.new(1, 0, 0, 36)
                container.BackgroundTransparency = 1
                container.Parent = Section

                local button = Instance.new("TextButton")
                button.Size = UDim2.new(1, 0, 1, 0)
                button.BackgroundColor3 = theme.ButtonBackground
                button.AutoButtonColor = false
                button.Font = Enum.Font.Gotham
                button.TextSize = 13
                button.TextColor3 = theme.Text
                button.Text = (name and name .. " " or "") .. "Color Picker"
                button.TextXAlignment = Enum.TextXAlignment.Left
                button.Parent = container

                local buttonCorner = Instance.new("UICorner")
                buttonCorner.CornerRadius = UDim.new(0, 8)
                buttonCorner.Parent = button

                local buttonStroke = Instance.new("UIStroke")
                buttonStroke.Color = theme.ButtonBorder
                buttonStroke.Thickness = 1
                buttonStroke.Transparency = 0.7
                buttonStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                buttonStroke.Parent = button

                local buttonPadding = Instance.new("UIPadding")
                buttonPadding.PaddingLeft = UDim.new(0, 10)
                buttonPadding.PaddingRight = UDim.new(0, 40)
                buttonPadding.Parent = button

                local preview = Instance.new("Frame")
                preview.Size = UDim2.new(0, 26, 0, 26)
                preview.Position = UDim2.new(1, -32, 0.5, -13)
                preview.BackgroundColor3 = currentColor
                preview.BorderSizePixel = 0
                preview.Parent = container

                local previewCorner = Instance.new("UICorner")
                previewCorner.CornerRadius = UDim.new(0, 8)
                previewCorner.Parent = preview

                local previewStroke = Instance.new("UIStroke")
                previewStroke.Color = theme.ButtonBorder
                previewStroke.Thickness = 1
                previewStroke.Transparency = 0.5
                previewStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                previewStroke.Parent = preview

                local function createColorDialog()
                    local guiParent = game:GetService("CoreGui")
                    local success, playerGui = pcall(function()
                        local plr = game:GetService("Players").LocalPlayer
                        if plr and plr:FindFirstChild("PlayerGui") then
                            return plr.PlayerGui
                        end
                    end)
                    if success and playerGui then 
                        guiParent = playerGui 
                    end
                    
                    local colorPickerGui = Instance.new("ScreenGui")
                    colorPickerGui.Name = "ColorPickerOverlay"
                    colorPickerGui.DisplayOrder = 1000000000
                    colorPickerGui.ResetOnSpawn = false
                    colorPickerGui.IgnoreGuiInset = true
                    colorPickerGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
                    colorPickerGui.Parent = guiParent

                    local dialogOverlay = Instance.new("Frame")
                    dialogOverlay.Name = "ColorPickerDialog"
                    dialogOverlay.Size = UDim2.new(1, 0, 1, 0)
                    dialogOverlay.Position = UDim2.new(0, 0, 0, 0)
                    dialogOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
                    dialogOverlay.BackgroundTransparency = 0.5
                    dialogOverlay.ZIndex = 1
                    dialogOverlay.Active = true
                    dialogOverlay.Parent = colorPickerGui

                    local dialog = Instance.new("Frame")
                    dialog.Size = UDim2.new(0, 440, 0, 340)
                    dialog.Position = UDim2.new(0.5, -220, 0.5, -170)
                    dialog.BackgroundColor3 = theme.SectionBackground
                    dialog.ZIndex = 2
                    dialog.Active = true
                    dialog.Parent = dialogOverlay

                    local dialogCorner = Instance.new("UICorner")
                    dialogCorner.CornerRadius = UDim.new(0, 12)
                    dialogCorner.Parent = dialog

                    local dialogStroke = Instance.new("UIStroke")
                    dialogStroke.Color = theme.ButtonBorder
                    dialogStroke.Thickness = 1
                    dialogStroke.Transparency = 0.7
                    dialogStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                    dialogStroke.Parent = dialog

                    addShadow(dialog, 0.6)

                    local title = Instance.new("TextLabel")
                    title.Text = name or "Color Picker"
                    title.Size = UDim2.new(1, -20, 0, 35)
                    title.Position = UDim2.new(0, 10, 0, 10)
                    title.BackgroundTransparency = 1
                    title.TextColor3 = theme.Text
                    title.Font = Enum.Font.GothamBold
                    title.TextSize = 16
                    title.TextXAlignment = Enum.TextXAlignment.Left
                    title.ZIndex = 3
                    title.Parent = dialog

                    local workingH, workingS, workingV = currentH, currentS, currentV

                    local satVibMap = Instance.new("ImageLabel")
                    satVibMap.Size = UDim2.new(0, 190, 0, 170)
                    satVibMap.Position = UDim2.new(0, 20, 0, 60)
                    satVibMap.Image = "rbxassetid://4155801252"
                    satVibMap.BackgroundColor3 = Color3.fromHSV(workingH, 1, 1)
                    satVibMap.ZIndex = 3
                    satVibMap.Active = true
                    satVibMap.Parent = dialog

                    local mapCorner = Instance.new("UICorner")
                    mapCorner.CornerRadius = UDim.new(0, 8)
                    mapCorner.Parent = satVibMap

                    local mapStroke = Instance.new("UIStroke")
                    mapStroke.Color = theme.ButtonBorder
                    mapStroke.Thickness = 1
                    mapStroke.Transparency = 0.7
                    mapStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                    mapStroke.Parent = satVibMap

                    local satVibCursor = Instance.new("ImageLabel")
                    satVibCursor.Size = UDim2.new(0, 20, 0, 20)
                    satVibCursor.Position = UDim2.new(workingS, -10, 1 - workingV, -10)
                    satVibCursor.Image = "rbxassetid://4805639000"
                    satVibCursor.BackgroundTransparency = 1
                    satVibCursor.AnchorPoint = Vector2.new(0.5, 0.5)
                    satVibCursor.ZIndex = 4
                    satVibCursor.Parent = satVibMap

                    local hueSlider = Instance.new("Frame")
                    hueSlider.Size = UDim2.new(0, 14, 0, 200)
                    hueSlider.Position = UDim2.new(0, 220, 0, 60)
                    hueSlider.ZIndex = 3
                    hueSlider.Active = true
                    hueSlider.Parent = dialog

                    local hueCorner = Instance.new("UICorner")
                    hueCorner.CornerRadius = UDim.new(1, 0)
                    hueCorner.Parent = hueSlider

                    local hueStroke = Instance.new("UIStroke")
                    hueStroke.Color = theme.ButtonBorder
                    hueStroke.Thickness = 1
                    hueStroke.Transparency = 0.7
                    hueStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                    hueStroke.Parent = hueSlider

                    local hueGradient = Instance.new("UIGradient")
                    hueGradient.Rotation = 90
                    local sequenceTable = {}
                    for i = 0, 1, 0.1 do
                        table.insert(sequenceTable, ColorSequenceKeypoint.new(i, Color3.fromHSV(i, 1, 1)))
                    end
                    hueGradient.Color = ColorSequence.new(sequenceTable)
                    hueGradient.Parent = hueSlider

                    local hueCursor = Instance.new("ImageLabel")
                    hueCursor.Size = UDim2.new(0, 16, 0, 16)
                    hueCursor.Position = UDim2.new(0, -1, workingH, -8)
                    hueCursor.Image = "rbxassetid://12266946128"
                    hueCursor.ImageColor3 = theme.InputBackground
                    hueCursor.BackgroundTransparency = 1
                    hueCursor.ZIndex = 4
                    hueCursor.Parent = hueSlider

                    local oldColorDisplay = Instance.new("ImageLabel")
                    oldColorDisplay.Size = UDim2.new(0, 94, 0, 28)
                    oldColorDisplay.Position = UDim2.new(0, 120, 0, 240)
                    oldColorDisplay.Image = GRADIENT_IMAGE
                    oldColorDisplay.ImageTransparency = 0.45
                    oldColorDisplay.ScaleType = Enum.ScaleType.Tile
                    oldColorDisplay.TileSize = UDim2.new(0, 40, 0, 40)
                    oldColorDisplay.ZIndex = 3
                    oldColorDisplay.Parent = dialog

                    local oldColorFrame = Instance.new("Frame")
                    oldColorFrame.Size = UDim2.new(1, 0, 1, 0)
                    oldColorFrame.BackgroundColor3 = currentColor
                    oldColorFrame.ZIndex = 4
                    oldColorFrame.Parent = oldColorDisplay

                    local oldCorner = Instance.new("UICorner")
                    oldCorner.CornerRadius = UDim.new(0, 6)
                    oldCorner.Parent = oldColorDisplay

                    local oldFrameCorner = Instance.new("UICorner")
                    oldFrameCorner.CornerRadius = UDim.new(0, 6)
                    oldFrameCorner.Parent = oldColorFrame

                    local oldStroke = Instance.new("UIStroke")
                    oldStroke.Color = theme.ButtonBorder
                    oldStroke.Thickness = 1
                    oldStroke.Transparency = 0.7
                    oldStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                    oldStroke.Parent = oldColorDisplay

                    local newColorDisplay = Instance.new("ImageLabel")
                    newColorDisplay.Size = UDim2.new(0, 94, 0, 28)
                    newColorDisplay.Position = UDim2.new(0, 20, 0, 240)
                    newColorDisplay.Image = GRADIENT_IMAGE
                    newColorDisplay.ImageTransparency = 0.45
                    newColorDisplay.ScaleType = Enum.ScaleType.Tile
                    newColorDisplay.TileSize = UDim2.new(0, 40, 0, 40)
                    newColorDisplay.ZIndex = 3
                    newColorDisplay.Parent = dialog

                    local newColorFrame = Instance.new("Frame")
                    newColorFrame.Size = UDim2.new(1, 0, 1, 0)
                    newColorFrame.BackgroundColor3 = Color3.fromHSV(workingH, workingS, workingV)
                    newColorFrame.ZIndex = 4
                    newColorFrame.Parent = newColorDisplay

                    local newCorner = Instance.new("UICorner")
                    newCorner.CornerRadius = UDim.new(0, 6)
                    newCorner.Parent = newColorDisplay

                    local newFrameCorner = Instance.new("UICorner")
                    newFrameCorner.CornerRadius = UDim.new(0, 6)
                    newFrameCorner.Parent = newColorFrame

                    local newStroke = Instance.new("UIStroke")
                    newStroke.Color = theme.ButtonBorder
                    newStroke.Thickness = 1
                    newStroke.Transparency = 0.7
                    newStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                    newStroke.Parent = newColorDisplay

                    local function createInput(pos, labelText, defaultValue)
                        local inputFrame = Instance.new("Frame")
                        inputFrame.Size = UDim2.new(0, 95, 0, 34)
                        inputFrame.Position = pos
                        inputFrame.BackgroundColor3 = theme.InputBackground
                        inputFrame.ZIndex = 3
                        inputFrame.Parent = dialog

                        local inputCorner = Instance.new("UICorner")
                        inputCorner.CornerRadius = UDim.new(0, 6)
                        inputCorner.Parent = inputFrame

                        local inputStroke = Instance.new("UIStroke")
                        inputStroke.Color = theme.InputBorder
                        inputStroke.Thickness = 1
                        inputStroke.Transparency = 0.7
                        inputStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                        inputStroke.Parent = inputFrame

                        local input = Instance.new("TextBox")
                        input.Size = UDim2.new(1, -14, 1, 0)
                        input.Position = UDim2.new(0, 7, 0, 0)
                        input.BackgroundTransparency = 1
                        input.TextColor3 = theme.Text
                        input.Font = Enum.Font.Gotham
                        input.TextSize = 12
                        input.Text = defaultValue
                        input.ClearTextOnFocus = false
                        input.ZIndex = 4
                        input.Parent = inputFrame

                        local label = Instance.new("TextLabel")
                        label.Text = labelText
                        label.Size = UDim2.new(0, 35, 0, 34)
                        label.Position = UDim2.new(1, 5, 0, 0)
                        label.BackgroundTransparency = 1
                        label.TextColor3 = theme.SubText
                        label.Font = Enum.Font.Gotham
                        label.TextSize = 13
                        label.TextXAlignment = Enum.TextXAlignment.Left
                        label.ZIndex = 3
                        label.Parent = inputFrame

                        input.Focused:Connect(function()
                            tween(inputStroke, {
                                Color = theme.Accent,
                                Transparency = 0
                            }, {duration = 0.15})
                        end)

                        input.FocusLost:Connect(function()
                            tween(inputStroke, {
                                Color = theme.InputBorder,
                                Transparency = 0.7
                            }, {duration = 0.15})
                        end)

                        return input
                    end

                    local hexInput = createInput(UDim2.new(0, 250, 0, 60), "Hex", 
                                                  "#" .. Color3.fromHSV(workingH, workingS, workingV):ToHex())
                    local redInput = createInput(UDim2.new(0, 250, 0, 100), "Red", 
                                                  tostring(math.floor(Color3.fromHSV(workingH, workingS, workingV).r * 255)))
                    local greenInput = createInput(UDim2.new(0, 250, 0, 140), "Green", 
                                                    tostring(math.floor(Color3.fromHSV(workingH, workingS, workingV).g * 255)))
                    local blueInput = createInput(UDim2.new(0, 250, 0, 180), "Blue", 
                                                   tostring(math.floor(Color3.fromHSV(workingH, workingS, workingV).b * 255)))

                    local function updateDisplay()
                        local newColor = Color3.fromHSV(workingH, workingS, workingV)
                        
                        satVibMap.BackgroundColor3 = Color3.fromHSV(workingH, 1, 1)
                        satVibCursor.Position = UDim2.new(workingS, -10, 1 - workingV, -10)
                        hueCursor.Position = UDim2.new(0, -1, workingH, -8)
                        newColorFrame.BackgroundColor3 = newColor
                        
                        hexInput.Text = "#" .. newColor:ToHex()
                        redInput.Text = tostring(math.floor(newColor.r * 255))
                        greenInput.Text = tostring(math.floor(newColor.g * 255))
                        blueInput.Text = tostring(math.floor(newColor.b * 255))
                    end

                    local satVibDragging = false
                    local hueDragging = false

                    local satVibConn = satVibMap.InputBegan:Connect(function(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1 then
                            satVibDragging = true
                        end
                    end)

                    local satVibMoveConn = UserInputService.InputChanged:Connect(function(input)
                        if satVibDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                            local mouse = UserInputService:GetMouseLocation()
                            local mapPos = satVibMap.AbsolutePosition
                            local mapSize = satVibMap.AbsoluteSize
                            
                            local relX = math.clamp((mouse.X - mapPos.X) / mapSize.X, 0, 1)
                            local relY = math.clamp((mouse.Y - mapPos.Y) / mapSize.Y, 0, 1)
                            
                            workingS = relX
                            workingV = 1 - relY
                            updateDisplay()
                        end
                    end)

                    local satVibEndConn = UserInputService.InputEnded:Connect(function(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1 then
                            satVibDragging = false
                        end
                    end)

                    local hueConn = hueSlider.InputBegan:Connect(function(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1 then
                            hueDragging = true
                        end
                    end)

                    local hueMoveConn = UserInputService.InputChanged:Connect(function(input)
                        if hueDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                            local mouse = UserInputService:GetMouseLocation()
                            local sliderPos = hueSlider.AbsolutePosition
                            local sliderSize = hueSlider.AbsoluteSize
                            
                            local relY = math.clamp((mouse.Y - sliderPos.Y) / sliderSize.Y, 0, 1)
                            workingH = relY
                            updateDisplay()
                        end
                    end)

                    local hueEndConn = UserInputService.InputEnded:Connect(function(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1 then
                            hueDragging = false
                        end
                    end)

                    local buttonContainer = Instance.new("Frame")
                    buttonContainer.Size = UDim2.new(0, 210, 0, 36)
                    buttonContainer.Position = UDim2.new(0, 20, 0, 290)
                    buttonContainer.BackgroundTransparency = 1
                    buttonContainer.ZIndex = 3
                    buttonContainer.Parent = dialog

                    local buttonLayout = Instance.new("UIListLayout")
                    buttonLayout.FillDirection = Enum.FillDirection.Horizontal
                    buttonLayout.Padding = UDim.new(0, 10)
                    buttonLayout.Parent = buttonContainer

                    local cancelBtn = Instance.new("TextButton")
                    cancelBtn.Size = UDim2.new(0, 100, 1, 0)
                    cancelBtn.BackgroundColor3 = theme.ButtonBackground
                    cancelBtn.TextColor3 = theme.Text
                    cancelBtn.Font = Enum.Font.Gotham
                    cancelBtn.TextSize = 14
                    cancelBtn.Text = "Cancel"
                    cancelBtn.AutoButtonColor = false
                    cancelBtn.ZIndex = 4
                    cancelBtn.Parent = buttonContainer

                    local cancelCorner = Instance.new("UICorner")
                    cancelCorner.CornerRadius = UDim.new(0, 8)
                    cancelCorner.Parent = cancelBtn

                    local cancelStroke = Instance.new("UIStroke")
                    cancelStroke.Color = theme.ButtonBorder
                    cancelStroke.Thickness = 1
                    cancelStroke.Transparency = 0.7
                    cancelStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                    cancelStroke.Parent = cancelBtn

                    local doneBtn = Instance.new("TextButton")
                    doneBtn.Size = UDim2.new(0, 100, 1, 0)
                    doneBtn.BackgroundColor3 = theme.Accent
                    doneBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
                    doneBtn.Font = Enum.Font.Gotham
                    doneBtn.TextSize = 14
                    doneBtn.Text = "Done"
                    doneBtn.AutoButtonColor = false
                    doneBtn.ZIndex = 4
                    doneBtn.Parent = buttonContainer

                    local doneCorner = Instance.new("UICorner")
                    doneCorner.CornerRadius = UDim.new(0, 8)
                    doneCorner.Parent = doneBtn

                    local doneStroke = Instance.new("UIStroke")
                    doneStroke.Color = theme.Accent
                    doneStroke.Thickness = 1
                    doneStroke.Transparency = 0
                    doneStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                    doneStroke.Parent = doneBtn

                    debouncedHover(cancelBtn,
                        function()
                            tween(cancelBtn, {BackgroundColor3 = theme.ButtonHover}, {duration = 0.1})
                            tween(cancelStroke, {Transparency = 0.5}, {duration = 0.1})
                        end,
                        function()
                            tween(cancelBtn, {BackgroundColor3 = theme.ButtonBackground}, {duration = 0.1})
                            tween(cancelStroke, {Transparency = 0.7}, {duration = 0.1})
                        end
                    )

                    debouncedHover(doneBtn,
                        function()
                            tween(doneBtn, {BackgroundColor3 = theme.AccentHover}, {duration = 0.1})
                        end,
                        function()
                            tween(doneBtn, {BackgroundColor3 = theme.Accent}, {duration = 0.1})
                        end
                    )

                    local function closeDialog()
                        pcall(function() satVibConn:Disconnect() end)
                        pcall(function() satVibMoveConn:Disconnect() end)
                        pcall(function() satVibEndConn:Disconnect() end)
                        pcall(function() hueConn:Disconnect() end)
                        pcall(function() hueMoveConn:Disconnect() end)
                        pcall(function() hueEndConn:Disconnect() end)
                        
                        tween(dialogOverlay, {BackgroundTransparency = 1}, {duration = 0.2})
                        tween(dialog, {
                            Size = UDim2.new(0, 0, 0, 0), 
                            Position = UDim2.new(0.5, 0, 0.5, 0)
                        }, {duration = 0.2})
                        
                        task.delay(0.2, function()
                            if colorPickerGui then
                                colorPickerGui:Destroy()
                            end
                        end)
                    end

                    cancelBtn.MouseButton1Click:Connect(closeDialog)

                    doneBtn.MouseButton1Click:Connect(function()
                        currentColor = Color3.fromHSV(workingH, workingS, workingV)
                        currentH, currentS, currentV = workingH, workingS, workingV
                        preview.BackgroundColor3 = currentColor
                        
                        if callback and type(callback) == "function" then
                            safeCallback(callback, currentColor)
                        end
                        
                        closeDialog()
                    end)

                    dialog.MouseButton1Click:Connect(function()
                        -- Prevent click bubbling
                    end)

                    dialogOverlay.MouseButton1Click:Connect(function()
                        closeDialog()
                    end)

                    dialog.Size = UDim2.new(0, 0, 0, 0)
                    dialog.Position = UDim2.new(0.5, 0, 0.5, 0)
                    dialogOverlay.BackgroundTransparency = 1
                    
                    tween(dialogOverlay, {BackgroundTransparency = 0.5}, {duration = 0.2})
                    tween(dialog, {
                        Size = UDim2.new(0, 440, 0, 340), 
                        Position = UDim2.new(0.5, -220, 0.5, -170)
                    }, {duration = 0.2})
                end

                local clickConn = button.MouseButton1Click:Connect(function()
                    createColorDialog()
                end)
                table.insert(connections, clickConn)

                debouncedHover(button,
                    function()
                        tween(button, {BackgroundColor3 = theme.ButtonHover}, {duration = 0.1})
                        tween(buttonStroke, {Transparency = 0.5}, {duration = 0.1})
                    end,
                    function()
                        tween(button, {BackgroundColor3 = theme.ButtonBackground}, {duration = 0.1})
                        tween(buttonStroke, {Transparency = 0.7}, {duration = 0.1})
                    end
                )

                return {
                    Get = function() return currentColor end,
                    Set = function(_, color)
                        if typeof(color) == "Color3" then
                            currentColor = color
                            currentH, currentS, currentV = Color3.toHSV(color)
                            preview.BackgroundColor3 = color
                            if callback then safeCallback(callback, color) end
                        end
                    end
                }
            end

            SectionObj.NewColorPicker = SectionObj.NewColorpicker
            SectionObj.NewTextBox = SectionObj.NewTextbox
            SectionObj.NewKeyBind = SectionObj.NewKeybind

            return SectionObj
        end

        return TabObj
    end

    Window:SetTheme(themeName or "Modern")

    -- Periodic maintenance
    local MAINTENANCE_INTERVAL = 5
    local accumDt = 0
    local maintConn = RunService.Heartbeat:Connect(function(dt)
        accumDt = accumDt + dt
        if accumDt >= MAINTENANCE_INTERVAL then
            accumDt = 0
            for obj, props in pairs(ActiveTweens) do
                if not obj or (type(obj) == "userdata" and not pcall(function() return obj.Parent end)) then
                    ActiveTweens[obj] = nil
                else
                    if type(props) == "table" and next(props) == nil then
                        ActiveTweens[obj] = nil
                    end
                end
            end
            for t,_ in pairs(_tweenTimestamps) do
                if _tweenTimestamps[t] and (tick() - _tweenTimestamps[t]) > 30 then
                    _tweenTimestamps[t] = nil
                end
            end
        end
    end)

    Window._maintConn = maintConn

    -- Window controls setup
    Window._minimizeBtn = MinimizeBtn
    Window._closeBtn = CloseBtn
    Window._topbar = Topbar
    Window._title = Title

    local minimizeConn = MinimizeBtn.MouseButton1Click:Connect(function()
        pcall(function()
            Window:ToggleMinimize()
        end)
    end)
    globalConnTracker:add(minimizeConn)

    local closeConn = CloseBtn.MouseButton1Click:Connect(function()
        local pressTween = tween(CloseBtn, {
            Size = UDim2.new(0, 32, 0, 32),
            BackgroundColor3 = Color3.fromRGB(200, 35, 51)
        }, {duration = 0.08})
        
        if pressTween then
            local conn
            conn = pressTween.Completed:Connect(function()
                pcall(function() conn:Disconnect() end)
                Window:Destroy()
            end)
        else
            task.delay(0.08, function()
                Window:Destroy()
            end)
        end
    end)
    globalConnTracker:add(closeConn)

    debouncedHover(MinimizeBtn,
        function()
            tween(MinimizeBtn, {
                BackgroundColor3 = theme.ButtonHover,
                Size = UDim2.new(0, 37, 0, 37)
            }, {duration = 0.1})
            tween(MinimizeBtnStroke, {Transparency = 0.5}, {duration = 0.1})
        end,
        function()
            tween(MinimizeBtn, {
                BackgroundColor3 = theme.ButtonBackground,
                Size = UDim2.new(0, 35, 0, 35)
            }, {duration = 0.1})
            tween(MinimizeBtnStroke, {Transparency = 0.7}, {duration = 0.1})
        end
    )

    debouncedHover(CloseBtn,
        function()
            tween(CloseBtn, {
                BackgroundColor3 = Color3.fromRGB(240, 73, 89),
                Size = UDim2.new(0, 37, 0, 37)
            }, {duration = 0.1})
        end,
        function()
            tween(CloseBtn, {
                BackgroundColor3 = Color3.fromRGB(220, 53, 69),
                Size = UDim2.new(0, 35, 0, 35)
            }, {duration = 0.1})
        end
    )

    Window:SetToggleKey(Enum.KeyCode.RightControl)

    return Window
end

return Kour6anHub
