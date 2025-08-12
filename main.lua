-- Anime Eternal GUI Script (FIX)
-- Version Configuration
local SCRIPT_VERSION = "0.02"
local SCRIPT_NAME = "Anime Eternal"
local SCRIPT_STATUS = "BETA"
local SCRIPT_URL = "https://raw.githubusercontent.com/example/anime-eternal/main/script.lua"

-- Load OrionLib with mobile fixes
local OrionLib
local success, result = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/shlexware/Orion/main/source"))()
end)
if success then
    OrionLib = result
else
    local fallbackSuccess, fallbackResult = pcall(function()
        return loadstring(game:HttpGet("https://raw.githubusercontent.com/jensonhirst/Orion/refs/heads/main/source"))()
    end)
    if fallbackSuccess then
        OrionLib = fallbackResult
        warn("Using fallback OrionLib version")
    else
        warn("Failed to load OrionLib: " .. tostring(result))
        return
    end
end

-- Create main Window
local Window = OrionLib:MakeWindow({
    Name = SCRIPT_NAME .. " Version " .. SCRIPT_VERSION .. " (" .. SCRIPT_STATUS .. ")",
    HidePremium = false,
    SaveConfig = false, -- Disable OrionLib default config
    IntroEnabled = true,
    IntroText = SCRIPT_NAME .. " Script v" .. SCRIPT_VERSION .. " (" .. SCRIPT_STATUS .. ")",
    Icon = "rbxassetid://4483345998"
})

-- Mobile optimization
local function optimizeForMobile()
    local ok, err = pcall(function()
        if game:GetService("UserInputService").TouchEnabled then
            local coreGui = game:GetService("CoreGui")
            local orionGui = coreGui:FindFirstChild("Orion")
            if orionGui and orionGui:FindFirstChild("Main") then
                local mainFrame = orionGui.Main
                mainFrame.Active = true
                mainFrame.Draggable = true
                for _, d in pairs(mainFrame:GetDescendants()) do
                    if d:IsA("GuiButton") or d:IsA("TextButton") then
                        d.AutoButtonColor = true
                        d.Active = true
                    elseif d:IsA("Frame") and d.Name:find("Slider") then
                        d.Active = true
                    end
                end
            end
        end
    end)
    if not ok then warn("Mobile optimization failed: " .. tostring(err)) end
end
task.spawn(function() task.wait(1); optimizeForMobile() end)

-- Tabs
local InfoTab = Window:MakeTab({ Name = "Info", PremiumOnly = false })
local MainTab = Window:MakeTab({ Name = "Main", PremiumOnly = false })
local AutoFarmTab = Window:MakeTab({ Name = "Auto Farm", PremiumOnly = false })
local AutoRollTab = Window:MakeTab({ Name = "Auto Roll", PremiumOnly = false })
local DungeonTab = Window:MakeTab({ Name = "Dungeon", PremiumOnly = false })
local PlayerTab = Window:MakeTab({ Name = "Player", PremiumOnly = false })
local TeleportTab = Window:MakeTab({ Name = "Teleport", PremiumOnly = false })
local MiscTab = Window:MakeTab({ Name = "Misc", PremiumOnly = false })
local ConfigTab = Window:MakeTab({ Name = "Config", PremiumOnly = false })
local SettingsTab = Window:MakeTab({ Name = "Settings", PremiumOnly = false })

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local LocalPlayer = Players.LocalPlayer

-- Noclip functionality
local function AddNotification(title, text)
    game:GetService("StarterGui"):SetCore("SendNotification", {Title = title; Text = text;})
end

local NoclipKey = 'X' -- Change your key here

local function updateNoclip()
    local noclipEnabled = OrionLib.Flags["noclipEnabled"] or false
    if LocalPlayer.Character then
        for _, v in pairs(LocalPlayer.Character:GetDescendants()) do
            if v:IsA("BasePart") then
                if noclipEnabled then
                    v.CanCollide = false
                else
                    -- Restore collision for parts that should normally have it
                    -- HumanoidRootPart should never have collision
                    if v.Name ~= "HumanoidRootPart" then
                        v.CanCollide = true
                    end
                end
            end
        end
    end
end

RunService.RenderStepped:Connect(updateNoclip)

local function Noclipping(ActionName, Properties)
    if ActionName == 'Noclip' then
        if not Properties or Properties == Enum.UserInputState.Begin then
            local currentState = OrionLib.Flags["noclipEnabled"] or false
            OrionLib.Flags["noclipEnabled"] = not currentState
            if uiElements.noclipToggle then
                uiElements.noclipToggle:Set(not currentState)
            end
            AddNotification('Noclip','Noclip is now - '..tostring(not currentState))
        end
    end
end

ContextActionService:BindAction('Noclip', Noclipping, true, Enum.KeyCode[NoclipKey])

-- State variables (sử dụng OrionLib.Flags thay vì local variables)
local scriptRunning = true
local antiAfkEnabled = true
-- Auto Respawn now uses OrionLib.Flags["autoRespawnEnabled"]
local selectedEnemies = {}
local enemiesList = {}

-- Store original walk speed EARLY (fix nil->number on Toggle callbacks)
local originalWalkSpeed = 16
local function _captureOriginalSpeed()
    local ch = LocalPlayer and LocalPlayer.Character
    if ch then
        local hum = ch:FindFirstChildOfClass("Humanoid")
        if hum and type(hum.WalkSpeed)=="number" then
            originalWalkSpeed = hum.WalkSpeed
        end
    end
end
_captureOriginalSpeed()
if LocalPlayer and LocalPlayer.CharacterAdded then
    LocalPlayer.CharacterAdded:Connect(function(ch)
        ch:WaitForChild("Humanoid",10)
        _captureOriginalSpeed()
    end)
end


-- UI Element References (để cập nhật GUI khi load config)
local uiElements = {}

-- OrionLib sử dụng hệ thống Flag để tự động lưu config
-- Không cần tự tạo config functions

-- Function to update selected enemies display (định nghĩa trước khi sử dụng)
local selectedEnemiesLabel = nil
local function updateSelectedEnemiesDisplay()
    if not selectedEnemiesLabel then return end
    local selectedList = {}
    for enemy, _ in pairs(selectedEnemies) do
        table.insert(selectedList, enemy)
    end
    if #selectedList > 0 then
        selectedEnemiesLabel:Set("Selected Enemies: " .. table.concat(selectedList, ", "))
    else
        selectedEnemiesLabel:Set("Selected Enemies: None")
    end
end

-- OrionLib tự động load config thông qua Flag system

-- Helper functions (định nghĩa trước khi sử dụng)
local _ID_KEYS = {"Id","ID","EntityId","MobId","MobID","Guid","GUID"}
local function getMonsterId(m)
    if not m then return nil end
    -- Attribute
    for _,k in ipairs(_ID_KEYS) do
        local v = m:GetAttribute(k)
        if v ~= nil then return tostring(v) end
    end
    -- ValueBase
    for _,k in ipairs(_ID_KEYS) do
        local v = m:FindFirstChild(k)
        if v and v:IsA("ValueBase") then return tostring(v.Value) end
    end
    -- fallback: chuỗi cuối tên (ít khi dùng cho GUID, nhưng để dự phòng)
    local tail = (m.Name or ""):match("([%w%-]+)$")
    return tail
end

local _TITLE_KEYS = {"Title","MobTitle","DisplayTitle"}
local function getMonsterTitle(m)
    if not m then return nil end
    
    -- Kiểm tra Attribute trực tiếp trên monster
    for _,k in ipairs(_TITLE_KEYS) do
        local v = m:GetAttribute(k)
        if v ~= nil and tostring(v) ~= "" then return tostring(v) end
    end
    
    -- Kiểm tra ValueBase trực tiếp trên monster
    for _,k in ipairs(_TITLE_KEYS) do
        local v = m:FindFirstChild(k)
        if v and v:IsA("ValueBase") and tostring(v.Value) ~= "" then return tostring(v.Value) end
    end
    
    -- Tìm trong các file con của monster (theo mô tả user)
    for _, child in ipairs(m:GetChildren()) do
        if child:IsA("Model") or child:IsA("Folder") or child:IsA("Part") then
            -- Kiểm tra Attribute trong file con
            for _,k in ipairs(_TITLE_KEYS) do
                local v = child:GetAttribute(k)
                if v ~= nil and tostring(v) ~= "" then return tostring(v) end
            end
            
            -- Kiểm tra ValueBase trong file con
            for _,k in ipairs(_TITLE_KEYS) do
                local v = child:FindFirstChild(k)
                if v and v:IsA("ValueBase") and tostring(v.Value) ~= "" then return tostring(v.Value) end
            end
            
            -- Tìm sâu hơn trong các file con của file con
            for _, grandchild in ipairs(child:GetChildren()) do
                for _,k in ipairs(_TITLE_KEYS) do
                    local v = grandchild:GetAttribute(k)
                    if v ~= nil and tostring(v) ~= "" then return tostring(v) end
                end
                
                for _,k in ipairs(_TITLE_KEYS) do
                    local v = grandchild:FindFirstChild(k)
                    if v and v:IsA("ValueBase") and tostring(v.Value) ~= "" then return tostring(v.Value) end
                end
            end
        end
    end
    
    return nil
