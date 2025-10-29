-- InterfaceManager for Kour6anHub
-- Handles theme management and interface settings

local InterfaceManager = {}
InterfaceManager.__index = InterfaceManager

function InterfaceManager:New()
    local self = setmetatable({}, InterfaceManager)
    
    self.Library = nil
    self.Folder = "Kour6anHub"
    
    return self
end

function InterfaceManager:SetLibrary(library)
    self.Library = library
    return self
end

function InterfaceManager:SetFolder(folder)
    self.Folder = folder
    
    if not isfolder(self.Folder) then
        makefolder(self.Folder)
    end
    
    return self
end

function InterfaceManager:BuildInterfaceSection(tab)
    assert(self.Library, "Library must be set using SetLibrary before building interface section")
    
    local section = tab:NewSection("Interface Settings")
    
    -- Theme selector
    local themes = self.Library:GetThemeList()
    local savedSettings = self:LoadInterfaceSettings()
    local currentTheme = (savedSettings and savedSettings.Theme) or "Dark"
    
    section:NewDropdown("Theme", themes, currentTheme, function(value)
        if self.Library and self.Library.SetTheme then
            self.Library:SetTheme(value)
        end
        self:SaveInterfaceSettings("Theme", value)
    end)
    
    -- UI Toggle keybind
    local defaultKey = (savedSettings and savedSettings.ToggleKey) or "RightControl"
    local toggleKeybind = section:NewKeybind("Toggle UI Keybind", Enum.KeyCode[defaultKey], function()
        -- Keybind functionality handled internally
    end)
    
    -- Save keybind when changed
    if toggleKeybind and toggleKeybind.Button then
        local conn = toggleKeybind.Button:GetPropertyChangedSignal("Text"):Connect(function()
            local key = toggleKeybind:GetKey()
            if key then
                local keyName = tostring(key):gsub("Enum.KeyCode.", "")
                self:SaveInterfaceSettings("ToggleKey", keyName)
                if self.Library and self.Library.SetToggleKey then
                    self.Library:SetToggleKey(key)
                end
            end
        end)
    end
    
    -- Reduced motion toggle
    local reducedMotion = (savedSettings and savedSettings.ReducedMotion) or false
    section:NewToggle("Reduced Motion", "Disable animations for better performance", reducedMotion, function(value)
        _G.ReducedMotion = value
        self:SaveInterfaceSettings("ReducedMotion", value)
    end)
    
    -- Notification duration slider
    local notifDuration = (savedSettings and savedSettings.NotificationDuration) or 4
    section:NewSlider("Notification Duration", 1, 10, notifDuration, function(value)
        if self.Library and self.Library._notifConfig then
            self.Library._notifConfig.defaultDuration = value
            self:SaveInterfaceSettings("NotificationDuration", value)
        end
    end)
    
    section:NewSeparator()
    
    -- Window controls
    section:NewButton("Minimize Window", "Minimize the UI window", function()
        if self.Library and self.Library.Minimize then
            self.Library:Minimize()
        end
    end)
    
    section:NewButton("Center Window", "Reset window position to center", function()
        if self.Library and self.Library.Main then
            self.Library.Main.Position = UDim2.new(0.5, -310, 0.5, -210)
            self.Library._storedPosition = self.Library.Main.Position
            if self.Library.Notify then
                self.Library:Notify("Window Reset", "Window position reset to center", 2)
            end
        end
    end)
end

function InterfaceManager:SaveInterfaceSettings(key, value)
    local settingsPath = self.Folder .. "/interface_settings.json"
    local settings = {}
    
    if isfile(settingsPath) then
        local success, content = pcall(function()
            return readfile(settingsPath)
        end)
        
        if success then
            local decoded
            success, decoded = pcall(function()
                return game:GetService("HttpService"):JSONDecode(content)
            end)
            
            if success and decoded then
                settings = decoded
            end
        end
    end
    
    settings[key] = value
    
    local success, encoded = pcall(function()
        return game:GetService("HttpService"):JSONEncode(settings)
    end)
    
    if success then
        if not isfolder(self.Folder) then
            makefolder(self.Folder)
        end
        writefile(settingsPath, encoded)
    end
end

function InterfaceManager:LoadInterfaceSettings()
    local settingsPath = self.Folder .. "/interface_settings.json"
    
    if not isfile(settingsPath) then
        return nil
    end
    
    local success, content = pcall(function()
        return readfile(settingsPath)
    end)
    
    if not success then
        return nil
    end
    
    local settings
    success, settings = pcall(function()
        return game:GetService("HttpService"):JSONDecode(content)
    end)
    
    if not success or type(settings) ~= "table" then
        return nil
    end
    
    -- Apply saved theme
    if settings.Theme and self.Library then
        task.defer(function()
            if self.Library and self.Library.SetTheme then
                self.Library:SetTheme(settings.Theme)
            end
        end)
    end
    
    -- Apply notification duration
    if settings.NotificationDuration and self.Library and self.Library._notifConfig then
        self.Library._notifConfig.defaultDuration = settings.NotificationDuration
    end
    
    -- Apply reduced motion
    if settings.ReducedMotion ~= nil then
        _G.ReducedMotion = settings.ReducedMotion
    end
    
    -- Apply toggle key
    if settings.ToggleKey and self.Library and self.Library.SetToggleKey then
        local success, keyEnum = pcall(function()
            return Enum.KeyCode[settings.ToggleKey]
        end)
        if success and keyEnum then
            task.defer(function()
                if self.Library and self.Library.SetToggleKey then
                    self.Library:SetToggleKey(keyEnum)
                end
            end)
        end
    end
    
    return settings
end

return InterfaceManager
