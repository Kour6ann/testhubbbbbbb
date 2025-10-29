-- SaveManager for Kour6anHub
-- Handles configuration saving and loading

local SaveManager = {}
SaveManager.__index = SaveManager

local HttpService = game:GetService("HttpService")

function SaveManager:New(configFolder)
    local self = setmetatable({}, SaveManager)
    
    self.ConfigFolder = configFolder or "Kour6anHub_Configs"
    self.Elements = {}
    self.IgnoreList = {}
    self.Library = nil
    self.Parser = {
        Toggle = {
            Save = function(element) 
                return element:GetState() 
            end,
            Load = function(element, value) 
                if type(value) == "boolean" then
                    element:SetState(value)
                end
            end
        },
        Slider = {
            Save = function(element) 
                return element:Get() 
            end,
            Load = function(element, value) 
                if type(value) == "number" then
                    element:Set(value)
                end
            end
        },
        Dropdown = {
            Save = function(element) 
                return element:Get() 
            end,
            Load = function(element, value) 
                if type(value) == "string" then
                    element:Set(value)
                end
            end
        },
        MultiDropdown = {
            Save = function(element) 
                return element:Get()
            end,
            Load = function(element, value) 
                if type(value) == "table" then
                    element:Set(value)
                end
            end
        },
        ColorPicker = {
            Save = function(element)
                local color = element:Get()
                return {R = color.R, G = color.G, B = color.B}
            end,
            Load = function(element, value)
                if type(value) == "table" and value.R and value.G and value.B then
                    element:Set(Color3.new(value.R, value.G, value.B))
                end
            end
        },
        Keybind = {
            Save = function(element)
                local key = element:GetKey()
                return key and tostring(key) or "None"
            end,
            Load = function(element, value)
                if value and value ~= "None" and type(value) == "string" then
                    local success, keycode = pcall(function()
                        return Enum.KeyCode[value:gsub("Enum.KeyCode.", "")]
                    end)
                    if success and keycode then
                        element:SetKey(keycode)
                    end
                end
            end
        },
        Textbox = {
            Save = function(element)
                return element:Get()
            end,
            Load = function(element, value)
                if type(value) == "string" then
                    element:Set(value)
                end
            end
        }
    }
    
    return self
end

function SaveManager:SetLibrary(library)
    self.Library = library
    return self
end

function SaveManager:SetIgnoreIndexes(list)
    for _, name in ipairs(list) do
        self.IgnoreList[name] = true
    end
end

function SaveManager:IgnoreThemeSettings()
    self.IgnoreList["Theme"] = true
end

function SaveManager:SetFolder(folder)
    self.ConfigFolder = folder
end

function SaveManager:RegisterElement(name, element, elementType)
    if self.IgnoreList[name] then return end
    
    if not self.Parser[elementType] then
        warn("[SaveManager] Unknown element type:", elementType, "for", name)
        return
    end
    
    self.Elements[name] = {
        Element = element,
        Type = elementType
    }
end

function SaveManager:Save(configName)
    configName = configName or "config"
    local data = {}
    
    for name, info in pairs(self.Elements) do
        local parser = self.Parser[info.Type]
        if parser and parser.Save then
            local success, result = pcall(function()
                return parser.Save(info.Element)
            end)
            
            if success then
                data[name] = result
            else
                warn("[SaveManager] Failed to save element:", name, result)
            end
        end
    end
    
    local success, encoded = pcall(function()
        return HttpService:JSONEncode(data)
    end)
    
    if not success then
        warn("[SaveManager] Failed to encode data:", encoded)
        return false
    end
    
    if not isfolder(self.ConfigFolder) then
        makefolder(self.ConfigFolder)
    end
    
    local filePath = self.ConfigFolder .. "/" .. configName .. ".json"
    writefile(filePath, encoded)
    return true
end

function SaveManager:Load(configName)
    configName = configName or "config"
    local filePath = self.ConfigFolder .. "/" .. configName .. ".json"
    
    if not isfile(filePath) then
        return false
    end
    
    local success, content = pcall(function()
        return readfile(filePath)
    end)
    
    if not success then
        warn("[SaveManager] Failed to read config file:", content)
        return false
    end
    
    local decoded
    success, decoded = pcall(function()
        return HttpService:JSONDecode(content)
    end)
    
    if not success then
        warn("[SaveManager] Failed to decode config:", decoded)
        return false
    end
    
    for name, value in pairs(decoded) do
        local info = self.Elements[name]
        if info then
            local parser = self.Parser[info.Type]
            if parser and parser.Load then
                local loadSuccess, err = pcall(function()
                    parser.Load(info.Element, value)
                end)
                
                if not loadSuccess then
                    warn("[SaveManager] Failed to load element:", name, err)
                end
            end
        end
    end
    
    return true
end

function SaveManager:Delete(configName)
    configName = configName or "config"
    local filePath = self.ConfigFolder .. "/" .. configName .. ".json"
    
    if isfile(filePath) then
        delfile(filePath)
        return true
    end
    return false
end