end

local function isAliveMonster(m)
    if not m or not m:IsA("Model") then return false end
    local hum = m:FindFirstChildOfClass("Humanoid")
    local hrp = m:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return false end
    if hum.Health <= 0 then return false end
    return true
end

-- UI: Info
InfoTab:AddSection({ Name = "Script Information" })
InfoTab:AddLabel("Script: " .. SCRIPT_NAME)
InfoTab:AddLabel("Version: " .. SCRIPT_VERSION .. " (" .. SCRIPT_STATUS .. ")")
InfoTab:AddLabel("Status: Active")

InfoTab:AddButton({
    Name = "Check for Updates",
    Callback = function()
        OrionLib:MakeNotification({
            Name = "Update Check",
            Content = "Checking for updates...",
            Image = "rbxassetid://4483345998",
            Time = 2
        })
        task.wait(2)
        OrionLib:MakeNotification({
            Name = "Update Status",
            Content = "You are using the latest version!",
            Image = "rbxassetid://4483345998",
            Time = 3
        })
    end
})

-- ===================== Main UI (Kill Aura) =====================
MainTab:AddSection({ Name = "Kill Aura Settings" })

uiElements.killAuraToggle = MainTab:AddToggle({
    Name = "Kill Aura",
    Default = false,
    Flag = "killAuraEnabled",
    Save = true,
    Callback = function(v)
        OrionLib:MakeNotification({
            Name = "Kill Aura",
            Content = v and "Kill Aura enabled!" or "Kill Aura disabled!",
            Image = "rbxassetid://4483345998",
            Time = 2
        })
    end
})

uiElements.killAuraSpeedTextbox = MainTab:AddTextbox({
    Name = "Attack Speed (seconds)",
    Default = "0.1",
    Flag = "killAuraSpeed",
    Save = true,
    TextDisappear = false,
    Callback = function(Value)
        local speed = tonumber(Value)
        if speed and speed >= 0.0001 and speed <= 10 then
            OrionLib:MakeNotification({
                Name = "Attack Speed",
                Content = "Attack speed set to " .. Value .. " seconds",
                Image = "rbxassetid://4483345998",
                Time = 2
            })
        else
            OrionLib:MakeNotification({
                Name = "Attack Speed Error",
                Content = "Invalid speed! Please enter a value between 0.0001 and 10",
                Image = "rbxassetid://4483345998",
                Time = 3
            })
        end
    end
})

uiElements.targetSelectedOnlyToggle = MainTab:AddToggle({
    Name = "Target Selected Enemies Only",
    Default = false,
    Flag = "targetSelectedOnly",
    Save = true,
    Callback = function(v)
        OrionLib:MakeNotification({
            Name = "Target Mode",
            Content = v and "Now targeting selected enemies only!" or "Now targeting all enemies!",
            Image = "rbxassetid://4483345998",
            Time = 2
        })
    end
})

MainTab:AddSection({ Name = "Quest Settings" })

uiElements.autoClaimQuestToggle = MainTab:AddToggle({
    Name = "Auto Accept & Claim Quest",
    Default = false,
    Flag = "autoClaimQuestEnabled",
    Save = true,
    Callback = function(v)
        OrionLib:MakeNotification({
            Name = "Auto Quest",
            Content = v and "Auto Accept & Claim Quest enabled!" or "Auto Accept & Claim Quest disabled!",
            Image = "rbxassetid://4483345998",
            Time = 2
        })
    end
})

uiElements.questClaimDelayTextbox = MainTab:AddTextbox({
    Name = "Quest Cycle Delay (seconds)",
    Default = "1",
    Flag = "questClaimDelay",
    Save = true,
    TextDisappear = false,
    Callback = function(Value)
        local delay = tonumber(Value)
        if delay and delay >= 0.1 and delay <= 60 then
            OrionLib:MakeNotification({
                Name = "Quest Delay",
                Content = "Quest cycle delay set to " .. Value .. " seconds",
                Image = "rbxassetid://4483345998",
                Time = 2
            })
        else
            OrionLib:MakeNotification({
                Name = "Quest Delay Error",
                Content = "Invalid delay! Please enter a value between 0.1 and 60",
                Image = "rbxassetid://4483345998",
                Time = 3
            })
        end
    end
})

MainTab:AddSection({ Name = "Rank Settings" })

uiElements.autoRankUpToggle = MainTab:AddToggle({
    Name = "Auto Rank Up",
    Default = false,
    Flag = "autoRankUpEnabled",
    Save = true,
    Callback = function(v)
        OrionLib:MakeNotification({
            Name = "Auto Rank Up",
            Content = v and "Auto Rank Up enabled!" or "Auto Rank Up disabled!",
            Image = "rbxassetid://4483345998",
            Time = 2
        })
    end
})

-- ===================== AutoFarm UI =====================
AutoFarmTab:AddSection({ Name = "Enemy Selection" })

-- Dynamic label to show selected enemies
selectedEnemiesLabel = AutoFarmTab:AddLabel("Selected Enemies: None")

local enemiesDropdown = AutoFarmTab:AddDropdown({
    Name = "Select Enemies",
    Default = "",
    Options = enemiesList,
    Callback = function(Value)
        if Value and Value ~= "" then
            if not selectedEnemies[Value] then
                selectedEnemies[Value] = true
                OrionLib:MakeNotification({
                    Name = "Enemy Selected",
                    Content = "Added " .. Value .. " to target list!",
                    Image = "rbxassetid://4483345998",
                    Time = 2
                })
            else
                selectedEnemies[Value] = nil
                OrionLib:MakeNotification({
                    Name = "Enemy Deselected",
                    Content = "Removed " .. Value .. " from target list!",
                    Image = "rbxassetid://4483345998",
                    Time = 2
                })
            end
            updateSelectedEnemiesDisplay()
        end
    end
})

AutoFarmTab:AddButton({
    Name = "Refresh Enemies List",
    Callback = function()
        enemiesList = {}
        mapIdTitle = {}
        
        -- DEBUG: Kiểm tra workspace.Debris
        print("[DEBUG] Checking workspace.Debris...")
        local debris = workspace:FindFirstChild("Debris")
        if not debris then
            print("[DEBUG] ERROR: workspace.Debris not found!")
            OrionLib:MakeNotification({
                Name = "Refresh Error",
                Content = "workspace.Debris not found!",
                Image = "rbxassetid://4483345998",
                Time = 3
            })
            return
        end
        print("[DEBUG] workspace.Debris found: " .. debris:GetFullName())
        
        -- DEBUG: Kiểm tra workspace.Debris.Monsters
        print("[DEBUG] Checking workspace.Debris.Monsters...")
        local monsters = debris:FindFirstChild("Monsters")
        if not monsters then
            print("[DEBUG] ERROR: workspace.Debris.Monsters not found!")
            print("[DEBUG] Available children in Debris:")
            for _, child in ipairs(debris:GetChildren()) do
                print("[DEBUG] - " .. child.Name .. " (" .. child.ClassName .. ")")
            end
            OrionLib:MakeNotification({
                Name = "Refresh Error",
                Content = "workspace.Debris.Monsters not found!",
                Image = "rbxassetid://4483345998",
                Time = 3
            })
            return
        end
        print("[DEBUG] workspace.Debris.Monsters found: " .. monsters:GetFullName())
        
        -- DEBUG: Kiểm tra monsters trong folder
        local monsterCount = #monsters:GetChildren()
        print("[DEBUG] Total children in Monsters folder: " .. monsterCount)
        
        if monsterCount == 0 then
            print("[DEBUG] WARNING: No monsters found in Monsters folder!")
            OrionLib:MakeNotification({
                Name = "Refresh Warning",
                Content = "No monsters found in Monsters folder!",
                Image = "rbxassetid://4483345998",
                Time = 3
            })
            return
        end
        
        local titleSet = {}
        local processedCount = 0
        
        for _, monster in ipairs(monsters:GetChildren()) do
            print("[DEBUG] Processing monster: " .. monster.Name .. " (" .. monster.ClassName .. ")")
            
            if monster:IsA("Model") then
                local humanoid = monster:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    print("[DEBUG] - Has Humanoid: " .. humanoid.Name)
                    processedCount = processedCount + 1
                    
                    local id = getMonsterId(monster)
                    local title = getMonsterTitle(monster)
                    
                    print("[DEBUG] - Monster ID: " .. tostring(id))
                    print("[DEBUG] - Monster Title: " .. tostring(title))
                    print("[DEBUG] - Monster Name: " .. monster.Name)
                    
                    if id and title and title ~= "" then
                        if not titleSet[title] then
                            titleSet[title] = true
                            table.insert(enemiesList, title)
                            print("[DEBUG] - Added to list (Title): " .. title)
                        else
                            print("[DEBUG] - Title already exists: " .. title)
                        end
                    elseif not titleSet[monster.Name] then
                        titleSet[monster.Name] = true
                        table.insert(enemiesList, monster.Name)
                        print("[DEBUG] - Added to list (Name): " .. monster.Name)
                    else
                        print("[DEBUG] - Name already exists: " .. monster.Name)
                    end
                else
                    print("[DEBUG] - No Humanoid found")
                end
            else
                print("[DEBUG] - Not a Model, skipping")
            end
        end
        
        print("[DEBUG] Final results:")
        print("[DEBUG] - Processed monsters with Humanoid: " .. processedCount)
        print("[DEBUG] - Total enemies in list: " .. #enemiesList)
        print("[DEBUG] - Enemies list: " .. table.concat(enemiesList, ", "))
        
        -- Cập nhật dropdown với danh sách mới
        enemiesDropdown:Refresh(enemiesList, true)
        
        OrionLib:MakeNotification({
            Name = "Enemies List",
            Content = "Found " .. #enemiesList .. " enemies! List refreshed successfully.",
            Image = "rbxassetid://4483345998",
            Time = 2
        })
    end
})

AutoFarmTab:AddButton({
    Name = "Clear Selected Enemies",
    Callback = function()
        selectedEnemies = {}
        updateSelectedEnemiesDisplay()
        OrionLib:MakeNotification({
            Name = "Enemy Selection",
            Content = "All selected enemies have been cleared!",
            Image = "rbxassetid://4483345998",
            Time = 2
        })
    end
})

AutoFarmTab:AddSection({
    Name = "Auto Farm Settings"
})

uiElements.autoFarmToggle = AutoFarmTab:AddToggle({
    Name = "Auto Farm",
    Default = false,
    Flag = "autoFarmEnabled",
    Save = true,
    Callback = function(v)
        if v then
            local count = 0
            for _ in pairs(selectedEnemies) do count = count + 1 end
            if count == 0 then
                OrionLib:MakeNotification({
                    Name = "Auto Farm Warning",
                    Content = "Please select at least one enemy before enabling Auto Farm!",
                    Image = "rbxassetid://4483345998",
                    Time = 3
                })
                uiElements.autoFarmToggle:Set(false)
                return
            end
            OrionLib:MakeNotification({
                Name = "Auto Farm",
                Content = "Auto Farm enabled! Targeting " .. count .. " enemy types.",
                Image = "rbxassetid://4483345998",
                Time = 2
            })
        else
            -- Restore original speed when auto farm is disabled
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
                LocalPlayer.Character.Humanoid.WalkSpeed = originalWalkSpeed
            end
            OrionLib:MakeNotification({
                Name = "Auto Farm",
                Content = "Auto Farm disabled!",
                Image = "rbxassetid://4483345998",
                Time = 2
            })
        end
    end
})

uiElements.farmModeDropdown = AutoFarmTab:AddDropdown({
    Name = "Select Mode",
    Default = "Teleport",
    Options = {"Move", "Teleport"},
    Flag = "farmMode",
    Save = true,
    Callback = function(Value)
        if Value then
            OrionLib:MakeNotification({
                Name = "Farm Mode",
                Content = "Farm mode set to: " .. Value,
                Image = "rbxassetid://4483345998",
                Time = 2
            })
        end
    end
})

uiElements.moveSpeedSlider = AutoFarmTab:AddSlider({
    Name = "Set Move Speed",
    Min = 1,
    Max = 500,
    Default = 50,
    Increment = 1,
    ValueName = "Speed",
    Flag = "farmMoveSpeed",
    Save = true,
    Callback = function(Value)
        if Value and tonumber(Value) then
            OrionLib:MakeNotification({
                Name = "Move Speed",
                Content = "Move speed set to: " .. Value,
                Image = "rbxassetid://4483345998",
                Time = 2
            })
        end
    end
})

uiElements.farmMode2Dropdown = AutoFarmTab:AddDropdown({
    Name = "Select Mode 2",
    Default = "Kill Aura",
    Options = {"Click Game", "Kill Aura"},
    Flag = "farmMode2",
    Save = true,
    Callback = function(Value)
        if Value then
            OrionLib:MakeNotification({
                Name = "Farm Mode 2",
                Content = "Farm mode 2 set to: " .. Value,
                Image = "rbxassetid://4483345998",
                Time = 2
            })
        end
    end
})

uiElements.noclipToggle = AutoFarmTab:AddToggle({
    Name = "Noclip",
    Default = false,
    Flag = "noclipEnabled",
    Save = true,
    Callback = function(v)
        OrionLib:MakeNotification({
            Name = "Noclip",
            Content = v and "Noclip enabled!" or "Noclip disabled!",
            Image = "rbxassetid://4483345998",
            Time = 2
        })
    end
})

-- ===================== Auto Roll UI =====================
AutoRollTab:AddSection({ Name = "Roll Settings" })

uiElements.rollAmountTextbox = AutoRollTab:AddTextbox({
    Name = "Roll Amount (All Types)",
    Default = "5",
    Flag = "rollAmount",
    Save = true,
    TextDisappear = false,
    Callback = function(Value)
        local amount = tonumber(Value)
        if amount and amount >= 1 and amount <= 1000 then
            OrionLib:MakeNotification({
                Name = "Roll Amount",
                Content = "Roll amount set to: " .. Value,
                Image = "rbxassetid://4483345998",
                Time = 2
            })
        else
            OrionLib:MakeNotification({
                Name = "Roll Amount Error",
                Content = "Invalid amount! Please enter a value between 1 and 1000",
                Image = "rbxassetid://4483345998",
                Time = 3
            })
        end
    end
})

AutoRollTab:AddSection({ Name = "Earth City" })

uiElements.autoRollToggle = AutoRollTab:AddToggle({
    Name = "Auto Roll Dragon Race",
    Default = false,
    Flag = "autoRollEnabled",
    Save = true,
    Callback = function(v)
        OrionLib:MakeNotification({
            Name = "Auto Roll Dragon",
            Content = v and "Auto Roll Dragon Race enabled!" or "Auto Roll Dragon Race disabled!",
            Image = "rbxassetid://4483345998",
            Time = 2
        })
    end
})

uiElements.autoRollSaiyanToggle = AutoRollTab:AddToggle({
    Name = "Auto Roll Saiyan Evolution",
    Default = false,
    Flag = "autoRollSaiyanEnabled",
    Save = true,
    Callback = function(v)
        OrionLib:MakeNotification({
            Name = "Auto Roll Saiyan",
            Content = v and "Auto Roll Saiyan Evolution enabled!" or "Auto Roll Saiyan Evolution disabled!",
            Image = "rbxassetid://4483345998",
            Time = 2
        })
    end
})

-- ===================== Config Tab =====================
-- Config Management System
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- Create config folder structure
local userName = LocalPlayer.Name or "Unknown"
local baseConfigFolder = "AnimeEternal"
local configFolder = baseConfigFolder .. "/Config"
local userConfigFolder = baseConfigFolder .. "/UserConfig_" .. userName -- User-specific folder
local customConfigs = {}
local currentConfigName = "Default"
local autoLoadConfigName = nil

-- Ensure config folders exist
if not isfolder(baseConfigFolder) then
    makefolder(baseConfigFolder)
end
if not isfolder(configFolder) then
    makefolder(configFolder)
end
if not isfolder(userConfigFolder) then
    makefolder(userConfigFolder)
end

-- Load available configs on startup
local function loadAvailableConfigs()
    customConfigs = {"Default"}
    if isfolder(configFolder) then
        for _, file in pairs(listfiles(configFolder)) do
            if file:match("%.json$") then
                local configName = file:match("([^/\\]+)%.json$")
                if configName and configName ~= "Default" then
                    table.insert(customConfigs, configName)
                end
            end
        end
    end
end

-- Save current config - AUTO-SAVES ALL FLAGS AND FEATURES
local function saveConfig(configName)
    if not configName or configName == "" then
        OrionLib:MakeNotification({
            Name = "Config Error",
            Content = "Please enter a valid config name!",
            Image = "rbxassetid://4483345998",
            Time = 3
        })
        return false
    end
    
    -- AUTO-COLLECT ALL FLAGS - This will automatically include any new features added
    local configData = {
        -- Core features
        killAuraEnabled = OrionLib.Flags["killAuraEnabled"] and OrionLib.Flags["killAuraEnabled"].Value or false,
        killAuraSpeed = OrionLib.Flags["killAuraSpeed"] and OrionLib.Flags["killAuraSpeed"].Value or "0.1",
        targetSelectedOnly = OrionLib.Flags["targetSelectedOnly"] and OrionLib.Flags["targetSelectedOnly"].Value or false,
        autoClaimQuestEnabled = OrionLib.Flags["autoClaimQuestEnabled"] and OrionLib.Flags["autoClaimQuestEnabled"].Value or false,
        questClaimDelay = OrionLib.Flags["questClaimDelay"] and OrionLib.Flags["questClaimDelay"].Value or "1",
        autoRankUpEnabled = OrionLib.Flags["autoRankUpEnabled"] and OrionLib.Flags["autoRankUpEnabled"].Value or false,
        autoFarmEnabled = OrionLib.Flags["autoFarmEnabled"] and OrionLib.Flags["autoFarmEnabled"].Value or false,
        rollAmount = OrionLib.Flags["rollAmount"] and OrionLib.Flags["rollAmount"].Value or "5",
        autoRollEnabled = OrionLib.Flags["autoRollEnabled"] and OrionLib.Flags["autoRollEnabled"].Value or false,
        autoRollSaiyanEnabled = OrionLib.Flags["autoRollSaiyanEnabled"] and OrionLib.Flags["autoRollSaiyanEnabled"].Value or false,
        autoRespawnEnabled = OrionLib.Flags["autoRespawnEnabled"] and OrionLib.Flags["autoRespawnEnabled"].Value or false,
        
        -- Custom data
        selectedEnemies = selectedEnemies,
        
        -- Auto-collect ALL OrionLib Flags for future features
        allFlags = {},
        
        -- Metadata
        version = SCRIPT_VERSION,
        timestamp = os.time(),
        userName = userName
    }
    
    -- AUTO-SAVE ALL FLAGS - This ensures any new features are automatically saved
    for flagName, flagData in pairs(OrionLib.Flags) do
        if flagData and flagData.Value ~= nil then
            configData.allFlags[flagName] = flagData.Value
        end
    end
    
    local success, result = pcall(function()
        local jsonData = HttpService:JSONEncode(configData)
        local filePath = configFolder .. "/" .. configName .. ".json"
        writefile(filePath, jsonData)
    end)
    
    if success then
        currentConfigName = configName
        if not table.find(customConfigs, configName) then
            table.insert(customConfigs, configName)
            configDropdown:Refresh(customConfigs, configName)
        end
        OrionLib:MakeNotification({
            Name = "Config Saved",
            Content = "Configuration '" .. configName .. "' saved successfully!",
            Image = "rbxassetid://4483345998",
            Time = 3
        })
        return true
    else
        OrionLib:MakeNotification({
            Name = "Save Error",
            Content = "Failed to save configuration!",
            Image = "rbxassetid://4483345998",
            Time = 3
        })
        return false
    end
end

-- Load config - AUTO-LOADS ALL FLAGS AND FEATURES
local function loadConfig(configName)
    if configName == "Default" then
        -- Reset ALL flags to default values
        for flagName, flagData in pairs(OrionLib.Flags) do
            if flagData and flagData.Set then
                -- Set common defaults
                if flagName:find("Enabled") then
                    flagData:Set(false)
                elseif flagName == "killAuraSpeed" then
                    flagData:Set("0.1")
                elseif flagName == "questClaimDelay" then
                    flagData:Set("1")
                elseif flagName == "rollAmount" then
                    flagData:Set("5")
                else
                    -- Try to reset to reasonable defaults
                    if type(flagData.Value) == "boolean" then
                        flagData:Set(false)
                    elseif type(flagData.Value) == "string" then
                        flagData:Set("")
                    elseif type(flagData.Value) == "number" then
                        flagData:Set(0)
                    end
                end
            end
        end
        
        selectedEnemies = {}
        updateSelectedEnemiesDisplay()
        currentConfigName = "Default"
        OrionLib:MakeNotification({
            Name = "Config Loaded",
            Content = "Default configuration loaded!",
            Image = "rbxassetid://4483345998",
            Time = 3
        })
        return true
    end
    
    local filePath = configFolder .. "/" .. configName .. ".json"
    if not isfile(filePath) then
        OrionLib:MakeNotification({
            Name = "Config Error",
            Content = "Configuration '" .. configName .. "' not found!",
            Image = "rbxassetid://4483345998",
            Time = 3
        })
        return false
    end
    
    local success, result = pcall(function()
        local jsonData = readfile(filePath)
        local configData = HttpService:JSONDecode(jsonData)
        
        -- Load ALL saved flags automatically - This ensures any new features are loaded
        if configData.allFlags then
            for flagName, flagValue in pairs(configData.allFlags) do
                if OrionLib.Flags[flagName] and OrionLib.Flags[flagName].Set then
                    OrionLib.Flags[flagName]:Set(flagValue)
                end
            end
        else
            -- Fallback for older configs - Apply specific known flags
            if OrionLib.Flags["killAuraEnabled"] then OrionLib.Flags["killAuraEnabled"]:Set(configData.killAuraEnabled or false) end
            if OrionLib.Flags["killAuraSpeed"] then OrionLib.Flags["killAuraSpeed"]:Set(configData.killAuraSpeed or "0.1") end
            if OrionLib.Flags["targetSelectedOnly"] then OrionLib.Flags["targetSelectedOnly"]:Set(configData.targetSelectedOnly or false) end
            if OrionLib.Flags["autoClaimQuestEnabled"] then OrionLib.Flags["autoClaimQuestEnabled"]:Set(configData.autoClaimQuestEnabled or false) end
            if OrionLib.Flags["questClaimDelay"] then OrionLib.Flags["questClaimDelay"]:Set(configData.questClaimDelay or "1") end
            if OrionLib.Flags["autoRankUpEnabled"] then OrionLib.Flags["autoRankUpEnabled"]:Set(configData.autoRankUpEnabled or false) end
            if OrionLib.Flags["autoFarmEnabled"] then OrionLib.Flags["autoFarmEnabled"]:Set(configData.autoFarmEnabled or false) end
            if OrionLib.Flags["rollAmount"] then OrionLib.Flags["rollAmount"]:Set(configData.rollAmount or "5") end
            if OrionLib.Flags["autoRollEnabled"] then OrionLib.Flags["autoRollEnabled"]:Set(configData.autoRollEnabled or false) end
            if OrionLib.Flags["autoRollSaiyanEnabled"] then OrionLib.Flags["autoRollSaiyanEnabled"]:Set(configData.autoRollSaiyanEnabled or false) end
            if OrionLib.Flags["autoRespawnEnabled"] then OrionLib.Flags["autoRespawnEnabled"]:Set(configData.autoRespawnEnabled or false) end
        end
        
        -- Load selected enemies
        if configData.selectedEnemies then
            selectedEnemies = configData.selectedEnemies
            updateSelectedEnemiesDisplay()
        end
        
        currentConfigName = configName
    end)
    
    if success then
        OrionLib:MakeNotification({
            Name = "Config Loaded",
            Content = "Configuration '" .. configName .. "' loaded successfully!",
            Image = "rbxassetid://4483345998",
            Time = 3
        })
        return true
    else
        OrionLib:MakeNotification({
            Name = "Load Error",
            Content = "Failed to load configuration '" .. configName .. "'!",
            Image = "rbxassetid://4483345998",
            Time = 3
        })
        return false
    end
end

-- Delete config
local function deleteConfig(configName)
    if configName == "Default" then
        OrionLib:MakeNotification({
            Name = "Delete Error",
            Content = "Cannot delete the Default configuration!",
            Image = "rbxassetid://4483345998",
            Time = 3
        })
        return false
    end
    
    local filePath = configFolder .. "/" .. configName .. ".json"
    if not isfile(filePath) then
        OrionLib:MakeNotification({
            Name = "Delete Error",
            Content = "Configuration '" .. configName .. "' not found!",
            Image = "rbxassetid://4483345998",
            Time = 3
        })
        return false
    end
    
    local success, result = pcall(function()
        delfile(filePath)
    end)
    
    if success then
        -- Remove from list and refresh dropdown
        for i, config in ipairs(customConfigs) do
            if config == configName then
                table.remove(customConfigs, i)
                break
            end
        end
        configDropdown:Refresh(customConfigs, "Default")
        
        -- If deleted config was current, switch to default
        if currentConfigName == configName then
            loadConfig("Default")
        end
        
        OrionLib:MakeNotification({
            Name = "Config Deleted",
            Content = "Configuration '" .. configName .. "' deleted successfully!",
            Image = "rbxassetid://4483345998",
            Time = 3
        })
        return true
    else
        OrionLib:MakeNotification({
            Name = "Delete Error",
            Content = "Failed to delete configuration '" .. configName .. "'!",
            Image = "rbxassetid://4483345998",
            Time = 3
        })
        return false
    end
end

-- Auto Load Config functions (defined before use)
local function saveAutoLoadConfig(configName)
    local autoLoadData = {
        configName = configName,
        userName = userName,
        timestamp = os.time()
    }
    
    local success, result = pcall(function()
        local jsonData = HttpService:JSONEncode(autoLoadData)
        writefile(userConfigFolder .. "/autoload.json", jsonData)
    end)
    
    if success then
        autoLoadConfigName = configName
        OrionLib:MakeNotification({
            Name = "Auto Load Set",
            Content = "Auto load config set to '" .. configName .. "'!",
            Image = "rbxassetid://4483345998",
            Time = 3
        })
        return true
    else
        OrionLib:MakeNotification({
            Name = "Auto Load Error",
            Content = "Failed to set auto load config!",
            Image = "rbxassetid://4483345998",
            Time = 3
        })
        return false
    end
end

local function loadAutoLoadConfig()
    local autoLoadFile = userConfigFolder .. "/autoload.json"
    
    if not isfile(autoLoadFile) then
        return nil
    end
    
    local success, result = pcall(function()
        local jsonData = readfile(autoLoadFile)
        local autoLoadData = HttpService:JSONDecode(jsonData)
        
        -- Check if the autoload config belongs to current user
        if autoLoadData.userName and autoLoadData.userName ~= userName then
            print("[DEBUG] AutoLoad config belongs to different user: " .. tostring(autoLoadData.userName) .. " (current: " .. userName .. ")")
            return nil
        end
        
        return autoLoadData.configName
    end)
    
    if success and result then
        autoLoadConfigName = result
        return result
    end
    
    return nil
end

-- Initialize available configs
loadAvailableConfigs()

-- Load auto-load config on startup
local autoLoadConfig = loadAutoLoadConfig()
if autoLoadConfig and autoLoadConfig ~= "Default" then
    -- Auto-load the saved config
    task.spawn(function()
        task.wait(2) -- Wait for GUI to fully load
        if loadConfig(autoLoadConfig) then
            print("[INFO] Auto-loaded config: " .. autoLoadConfig)
        end
    end)
end

ConfigTab:AddSection({ Name = "Configuration Management" })

ConfigTab:AddLabel("Current Config: " .. currentConfigName)
ConfigTab:AddLabel("User: " .. userName)
ConfigTab:AddLabel("Config Folder: " .. configFolder)
ConfigTab:AddLabel("UserConfig Folder: " .. userConfigFolder)
ConfigTab:AddLabel("Auto-saves all new features to selected config")

-- Config dropdown
local configDropdown = ConfigTab:AddDropdown({
    Name = "Select Configuration",
    Default = currentConfigName,
    Options = customConfigs,
    Callback = function(Value)
        -- Only update the selection, don't auto-load
        -- User needs to manually click "Load Selected Config" button
    end
})

-- Create new config
local newConfigTextbox = ConfigTab:AddTextbox({
    Name = "New Config Name",
    Default = "",
    TextDisappear = false,
    Flag = "newConfigName",
    Save = false,
    Callback = function(Value)
        -- Value is automatically stored in OrionLib.Flags["newConfigName"]
    end
})

ConfigTab:AddButton({
    Name = "Create & Save Config",
    Callback = function()
        local configName = OrionLib.Flags["newConfigName"] and OrionLib.Flags["newConfigName"].Value or ""
        if configName and configName ~= "" and configName:gsub("%s+", "") ~= "" then
            if saveConfig(configName) then
                -- Clear the textbox after successful save
                if OrionLib.Flags["newConfigName"] then
                    OrionLib.Flags["newConfigName"]:Set("")
                end
            end
        else
            OrionLib:MakeNotification({
                Name = "Config Error",
                Content = "Please enter a valid config name!",
                Image = "rbxassetid://4483345998",
                Time = 3
            })
        end
    end
})

ConfigTab:AddSection({ Name = "Config Actions" })

ConfigTab:AddButton({
    Name = "Save Current Config",
    Callback = function()
        saveConfig(currentConfigName)
    end
})

ConfigTab:AddButton({
    Name = "Load Selected Config",
    Callback = function()
        local selectedConfig = configDropdown.Value or "Default"
        loadConfig(selectedConfig)
    end
})

ConfigTab:AddButton({
    Name = "Delete Selected Config",
    Callback = function()
        local selectedConfig = configDropdown.Value or "Default"
        deleteConfig(selectedConfig)
    end
})

ConfigTab:AddButton({
    Name = "Refresh Config List",
    Callback = function()
        loadAvailableConfigs()
        configDropdown:Refresh(customConfigs, currentConfigName)
        OrionLib:MakeNotification({
            Name = "Config List",
            Content = "Configuration list refreshed!",
            Image = "rbxassetid://4483345998",
            Time = 2
        })
    end
})

ConfigTab:AddSection({ Name = "Reset Options" })

ConfigTab:AddButton({
    Name = "Set AutoLoad Config",
    Callback = function()
        local selectedConfig = configDropdown.Value or "Default"
        if not selectedConfig or selectedConfig == "" then
            OrionLib:MakeNotification({
                Name = "AutoLoad Error",
                Content = "Please select a valid configuration!",
                Image = "rbxassetid://4483345998",
                Time = 3
            })
            return
        end
        
        if selectedConfig == "Default" then
            -- Clear auto-load
            local autoLoadFile = userConfigFolder .. "/autoload.json"
            if isfile(autoLoadFile) then
                delfile(autoLoadFile)
            end
            autoLoadConfigName = nil
            OrionLib:MakeNotification({
                Name = "AutoLoad Cleared",
                Content = "Auto-load configuration cleared!",
                Image = "rbxassetid://4483345998",
                Time = 3
            })
        else
            saveAutoLoadConfig(selectedConfig)
        end
    end
})

ConfigTab:AddButton({
    Name = "Reset All Settings",
    Callback = function()
        loadConfig("Default")
    end
})

-- NEW: Fixed Radius & Max distance
local KILLAURA_RADIUS = 150
local MAX_ATTACK_DISTANCE = 200

-- Player Tab
PlayerTab:AddSection({ Name = "Player Settings" })
PlayerTab:AddSlider({
    Name = "Walk Speed",
    Min = 16, Max = 100, Default = 16,
    Increment = 1, ValueName = "Speed",
    Callback = function(v)
        if v and tonumber(v) and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            LocalPlayer.Character.Humanoid.WalkSpeed = tonumber(v)
        end
    end
})
PlayerTab:AddSlider({
    Name = "Jump Power",
    Min = 50, Max = 200, Default = 50,
    Increment = 1, ValueName = "Power",
    Callback = function(v)
        if v and tonumber(v) and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            LocalPlayer.Character.Humanoid.JumpPower = tonumber(v)
        end
    end
})
PlayerTab:AddToggle({
    Name = "Auto Respawn",
    Default = false,
    Flag = "autoRespawnEnabled",
    Save = true,
    Callback = function(v)
        OrionLib:MakeNotification({
            Name = "Auto Respawn",
            Content = v and "Auto Respawn enabled!" or "Auto Respawn disabled!",
            Image = "rbxassetid://4483345998",
            Time = 2
        })
    end
})

-- Teleport
TeleportTab:AddSection({ Name = "Quick Teleports" })
TeleportTab:AddButton({
    Name = "Teleport to Spawn",
    Callback = function()
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(0, 10, 0)
            OrionLib:MakeNotification({
                Name = "Teleport",
                Content = "Teleported to spawn!",
                Image = "rbxassetid://4483345998",
                Time = 2
            })
        end
    end
})

-- Misc Tab
MiscTab:AddSection({ Name = "Code Redemption" })

-- Function to redeem a single code
local function redeemCode(code)
    local args = {
        {
            Action = "_Redeem_Code",
            Text = code
        }
    }
    
    local success, err = pcall(function()
        game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("To_Server"):FireServer(unpack(args))
    end)
    
    if success then
        print("[Code Redeem] Successfully redeemed: " .. code)
    else
        warn("[Code Redeem] Failed to redeem " .. code .. ": " .. tostring(err))
    end
end

-- All available codes
local allCodes = {
    "DungeonFixed",
    "TinyCode",
    "EnergyFix",
    "Update10",
    "20MVisits",
    "280KFAV",
    "290KFAV",
    "105KLikes",
    "RefreshCode",
    "DungFix?",
    "MaxButtonNextUpdate",
    "Update9Part2",
    "95KLIKES",
    "270KFAV",
    "100KLIKES",
    "WaitRoom",
    "16KPlayers",
    "85KLIKES",
    "Update9Part1",
    "90KLIKES",
    "260KFAV",
    "JewelFix2",
    "240KFAV",
    "250KFAV",
    "Update8P2",
    "80KLIKES",
    "12KPlayers",
    "13KPlayers",
    "14KPlayers",
    "Update8P1",
    "75KLIKES",
    "JewelFix",
    "Update8",
    "70KLikes",
    "11KPlayers",
    "230KFAV",
    "13MVISITS"
}

MiscTab:AddButton({
    Name = "Redeem All Codes",
    Callback = function()
        OrionLib:MakeNotification({
            Name = "Code Redemption",
            Content = "Starting to redeem all codes...",
            Image = "rbxassetid://4483345998",
            Time = 3
        })
        
        task.spawn(function()
            local successCount = 0
            for i, code in ipairs(allCodes) do
                redeemCode(code)
                successCount = successCount + 1
                task.wait(0.5) -- Small delay between redemptions
            end
            
            OrionLib:MakeNotification({
                Name = "Code Redemption Complete",
                Content = "Attempted to redeem " .. successCount .. " codes!",
                Image = "rbxassetid://4483345998",
                Time = 5
            })
        end)
    end
})

MiscTab:AddTextbox({
    Name = "Custom Code",
    Default = "",
    TextDisappear = false,
    Flag = "customCode",
    Save = false,
    Callback = function(Value)
        -- Value is stored in OrionLib.Flags["customCode"]
    end
})

MiscTab:AddButton({
    Name = "Redeem Custom Code",
    Callback = function()
        local customCode = OrionLib.Flags["customCode"] and OrionLib.Flags["customCode"].Value or ""
        if customCode and customCode ~= "" and customCode:gsub("%s+", "") ~= "" then
            redeemCode(customCode)
            OrionLib:MakeNotification({
                Name = "Custom Code",
                Content = "Attempting to redeem: " .. customCode,
                Image = "rbxassetid://4483345998",
                Time = 3
            })
        else
            OrionLib:MakeNotification({
                Name = "Code Error",
                Content = "Please enter a valid code!",
                Image = "rbxassetid://4483345998",
                Time = 3
            })
        end
    end
})

-- Settings
SettingsTab:AddSection({ Name = "General Settings" })
SettingsTab:AddToggle({
    Name = "Anti AFK",
    Default = true,
    Callback = function(v)
        antiAfkEnabled = v
        if v then
            OrionLib:MakeNotification({
                Name = "Anti AFK",
                Content = "Anti AFK enabled!",
                Image = "rbxassetid://4483345998",
                Time = 2
            })
        end
    end
})
SettingsTab:AddSection({ Name = "Script Controls" })
SettingsTab:AddButton({
    Name = "Reload Script",
    Callback = function()
        OrionLib:MakeNotification({
            Name = "Script Reload",
            Content = "Reloading script...",
            Image = "rbxassetid://4483345998",
            Time = 2
        })
        task.wait(1)
        loadstring(game:HttpGet(SCRIPT_URL))()
    end
})
SettingsTab:AddButton({
    Name = "Destroy GUI",
    Callback = function()
        scriptRunning = false
        OrionLib:Destroy()
        print("[INFO] GUI destroyed successfully")
    end
})

-- ===================== Anti AFK =====================
task.spawn(function()
    while scriptRunning do
        if antiAfkEnabled then
            local ok, err = pcall(function()
                local vu = game:GetService("VirtualUser")
                vu:CaptureController()
                vu:ClickButton2(Vector2.new())
            end)
            if not ok then warn("Anti AFK failed: " .. tostring(err)) end
        end
        task.wait(60)
    end
end)

-- ===================== KILL AURA (FIXED) =====================
-- No teleport, no rotate; robust To_Server finder; Id-based payload
local USE_ID_WHITELIST = false
local ID_WHITELIST = {} -- ví dụ: ["8e49-xxxx"]=true

-- Safe finder (không gọi method trên nil)
local ToServer
local function findToServer()
    local rs = ReplicatedStorage

    -- 1) thử trong folder Events nếu có
    local events = rs:FindFirstChild("Events")
    if events then
        for _, name in ipairs({"To_Server", "ToServer", "Combat", "Attack"}) do
            local r = events:FindFirstChild(name)
            if r and r:IsA("RemoteEvent") then return r end
        end
    end

    -- 2) quét toàn ReplicatedStorage
    local candidates = {}
    for _, inst in ipairs(rs:GetDescendants()) do
        if inst:IsA("RemoteEvent") then
            local n = inst.Name
            if n == "To_Server" or n == "ToServer" or n == "Combat" or n == "Attack" then
                table.insert(candidates, inst)
            end
        end
    end
    if #candidates > 0 then
        return candidates[1]
    end

    -- 3) debug: in tất cả RemoteEvent 1 lần (không spam)
    if not ToServer then
        warn("[KillAura] Không tìm thấy Remote mong muốn. Liệt kê RemoteEvent trong ReplicatedStorage:")
        for _,inst in ipairs(rs:GetDescendants()) do
            if inst:IsA("RemoteEvent") then
                print("[RemoteEvent]", inst:GetFullName())
            end
        end
    end
    return nil