function SaveManager:GetConfigList()
    if not isfolder(self.ConfigFolder) then
        return {}
    end
    
    local configs = {}
    local files = listfiles(self.ConfigFolder)
    
    for _, file in ipairs(files) do
        if file:match("%.json$") then
            local name = file:match("([^/\\]+)%.json$")
            if name and name ~= "autoload" then
                table.insert(configs, name)
            end
        end
    end
    
    return configs
end

function SaveManager:SetAutoloadConfig(configName)
    if not isfolder(self.ConfigFolder) then
        makefolder(self.ConfigFolder)
    end
    
    local autoloadPath = self.ConfigFolder .. "/autoload.json"
    local data = {autoload = configName}
    
    local success, encoded = pcall(function()
        return HttpService:JSONEncode(data)
    end)
    
    if success then
        writefile(autoloadPath, encoded)
        return true
    end
    return false
end

function SaveManager:GetAutoloadConfig()
    local autoloadPath = self.ConfigFolder .. "/autoload.json"
    
    if not isfile(autoloadPath) then
        return nil
    end
    
    local success, content = pcall(function()
        return readfile(autoloadPath)
    end)
    
    if not success then
        return nil
    end
    
    local decoded
    success, decoded = pcall(function()
        return HttpService:JSONDecode(content)
    end)
    
    if success and decoded and decoded.autoload then
        return decoded.autoload
    end
    
    return nil
end

function SaveManager:LoadAutoloadConfig()
    local autoload = self:GetAutoloadConfig()
    if autoload then
        return self:Load(autoload)
    end
    return false
end

function SaveManager:BuildConfigSection(tab)
    local section = tab:NewSection("Configuration")
    
    local configList = self:GetConfigList()
    local selectedConfig = configList[1] or "default"
    
    local configDropdown = section:NewDropdown(
        "Select Config",
        #configList > 0 and configList or {"No configs found"},
        selectedConfig,
        function(value)
            selectedConfig = value
        end
    )
    
    section:NewButton("Save Config", "Save current settings", function()
        if self:Save(selectedConfig) then
            if self.Library then
                self.Library:Notify("Config Saved", "Configuration saved as: " .. selectedConfig, 3)
            end
        else
            if self.Library then
                self.Library:Notify("Save Failed", "Failed to save configuration", 3)
            end
        end
    end)
    
    section:NewButton("Load Config", "Load saved settings", function()
        if self:Load(selectedConfig) then
            if self.Library then
                self.Library:Notify("Config Loaded", "Configuration loaded: " .. selectedConfig, 3)
            end
        else
            if self.Library then
                self.Library:Notify("Load Failed", "Failed to load configuration", 3)
            end
        end
    end)
    
    section:NewButton("Delete Config", "Delete selected config", function()
        if self:Delete(selectedConfig) then
            if self.Library then
                self.Library:Notify("Config Deleted", "Configuration deleted: " .. selectedConfig, 3)
            end
            configList = self:GetConfigList()
            if configDropdown and configDropdown.SetOptions then
                configDropdown:SetOptions(#configList > 0 and configList or {"No configs found"})
            end
        else
            if self.Library then
                self.Library:Notify("Delete Failed", "Failed to delete configuration", 3)
            end
        end
    end)
    
    section:NewButton("Refresh List", "Refresh config list", function()
        configList = self:GetConfigList()
        if configDropdown and configDropdown.SetOptions then
            configDropdown:SetOptions(#configList > 0 and configList or {"No configs found"})
        end
        if self.Library then
            self.Library:Notify("Refreshed", "Config list updated", 2)
        end
    end)
    
    section:NewSeparator()
    
    local configNameBox = section:NewTextbox("New Config Name", "MyConfig", function() end)
    
    section:NewButton("Create New Config", "Create config with custom name", function()
        local newName = configNameBox and configNameBox:Get() or ""
        if newName and newName ~= "" then
            if self:Save(newName) then
                if self.Library then
                    self.Library:Notify("Config Created", "New configuration created: " .. newName, 3)
                end
                configList = self:GetConfigList()
                if configDropdown then
                    if configDropdown.SetOptions then
                        configDropdown:SetOptions(configList)
                    end
                    if configDropdown.Set then
                        configDropdown:Set(newName)
                    end
                end
                selectedConfig = newName
            end
        else
            if self.Library then
                self.Library:Notify("Invalid Name", "Please enter a valid config name", 3)
            end
        end
    end)
    
    section:NewSeparator()
    
    section:NewButton("Set as Auto-load", "Automatically load this config on startup", function()
        if self:SetAutoloadConfig(selectedConfig) then
            if self.Library then
                self.Library:Notify("Auto-load Set", selectedConfig .. " will load automatically", 3)
            end
        end
    end)
    
    local currentAutoload = self:GetAutoloadConfig()
    if currentAutoload then
        section:NewLabel("Current Auto-load: " .. currentAutoload)
    else
        section:NewLabel("No Auto-load config set")
    end
end

function SaveManager:AutoSave(interval)
    interval = interval or 60
    
    task.spawn(function()
        while true do
            task.wait(interval)
            self:Save()
        end
    end)
end

return SaveManager