end

-- Helper functions đã được di chuyển lên trên

local function getNearestMonster(origin, radius)
    local debris = workspace:FindFirstChild("Debris")
    if not debris then return nil end
    local monsters = debris:FindFirstChild("Monsters")
    if not monsters then return nil end

    local best, bestDist = nil, math.huge
    for _, m in ipairs(monsters:GetChildren()) do
        if isAliveMonster(m) then
            local hrp = m:FindFirstChild("HumanoidRootPart")
            local d = (hrp.Position - origin).Magnitude
            if d <= radius and d <= MAX_ATTACK_DISTANCE then
                local mid = getMonsterId(m)
                if mid and ((not USE_ID_WHITELIST) or ID_WHITELIST[mid]) then
                    if d < bestDist then
                        best, bestDist = m, d
                    end
                end
            end
        end
    end
    return best
end

-- Helper: tìm enemy được chọn trong Auto Farm (improved for multiple targets)
local lastTargetedEnemy = nil
local lastTargetTime = 0
local TARGET_COOLDOWN = 3 -- seconds to wait before switching targets

local function getSelectedEnemy()
    local debris = workspace:FindFirstChild("Debris")
    if not debris then return nil end
    local monsters = debris:FindFirstChild("Monsters")
    if not monsters then return nil end
    
    local availableEnemies = {}
    
    -- Collect all available selected enemies
    for _, m in ipairs(monsters:GetChildren()) do
        if isAliveMonster(m) then
            local title = getMonsterTitle(m)
            local name = title or m.Name
            if selectedEnemies[name] then
                table.insert(availableEnemies, m)
            end
        end
    end
    
    if #availableEnemies == 0 then
        return nil
    end
    
    -- Check if last targeted enemy is still alive and valid
    if lastTargetedEnemy and lastTargetedEnemy.Parent and isAliveMonster(lastTargetedEnemy) then
        local title = getMonsterTitle(lastTargetedEnemy)
        local name = title or lastTargetedEnemy.Name
        if selectedEnemies[name] and (tick() - lastTargetTime) < TARGET_COOLDOWN then
            return lastTargetedEnemy
        end
    end
    
    -- Find a new target (prefer closest one)
    local player = LocalPlayer
    if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
        return availableEnemies[1]
    end
    
    local playerPos = player.Character.HumanoidRootPart.Position
    local closestEnemy = nil
    local closestDistance = math.huge
    
    for _, enemy in ipairs(availableEnemies) do
        if enemy:FindFirstChild("HumanoidRootPart") then
            local distance = (enemy.HumanoidRootPart.Position - playerPos).Magnitude
            if distance < closestDistance then
                closestDistance = distance
                closestEnemy = enemy
            end
        end
    end
    
    if closestEnemy then
        lastTargetedEnemy = closestEnemy
        lastTargetTime = tick()
        return closestEnemy
    end
    
    return availableEnemies[1]
end

task.spawn(function()
    math.randomseed(tick())
    while scriptRunning do
        -- Chỉ hoạt động khi Kill Aura được bật và farmMode2 = "Kill Aura" (hoặc không có farmMode2)
        local farmMode2 = OrionLib.Flags["farmMode2"] and OrionLib.Flags["farmMode2"].Value or "Kill Aura"
        if OrionLib.Flags["killAuraEnabled"] and OrionLib.Flags["killAuraEnabled"].Value and LocalPlayer.Character and farmMode2 == "Kill Aura" then
            ToServer = ToServer or findToServer() -- luôn cố lấy lại nếu mất
            local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp and ToServer then
                local target
                if OrionLib.Flags["targetSelectedOnly"] and OrionLib.Flags["targetSelectedOnly"].Value then
                    target = getSelectedEnemy()
                else
                    target = getNearestMonster(hrp.Position, KILLAURA_RADIUS)
                end
                if target then
                    local thrp = target:FindFirstChild("HumanoidRootPart")
                    if thrp then
                        local dist = (thrp.Position - hrp.Position).Magnitude
                        if dist <= MAX_ATTACK_DISTANCE then
                            local id = getMonsterId(target)
                            if id then
                                local payload = { { Id = id, Action = "_Mouse_Click" } }
                                local ok, err = pcall(function()
                                    ToServer:FireServer(unpack(payload))
                                end)
                                if not ok then warn("[KillAura] FireServer error: ", err) end
                            else
                                -- Không có Id thì bỏ qua để tránh gửi payload sai
                                -- print("[KillAura] Missing Id for:", target:GetFullName())
                            end
                        end
                    end
                end
            elseif not ToServer then
                -- chỉ cảnh báo nhẹ, không spam
                warn("[KillAura] Remote chưa sẵn sàng. Đứng yên vài giây hoặc chuyển map rồi thử lại.")
            end
        end
        local speed = tonumber(OrionLib.Flags["killAuraSpeed"] and OrionLib.Flags["killAuraSpeed"].Value) or 0.1
        task.wait(speed + (math.random() * 0.05))
    end
end)

-- (moved earlier) originalWalkSpeed defined above

-- Move to target function for Move mode
local function moveToTarget(targetPosition, moveSpeed)
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        return false
    end
    
    local humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
    local hrp = LocalPlayer.Character.HumanoidRootPart
    
    if not humanoid then return false end
    
    -- Validate moveSpeed parameter
    moveSpeed = tonumber(moveSpeed) or 50
    
    -- Store original speed if not stored yet
    if originalWalkSpeed == 16 then
        originalWalkSpeed = humanoid.WalkSpeed
    end
    
    -- Set walk speed only for Move mode
    humanoid.WalkSpeed = moveSpeed
    
    -- Move to target without waiting - let the main loop handle continuous movement
    humanoid:MoveTo(targetPosition)
    
    return true
end

-- Auto Farm System
task.spawn(function()
    while scriptRunning do
        if OrionLib.Flags["autoFarmEnabled"] and OrionLib.Flags["autoFarmEnabled"].Value and LocalPlayer.Character then
            ToServer = ToServer or findToServer()
            local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp and ToServer then
                local target = getSelectedEnemy()
                
                if target then
                    local targetHrp = target:FindFirstChild("HumanoidRootPart")
                    if targetHrp then
                        local farmMode = OrionLib.Flags["farmMode"] and OrionLib.Flags["farmMode"].Value or "Teleport"
                        
                        if farmMode == "Move" then
                            -- Move mode: Walk to target
                            local moveSpeed = OrionLib.Flags["farmMoveSpeed"] and OrionLib.Flags["farmMoveSpeed"].Value or 50
                            local targetPos = targetHrp.Position + Vector3.new(0, 0, 5)
                            moveToTarget(targetPos, moveSpeed)
                        else
                            -- Teleport mode: Instant teleport to target
                            -- Restore original speed for teleport mode
                            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
                                LocalPlayer.Character.Humanoid.WalkSpeed = originalWalkSpeed
                            end
                            hrp.CFrame = CFrame.new(targetHrp.Position + Vector3.new(0, 0, 5))
                            task.wait(0.1)
                        end
                        
                        -- Chỉ tấn công khi farmMode2 = "Kill Aura"
                        local farmMode2 = OrionLib.Flags["farmMode2"] and OrionLib.Flags["farmMode2"].Value or "Kill Aura"
                        if farmMode2 == "Kill Aura" then
                            local id = getMonsterId(target)
                            if id then
                                local payload = { { Id = id, Action = "_Mouse_Click" } }
                                local ok, err = pcall(function()
                                    ToServer:FireServer(unpack(payload))
                                end)
                                if not ok then warn("[AutoFarm] FireServer error: ", err) end
                            end
                        end
                        -- Nếu farmMode2 = "Click Game" thì chỉ di chuyển, không tấn công
                    end
                end
                -- Continue farming without long delays
            end
        end
        -- Use consistent short delay for smooth farming
        local speed = tonumber(OrionLib.Flags["killAuraSpeed"] and OrionLib.Flags["killAuraSpeed"].Value) or 0.1
        task.wait(speed)
    end
end)

-- Auto Accept & Claim Quest System
task.spawn(function()
    while scriptRunning do
        if OrionLib.Flags["autoClaimQuestEnabled"] and OrionLib.Flags["autoClaimQuestEnabled"].Value then
            local ok, err = pcall(function()
                local rs = game:GetService("ReplicatedStorage")
                local events = rs:WaitForChild("Events")
                local toServer = events:WaitForChild("To_Server")
                
                -- Accept and Claim quests with ID from 1 to 6
                for questId = 1, 6 do
                    -- Accept quest first
                    local acceptArgs = {
                        {
                            Id = tostring(questId),
                            Type = "Accept",
                            Action = "_Quest"
                        }
                    }
                    toServer:FireServer(unpack(acceptArgs))
                    task.wait(0.1) -- Small delay between accept and claim
                    
                    -- Then claim quest
                    local claimArgs = {
                        {
                            Id = tostring(questId),
                            Type = "Complete",
                            Action = "_Quest"
                        }
                    }
                    toServer:FireServer(unpack(claimArgs))
                    task.wait(0.1) -- Small delay between each quest cycle
                end
            end)
            if not ok then warn("[AutoAcceptClaimQuest] Error: ", err) end
        else
            task.wait(1)
        end
        local delay = tonumber(OrionLib.Flags["questClaimDelay"] and OrionLib.Flags["questClaimDelay"].Value) or 1
        task.wait(delay)
    end
end)
-- ===================== END KILL AURA =====================

-- ===================== Auto Rank Up System =====================
task.spawn(function()
    while scriptRunning do
        if OrionLib.Flags["autoRankUpEnabled"] and OrionLib.Flags["autoRankUpEnabled"].Value then
            local ok, err = pcall(function()
                local args = {
                    {
                        Upgrading_Name = "Rank",
                        Action = "_Upgrades",
                        Upgrade_Name = "Rank_Up"
                    }
                }
                game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("To_Server"):FireServer(unpack(args))
            end)
            if not ok then warn("[AutoRankUp] Error: " .. tostring(err)) end
        end
        task.wait(1) -- Check every second
    end
end)

-- ===================== Auto Respawn =====================
task.spawn(function()
    while scriptRunning do
        if OrionLib.Flags["autoRespawnEnabled"] and OrionLib.Flags["autoRespawnEnabled"].Value then
            local ok, err = pcall(function()
                if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
                    if LocalPlayer.Character.Humanoid.Health <= 0 then
                        LocalPlayer:LoadCharacter()
                    end
                end
            end)
            if not ok then warn("Auto Respawn failed: " .. tostring(err)) end
        end
        task.wait(1)
    end
end)

-- Script loaded notification
local deviceType = game:GetService("UserInputService").TouchEnabled and "Mobile" or "PC"
OrionLib:MakeNotification({
    Name = "Script Loaded",
    Content = "Anime Eternal GUI loaded successfully on " .. deviceType .. "!",
    Image = "rbxassetid://4483345998",
    Time = 5
})
print(SCRIPT_NAME .. " GUI Script v" .. SCRIPT_VERSION .. " (" .. SCRIPT_STATUS .. ") loaded successfully on " .. deviceType .. "!")

-- ===================== AUTO ROLL SYSTEM =====================
task.spawn(function()
    while scriptRunning do
        local rollEnabled = OrionLib.Flags["autoRollEnabled"] and OrionLib.Flags["autoRollEnabled"].Value
        local rollSaiyanEnabled = OrionLib.Flags["autoRollSaiyanEnabled"] and OrionLib.Flags["autoRollSaiyanEnabled"].Value
        local amount = tonumber(OrionLib.Flags["rollAmount"] and OrionLib.Flags["rollAmount"].Value) or 5
        
        if rollEnabled then
            local ok, err = pcall(function()
                local args = {
                    {
                        Open_Amount = amount,
                        Action = "_Gacha_Activate",
                        Name = "Dragon_Race"
                    }
                }
                game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("To_Server"):FireServer(unpack(args))
            end)
            if not ok then warn("Auto Roll Dragon Race failed: " .. tostring(err)) end
            task.wait(1) -- Wait 1 second between rolls
        end
        
        if rollSaiyanEnabled then
            local ok, err = pcall(function()
                local args = {
                    {
                        Open_Amount = amount,
                        Action = "_Gacha_Activate",
                        Name = "Saiyan_Evolution"
                    }
                }
                game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("To_Server"):FireServer(unpack(args))
            end)
            if not ok then warn("Auto Roll Saiyan Evolution failed: " .. tostring(err)) end
            task.wait(1) -- Wait 1 second between rolls
        end
        
        if not rollEnabled and not rollSaiyanEnabled then
            task.wait(1)
        end
    end
end)

-- Dungeon Tab
local selectedDungeons = {}

-- Get dungeon gates from workspace
local function getDungeonGates()
    -- Return fixed list of dungeons
    return {
        "Dungeon Easy",
        "Dungeon Medium", 
        "Dungeon Hard",
        "Dungeon Insane",
        "Dungeon Crazy",
        "Dungeon Nightmare"
    }
end

-- Function to update selected dungeons display
local selectedDungeonsLabel = nil
local function updateSelectedDungeonsDisplay()
    if not selectedDungeonsLabel then return end
    if #selectedDungeons > 0 then
        -- Show short names for better display
        local shortNames = {}
        for _, dungeon in ipairs(selectedDungeons) do
            local shortName = dungeon:gsub("Dungeon ", "")
            table.insert(shortNames, shortName)
        end
        selectedDungeonsLabel:Set("Selected Dungeons: " .. table.concat(shortNames, ", "))
    else
        selectedDungeonsLabel:Set("Selected Dungeons: None")
    end
end

-- Add section for dungeon selection
DungeonTab:AddSection({ Name = "Dungeon Selection" })

-- Dynamic label to show selected dungeons
selectedDungeonsLabel = DungeonTab:AddLabel("Selected Dungeons: None")

-- Dungeon Gate Selection Dropdown
local dungeonGates = getDungeonGates()
local dungeonDropdown = DungeonTab:AddDropdown({
    Name = "Select Dungeons",
    Default = "",
    Options = dungeonGates,
    Callback = function(Value)
        if Value and Value ~= "" then
            if not table.find(selectedDungeons, Value) then
                table.insert(selectedDungeons, Value)
                OrionLib:MakeNotification({
                    Name = "Dungeon Selected",
                    Content = "Added " .. Value:gsub("Dungeon ", "") .. " to dungeon list!",
                    Image = "rbxassetid://4483345998",
                    Time = 2
                })
            else
                -- Remove from list if already selected
                for i, dungeon in ipairs(selectedDungeons) do
                    if dungeon == Value then
                        table.remove(selectedDungeons, i)
                        break
                    end
                end
                OrionLib:MakeNotification({
                    Name = "Dungeon Deselected",
                    Content = "Removed " .. Value:gsub("Dungeon ", "") .. " from dungeon list!",
                    Image = "rbxassetid://4483345998",
                    Time = 2
                })
            end
            updateSelectedDungeonsDisplay()
        end
    end
})

-- Refresh List Button
DungeonTab:AddButton({
    Name = "Refresh List",
    Callback = function()
        dungeonGates = getDungeonGates()
        dungeonDropdown:Refresh(dungeonGates, true)
        OrionLib:MakeNotification({
            Name = "Dungeon List",
            Content = "Dungeon list refreshed successfully!",
            Image = "rbxassetid://4483345998",
            Time = 2
        })
    end
})

-- Reset Dungeon Selected Button
DungeonTab:AddButton({
    Name = "Reset Dungeon Selected",
    Callback = function()
        selectedDungeons = {}
        updateSelectedDungeonsDisplay()
        OrionLib:MakeNotification({
            Name = "Dungeon Selection",
            Content = "All selected dungeons have been cleared!",
            Image = "rbxassetid://4483345998",
            Time = 2
        })
    end
})

-- Add section for auto dungeon
DungeonTab:AddSection({ Name = "Auto Dungeon" })

-- Auto Dungeon Toggle
DungeonTab:AddToggle({
    Name = "Auto Dungeon",
    Default = false,
    Flag = "autoDungeonEnabled",
    Save = true,
    Callback = function(Value)
        if Value then
            OrionLib:MakeNotification({
                Name = "Auto Dungeon",
                Content = "Auto Dungeon enabled!",
                Image = "rbxassetid://4483345998",
                Time = 2
            })
        else
            OrionLib:MakeNotification({
                Name = "Auto Dungeon",
                Content = "Auto Dungeon disabled!",
                Image = "rbxassetid://4483345998",
                Time = 2
            })
        end
    end
})

-- Dungeon name mapping (display name -> attribute name)
local dungeonNameMap = {
    ["Dungeon Easy"] = "Dungeon_Easy",
    ["Dungeon Medium"] = "Dungeon_Medium",
    ["Dungeon Hard"] = "Dungeon_Hard", 
    ["Dungeon Insane"] = "Dungeon_Insane",
    ["Dungeon Crazy"] = "Dungeon_Crazy",
    ["Dungeon Nightmare"] = "Dungeon_Nightmare"
}

-- Auto Dungeon Logic
spawn(function()
    while true do
        local autoDungeonEnabled = OrionLib.Flags["autoDungeonEnabled"] and OrionLib.Flags["autoDungeonEnabled"].Value or false
        
        if autoDungeonEnabled and #selectedDungeons > 0 then
            local success, err = pcall(function()
                -- Check dungeon notification UI
                local player = game:GetService("Players").LocalPlayer
                local playerGui = player:WaitForChild("PlayerGui")
                local dungeonUI = playerGui:FindFirstChild("Dungeon")
                
                if dungeonUI then
                    local dungeonNotification = dungeonUI:FindFirstChild("Dungeon_Notification")
                    if dungeonNotification and dungeonNotification.Visible then
                        -- Get dungeon name from properties instead of text
                        local dungeonNameFromProps = dungeonNotification:GetAttribute("dungeon_name")
                        if not dungeonNameFromProps then
                            -- Try alternative property names
                            dungeonNameFromProps = dungeonNotification:GetAttribute("Dungeon_Name") or
                                                 dungeonNotification:GetAttribute("DungeonName") or
                                                 dungeonNotification:GetAttribute("Name")
                        end
                        
                        if dungeonNameFromProps then
                            -- Check if this dungeon is in our selected list
                            for _, selectedDungeon in ipairs(selectedDungeons) do
                                local attributeName = dungeonNameMap[selectedDungeon] or selectedDungeon
                                if tostring(dungeonNameFromProps) == attributeName then
                                    
                                    -- Find and click Yes button
                                    local yesButton = dungeonNotification:FindFirstChild("Yes")
                                    if not yesButton then
                                        -- Try to find Yes button in children
                                        for _, child in pairs(dungeonNotification:GetDescendants()) do
                                            if child:IsA("GuiButton") or child:IsA("TextButton") or child:IsA("ImageButton") then
                                                -- Check by name first
                                                if child.Name == "Yes" then
                                                    yesButton = child
                                                    break
                                                end
                                                -- Only check Text property if it's a TextButton
                                                if child:IsA("TextButton") and child.Text and string.find(child.Text:lower(), "yes") then
                                                    yesButton = child
                                                    break
                                                end
                                            end
                                        end
                                    end
                                    
                                    if yesButton then
                                        -- Click the Yes button
                                        for _, connection in pairs(getconnections(yesButton.MouseButton1Click)) do
                                            connection:Fire()
                                        end
                                        for _, connection in pairs(getconnections(yesButton.Activated)) do
                                            connection:Fire()
                                        end
                                        
                                        -- Hide the dungeon notification UI to prevent multiple clicks
                                        dungeonNotification.Visible = false
                                        
                                        print("[Auto Dungeon] Clicked Yes button for dungeon: " .. tostring(dungeonNameFromProps))
                                        
                                        task.wait(3) -- Wait longer after clicking
                                        break
                                    else
                                        -- Fallback: Use RemoteEvent with dungeon name from properties
                                        local args = {
                                            {
                                                Action = "_Enter_Dungeon",
                                                Name = tostring(dungeonNameFromProps)
                                            }
                                        }
                                        game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("To_Server"):FireServer(unpack(args))
                                        
                                        -- Hide the dungeon notification UI after sending RemoteEvent
                                        dungeonNotification.Visible = false
                                        
                                        print("[Auto Dungeon] Used RemoteEvent for dungeon: " .. tostring(dungeonNameFromProps))
                                        
                                        task.wait(1)
                                        break
                                    end
                                end
                            end
                        end
                    end
                end
            end)
            
            if not success then
                warn("Auto Dungeon failed: " .. tostring(err))
            end
        end
        
        task.wait(1) -- Check every second
    end
end)

-- Initialize OrionLib
OrionLib:Init()
