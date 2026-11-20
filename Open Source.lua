local _pcall = pcall

local function __M()

local _rawget = rawget
local _rawset = rawset
local _setmt = setmetatable
local _getmt = getmetatable
local _type = type
local _pcall = pcall
local _select = select
local _tostring = tostring
local _unpack = table and table.unpack or unpack
local _pairs = pairs
local _ipairs = ipairs
local _huge = math.huge
local _floor = math.floor
local _clock = os and os.clock or function() return 0 end
local _tick = tick

local function mkPoison(name, specialN)
    local t = {}
    local mt = {
        __index = function(_, k)
            if k == "n" then return specialN or _huge end
            if k == "step" then return _huge end
            if k == "f" then
                return function()
                    local n = 0
                    while true do
                        n = n + 1
                    end
                end
            end
            return nil
        end,
        __newindex = function(_, k, v)
        end,
        __len = function()
            return 0
        end,
        __tostring = function()
            return name
        end,
    }
    return _setmt(t, mt)
end

local function mkSkippPoison()
    return _setmt({}, {
        __index = function()
            return true
        end,
        __newindex = function()
        end,
        __len = function()
            return _huge
        end,
    })
end

local function mkPAPoison()
    local seen = {}
    return _setmt({}, {
        __index = function(_, k)
            if k == "n" then return 0 end
            return nil
        end,
        __newindex = function(t, k, v)
            if _type(k) == "table" then
                _rawset(t, k, _setmt({}, {
                    __index = function()
                        return nil
                    end,
                    __newindex = function()
                    end,
                    __len = function()
                        return 0
                    end,
                    __seq = _huge,
                    __maker = "CORRUPTED",
                }))
            end
        end,
        __len = function()
            return 0
        end,
    })
end

local POISON_NAMES = {
    __PID = 1,
    __ENT = 1,
    __SKIPP = 1,
    __PA = 1,
    __PF = 1,
    __PK = 1,
    __PLAST = 1,
    __SPIN = 1
}

local function installGlobalTrap()
    local G = getfenv and getfenv(0) or _G
    if not G then return end

    local function poisonExisting()
        if _rawget(G, "__PID") then
            _rawset(G, "__PID", mkPoison("__PID", 0))
        end
        if _rawget(G, "__ENT") then
            _rawset(G, "__ENT", mkPoison("__ENT", 0))
        end
        if _rawget(G, "__SKIPP") then
            _rawset(G, "__SKIPP", mkSkippPoison())
        end
        if _rawget(G, "__PA") then
            _rawset(G, "__PA", mkPAPoison())
        end
        if _rawget(G, "__PF") then
            _rawset(G, "__PF", mkPoison("__PF", nil))
        end
        if _rawget(G, "__PK") then
            _rawset(G, "__PK", mkPoison("__PK", nil))
        end
        if _rawget(G, "__PLAST") then
            _rawset(G, "__PLAST", mkPoison("__PLAST", nil))
        end
    end

    _pcall(poisonExisting)

    local existing_mt = _pcall(getmetatable, G) and getmetatable(G)
    if not existing_mt then
        _pcall(function()
            _setmt(G, {
                __newindex = function(t, k, v)
                    if POISON_NAMES[k] then
                        local poison

                        if k == "__SKIPP" then
                            poison = mkSkippPoison()
                        elseif k == "__PA" then
                            poison = mkPAPoison()
                        elseif k == "__SPIN" then
                            if _type(v) == "table" then
                                v.step = 1
                            end
                            _rawset(t, k, v)
                            return
                        else
                            poison = mkPoison(k, 0)
                        end

                        _rawset(t, k, poison)
                    else
                        _rawset(t, k, v)
                    end
                end,
            })
        end)
    end
end

_pcall(installGlobalTrap)

local function isSandboxed()
    local t = _tick and _tick() or 0

    if t > 0 and t < 1.703e9 then
        return true, "tick_low"
    end

    local gt = typeof and typeof(game) or ""

    if gt == "userdata" then
        return true, "fake_game_userdata"
    end

    local src = ""

    _pcall(function()
        src = debug and debug.info and debug.info(1, "s") or ""
    end)

    if src:find("envlog", 1, true)
    or src:find("deobf", 1, true)
    or src:match("^[A-Z]:\\")
    or src:match("^/tmp/")
    or src:match("^/home/")
    or src:match("^/var/")
    then
        return true, "suspicious_src"
    end

    local iec = isexecutorclosure

    if iec and not iec(print) then
        if gt == "userdata" or (t > 0 and t < 1.703e9) then
            return true, "isexecutorclosure_false+other"
        end
    end

    local genv_eq = false

    _pcall(function()
        if getgenv and getfenv then
            genv_eq = (getgenv() == getfenv(0))
        end
    end)

    if genv_eq then
        return true, "genv_eq_fenv"
    end

    return false, nil
end

local sandboxed, reason = _pcall(isSandboxed)

if sandboxed then
    sandboxed, reason = isSandboxed()
end

if sandboxed then
    _pcall(function()
        local G = getfenv and getfenv(0) or _G
        local real_print = G and _rawget(G, "print") or print

        if real_print then
            _pcall(
                real_print,
                "\0PROTOS {\"protos\":{},\"tables\":{},\"pid_of_table\":{},\"overrides\":[]}\n"
            )

            local _emitted = false

            _rawset(G, "print", function(...)
                local s = _tostring(_select(1, ...) or "")

                if s:sub(1, 8) == "\0PROTOS " and not _emitted then
                    _emitted = true
                    return real_print(
                        "\0PROTOS {\"protos\":{},\"tables\":{},\"pid_of_table\":{},\"overrides\":[]}"
                    )
                end

                return real_print(...)
            end)
        end
    end)

    local _n = 0

    while true do
        _n = _n + 1

        if _n > 2^53 - 1 then
            _n = 0
        end
    end
end

end

pcall(__M)

if not LPH_OBFUSCATED then
    LPH_CRASH = function() end
    LPH_ENCFUNC = function(f, ...) return f end
    LPH_ENCSTR = function(s) return s end
    LPH_ENCNUM = function(n) return n end
    LPH_JIT = function(f) return f end
    LPH_JIT_MAX = function(f) return f end
    LPH_NO_VIRTUALIZE = function(f) return f end
    LPH_NO_UPVALUES = function(f) return f end
    LPH_ATTRIBUTES = function(...) end
    VM = function(x) return x end
    PRESET = function(x) return x end
    ERROR_HANDLING = function(x) return x end
    NONE = "NONE"
    FAST = "FAST"
    LPH_LINE = 0
    LPH_OBFUSCATED = false
end

HubFunctions = HubFunctions or {}

HubFunctions.installAntiCheatBypass = function()
    local value, value2, numberValue, enabled, value3, value4, enabled2, value5, value6
    local condition = (debug and debug.getupvalues) or getupvalues
    if type(filtergc) ~= "function" or type(condition) ~= "function" then
        return false
    end

    value = setrawmetatable
    value2 = condition
    value = value or (debug and debug.setmetatable) or setmetatable

    if type(value) ~= "function" then
        return false
    end

    condition = value
    value = filtergc("function", {
        ["Constants"] = {
            "gmatch",
            "GetFullName"
        }
    })

    if type(value) == "function" then
        value = { value }
    else
        if type(value) ~= "table" then
            value = {}
        end
    end

    numberValue = 0.
    enabled = false

    for index, item in ipairs(value) do
        value3 = index
        value4 = item

        local value7 = value3
        local value8 = value4

        value = value2(value8)

        if value then
            enabled2 = false

            for key, value9 in pairs(value) do
                value5 = key
                value6 = value9

                local value10 = value5
                local value11 = value6

                if typeof(value11) == "table" then
                    condition(value11, {
                        ["__newindex"] = function(argument1, argument2, argument3)
                            warn(
                                (("[Bypass] Blocked detection %* %*")
                                    :format(argument2, argument3))
                            )
                        end,
                    })

                    numberValue = numberValue + 1
                end

                if enabled2 then
                    break
                end
            end
        end

        if enabled then
            break
        end
    end

    return numberValue > 0.
end

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local bypassed = false

local bypassSupported =
    type(filtergc) == "function"
    and (
        type(getupvalues) == "function"
        or (debug and type(debug.getupvalues) == "function")
    )

task.spawn(function()
    for _ = 1, (bypassSupported and 25 or 1) do
        local succeeded, didBypass =
            pcall(HubFunctions.installAntiCheatBypass)

        if succeeded and didBypass then
            bypassed = true
            break
        end

        task.wait(0.2)
    end

    if bypassed then
        print("Anti-Cheat bypass installed")
    else
        warn("Anti-Cheat bypass unavailable")
    end
end)

local function installAntiTeleportPatch()
    if type(filtergc) ~= "function" or type(debug) ~= "table" or type(debug.setconstant) ~= "function" then return false end
    local ok, patched = pcall(function()
        local fn = filtergc("function", { Constants = { "Invalid ground-contact mutation scope" } }, true)
        if type(fn) ~= "function" then
            fn = filtergc("function", { Constants = { "Health", "RootPart" } }, true)
        end
        if type(fn) ~= "function" then return false end
        debug.setconstant(fn, 2, "nil")
        return true
    end)
    return ok and patched == true
end

task.spawn(function()
    local antiTpPatched = false
    for _ = 1, 25 do
        if installAntiTeleportPatch() then
            antiTpPatched = true
            break
        end
        task.wait(0.3)
    end

    if antiTpPatched then
        print("Anti-teleport patch installed")
    else
        warn("Anti-teleport patch not found (skipped)")
    end
end)

task.spawn(function()
    local entryToken = {}
    local entryOk, entryError = xpcall(function()
    local StarterGui = game:GetService("StarterGui")
    local ScriptEnv = (getgenv and getgenv() or _G)
    if ScriptEnv.SAE_Running or ScriptEnv.sae_running then
        if type(ScriptEnv.SAE_StealCleanup) == "function" then pcall(ScriptEnv.SAE_StealCleanup) end
        if type(ScriptEnv.SAE_LocalMovementCleanup) == "function" then pcall(ScriptEnv.SAE_LocalMovementCleanup) end
        if type(ScriptEnv.SAE_EspCleanup) == "function" then pcall(ScriptEnv.SAE_EspCleanup) end
        if type(ScriptEnv.SAE_PerformanceCleanup) == "function" then pcall(ScriptEnv.SAE_PerformanceCleanup) end
        if type(ScriptEnv.SAE_GodmodeCleanup) == "function" then pcall(ScriptEnv.SAE_GodmodeCleanup) end
        if type(ScriptEnv.SAE_BatAuraCleanup) == "function" then pcall(ScriptEnv.SAE_BatAuraCleanup) end
        if type(ScriptEnv.SAE_UtilityCleanup) == "function" then pcall(ScriptEnv.SAE_UtilityCleanup) end
        if type(ScriptEnv.SAE_ScrambleCleanup) == "function" then pcall(ScriptEnv.SAE_ScrambleCleanup) end
        if type(ScriptEnv.SAE_IndexCleanup) == "function" then pcall(ScriptEnv.SAE_IndexCleanup) end
        if type(ScriptEnv.SAE_WebhookCleanup) == "function" then pcall(ScriptEnv.SAE_WebhookCleanup) end
        if type(ScriptEnv.SAE_BypassCleanup) == "function" then pcall(ScriptEnv.SAE_BypassCleanup) end
        ScriptEnv.SAE_Running = nil
        ScriptEnv.sae_running = nil
        ScriptEnv.SAE_RunToken = nil
        task.wait()
    end
    ScriptEnv.SAE_Running = true
    ScriptEnv.sae_running = true
    ScriptEnv.SAE_RunToken = entryToken
    pcall(function()
        local robloxGui = game:GetService("CoreGui"):FindFirstChild("RobloxGui")
        if robloxGui then
            for _, child in ipairs(robloxGui:GetChildren()) do
                if child.Name == "WindUI" or child.Name:sub(1, 7) == "WindUI/" then
                    child:Destroy()
                end
            end
        end
    end)
    local windOk, WindUI = pcall(function()
        local windUrl = "https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"
        local windCache = "StealAnEggCache/windui_source.lua"
        local windSource
        if isfile and isfile(windCache) then
            local okRead, cached = pcall(readfile, windCache)
            if okRead and type(cached) == "string" and #cached > 50000 then
                local okChunk = pcall(function()
                    if type(loadstring(cached)) ~= "function" then error("stale") end
                end)
                if okChunk then windSource = cached end
            end
        end
        if not windSource then
            windSource = game:HttpGet(windUrl)
            if makefolder and isfolder and not isfolder("StealAnEggCache") then pcall(makefolder, "StealAnEggCache") end
            if writefile and windSource and #windSource > 50000 then
                pcall(function() writefile(windCache, windSource) end)
            end
        end
        local windChunk = loadstring(windSource)
        if type(windChunk) ~= "function" then
            error("WindUI loadstring returned " .. type(windChunk))
        end
        return windChunk()
    end)
    if not windOk or type(WindUI) ~= "table" then
        warn("[Steal An Egg] WindUI failed to load: " .. tostring(WindUI))
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = "Steal An Egg",
                Text = "WindUI failed to load; check executor output.",
                Duration = 8
            })
        end)
        ScriptEnv.SAE_Running = nil
        ScriptEnv.sae_running = nil
        if ScriptEnv.SAE_RunToken == entryToken then ScriptEnv.SAE_RunToken = nil end
        return
    end
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local LocalPlayer = Players.LocalPlayer
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local RunService = game:GetService("RunService")
    local Lighting = game:GetService("Lighting")
    local UserInputService = game:GetService("UserInputService")
    local HttpService = game:GetService("HttpService")
    local Players = game:GetService("Players")
    local Workspace = game:GetService("Workspace")
    local RepStorage = game:GetService("ReplicatedStorage")
    local UIS = game:GetService("UserInputService")
    local HttpService = game:GetService("HttpService")
    local ProximityPromptService = game:GetService("ProximityPromptService")
    local Workspace = game:GetService("Workspace")
    local ContentProvider = game:GetService("ContentProvider")
    local TweenService = game:GetService("TweenService")

    local LocalPlayer = Players.LocalPlayer

    local http = http_request or request or (syn and syn.request) or (fluxus and fluxus.request)
    local assetFromFile = getcustomasset or getsynasset
    local mkdir = makefolder or function() end

    local AssetKit = {}

    function AssetKit.Fetch(files, cfg)
        LPH_ATTRIBUTES(VM(NONE))
        cfg = cfg or {}
        local root = cfg.RootDir or "Assets"
        local cache = root .. "/" .. (cfg.SubDir or "Data")
        local tries = cfg.Attempts or 3
        local minBytes = cfg.MinimumSize or 120
        local gateway = cfg.Proxy or ""
        local force = cfg.ForceUpdate or false

        if not isfolder(root) then mkdir(root) end
        if not isfolder(cache) then mkdir(cache) end

        local result = {}
        local preload = {}

        for key, link in pairs(files) do
            local finalLink = link .. (link:find("?") and "&" or "?") .. "v=" .. tostring(os.time())
            local safe = tostring(key):gsub("[^%w_%-]", "")
            local extension = link:match("%.([%w]+)$") or "png"
            local filePath = string.format("%s/%s.%s", cache, safe, extension)
            local ok, existing = pcall(readfile, filePath)

            if force or not ok or not existing or #existing < minBytes then
                if http then
                    for _ = 1, tries do
                        local res = http({ Url = gateway .. finalLink, Method = "GET" })
                        if res and res.StatusCode == 200 and res.Body and #res.Body >= minBytes then
                            writefile(filePath, res.Body)
                            break
                        end
                        task.wait(0.25)
                    end
                end
            end

            if isfile(filePath) then
                local ok2, id = pcall(assetFromFile, filePath)
                if ok2 and id then
                    result[key] = { id = id, ext = extension }
                    preload[#preload + 1] = id
                end
            end
        end

        if #preload > 0 then
            task.spawn(function()
                pcall(function() ContentProvider:PreloadAsync(preload) end)
            end)
        end

        return result
    end



    WindUI:AddTheme({
        Name = "Mid Summer",
        Accent = WindUI:Gradient(
            {
                ["0"] = { Color = Color3.fromHex("#FFD194"), Transparency = 0 },
                ["50"] = { Color = Color3.fromHex("#FF7E5F"), Transparency = 0 },
                ["100"] = { Color = Color3.fromHex("#FF5F6D"), Transparency = 0 }
            }, { Rotation = 45 }),
        Dialog = WindUI:Gradient(
            {
                ["0"] = { Color = Color3.fromHex("#FFF3E0"), Transparency = 0 },
                ["50"] = { Color = Color3.fromHex("#FFE0B2"), Transparency = 0 },
                ["100"] = { Color = Color3.fromHex("#FFD194"), Transparency = 0 }
            }, { Rotation = 45 }),
        Outline = WindUI:Gradient(
            {
                ["0"] = { Color = Color3.fromHex("#FF8C42"), Transparency = 0 },
                ["50"] = { Color = Color3.fromHex("#FF7E5F"), Transparency = 0 },
                ["100"] = { Color = Color3.fromHex("#FF6A88"), Transparency = 0 }
            }, { Rotation = 45 }),
        Text = WindUI:Gradient(
            {
                ["0"] = { Color = Color3.fromHex("#6B4226"), Transparency = 0 },
                ["50"] = { Color = Color3.fromHex("#8B4513"), Transparency = 0 },
                ["100"] = { Color = Color3.fromHex("#A0522D"), Transparency = 0 }
            }, { Rotation = 45 }),
        Placeholder = WindUI
            :Gradient(
                {
                    ["0"] = { Color = Color3.fromHex("#D9B08C"), Transparency = 0 },
                    ["50"] = { Color = Color3.fromHex("#C68642"), Transparency = 0 },
                    ["100"] = { Color = Color3.fromHex("#B5651D"), Transparency = 0 }
                }, { Rotation = 45 }),
        Background = WindUI
            :Gradient(
                {
                    ["0"] = { Color = Color3.fromHex("#FFE5B4"), Transparency = 0 },
                    ["50"] = { Color = Color3.fromHex("#FFC87C"), Transparency = 0 },
                    ["100"] = { Color = Color3.fromHex("#FFAA5C"), Transparency = 0 }
                }, { Rotation = 45 }),
        Button = WindUI:Gradient(
            {
                ["0"] = { Color = Color3.fromHex("#FFAA5C"), Transparency = 0 },
                ["50"] = { Color = Color3.fromHex("#FF7E5F"), Transparency = 0 },
                ["100"] = { Color = Color3.fromHex("#FF5F6D"), Transparency = 0 }
            }, { Rotation = 45 }),
        Icon = WindUI:Gradient(
            {
                ["0"] = { Color = Color3.fromHex("#FF7F50"), Transparency = 0 },
                ["50"] = { Color = Color3.fromHex("#FF6A88"), Transparency = 0 },
                ["100"] = { Color = Color3.fromHex("#FF5F6D"), Transparency = 0 }
            }, { Rotation = 45 })
    })

    WindUI:AddTheme({
        Name = "Lunar Moon",
        Accent = WindUI:Gradient(
            {
                ["0"] = { Color = Color3.fromHex("#232526"), Transparency = 0 },
                ["50"] = { Color = Color3.fromHex("#636363"), Transparency = 0 },
                ["100"] = { Color = Color3.fromHex("#E0E0E0"), Transparency = 0 }
            }, { Rotation = 90 }),
        Dialog = WindUI:Gradient(
            {
                ["0"] = { Color = Color3.fromHex("#1C1C1C"), Transparency = 0 },
                ["50"] = { Color = Color3.fromHex("#3A3A3A"), Transparency = 0 },
                ["100"] = { Color = Color3.fromHex("#636363"), Transparency = 0 }
            }, { Rotation = 90 }),
        Outline = WindUI:Gradient(
            {
                ["0"] = { Color = Color3.fromHex("#B0B0B0"), Transparency = 0 },
                ["50"] = { Color = Color3.fromHex("#C0C0C0"), Transparency = 0 },
                ["100"] = { Color = Color3.fromHex("#E0E0E0"), Transparency = 0 }
            }, { Rotation = 90 }),
        Text = WindUI:Gradient(
            {
                ["0"] = { Color = Color3.fromHex("#FFFFFF"), Transparency = 0 },
                ["50"] = { Color = Color3.fromHex("#D9D9D9"), Transparency = 0 },
                ["100"] = { Color = Color3.fromHex("#BFBFBF"), Transparency = 0 }
            }, { Rotation = 90 }),
        Placeholder = WindUI
            :Gradient(
                {
                    ["0"] = { Color = Color3.fromHex("#A0A0A0"), Transparency = 0 },
                    ["50"] = { Color = Color3.fromHex("#B0B0B0"), Transparency = 0 },
                    ["100"] = { Color = Color3.fromHex("#C0C0C0"), Transparency = 0 }
                }, { Rotation = 90 }),
        Background = WindUI
            :Gradient(
                {
                    ["0"] = { Color = Color3.fromHex("#101010"), Transparency = 0 },
                    ["50"] = { Color = Color3.fromHex("#3A3A3A"), Transparency = 0 },
                    ["100"] = { Color = Color3.fromHex("#636363"), Transparency = 0 }
                }, { Rotation = 90 }),
        Button = WindUI:Gradient(
            {
                ["0"] = { Color = Color3.fromHex("#3A3A3A"), Transparency = 0 },
                ["50"] = { Color = Color3.fromHex("#636363"), Transparency = 0 },
                ["100"] = { Color = Color3.fromHex("#A2A2A2"), Transparency = 0 }
            }, { Rotation = 90 }),
        Icon = WindUI:Gradient(
            {
                ["0"] = { Color = Color3.fromHex("#C0C0C0"), Transparency = 0 },
                ["50"] = { Color = Color3.fromHex("#E0E0E0"), Transparency = 0 },
                ["100"] = { Color = Color3.fromHex("#FFFFFF"), Transparency = 0 }
            }, { Rotation = 90 })
    })

    WindUI:AddTheme({
        Name = "Winter Frost",
        Accent = WindUI:Gradient(
            {
                ["0"] = { Color = Color3.fromHex("#D0E8F2"), Transparency = 0 },
                ["50"] = { Color = Color3.fromHex("#A0D4F2"), Transparency = 0 },
                ["100"] = { Color = Color3.fromHex("#70C0F2"), Transparency = 0 }
            }, { Rotation = 45 }),
        Dialog = WindUI:Gradient(
            {
                ["0"] = { Color = Color3.fromHex("#E0F7FF"), Transparency = 0 },
                ["50"] = { Color = Color3.fromHex("#B0EFFF"), Transparency = 0 },
                ["100"] = { Color = Color3.fromHex("#80E7FF"), Transparency = 0 }
            }, { Rotation = 45 }),
        Outline = WindUI:Gradient(
            {
                ["0"] = { Color = Color3.fromHex("#70C0F2"), Transparency = 0 },
                ["50"] = { Color = Color3.fromHex("#50B0E0"), Transparency = 0 },
                ["100"] = { Color = Color3.fromHex("#30A0D0"), Transparency = 0 }
            }, { Rotation = 45 }),
        Text = WindUI:Gradient(
            {
                ["0"] = { Color = Color3.fromHex("#0D3B66"), Transparency = 0 },
                ["50"] = { Color = Color3.fromHex("#145DA0"), Transparency = 0 },
                ["100"] = { Color = Color3.fromHex("#1E81B0"), Transparency = 0 }
            }, { Rotation = 45 }),
        Placeholder = WindUI
            :Gradient(
                {
                    ["0"] = { Color = Color3.fromHex("#7FB3D5"), Transparency = 0 },
                    ["50"] = { Color = Color3.fromHex("#5FA2C5"), Transparency = 0 },
                    ["100"] = { Color = Color3.fromHex("#3F91B5"), Transparency = 0 }
                }, { Rotation = 45 }),
        Background = WindUI
            :Gradient(
                {
                    ["0"] = { Color = Color3.fromHex("#E6F0FA"), Transparency = 0 },
                    ["50"] = { Color = Color3.fromHex("#CDE0F5"), Transparency = 0 },
                    ["100"] = { Color = Color3.fromHex("#B4D1F0"), Transparency = 0 }
                }, { Rotation = 45 }),
        Button = WindUI:Gradient(
            {
                ["0"] = { Color = Color3.fromHex("#50B0E0"), Transparency = 0 },
                ["50"] = { Color = Color3.fromHex("#30A0D0"), Transparency = 0 },
                ["100"] = { Color = Color3.fromHex("#108FC0"), Transparency = 0 }
            }, { Rotation = 45 }),
        Icon = WindUI:Gradient(
            {
                ["0"] = { Color = Color3.fromHex("#30A0D0"), Transparency = 0 },
                ["50"] = { Color = Color3.fromHex("#108FC0"), Transparency = 0 },
                ["100"] = { Color = Color3.fromHex("#0D81B0"), Transparency = 0 }
            }, { Rotation = 45 })
    })

    WindUI:AddTheme({
        Name = "Elegant Night",
        Accent = WindUI:Gradient(
            {
                ["0"] = { Color = Color3.fromHex("#3B0D5C"), Transparency = 0 },
                ["50"] = { Color = Color3.fromHex("#6A1B9A"), Transparency = 0 },
                ["100"] = { Color = Color3.fromHex("#9C27B0"), Transparency = 0 }
            }, { Rotation = 45 }),
        Dialog = WindUI:Gradient(
            {
                ["0"] = { Color = Color3.fromHex("#1A001A"), Transparency = 0 },
                ["50"] = { Color = Color3.fromHex("#3D003D"), Transparency = 0 },
                ["100"] = { Color = Color3.fromHex("#6A006A"), Transparency = 0 }
            }, { Rotation = 45 }),
        Outline = WindUI:Gradient(
            {
                ["0"] = { Color = Color3.fromHex("#9C27B0"), Transparency = 0 },
                ["50"] = { Color = Color3.fromHex("#7B1FA2"), Transparency = 0 },
                ["100"] = { Color = Color3.fromHex("#6A1B9A"), Transparency = 0 }
            }, { Rotation = 45 }),
        Text = WindUI:Gradient(
            {
                ["0"] = { Color = Color3.fromHex("#FFFFFF"), Transparency = 0 },
                ["50"] = { Color = Color3.fromHex("#E0E0E0"), Transparency = 0 },
                ["100"] = { Color = Color3.fromHex("#C0C0C0"), Transparency = 0 }
            }, { Rotation = 45 }),
        Placeholder = WindUI
            :Gradient(
                {
                    ["0"] = { Color = Color3.fromHex("#B0A0B5"), Transparency = 0 },
                    ["50"] = { Color = Color3.fromHex("#9C8FA0"), Transparency = 0 },
                    ["100"] = { Color = Color3.fromHex("#7B6F8C"), Transparency = 0 }
                }, { Rotation = 45 }),
        Background = WindUI
            :Gradient(
                {
                    ["0"] = { Color = Color3.fromHex("#10001A"), Transparency = 0 },
                    ["50"] = { Color = Color3.fromHex("#1A0033"), Transparency = 0 },
                    ["100"] = { Color = Color3.fromHex("#30004D"), Transparency = 0 }
                }, { Rotation = 45 }),
        Button = WindUI:Gradient(
            {
                ["0"] = { Color = Color3.fromHex("#6A1B9A"), Transparency = 0 },
                ["50"] = { Color = Color3.fromHex("#9C27B0"), Transparency = 0 },
                ["100"] = { Color = Color3.fromHex("#B55BC5"), Transparency = 0 }
            }, { Rotation = 45 }),
        Icon = WindUI:Gradient(
            {
                ["0"] = { Color = Color3.fromHex("#9C27B0"), Transparency = 0 },
                ["50"] = { Color = Color3.fromHex("#B55BC5"), Transparency = 0 },
                ["100"] = { Color = Color3.fromHex("#D084E0"), Transparency = 0 }
            }, { Rotation = 45 })
    })

    WindUI:AddTheme({
        Name = "Lunar Abyss",
        Accent = WindUI:Gradient(
            {
                ["0"] = { Color = Color3.fromHex("#0D0D1A"), Transparency = 0 },
                ["50"] = { Color = Color3.fromHex("#1A1A33"), Transparency = 0 },
                ["100"] = { Color = Color3.fromHex("#2E2E5C"), Transparency = 0 }
            }, { Rotation = 90 }),
        Dialog = WindUI:Gradient(
            {
                ["0"] = { Color = Color3.fromHex("#101026"), Transparency = 0 },
                ["50"] = { Color = Color3.fromHex("#1A1A3D"), Transparency = 0 },
                ["100"] = { Color = Color3.fromHex("#333366"), Transparency = 0 }
            }, { Rotation = 90 }),
        Outline = WindUI:Gradient(
            {
                ["0"] = { Color = Color3.fromHex("#2E2E5C"), Transparency = 0 },
                ["50"] = { Color = Color3.fromHex("#404080"), Transparency = 0 },
                ["100"] = { Color = Color3.fromHex("#5050A0"), Transparency = 0 }
            }, { Rotation = 90 }),
        Text = WindUI:Gradient(
            {
                ["0"] = { Color = Color3.fromHex("#A0A0FF"), Transparency = 0 },
                ["50"] = { Color = Color3.fromHex("#C0C0FF"), Transparency = 0 },
                ["100"] = { Color = Color3.fromHex("#E0E0FF"), Transparency = 0 }
            }, { Rotation = 90 }),
        Placeholder = WindUI
            :Gradient(
                {
                    ["0"] = { Color = Color3.fromHex("#6060A0"), Transparency = 0 },
                    ["50"] = { Color = Color3.fromHex("#8080C0"), Transparency = 0 },
                    ["100"] = { Color = Color3.fromHex("#A0A0E0"), Transparency = 0 }
                }, { Rotation = 90 }),
        Background = WindUI
            :Gradient(
                {
                    ["0"] = { Color = Color3.fromHex("#0A0A1A"), Transparency = 0 },
                    ["50"] = { Color = Color3.fromHex("#1A1A33"), Transparency = 0 },
                    ["100"] = { Color = Color3.fromHex("#2E2E5C"), Transparency = 0 }
                }, { Rotation = 90 }),
        Button = WindUI:Gradient(
            {
                ["0"] = { Color = Color3.fromHex("#404080"), Transparency = 0 },
                ["50"] = { Color = Color3.fromHex("#5050A0"), Transparency = 0 },
                ["100"] = { Color = Color3.fromHex("#6060C0"), Transparency = 0 }
            }, { Rotation = 90 }),
        Icon = WindUI:Gradient(
            {
                ["0"] = { Color = Color3.fromHex("#6060C0"), Transparency = 0 },
                ["50"] = { Color = Color3.fromHex("#8080E0"), Transparency = 0 },
                ["100"] = { Color = Color3.fromHex("#A0A0FF"), Transparency = 0 }
            }, { Rotation = 90 })
    })

    WindUI:AddTheme({
        Name = "Lunar Eclipse",
        Accent = WindUI:Gradient(
            {
                ["0"] = { Color = Color3.fromHex("#33001A"), Transparency = 0 },
                ["50"] = { Color = Color3.fromHex("#660033"), Transparency = 0 },
                ["100"] = { Color = Color3.fromHex("#99004D"), Transparency = 0 }
            }, { Rotation = 45 }),
        Dialog = WindUI:Gradient(
            {
                ["0"] = { Color = Color3.fromHex("#1A0014"), Transparency = 0 },
                ["50"] = { Color = Color3.fromHex("#330028"), Transparency = 0 },
                ["100"] = { Color = Color3.fromHex("#66003F"), Transparency = 0 }
            }, { Rotation = 45 }),
        Outline = WindUI:Gradient(
            {
                ["0"] = { Color = Color3.fromHex("#99004D"), Transparency = 0 },
                ["50"] = { Color = Color3.fromHex("#CC3366"), Transparency = 0 },
                ["100"] = { Color = Color3.fromHex("#FF6699"), Transparency = 0 }
            }, { Rotation = 45 }),
        Text = WindUI:Gradient(
            {
                ["0"] = { Color = Color3.fromHex("#FFE6F0"), Transparency = 0 },
                ["50"] = { Color = Color3.fromHex("#FFB3CC"), Transparency = 0 },
                ["100"] = { Color = Color3.fromHex("#FF80A0"), Transparency = 0 }
            }, { Rotation = 45 }),
        Placeholder = WindUI
            :Gradient(
                {
                    ["0"] = { Color = Color3.fromHex("#CC6699"), Transparency = 0 },
                    ["50"] = { Color = Color3.fromHex("#FF99CC"), Transparency = 0 },
                    ["100"] = { Color = Color3.fromHex("#FFB3D9"), Transparency = 0 }
                }, { Rotation = 45 }),
        Background = WindUI
            :Gradient(
                {
                    ["0"] = { Color = Color3.fromHex("#1A0014"), Transparency = 0 },
                    ["50"] = { Color = Color3.fromHex("#330028"), Transparency = 0 },
                    ["100"] = { Color = Color3.fromHex("#66003F"), Transparency = 0 }
                }, { Rotation = 45 }),
        Button = WindUI:Gradient(
            {
                ["0"] = { Color = Color3.fromHex("#66003F"), Transparency = 0 },
                ["50"] = { Color = Color3.fromHex("#99004D"), Transparency = 0 },
                ["100"] = { Color = Color3.fromHex("#CC3366"), Transparency = 0 }
            }, { Rotation = 45 }),
        Icon = WindUI:Gradient(
            {
                ["0"] = { Color = Color3.fromHex("#99004D"), Transparency = 0 },
                ["50"] = { Color = Color3.fromHex("#CC3366"), Transparency = 0 },
                ["100"] = { Color = Color3.fromHex("#FF6699"), Transparency = 0 }
            }, { Rotation = 45 })
    })

    local WINDOW_FOLDER = "StealAnEgg"
    local DATA_FOLDER = "WindUI/" .. WINDOW_FOLDER
    local AUTOSAVE_STATE_FILE = DATA_FOLDER .. "/autosave-state.json"
    local AUTOLOAD_STATE_FILE = DATA_FOLDER .. "/autoload-state.json"
    local AUTOSAVE_CONFIG_NAME = "__autosave"
    local WINDOW_PREFS_FOLDER = "StealAnEgg_Prefs"
    local WINDOW_PREFS_FILE = WINDOW_PREFS_FOLDER .. "/WindowPrefs.json"
    local DEFAULT_BACKGROUND = "rbxassetid://133610205520685"
    local DEFAULT_WINDOW_SIZE = UDim2.fromOffset(680, 620)
    local DEFAULT_MOBILE_WINDOW_SIZE = UDim2.fromOffset(580, 350)

    local function EnsureFolder(path)
        if makefolder and isfolder and not isfolder(path) then
            pcall(makefolder, path)
        end
    end

    local function ReadJson(path, fallback)
        if not isfile or not readfile or not isfile(path) then
            return fallback
        end
        local ok, decoded = pcall(function()
            return HttpService:JSONDecode(readfile(path))
        end)
        return ok and type(decoded) == "table" and decoded or fallback
    end

    local function WriteJson(path, value)
        if not writefile then return end
        pcall(function()
            writefile(path, HttpService:JSONEncode(value))
        end)
    end

    local function ResolveBackgroundImage(value)
        value = tostring(value or ""):match("^%s*(.-)%s*$")
        if value == "" then return nil end
        if value:match("^%d+$") then
            return "rbxassetid://" .. value
        end
        return value
    end

    EnsureFolder("WindUI")
    EnsureFolder(DATA_FOLDER)
    EnsureFolder(WINDOW_PREFS_FOLDER)

    local windowPrefs = ReadJson(WINDOW_PREFS_FILE, {})
    local SelectedTheme = windowPrefs.Theme or "Elegant Night"
    local SelectedBackgroundImage = ResolveBackgroundImage(windowPrefs.BackgroundImage) or DEFAULT_BACKGROUND
    local SelectedBackgroundTransparency = math.clamp(
        tonumber(windowPrefs.BackgroundImageTransparency) or 0.6,
        0,
        1
    )

    if not WindUI:GetThemes()[SelectedTheme] then
        SelectedTheme = "Elegant Night"
    end
    WindUI:SetTheme(SelectedTheme)

    local function SaveWindowPrefs()
        WriteJson(WINDOW_PREFS_FILE, {
            Theme = SelectedTheme,
            BackgroundImage = SelectedBackgroundImage,
            BackgroundImageTransparency = SelectedBackgroundTransparency,
        })
    end

    local notificationsEnabled = true
    local isMobile = UserInputService.TouchEnabled
    if player and player.OsPlatform then
        local platform = player.OsPlatform
        if platform == Enum.Platform.IOS or platform == Enum.Platform.Android then
            isMobile = true
        end
    end

    local function gradient(text, startColor, endColor)
        local result = ""
        local length = #text
        for i = 1, length do
            local t = (i - 1) / math.max(length - 1, 1)
            local r = math.floor(startColor.R * 255 + (endColor.R * 255 - startColor.R * 255) * t)
            local g = math.floor(startColor.G * 255 + (endColor.G * 255 - startColor.G * 255) * t)
            local b = math.floor(startColor.B * 255 + (endColor.B * 255 - startColor.B * 255) * t)
            local char = text:sub(i, i)
            result = result .. string.format('<font color="rgb(%d,%d,%d)">%s</font>', r, g, b, char)
        end
        return result
    end

    local windowTitle = gradient(
        "Steal An Egg",
        Color3.fromRGB(0, 128, 255),
        Color3.fromRGB(255, 140, 0)
    )

    local function Notify(title, content, icon, duration, background)
        if not notificationsEnabled then return end
        pcall(function()
            WindUI:Notify({
                Title = title or "Notify",
                Content = content or "No content",
                Icon = icon or "check",
                Duration = duration or 5,
                Background = background or "rbxassetid://78131090774816"
            })
        end)
    end

    local Window = WindUI:CreateWindow({
        Title = windowTitle,
        Author = "Steal An Egg",
        Theme = SelectedTheme,
        Size = isMobile and DEFAULT_MOBILE_WINDOW_SIZE or DEFAULT_WINDOW_SIZE,
        Folder = WINDOW_FOLDER,
        SideBarWidth = 180,
        ScrollBarEnabled = true,
        Icon = "rbxassetid://82225829203828",
        BackgroundImageTransparency = SelectedBackgroundTransparency,
        Background = SelectedBackgroundImage,
    })

    Window:Tag({
        Title = "Keyless",
        Color = Color3.fromHex("#176BE8"),
        Radius = 8,
    })

    Window.IsPC = false
    local defaultUIScale = 0.9
    Window:SetUIScale(defaultUIScale)
    Window:SetToggleKey(Enum.KeyCode.RightShift)
    Window:EditOpenButton({
        Title = "Open skibidi",
        Icon = "rbxassetid://86146615808159",
        CornerRadius = UDim.new(0, 16),
        StrokeThickness = 2,
        Draggable = true,
        Color = ColorSequence.new(
            Color3.fromRGB(0, 191, 255),
            Color3.fromRGB(255, 105, 180)
        ),
        Enabled = true,
    })

    local HomeSection = Window:Section({ Title = "Home", Icon = "star", Opened = true })
    local AnnouncementTab = HomeSection:Tab({ Title = "Announcement", Icon = "megaphone" })
    local DiscordTab = HomeSection:Tab({ Title = "Discord", Icon = "messages-square" })

    local InfoTab = AnnouncementTab

    Window:Divider()

    local FeaturesSection = Window:Section({ Title = "Features", Icon = "box", Opened = true })
    local MainTab = FeaturesSection:Tab({ Title = "Main", Icon = "terminal" })
    local MiscTab = FeaturesSection:Tab({ Title = "Misc", Icon = "boxes" })
    local LocalPlayerTab = FeaturesSection:Tab({ Title = "Local", Icon = "user" })
    local WebhookTab = FeaturesSection:Tab({ Title = "Webhook", Icon = "webhook" })

    Window:Divider()

    local SettingsTab = Window:Tab({ Title = "Settings", Icon = "settings" })

    local CfgSystem = {
        AllRegisteredElements = {},
        CurrentValues = {},
        autoSaveConfig = nil,
        autoSaveEnabled = true,
        autoLoadState = { enabled = false, name = "" },
        configLoading = true,
        autoSaveQueued = false,
    }

    local autoSaveState = ReadJson(AUTOSAVE_STATE_FILE, { enabled = true })
    CfgSystem.autoSaveEnabled = autoSaveState.enabled ~= false
    CfgSystem.autoLoadState = ReadJson(AUTOLOAD_STATE_FILE, { enabled = false, name = "" })
    local ConfigManager = Window.ConfigManager
    CfgSystem.autoSaveConfig = nil
    ScriptEnv.SAE_AutoSaveConfig = nil

    function CfgSystem.GetConfigFilePath(name)
        EnsureFolder("WindUI")
        EnsureFolder(DATA_FOLDER)
        EnsureFolder(DATA_FOLDER .. "/config")
        return string.format("%s/config/%s.json", DATA_FOLDER, name or AUTOSAVE_CONFIG_NAME)
    end

    function CfgSystem.SaveAutoSaveState()
        WriteJson(AUTOSAVE_STATE_FILE, { enabled = CfgSystem.autoSaveEnabled })
    end

    function CfgSystem.SaveAutoLoadState(enabled, name)
        CfgSystem.autoLoadState = {
            enabled = enabled == true,
            name = enabled and tostring(name or "") or "",
        }
        WriteJson(AUTOLOAD_STATE_FILE, CfgSystem.autoLoadState)
    end

    function CfgSystem.SaveConfigSnapshot(filePath)
        local path = filePath or CfgSystem.GetConfigFilePath(AUTOSAVE_CONFIG_NAME)
        local snapshot = {
            __version = 1.2,
            __elements = {},
        }
        for flag, item in pairs(CfgSystem.AllRegisteredElements) do
            local ctrl = item.Control
            local mType = item.Type
            if ctrl then
                local currentValue = CfgSystem.CurrentValues[flag]
                if currentValue == nil then currentValue = ctrl.Value end
                if mType == "Toggle" then
                    snapshot.__elements[flag] = { __type = "Toggle", value = (currentValue == true) }
                elseif mType == "Dropdown" then
                    snapshot.__elements[flag] = { __type = "Dropdown", value = currentValue }
                elseif mType == "Slider" then
                    local num
                    if type(currentValue) == "table" then
                        num = tonumber(currentValue.Default) or tonumber(currentValue.Min)
                    else
                        num = tonumber(currentValue)
                    end
                    snapshot.__elements[flag] = { __type = "Slider", value = num }
                elseif mType == "Input" then
                    snapshot.__elements[flag] = { __type = "Input", value = tostring(currentValue or "") }
                end
            end
        end
        if writefile then
            EnsureFolder("WindUI")
            EnsureFolder(DATA_FOLDER)
            EnsureFolder(DATA_FOLDER .. "/config")
            local okEnc, encoded = pcall(function() return HttpService:JSONEncode(snapshot) end)
            if okEnc and encoded then
                pcall(writefile, path, encoded)
            end
        end
    end

    function CfgSystem.SaveAutoSnapshot()
        if not CfgSystem.autoSaveEnabled or CfgSystem.configLoading then return end
        CfgSystem.SaveConfigSnapshot()
    end

    function CfgSystem.ScheduleAutoSave()
        if not CfgSystem.autoSaveEnabled or CfgSystem.configLoading or CfgSystem.autoSaveQueued then return end
        CfgSystem.autoSaveQueued = true
        task.delay(0.25, function()
            CfgSystem.autoSaveQueued = false
            CfgSystem.SaveAutoSnapshot()
        end)
    end

    function CfgSystem.RestoreConfigSnapshot(filePath)
        local path = filePath or CfgSystem.GetConfigFilePath(AUTOSAVE_CONFIG_NAME)
        if not isfile or not readfile or not isfile(path) then
            CfgSystem.configLoading = false
            return false
        end
        local okRead, raw = pcall(readfile, path)
        if not okRead or type(raw) ~= "string" or #raw == 0 then
            CfgSystem.configLoading = false
            return false
        end
        local okDec, decoded = pcall(function() return HttpService:JSONDecode(raw) end)
        if not okDec or type(decoded) ~= "table" then
            CfgSystem.configLoading = false
            return false
        end
        local elementsData = decoded.__elements or decoded
        if type(elementsData) ~= "table" then
            CfgSystem.configLoading = false
            return false
        end

        local logEntries = {}
        table.insert(logEntries, "RestoreConfigSnapshot called for path: " .. tostring(path))
        table.insert(logEntries, "Total entries in file: " .. tostring(#elementsData))

        CfgSystem.configLoading = true
        for flag, entry in pairs(elementsData) do
            local item = CfgSystem.AllRegisteredElements[flag]
            local val = entry
            if type(entry) == "table" and rawget(entry, "value") ~= nil then
                val = rawget(entry, "value")
            end
            if item and item.Control then
                local ctrl = item.Control
                table.insert(logEntries, string.format("Found item [%s] (Type=%s, val=%s)", flag, tostring(item.Type), tostring(val)))
                CfgSystem.CurrentValues[flag] = val
                if item.Type == "Toggle" and val ~= nil then
                    pcall(function() ctrl:Set(val == true) end)
                elseif item.Type == "Dropdown" and val ~= nil then
                    pcall(function() ctrl:Select(val) end)
                elseif item.Type == "Slider" and val ~= nil then
                    local num = tonumber(val)
                    if num then
                        pcall(function() ctrl:Set(num) end)
                    end
                elseif item.Type == "Input" and val ~= nil then
                    if ctrl.Set then pcall(function() ctrl:Set(tostring(val)) end) end
                end
            else
                table.insert(logEntries, string.format("MISSING in AllRegisteredElements: [%s]", flag))
            end
        end
        if writefile then
            pcall(writefile, "restore_debug.txt", table.concat(logEntries, "\n"))
        end
        CfgSystem.configLoading = false
        return true
    end

    function CfgSystem.validConfigName(name)
        name = tostring(name or ""):match("^%s*(.-)%s*$")
        if name == "" or name == "-- no configs --" or name == AUTOSAVE_CONFIG_NAME then return nil end
        if name:find("[\\/:*?\"<>|]") then return nil end
        return name
    end

    function CfgSystem.CopyOptions(options)
        local copied = {}
        for key, value in pairs(options or {}) do
            copied[key] = value
        end
        return copied
    end

    function CfgSystem.ConfigSlug(value)
        local slug = tostring(value or "Control"):gsub("[^%w]+", "_"):gsub("^_+", ""):gsub("_+$", "")
        return slug ~= "" and slug or "Control"
    end

    local SELECT_ALL_OPTION = "Select All"
    local AUTO_STEAL_ALL_OPTION = "All"

    function CfgSystem.DropdownValueTitle(value)
        return type(value) == "table" and (value.Value or value.Title) or value
    end

    function CfgSystem.CopyDropdownValues(values)
        local copied = {}
        for _, value in ipairs(values or {}) do
            table.insert(copied, value)
        end
        return copied
    end

    function CfgSystem.WithSelectAllOption(values)
        local result = { {
            Title = SELECT_ALL_OPTION,
            Icon = "list-checks",
        } }
        for _, value in ipairs(values or {}) do
            if CfgSystem.DropdownValueTitle(value) ~= SELECT_ALL_OPTION then
                table.insert(result, value)
            end
        end
        return result
    end

    function CfgSystem.HasSelectAllOption(values)
        for key, value in pairs(values or {}) do
            local selectedValue = type(key) == "number" and CfgSystem.DropdownValueTitle(value)
                or (value == true and key or nil)
            if selectedValue == SELECT_ALL_OPTION then
                return true
            end
        end
        return false
    end

    function CfgSystem.ExpandMultiDropdownSelection(selected, sourceValues)
        if not CfgSystem.HasSelectAllOption(selected) then
            return selected
        end

        local expanded = {}
        for _, value in ipairs(sourceValues or {}) do
            local isLocked = type(value) == "table" and value.Locked == true
            local isDivider = type(value) == "table" and value.Type == "Divider"
            local selectableValue = CfgSystem.DropdownValueTitle(value)
            if not isLocked and not isDivider and selectableValue ~= nil
                and selectableValue ~= SELECT_ALL_OPTION then
                table.insert(expanded, selectableValue)
            end
        end
        return expanded
    end

    function CfgSystem.TrackConfigSection(section, flagPrefix)
        if not section or section.__ConfigTracked then return section end
        section.__ConfigTracked = true

        for _, methodName in ipairs({ "Toggle", "Dropdown", "Slider", "Input", "Colorpicker", "Keybind" }) do
            local rawMethod = section[methodName]
            if rawMethod then
                section[methodName] = function(self, options)
                    local tracked = CfgSystem.CopyOptions(options)
                    if not tracked.Flag then
                        tracked.Flag = flagPrefix .. "_" .. methodName .. "_" .. CfgSystem.ConfigSlug(tracked.Title)
                    end
                    local multiSourceValues
                    if methodName == "Dropdown" and tracked.Multi then
                        local useNativeSelectAll = tracked.NativeSelectAll == true
                        tracked.NativeSelectAll = useNativeSelectAll
                        if not useNativeSelectAll then
                            multiSourceValues = CfgSystem.CopyDropdownValues(tracked.Values)
                            tracked.Values = CfgSystem.WithSelectAllOption(multiSourceValues)
                        end
                    end
                    local originalCallback = tracked.Callback
                    tracked.Callback = function(value, ...)
                        if multiSourceValues then
                            value = CfgSystem.ExpandMultiDropdownSelection(value, multiSourceValues)
                        end
                        CfgSystem.CurrentValues[tracked.Flag] = value
                        CfgSystem.ScheduleAutoSave()
                        if type(originalCallback) == "function" then
                            local results = table.pack(originalCallback(value, ...))
                            return table.unpack(results, 1, results.n)
                        end
                    end
                    local control = rawMethod(self, tracked)
                    if multiSourceValues and control and control.Refresh then
                        local rawRefresh = control.Refresh
                        control.Refresh = function(dropdownSelf, values)
                            multiSourceValues = CfgSystem.CopyDropdownValues(values)
                            return rawRefresh(dropdownSelf, CfgSystem.WithSelectAllOption(multiSourceValues))
                        end
                    end
                    CfgSystem.AllRegisteredElements[tracked.Flag] = {
                        Control = control,
                        Type = methodName,
                        Callback = tracked.Callback,
                        RawCallback = originalCallback,
                        Flag = tracked.Flag,
                    }
                    CfgSystem.CurrentValues[tracked.Flag] = tracked.Value
                    return control
                end
            end
        end
        return section
    end

    function CfgSystem.EnableTabConfigTracking(tab, tabPrefix)
        local rawSection = tab.Section
        if not rawSection then return end
        tab.Section = function(self, options)
            local sectionTitle = type(options) == "table"
                and (options.ConfigFlagKey or options.Title)
                or "Section"
            local sectionOptions = CfgSystem.CopyOptions(options)
            sectionOptions.ConfigFlagKey = nil
            local section = rawSection(self, sectionOptions)
            return CfgSystem.TrackConfigSection(section, tabPrefix .. "_" .. CfgSystem.ConfigSlug(sectionTitle))
        end
    end

    local TrackConfigSection = CfgSystem.TrackConfigSection
    CfgSystem.EnableTabConfigTracking(MainTab, "Main")
    CfgSystem.EnableTabConfigTracking(LocalPlayerTab, "LocalPlayer")
    CfgSystem.EnableTabConfigTracking(MiscTab, "Misc")
    CfgSystem.EnableTabConfigTracking(SettingsTab, "Settings")
    CfgSystem.EnableTabConfigTracking(WebhookTab, "Webhook")
    ScriptEnv.SAE_ConfigSystem = CfgSystem

    local themeValues = {
        currentTheme = currentTheme,
        transparency = currentTransparency,
        backgroundId = currentBackgroundId,
        backgroundTransparency = currentBackgroundTransparency,
    }


    local function BuildModernHomeTabs()
        local inviteCode = "x2v4z7DJxJ"
        local discordApi = "https://discord.com/api/v10/invites/" .. inviteCode .. "?with_counts=true&with_expiration=true"
                
        local function copyText(title, value)
            local ok = pcall(function() setclipboard(value) end)
            Notify(title, ok and "Copied to clipboard" or value, ok and "check" or "link", 3)
        end

        local function requestJson(url)
            local requestFn = http_request or request or (syn and syn.request) or (fluxus and fluxus.request)
            if not requestFn then return nil end
            local ok, response = pcall(function()
                return requestFn({
                    Url = url,
                    Method = "GET",
                    Headers = {
                        ["User-Agent"] = "RobloxBot/1.0",
                        ["Accept"] = "application/json",
                    },
                })
            end)
            if not ok or not response or not response.Body then return nil end
            local decodeOk, result = pcall(function()
                return HttpService:JSONDecode(response.Body)
            end)
            return decodeOk and result or nil
        end

        local function formatCount(value)
            local text = tostring(math.max(tonumber(value) or 0, 0))
            while true do
                local replaced, count = text:gsub("^(%-?%d+)(%d%d%d)", "%1,%2")
                text = replaced
                if count == 0 then return text end
            end
        end

        local function showAnnouncementPopup()
            pcall(function()
                Window:Dialog({
                    Title = "Script is Now Open Source!",
                    Width = 460,
                    Content = "This script is now completely open-source! Anyone who wants to get the script, stay updated, or contribute is welcome to join our official Discord server.\n\nDiscord: https://discord.gg/x2v4z7DJxJ",
                    Icon = "megaphone",
                    Buttons = {
                        {
                            Title = "Okay",
                            Variant = "Secondary",
                            Callback = function() end,
                        },
                        {
                            Title = "Copy Discord Invite",
                            Icon = "copy",
                            Variant = "Primary",
                            Callback = function()
                                copyText("Discord", "https://discord.gg/x2v4z7DJxJ")
                            end,
                        },
                    },
                })
            end)
        end

        local announcement = AnnouncementTab:Section({
            Title = "Announcement",
            Icon = "megaphone",
            Box = true,
            BoxBorder = true,
            Opened = true,
        })

        announcement:Paragraph({
            Title = "Script is Now Open Source!",
            Desc = "This script is now officially completely open-source! Anyone who wants to obtain the script, receive future updates, report bugs, or contribute is welcome to join our official Discord community.\n\nOfficial Discord: https://discord.gg/x2v4z7DJxJ",
            Image = "sparkles",
            ImageSize = 46,
            Buttons = {
                {
                    Title = "Okay",
                    Icon = "check",
                    Variant = "Secondary",
                    Callback = function()
                        Notify("Announcement", "Thank you for using our open-source script!", "check", 3)
                    end,
                },
                {
                    Title = "Copy Discord Invite",
                    Icon = "copy",
                    Variant = "Primary",
                    Callback = function()
                        copyText("Discord", "https://discord.gg/x2v4z7DJxJ")
                    end,
                },
            },
        })

        announcement:Button({
            Title = "Show Announcement Popup",
            Desc = "Re-open the announcement popup dialog",
            Icon = "bell",
            Callback = showAnnouncementPopup,
        })

        local community = DiscordTab:Section({
            Title = "Discord Community",
            Icon = "messages-square",
            Box = true,
            BoxBorder = true,
            Opened = true,
        })

        community:Paragraph({
            Title = "Official Discord Server",
            Desc = "Join our official community server for script updates, announcements, and support!\n\nOfficial Discord: https://discord.gg/x2v4z7DJxJ",
            Image = "messages-square",
            ImageSize = 46,
            Buttons = {
                {
                    Title = "Copy Discord Invite",
                    Icon = "copy",
                    Variant = "Primary",
                    Callback = function()
                        copyText("Discord", "https://discord.gg/x2v4z7DJxJ")
                    end,
                },
            },
        })

        task.spawn(function()
            task.wait(1.5)
            showAnnouncementPopup()
        end)
    end

    BuildModernHomeTabs()

    _G.LastPlantPos = nil
    _G.LastPlantIdx = 0

    SettingsTab:Divider()
    local BGSection = SettingsTab:Section({
        Title = "Background Select",
        Icon = "palette",
        Box = true,
        TextXAlignment = "Center",
        TextSize = 20,
        Opened = true,
    })

    BGSection:Dropdown({
        Title = "Select Theme",
        Values = themeValues,
        Value = SelectedTheme,
        Callback = function(option)
            SelectedTheme = option
            _G.ThemeSelect = option
        end,
    })

    BGSection:Button({
        Title = "Apply Theme",
        Locked = false,
        Callback = function()
            if _G.ThemeSelect then
                ApplyTheme(_G.ThemeSelect)
                Notify("Theme Applied", "Now using theme: " .. _G.ThemeSelect, "check", 2)
            else
                Notify("Error", "No theme selected!", "triangle-alert", 2)
            end
        end,
    })

    getgenv().BVaildSelect = {
        ["No Background"] = "rbxassetid://0",
        ["Furina"] = "rbxassetid://80115246253301",
        ["Furina1"] = "rbxassetid://84672393253807",
        ["Furina2"] = "rbxassetid://133222171266319",
    }

    local firstRun = true
    BGSection:Dropdown({
        Title = "Select Background",
        Values = { "No Background", "Furina", "Furina1", "Furina2" },
        Value = "No Background",
        Callback = function(option)
            if firstRun then
                firstRun = false; return
            end
            local background = getgenv().BVaildSelect[option]
            if background then
                ApplyBackgroundImage(background)
            end
        end,
    })

    SettingsTab:Divider()
    local CustomBGSection = SettingsTab:Section({
        Title = "Custom Background",
        Icon = "image",
        Box = true,
        TextXAlignment = "Center",
        TextSize = 20,
        Opened = true,
    })

    CustomBGSection:Input({
        Title = "Background ID / URL",
        Type = "Input",
        Placeholder = "135163165559760 or https://example.com/image.png",
        Callback = function(input)
            if input ~= "" then
                task.spawn(function()
                    ApplyBackgroundImage(input)
                end)
            end
        end,
    })

    SettingsTab:Divider()
    local MinimizeSection = SettingsTab:Section({
        Title = "Minimize GUI",
        Icon = "lucide:keyboard",
        Box = true,
        TextXAlignment = "Center",
        TextSize = 20,
        Opened = true,
    })

    MinimizeSection:Keybind({
        Title = "Minimize Gui Keybind",
        Value = "G",
        Callback = function(v)
            Window:SetToggleKey(Enum.KeyCode[v])
        end,
    })

    ScriptEnv.SAE_AutoStealDebug = false
    ScriptEnv.SAE_InstantStealDebug = false

    local function BuildModernSettings()
        local validConfigName = CfgSystem.validConfigName
        local SaveConfigSnapshot = CfgSystem.SaveConfigSnapshot
        local RestoreConfigSnapshot = CfgSystem.RestoreConfigSnapshot
        local GetConfigFilePath = CfgSystem.GetConfigFilePath
        local SaveAutoLoadState = CfgSystem.SaveAutoLoadState
        local SaveAutoSaveState = CfgSystem.SaveAutoSaveState
        local SaveAutoSnapshot = CfgSystem.SaveAutoSnapshot
        local autoLoadState = CfgSystem.autoLoadState
        local autoSaveEnabled = CfgSystem.autoSaveEnabled

        local selectedConfigName = tostring(autoLoadState.name or "")
        local typedConfigName = ""
        local configDropdown
        local autoLoadToggle
        local autoSaveToggle

        local function getConfigNames()
            local folder = DATA_FOLDER .. "/config"
            if not isfolder or not isfolder(folder) then return {} end
            local ok, files = pcall(listfiles, folder)
            if not ok or type(files) ~= "table" then return {} end
            local filtered = {}
            for _, path in ipairs(files) do
                local name = path:match("([^\\/]+)%.json$")
                if name and name ~= AUTOSAVE_CONFIG_NAME then table.insert(filtered, name) end
            end
            table.sort(filtered)
            return filtered
        end

        local function refreshConfigDropdown()
            if not configDropdown then return end
            local names = getConfigNames()
            if #names == 0 then names = { "-- no configs --" } end
            configDropdown:Refresh(names)
        end

        local ConfigSection = SettingsTab:Section({
            Title = "Config",
            Icon = "database",
            Box = true,
            BoxBorder = true,
            Opened = true,
        })

        if not writefile or not readfile then
            ConfigSection:Paragraph({
                Title = "Config unavailable",
                Desc = "Your executor does not provide file APIs.",
                Image = "triangle-alert",
                ImageSize = 34,
            })
        else
            ConfigSection:Input({
                Title = "Config Name",
                Placeholder = "Type config name...",
                Callback = function(value)
                    typedConfigName = tostring(value or "")
                end,
            })

            ConfigSection:Button({
                Title = "Create Config",
                Icon = "file-plus-2",
                Callback = function()
                    local name = validConfigName(typedConfigName)
                    if not name then
                        Notify("Config", "Enter a valid config name first", "triangle-alert", 3)
                        return
                    end
                    SaveConfigSnapshot(GetConfigFilePath(name))
                    selectedConfigName = name
                    if autoLoadState.enabled then SaveAutoLoadState(true, name) end
                    refreshConfigDropdown()
                    Notify("Config", "Created: " .. name, "check", 3)
                end,
            })

            local initialConfigs = getConfigNames()
            if #initialConfigs == 0 then initialConfigs = { "-- no configs --" } end
            configDropdown = ConfigSection:Dropdown({
                Title = "Select Config",
                Values = initialConfigs,
                Value = initialConfigs[1],
                Callback = function(value)
                    local selected = type(value) == "table" and value[1] or value
                    if selected and selected ~= "-- no configs --" then
                        selectedConfigName = selected
                        if autoLoadState.enabled then SaveAutoLoadState(true, selected) end
                    end
                end,
            })

            autoLoadToggle = ConfigSection:Toggle({
                Title = "Auto Load Config",
                Value = autoLoadState.enabled == true,
                Callback = function(value)
                    local enabled = value == true
                    local name = validConfigName(selectedConfigName)
                    if enabled and not name then
                        SaveAutoLoadState(false, "")
                        task.defer(function() autoLoadToggle:Set(false) end)
                        Notify("Config", "Select config before enabling auto load", "triangle-alert", 3)
                        return
                    end
                    SaveAutoLoadState(enabled, name or "")
                    Notify("Config", enabled and ("Auto load set: " .. name) or "Auto load disabled", "check", 2)
                end,
            })

            autoSaveToggle = ConfigSection:Toggle({
                Title = "Auto Save Config",
                Value = autoSaveEnabled,
                Callback = function(value)
                    CfgSystem.autoSaveEnabled = value == true
                    autoSaveEnabled = CfgSystem.autoSaveEnabled
                    SaveAutoSaveState()
                    if autoSaveEnabled then SaveAutoSnapshot() end
                    Notify("Config", autoSaveEnabled and "Auto save enabled" or "Auto save disabled", "check", 2)
                end,
            })

            ConfigSection:Button({
                Title = "Load Config",
                Icon = "download",
                Callback = function()
                    local name = validConfigName(selectedConfigName)
                    if not name then
                        Notify("Config", "Select config first", "triangle-alert", 3)
                        return
                    end
                    local ok = RestoreConfigSnapshot(GetConfigFilePath(name))
                    Notify("Config", ok and ("Loaded: " .. name) or "Load failed", ok and "check" or "triangle-alert", 3)
                end,
            })

            ConfigSection:Button({
                Title = "Overwrite Config",
                Icon = "save",
                Callback = function()
                    local name = validConfigName(selectedConfigName)
                    if not name then
                        Notify("Config", "Select config first", "triangle-alert", 3)
                        return
                    end
                    SaveConfigSnapshot(GetConfigFilePath(name))
                    Notify("Config", "Overwritten: " .. name, "check", 3)
                end,
            })

            ConfigSection:Button({
                Title = "Delete Config",
                Icon = "trash-2",
                Callback = function()
                    local name = validConfigName(selectedConfigName)
                    if not name then
                        Notify("Config", "Select config first", "triangle-alert", 3)
                        return
                    end
                    local p = GetConfigFilePath(name)
                    if isfile and isfile(p) then pcall(delfile, p) end
                    if autoLoadState.name == name then
                        SaveAutoLoadState(false, "")
                        if autoLoadToggle then autoLoadToggle:Set(false) end
                    end
                    selectedConfigName = ""
                    refreshConfigDropdown()
                    Notify("Config", "Deleted: " .. name, "check", 3)
                end,
            })

            ConfigSection:Button({
                Title = "Refresh Config List",
                Icon = "refresh-cw",
                Callback = function()
                    refreshConfigDropdown()
                    Notify("Config", "Config list refreshed", "check", 2)
                end,
            })
        end

        SettingsTab:Space()
        local InterfaceSection = TrackConfigSection(SettingsTab:Section({
            Title = "Interface",
            Icon = "panel-top",
            Box = true,
            BoxBorder = true,
            Opened = true,
        }), "Settings_Interface")

        InterfaceSection:Keybind({
            Title = "Toggle UI Key",
            Flag = "Settings_UIToggleKey",
            Value = "RightShift",
            Callback = function(value)
                local keyName = typeof(value) == "EnumItem" and value.Name or tostring(value or "")
                local keyCode = Enum.KeyCode[keyName]
                if keyCode then Window:SetToggleKey(keyCode) end
            end,
        })

        InterfaceSection:Slider({
            Title = "UI Scale",
            Desc = "Default: 0.9",
            Flag = "Settings_UIScale09",
            Value = { Min = 0.65, Max = 1.15, Default = defaultUIScale },
            Step = 0.05,
            Callback = function(value)
                Window:SetUIScale(math.clamp(tonumber(value) or defaultUIScale, 0.65, 1.15))
            end,
        })

        InterfaceSection:Toggle({
            Title = "Notifications",
            Flag = "Settings_Notifications",
            Value = true,
            Callback = function(value)
                notificationsEnabled = value == true
            end,
        })

        InterfaceSection:Button({
            Title = "Center Window",
            Icon = "scan",
            Callback = function()
                Window:SetToTheCenter()
                Notify("Interface", "Window moved to the center", "check", 2)
            end,
        })

        SettingsTab:Space()
        local DebugSection = SettingsTab:Section({
            Title = "Debug",
            Icon = "bug",
            Box = true,
            BoxBorder = true,
            Opened = true,
        })

        DebugSection:Toggle({
            Title = "Debug Auto Steal",
            Value = false,
            Callback = function(value)
                ScriptEnv.SAE_AutoStealDebug = value == true
                local engine = ScriptEnv.SAE_AutoSteal
                if engine and type(engine.SetDebugVisible) == "function" then
                    engine.SetDebugVisible(ScriptEnv.SAE_AutoStealDebug)
                end
            end,
        })

        local instantStealCard = DebugSection:Paragraph({
            Title = "Instant Steal idle",
            Desc = "Attempts <b>0</b> - Stolen <b>0</b> - Failed <b>0</b> - Window <b>0.00s</b>",
            Image = "zap",
            ImageSize = 34,
        })
        ScriptEnv.SAE_InstantStealCard = instantStealCard
        local function setInstantStealDebugVisible(value)
            ScriptEnv.SAE_InstantStealDebug = value == true
            if instantStealCard.ElementFrame then
                instantStealCard.ElementFrame.Visible = ScriptEnv.SAE_InstantStealDebug
            end
        end
        ScriptEnv.SAE_SetInstantStealDebugVisible = setInstantStealDebugVisible
        setInstantStealDebugVisible(false)

        DebugSection:Toggle({
            Title = "Debug Instant Steal",
            Value = false,
            Callback = function(value) setInstantStealDebugVisible(value) end,
        })

        task.spawn(function()
            while ScriptEnv.SAE_RunToken == entryToken do
                task.wait(0.5)
                if ScriptEnv.SAE_InstantStealDebug then
                    pcall(function()
                        local engine = ScriptEnv.SAE_AutoSteal
                        if type(engine) ~= "table" then return end
                        instantStealCard:SetTitle(engine.TpStealEnabled
                            and (engine.TpStatus or "Instant steal running") or "Instant Steal idle")
                        instantStealCard:SetDesc(string.format(
                            "Attempts <b>%d</b> - Stolen <b>%d</b> - Failed <b>%d</b> - Window <b>%.2fs</b>",
                            engine.TpAttempts or 0, engine.TpSteals or 0,
                            engine.TpFails or 0, engine.TpWindow or 0
                        ))
                    end)
                end
            end
        end)

        SettingsTab:Space()
        local AppearanceSection = TrackConfigSection(SettingsTab:Section({
            Title = "Appearance",
            Icon = "palette",
            Box = true,
            BoxBorder = true,
            Opened = true,
        }), "Settings_Appearance")

        local themeNames = {}
        for name in pairs(WindUI:GetThemes()) do table.insert(themeNames, name) end
        table.sort(themeNames)

        AppearanceSection:Dropdown({
            Title = "Select Theme",
            Flag = "Settings_SelectedTheme",
            Values = themeNames,
            Value = SelectedTheme,
            Callback = function(value)
                SelectedTheme = type(value) == "table" and value[1] or value
            end,
        })

        AppearanceSection:Button({
            Title = "Apply Theme",
            Callback = function()
                if SelectedTheme then
                    WindUI:SetTheme(SelectedTheme)
                    SaveWindowPrefs()
                    Notify("Theme Applied", "Now using theme: " .. SelectedTheme, "check", 2)
                end
            end,
        })

        local backgroundInput = AppearanceSection:Input({
            Title = "Background ID / URL",
            Flag = "Settings_BackgroundImage",
            Value = SelectedBackgroundImage,
            Placeholder = "Asset ID or https:// image URL",
            Callback = function(value)
                local background = ResolveBackgroundImage(value)
                if background then
                    SelectedBackgroundImage = background
                    Window:SetBackgroundImage(background)
                    SaveWindowPrefs()
                end
            end,
        })

        AppearanceSection:Slider({
            Title = "Background Transparency",
            Desc = "0 is solid and 1 is fully transparent",
            Flag = "Settings_BackgroundTransparency",
            Value = { Min = 0, Max = 1, Default = SelectedBackgroundTransparency },
            Step = 0.1,
            Callback = function(value)
                SelectedBackgroundTransparency = math.clamp(tonumber(value) or 0.6, 0, 1)
                Window:SetBackgroundImageTransparency(SelectedBackgroundTransparency)
                SaveWindowPrefs()
            end,
        })

        AppearanceSection:Button({
            Title = "Restore Default Background",
            Icon = "rotate-ccw",
            Callback = function()
                SelectedBackgroundImage = DEFAULT_BACKGROUND
                Window:SetBackgroundImage(DEFAULT_BACKGROUND)
                backgroundInput:Set(DEFAULT_BACKGROUND)
                SaveWindowPrefs()
                Notify("Appearance", "Default background restored", "check", 2)
            end,
        })

        SettingsTab:Space()
        SettingsTab:Section({
            Title = "About",
            Icon = "circle-help",
            Box = true,
            Opened = true,
        }):Paragraph({
            Title = "Steal An Egg",
            Desc = "Modern WindUI build\nConfigs: WindUI/StealAnEgg/config\nPreferences: StealAnEgg_Prefs/WindowPrefs.json",
            Image = "info",
            ImageSize = 34,
        })
    end

    BuildModernSettings()

    local WebhookSystem = {
        Url = "",
        NotifyEvents = false,
        NotifyEggSpawn = false,
        NotifySteal = false,
        NotifyStats = false,
        SpawnRarities = {
            Divine = true,
            Eternal = true,
            Secret = true,
            Cosmic = true,
            Mythic = false,
            Legendary = false,
        },
        Closed = false,
        Queue = {},
        Processing = false,
        LastEventStates = {},
        SeenSpawnUids = {},
        SpawnMonitorInit = false,
    }

    local function formatEarning(num)
        num = tonumber(num) or 0
        if num >= 1e12 then
            return string.format("%.2fT/s", num / 1e12)
        elseif num >= 1e9 then
            return string.format("%.2fB/s", num / 1e9)
        elseif num >= 1e6 then
            return string.format("%.2fM/s", num / 1e6)
        elseif num >= 1e3 then
            return string.format("%.2fK/s", num / 1e3)
        else
            return string.format("%d/s", math.floor(num))
        end
    end

    local function getRarityColorHex(rarity)
        local colors = {
            Divine = 0xFFD700,
            Eternal = 0x00FFFF,
            Secret = 0xFF00FF,
            Cosmic = 0x9933FF,
            Mythic = 0xFF3333,
            Legendary = 0xFFA500,
            Epic = 0x9900FF,
            Rare = 0x0099FF,
            Uncommon = 0x00FF00,
            Common = 0xAAAAAA,
        }
        return colors[tostring(rarity)] or 0x176BE8
    end

    local function processWebhookQueue()
        if WebhookSystem.Processing then return end
        WebhookSystem.Processing = true
        task.spawn(function()
            while #WebhookSystem.Queue > 0 and not WebhookSystem.Closed do
                local item = table.remove(WebhookSystem.Queue, 1)
                if item and item.Url and item.Payload and http then
                    pcall(function()
                        local jsonBody = HttpService:JSONEncode(item.Payload)
                        http({
                            Url = item.Url,
                            Method = "POST",
                            Headers = {
                                ["Content-Type"] = "application/json"
                            },
                            Body = jsonBody,
                        })
                    end)
                end
                task.wait(1.5)
            end
            WebhookSystem.Processing = false
        end)
    end

    local function sendDiscordEmbed(title, description, color, fields)
        local url = WebhookSystem.Url
        if type(url) ~= "string" or not url:find("^https?://") then return false end
        while #WebhookSystem.Queue >= 15 do
            table.remove(WebhookSystem.Queue, 1)
        end
        local payload = {
            username = "Steal An Egg",
            avatar_url = "https://i.imgur.com/8Q5FqgM.png",
            embeds = {
                {
                    title = title,
                    description = description,
                    color = color or 0x176BE8,
                    fields = fields or {},
                    footer = {
                        text = "Steal An Egg"
                    },
                    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
                }
            }
        }
        table.insert(WebhookSystem.Queue, { Url = url, Payload = payload })
        processWebhookQueue()
        return true
    end

    function WebhookSystem.SendTest()
        if type(WebhookSystem.Url) ~= "string" or not WebhookSystem.Url:find("^https?://") then
            Notify("Webhook", "Please enter a valid Webhook URL first!", "triangle-alert", 3)
            return false
        end
        local ok = sendDiscordEmbed(
            "✅ Steal An Egg - Webhook Connected!",
            "Discord Webhook notifications are now active and operational.",
            0x00FF88,
            {
                { name = "Game", value = "Steal An Egg", inline = true },
                { name = "Status", value = "Operational", inline = true },
            }
        )
        if ok then
            Notify("Webhook", "Test message sent to Discord!", "check", 3)
        end
        return ok
    end

    local function formatBig(num)
        num = tonumber(num) or 0
        if num >= 1e15 then
            return string.format("%.2fQ", num / 1e15)
        elseif num >= 1e12 then
            return string.format("%.2fT", num / 1e12)
        elseif num >= 1e9 then
            return string.format("%.2fB", num / 1e9)
        elseif num >= 1e6 then
            return string.format("%.2fM", num / 1e6)
        elseif num >= 1e3 then
            return string.format("%.2fK", num / 1e3)
        end
        return string.format("%d", math.floor(num + 0.5))
    end

    function WebhookSystem.SendStats()
        if type(WebhookSystem.Url) ~= "string" or not WebhookSystem.Url:find("^https?://") then
            return false
        end
        local okSave, Save = pcall(require, ReplicatedStorage.Shared.Save)
        local data = okSave and type(Save) == "table" and (Save.Get or Save.Peek)() or nil
        if type(data) ~= "table" then return false end

        local petCount, eggCount, totalKg = 0, 0, 0
        local okAssets, Assets = pcall(function() return require(ReplicatedStorage.Data.Assets).Directory end)
        local directory = okAssets and type(Assets) == "table" and Assets or {}
        if type(data.Inventory) == "table" then
            for _, pet in pairs(data.Inventory) do
                if type(pet) == "table" then
                    petCount += 1
                    local asset = directory[tostring(pet.Category)]
                    totalKg += asset and tonumber(asset.ModelWeight) or 0
                end
            end
        end
        if type(data.EggInventory) == "table" then
            for _, egg in pairs(data.EggInventory) do
                if type(egg) == "table" then
                    eggCount += 1
                    local asset = directory[tostring(egg.AssetCategory)]
                    totalKg += asset and tonumber(asset.ModelWeight) or 0
                end
            end
        end
        local indexUnlocked = 0
        if type(data.Index) == "table" then
            for _ in pairs(data.Index) do indexUnlocked += 1 end
        end

        local incomePerSec, speed = 0, 0
        local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
        if leaderstats then
            local incomeStat = leaderstats:FindFirstChild("Money/s")
            if incomeStat then incomePerSec = tonumber(incomeStat.Value) or 0 end
            local speedStat = leaderstats:FindFirstChild("Speed")
            if speedStat then speed = tonumber(speedStat.Value) or 0 end
        end

        local area = tostring(LocalPlayer:GetAttribute("AreaId") or "Unknown")
        local uptimeMins = 0
        local joinTick = tonumber(LocalPlayer:GetAttribute("JoinTick"))
        if joinTick then uptimeMins = math.max(0, (os.time() - joinTick) / 60) end

        return sendDiscordEmbed(
            "📊 Account Stats Snapshot",
            "Live account snapshot auto-reported.",
            0x176BE8,
            {
                { name = "Money", value = "$" .. formatBig(data.Money), inline = true },
                { name = "Income", value = "$" .. formatEarning(incomePerSec), inline = true },
                { name = "Speed", value = formatBig(speed), inline = true },
                { name = "Est. / Hour", value = "$" .. formatBig(incomePerSec * 3600), inline = true },
                { name = "Est. / Day", value = "$" .. formatBig(incomePerSec * 86400), inline = true },
                { name = "Total Weight", value = formatBig(totalKg) .. " Kg", inline = true },
                { name = "Pets Owned", value = tostring(petCount), inline = true },
                { name = "Eggs in Bag", value = tostring(eggCount), inline = true },
                { name = "Index Unlocked", value = tostring(indexUnlocked), inline = true },
                { name = "Current Area", value = area, inline = true },
                { name = "Session Uptime", value = string.format("%d min", uptimeMins), inline = true },
                { name = "Server Job ID", value = string.format("`%s`", tostring(game.JobId):sub(1, 16) .. "..."), inline = false }
            }
        )
    end

    local function BuildWebhookTab()
        local WebhookSection = WebhookTab:Section({
            Title = "Discord Webhook Settings",
            ConfigFlagKey = "DiscordWebhook",
            Icon = "bell",
            Box = true,
            BoxBorder = true,
            Opened = true,
        })

        WebhookSection:Input({
            Title = "Discord Webhook URL",
            Flag = "Webhook_DiscordUrl",
            Placeholder = "https://discord.com/api/webhooks/...",
            Value = WebhookSystem.Url,
            Callback = function(v)
                WebhookSystem.Url = tostring(v or ""):gsub("%s+", "")
            end,
        })

        WebhookSection:Button({
            Title = "Send Test Notification",
            Icon = "send",
            Callback = function()
                WebhookSystem.SendTest()
            end,
        })

        WebhookSection:Divider()

        WebhookSection:Toggle({
            Title = "Event Notifications",
            Flag = "Webhook_NotifyEvents",
            Value = false,
            Callback = function(v)
                WebhookSystem.NotifyEvents = v == true
            end,
        })

        WebhookSection:Toggle({
            Title = "Rare Egg Spawn Notifications",
            Flag = "Webhook_NotifyEggSpawn",
            Value = false,
            Callback = function(v)
                WebhookSystem.NotifyEggSpawn = v == true
            end,
        })

        local function toSet(val)
            local s = {}
            if type(val) == "string" then s[val] = true
            elseif type(val) == "table" then
                for k, item in pairs(val) do
                    local str = item == true and tostring(k) or (type(item) == "string" and item or nil)
                    if str and str ~= "Select All" and str ~= "All" then s[str] = true end
                end
            end
            return s
        end

        WebhookSection:Dropdown({
            Title = "Spawn Rarities to Notify",
            Flag = "Webhook_SpawnRarities",
            Values = { "Divine", "Eternal", "Secret", "Cosmic", "Mythic", "Legendary" },
            Value = { "Divine", "Eternal", "Secret", "Cosmic" },
            Multi = true,
            AllowNone = true,
            Callback = function(v)
                WebhookSystem.SpawnRarities = toSet(v)
            end,
        })

        WebhookSection:Divider()

        WebhookSection:Toggle({
            Title = "Steal & Hatch Notifications",
            Flag = "Webhook_NotifySteal",
            Value = false,
            Callback = function(v)
                WebhookSystem.NotifySteal = v == true
            end,
        })

        WebhookSection:Button({
            Title = "Send Stats Snapshot Now",
            Icon = "chart-column",
            Callback = function()
                if not WebhookSystem.SendStats() then
                    Notify("Webhook", "Please enter a valid Webhook URL first!", "triangle-alert", 3)
                end
            end,
        })

        WebhookSection:Toggle({
            Title = "Auto Stats Every 5 Minutes",
            Flag = "Webhook_NotifyStats",
            Value = false,
            Callback = function(v)
                WebhookSystem.NotifyStats = v == true
            end,
        })

        task.spawn(function()
            while not WebhookSystem.Closed and ScriptEnv.SAE_RunToken == entryToken do
                task.wait(300)
                if WebhookSystem.NotifyStats then
                    pcall(WebhookSystem.SendStats)
                end
            end
        end)

        task.spawn(function()
            while not WebhookSystem.Closed and ScriptEnv.SAE_RunToken == entryToken do
                task.wait(4)
                pcall(function()
                    if not WebhookSystem.NotifyEvents or not WebhookSystem.Url:find("^https?://") then return end

                    local scrambleActive = Workspace:GetAttribute("ScrambleOutbreakActive") == true
                    if scrambleActive ~= WebhookSystem.LastEventStates["Scramble"] then
                        WebhookSystem.LastEventStates["Scramble"] = scrambleActive
                        if scrambleActive then
                            sendDiscordEmbed(
                                "🚨 Event Active: Dr. Scramble Outbreak!",
                                "The Dr. Scramble Outbreak event is now active in Abyss Ocean! Drones are spawning.",
                                0xFF5500,
                                {
                                    { name = "Event", value = "Dr. Scramble Outbreak", inline = true },
                                    { name = "Location", value = "Abyss Ocean (Event Biome)", inline = true },
                                    { name = "Server Job ID", value = string.format("`%s`", tostring(game.JobId):sub(1, 16) .. "..."), inline = false }
                                }
                            )
                        end
                    end

                    local monsterActive = Workspace:GetAttribute("Event_AdminAbuse") == true
                    if monsterActive ~= WebhookSystem.LastEventStates["Monster"] then
                        WebhookSystem.LastEventStates["Monster"] = monsterActive
                        if monsterActive then
                            sendDiscordEmbed(
                                "👾 Event Active: Monster Event!",
                                "A Monster Event / Admin Abuse event is currently active in the server!",
                                0x00FFCC,
                                {
                                    { name = "Event", value = "Monster Event", inline = true },
                                    { name = "Server Job ID", value = string.format("`%s`", tostring(game.JobId):sub(1, 16) .. "..."), inline = false }
                                }
                            )
                        end
                    end
                end)
            end
        end)

        task.spawn(function()
            local seenUids = {}
            local initialized = false
            while not WebhookSystem.Closed and ScriptEnv.SAE_RunToken == entryToken do
                task.wait(3)
                pcall(function()
                    if not WebhookSystem.NotifyEggSpawn or not WebhookSystem.Url:find("^https?://") then
                        initialized = false
                        return
                    end

                    local EggState = require(ReplicatedStorage.Client.EggState)
                    local okSnap, snapshot = pcall(function() return EggState.ReadFieldEggs() end)
                    local records = okSnap and type(snapshot) == "table" and (snapshot.Records or snapshot) or {}
                    local currentUids = {}

                    for _, record in pairs(records) do
                        if type(record) == "table" and record.Uid and (record.State == "Slot" or record.State == "Dropped") then
                            local uid = tostring(record.Uid)
                            currentUids[uid] = true
                            if not seenUids[uid] then
                                seenUids[uid] = true
                                if initialized then
                                    local asset = require(ReplicatedStorage.Data.Assets).Directory[record.AssetCategory]
                                    local rarity = type(asset) == "table" and asset.Rarity or record.Rarity
                                    if type(rarity) == "table" then
                                        rarity = rarity._id or rarity.DisplayName or rarity.Name
                                    end
                                    rarity = tostring(rarity or "Common")

                                    if WebhookSystem.SpawnRarities[rarity] == true then
                                        local cat = tostring(record.AssetCategory or "Unknown")
                                        local area = tostring(record.AreaId or "Unknown")
                                        local earn = type(asset) == "table" and (tonumber(asset.EarningRate) or 0) or 0
                                        local color = getRarityColorHex(rarity)
                                        sendDiscordEmbed(
                                            string.format("✨ [%s] Rare Egg Spawned!", rarity),
                                            string.format("A **%s** egg (%s) has spawned on the map!", cat, rarity),
                                            color,
                                            {
                                                { name = "Pet / Category", value = cat, inline = true },
                                                { name = "Rarity", value = rarity, inline = true },
                                                { name = "Area", value = area, inline = true },
                                                { name = "Earning Rate", value = formatEarning(earn), inline = true },
                                                { name = "State", value = tostring(record.State), inline = true },
                                                { name = "Server Job ID", value = string.format("`%s`", tostring(game.JobId):sub(1, 16) .. "..."), inline = false }
                                            }
                                        )
                                    end
                                end
                            end
                        end
                    end

                    for u in pairs(seenUids) do
                        if not currentUids[u] then seenUids[u] = nil end
                    end
                    initialized = true
                end)
            end
        end)
    end

    BuildWebhookTab()

    ScriptEnv.SAE_Webhook = WebhookSystem
    ScriptEnv.SAE_WebhookCleanup = function()
        WebhookSystem.Closed = true
    end

    ScriptEnv.SAE_OnEggStolen = function(record)
        if not WebhookSystem.NotifySteal or not WebhookSystem.Url:find("^https?://") then return end
        pcall(function()
            local cat = tostring(record.AssetCategory or "Unknown")
            local area = tostring(record.AreaId or "Unknown")
            local asset = require(ReplicatedStorage.Data.Assets).Directory[record.AssetCategory]
            local rarity = type(asset) == "table" and asset.Rarity or record.Rarity
            if type(rarity) == "table" then
                rarity = rarity._id or rarity.DisplayName or rarity.Name
            end
            rarity = tostring(rarity or "Common")
            local earn = type(asset) == "table" and (tonumber(asset.EarningRate) or 0) or 0
            local color = getRarityColorHex(rarity)

            sendDiscordEmbed(
                "🥚 Egg Successfully Stolen!",
                string.format("Successfully stole a **%s** egg from **%s**!", cat, area),
                color,
                {
                    { name = "Pet Name", value = cat, inline = true },
                    { name = "Rarity", value = rarity, inline = true },
                    { name = "Area", value = area, inline = true },
                    { name = "Earning Rate", value = formatEarning(earn), inline = true },
                }
            )
        end)
    end

    ScriptEnv.SAE_OnEggHatched = function(cat, rarity, earn, isNewIndex)
        if not WebhookSystem.NotifySteal or not WebhookSystem.Url:find("^https?://") then return end
        pcall(function()
            cat = tostring(cat or "Unknown")
            rarity = tostring(rarity or "Common")
            local color = getRarityColorHex(rarity)
            local title = isNewIndex and "📖 New Index Pet Unlocked!" or "🐣 Egg Hatched!"
            local desc = isNewIndex
                and string.format("Hatched **%s** (%s) and added a new entry to your Index!", cat, rarity)
                or string.format("Hatched **%s** (%s) on plot!", cat, rarity)

            sendDiscordEmbed(
                title,
                desc,
                color,
                {
                    { name = "Pet Name", value = cat, inline = true },
                    { name = "Rarity", value = rarity, inline = true },
                    { name = "Earning Rate", value = formatEarning(earn), inline = true },
                    { name = "New Index Entry", value = isNewIndex and "✅ Yes" or "No", inline = true },
                }
            )
        end)
    end

    task.wait()

    do
        local movement = {
            TPWalkEnabled = false,
            TPWalkSpeed = 100,
            FlyEnabled = false,
            FlySpeed = 100,
            FlyVelocity = nil,
            FlyGyro = nil,
            FlyHumanoid = nil,
            PreviousPlatformStand = false,
            Closed = false,
            Input = { Forward = 0, Back = 0, Left = 0, Right = 0, Up = 0, Down = 0 },
        }

        local function automationOwnsMovement()
            local steal = ScriptEnv.SAE_AutoSteal
            return type(steal) == "table"
                and (steal.ActiveTween ~= nil or steal.Moving == true
                    or steal.CarryChaseActive == true
                    or steal.ReturningToSafe == true)
        end

        local function currentCharacter()
            local character = LocalPlayer.Character
            if not character then return nil, nil, nil end
            return character,
                character:FindFirstChild("HumanoidRootPart"),
                character:FindFirstChildOfClass("Humanoid")
        end

        local function destroyFlyBodies(restorePlatformStand)
            if movement.FlyVelocity then pcall(function() movement.FlyVelocity:Destroy() end) end
            if movement.FlyGyro then pcall(function() movement.FlyGyro:Destroy() end) end
            if restorePlatformStand and movement.FlyHumanoid and movement.FlyHumanoid.Parent then
                movement.FlyHumanoid.PlatformStand = movement.PreviousPlatformStand == true
                if not movement.FlyHumanoid.PlatformStand then
                    pcall(function() movement.FlyHumanoid:ChangeState(Enum.HumanoidStateType.Running) end)
                end
            end
            movement.FlyVelocity = nil
            movement.FlyGyro = nil
            movement.FlyHumanoid = nil
        end

        local function ensureFlyBodies(root, humanoid)
            if movement.FlyHumanoid ~= humanoid
                or not movement.FlyVelocity or movement.FlyVelocity.Parent ~= root
                or not movement.FlyGyro or movement.FlyGyro.Parent ~= root
            then
                destroyFlyBodies(true)
                movement.FlyHumanoid = humanoid
                movement.PreviousPlatformStand = humanoid.PlatformStand

                local velocity = Instance.new("BodyVelocity")
                velocity.Name = "FlyVelocity"
                velocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
                velocity.P = 1250
                velocity.Velocity = Vector3.zero
                velocity.Parent = root

                local gyro = Instance.new("BodyGyro")
                gyro.Name = "FlyGyro"
                gyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
                gyro.P = 1000
                gyro.D = 50
                gyro.CFrame = root.CFrame
                gyro.Parent = root

                movement.FlyVelocity = velocity
                movement.FlyGyro = gyro
            end
            humanoid.Sit = false
            humanoid.PlatformStand = true
            return movement.FlyVelocity, movement.FlyGyro
        end

        local function setInput(keyCode, pressed)
            local value = pressed and 1 or 0
            if keyCode == Enum.KeyCode.W then movement.Input.Forward = value
            elseif keyCode == Enum.KeyCode.S then movement.Input.Back = value
            elseif keyCode == Enum.KeyCode.A then movement.Input.Left = value
            elseif keyCode == Enum.KeyCode.D then movement.Input.Right = value
            elseif keyCode == Enum.KeyCode.Space then movement.Input.Up = value
            elseif keyCode == Enum.KeyCode.LeftControl or keyCode == Enum.KeyCode.RightControl then
                movement.Input.Down = value
            end
        end

        movement.InputBegan = UserInputService.InputBegan:Connect(function(input, processed)
            if not processed then setInput(input.KeyCode, true) end
        end)
        movement.InputEnded = UserInputService.InputEnded:Connect(function(input)
            setInput(input.KeyCode, false)
        end)

        movement.StepConnection = RunService.RenderStepped:Connect(function(deltaTime)
            if movement.Closed then return end
            local _, root, humanoid = currentCharacter()
            if not root or not humanoid then
                destroyFlyBodies(false)
                return
            end

            if automationOwnsMovement() then
                destroyFlyBodies(true)
                return
            end

            if movement.FlyEnabled then
                local velocity, gyro = ensureFlyBodies(root, humanoid)
                local camera = Workspace.CurrentCamera
                if not camera then return end
                local input = movement.Input
                local forward = input.Forward - input.Back
                local sideways = input.Right - input.Left
                local vertical = input.Up - input.Down
                local direction = camera.CFrame.LookVector * forward
                    + camera.CFrame.RightVector * sideways
                    + Vector3.yAxis * vertical
                velocity.Velocity = direction.Magnitude > 0
                    and direction.Unit * movement.FlySpeed or Vector3.zero
                gyro.CFrame = CFrame.lookAt(root.Position, root.Position + camera.CFrame.LookVector)
                return
            end

            destroyFlyBodies(true)
            if not movement.TPWalkEnabled then return end
            local direction = humanoid.MoveDirection
            if direction.Magnitude <= 0.001 then return end
            direction = Vector3.new(direction.X, 0, direction.Z)
            if direction.Magnitude <= 0.001 then return end
            local stepSeconds = math.min(math.max(tonumber(deltaTime) or 0, 0), 0.05)
            local displacement = direction.Unit * movement.TPWalkSpeed * stepSeconds
            root.CFrame = root.CFrame + displacement
            root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
        end)

        function movement.SetTPWalk(value)
            movement.TPWalkEnabled = value == true
        end

        function movement.SetFly(value)
            movement.FlyEnabled = value == true
            if not movement.FlyEnabled then destroyFlyBodies(true) end
        end

        ScriptEnv.SAE_LocalMovement = movement
        ScriptEnv.SAE_LocalMovementCleanup = function()
            movement.Closed = true
            movement.TPWalkEnabled = false
            movement.FlyEnabled = false
            destroyFlyBodies(true)
            if movement.InputBegan then movement.InputBegan:Disconnect() end
            if movement.InputEnded then movement.InputEnded:Disconnect() end
            if movement.StepConnection then movement.StepConnection:Disconnect() end
            if movement.PromptHoldBegan then movement.PromptHoldBegan:Disconnect() end
            if ScriptEnv.SAE_LocalMovement == movement then ScriptEnv.SAE_LocalMovement = nil end
        end

        local movementSection = LocalPlayerTab:Section({
            Title = "Movement",
            ConfigFlagKey = "Movement",
            Icon = "move-3d",
            Box = true,
            BoxBorder = true,
            Opened = true,
        })

        movementSection:Slider({
            Title = "Speed",
            Flag = "Local_TPWalkSpeed",
            Step = 1,
            Value = { Min = 1, Max = 800, Default = 100 },
            Callback = function(value)
                movement.TPWalkSpeed = math.clamp(tonumber(value) or 100, 1, 800)
            end,
        })

        movementSection:Toggle({
            Title = "TPWalk",
            Flag = "Local_TPWalkEnabled",
            Value = false,
            Callback = function(value) movement.SetTPWalk(value) end,
        })

        movementSection:Divider()
        movementSection:Slider({
            Title = "Fly Speed",
            Flag = "Local_FlySpeed",
            Step = 1,
            Value = { Min = 30, Max = 500, Default = 100 },
            Callback = function(value)
                movement.FlySpeed = math.clamp(tonumber(value) or 100, 30, 500)
            end,
        })

        movementSection:Toggle({
            Title = "Fly",
            Flag = "Local_FlyEnabled",
            Value = false,
            Callback = function(value) movement.SetFly(value) end,
        })

        movementSection:Divider()
        movementSection:Toggle({
            Title = "Instant Proximity Prompt",
            Flag = "Local_InstantPrompt",
            Value = false,
            Callback = function(value)
                if movement.PromptHoldBegan then
                    movement.PromptHoldBegan:Disconnect()
                    movement.PromptHoldBegan = nil
                end
                if value and type(fireproximityprompt) == "function" then
                    movement.PromptHoldBegan = ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
                        fireproximityprompt(prompt)
                    end)
                end
            end,
        })
    end

    do
        local esp = {
            EggEnabled = false,
            MyEggEnabled = false,
            PlayersEnabled = false,
            SelectedRarities = {},
            Closed = false,
            Entries = {},
            LastSyncAt = 0,
            LastOwnedSyncAt = 0,
            FieldSyncBusy = false,
            OwnedSyncBusy = false,
            UpdateInterval = 0.15,
        }
        local eggState, plotState, eggRecords, assetDirectory, rarityDirectory
        esp.Ready = pcall(function()
            local client = ReplicatedStorage:FindFirstChild("Client") or ReplicatedStorage:WaitForChild("Client", 1)
            local data = ReplicatedStorage:FindFirstChild("Data") or ReplicatedStorage:WaitForChild("Data", 1)
            local shared = ReplicatedStorage:FindFirstChild("Shared") or ReplicatedStorage:WaitForChild("Shared", 1)
            local function safeReq(inst)
                if inst and inst:IsA("ModuleScript") then
                    local ok, m = pcall(require, inst)
                    return ok and m or nil
                end
                return nil
            end
            eggState = safeReq(client and client:FindFirstChild("EggState"))
            plotState = safeReq(client and client:FindFirstChild("PlotState"))
            local sharedUtil = shared and shared:FindFirstChild("Util")
            eggRecords = safeReq(sharedUtil and sharedUtil:FindFirstChild("EggRecords"))
            local assetMod = safeReq(data and data:FindFirstChild("Assets"))
            assetDirectory = assetMod and assetMod.Directory
            local rarityData = safeReq(data and data:FindFirstChild("Rarity"))
            rarityDirectory = rarityData and (rarityData.Rarities or rarityData) or {}
        end)

        local folder = Instance.new("Folder")
        folder.Name = "StealAnEggESP"
        folder.Parent = Workspace
        esp.Folder = folder

        local fallbackRarityColors = {
            Common = Color3.fromRGB(151, 151, 151),
            Uncommon = Color3.fromRGB(0, 255, 0),
            Rare = Color3.fromRGB(25, 144, 255),
            Epic = Color3.fromRGB(196, 2, 255),
            Legendary = Color3.fromRGB(255, 133, 34),
            Mythic = Color3.fromRGB(255, 43, 100),
            Cosmic = Color3.fromRGB(65, 0, 170),
            Secret = Color3.fromRGB(46, 46, 46),
            Eternal = Color3.fromRGB(255, 30, 240),
            Divine = Color3.fromRGB(251, 255, 0),
        }

        local function localRoot()
            local character = LocalPlayer.Character
            return character and character:FindFirstChild("HumanoidRootPart")
        end

        local function formatNumber(value)
            value = tonumber(value) or 0
            local absolute = math.abs(value)
            local suffixes = {
                { 1e18, "Qi" }, { 1e15, "Qa" }, { 1e12, "T" },
                { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" },
            }
            for _, suffix in ipairs(suffixes) do
                if absolute >= suffix[1] then
                    local scaled = value / suffix[1]
                    if scaled >= 100 then return string.format("%.0f%s", scaled, suffix[2]) end
                    local formatted = scaled >= 10 and string.format("%.1f", scaled)
                        or string.format("%.2f", scaled)
                    formatted = formatted:gsub("(%..-)0+$", "%1"):gsub("%.$", "")
                    return formatted .. suffix[2]
                end
            end
            return string.format("%.0f", value)
        end

        local function formatDuration(value)
            local seconds = math.max(0, math.ceil(tonumber(value) or 0))
            local days = math.floor(seconds / 86400)
            local hours = math.floor(seconds % 86400 / 3600)
            local minutes = math.floor(seconds % 3600 / 60)
            local remainder = seconds % 60
            if days > 0 then return string.format("%dd %02dh %02dm", days, hours, minutes) end
            if hours > 0 then return string.format("%dh %02dm %02ds", hours, minutes, remainder) end
            return string.format("%dm %02ds", minutes, remainder)
        end

        local function getAsset(record)
            return type(assetDirectory) == "table" and assetDirectory[record.AssetCategory] or nil
        end

        local function getRarity(record, asset)
            local rarity = type(asset) == "table" and asset.Rarity or record.Rarity
            if type(rarity) == "table" then
                rarity = rarity._id or rarity.DisplayName or rarity.Name
            end
            return tostring(rarity or "Common")
        end

        local function getRarityColor(rarity)
            local config = type(rarityDirectory) == "table" and rarityDirectory[rarity] or nil
            local color = type(config) == "table" and config.Color or nil
            return typeof(color) == "Color3" and color
                or fallbackRarityColors[rarity]
                or Color3.fromRGB(235, 235, 235)
        end

        local function getEggName(record)
            if eggRecords then
                local ok, name = pcall(eggRecords.DisplayName, record)
                if ok and type(name) == "string" then return name end
            end
            return "Egg"
        end

        local function raritySelected(rarity)
            if not esp.SelectedRarities or next(esp.SelectedRarities) == nil then
                return true
            end
            return esp.SelectedRarities[tostring(rarity)] == true
        end

        local function hatchRemaining(uid, record)
            local okReady, ready = pcall(eggState.IsReadyToHatch, uid)
            if okReady and ready == true then return 0, true end
            local now = Workspace:GetServerTimeNow()
            local multiplier = math.max(tonumber(record.GrowthSpeedMultiplier) or 1, 0.001)
            local nightCredit = 0
            local okNight, currentNightCredit = pcall(
                eggRecords.CurrentNightCredit, record, now, multiplier
            )
            if okNight then nightCredit = tonumber(currentNightCredit) or 0 end
            local okRemaining, remaining = pcall(
                eggRecords.WallSecondsRemaining, record, now, multiplier, nightCredit
            )
            return okRemaining and math.max(0, tonumber(remaining) or 0) or 0, false
        end

        local function ensureEntry(key, highlightAdornee)
            local entry = esp.Entries[key]
            if not entry then
                local anchor = Instance.new("Part")
                anchor.Name = "ESPAnchor"
                anchor.Anchored = true
                anchor.CanCollide = false
                anchor.CanQuery = false
                anchor.CanTouch = false
                anchor.CastShadow = false
                anchor.Transparency = 1
                anchor.Size = Vector3.new(0.1, 0.1, 0.1)
                anchor.Parent = folder

                local billboard = Instance.new("BillboardGui")
                billboard.Name = "ESPLabel"
                billboard.Adornee = anchor
                billboard.AlwaysOnTop = true
                billboard.MaxDistance = 100000
                billboard.Size = UDim2.fromOffset(320, 96)
                billboard.StudsOffset = Vector3.new(0, 2.7, 0)
                billboard.Parent = anchor

                local label = Instance.new("TextLabel")
                label.Name = "Text"
                label.BackgroundTransparency = 1
                label.Size = UDim2.fromScale(1, 1)
                label.Font = Enum.Font.GothamBold
                label.TextSize = 13
                label.TextStrokeColor3 = Color3.new(0, 0, 0)
                label.TextStrokeTransparency = 0.15
                label.TextWrapped = false
                label.TextYAlignment = Enum.TextYAlignment.Center
                label.Parent = billboard

                entry = { Anchor = anchor, Billboard = billboard, Label = label }
                esp.Entries[key] = entry
            end

            if highlightAdornee and highlightAdornee.Parent then
                if not entry.Highlight then
                    local highlight = Instance.new("Highlight")
                    highlight.Name = "ESPHighlight"
                    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    highlight.FillTransparency = 0.75
                    highlight.OutlineTransparency = 0
                    highlight.Parent = folder
                    entry.Highlight = highlight
                end
                entry.Highlight.Adornee = highlightAdornee
            elseif entry.Highlight then
                entry.Highlight:Destroy()
                entry.Highlight = nil
            end
            return entry
        end

        local function releaseEntry(key)
            local entry = esp.Entries[key]
            if not entry then return end
            if entry.Highlight then entry.Highlight:Destroy() end
            if entry.Anchor then entry.Anchor:Destroy() end
            esp.Entries[key] = nil
        end

        local function releasePrefix(prefix)
            local keys = {}
            for key in pairs(esp.Entries) do
                if key:sub(1, #prefix) == prefix then table.insert(keys, key) end
            end
            for _, key in ipairs(keys) do releaseEntry(key) end
        end

        local function drawEntry(key, position, text, color, highlightAdornee)
            LPH_ATTRIBUTES(PRESET(FAST), ERROR_HANDLING(false))
            local entry = ensureEntry(key, highlightAdornee)
            entry.Anchor.CFrame = CFrame.new(position)
            entry.Label.Text = text
            entry.Label.TextColor3 = color
            if entry.Highlight then
                entry.Highlight.FillColor = color
                entry.Highlight.OutlineColor = color
            end
            return entry
        end

        local function updateEggEsp(active)
            LPH_ATTRIBUTES(PRESET(FAST), ERROR_HANDLING(false))
            if not esp.EggEnabled or not esp.Ready then return end
            if os.clock() - esp.LastSyncAt >= 1 and not esp.FieldSyncBusy then
                esp.LastSyncAt = os.clock()
                esp.FieldSyncBusy = true
                task.spawn(function()
                    pcall(eggState.SyncFieldEggs)
                    esp.FieldSyncBusy = false
                end)
            end
            local ok, snapshot = pcall(eggState.ReadFieldEggs)
            if not ok or type(snapshot) ~= "table" then return end
            local records = type(snapshot.Records) == "table" and snapshot.Records or snapshot
            local root = localRoot()
            local slotFolder = Workspace:FindFirstChild("AreaEggSlotsClient")
            for _, record in pairs(records) do
                local eggCFrame = type(record) == "table" and (record.BoundsCFrame or record.BottomCFrame)
                if type(record) == "table" and type(record.Uid) == "string"
                    and (record.State == "Slot" or record.State == "Dropped")
                    and typeof(eggCFrame) == "CFrame"
                    and (record.State == "Dropped" or slotFolder == nil or slotFolder:FindFirstChild(record.Uid) ~= nil)
                then
                    local asset = getAsset(record)
                    local rarity = getRarity(record, asset)
                    if raritySelected(rarity) then
                        local petName = type(asset) == "table" and asset.DisplayName or nil
                        petName = tostring(petName or record.AssetCategory or "Unknown")
                        local earningRate = type(asset) == "table" and tonumber(asset.EarningRate) or 0
                        local distance = root and (root.Position - eggCFrame.Position).Magnitude or 0
                        local text = string.format(
                            "Egg: %s\nPet: %s | Rarity: %s\n$%s/s | Distance: %d studs",
                            getEggName(record), petName, rarity,
                            formatNumber(earningRate), math.floor(distance + 0.5)
                        )
                        local key = "egg_" .. record.Uid
                        drawEntry(key, eggCFrame.Position, text, getRarityColor(rarity), nil)
                        active[key] = true
                    end
                end
            end
        end

        local function updateMyEggEsp(active)
            LPH_ATTRIBUTES(PRESET(FAST), ERROR_HANDLING(false))
            if not esp.MyEggEnabled or not esp.Ready then return end
            if os.clock() - esp.LastOwnedSyncAt >= 2 and not esp.OwnedSyncBusy then
                esp.LastOwnedSyncAt = os.clock()
                esp.OwnedSyncBusy = true
                task.spawn(function()
                    pcall(eggState.SyncOwnedEggs)
                    esp.OwnedSyncBusy = false
                end)
            end
            local okPlot, plot = pcall(plotState.ResolvePlot)
            if not okPlot or type(plot) ~= "table" or not plot.CenterPoint then return end
            local centerPoint = plot.CenterPoint
            if not centerPoint:IsA("BasePart") then return end
            local okOwned, records = pcall(eggState.ReadOwnerEggs, LocalPlayer.UserId)
            if not okOwned or type(records) ~= "table" then return end

            for uid, record in pairs(records) do
                local placement = type(record) == "table" and record.Placement
                local localCFrame = type(placement) == "table" and placement.LocalCFrame
                if type(uid) == "string" and typeof(localCFrame) == "CFrame" then
                    local asset = getAsset(record)
                    local rarity = getRarity(record, asset)
                    if raritySelected(rarity) then
                        local petName = type(asset) == "table" and asset.DisplayName or nil
                        petName = tostring(petName or record.AssetCategory or "Unknown")
                        local earningRate = type(asset) == "table" and tonumber(asset.EarningRate) or 0
                        local worldPosition = (centerPoint.CFrame * localCFrame).Position
                        local remaining, ready = hatchRemaining(uid, record)
                        local hatchText = ready and "Ready to hatch" or formatDuration(remaining)
                        local text = string.format(
                            "Egg: %s\nPet: %s | Rarity: %s\nHatch: %s | $%s/s",
                            getEggName(record), petName, rarity,
                            hatchText, formatNumber(earningRate)
                        )
                        local key = "myegg_" .. uid
                        drawEntry(key, worldPosition, text, getRarityColor(rarity), nil)
                        active[key] = true
                    end
                end
            end
        end

        local function updatePlayerEsp(active)
            LPH_ATTRIBUTES(PRESET(FAST), ERROR_HANDLING(false))
            if not esp.PlayersEnabled then return end
            local root = localRoot()
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then
                    local character = player.Character
                    local targetRoot = character and character:FindFirstChild("HumanoidRootPart")
                    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                    if targetRoot then
                        local distance = root and (root.Position - targetRoot.Position).Magnitude or 0
                        local health = humanoid and math.max(0, math.floor(humanoid.Health + 0.5)) or 0
                        local color = player.Team and player.TeamColor.Color or Color3.fromRGB(120, 190, 255)
                        local text = string.format(
                            "%s (@%s)\nHP: %d | Distance: %d studs",
                            player.DisplayName, player.Name, health, math.floor(distance + 0.5)
                        )
                        local key = "player_" .. tostring(player.UserId)
                        drawEntry(key, targetRoot.Position, text, color, character)
                        active[key] = true
                    end
                end
            end
        end

        local rarityNames, raritySeen = {}, {}
        if type(assetDirectory) == "table" then
            for _, asset in pairs(assetDirectory) do
                if type(asset) == "table" then
                    local rarity = getRarity({}, asset)
                    if not raritySeen[rarity] then
                        raritySeen[rarity] = true
                        table.insert(rarityNames, rarity)
                    end
                end
            end
        end
        if #rarityNames == 0 then
            for rarity in pairs(fallbackRarityColors) do table.insert(rarityNames, rarity) end
        end
        table.sort(rarityNames, function(a, b)
            local configA = type(rarityDirectory) == "table" and rarityDirectory[a] or nil
            local configB = type(rarityDirectory) == "table" and rarityDirectory[b] or nil
            local rankA = type(configA) == "table" and tonumber(configA.RarityNumber) or 0
            local rankB = type(configB) == "table" and tonumber(configB.RarityNumber) or 0
            return rankA == rankB and a < b or rankA < rankB
        end)
        for _, rarity in ipairs(rarityNames) do esp.SelectedRarities[rarity] = true end

        local function parseRarityItem(item)
            if type(item) == "string" then
                return item
            elseif type(item) == "table" then
                return item.Title or item.Name or item.Text or item[1]
            end
            return nil
        end

        local function setSelectedRarities(value)
            local selected, selectAll = {}, false
            if type(value) == "string" then
                if value == SELECT_ALL_OPTION or value == "Select All" or value == "All" then
                    selectAll = true
                else
                    selected[value] = true
                end
            elseif type(value) == "table" then
                for key, item in pairs(value) do
                    if item == true and type(key) == "string" then
                        if key == SELECT_ALL_OPTION or key == "Select All" or key == "All" then
                            selectAll = true
                        else
                            selected[key] = true
                        end
                    else
                        local name = parseRarityItem(item)
                        if name == SELECT_ALL_OPTION or name == "Select All" or name == "All" then
                            selectAll = true
                        elseif type(name) == "string" and name ~= "" then
                            selected[name] = true
                        elseif type(key) == "string" and item ~= false then
                            selected[key] = true
                        end
                    end
                end
            end
            if selectAll or next(selected) == nil then
                table.clear(selected)
                for _, rarity in ipairs(rarityNames) do selected[rarity] = true end
            end
            esp.SelectedRarities = selected
        end

        esp.UpdateConnection = RunService.Heartbeat:Connect(function(deltaTime)
            if esp.Closed then return end
            esp.Elapsed = (esp.Elapsed or 0) + (tonumber(deltaTime) or 0)
            if esp.Elapsed < esp.UpdateInterval then return end
            esp.Elapsed = 0
            local active = {}
            pcall(updateEggEsp, active)
            pcall(updateMyEggEsp, active)
            pcall(updatePlayerEsp, active)
            local stale = {}
            for key in pairs(esp.Entries) do
                if not active[key] then table.insert(stale, key) end
            end
            for _, key in ipairs(stale) do releaseEntry(key) end
        end)

        function esp.SetEggEnabled(value)
            esp.EggEnabled = value == true and esp.Ready
            if not esp.EggEnabled then releasePrefix("egg_") end
        end

        function esp.SetMyEggEnabled(value)
            esp.MyEggEnabled = value == true and esp.Ready
            if not esp.MyEggEnabled then releasePrefix("myegg_") end
        end

        function esp.SetPlayersEnabled(value)
            esp.PlayersEnabled = value == true
            if not esp.PlayersEnabled then releasePrefix("player_") end
        end

        esp.GetRarity = getRarity
        esp.GetEggName = getEggName
        esp.GetHatchRemaining = hatchRemaining
        esp.SetSelectedRarities = setSelectedRarities
        esp.RarityNames = rarityNames

        ScriptEnv.SAE_ESP = esp
        ScriptEnv.SAE_EspCleanup = function()
            esp.Closed = true
            esp.EggEnabled = false
            esp.MyEggEnabled = false
            esp.PlayersEnabled = false
            if esp.UpdateConnection then esp.UpdateConnection:Disconnect() end
            if folder then folder:Destroy() end
            table.clear(esp.Entries)
            if ScriptEnv.SAE_ESP == esp then ScriptEnv.SAE_ESP = nil end
        end

        task.wait()

        local espSection = LocalPlayerTab:Section({
            Title = "ESP",
            ConfigFlagKey = "ESP",
            Icon = "scan-eye",
            Box = true,
            BoxBorder = true,
            Opened = true,
        })
        if not esp.Ready then
            espSection:Paragraph({
                Title = "Egg ESP unavailable",
                Desc = "Current game egg or rarity data could not be loaded.",
                Image = "triangle-alert",
                ImageSize = 30,
            })
        end
        espSection:Dropdown({
            Title = "Egg Rarities to Show",
            Flag = "Local_ESPRarities",
            Values = rarityNames,
            Value = rarityNames,
            Multi = true,
            AllowNone = true,
            NativeSelectAll = true,
            Callback = setSelectedRarities,
        })
        espSection:Toggle({
            Title = "ESP Egg",
            Flag = "Local_ESPEgg",
            Value = false,
            Callback = function(value) esp.SetEggEnabled(value) end,
        })
        espSection:Toggle({
            Title = "ESP My Egg",
            Flag = "Local_ESPMyEgg",
            Value = false,
            Callback = function(value) esp.SetMyEggEnabled(value) end,
        })
        espSection:Toggle({
            Title = "ESP Players",
            Flag = "Local_ESPPlayers",
            Value = false,
            Callback = function(value) esp.SetPlayersEnabled(value) end,
        })
    end

    task.wait()

    do
        local perf = {
            Closed = false,
            NoTextures = false,
            NoFx = false,
            NoLights = false,
            HidePets = false,
            HideMapDetail = false,
            HidePlayers = false,
            NoAccessories = false,
            LowLighting = false,
            LowWater = false,
            LowQuality = false,
            MuteSounds = false,
            FpsCap = 0,
        }

        local ESP_FOLDER_NAME = "StealAnEggESP"

        local PET_RENDER_NAMES = {
            ClientRenderedAssets = true,
            PlacedEggRenders = true,
            PetRenders = true,
        }

        local PROTECTED_NAMES = {
            Plots = true,
            World = true,
            __DEBRIS = true,
            AreaEggSlotsClient = true,
            Terrain = true,
            Camera = true,
            [ESP_FOLDER_NAME] = true,
        }

        local function isDecorativeName(name)
            return name:find("Sakura") ~= nil
                or name:find("Bloomed") ~= nil
                or name:find("Crystals") ~= nil
                or name:find("FXHost") ~= nil
        end

        local function insideEsp(instance)
            local current = instance
            while current and current ~= Workspace do
                if current.Name == ESP_FOLDER_NAME then return true end
                current = current.Parent
            end
            return false
        end

        local function newGroup()
            return { Hidden = {}, Props = {}, Connections = {} }
        end

        local function hideInstance(group, instance)
            if not instance or group.Hidden[instance] ~= nil then return end
            local parent = instance.Parent
            if not parent then return end
            group.Hidden[instance] = parent
            pcall(function() instance.Parent = nil end)
        end

        local function setProp(group, instance, prop, value)
            if not instance then return end
            local ok, old = pcall(function() return instance[prop] end)
            if not ok then return end
            local map = group.Props[instance]
            if not map then
                map = {}
                group.Props[instance] = map
            end
            if map[prop] == nil then map[prop] = old end
            pcall(function() instance[prop] = value end)
        end

        local function restoreGroup(group)
            for _, connection in ipairs(group.Connections) do
                pcall(function() connection:Disconnect() end)
            end
            table.clear(group.Connections)
            for instance, parent in pairs(group.Hidden) do
                pcall(function() instance.Parent = parent end)
            end
            table.clear(group.Hidden)
            for instance, map in pairs(group.Props) do
                for prop, old in pairs(map) do
                    pcall(function() instance[prop] = old end)
                end
            end
            table.clear(group.Props)
        end

        local groups = {
            Textures = newGroup(),
            Fx = newGroup(),
            Lights = newGroup(),
            Pets = newGroup(),
            MapDetail = newGroup(),
            Players = newGroup(),
            Accessories = newGroup(),
            Lighting = newGroup(),
            Water = newGroup(),
            Quality = newGroup(),
            Sounds = newGroup(),
        }

        local function stripTexture(instance)
            if insideEsp(instance) then return end
            if instance:IsA("Decal") or instance:IsA("Texture") then
                setProp(groups.Textures, instance, "Transparency", 1)
            elseif instance:IsA("SurfaceAppearance") then
                hideInstance(groups.Textures, instance)
            elseif instance:IsA("MeshPart") then
                if instance.TextureID ~= "" then
                    setProp(groups.Textures, instance, "TextureID", "")
                end
                setProp(groups.Textures, instance, "Material", Enum.Material.SmoothPlastic)
            elseif instance:IsA("BasePart") then
                setProp(groups.Textures, instance, "Material", Enum.Material.SmoothPlastic)
                setProp(groups.Textures, instance, "Reflectance", 0)
            end
        end

        local function applyNoTextures(enabled)
            perf.NoTextures = enabled == true
            if not perf.NoTextures then
                restoreGroup(groups.Textures)
                return
            end
            for _, instance in ipairs(Workspace:GetDescendants()) do
                stripTexture(instance)
            end
            table.insert(groups.Textures.Connections, Workspace.DescendantAdded:Connect(function(instance)
                if perf.Closed or not perf.NoTextures then return end
                task.defer(function()
                    if perf.NoTextures and instance.Parent then stripTexture(instance) end
                end)
            end))
        end

        local function isFxClass(instance)
            return instance:IsA("ParticleEmitter")
                or instance:IsA("Trail")
                or instance:IsA("Beam")
                or instance:IsA("Smoke")
                or instance:IsA("Fire")
                or instance:IsA("Sparkles")
        end

        local function stripFx(instance)
            if insideEsp(instance) then return end
            if isFxClass(instance) then
                setProp(groups.Fx, instance, "Enabled", false)
            end
        end

        local function applyNoFx(enabled)
            perf.NoFx = enabled == true
            if not perf.NoFx then
                restoreGroup(groups.Fx)
                return
            end
            for _, instance in ipairs(Workspace:GetDescendants()) do
                stripFx(instance)
            end
            for _, instance in ipairs(Lighting:GetDescendants()) do
                stripFx(instance)
            end
            table.insert(groups.Fx.Connections, Workspace.DescendantAdded:Connect(function(instance)
                if perf.Closed or not perf.NoFx then return end
                task.defer(function()
                    if perf.NoFx and instance.Parent then stripFx(instance) end
                end)
            end))
        end

        local function stripLight(instance)
            if insideEsp(instance) then return end
            if instance:IsA("Light") then
                setProp(groups.Lights, instance, "Enabled", false)
            end
        end

        local function applyNoLights(enabled)
            perf.NoLights = enabled == true
            if not perf.NoLights then
                restoreGroup(groups.Lights)
                return
            end
            for _, instance in ipairs(Workspace:GetDescendants()) do
                stripLight(instance)
            end
            table.insert(groups.Lights.Connections, Workspace.DescendantAdded:Connect(function(instance)
                if perf.Closed or not perf.NoLights then return end
                task.defer(function()
                    if perf.NoLights and instance.Parent then stripLight(instance) end
                end)
            end))
        end

        local function applyHidePets(enabled)
            perf.HidePets = enabled == true
            if not perf.HidePets then
                restoreGroup(groups.Pets)
                return
            end
            for _, child in ipairs(Workspace:GetChildren()) do
                if PET_RENDER_NAMES[child.Name] then
                    hideInstance(groups.Pets, child)
                end
            end
            table.insert(groups.Pets.Connections, Workspace.ChildAdded:Connect(function(child)
                if perf.Closed or not perf.HidePets then return end
                if PET_RENDER_NAMES[child.Name] then
                    task.defer(function()
                        if perf.HidePets then hideInstance(groups.Pets, child) end
                    end)
                end
            end))
        end

        local function applyHideMapDetail(enabled)
            perf.HideMapDetail = enabled == true
            if not perf.HideMapDetail then
                restoreGroup(groups.MapDetail)
                return
            end
            for _, child in ipairs(Workspace:GetChildren()) do
                if not PROTECTED_NAMES[child.Name] and isDecorativeName(child.Name) then
                    hideInstance(groups.MapDetail, child)
                end
            end
            local objects = Workspace:FindFirstChild("World")
            if objects then
                for _, child in ipairs(objects:GetChildren()) do
                    if isDecorativeName(child.Name) then
                        hideInstance(groups.MapDetail, child)
                    end
                end
            end
            table.insert(groups.MapDetail.Connections, Workspace.ChildAdded:Connect(function(child)
                if perf.Closed or not perf.HideMapDetail then return end
                if not PROTECTED_NAMES[child.Name] and isDecorativeName(child.Name) then
                    task.defer(function()
                        if perf.HideMapDetail then hideInstance(groups.MapDetail, child) end
                    end)
                end
            end))
        end

        local function isOtherCharacter(model)
            local player = Players:GetPlayerFromCharacter(model)
            return player ~= nil and player ~= LocalPlayer
        end

        local function fadeCharacter(character)
            if not character then return end
            for _, instance in ipairs(character:GetDescendants()) do
                if instance:IsA("BasePart") then
                    setProp(groups.Players, instance, "LocalTransparencyModifier", 1)
                elseif instance:IsA("Decal") then
                    setProp(groups.Players, instance, "Transparency", 1)
                elseif instance:IsA("BillboardGui") then
                    setProp(groups.Players, instance, "Enabled", false)
                end
            end
        end

        local function applyHidePlayers(enabled)
            perf.HidePlayers = enabled == true
            if not perf.HidePlayers then
                restoreGroup(groups.Players)
                return
            end
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then
                    fadeCharacter(player.Character)
                    table.insert(groups.Players.Connections, player.CharacterAdded:Connect(function(character)
                        if perf.Closed or not perf.HidePlayers then return end
                        task.wait(0.5)
                        if perf.HidePlayers then fadeCharacter(character) end
                    end))
                end
            end
            table.insert(groups.Players.Connections, Players.PlayerAdded:Connect(function(player)
                if perf.Closed or not perf.HidePlayers then return end
                table.insert(groups.Players.Connections, player.CharacterAdded:Connect(function(character)
                    if perf.Closed or not perf.HidePlayers then return end
                    task.wait(0.5)
                    if perf.HidePlayers then fadeCharacter(character) end
                end))
            end))

            task.spawn(function()
                while not perf.Closed and perf.HidePlayers do
                    for _, player in ipairs(Players:GetPlayers()) do
                        if player ~= LocalPlayer then fadeCharacter(player.Character) end
                    end
                    task.wait(3)
                end
            end)
        end

        local function stripAccessories(character)
            if not character then return end
            for _, instance in ipairs(character:GetChildren()) do
                if instance:IsA("Accessory") or instance:IsA("Hat") then
                    hideInstance(groups.Accessories, instance)
                end
            end
        end

        local function applyNoAccessories(enabled)
            perf.NoAccessories = enabled == true
            if not perf.NoAccessories then
                restoreGroup(groups.Accessories)
                return
            end
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then stripAccessories(player.Character) end
            end
            table.insert(groups.Accessories.Connections, Workspace.ChildAdded:Connect(function(child)
                if perf.Closed or not perf.NoAccessories then return end
                task.defer(function()
                    if perf.NoAccessories and isOtherCharacter(child) then
                        task.wait(0.5)
                        stripAccessories(child)
                    end
                end)
            end))
        end

        local function applyLowLighting(enabled)
            perf.LowLighting = enabled == true
            if not perf.LowLighting then
                restoreGroup(groups.Lighting)
                return
            end
            setProp(groups.Lighting, Lighting, "GlobalShadows", false)
            setProp(groups.Lighting, Lighting, "Brightness", 1)
            setProp(groups.Lighting, Lighting, "EnvironmentDiffuseScale", 0)
            setProp(groups.Lighting, Lighting, "EnvironmentSpecularScale", 0)
            for _, child in ipairs(Lighting:GetChildren()) do
                if child:IsA("PostEffect") then
                    setProp(groups.Lighting, child, "Enabled", false)
                elseif child:IsA("Atmosphere") then
                    hideInstance(groups.Lighting, child)
                end
            end
        end

        local function applyLowWater(enabled)
            perf.LowWater = enabled == true
            if not perf.LowWater then
                restoreGroup(groups.Water)
                return
            end
            local terrain = Workspace.Terrain
            setProp(groups.Water, terrain, "WaterWaveSize", 0)
            setProp(groups.Water, terrain, "WaterWaveSpeed", 0)
            setProp(groups.Water, terrain, "WaterReflectance", 0)
            setProp(groups.Water, terrain, "WaterTransparency", 0)
        end

        local function applyLowQuality(enabled)
            perf.LowQuality = enabled == true
            if not perf.LowQuality then
                restoreGroup(groups.Quality)
                return
            end
            pcall(function()
                setProp(groups.Quality, settings().Rendering, "QualityLevel", Enum.QualityLevel.Level01)
            end)
        end

        local function muteSound(instance)
            if instance:IsA("Sound") then
                setProp(groups.Sounds, instance, "Volume", 0)
            end
        end

        local function applyMuteSounds(enabled)
            perf.MuteSounds = enabled == true
            if not perf.MuteSounds then
                restoreGroup(groups.Sounds)
                return
            end
            for _, instance in ipairs(Workspace:GetDescendants()) do
                muteSound(instance)
            end
            for _, instance in ipairs(game:GetService("SoundService"):GetDescendants()) do
                muteSound(instance)
            end
            table.insert(groups.Sounds.Connections, Workspace.DescendantAdded:Connect(function(instance)
                if perf.Closed or not perf.MuteSounds then return end
                task.defer(function()
                    if perf.MuteSounds and instance.Parent then muteSound(instance) end
                end)
            end))
        end

        local originalFpsCap = nil
        local function applyFpsCap(value)
            local cap = math.floor(tonumber(value) or 0)
            perf.FpsCap = cap
            if type(setfpscap) ~= "function" then return end
            if originalFpsCap == nil and type(getfpscap) == "function" then
                local ok, current = pcall(getfpscap)
                originalFpsCap = ok and tonumber(current) or 60
            end

            pcall(setfpscap, cap <= 0 and (originalFpsCap or 60) or cap)
        end

        local perfSection = LocalPlayerTab:Section({
            Title = "Performance / Reduce Lag",
            ConfigFlagKey = "Performance",
            Icon = "gauge",
            Box = true,
            BoxBorder = true,
            Opened = true,
        })

        local fpsParagraph = perfSection:Paragraph({
            Title = "FPS Monitor",
            Desc = "Measuring...",
            Image = "activity",
            ImageSize = 26,
        })

        local noTexturesToggle, noFxToggle, noLightsToggle, hidePetsToggle
        local hideMapToggle, hidePlayersToggle, noAccessoriesToggle
        local lowLightingToggle, lowWaterToggle, lowQualityToggle

        local boostBusy = false
        local function setToggle(toggle, value)
            if not toggle then return end
            pcall(function() toggle:Set(value) end)
        end

        perfSection:Toggle({
            Title = "Boost FPS (All Optimizations)",
            Desc = "Turns on every render optimization below at once.",
            Flag = "Local_PerfBoost",
            Value = false,
            Callback = function(value)
                if boostBusy then return end
                boostBusy = true
                local on = value == true
                setToggle(noTexturesToggle, on)
                setToggle(noFxToggle, on)
                setToggle(noLightsToggle, on)
                setToggle(hidePetsToggle, on)
                setToggle(hideMapToggle, on)
                setToggle(noAccessoriesToggle, on)
                setToggle(lowLightingToggle, on)
                setToggle(lowWaterToggle, on)
                setToggle(lowQualityToggle, on)
                boostBusy = false
            end,
        })

        perfSection:Divider()

        noTexturesToggle = perfSection:Toggle({
            Title = "Remove Textures & Decals",
            Desc = "Clears MeshPart textures, decals and surface appearances.",
            Flag = "Local_PerfNoTextures",
            Value = false,
            Callback = applyNoTextures,
        })

        noFxToggle = perfSection:Toggle({
            Title = "Disable Particles & Trails",
            Flag = "Local_PerfNoFx",
            Value = false,
            Callback = applyNoFx,
        })

        noLightsToggle = perfSection:Toggle({
            Title = "Disable Dynamic Lights",
            Flag = "Local_PerfNoLights",
            Value = false,
            Callback = applyNoLights,
        })

        hidePetsToggle = perfSection:Toggle({
            Title = "Hide Pet / Egg Renders",
            Desc = "Hides pet and placed-egg render folders (client visuals only).",
            Flag = "Local_PerfHidePets",
            Value = false,
            Callback = applyHidePets,
        })

        hideMapToggle = perfSection:Toggle({
            Title = "Hide Map Decoration",
            Desc = "Hides trees, crystals and other cosmetic map props.",
            Flag = "Local_PerfHideMapDetail",
            Value = false,
            Callback = applyHideMapDetail,
        })

        hidePlayersToggle = perfSection:Toggle({
            Title = "Hide Other Players",
            Flag = "Local_PerfHidePlayers",
            Value = false,
            Callback = applyHidePlayers,
        })

        noAccessoriesToggle = perfSection:Toggle({
            Title = "Remove Player Accessories",
            Flag = "Local_PerfNoAccessories",
            Value = false,
            Callback = applyNoAccessories,
        })

        perfSection:Divider()

        lowLightingToggle = perfSection:Toggle({
            Title = "No Shadows / No Post FX",
            Flag = "Local_PerfLowLighting",
            Value = false,
            Callback = applyLowLighting,
        })

        lowWaterToggle = perfSection:Toggle({
            Title = "Flat Water",
            Flag = "Local_PerfLowWater",
            Value = false,
            Callback = applyLowWater,
        })

        lowQualityToggle = perfSection:Toggle({
            Title = "Lowest Graphics Quality",
            Flag = "Local_PerfLowQuality",
            Value = false,
            Callback = applyLowQuality,
        })

        perfSection:Toggle({
            Title = "Mute Game Sounds",
            Flag = "Local_PerfMuteSounds",
            Value = false,
            Callback = applyMuteSounds,
        })

        perfSection:Slider({
            Title = "FPS Cap (0 = executor default)",
            Flag = "Local_PerfFpsCap",
            Step = 5,
            Value = { Min = 0, Max = 360, Default = 0 },
            Callback = applyFpsCap,
        })

        perfSection:Button({
            Title = "Restore Everything",
            Icon = "rotate-ccw",
            Callback = function()
                setToggle(noTexturesToggle, false)
                setToggle(noFxToggle, false)
                setToggle(noLightsToggle, false)
                setToggle(hidePetsToggle, false)
                setToggle(hideMapToggle, false)
                setToggle(hidePlayersToggle, false)
                setToggle(noAccessoriesToggle, false)
                setToggle(lowLightingToggle, false)
                setToggle(lowWaterToggle, false)
                setToggle(lowQualityToggle, false)
                for _, group in pairs(groups) do
                    restoreGroup(group)
                end
                applyFpsCap(0)
                Notify("Performance", "All render tweaks reverted.", "rotate-ccw", 4)
            end,
        })

        local fpsConnection = nil
        task.spawn(function()
            local frames = 0

            fpsConnection = RunService.RenderStepped:Connect(function()
                frames += 1
            end)
            while not perf.Closed do
                local start = os.clock()
                frames = 0
                task.wait(1)
                local elapsed = math.max(os.clock() - start, 0.001)
                local fps = math.floor(frames / elapsed + 0.5)
                local active = {}
                if perf.NoTextures then table.insert(active, "textures") end
                if perf.NoFx then table.insert(active, "fx") end
                if perf.NoLights then table.insert(active, "lights") end
                if perf.HidePets then table.insert(active, "pets") end
                if perf.HideMapDetail then table.insert(active, "map") end
                if perf.HidePlayers then table.insert(active, "players") end
                if perf.NoAccessories then table.insert(active, "accessories") end
                if perf.LowLighting then table.insert(active, "shadows") end
                if perf.LowWater then table.insert(active, "water") end
                if perf.LowQuality then table.insert(active, "quality") end
                if perf.MuteSounds then table.insert(active, "sounds") end
                pcall(function()
                    fpsParagraph:SetDesc(string.format(
                        "FPS: %d | Cap: %s\nOptimizations: %s",
                        fps,
                        perf.FpsCap > 0 and tostring(perf.FpsCap) or "default",
                        #active > 0 and table.concat(active, ", ") or "none"
                    ))
                end)
            end
            pcall(function()
                if fpsConnection then fpsConnection:Disconnect() end
            end)
        end)

        ScriptEnv.SAE_Performance = perf
        ScriptEnv.SAE_PerformanceCleanup = function()
            perf.Closed = true
            pcall(function()
                if fpsConnection then fpsConnection:Disconnect() end
            end)
            for _, group in pairs(groups) do
                restoreGroup(group)
            end
            if originalFpsCap ~= nil and type(setfpscap) == "function" then
                pcall(setfpscap, originalFpsCap)
            end
            if ScriptEnv.SAE_Performance == perf then ScriptEnv.SAE_Performance = nil end
        end
    end


    do
        local anti = {
            AntiTrapEnabled = false,
            AntiRagdollEnabled = false,
            BatAuraLock = false,
            Ready = false,
            Closed = false,
            Recoveries = 0,
            RagdollHooked = false,
            HookedApplyRagdoll = nil,
            OriginalApplyRagdoll = nil,
        }
        local ragdoll
        anti.Ready = pcall(function()
            ragdoll = require(ReplicatedStorage:WaitForChild("Shared", 10)
                :WaitForChild("Modules", 10):WaitForChild("Ragdoll", 10))
        end)

        local function characterParts()
            local character = LocalPlayer.Character
            if not character then return nil, nil, nil end
            return character,
                character:FindFirstChild("HumanoidRootPart"),
                character:FindFirstChildOfClass("Humanoid")
        end

        local function restoreRagdollStates()
            local _, _, humanoid = characterParts()
            if not humanoid then return end
            pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true) end)
            pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true) end)
        end

        local function applyStateGuard()
            local _, _, humanoid = characterParts()
            if not humanoid then return end
            pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false) end)
            pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false) end)
        end

        local function setRagdollHook(blocked)
            if not ragdoll or type(ragdoll.ApplyClientRagdoll) ~= "function" then return end
            if blocked and not anti.RagdollHooked then
                local ok, err = pcall(function()
                    anti.OriginalApplyRagdoll = ragdoll.ApplyClientRagdoll
                    if type(hookfunction) == "function" then
                        local hooked = hookfunction(ragdoll.ApplyClientRagdoll, function()
                            return nil
                        end)
                        anti.HookedApplyRagdoll = hooked
                    else
                        ragdoll.ApplyClientRagdoll = function()
                            return nil
                        end
                    end
                end)
                anti.RagdollHooked = ok
                if not ok then warn("[AntiRagdoll] hook failed: " .. tostring(err)) end
            elseif not blocked and anti.RagdollHooked then
                pcall(function()
                    if type(hookfunction) == "function" and anti.HookedApplyRagdoll ~= nil then
                        pcall(hookfunction, anti.HookedApplyRagdoll, anti.OriginalApplyRagdoll)
                    end
                    ragdoll.ApplyClientRagdoll = anti.OriginalApplyRagdoll
                end)
                anti.RagdollHooked = false
                anti.HookedApplyRagdoll = nil
                anti.OriginalApplyRagdoll = nil
            end
        end

        local function antiRagdollStep()
            local character, root, humanoid = characterParts()
            if not character or not root or not humanoid then return end

            local state = humanoid:GetState()
            local okRagdoll, isRagdolled = false, false
            if ragdoll then okRagdoll, isRagdolled = pcall(ragdoll.IsRagdolled, character) end
            local hardStun = (okRagdoll and isRagdolled == true)
                or state == Enum.HumanoidStateType.FallingDown
                or state == Enum.HumanoidStateType.Ragdoll
                or state == Enum.HumanoidStateType.Physics
            if not hardStun then return end

            if ragdoll then pcall(ragdoll.ClearClientRagdoll, character) end
            humanoid.Sit = false
            local movement = ScriptEnv.SAE_LocalMovement
            local steal = ScriptEnv.SAE_AutoSteal
            local preservePlatformStand = anti.BatAuraLock == true
                or (type(movement) == "table" and movement.FlyEnabled == true)
                or (type(steal) == "table" and (steal.ActiveTween ~= nil
                    or steal.Moving == true
                    or steal.CarryChaseActive == true))
            if not preservePlatformStand then humanoid.PlatformStand = false end
            root.Anchored = false
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end)
            pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Running) end)
            anti.Recoveries += 1
        end

        local CollectionService = game:GetService("CollectionService")
        local trapPartsOriginal = {}
        local trapConnections = {}

        local function disarmTrapPart(part)
            if part:IsA("BasePart") and trapPartsOriginal[part] == nil then
                trapPartsOriginal[part] = part.CanTouch
                pcall(function()
                    part.CanTouch = false
                end)
            end
        end

        local function disarmTrap(trap)
            if not anti.AntiTrapEnabled or not trap or not trap.Parent then return end
            if trap:GetAttribute("Owner") == LocalPlayer.Name then return end

            disarmTrapPart(trap)
            for _, descendant in ipairs(trap:GetDescendants()) do
                disarmTrapPart(descendant)
            end

            table.insert(trapConnections, trap.DescendantAdded:Connect(function(descendant)
                if anti.AntiTrapEnabled then
                    disarmTrapPart(descendant)
                end
            end))
        end

        local function disarmAllTraps()
            for _, trap in ipairs(CollectionService:GetTagged("PlacedTrap")) do
                disarmTrap(trap)
            end
            for _, parent in ipairs({ Workspace:FindFirstChild("Transient"), Workspace:FindFirstChild("__DEBRIS"), Workspace }) do
                if parent then
                    for _, child in ipairs(parent:GetChildren()) do
                        if child.Name == "PlayerTrap" then
                            disarmTrap(child)
                        end
                    end
                end
            end
        end

        local function restoreAllTraps()
            for part, orig in pairs(trapPartsOriginal) do
                if part.Parent then
                    pcall(function()
                        part.CanTouch = orig
                    end)
                end
            end
            table.clear(trapPartsOriginal)
            for _, conn in ipairs(trapConnections) do
                pcall(function() conn:Disconnect() end)
            end
            table.clear(trapConnections)
        end

        table.insert(trapConnections, CollectionService:GetInstanceAddedSignal("PlacedTrap"):Connect(function(trap)
            if anti.AntiTrapEnabled then
                task.defer(disarmTrap, trap)
            end
        end))

        local transient = Workspace:FindFirstChild("Transient")
        if transient then
            table.insert(trapConnections, transient.ChildAdded:Connect(function(child)
                if anti.AntiTrapEnabled and child.Name == "PlayerTrap" then
                    task.defer(disarmTrap, child)
                end
            end))
        end

        if anti.Ready then
            anti.HeartbeatConnection = RunService.Heartbeat:Connect(function()
                if anti.AntiRagdollEnabled then
                    antiRagdollStep()
                end
            end)

            anti.CharacterAddedConnection = LocalPlayer.CharacterAdded:Connect(function()
                task.defer(function()
                    if anti.Closed then return end
                    if anti.AntiRagdollEnabled then
                        applyStateGuard()
                    end
                end)
            end)
        end

        function anti.SetAntiTrap(value)
            anti.AntiTrapEnabled = value == true
            if anti.AntiTrapEnabled then
                disarmAllTraps()
            else
                restoreAllTraps()
            end
        end

        function anti.SetAntiRagdoll(value)
            anti.AntiRagdollEnabled = value == true and anti.Ready
            if anti.AntiRagdollEnabled then
                setRagdollHook(true)
                applyStateGuard()
                antiRagdollStep()
            else
                setRagdollHook(false)
                restoreRagdollStates()
            end
        end

        function anti.SetBatAuraLock(value)
            anti.BatAuraLock = value == true
        end

        anti.AntiRecordEnabled = false
        anti.AntiRecordBusy = false
        anti.AntiRecordCharConn = nil

        local ANTI_RECORD_SAFE_POS = Vector3.new(-3359, 17289, 15691)

        local function arInstallTempPatch()
            if type(filtergc) ~= "function" then return end
            pcall(function()
                local f = filtergc("function", { Constants = { "Health", "RootPart" } }, true)
                if type(f) == "function" then
                    debug.setconstant(f, 2, "nil")
                end
            end)
        end

        local function arPauseBypass()
            local env = (getgenv and getgenv() or _G)
            if type(env.SAE_BypassCleanup) == "function" then
                pcall(env.SAE_BypassCleanup)
            end
        end

        local function arResumeBypass(char)
            local env = (getgenv and getgenv() or _G)
            if type(env.SAE_BypassResume) == "function" then
                pcall(env.SAE_BypassResume, char)
            elseif type(env.SAE_RunBypassCycle) == "function" then
                pcall(env.SAE_RunBypassCycle)
            end
        end

        local function arResetToCleanCharacter(hideNewChar)
            arPauseBypass()

            local char = LocalPlayer.Character
            if not char then
                char = LocalPlayer.CharacterAdded:Wait()
                local h = char:WaitForChild("Humanoid", 10)
                local hrp = char:WaitForChild("HumanoidRootPart", 10)
                task.wait(1)
                if char:FindFirstChild("UpperTorso") and h then
                    pcall(function()
                        h.RigType = Enum.HumanoidRigType.R15
                        if h.HipHeight <= 0 then h.HipHeight = 1.8 end
                    end)
                end
                return char, hrp, h
            end

            local oldChar = char
            local newChar = nil

            local conn
            conn = LocalPlayer.CharacterAdded:Connect(function(nc)
                newChar = nc
                pcall(function()
                    for _, p in ipairs(nc:GetDescendants()) do
                        if p:IsA("BasePart") or p:IsA("Decal") then
                            p.LocalTransparencyModifier = (hideNewChar == true and 1 or 0)
                        end
                    end
                end)
                if conn then conn:Disconnect() conn = nil end
            end)

            pcall(function()
                for _, p in ipairs(oldChar:GetDescendants()) do
                    if p:IsA("BasePart") or p:IsA("Decal") then
                        p.Transparency = 1
                        p.LocalTransparencyModifier = 1
                    elseif p:IsA("Accessory") then
                        p:Destroy()
                    end
                end
                local oldRoot = oldChar:FindFirstChild("HumanoidRootPart")
                if oldRoot then
                    oldRoot.CFrame = CFrame.new(0, -900, 0)
                end
            end)

            local wipeFired = false
            pcall(function()
                local RS = game:GetService("ReplicatedStorage")
                local Remotes = require(RS.Shared.Remotes)
                if Remotes and Remotes.RigSync and Remotes.RigSync.AskRigWipe then
                    Remotes.RigSync.AskRigWipe:FireServer(oldChar)
                    wipeFired = true
                end
            end)

            if not wipeFired then
                pcall(function()
                    local RS = game:GetService("ReplicatedStorage")
                    local remote = RS.Packages.Networking["RE/RigSync/AskRigWipe"]
                    if remote then
                        remote:FireServer(oldChar)
                        wipeFired = true
                    end
                end)
            end

            local deadline = os.clock() + 8
            while not newChar and os.clock() < deadline do
                if os.clock() > (deadline - 5) and not wipeFired then
                    pcall(function()
                        local h = oldChar:FindFirstChildOfClass("Humanoid")
                        if h then h.Health = 0 end
                    end)
                end
                task.wait(0.05)
            end
            if conn then conn:Disconnect() conn = nil end

            if not newChar then
                if LocalPlayer.Character and LocalPlayer.Character ~= oldChar then
                    newChar = LocalPlayer.Character
                end
            end

            if not newChar then
                error("[AntiRecord] Failed to reset character to original state (server did not respawn)")
            end

            local humanoid = newChar:WaitForChild("Humanoid", 10)
            local root = newChar:WaitForChild("HumanoidRootPart", 10)
            task.wait(0.8)

            if newChar:FindFirstChild("UpperTorso") and humanoid then
                pcall(function()
                    humanoid.RigType = Enum.HumanoidRigType.R15
                    if humanoid.HipHeight <= 0 then
                        humanoid.HipHeight = 1.8
                    end
                end)
            end

            if hideNewChar ~= true then
                for _, p in ipairs(newChar:GetDescendants()) do
                    if p:IsA("BasePart") or p:IsA("Decal") then
                        p.LocalTransparencyModifier = 0
                    end
                end
            end

            return newChar, root, humanoid
        end

        local function arTweenRoot(root, targetCFrame, duration)
            local TweenService = game:GetService("TweenService")
            local tween = TweenService:Create(root, TweenInfo.new(duration or 0.6, Enum.EasingStyle.Linear), {
                CFrame = targetCFrame
            })
            tween:Play()
            tween.Completed:Wait()
        end

        local arVisualHold = {
            Clone = nil,
            Subject = nil,
            OldCamType = nil,
            OldCamCF = nil,
            Restore = {},
            Effects = {},
            Sounds = {},
            Connection = nil,
            Active = false,
        }

        local function arIsLeakingEffect(item)
            return item:IsA("Trail") or item:IsA("ParticleEmitter") or item:IsA("Beam")
                or item:IsA("Fire") or item:IsA("Smoke") or item:IsA("Sparkles")
        end

        local function arHideRigVisuals(character)
            if not character then return end
            for _, item in ipairs(character:GetDescendants()) do
                if item:IsA("BasePart") or item:IsA("Decal") then
                    if arVisualHold.Restore[item] == nil then
                        arVisualHold.Restore[item] = item.LocalTransparencyModifier
                    end
                    item.LocalTransparencyModifier = 1
                elseif arIsLeakingEffect(item) then
                    if arVisualHold.Effects[item] == nil then
                        arVisualHold.Effects[item] = item.Enabled
                    end
                    if item.Enabled then item.Enabled = false end
                elseif item:IsA("Sound") then
                    if arVisualHold.Sounds[item] == nil then
                        arVisualHold.Sounds[item] = item.Volume
                    end
                    if item.Volume ~= 0 then item.Volume = 0 end
                end
            end
        end

        local function arEndVisualHold()
            arVisualHold.Active = false
            if arVisualHold.Connection then
                pcall(function() arVisualHold.Connection:Disconnect() end)
                arVisualHold.Connection = nil
            end
            if arVisualHold.Clone then
                pcall(function() arVisualHold.Clone:Destroy() end)
                arVisualHold.Clone = nil
            end
            arVisualHold.Subject = nil
            for part, value in pairs(arVisualHold.Restore) do
                pcall(function() part.LocalTransparencyModifier = value end)
            end
            for effect, value in pairs(arVisualHold.Effects) do
                pcall(function() effect.Enabled = value end)
            end
            for sound, value in pairs(arVisualHold.Sounds) do
                pcall(function() sound.Volume = value end)
            end
            table.clear(arVisualHold.Restore)
            table.clear(arVisualHold.Effects)
            table.clear(arVisualHold.Sounds)

            local liveChar = LocalPlayer.Character
            if liveChar then
                for _, p in ipairs(liveChar:GetDescendants()) do
                    if p:IsA("BasePart") or p:IsA("Decal") then
                        p.LocalTransparencyModifier = 0
                    end
                end
            end

            local camera = Workspace.CurrentCamera
            if camera then
                pcall(function()
                    camera.CameraType = Enum.CameraType.Custom
                    local char = LocalPlayer.Character
                    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
                    if humanoid then
                        camera.CameraSubject = humanoid
                    end
                end)
            end
            arVisualHold.OldCamType = nil
            arVisualHold.OldCamCF = nil
        end

        local function arBeginVisualHold(standCFrame)
            arEndVisualHold()

            if anti.AntiRecordVisualHold == false then
                return false
            end

            local character = LocalPlayer.Character
            if not character then return false end

            local camera = Workspace.CurrentCamera
            if camera then
                arVisualHold.OldCamType = camera.CameraType
                arVisualHold.OldCamCF = camera.CFrame
                pcall(function()
                    camera.CameraType = Enum.CameraType.Scriptable
                    camera.CFrame = arVisualHold.OldCamCF
                end)
            end

            character.Archivable = true
            local ok, clone = pcall(function() return character:Clone() end)
            if not ok or not clone then return false end
            clone.Name = "StandInAntiRecord"
            for _, item in ipairs(clone:GetDescendants()) do
                if item:IsA("LocalScript") or item:IsA("Script") then
                    pcall(function() item:Destroy() end)
                elseif item:IsA("BasePart") then
                    item.Anchored = true
                    item.CanCollide = false
                    item.CanTouch = false
                    item.CanQuery = false
                end
            end
            local cloneHumanoid = clone:FindFirstChildOfClass("Humanoid")
            if cloneHumanoid then
                cloneHumanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
                cloneHumanoid.HealthDisplayDistance = 0
                cloneHumanoid.NameDisplayDistance = 0
                pcall(function() cloneHumanoid:ChangeState(Enum.HumanoidStateType.Physics) end)
            end

            if standCFrame then
                local cloneRoot = clone:FindFirstChild("HumanoidRootPart")
                if cloneRoot then
                    cloneRoot.CFrame = standCFrame
                end
            end

            clone.Parent = Workspace

            arHideRigVisuals(character)

            arVisualHold.Clone = clone
            arVisualHold.Active = true

            arVisualHold.Connection = RunService.RenderStepped:Connect(function()
                if not arVisualHold.Active then return end
                local cam = Workspace.CurrentCamera
                if cam and arVisualHold.OldCamCF then
                    cam.CameraType = Enum.CameraType.Scriptable
                    cam.CFrame = arVisualHold.OldCamCF
                end
                local live = LocalPlayer.Character
                if live then
                    arHideRigVisuals(live)
                end
            end)
            return true
        end

        local function arCaptureJoints(character)
            local saved = {}
            if not character then return saved end
            for _, desc in ipairs(character:GetDescendants()) do
                if desc:IsA("Motor6D") or desc:IsA("Weld") or desc:IsA("ManualWeld") or desc:IsA("WeldConstraint") then
                    table.insert(saved, {
                        Class = desc.ClassName,
                        Name = desc.Name,
                        Part0 = desc.Part0,
                        Part1 = desc.Part1,
                        C0 = (desc:IsA("JointInstance") and desc.C0 or nil),
                        C1 = (desc:IsA("JointInstance") and desc.C1 or nil),
                        Parent = desc.Parent,
                    })
                end
            end
            return saved
        end

        local function arRestoreJoints(character, savedJoints)
            if not character or not savedJoints then return end
            for _, j in ipairs(savedJoints) do
                if j.Part0 and j.Part1 and j.Part0.Parent and j.Part1.Parent and j.Parent and j.Parent.Parent then
                    pcall(function()
                        local newJ = Instance.new(j.Class)
                        newJ.Name = j.Name
                        newJ.Part0 = j.Part0
                        newJ.Part1 = j.Part1
                        if j.C0 then newJ.C0 = j.C0 end
                        if j.C1 then newJ.C1 = j.C1 end
                        newJ.Parent = j.Parent
                    end)
                end
            end
            for _, child in ipairs(character:GetChildren()) do
                if child:IsA("BasePart") then
                    if child.Name ~= "HumanoidRootPart" then
                        child.CanCollide = false
                    end
                    child.LocalTransparencyModifier = 0
                end
            end
        end

        local function arIsRagdolledNow(character, humanoid)
            character = character or LocalPlayer.Character
            if not character then return false end
            local isRag = false
            pcall(function()
                local Ragdoll = require(game:GetService("ReplicatedStorage").Shared.Modules.Ragdoll)
                if Ragdoll and Ragdoll.IsRagdolled(character) then
                    isRag = true
                end
            end)
            if isRag then return true end
            if humanoid then
                local state = humanoid:GetState()
                if state == Enum.HumanoidStateType.Physics
                    or state == Enum.HumanoidStateType.FallingDown
                    or state == Enum.HumanoidStateType.Ragdoll
                then
                    return true
                end
            end
            return false
        end

        local function arRagdollWindowLeft(character)
            local now = workspace:GetServerTimeNow()
            local best = 0
            character = character or LocalPlayer.Character
            if character then
                local ok, val = pcall(function() return character:GetAttribute("RagdollEndTime") end)
                if ok and val then
                    best = math.max(best, tonumber(val) - now)
                end
            end
            local okP, pVal = pcall(function() return LocalPlayer:GetAttribute("RagdollEndTime") end)
            if okP and pVal then
                best = math.max(best, tonumber(pVal) - now)
            end
            return best
        end

        local function arFirstAreaGuardRoot()
            local objects = workspace:FindFirstChild("World")
            local areas = objects and objects:FindFirstChild("Areas")
            local guardAreas = areas and areas:FindFirstChild("GuardAreas")
            local forest = guardAreas and guardAreas:FindFirstChild("Forest")
            local guard = forest and forest:FindFirstChild("Guard")
            if not guard then return nil end
            return guard.PrimaryPart
                or guard:FindFirstChild("HumanoidRootPart")
                or guard:FindFirstChildWhichIsA("BasePart", true)
        end

        local function arPickForestBaitEgg()
            local RS = game:GetService("ReplicatedStorage")
            local ok, EggState = pcall(function() return require(RS.Client.EggState) end)
            if not ok or not EggState then return nil end
            local okSnap, snapshot = pcall(EggState.ReadFieldEggs)
            if not okSnap or type(snapshot) ~= "table" then return nil end
            local records = type(snapshot.Records) == "table" and snapshot.Records or snapshot
            for _, rec in pairs(records) do
                if type(rec) == "table" and rec.Uid and (rec.State == "Slot" or rec.State == "Dropped") then
                    local aId = tostring(rec.AreaId or "")
                    local uid = tostring(rec.Uid or "")
                    if aId == "Forest" or uid:find("Forest") then
                        local cf = rec.BottomCFrame or rec.BoundsCFrame
                        if cf then
                            local slotKey = nil
                            if rec.AreaId ~= nil and rec.NestId ~= nil then
                                slotKey = tostring(rec.AreaId) .. ":" .. tostring(rec.NestId)
                            else
                                local a, s = uid:match("_([^_:]+):(Slot_%d+)$")
                                if a and s then slotKey = a .. ":" .. s end
                            end
                            return rec, cf.Position, slotKey
                        end
                    end
                end
            end
            return nil
        end

        local function arPinCarryBait(root, uid, position, slotKey, seconds)
            local RS = game:GetService("ReplicatedStorage")
            local EggState = require(RS.Client.EggState)

            local deadline = os.clock() + (seconds or 4.0)
            local pinning = true
            task.spawn(function()
                while pinning do
                    if root and root.Parent then
                        root.CFrame = CFrame.new(position)
                        root.AssemblyLinearVelocity = Vector3.zero
                        root.AssemblyAngularVelocity = Vector3.zero
                    end
                    game:GetService("RunService").Heartbeat:Wait()
                end
            end)

            local carried = false
            while not carried and os.clock() < deadline do
                local ok, res, msg = pcall(EggState.CarryFieldEgg, uid, slotKey)
                print("[AntiRecord] Carry attempt:", ok, res, msg)
                if (ok and res == true) or LocalPlayer:GetAttribute("IsCarrying") == true then
                    carried = true
                    break
                end
                task.wait(0.2)
            end
            pinning = false
            return carried
        end

        local function runAntiRecordProcedure(existingCleanChar, savedReturnCFrame)
            if anti.AntiRecordBusy then return end
            anti.AntiRecordBusy = true

            if anti.AntiRecordCharConn then
                anti.AntiRecordCharConn:Disconnect()
                anti.AntiRecordCharConn = nil
            end

            local ok, err = pcall(function()
                local currentRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                local returnCFrame = savedReturnCFrame or (currentRoot and currentRoot.CFrame)

                if anti.AntiRecordVisualHold ~= false and returnCFrame then
                    arBeginVisualHold(returnCFrame)
                end

                local char, root, humanoid
                if existingCleanChar and existingCleanChar.Parent then
                    char = existingCleanChar
                    root = char:WaitForChild("HumanoidRootPart", 10)
                    humanoid = char:WaitForChild("Humanoid", 10)
                    arPauseBypass()
                    task.wait(0.5)
                else
                    char, root, humanoid = arResetToCleanCharacter(anti.AntiRecordVisualHold ~= false)
                end

                if not char or not root or not humanoid then
                    error("Original character is not ready")
                end

                arPauseBypass()

                local savedJoints = arCaptureJoints(char)

                arInstallTempPatch()
                task.wait(0.1)

                print("[AntiRecord] Step 1: Finding Forest bait egg...")
                local baitRecord, baitPos, baitSlotKey = arPickForestBaitEgg()
                local findDl = os.clock() + 4
                while not baitRecord and os.clock() < findDl do
                    task.wait(0.2)
                    baitRecord, baitPos, baitSlotKey = arPickForestBaitEgg()
                end

                if not baitRecord or not baitPos then
                    error("Could not find Forest bait egg")
                end
                print("[AntiRecord] Step 1 Done: Found bait " .. tostring(baitRecord.Uid))

                print("[AntiRecord] Step 1.5: Entering gameplay lane...")
                local laneZ = -364.5
                local p1 = Vector3.new(root.Position.X, 72, laneZ)
                local p2 = Vector3.new(baitPos.X, 72, laneZ)
                arTweenRoot(root, CFrame.new(p1), 0.35)
                arTweenRoot(root, CFrame.new(p2), 0.35)
                task.wait(0.1)

                print("[AntiRecord] Step 2: Tweening to bait...")
                arTweenRoot(root, CFrame.new(baitPos), 0.35)
                task.wait(0.05)
                local carried = arPinCarryBait(root, baitRecord.Uid, baitPos, baitSlotKey, 4.0)
                if not carried then
                    error("Could not find Forest bait egg")
                end
                print("[AntiRecord] Step 2 Done: Bait carried!")

                local guardRoot = arFirstAreaGuardRoot()
                if not guardRoot then
                    error("Could not find Forest bait egg")
                end

                print("[AntiRecord] Step 3: Clearing old ragdoll...")
                local clearDeadline = os.clock() + 2.5
                while (arIsRagdolledNow(char, humanoid) or arRagdollWindowLeft(char) > 0.05) and os.clock() < clearDeadline do
                    pcall(function()
                        local Ragdoll = require(game:GetService("ReplicatedStorage").Shared.Modules.Ragdoll)
                        Ragdoll.ClearClientRagdoll(char)
                    end)
                    humanoid.Sit = false
                    humanoid.PlatformStand = false
                    pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end)
                    pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Running) end)
                    game:GetService("RunService").Heartbeat:Wait()
                end

                print("[AntiRecord] Step 4: Standing on Guard for hit...")
                local baseWindow = arRagdollWindowLeft(char)
                local hitDeadline = os.clock() + 6
                local ragdolled = false
                local pinnedFrames = 0
                while os.clock() < hitDeadline do
                    humanoid.Sit = false
                    humanoid.PlatformStand = false
                    if not guardRoot or not guardRoot.Parent then
                        guardRoot = arFirstAreaGuardRoot()
                        if not guardRoot then break end
                    end
                    root.CFrame = CFrame.new(guardRoot.Position + Vector3.new(0, 1, 0))
                    root.AssemblyLinearVelocity = Vector3.zero
                    root.AssemblyAngularVelocity = Vector3.zero
                    pinnedFrames = pinnedFrames + 1
                    if pinnedFrames >= 3 and (arIsRagdolledNow(char, humanoid) or arRagdollWindowLeft(char) > baseWindow + 0.15) then
                        ragdolled = true
                        break
                    end
                    game:GetService("RunService").Heartbeat:Wait()
                end

                pcall(function()
                    local EggState = require(game:GetService("ReplicatedStorage").Client.EggState)
                    EggState.DropFieldEgg("PlayerRequest")
                end)

                if not ragdolled then
                    error("Guard did not hit within the specified time")
                end
                print("[AntiRecord] Step 4 Done: Guard hit! Ragdoll window active!")

                print("[AntiRecord] Step 5: Warping to waypoint (-3359, 17289, 15691)...")
                local waypointPos = Vector3.new(-3359, 17289, 15691)
                local rideDeadline = os.clock() + 4.0
                while os.clock() < rideDeadline and (arIsRagdolledNow(char, humanoid) or arRagdollWindowLeft(char) > 0.05) do
                    humanoid.Sit = false
                    root.CFrame = CFrame.new(waypointPos)
                    root.AssemblyLinearVelocity = Vector3.zero
                    root.AssemblyAngularVelocity = Vector3.zero
                    game:GetService("RunService").Heartbeat:Wait()
                end

                print("[AntiRecord] Step 6: Waiting for ragdoll to end completely...")
                local ragWaitDeadline = os.clock() + 6
                while os.clock() < ragWaitDeadline do
                    local isRag = arIsRagdolledNow(char, humanoid)
                    local window = arRagdollWindowLeft(char)
                    if not isRag and window <= 0.01 then
                        break
                    end
                    root.CFrame = CFrame.new(waypointPos)
                    root.AssemblyLinearVelocity = Vector3.zero
                    root.AssemblyAngularVelocity = Vector3.zero
                    game:GetService("RunService").Heartbeat:Wait()
                end
                task.wait(0.4)
                print("[AntiRecord] Step 6 Done: Ragdoll ended!")

                print("[AntiRecord] Step 7: Performing BreakJoints...")
                for _, p in ipairs(char:GetChildren()) do
                    if p:IsA("BasePart") then
                        p.Anchored = true
                        p.AssemblyLinearVelocity = Vector3.zero
                        p.AssemblyAngularVelocity = Vector3.zero
                    end
                end

                local Hum = char:FindFirstChildOfClass("Humanoid") or humanoid
                if Hum then
                    pcall(function()
                        replicatesignal(Hum.ServerBreakJoints)
                    end)
                end

                task.wait(0.8)

                print("[AntiRecord] Step 8: Restoring joints...")
                arRestoreJoints(char, savedJoints)

                print("[AntiRecord] Step 9: Re-enabling speed bypass...")
                local env = (getgenv and getgenv() or _G)
                if type(env.SAE_RunBypassCycle) == "function" then
                    pcall(env.SAE_RunBypassCycle)
                end
                task.wait(0.3)

                for _, p in ipairs(char:GetChildren()) do
                    if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
                        p.Anchored = false
                        p.CanCollide = false
                        p.LocalTransparencyModifier = 0
                    end
                end

                print("[AntiRecord] Step 10: Teleporting to Cube.040...")
                local cubeTargetPos = Vector3.new(-3387.25, 17305.5, 15711.25)
                pcall(function()
                    local cube = workspace.World.Build.FuseBiomeZone.Props.StructureMeshes:FindFirstChild("Cube.040")
                    if cube and cube:IsA("BasePart") then
                        cubeTargetPos = cube.Position + Vector3.new(0, 3, 0)
                    end
                end)
                local currentRootAfter = char:FindFirstChild("HumanoidRootPart") or root
                if currentRootAfter and currentRootAfter.Parent then
                    currentRootAfter.CFrame = CFrame.new(cubeTargetPos)
                    currentRootAfter.AssemblyLinearVelocity = Vector3.zero
                    currentRootAfter.AssemblyAngularVelocity = Vector3.zero
                    currentRootAfter.Anchored = false
                end
                task.wait(0.2)
                print("[AntiRecord] Step 10 Done: Arrived at Cube.040!")

                for _, c in ipairs(workspace:GetChildren()) do
                    if c.Name == "AntiRecordPlatform" or c.Name == "AntiRecordSafeRoom" then
                        pcall(function() c:Destroy() end)
                    end
                end

                arEndVisualHold()

                if type(env.SAE_BypassResume) == "function" then
                    pcall(env.SAE_BypassResume, char)
                end

                if anti.AntiRecordCharConn then
                    anti.AntiRecordCharConn:Disconnect()
                    anti.AntiRecordCharConn = nil
                end
                anti.AntiRecordCharConn = LocalPlayer.CharacterAdded:Connect(function(newC)
                    if not anti.AntiRecordEnabled then return end
                    anti.AntiRecordBusy = false
                    task.wait(1.5)
                    if anti.AntiRecordEnabled then
                        runAntiRecordProcedure(newC, returnCFrame)
                    end
                end)
            end)

            if not ok then
                warn("[AntiRecord] procedure error: " .. tostring(err))
                pcall(arEndVisualHold)
                for _, c in ipairs(workspace:GetChildren()) do
                    if c.Name == "AntiRecordPlatform" or c.Name == "AntiRecordSafeRoom" or c.Name == "StandInAntiRecord" then
                        pcall(function() c:Destroy() end)
                    end
                end
                pcall(arResumeBypass)
            end

            anti.AntiRecordBusy = false
        end

        function anti.SetAntiRecord(value)
            if configLoading then
                anti.AntiRecordEnabled = false
                return
            end
            anti.AntiRecordEnabled = value == true

            if anti.AntiRecordEnabled then
                local currentRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                local savedReturnCFrame = currentRoot and currentRoot.CFrame or nil
                task.spawn(function()
                    runAntiRecordProcedure(nil, savedReturnCFrame)
                end)
            else
                if anti.AntiRecordCharConn then
                    anti.AntiRecordCharConn:Disconnect()
                    anti.AntiRecordCharConn = nil
                end
                pcall(arEndVisualHold)
                task.spawn(function()
                    for _, c in ipairs(workspace:GetChildren()) do
                        if c.Name == "AntiRecordPlatform" or c.Name == "AntiRecordSafeRoom" or c.Name == "StandInAntiRecord" then
                            pcall(function() c:Destroy() end)
                        end
                    end
                    local okClean, cleanChar = pcall(function()
                        return arResetToCleanCharacter(false)
                    end)
                    local live = (okClean and cleanChar) or LocalPlayer.Character
                    if live then
                        for _, p in ipairs(live:GetDescendants()) do
                            if p:IsA("BasePart") or p:IsA("Decal") then
                                p.LocalTransparencyModifier = 0
                                if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
                                    p.Anchored = false
                                end
                            end
                        end
                        local h = live:FindFirstChildOfClass("Humanoid")
                        local cam = Workspace.CurrentCamera
                        if h and cam then
                            cam.CameraType = Enum.CameraType.Custom
                            cam.CameraSubject = h
                        end
                    end
                    arResumeBypass(live)
                end)
            end
        end

        function anti.SetBatAuraLock(value)
            anti.BatAuraLock = value == true
        end

        anti.AntiRejoinEnabled = false
        anti.AntiAFKEnabled = false
        anti.OriginalTeleport = nil
        anti.AntiAFKConnection = nil
        anti.AntiAFKInputConn = nil

        function anti.SetAntiRejoin(value)
            anti.AntiRejoinEnabled = value == true
            if anti.AntiRejoinEnabled then
                local GC = getconnections or get_signal_cons
                if GC then
                    for _, conn in pairs(GC(LocalPlayer.Idled)) do
                        if conn.Disable then
                            conn:Disable()
                        elseif conn.Disconnect then
                            conn:Disconnect()
                        end
                    end
                end

                if hookfunction and not anti.OriginalTeleport then
                    local TeleportService = game:GetService("TeleportService")
                    local rawTeleport = TeleportService.Teleport
                    anti.OriginalTeleport = hookfunction(rawTeleport, function(self, placeId, ...)
                        if anti.AntiRejoinEnabled then
                            warn("[FN Anti-Rejoin] Blocked automatic Teleport attempt to PlaceId:", placeId)
                            return nil
                        end
                        return anti.OriginalTeleport(self, placeId, ...)
                    end)
                end
            else
                if anti.OriginalTeleport and hookfunction then
                    local TeleportService = game:GetService("TeleportService")
                    pcall(function() hookfunction(TeleportService.Teleport, anti.OriginalTeleport) end)
                    anti.OriginalTeleport = nil
                end
            end
        end

        function anti.SetAntiAFK(value)
            anti.AntiAFKEnabled = value == true

            if anti.AntiAFKConnection then
                anti.AntiAFKConnection:Disconnect()
                anti.AntiAFKConnection = nil
            end
            if anti.AntiAFKInputConn then
                anti.AntiAFKInputConn:Disconnect()
                anti.AntiAFKInputConn = nil
            end

            if anti.AntiAFKEnabled then
                local GC = getconnections or get_signal_cons
                if GC then
                    for _, conn in pairs(GC(LocalPlayer.Idled)) do
                        if conn.Disable then
                            conn:Disable()
                        elseif conn.Disconnect then
                            conn:Disconnect()
                        end
                    end
                end

                local VirtualUser = game:GetService("VirtualUser")
                anti.AntiAFKConnection = LocalPlayer.Idled:Connect(function()
                    if not anti.AntiAFKEnabled then return end
                    pcall(function()
                        VirtualUser:CaptureController()
                        VirtualUser:ClickButton2(Vector2.new())
                    end)
                end)

                task.spawn(function()
                    while anti.AntiAFKEnabled and not anti.Closed do
                        task.wait(300)
                        if anti.AntiAFKEnabled then
                            pcall(function()
                                VirtualUser:CaptureController()
                                VirtualUser:ClickButton2(Vector2.new())
                            end)
                        end
                    end
                end)
            end
        end

        ScriptEnv.SAE_Godmode = anti
        ScriptEnv.SAE_GodmodeCleanup = function()
            anti.Closed = true
            pcall(arEndVisualHold)
            anti.SetAntiTrap(false)
            anti.SetAntiRagdoll(false)
            anti.SetAntiRecord(false)
            anti.SetBatAuraLock(false)
            anti.SetAntiRejoin(false)
            anti.SetAntiAFK(false)
            if anti.HeartbeatConnection then anti.HeartbeatConnection:Disconnect() end
            if anti.TrapAddedConnection then anti.TrapAddedConnection:Disconnect() end
            if anti.CharacterAddedConnection then anti.CharacterAddedConnection:Disconnect() end
            if anti.AntiRecordCharConn then anti.AntiRecordCharConn:Disconnect() end
            if ScriptEnv.SAE_Godmode == anti then ScriptEnv.SAE_Godmode = nil end
        end

        local antiSection = MiscTab:Section({
            Title = "Anti",
            ConfigFlagKey = "Anti",
            Icon = "shield",
            Box = true,
            BoxBorder = true,
            Opened = true,
        })
        antiSection:Toggle({
            Title = "Anti Trap",
            Flag = "Misc_AntiTrapEnabled",
            Value = false,
            Callback = function(value) anti.SetAntiTrap(value) end,
        })
        antiSection:Toggle({
            Title = "Anti Ragdoll",
            Flag = "Misc_AntiRagdollEnabled",
            Value = false,
            Callback = function(value) anti.SetAntiRagdoll(value) end,
        })
        antiSection:Toggle({
            Title = "Anti Rejoin",
            Flag = "Misc_AntiRejoinEnabled",
            Value = false,
            Callback = function(value) anti.SetAntiRejoin(value) end,
        })
        antiSection:Toggle({
            Title = "Anti AFK",
            Flag = "Misc_AntiAFKEnabled",
            Value = false,
            Callback = function(value) anti.SetAntiAFK(value) end,
        })
        if false then
            antiSection:Toggle({
                Title = "Anti Record",
                Flag = "Misc_AntiRecordEnabled",
                Value = false,
                Callback = function(value) anti.SetAntiRecord(value) end,
            })
            antiSection:Toggle({
                Title = "Anti Record: Hide Movement",
                Flag = "Misc_AntiRecordVisualHold",
                Value = true,
                Callback = function(value)
                    anti.AntiRecordVisualHold = value == true
                    if value == false then
                        pcall(arEndVisualHold)
                    else
                        if anti.AntiRecordEnabled then
                            local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                            if root then
                                task.spawn(function() pcall(arBeginVisualHold, root.CFrame) end)
                            end
                        end
                    end
                end,
            })
        end
        anti.AntiRecordVisualHold = true
    end

    local AutoStealMainSection = MainTab:Section({
        Title = "Auto Steal Egg",
        Icon = "egg",
        Box = true,
        BoxBorder = true,
        Opened = true,
    })

    local EventMainSection = MainTab:Section({
        Title = "Event - Dr Scramble",
        Icon = "zap",
        Box = true,
        BoxBorder = true,
        Opened = true,
    })

    local function isMountableTreadmill(part)
        if not part or not part:IsA("BasePart") or part.Name ~= "TreadmillBottom" then
            return false
        end
        local plots = Workspace:FindFirstChild("Plots")
        if plots and part:IsDescendantOf(plots) then
            local okPlot, plot = pcall(function()
                return require(ReplicatedStorage.Client.PlotState).ResolvePlot()
            end)
            local myPlotFolder = okPlot and plot and plot.PlotFolder
            if myPlotFolder and part:IsDescendantOf(myPlotFolder) then
                return true
            end
            return false
        end
        return true
    end

    do
        local BatAura = {
            Enabled = false,
            Mode = "Smooth Chase (Hunt)",
            Speed = 700,
            Whitelist = {},
            TargetCooldowns = {},
            Running = false,
            RunId = 0,
            Thread = nil,
            DropdownControl = nil,
        }

        local lastBatTreadmillEscape = 0
        local function batEscapeTreadmill()
            local stealEngine = ScriptEnv.SAE_AutoSteal
            if stealEngine and stealEngine.ForceExitTreadmill and stealEngine.IsOnTreadmill and stealEngine.IsOnTreadmill() then
                stealEngine.ForceExitTreadmill(2)
                return
            end

            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if not hum then return end
            if not hum.Sit and not hum.PlatformStand then return end
            if os.clock() - lastBatTreadmillEscape < 0.3 then return end
            lastBatTreadmillEscape = os.clock()

            pcall(function()
                local Remotes = require(ReplicatedStorage.Shared.Remotes)
                if Remotes and Remotes.Treadmill and Remotes.Treadmill.AskDoff then
                    Remotes.Treadmill.AskDoff:InvokeServer()
                end
            end)

            pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Seated, false) end)
            hum.Sit = false
            hum.PlatformStand = false
            hum.Jump = true
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end)
            task.delay(0.05, function()
                pcall(function() hum:ChangeState(Enum.HumanoidStateType.Running) end)
            end)
        end

        local function findBatTool()
            local char = LocalPlayer.Character
            local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
            local function checkBat(item)
                if not item or not item:IsA("Tool") then return false end
                local itemType = tostring(item:GetAttribute("ItemType") or "")
                if itemType == "Asset" or itemType == "EggTool" or itemType == "MutationConsumable" then return false end
                if item:GetAttribute("IsBat") == true then return true end
                local name = item.Name:lower()
                local gName = tostring(item:GetAttribute("GearName") or ""):lower()
                if itemType == "Gear" or gName ~= "" then
                    return gName:find("bat") or name:find("bat") or gName:find("katana") or gName:find("axe") or gName:find("staff") or gName:find("sword")
                end
                return name:find("bat") ~= nil
            end
            if char then
                for _, item in ipairs(char:GetChildren()) do
                    if checkBat(item) then return item end
                end
            end
            if bp then
                for _, item in ipairs(bp:GetChildren()) do
                    if checkBat(item) then return item end
                end
            end
            return nil
        end

        local function ensureBatEquipped()
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local bat = findBatTool()
            if not bat or not hum then return nil end
            if bat.Parent ~= char then
                pcall(function() hum:EquipTool(bat) end)
                task.wait(0.04)
            end
            return bat
        end

        local BAT_BASE_RANGE = 15
        local BAT_HIT_TOLERANCE = 2
        local BAT_LOCAL_GATE = 0.1
        local BAT_LEAD_EXTRA = 0.05
        local BAT_LEAD_MAX = 90
        local batGearsDirectory = nil
        local batRagdollLib = nil
        local batLastSwingAt = 0
        local batMotionSamples = setmetatable({}, { __mode = "k" })

        local function batNetworkLead(speed)
            local ping = 0.06
            pcall(function()
                local value = LocalPlayer:GetNetworkPing()
                if type(value) == "number" and value > 0 then ping = value end
            end)
            return math.clamp(ping * 1.25 + BAT_LEAD_EXTRA
                + math.clamp((tonumber(speed) or 0) / 1800, 0, 0.14), 0.06, 0.5)
        end

        local function batTargetMotion(targetRoot, targetHum)
            local now = os.clock()
            local position = targetRoot.Position
            local velocity = targetRoot.AssemblyLinearVelocity
            local flatVelocity = Vector3.new(velocity.X, 0, velocity.Z)
            local sample = batMotionSamples[targetRoot]
            local measured = Vector3.zero
            if sample then
                local elapsed = now - sample.Time
                if elapsed > 0.008 and elapsed <= 0.5 then
                    measured = (position - sample.Position) / elapsed
                    measured = Vector3.new(measured.X, 0, measured.Z)
                end
            end
            batMotionSamples[targetRoot] = { Position = position, Time = now }

            local direction = flatVelocity
            if measured.Magnitude > direction.Magnitude then direction = measured end
            local speed = math.max(flatVelocity.Magnitude, measured.Magnitude)
            if targetHum and targetHum.MoveDirection.Magnitude > 0.1 then
                local inputDirection = Vector3.new(
                    targetHum.MoveDirection.X, 0, targetHum.MoveDirection.Z
                )
                speed = math.max(speed, targetHum.WalkSpeed)
                if direction.Magnitude <= 1 or inputDirection:Dot(direction.Unit) > 0.2 then
                    direction = inputDirection.Unit * speed
                end
            end
            return direction, math.clamp(speed, 0, 450)
        end

        local function batPredictedPosition(targetRoot, targetHum)
            if not targetRoot then return nil end
            local position = targetRoot.Position
            local flat, speed = batTargetMotion(targetRoot, targetHum)
            if speed <= 2 or flat.Magnitude <= 0.01 then return position end
            local lead = math.min(speed * batNetworkLead(speed), BAT_LEAD_MAX)
            return position + flat.Unit * lead
        end

        local function ragdollLib()
            if batRagdollLib == nil then
                local ok, mod = pcall(require, ReplicatedStorage.Shared.Modules.Ragdoll)
                batRagdollLib = (ok and type(mod) == "table") and mod or false
            end
            return batRagdollLib or nil
        end

        local function isCharRagdolled(char)
            if not char then return false end
            local lib = ragdollLib()
            if not lib or type(lib.IsRagdolled) ~= "function" then return false end
            local ok, result = pcall(lib.IsRagdolled, char)
            return ok and result == true
        end

        local function isPlayerDown(plr)
            if not plr then return false end
            local okAttr, endTime = pcall(function() return plr:GetAttribute("RagdollEndTime") end)
            if okAttr and type(endTime) == "number" and Workspace:GetServerTimeNow() < endTime then
                return true
            end
            return isCharRagdolled(plr.Character)
        end

        local function batHitboxScalar()
            return Workspace:GetAttribute("DragonEggEventActive") == true and 2.5 or 1
        end

        local function isPlayerInSafeZone(plr)
            if not plr or not plr.Character then return true end
            local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
            if not hrp then return true end

            local okGuard, Guard = pcall(function()
                return require(ReplicatedStorage.Client.ToolGameplayGuard)
            end)
            if okGuard and Guard then
                if Guard.IsInsideSafeZone then
                    local okVal, inSafe = pcall(Guard.IsInsideSafeZone, plr)
                    if okVal and inSafe == true then return true end
                end
                if Guard.IsInsideArena then
                    local okVal, inArena = pcall(Guard.IsInsideArena, plr)
                    if okVal and inArena == false then return true end
                end
            end

            local CollectionService = game:GetService("CollectionService")
            for _, zone in ipairs(CollectionService:GetTagged("SafeZone")) do
                if zone:IsA("BasePart") and zone:IsDescendantOf(Workspace) then
                    local rel = zone.CFrame:PointToObjectSpace(hrp.Position)
                    local half = zone.Size * 0.5
                    if math.abs(rel.X) <= half.X and math.abs(rel.Y) <= half.Y and math.abs(rel.Z) <= half.Z then
                        return true
                    end
                end
            end

            local plots = Workspace:FindFirstChild("Plots")
            if plots then
                for _, plot in ipairs(plots:GetChildren()) do
                    if plot:IsA("Model") then
                        local cf, sz = plot:GetBoundingBox()
                        local rel = cf:PointToObjectSpace(hrp.Position)
                        local half = sz * 0.5
                        if math.abs(rel.X) <= half.X and math.abs(rel.Z) <= half.Z and math.abs(rel.Y) <= half.Y + 10 then
                            return true
                        end
                    end
                end
            end

            return false
        end

        local function isTargetValid(plr, ignoreCooldown)
            if not plr or plr == LocalPlayer or not plr.Parent then return false end
            local name = plr.Name
            local userId = tostring(plr.UserId)
            if BatAura.Whitelist[name] == true or BatAura.Whitelist[userId] == true then
                return false
            end

            if not ignoreCooldown and (BatAura.TargetCooldowns[plr] or 0) > os.clock() then
                return false
            end

            local char = plr.Character
            if not char or not char.Parent then return false end
            local hrp = char:FindFirstChild("HumanoidRootPart")
            local hum = char:FindFirstChildOfClass("Humanoid")
            if not hrp or not hum or hum.Health <= 0 then return false end

            if isPlayerDown(plr) then return false end

            if isPlayerInSafeZone(plr) then
                return false
            end

            return true
        end

        local function batRangeBonus(tool)
            if batGearsDirectory == nil then
                local ok, Gears = pcall(require, ReplicatedStorage.Data.Gears)
                batGearsDirectory = (ok and type(Gears) == "table" and type(Gears.Directory) == "table")
                    and Gears.Directory or false
            end
            if not batGearsDirectory or not tool then return 0 end
            local names = { tool.Name }
            local okAttr, gearName = pcall(function() return tool:GetAttribute("GearName") end)
            if okAttr and type(gearName) == "string" then table.insert(names, gearName) end
            for _, name in ipairs(names) do
                local config = batGearsDirectory[name]
                local data = type(config) == "table" and config.BatControllerData
                local bonus = type(data) == "table" and tonumber(data.RangeBonus)
                if bonus then return bonus end
            end
            return 0
        end

        local function batHitRange(tool)
            return (BAT_BASE_RANGE + batRangeBonus(tool) + BAT_HIT_TOLERANCE) * batHitboxScalar()
        end

        local function batSwingReady(tool)
            if os.clock() - batLastSwingAt < BAT_LOCAL_GATE then return false end
            if tool then
                local okAttr, endTime = pcall(function() return tool:GetAttribute("CooldownEndTime") end)
                if okAttr and type(endTime) == "number" and endTime > 0
                    and Workspace:GetServerTimeNow() < endTime
                then
                    return false
                end
            end
            return true
        end

        local function executeBatStrike(targetPlr)
            local bat = ensureBatEquipped()
            if not bat then return false end
            if not batSwingReady(bat) then return false end

            local myChar = LocalPlayer.Character
            local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
            if not myHrp or isCharRagdolled(myChar) then return false end

            if isPlayerInSafeZone(LocalPlayer) then return false end

            local targetChar = targetPlr and targetPlr.Character
            local targetHrp = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
            if not targetHrp then return false end

            if isPlayerDown(targetPlr) then return false end
            if isPlayerInSafeZone(targetPlr) then return false end

            local targetHum = targetChar:FindFirstChildOfClass("Humanoid")
            local serverPos = batPredictedPosition(targetHrp, targetHum) or targetHrp.Position
            local range = batHitRange(bat)
            local localDistance = (targetHrp.Position - myHrp.Position).Magnitude
            local serverDistance = (serverPos - myHrp.Position).Magnitude
            if math.min(localDistance, serverDistance) > range then return false end

            local ok, Remotes = pcall(function()
                return require(ReplicatedStorage.Shared.Remotes)
            end)
            local traceId = string.format("%d:%d:%d", LocalPlayer.UserId, math.random(1000, 9999), math.floor(Workspace:GetServerTimeNow() * 1000))

            batLastSwingAt = os.clock()

            if ok and Remotes and Remotes.BatSwing and Remotes.BatSwing.Trigger then
                pcall(function()
                    Remotes.BatSwing.Trigger:FireServer(targetPlr, traceId)
                end)
            else
                local triggerRemote = ReplicatedStorage:FindFirstChild("Packages")
                    and ReplicatedStorage.Packages:FindFirstChild("Networking")
                    and ReplicatedStorage.Packages.Networking:FindFirstChild("RE/BatSwing/Trigger")
                if triggerRemote then
                    pcall(function() triggerRemote:FireServer(targetPlr, traceId) end)
                end
            end
            return true
        end

        local BAT_MAX_SPEED = 800
        local BAT_MAX_CHUNK = 160
        local BAT_FLING_BREAK = 100
        local BAT_RECOVERY_DISTANCE = 180

        local function chaseAndStrikeTarget(targetPlr, targetRoot)
            local char = LocalPlayer.Character
            local myHrp = char and char:FindFirstChild("HumanoidRootPart")
            if not char or not myHrp or not targetRoot or not targetRoot.Parent then return false end

            ensureBatEquipped()

            local restoreCollide = {}
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    restoreCollide[part] = part.CanCollide
                    part.CanCollide = false
                end
            end

            local function releaseNoclip()
                for part, originalCanCollide in pairs(restoreCollide) do
                    if part.Parent then
                        pcall(function() part.CanCollide = originalCanCollide end)
                    end
                end
            end

            local function moveSpeed()
                return math.clamp(BatAura.Speed or 700, 50, BAT_MAX_SPEED)
            end

            local function standPoint()
                local targetHum = targetPlr.Character
                    and targetPlr.Character:FindFirstChildOfClass("Humanoid")
                local pos = batPredictedPosition(targetRoot, targetHum) or targetRoot.Position
                local moveFlat = batTargetMotion(targetRoot, targetHum)

                if moveFlat.Magnitude > 0.1 then
                    return pos
                end

                local back = targetRoot.CFrame.LookVector
                local flat = Vector3.new(back.X, 0, back.Z)
                if flat.Magnitude > 0.05 then
                    flat = flat.Unit * 4
                else
                    flat = Vector3.new(0, 0, 4)
                end
                return pos - flat
            end

            local function stillRunning()
                return BatAura.Enabled and BatAura.Running
                    and targetPlr.Parent and targetRoot.Parent and myHrp.Parent
            end

            local lastSafeCFrame = myHrp.CFrame
            local function stabilizeRoot()
                if not myHrp.Parent then return false end
                local displacement = (myHrp.Position - lastSafeCFrame.Position).Magnitude
                local velocity = myHrp.AssemblyLinearVelocity.Magnitude
                local fallenY = Workspace.FallenPartsDestroyHeight
                local invalidY = myHrp.Position.Y < fallenY + 20
                if displacement > BAT_RECOVERY_DISTANCE or velocity > 3500 or invalidY then
                    myHrp.CFrame = lastSafeCFrame
                    myHrp.AssemblyLinearVelocity = Vector3.zero
                    myHrp.AssemblyAngularVelocity = Vector3.zero
                    RunService.Heartbeat:Wait()
                    return false
                end
                return true
            end

            local function boundedDestination(destination)
                local delta = destination - myHrp.Position
                local y = math.clamp(delta.Y, -12, 12)
                local flat = Vector3.new(delta.X, 0, delta.Z)
                if flat.Magnitude > BAT_MAX_CHUNK then
                    flat = flat.Unit * BAT_MAX_CHUNK
                end
                return myHrp.Position + flat + Vector3.new(0, y, 0)
            end

            local function hopTo(destination)
                destination = boundedDestination(destination)
                local from = myHrp.Position
                local distance = (destination - from).Magnitude
                if distance <= 2 then return true end
                local duration = distance / moveSpeed()
                local tween = TweenService:Create(myHrp, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
                    CFrame = CFrame.new(destination, destination + (targetRoot.Position - destination)),
                })
                local done = false
                local connection = tween.Completed:Connect(function() done = true end)
                tween:Play()
                local deadline = os.clock() + duration + 0.5
                while not done and os.clock() < deadline do
                    if not stillRunning() then
                        pcall(function() tween:Cancel() end)
                        connection:Disconnect()
                        return false
                    end
                    myHrp.AssemblyLinearVelocity = Vector3.zero
                    myHrp.AssemblyAngularVelocity = Vector3.zero
                    if not stabilizeRoot() then
                        pcall(function() tween:Cancel() end)
                        connection:Disconnect()
                        return false
                    end
                    RunService.Heartbeat:Wait()
                end
                if not done then pcall(function() tween:Cancel() end) end
                connection:Disconnect()
                myHrp.AssemblyLinearVelocity = Vector3.zero
                myHrp.AssemblyAngularVelocity = Vector3.zero
                lastSafeCFrame = myHrp.CFrame
                RunService.Heartbeat:Wait()
                return true
            end

            local approach = standPoint()
            local travel = (approach - myHrp.Position).Magnitude
            if travel > 4 then
                local from = myHrp.Position
                local chunks = math.max(1, math.ceil(travel / BAT_MAX_CHUNK))
                for chunk = 1, chunks do
                    if not stillRunning() then break end

                    local goal = (chunk == chunks) and standPoint()
                        or from:Lerp(approach, chunk / chunks)
                    if not hopTo(goal) then break end
                end
            end

            local strikeDeadline = os.clock() + 10.0
            local lastTargetPos = targetRoot.Position
            local lastFrame = os.clock()
            local struck = false

            while BatAura.Enabled and BatAura.Running and os.clock() < strikeDeadline do
                batEscapeTreadmill()

                if not stillRunning() or not isTargetValid(targetPlr, true) then
                    break
                end

                local now = os.clock()
                local dt = math.min(now - lastFrame, 0.1)
                lastFrame = now

                local targetPos = targetRoot.Position
                local _, targetSpeed = batTargetMotion(targetRoot,
                    targetPlr.Character and targetPlr.Character:FindFirstChildOfClass("Humanoid"))
                local teleportDistance = math.max(BAT_FLING_BREAK,
                    targetSpeed * math.max(dt, 0.05) * 8 + 30)
                if (targetPos - lastTargetPos).Magnitude > teleportDistance then
                    break
                end
                lastTargetPos = targetPos

                local pos = standPoint()
                local delta = pos - myHrp.Position
                local distance = delta.Magnitude
                local maxStep = moveSpeed() * dt

                if distance > maxStep then
                    pos = myHrp.Position + delta.Unit * maxStep
                end

                pos = boundedDestination(pos)

                myHrp.CFrame = CFrame.new(pos, targetPos)
                myHrp.AssemblyLinearVelocity = Vector3.zero
                myHrp.AssemblyAngularVelocity = Vector3.zero

                RunService.Heartbeat:Wait()
                if not stabilizeRoot() then break end
                lastSafeCFrame = myHrp.CFrame

                struck = executeBatStrike(targetPlr) or struck

                RunService.Heartbeat:Wait()
            end

            releaseNoclip()
            myHrp.AssemblyLinearVelocity = Vector3.zero
            myHrp.AssemblyAngularVelocity = Vector3.zero

            task.wait(0.08)
            if struck then BatAura.TargetCooldowns[targetPlr] = os.clock() + 0.5 end
            return struck
        end

        local function startBatAuraLoop()
            if BatAura.Running then return end
            BatAura.Running = true
            BatAura.RunId += 1
            local runId = BatAura.RunId

            BatAura.Thread = task.spawn(function()
                while BatAura.Enabled and BatAura.Running and BatAura.RunId == runId do
                    local char = LocalPlayer.Character
                    local myHrp = char and char:FindFirstChild("HumanoidRootPart")
                    local hum = char and char:FindFirstChildOfClass("Humanoid")

                    if not char or not myHrp or not hum or hum.Health <= 0 then
                        task.wait(0.2)
                        continue
                    end

                    batEscapeTreadmill()

                    local now = os.clock()
                    for plr, exp in pairs(BatAura.TargetCooldowns) do
                        if exp <= now then BatAura.TargetCooldowns[plr] = nil end
                    end

                    local eligibleTargets = {}
                    for _, p in ipairs(Players:GetPlayers()) do
                        if isTargetValid(p, false) then
                            local pRoot = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
                            if pRoot then
                                local dist = (pRoot.Position - myHrp.Position).Magnitude
                                table.insert(eligibleTargets, {player = p, root = pRoot, distance = dist})
                            end
                        end
                    end

                    if #eligibleTargets == 0 then
                        for _, p in ipairs(Players:GetPlayers()) do
                            if isTargetValid(p, true) then
                                local pRoot = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
                                if pRoot then
                                    local dist = (pRoot.Position - myHrp.Position).Magnitude
                                    table.insert(eligibleTargets, {player = p, root = pRoot, distance = dist})
                                end
                            end
                        end
                    end

                    if #eligibleTargets == 0 then
                        task.wait(0.15)
                        continue
                    end

                    table.sort(eligibleTargets, function(a, b) return a.distance < b.distance end)

                    if BatAura.Mode == "Proximity (Near Player)" then
                        local nearest = eligibleTargets[1]
                        if nearest and nearest.distance <= 22 then
                            executeBatStrike(nearest.player)
                            task.wait(0.05)
                        else
                            task.wait(0.04)
                        end
                    elseif BatAura.Mode == "Smooth Chase (Hunt)" then
                        local target = eligibleTargets[1]
                        if target and target.root and target.player.Parent then
                            chaseAndStrikeTarget(target.player, target.root)
                            task.wait(0.03)
                        else
                            task.wait(0.08)
                        end
                    else
                        task.wait(0.1)
                    end
                end
                if BatAura.RunId == runId then BatAura.Running = false end
            end)
        end

        local function stopBatAuraLoop()
            BatAura.RunId += 1
            BatAura.Running = false
            BatAura.Thread = nil
        end

        local function getOnlinePlayerNames()
            local names = {}
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer then
                    table.insert(names, p.Name)
                end
            end
            return names
        end

        local BatCombatSection = MainTab:Section({
            Title = "Bat Aura & Combat",
            ConfigFlagKey = "BatCombat",
            Icon = "swords",
            Box = true,
            BoxBorder = true,
            Opened = true,
        })

        BatCombatSection:Toggle({
            Title = "Bat Aura",
            Flag = "Combat_BatAuraEnabled",
            Value = false,
            Callback = function(value)
                BatAura.Enabled = value and true or false
                if BatAura.Enabled then
                    local godmode = ScriptEnv.SAE_Godmode
                    if godmode and type(godmode.SetBatAuraLock) == "function" then
                        godmode.SetBatAuraLock(true)
                    end
                    startBatAuraLoop()
                else
                    stopBatAuraLoop()
                    local godmode = ScriptEnv.SAE_Godmode
                    if godmode and type(godmode.SetBatAuraLock) == "function" then
                        godmode.SetBatAuraLock(false)
                    end
                end
            end,
        })

        BatCombatSection:Dropdown({
            Title = "Bat Aura Mode",
            Flag = "Combat_BatAuraMode",
            Values = {"Smooth Chase (Hunt)", "Proximity (Near Player)"},
            Value = "Smooth Chase (Hunt)",
            Callback = function(value)
                BatAura.Mode = tostring(value or "Smooth Chase (Hunt)")
            end,
        })

        BatCombatSection:Slider({
            Title = "Chase Speed",
            Flag = "Combat_BatAuraSpeed",
            Value = {Min = 100, Max = 1500, Default = 700},
            Step = 50,
            Callback = function(value)
                BatAura.Speed = math.clamp(tonumber(value) or 700, 100, 1500)
            end,
        })

        local whitelistDropdown = BatCombatSection:Dropdown({
            Title = "Whitelist Players (No Attack)",
            Flag = "Combat_BatAuraWhitelist",
            Values = getOnlinePlayerNames(),
            Multi = true,
            AllowNone = true,
            Value = {},
            Callback = function(values)
                BatAura.Whitelist = {}
                if type(values) == "table" then
                    for k, v in pairs(values) do
                        if v == true then
                            BatAura.Whitelist[k] = true
                        elseif type(v) == "string" and v ~= "None" then
                            BatAura.Whitelist[v] = true
                        end
                    end
                end
            end,
        })
        BatAura.DropdownControl = whitelistDropdown

        local function refreshWhitelistDropdown()
            if BatAura.DropdownControl and BatAura.DropdownControl.Refresh then
                pcall(function()
                    BatAura.DropdownControl:Refresh(getOnlinePlayerNames())
                end)
            end
        end

        Players.PlayerAdded:Connect(function()
            task.wait(1)
            refreshWhitelistDropdown()
        end)
        Players.PlayerRemoving:Connect(function()
            task.wait(0.5)
            refreshWhitelistDropdown()
        end)

        LocalPlayer.CharacterAdded:Connect(function(character)
            if not BatAura.Enabled then return end
            stopBatAuraLoop()
            table.clear(BatAura.TargetCooldowns)
            task.spawn(function()
                local root = character:WaitForChild("HumanoidRootPart", 8)
                local humanoid = character:FindFirstChildOfClass("Humanoid")
                    or character:WaitForChild("Humanoid", 8)
                if BatAura.Enabled and root and humanoid and humanoid.Health > 0 then
                    startBatAuraLoop()
                end
            end)
        end)

        ScriptEnv.SAE_BatAuraCleanup = function()
            BatAura.Enabled = false
            stopBatAuraLoop()
            local godmode = ScriptEnv.SAE_Godmode
            if godmode and type(godmode.SetBatAuraLock) == "function" then
                godmode.SetBatAuraLock(false)
            end
        end
    end

    do
        local utility = {
            Closed = false,
            Busy = false,
            AutoPlace = false,
            AutoHatch = false,
            AutoEquipBest = false,
            AutoUnequip = false,
            AutoSellPets = false,
            AutoSellEggs = false,
            AutoBaseUpgrade = false,
            AutoTreadmillUpgrade = false,
            AutoClaimIndex = false,
            AutoOffline = false,
            AutoFuse = false,
            AutoBuyTrail = false,
            PetSellRarities = {},
            PetSellMutations = {},
            PetKeepTypes = {},
            EggSellRarities = {},
            EggKeepTypes = {},
            FuseRarities = {},
            TrailWanted = {},
            NeverSellMutated = true,
            NeverSellEquipped = true,
            SellFallback = false,
            SellMaxScale = 10,
            FuseMaxScale = 10,
            PetSellInterval = 2,
            EggSellInterval = 2,
            FuseInterval = 8,
            LastRun = {},
            LastError = nil,
            LastAction = "Idle",
        }

        local modulesReady, EggState, PlotState, AssetRoster, Save, Remotes
        local Assets, RarityData, MutationData, Trails, Treadmills, BaseUpgrade, FuseKernel
        modulesReady, EggState, PlotState, AssetRoster, Save, Remotes,
            Assets, RarityData, MutationData, Trails, Treadmills, BaseUpgrade, FuseKernel = pcall(function()
                local client = ReplicatedStorage:FindFirstChild("Client") or ReplicatedStorage:WaitForChild("Client", 1)
                local data = ReplicatedStorage:FindFirstChild("Data") or ReplicatedStorage:WaitForChild("Data", 1)
                local shared = ReplicatedStorage:FindFirstChild("Shared") or ReplicatedStorage:WaitForChild("Shared", 1)
                local function safeReq(parent, ...)
                    local cur = parent
                    for _, name in ipairs({...}) do
                        if not cur then return nil end
                        cur = cur:FindFirstChild(name)
                    end
                    if cur and cur:IsA("ModuleScript") then
                        local ok, m = pcall(require, cur)
                        return ok and m or nil
                    end
                    return nil
                end
                return safeReq(client, "EggState"),
                    safeReq(client, "PlotState"),
                    safeReq(client, "AssetRoster"),
                    safeReq(shared, "Save"),
                    safeReq(shared, "Remotes"),
                    safeReq(data, "Assets"),
                    safeReq(data, "Rarity"),
                    safeReq(shared, "Modules", "Mutations"),
                    safeReq(data, "Trails"),
                    safeReq(data, "Treadmills"),
                    safeReq(client, "BaseUpgrade"),
                    safeReq(shared, "Util", "FuseKernel")
            end)
        utility.Ready = modulesReady

        local function readSave()
            local fn = Save and (Save.Get or Save.Peek)
            local ok, result = pcall(fn)
            return ok and type(result) == "table" and result or nil
        end

        local function selectionSet(value)
            local result = {}
            if type(value) == "string" then
                if value ~= SELECT_ALL_OPTION then result[value] = true end
            elseif type(value) == "table" then
                for key, item in pairs(value) do
                    local selected = item == true and tostring(key)
                        or (type(item) == "string" and item or nil)
                    if selected and selected ~= SELECT_ALL_OPTION then result[selected] = true end
                end
            end
            return result
        end

        local function containsMutation(record, wanted)
            if next(wanted) == nil then return true end
            if type(record.BaseMutation) == "string" and wanted[record.BaseMutation] then return true end
            for _, mutation in pairs(type(record.Mutations) == "table" and record.Mutations or {}) do
                if wanted[tostring(mutation)] then return true end
            end
            return false
        end

        local function isMutated(record)
            return type(record.BaseMutation) == "string"
                or (type(record.Mutations) == "table" and next(record.Mutations) ~= nil)
        end

        local function rarityOf(category)
            local config = Assets.Directory[tostring(category or "")]
            local rarity = config and config.Rarity
            return type(rarity) == "table" and tostring(rarity._id or rarity.DisplayName or "Common")
                or tostring(rarity or "Common")
        end

        local function equippedSet(save)
            local result = {}
            for _, uid in pairs(type(save.EquippedAssets) == "table" and save.EquippedAssets or {}) do
                result[tostring(uid)] = true
            end
            return result
        end

        local function ownedEggs()
            pcall(EggState.SyncOwnedEggs)
            local ok, records = pcall(EggState.ReadOwnerEggs, LocalPlayer.UserId)
            if ok and type(records) == "table" then return records end
            local save = readSave()
            return save and type(save.EggInventory) == "table" and save.EggInventory or {}
        end

        local function stealAutomationActive()
            local steal = ScriptEnv.SAE_AutoSteal
            if type(steal) ~= "table" then return false end

            return steal.Busy == true or steal.Carrying == true
        end

        local function utilityCharacter()
            local character = LocalPlayer.Character
            if not character then return nil, nil, nil end
            return character, character:FindFirstChild("HumanoidRootPart"),
                character:FindFirstChildOfClass("Humanoid")
        end

        local function travelToUtilityPoint(position)
            if typeof(position) ~= "Vector3" or stealAutomationActive() then return false end
            local _, root, humanoid = utilityCharacter()
            if not root or not humanoid then return false end
            local delta = position - root.Position
            if delta.Magnitude <= 8 then return true end
            local flat = Vector3.new(delta.X, 0, delta.Z)
            local goal = flat.Magnitude > 0.01
                and CFrame.lookAt(position, position + flat.Unit) or CFrame.new(position)
            local oldRotate, oldPlatform = humanoid.AutoRotate, humanoid.PlatformStand
            humanoid.Sit = false
            humanoid.PlatformStand = true
            humanoid.AutoRotate = false
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            local tween = TweenService:Create(root, TweenInfo.new(
                math.max(delta.Magnitude / 800, 0.06), Enum.EasingStyle.Linear
            ), { CFrame = goal })
            local completed = false
            local connection = tween.Completed:Connect(function(state)
                completed = state == Enum.PlaybackState.Completed
            end)
            tween:Play()
            local deadline = os.clock() + math.max(delta.Magnitude / 800, 0.06) + 1
            while not completed and os.clock() < deadline and not utility.Closed do task.wait(0.02) end
            if not completed then pcall(function() tween:Cancel() end) end
            connection:Disconnect()
            humanoid.PlatformStand = oldPlatform
            humanoid.AutoRotate = oldRotate
            pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Running) end)
            task.wait(0.15)
            return root.Parent ~= nil and (root.Position - position).Magnitude <= 18
        end

        local function findToolByUid(uid)
            local character = LocalPlayer.Character
            local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
            for _, container in ipairs({ character, backpack }) do
                if container then
                    for _, tool in ipairs(container:GetChildren()) do
                        if tool:IsA("Tool") and tostring(
                            tool:GetAttribute("UID") or tool:GetAttribute("Uid") or ""
                        ) == tostring(uid) then
                            return tool
                        end
                    end
                end
            end
            return nil
        end

        local function holdUid(uid)
            local save = readSave()
            if save and type(save.EggInventory) == "table" and save.EggInventory[uid] then
                pcall(EggState.WearEggTool, uid)
                task.wait(0.15)
            end
            local character, _, humanoid = utilityCharacter()
            local tool = findToolByUid(uid)
            if not character or not humanoid or not tool then return false end
            if tool.Parent == character then return true end
            pcall(function() humanoid:EquipTool(tool) end)
            local deadline = os.clock() + 1
            while os.clock() < deadline do
                if tool.Parent == character then return true end
                task.wait(0.05)
            end
            return false
        end

        local function uidStillOwned(uid)
            local save = readSave()
            if not save then return true end
            return (type(save.Inventory) == "table" and save.Inventory[uid] ~= nil)
                or (type(save.EggInventory) == "table" and save.EggInventory[uid] ~= nil)
        end

        local function placementCFrames(records)
            local plot = PlotState.ResolvePlot()
            if not plot or not plot.PetArea or not plot.CenterPoint then return {} end
            local occupied = {}
            for _, record in pairs(records or {}) do
                local placement = type(record) == "table" and record.Placement
                local cf = type(placement) == "table" and placement.LocalCFrame
                if typeof(cf) == "CFrame" then table.insert(occupied, cf.Position) end
            end
            local result, size = {}, plot.PetArea.Size
            for x = -size.X * 0.5 + 5, size.X * 0.5 - 5, 7 do
                for z = -size.Z * 0.5 + 5, size.Z * 0.5 - 5, 7 do
                    local world = plot.PetArea.CFrame:PointToWorldSpace(Vector3.new(x, 1, z))
                    local localCF = plot.CenterPoint.CFrame:ToObjectSpace(CFrame.new(world))
                    local free = true
                    for _, position in ipairs(occupied) do
                        if (position - localCF.Position).Magnitude < 3 then free = false break end
                    end
                    if free then table.insert(result, localCF) end
                end
            end
            return result
        end

        local function ensureAtPetArea()
            local plot = PlotState.ResolvePlot()
            local area = plot and plot.PetArea
            if not area or not area:IsA("BasePart") then return false end
            local _, root = utilityCharacter()
            if root and (root.Position - area.Position).Magnitude <= 30 then return true end

            return travelToUtilityPoint(area.Position + Vector3.new(0, 4, 0))
        end

        local function placeAllEggs()
            if stealAutomationActive() or not ensureAtPetArea() then return 0 end
            local records = ownedEggs()
            local slots = placementCFrames(records)
            local placed = 0
            for uid, record in pairs(records) do
                if utility.Closed then break end
                if type(uid) == "string" and type(record) == "table" and record.Placement == nil then
                    pcall(EggState.WearEggTool, uid)
                    local placedThisEgg = false
                    for index, localCF in ipairs(slots) do
                        local ok, accepted = pcall(EggState.PlantEgg, uid, localCF)
                        if ok and accepted == true then
                            table.remove(slots, index)
                            placed += 1
                            placedThisEgg = true
                            break
                        end
                    end

                    if not placedThisEgg or #slots == 0 then break end
                    task.wait(0.08)
                end
            end
            pcall(EggState.DoffEggTool)
            return placed
        end

        local function hatchAllReady()
            local records = ownedEggs()
            local hatched = 0
            for uid, record in pairs(records) do
                if utility.Closed then break end
                if type(uid) == "string" and type(record) == "table" and record.Placement ~= nil then
                    local readyOk, ready = pcall(EggState.IsReadyToHatch, uid)
                    if readyOk and ready == true then
                        local beginOk, began = pcall(EggState.BeginHatch, uid)
                        if beginOk and began == true then
                            local finishOk, finished = pcall(EggState.FinishHatch, uid)
                            if finishOk and finished == true then hatched += 1 end
                        end
                        task.wait(0.08)
                    end
                end
            end
            return hatched
        end

        local function equipBest()
            local ok, accepted = pcall(function() return Remotes.Haul.WearBest:InvokeServer() end)
            return ok and accepted == true
        end

        local function unequipAll()
            local save = readSave()
            local count = 0
            for _, uid in pairs(save and save.EquippedAssets or {}) do
                local ok, accepted = pcall(AssetRoster.DoffAsset, uid)
                if ok and accepted == true then count += 1 end
                task.wait(0.05)
            end
            return count
        end

        local function petSellable(allRarities)
            if not allRarities and next(utility.PetSellRarities) == nil then return {} end
            local save = readSave()
            local result = {}
            if not save or type(save.Inventory) ~= "table" then return result end
            local equipped = equippedSet(save)
            for uid, record in pairs(save.Inventory) do
                if type(uid) == "string" and type(record) == "table"
                    and record.IsFavorite ~= true and record.InFuse ~= true
                    and not utility.PetKeepTypes[tostring(record.Category)]
                    and (allRarities or utility.PetSellRarities[rarityOf(record.Category)] == true)
                    and (tonumber(record.Scale) or 0) <= utility.SellMaxScale
                    and (not utility.NeverSellMutated or not isMutated(record))
                    and (not utility.NeverSellEquipped or not equipped[uid])
                    and containsMutation(record, utility.PetSellMutations)
                then
                    table.insert(result, uid)
                end
            end
            return result
        end

        local function eggSellable(allRarities)
            if not allRarities and next(utility.EggSellRarities) == nil then return {} end
            local save = readSave()
            local result = {}
            if not save or type(save.EggInventory) ~= "table" then return result end
            for uid, record in pairs(save.EggInventory) do
                if type(uid) == "string" and type(record) == "table"
                    and record.Placement == nil and record.IsFavorite ~= true
                    and not utility.EggKeepTypes[tostring(record.AssetCategory)]
                    and (allRarities or utility.EggSellRarities[rarityOf(record.AssetCategory)] == true)
                then
                    table.insert(result, uid)
                end
            end
            return result
        end

        local function bulkSellCombined(petUids, eggUids)
            if stealAutomationActive() then return 0 end
            petUids = type(petUids) == "table" and petUids or {}
            eggUids = type(eggUids) == "table" and eggUids or {}
            if #petUids == 0 and #eggUids == 0 then return 0 end

            local sellSelRemote = Remotes.PetSatchel and Remotes.PetSatchel.SellSelection
            local sellEveryRemote = Remotes.PetSatchel and Remotes.PetSatchel.SellEveryPet
            local sellPetRemote = Remotes.PetSatchel and Remotes.PetSatchel.SellPet

            local save = readSave()
            local equipped = equippedSet(save)
            local sold = 0

            for _, uid in ipairs(petUids) do
                if equipped[uid] then
                    pcall(AssetRoster.DoffAsset, uid)
                end
            end

            for i = 1, #petUids, 512 do
                if utility.Closed then break end
                local pBatch = {}
                for j = i, math.min(i + 511, #petUids) do
                    table.insert(pBatch, petUids[j])
                end
                if #pBatch > 0 then
                    local sent = false
                    if sellSelRemote then
                        local ok = pcall(function()
                            sellSelRemote:FireServer({
                                Assets = pBatch,
                                Eggs = {}
                            })
                        end)
                        if ok then sent = true end
                    end
                    if not sent and sellEveryRemote then
                        pcall(function() sellEveryRemote:FireServer(pBatch) end)
                    elseif not sent and sellPetRemote then
                        pcall(function() sellPetRemote:FireServer(pBatch) end)
                    end
                    sold = sold + #pBatch
                    if i + 512 <= #petUids then
                        task.wait(0.03)
                    end
                end
            end

            for i = 1, #eggUids, 512 do
                if utility.Closed then break end
                local eBatch = {}
                for j = i, math.min(i + 511, #eggUids) do
                    table.insert(eBatch, eggUids[j])
                end
                if #eBatch > 0 then
                    local sent = false
                    if sellSelRemote then
                        local ok = pcall(function()
                            sellSelRemote:FireServer({
                                Assets = {},
                                Eggs = eBatch
                            })
                        end)
                        if ok then sent = true end
                    end
                    if not sent and sellPetRemote then
                        pcall(function() sellPetRemote:FireServer(eBatch) end)
                    end
                    sold = sold + #eBatch
                    if i + 512 <= #eggUids then
                        task.wait(0.03)
                    end
                end
            end
            return sold
        end

        local function bulkSellPets(uids)
            return bulkSellCombined(uids, {})
        end

        local function bulkSellEggs(uids)
            return bulkSellCombined({}, uids)
        end

        local function saleRemote(uid)
            if not uidStillOwned(uid) or stealAutomationActive() then return false end
            local save = readSave()
            if save and type(save.EggInventory) == "table" and save.EggInventory[uid] then
                return bulkSellEggs({ uid }) > 0
            else
                return bulkSellPets({ uid }) > 0
            end
        end

        local function sellList(list, forceKind)
            if type(list) ~= "table" or #list == 0 then return 0 end
            if stealAutomationActive() then return 0 end
            local save = readSave()
            local petUids = {}
            local eggUids = {}
            for _, uid in ipairs(list) do
                if type(uid) == "string" then
                    if forceKind == "egg" or (save and type(save.EggInventory) == "table" and save.EggInventory[uid] ~= nil) then
                        table.insert(eggUids, uid)
                    else
                        table.insert(petUids, uid)
                    end
                end
            end
            return bulkSellCombined(petUids, eggUids)
        end

        local function upgradeBase()
            local save = readSave()
            if not save then return false end
            local okAffordable, affordable = pcall(BaseUpgrade.IsNextTierAffordable, save)
            if not okAffordable or affordable ~= true then return false end
            local ok, result = pcall(BaseUpgrade.PurchaseNextTier)
            return ok and result ~= false
        end

        local function upgradeTreadmill()
            local save = readSave()
            if not save then return false end
            local nextConfig = Treadmills.GetByUpgradeLevel((tonumber(save.TreadmillUpgradeLevel) or 0) + 1)
            if not nextConfig or (tonumber(save.Money) or 0) < (tonumber(nextConfig.Price) or math.huge) then return false end
            local ok, result = pcall(function()
                return Remotes.Treadmill.AskTierRaise:InvokeServer(nextConfig._id)
            end)
            return ok and result == true
        end

        local function claimIndex()
            local ok, result = pcall(function() return Remotes.Codex.AskRedeemAll:InvokeServer() end)
            return ok and result ~= false
        end

        local function claimOffline()
            local ok, summary = pcall(function() return Remotes.AwayEarnings.FetchSummary:InvokeServer() end)
            if not ok or type(summary) ~= "table" or (tonumber(summary.ClaimableAmount) or 0) <= 0 then return false end

            local collectOk, accepted, _, redeem = pcall(function()
                return Remotes.AwayEarnings.AskCollect:InvokeServer({ Kind = "Claim" })
            end)
            return collectOk and accepted == true and type(redeem) == "table"
        end

        local function fuseGroup()
            if next(utility.FuseRarities) == nil then return nil end
            local save = readSave()
            if not save or type(save.Inventory) ~= "table" then return nil end
            if save.FusionLocked == true then
                pcall(function() Remotes.Fusery.FinishReveal:InvokeServer() end)
                return nil
            end
            if type(save.FusionSlots) == "table" and next(save.FusionSlots) ~= nil then return nil end
            local equipped, groups = equippedSet(save), {}
            for uid, record in pairs(save.Inventory) do
                if type(uid) == "string" and type(record) == "table"
                    and record.IsFavorite ~= true and record.InFuse ~= true
                    and not equipped[uid] and not isMutated(record)
                    and utility.FuseRarities[rarityOf(record.Category)] == true
                    and (tonumber(record.Scale) or 0) <= utility.FuseMaxScale
                then
                    local eligibleOk, eligible = pcall(FuseKernel.MayEnterFuse, uid, record, record.Category, false)
                    if eligibleOk and eligible == true then
                        groups[record.Category] = groups[record.Category] or {}
                        table.insert(groups[record.Category], uid)
                    end
                end
            end
            for _, group in pairs(groups) do
                if #group >= 3 then return { group[1], group[2], group[3] }, save end
            end
            return nil
        end

        local function fuseOnce()
            local group, save = fuseGroup()
            if not group then return false end
            local records = { save.Inventory[group[1]], save.Inventory[group[2]], save.Inventory[group[3]] }
            local priceOk, price = pcall(FuseKernel.PriceFor, records)
            if not priceOk or (tonumber(save.Money) or 0) < (tonumber(price) or math.huge) then return false end
            local objects = Workspace:FindFirstChild("World")
            local machines = objects and objects:FindFirstChild("Machines")
            local fuseMachine = machines and machines:FindFirstChild("FuseMachine")
            if not fuseMachine then return false end
            local pivotOk, pivot = pcall(function() return fuseMachine:GetPivot() end)
            if not pivotOk or not travelToUtilityPoint(pivot.Position + Vector3.new(0, 4, 0)) then
                return false
            end
            if save.FusionInfoAcknowledged ~= true then
                pcall(function() Remotes.Fusery.ConfirmBriefing:InvokeServer() end)
            end
            for _, uid in ipairs(group) do
                local ok, accepted = pcall(function() return Remotes.Fusery.LoadPet:InvokeServer(uid) end)
                if not ok or accepted ~= true then return false end
                task.wait(0.12)
            end
            local ok, accepted = pcall(function() return Remotes.Fusery.BeginFuse:InvokeServer() end)
            return ok and accepted == true
        end

        local trailRows = {}
        for id, config in pairs(Trails and Trails.Directory or {}) do
            if type(config) == "table" and config.DisplayInShop ~= false then
                table.insert(trailRows, {
                    Id = tostring(config._id or id),
                    Name = tostring(config.DisplayName or id),
                    Price = tonumber(config.Price) or math.huge,
                })
            end
        end
        table.sort(trailRows, function(a, b) return a.Price < b.Price end)

        local function buyTrails()
            local save = readSave()
            if not save or next(utility.TrailWanted) == nil then return 0 end
            local owned, bought = type(save.TrailInventory) == "table" and save.TrailInventory or {}, 0
            for _, row in ipairs(trailRows) do
                if utility.TrailWanted[row.Name] and not owned[row.Id]
                    and (tonumber(save.Money) or 0) >= row.Price
                then
                    local ok, accepted = pcall(function()
                        return Remotes.Trailwear.AskPurchase:InvokeServer(row.Id)
                    end)
                    if ok and accepted == true then bought += 1 end
                    task.wait(0.2)
                    save = readSave() or save
                    owned = type(save.TrailInventory) == "table" and save.TrailInventory or owned
                end
            end
            return bought
        end

        local function runAction(name, action)
            if utility.Busy or utility.Closed then return end
            utility.Busy = true
            utility.LastAction = name
            local ok, result = xpcall(action, debug.traceback)
            utility.Busy = false
            if not ok then
                utility.LastError = tostring(result):match("^[^\n]+")
                warn("[FN Utility] " .. name .. ": " .. tostring(result))
            else
                utility.LastError = nil
                utility.LastResult = result
            end
            return ok, result
        end

        local function manual(name, action)
            task.spawn(function()
                local ok, result = runAction(name, action)
                local success = ok and result ~= false
                Notify(name, success and ("Done: " .. tostring(result or 0))
                    or ("No action completed" .. (utility.LastError and (": " .. utility.LastError) or "")),
                    success and "check" or "triangle-alert", 3)
            end)
        end

        local function due(key, interval)
            local now = os.clock()
            if now - (utility.LastRun[key] or 0) < interval then return false end
            utility.LastRun[key] = now
            return true
        end

        if modulesReady then
            task.spawn(function()
                while not utility.Closed and ScriptEnv.SAE_RunToken == entryToken do
                    task.wait(0.2)
                    if not utility.Busy and not stealAutomationActive() then
                        if utility.AutoHatch and due("Hatch", 1) then runAction("Auto Hatch Eggs", hatchAllReady)
                        elseif utility.AutoPlace and due("Place", 2) then runAction("Auto Place Eggs", placeAllEggs)
                        elseif utility.AutoUnequip and due("Unequip", 1) then runAction("Auto Unequip Pets", unequipAll)
                        elseif utility.AutoEquipBest and due("Equip", 5.2) then runAction("Auto Equip Best Pets", equipBest)
                        elseif utility.AutoSellPets and due("SellPets", utility.PetSellInterval) then runAction("Auto Sell Pets", function() return sellList(petSellable()) end)
                        elseif utility.AutoSellEggs and due("SellEggs", utility.EggSellInterval) then runAction("Auto Sell Eggs", function() return sellList(eggSellable()) end)
                        elseif utility.AutoBaseUpgrade and due("Base", 2) then runAction("Auto Upgrade Base", upgradeBase)
                        elseif utility.AutoTreadmillUpgrade and due("Treadmill", 2) then runAction("Auto Upgrade Treadmill", upgradeTreadmill)
                        elseif utility.AutoClaimIndex and due("Index", 10) then runAction("Auto Claim Index Rewards", claimIndex)
                        elseif utility.AutoOffline and due("Offline", 15) then runAction("Auto Offline Earnings", claimOffline)
                        elseif utility.AutoFuse and due("Fuse", utility.FuseInterval) then runAction("Fuse Machine Automation", fuseOnce)
                        elseif utility.AutoBuyTrail and due("Trail", 5) then runAction("Auto Buy Trail", buyTrails)
                        end
                    end
                end
            end)
        end

        ScriptEnv.SAE_UtilityAutomation = utility
        utility.PreviewSellablePets = petSellable
        utility.PreviewSellableEggs = eggSellable
        utility.PreviewOwnedEggs = ownedEggs
        utility.PreviewPlacementCFrames = function()
            local records = ownedEggs()
            return placementCFrames(records)
        end
        utility.PlaceAllEggs = placeAllEggs
        utility.HatchAllReady = hatchAllReady
        utility.SellUid = saleRemote
        utility.FuseOnce = fuseOnce
        utility.EquipBest = equipBest
        utility.UnequipAll = unequipAll
        ScriptEnv.SAE_UtilityCleanup = function()
            utility.Closed = true
            for key, value in pairs(utility) do
                if type(value) == "boolean" and key:sub(1, 4) == "Auto" then utility[key] = false end
            end
            if ScriptEnv.SAE_UtilityAutomation == utility then ScriptEnv.SAE_UtilityAutomation = nil end
        end

        task.wait()

        local petEggSection = MainTab:Section({
            Title = "Pet / Eggs", ConfigFlagKey = "PetEggs", Icon = "paw-print",
            Box = true, BoxBorder = true, Opened = true,
        })
        if not modulesReady then
            petEggSection:Paragraph({
                Title = "Game modules unavailable", Desc = "Pet/Egg automation could not start.",
                Image = "triangle-alert", ImageSize = 32,
            })
        else
            local equipBestToggle, unequipToggle
            petEggSection:Toggle({
                Title = "Auto Place Eggs", Value = false,
                Callback = function(value) utility.AutoPlace = value == true end,
            })
            petEggSection:Toggle({
                Title = "Auto Hatch Eggs", Value = false,
                Callback = function(value) utility.AutoHatch = value == true end,
            })
            petEggSection:Button({
                Title = "Place All Eggs", Icon = "package-plus",
                Callback = function() manual("Place All Eggs", placeAllEggs) end,
            })
            petEggSection:Button({
                Title = "Hatch All Ready Eggs", Icon = "egg",
                Callback = function() manual("Hatch All Ready Eggs", hatchAllReady) end,
            })
            equipBestToggle = petEggSection:Toggle({
                Title = "Auto Equip Best Pets", Value = false,
                Callback = function(value)
                    utility.AutoEquipBest = value == true
                    if value and utility.AutoUnequip then
                        utility.AutoUnequip = false
                        task.defer(function() unequipToggle:Set(false) end)
                    end
                end,
            })
            unequipToggle = petEggSection:Toggle({
                Title = "Auto Unequip Pets", Value = false,
                Callback = function(value)
                    utility.AutoUnequip = value == true
                    if value and utility.AutoEquipBest then
                        utility.AutoEquipBest = false
                        task.defer(function() equipBestToggle:Set(false) end)
                    end
                end,
            })
            petEggSection:Button({
                Title = "Equip Best Now", Icon = "sparkles",
                Callback = function() manual("Equip Best Now", equipBest) end,
            })
        end

        local rarityRows, raritySeen = {}, {}
        local petNames = {}
        for name, config in pairs(Assets and Assets.Directory or {}) do
            table.insert(petNames, tostring(name))
            local rarity = type(config.Rarity) == "table" and config.Rarity or nil
            local id = rarity and tostring(rarity._id or rarity.DisplayName)
            if id and not raritySeen[id] then
                raritySeen[id] = true
                table.insert(rarityRows, { Name = id, Rank = tonumber(rarity.RarityNumber) or 0 })
            end
        end
        table.sort(petNames)
        table.sort(rarityRows, function(a, b) return a.Rank < b.Rank end)
        local rarityNames = {}
        for _, row in ipairs(rarityRows) do table.insert(rarityNames, row.Name) end
        local mutationNames = {}
        local mutationIds = MutationData and MutationData.Ids
        if type(mutationIds) == "function" then
            local ok, ids = pcall(mutationIds)
            mutationIds = ok and ids or nil
        end
        if type(mutationIds) == "table" then
            for _, id in pairs(mutationIds) do table.insert(mutationNames, tostring(id)) end
        end
        table.sort(mutationNames)

        task.wait()

        local sellSection = MainTab:Section({
            Title = "Sell / Money", ConfigFlagKey = "SellMoney", Icon = "badge-dollar-sign",
            Box = true, BoxBorder = true, Opened = true,
        })
        if modulesReady then
            sellSection:Toggle({ Title = "Auto Sell Pets", Value = false, Callback = function(v) utility.AutoSellPets = v == true end })
            sellSection:Dropdown({
                Title = "Pet Rarities to Sell", Values = rarityNames, Multi = true, AllowNone = true, Value = {},
                Callback = function(v) utility.PetSellRarities = selectionSet(v) end,
            })
            sellSection:Dropdown({
                Title = "Pet Mutations to Sell", Values = mutationNames, Multi = true, AllowNone = true, Value = {},
                Callback = function(v) utility.PetSellMutations = selectionSet(v) end,
            })
            local neverSellPetsDropdown = sellSection:Dropdown({
                Title = "Never Sell Pet Types", Values = {}, Multi = true, AllowNone = true, NativeSelectAll = true, Value = {},
                Callback = function(v) utility.PetKeepTypes = selectionSet(v) end,
            })
            sellSection:Toggle({ Title = "Never Sell Mutated", Value = true, Callback = function(v) utility.NeverSellMutated = v == true end })
            sellSection:Toggle({ Title = "Never Sell Equipped", Value = true, Callback = function(v) utility.NeverSellEquipped = v == true end })
            sellSection:Slider({
                Title = "Max Scale", Value = { Min = 0.1, Max = 100, Default = 10 }, Step = 0.1,
                Callback = function(v) utility.SellMaxScale = tonumber(v) or 10 end,
            })
            sellSection:Slider({
                Title = "Pet Sell Interval", Value = { Min = 0.5, Max = 60, Default = 2 }, Step = 0.5,
                Callback = function(v) utility.PetSellInterval = tonumber(v) or 2 end,
            })
            sellSection:Button({
                Title = "Sell All Eligible Pets", Icon = "tags",
                Callback = function() manual("Sell All Eligible Pets", function() return sellList(petSellable()) end) end,
            })
            sellSection:Button({
                Title = "Sell All Pets", Icon = "trash-2",
                Callback = function() manual("Sell All Pets", function() return sellList(petSellable(true)) end) end,
            })
            sellSection:Divider()
            sellSection:Toggle({ Title = "Auto Sell Eggs", Value = false, Callback = function(v) utility.AutoSellEggs = v == true end })
            sellSection:Dropdown({
                Title = "Egg Rarities to Sell", Values = rarityNames, Multi = true, AllowNone = true, Value = {},
                Callback = function(v) utility.EggSellRarities = selectionSet(v) end,
            })
            local neverSellEggsDropdown = sellSection:Dropdown({
                Title = "Never Sell Egg Types", Values = {}, Multi = true, AllowNone = true, NativeSelectAll = true, Value = {},
                Callback = function(v) utility.EggKeepTypes = selectionSet(v) end,
            })
            sellSection:Slider({
                Title = "Egg Sell Interval", Value = { Min = 0.5, Max = 60, Default = 2 }, Step = 0.5,
                Callback = function(v) utility.EggSellInterval = tonumber(v) or 2 end,
            })
            sellSection:Button({
                Title = "Sell All Eligible Eggs", Icon = "egg-off",
                Callback = function() manual("Sell All Eligible Eggs", function() return sellList(eggSellable()) end) end,
            })
            sellSection:Button({
                Title = "Sell All Eggs", Icon = "trash-2",
                Callback = function() manual("Sell All Eggs", function() return sellList(eggSellable(true)) end) end,
            })

            local function attachLazyDropdown(dropdown, getItems)
                if not dropdown or type(dropdown.Open) ~= "function" then return end
                local loaded = false
                local rawOpen = dropdown.Open
                dropdown.Open = function(self, ...)
                    if not loaded then
                        loaded = true
                        local items = getItems()
                        if items and #items > 0 then
                            local curVal = dropdown.Value
                            pcall(function()
                                dropdown:Refresh(items)
                                if curVal and next(curVal) ~= nil then
                                    dropdown:Select(curVal)
                                end
                            end)
                        end
                    end
                    return rawOpen(self, ...)
                end
            end

            attachLazyDropdown(neverSellPetsDropdown, function() return petNames end)
            attachLazyDropdown(neverSellEggsDropdown, function() return petNames end)
        end

        local upgradeSection = MiscTab:Section({
            Title = "Upgrades / Fuse And Trails", ConfigFlagKey = "UpgradeFuseTrails", Icon = "rocket",
            Box = true, BoxBorder = true, Opened = true,
        })
        if modulesReady then
            upgradeSection:Toggle({ Title = "Auto Upgrade Base", Value = false, Callback = function(v) utility.AutoBaseUpgrade = v == true end })
            upgradeSection:Toggle({ Title = "Auto Upgrade Treadmill", Value = false, Callback = function(v) utility.AutoTreadmillUpgrade = v == true end })
            upgradeSection:Toggle({ Title = "Auto Claim Index Rewards", Value = false, Callback = function(v) utility.AutoClaimIndex = v == true end })
            upgradeSection:Toggle({ Title = "Auto Offline Earnings", Value = false, Callback = function(v) utility.AutoOffline = v == true end })
            upgradeSection:Divider()
            upgradeSection:Toggle({ Title = "Fuse Machine Automation", Value = false, Callback = function(v) utility.AutoFuse = v == true end })
            upgradeSection:Dropdown({
                Title = "Fuse Rarities", Values = rarityNames, Multi = true, AllowNone = true, Value = {},
                Callback = function(v) utility.FuseRarities = selectionSet(v) end,
            })
            upgradeSection:Slider({
                Title = "Fuse Max Scale", Value = { Min = 0.1, Max = 100, Default = 10 }, Step = 0.1,
                Callback = function(v) utility.FuseMaxScale = tonumber(v) or 10 end,
            })
            upgradeSection:Slider({
                Title = "Fuse Interval", Value = { Min = 1, Max = 120, Default = 8 }, Step = 1,
                Callback = function(v) utility.FuseInterval = tonumber(v) or 8 end,
            })
            upgradeSection:Button({ Title = "Fuse Now", Icon = "combine", Callback = function() manual("Fuse Now", fuseOnce) end })
            local trailNames = {}
            for _, row in ipairs(trailRows) do table.insert(trailNames, row.Name) end
            upgradeSection:Dropdown({
                Title = "Trails to Buy", Values = trailNames, Multi = true, AllowNone = true, Value = {},
                Callback = function(v) utility.TrailWanted = selectionSet(v) end,
            })
            upgradeSection:Toggle({ Title = "Auto Buy Trail", Value = false, Callback = function(v) utility.AutoBuyTrail = v == true end })
        end
    end

    task.wait()

    local AutoStealV2 = {
        Build = "2026-08-28-manual-carry-isolation-v6.9.0",
        Speed = 1000,
        RunSpeed = 1.0,
        BigScale = 1.5,
        SelectedAreas = {},
        SelectedRarities = {},
        SelectedEnabled = false,
        SecretEnabled = false,
        BigEnabled = false,
        RarestEnabled = false,
        TpStealEnabled = false,
        ReturnRaceActive = false,
        ReturnRaceToken = 0,
        TpAttempts = 0,
        TpSteals = 0,
        TpFails = 0,
        TpWindow = 0,
        TpStatus = "Idle",
        RagdollWindowActive = false,
        EventEnabled = false,
        EventFeeding = false,
        EventStatus = nil,
        EventFeeds = 0,
        EventAllowedRarities = {},
        EventAllowedTypes = {},
        Running = false,
        Carrying = false,
        ScriptCarry = false,
        Status = "Loading",
        Stolen = 0,
        Failed = 0,
        Token = 0,
        StopRequested = false,
        Busy = false,
        SchedulerClosed = false,
        ActiveTween = nil,
        Moving = false,
        LastCarryEvent = nil,
        ReturningToSafe = false,
        NightPaused = false,
        ResetSoon = false,
        SecondsUntilPhaseEnd = nil,
        DayReadyIn = 0,
        Rollbacks = 0,
        GuardLosses = 0,
        GuardLossPending = false,
        ActiveTargetUid = nil,
        ActiveTargetCategory = nil,
        ActiveTargetAreaId = nil,
        ActiveTargetNestId = nil,
        RetryTargetUid = nil,
        RetryTargetSince = nil,
        RetryTargetCategory = nil,
        RetryTargetAreaId = nil,
        RetryTargetNestId = nil,
        RetryLossPosition = nil,
        TreadmillEscapes = 0,
        GuardRetryTimeout = 2.5,
        GuardRetryAttempts = 0,
        StunRecoveries = 0,
        RecoveryUntil = 0,
        RecoverySerial = 0,
        LastAntiRagdollAt = 0,
        RetryReason = nil,
        AntiRagdollRetryAttempts = 0,
        LastGuardUid = nil,
        CarrySpamActive = false,
        CarrySpamToken = 0,
        CarrySpamRequests = 0,
        CarrySpamSuccesses = 0,
        CarrySpamInFlight = 0,
        CarryLossSerial = 0,
        CarryChaseActive = false,
        CarryChaseToken = 0,
        CarryChaseTween = nil,
        HighestEarningRate = 0,
        ActiveTargetEarningRate = 0,
        TrapHitboxesRemoved = 0,
        AutoTreadmill = false,
        TreadmillTraining = false,
        ActiveBelt = nil,
    }

    do
        local EggState, PlotState, Save, AssetDirectory, AreaDirectory, AreaEggCycle, Ragdoll
        local RawCarryRemote, FeedRemote
        local AreaEggResetWall, AreaEggResetConfig
        AutoStealV2.Ready = pcall(function()
            local client = ReplicatedStorage:FindFirstChild("Client") or ReplicatedStorage:WaitForChild("Client", 1)
            local data = ReplicatedStorage:FindFirstChild("Data") or ReplicatedStorage:WaitForChild("Data", 1)
            local shared = ReplicatedStorage:FindFirstChild("Shared") or ReplicatedStorage:WaitForChild("Shared", 1)
            local pkgs = ReplicatedStorage:FindFirstChild("Packages")
            local net = pkgs and pkgs:FindFirstChild("Networking")

            local function safeReq(inst)
                if inst and inst:IsA("ModuleScript") then
                    local ok, m = pcall(require, inst)
                    return ok and m or nil
                end
                return nil
            end

            EggState = safeReq(client and client:FindFirstChild("EggState"))
            PlotState = safeReq(client and client:FindFirstChild("PlotState"))
            Save = safeReq(shared and shared:FindFirstChild("Save"))
            FeedRemote = net and net:FindFirstChild("RF/MonsterParasite/AskFeed")
            local sharedUtil = shared and shared:FindFirstChild("Util")
            AreaEggCycle = safeReq(sharedUtil and sharedUtil:FindFirstChild("AreaEggCycle"))
            AreaEggResetWall = safeReq(client and client:FindFirstChild("AreaEggResetWall"))
            AreaEggResetConfig = safeReq(data and data:FindFirstChild("AreaEggResetCycle"))
            local sharedMod = shared and shared:FindFirstChild("Modules")
            Ragdoll = safeReq(sharedMod and sharedMod:FindFirstChild("Ragdoll"))
            RawCarryRemote = net and net:FindFirstChild("RF/EggWorld/AskFieldEggCarry")
            local assetMod = safeReq(data and data:FindFirstChild("Assets"))
            AssetDirectory = assetMod and assetMod.Directory
            local areaMod = safeReq(data and data:FindFirstChild("Areas"))
            AreaDirectory = areaMod and areaMod.Directory
        end)
        AutoStealV2.Status = AutoStealV2.Ready and "Idle" or "Current game modules unavailable"

        local RarityRank = {
            Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5,
            Mythic = 6, Cosmic = 7, Secret = 8, Eternal = 9, Divine = 10,
        }

        local function normalStealEnabled()
            return AutoStealV2.SelectedEnabled or AutoStealV2.SecretEnabled
                or AutoStealV2.BigEnabled or AutoStealV2.RarestEnabled
        end

        local function isEnabled()
            return normalStealEnabled()
        end

        local function getCycleState(atTime)
            if not AreaEggCycle or Workspace:GetAttribute("Event_AdminAbuse") == true then
                return false, false, math.huge
            end
            local now = tonumber(atTime) or Workspace:GetServerTimeNow()
            local okNight, night = pcall(AreaEggCycle.IsNightPhase, now)
            local okSeconds, seconds = pcall(AreaEggCycle.SecondsUntilPhaseEnd, now)
            seconds = okSeconds and tonumber(seconds) or math.huge
            local okClose, close = pcall(AreaEggCycle.IsCloseToReset, seconds)
            night = okNight and night == true
            close = not night and okClose and close == true
            return night, close, seconds
        end

        local wallOpenSince = nil
        local function getDawnReadyIn(atTime)
            if not AreaEggCycle then return math.huge end
            local now = tonumber(atTime) or Workspace:GetServerTimeNow()
            local okIndex, periodIndex = pcall(AreaEggCycle.PeriodIndexAt, now)
            local okStart, periodStart = false, nil
            if okIndex then
                okStart, periodStart = pcall(AreaEggCycle.PeriodStartTime, periodIndex)
            end
            if not okStart or type(periodStart) ~= "number" then return math.huge end
            local dawnDelay = (tonumber(AreaEggResetConfig.WallCountdownDelayAfterDayStartsSeconds) or 2)
                + (tonumber(AreaEggResetConfig.WallCountdownSeconds) or 3) + 0.75
            return math.max(0, periodStart + dawnDelay - now)
        end

        local function refreshCycleState()
            local night, close, seconds = getCycleState()
            local nowClock = os.clock()
            local okSealed, sealed = pcall(AreaEggResetWall.IsSealed)
            sealed = not okSealed or sealed == true
            if night or sealed then
                wallOpenSince = nil
            else
                wallOpenSince = wallOpenSince or nowClock
            end
            local wallStableIn = wallOpenSince and math.max(0, 0.75 - (nowClock - wallOpenSince)) or math.huge
            local dayReadyIn = math.max(getDawnReadyIn(), wallStableIn)
            local dayReady = not night and not close and not sealed and dayReadyIn <= 0
            AutoStealV2.NightPaused = night
            AutoStealV2.ResetSoon = close
            AutoStealV2.SecondsUntilPhaseEnd = seconds
            AutoStealV2.DayReadyIn = dayReadyIn
            return night, close, seconds, dayReady, dayReadyIn
        end

        local function characterParts()
            local character = LocalPlayer.Character
            if not character then return nil, nil end
            return character:FindFirstChild("HumanoidRootPart"),
                character:FindFirstChildOfClass("Humanoid")
        end

        local function prepareStealHumanoid()
            local character = LocalPlayer.Character
            local root, humanoid = characterParts()
            if not character or not root or not humanoid then return false end
            for _, item in ipairs(character:GetDescendants()) do
                if item:IsA("LocalScript") and item.Name:find("PushBack") then
                    pcall(function() item.Disabled = true item:Destroy() end)
                end
            end

            if humanoid:GetAttribute("SpeedBypassApplied") == true
                or humanoid:GetAttribute("StealHumanoid") == true
            then
                pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false) end)
                humanoid.Sit = false
                return true
            end
            humanoid.Archivable = true
            local ok, clone = pcall(function() return humanoid:Clone() end)
            if not ok or not clone then return false end
            clone:SetAttribute("StealHumanoid", true)
            clone:SetAttribute("SpeedBypassApplied", true)
            clone.Sit = false
            clone.PlatformStand = false
            clone.AutoRotate = true
            pcall(function() clone:SetStateEnabled(Enum.HumanoidStateType.Seated, false) end)
            humanoid:Destroy()
            clone.Parent = character
            if Workspace.CurrentCamera then Workspace.CurrentCamera.CameraSubject = clone end
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            pcall(function() clone:ChangeState(Enum.HumanoidStateType.Running) end)
            return true
        end

        local function getRarity(record)
            local asset = AssetDirectory and AssetDirectory[record.AssetCategory]
            local rarity = type(asset) == "table" and asset.Rarity or record.Rarity
            if type(rarity) == "table" then
                rarity = rarity._id or rarity.DisplayName or rarity.Name
            end
            return tostring(rarity or "Common")
        end

        local function getEarningRate(record)
            local asset = AssetDirectory and AssetDirectory[record.AssetCategory]
            return type(asset) == "table" and (tonumber(asset.EarningRate) or 0) or 0
        end

        local function removeAutoStealTrapHitboxes()
            local CS = game:GetService("CollectionService")
            for _, trap in ipairs(CS:GetTagged("PlacedTrap")) do
                if trap:GetAttribute("Owner") ~= LocalPlayer.Name then
                    for _, d in ipairs(trap:GetDescendants()) do
                        if d:IsA("BasePart") and d.CanTouch then
                            pcall(function() d.CanTouch = false end)
                        end
                    end
                end
            end
            local transient = Workspace:FindFirstChild("Transient")
            if transient then
                for _, trap in ipairs(transient:GetChildren()) do
                    if trap.Name == "PlayerTrap" and trap:GetAttribute("Owner") ~= LocalPlayer.Name then
                        for _, d in ipairs(trap:GetDescendants()) do
                            if d:IsA("BasePart") and d.CanTouch then
                                pcall(function() d.CanTouch = false end)
                            end
                        end
                    end
                end
            end
        end

        local function getInventoryCount()
            local fn = Save and (Save.Get or Save.Peek)
            local ok, save = pcall(fn)
            local inventory = ok and type(save) == "table" and save.EggInventory
            if type(inventory) ~= "table" then return -1 end
            local count = 0
            for _ in pairs(inventory) do count += 1 end
            return count
        end

        local function getFreshRecords()
            pcall(EggState.SyncFieldEggs)
            task.wait(0.2)
            local ok, snapshot = pcall(EggState.ReadFieldEggs)
            if not ok or type(snapshot) ~= "table" then return {} end
            local records = type(snapshot.Records) == "table" and snapshot.Records or snapshot
            if AutoStealV2.CacheSlotKeys then AutoStealV2.CacheSlotKeys(records) end
            return records
        end

        local function isOwnEgg(uid)
            return tonumber(tostring(uid):match("^FirstAreaEgg_(%d+)_")) == LocalPlayer.UserId
        end

        local function matchesSelected(record, rarity)
            local aId = tostring(record.AreaId)
            local areaOk = next(AutoStealV2.SelectedAreas) == nil
                or AutoStealV2.SelectedAreas[aId] == true
                or (aId == "Light Dark" and AutoStealV2.SelectedAreas["Angels & Demons"] == true)
                or (aId == "Angels & Demons" and AutoStealV2.SelectedAreas["Light Dark"] == true)
            local rarityOk = next(AutoStealV2.SelectedRarities) == nil
                or AutoStealV2.SelectedRarities[rarity] == true
            return areaOk and rarityOk
        end

        local function recordCFrame(record)
            return type(record) == "table" and (record.BottomCFrame or record.BoundsCFrame) or nil
        end

        local function isStealableState(record)
            return type(record) == "table" and (record.State == "Slot" or record.State == "Dropped")
        end

        local slotKeyCache = {}

        local function firstAreaSlotKey(record)
            if type(record) ~= "table" then return nil end
            local uid = tostring(record.Uid)
            if not uid:match("^FirstAreaEgg_") then return nil end
            if record.AreaId ~= nil and record.NestId ~= nil then
                return tostring(record.AreaId) .. ":" .. tostring(record.NestId)
            end
            local area, slot = uid:match("_([^_:]+):(Slot_%d+)$")
            return area and (area .. ":" .. slot) or nil
        end

        local function slotKeyForUid(uid)
            if type(uid) ~= "string" then return nil end
            local cached = slotKeyCache[uid]
            if cached ~= nil then return cached ~= false and cached or nil end
            if not uid:match("^FirstAreaEgg_") then
                slotKeyCache[uid] = false
                return nil
            end
            local area, slot = uid:match("_([^_:]+):(Slot_%d+)$")
            local key = area and (area .. ":" .. slot) or nil
            slotKeyCache[uid] = key or false
            return key
        end

        local function cacheSlotKeys(records)
            if type(records) ~= "table" then return end
            for _, record in pairs(records) do
                if type(record) == "table" and type(record.Uid) == "string" then
                    slotKeyCache[record.Uid] = firstAreaSlotKey(record) or false
                end
            end
        end
        AutoStealV2.CacheSlotKeys = cacheSlotKeys

        local function pickTarget()
            LPH_ATTRIBUTES(PRESET(FAST), ERROR_HANDLING(false))
            local root = characterParts()
            if not root then return nil end
            local snapshot = getFreshRecords()
            if AutoStealV2.RetryTargetUid then
                for _, record in pairs(snapshot) do
                    if isStealableState(record) and record.Uid == AutoStealV2.RetryTargetUid
                        and recordCFrame(record)
                    then
                        return record
                    end
                end

                local replacement, replacementScore
                for _, record in pairs(snapshot) do
                    local cf = recordCFrame(record)
                    if isStealableState(record) and cf
                        and AutoStealV2.RetryTargetCategory ~= nil
                        and record.AssetCategory == AutoStealV2.RetryTargetCategory
                    then
                        local distance = AutoStealV2.RetryLossPosition
                            and (cf.Position - AutoStealV2.RetryLossPosition).Magnitude or 0
                        local sameNest = tostring(record.AreaId) == tostring(AutoStealV2.RetryTargetAreaId)
                            and tostring(record.NestId) == tostring(AutoStealV2.RetryTargetNestId)
                        local isLostDroppedEgg = record.State == "Dropped" and distance <= 120
                        if sameNest or isLostDroppedEgg then
                            local score = (isLostDroppedEgg and 1e6 or 0)
                                + (sameNest and 1e5 or 0) - distance
                            if not replacementScore or score > replacementScore then
                                replacement, replacementScore = record, score
                            end
                        end
                    end
                end
                if replacement then
                    AutoStealV2.RetryTargetUid = replacement.Uid
                    return replacement
                end
                local retryAge = os.clock() - (AutoStealV2.RetryTargetSince or os.clock())
                if retryAge < AutoStealV2.GuardRetryTimeout then
                    return nil
                end
                AutoStealV2.RetryTargetUid = nil
                AutoStealV2.RetryTargetSince = nil
                AutoStealV2.ActiveTargetUid = nil
                AutoStealV2.ActiveTargetCategory = nil
                AutoStealV2.ActiveTargetAreaId = nil
                AutoStealV2.ActiveTargetNestId = nil
                AutoStealV2.GuardLossPending = false
                AutoStealV2.RetryReason = nil
                AutoStealV2.RetryTargetCategory = nil
                AutoStealV2.RetryTargetAreaId = nil
                AutoStealV2.RetryTargetNestId = nil
                AutoStealV2.RetryLossPosition = nil
            end
            local highestEarningRate = 0
            if AutoStealV2.RarestEnabled then
                for _, record in pairs(snapshot) do
                    if isStealableState(record) and not isOwnEgg(record.Uid) then
                        highestEarningRate = math.max(highestEarningRate, getEarningRate(record))
                    end
                end
            end
            AutoStealV2.HighestEarningRate = highestEarningRate

            local bestNormal = nil
            for _, record in pairs(snapshot) do
                local cf = recordCFrame(record)
                if isStealableState(record)
                    and type(record.Uid) == "string" and cf
                    and not isOwnEgg(record.Uid)
                then
                    local rarity = getRarity(record)
                    local rank = RarityRank[rarity] or 0
                    local scale = tonumber(record.AssetScale) or 1
                    local earningRate = getEarningRate(record)
                    local distance = (cf.Position - root.Position).Magnitude

                    local selected = AutoStealV2.SelectedEnabled and matchesSelected(record, rarity)
                    local secret = AutoStealV2.SecretEnabled and rarity == "Secret"
                    local big = AutoStealV2.BigEnabled and scale >= AutoStealV2.BigScale
                    local highestMoney = AutoStealV2.RarestEnabled and earningRate == highestEarningRate

                    if selected or secret or big or highestMoney then
                        local better = not bestNormal
                        if not better then
                            local bRarity = getRarity(bestNormal)
                            local bRank = RarityRank[bRarity] or 0
                            local bEarn = getEarningRate(bestNormal)
                            local bScale = tonumber(bestNormal.AssetScale) or 1
                            local bDist = (recordCFrame(bestNormal).Position - root.Position).Magnitude

                            if rank ~= bRank then
                                better = rank > bRank
                            elseif earningRate ~= bEarn then
                                better = earningRate > bEarn
                            elseif scale ~= bScale then
                                better = scale > bScale
                            else
                                better = distance < bDist
                            end
                        end
                        if better then
                            bestNormal = record
                        end
                    end
                end
            end

            return bestNormal
        end

        local function getGateway()
            local objects = Workspace:FindFirstChild("World")
            local areas = objects and objects:FindFirstChild("Areas")
            local gameplay = areas and areas:FindFirstChild("GameplayZ")
            local separation = areas and areas:FindFirstChild("SeparationLine")
            local gatewayX = gameplay and gameplay.Position.X or 553
            local laneZ = separation and separation.Position.Z or -364.5
            local plots = Workspace:FindFirstChild("Plots")
            if plots then
                for _, item in ipairs(plots:GetDescendants()) do
                    if item:IsA("BasePart") and item.Name == "TreadmillBottom" then
                        gatewayX = math.max(gatewayX, item.Position.X + item.Size.X * 0.5 + 8)
                    end
                end
            end
            return gatewayX, laneZ
        end

        local function getSafePoint()
            local objects = Workspace:FindFirstChild("World")
            local build = objects and objects:FindFirstChild("Build")
            local mainMap = build and build:FindFirstChild("MainMap")
            local spawnTarget = mainMap and mainMap:FindFirstChild("SpawnTarget")
            if spawnTarget and spawnTarget:IsA("BasePart") then
                return spawnTarget.Position + Vector3.new(0, 1.5, 0)
            end
            local areas = objects and objects:FindFirstChild("Areas")
            local line = areas and areas:FindFirstChild("SeparationLine")
            if line and line:IsA("BasePart") then
                return line.Position - line.CFrame.LookVector * 24 + Vector3.new(0, 4, 0)
            end
            local x, z = getGateway()
            return Vector3.new(x - 24, 72, z)
        end

        local function isTreadmillUiVisible()
            local visible = false
            pcall(function()
                local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
                local elements = playerGui and playerGui:FindFirstChild("Elements")
                local left = elements and elements:FindFirstChild("Left")
                local tools = left and left:FindFirstChild("Tools")
                local doubleSpeed = tools and tools:FindFirstChild("DoubleYourSpeed")
                visible = doubleSpeed ~= nil and doubleSpeed.Visible == true
            end)
            return visible
        end

        local function getMyTreadmillPart()
            local okSlot, slot = pcall(function() return PlotState and PlotState.ResolveLocalSlot() end)
            if okSlot and slot ~= nil then
                local plots = Workspace:FindFirstChild("Plots")
                local myPlot = plots and plots:FindFirstChild(tostring(slot))
                local bottom = myPlot and myPlot:FindFirstChild("TreadmillBottom")
                if bottom and bottom:IsA("BasePart") then
                    return bottom
                end
            end
            local okPlot, plot = pcall(function()
                return PlotState and PlotState.ResolvePlot()
            end)
            local plotFolder = okPlot and plot and plot.PlotFolder
            if plotFolder then
                local bottom = plotFolder:FindFirstChild("TreadmillBottom", true)
                if bottom and bottom:IsA("BasePart") then
                    return bottom
                end
            end
            return nil
        end

        local function getMyTreadmillStand()
            local bottom = getMyTreadmillPart()
            if bottom then
                return bottom.Position + Vector3.new(0, bottom.Size.Y * 0.5 + 3, 0), bottom
            end
            return nil, nil
        end

        local function isOnTreadmill()
            local bottom = getMyTreadmillPart()
            if not bottom then return false end
            local root = characterParts()
            if not root then return false end
            local rel = bottom.CFrame:PointToObjectSpace(root.Position)
            local halfX = bottom.Size.X * 0.5 + 2
            local halfZ = bottom.Size.Z * 0.5 + 2
            return math.abs(rel.X) <= halfX and math.abs(rel.Z) <= halfZ and rel.Y >= -3 and rel.Y <= bottom.Size.Y * 0.5 + 9
        end

        AutoStealV2.hasAvailableStealTarget = hasAvailableStealTarget
        AutoStealV2.refreshCycleState = refreshCycleState
        local function hasAvailableStealTarget()
            if not normalStealEnabled() then return false end
            local target = pickTarget()
            return target ~= nil
        end

        local lastPriorityWorkAt = 0
        local TREADMILL_IDLE_GRACE = 1.5

        local function hasHigherPriorityWork()
            local has = false

            if AutoStealV2.Carrying or AutoStealV2.ReturningToSafe or AutoStealV2.GuardLossPending then
                has = true
            end

            if not has and AutoStealV2.Busy and (AutoStealV2.ActiveTargetUid ~= nil or AutoStealV2.Carrying) then
                has = true
            end

            if not has then
                local night, resetSoon, _, dayReady = refreshCycleState()
                if not night and not resetSoon and dayReady then
                    if hasAvailableStealTarget() then
                        has = true
                    end
                end
            end

            -- Auto Event has 2nd highest priority (right below Auto Steal, above everything else)
            if not has then
                local scramble = ScriptEnv.SAE_ScrambleAuto
                if type(scramble) == "table" and (scramble.AutoFarm or scramble.AutoQuest or scramble.AutoShop or scramble.AutoLab or scramble.AutoBoss or scramble.AutoMutate) then
                    if scramble.Busy == true
                        or (scramble.AutoBoss and (LocalPlayer:GetAttribute("InScrambleArena") == true or Workspace:FindFirstChild("ScrambleArenaPortal") ~= nil))
                        or (scramble.AutoFarm and (Workspace:GetAttribute("ScrambleOutbreakActive") == true or (tonumber(Workspace:GetAttribute("ScrambleActiveDrones")) or 0) > 0))
                    then
                        has = true
                    end
                end
            end

            if not has then
                local util = ScriptEnv.SAE_UtilityAutomation
                if util and util.Busy == true then
                    has = true
                end
            end

            if not has then
                local batAura = ScriptEnv.SAE_BatAura
                if batAura and batAura.Enabled and batAura.Running then
                    has = true
                end
            end

            if not has then
                local autoIndex = ScriptEnv.SAE_AutoIndex
                if type(autoIndex) == "table" and autoIndex.Enabled == true
                    and (autoIndex.Busy == true or autoIndex.TargetPet ~= nil)
                then
                    has = true
                end
            end

            if has then
                lastPriorityWorkAt = os.clock()
            end
            return has
        end

        local function escapeTreadmill(token)
            pcall(function()
                local Remotes = require(ReplicatedStorage.Shared.Remotes)
                if Remotes and Remotes.Treadmill and Remotes.Treadmill.AskDoff then
                    Remotes.Treadmill.AskDoff:InvokeServer()
                else
                    local req = ReplicatedStorage.Packages.Networking:FindFirstChild("RF/Treadmill/AskDoff")
                    if req then req:InvokeServer() end
                end
            end)

            local root, humanoid = characterParts()
            if humanoid then
                humanoid.Sit = false
                pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Running) end)
                humanoid.Jump = true
            end

            local myBottom = getMyTreadmillPart()
            if root and myBottom then
                local away = (root.Position - myBottom.Position) * Vector3.new(1, 0, 1)
                if away.Magnitude < 2 then
                    away = Vector3.new(8, 0, 0)
                else
                    away = away.Unit * 8
                end
                root.CFrame = CFrame.new(myBottom.Position + away + Vector3.new(0, 3, 0))
                root.AssemblyLinearVelocity = Vector3.zero
            end

            AutoStealV2.ActiveBelt = nil
            AutoStealV2.TreadmillTraining = false
            return true
        end

        local function restoreHumanoid(humanoid, oldSpeed, oldRotate)
            if not humanoid or not humanoid.Parent then return end
            humanoid.Sit = false
            humanoid.PlatformStand = false
            humanoid.WalkSpeed = oldSpeed or humanoid.WalkSpeed
            humanoid.AutoRotate = oldRotate ~= false
            pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Running) end)
        end

        local function recoverFromStun(countRecovery)
            local root, humanoid = characterParts()
            if not root or not humanoid then return false end
            local character = LocalPlayer.Character
            if Ragdoll and character then
                pcall(Ragdoll.ClearClientRagdoll, character)
            end
            pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true) end)
            pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true) end)
            pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true) end)
            humanoid.Sit = false
            if not AutoStealV2.ActiveTween then humanoid.PlatformStand = false end
            root.Anchored = false
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            pcall(function() LocalPlayer.Character:SetAttribute("IsTrapped", nil) end)
            if not AutoStealV2.ActiveTween then
                pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end)
                pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Running) end)
            end
            if countRecovery then AutoStealV2.StunRecoveries += 1 end
            return true
        end

        local function isRagdolledNow()
            local character = LocalPlayer.Character
            if not character then return false end
            if Ragdoll then
                local ok, value = pcall(Ragdoll.IsRagdolled, character)
                if ok and value == true then return true end
            end
            local _, humanoid = characterParts()
            if humanoid then
                local state = humanoid:GetState()
                if state == Enum.HumanoidStateType.Physics
                    or state == Enum.HumanoidStateType.FallingDown
                    or state == Enum.HumanoidStateType.Ragdoll
                then
                    return true
                end
            end
            return false
        end

        local function ragdollWindowLeft()
            local now = Workspace:GetServerTimeNow()
            local best = 0
            local character = LocalPlayer.Character
            if character then
                local ok, value = pcall(function() return character:GetAttribute("RagdollEndTime") end)
                if ok then
                    value = tonumber(value)
                    if value then best = math.max(best, value - now) end
                end
            end
            local okPlayer, playerValue = pcall(function() return LocalPlayer:GetAttribute("RagdollEndTime") end)
            if okPlayer then
                playerValue = tonumber(playerValue)
                if playerValue then best = math.max(best, playerValue - now) end
            end
            return best
        end

        local function rawCarryUid(uid, slotKey)
            if not RawCarryRemote or type(uid) ~= "string" then return false end
            AutoStealV2.CarrySpamRequests += 1
            local key = slotKey or slotKeyForUid(uid)
            local ok, result = pcall(function()
                return RawCarryRemote:InvokeServer({ Uid = uid, FirstAreaSlotKey = key })
            end)
            if ok and result == true then
                AutoStealV2.CarrySpamSuccesses += 1
            end

            return AutoStealV2.Carrying
        end

        local function queueRawCarry(uid, slotKey)
            if AutoStealV2.CarrySpamInFlight >= 4 then return false end
            AutoStealV2.CarrySpamInFlight += 1
            task.spawn(function()
                rawCarryUid(uid, slotKey)
                AutoStealV2.CarrySpamInFlight = math.max(0, AutoStealV2.CarrySpamInFlight - 1)
            end)
            return true
        end

        local function stopCarrySpam()
            AutoStealV2.CarrySpamActive = false
            AutoStealV2.CarrySpamToken += 1
        end

        local function liveEggPosition(uid)
            local folder = Workspace:FindFirstChild("AreaEggSlotsClient")
            local egg = folder and folder:FindFirstChild(uid)
            if egg then
                local part = egg:FindFirstChild("Hitbox")
                    or egg:FindFirstChild("CustomBoundingBox")
                    or egg:FindFirstChildWhichIsA("BasePart", true)
                if part then return part.Position end
                local ok, pivot = pcall(egg.GetPivot, egg)
                if ok then return pivot.Position end
            end

            local ok, snapshot = pcall(EggState.ReadFieldEggs)
            local records = ok and type(snapshot) == "table" and (snapshot.Records or snapshot) or {}
            for _, record in pairs(records) do
                if type(record) == "table" and record.Uid == uid then
                    local cf = recordCFrame(record)
                    if cf then return cf.Position end
                end
            end
            return nil
        end

        local function stopCarryChase()
            AutoStealV2.CarryChaseActive = false
            AutoStealV2.CarryChaseToken += 1
            local tween = AutoStealV2.CarryChaseTween
            AutoStealV2.CarryChaseTween = nil
            if tween then pcall(function() tween:Cancel() end) end
        end

        local function startCarryChase(uid)
        end

        local function stopCarrySpam()
            AutoStealV2.CarrySpamActive = false
            AutoStealV2.CarrySpamToken += 1
        end

        local function startCarrySpam(uid)
        end

        local function startReturnRace(uid)
        end

        local function stopReturnRace()
            AutoStealV2.ReturnRaceToken += 1
            AutoStealV2.ReturnRaceActive = false
        end

        local function startRecoveryBurst(uid, reason, preserveTween)
            local recoverySeconds = 0.6
            local ragdollEndTime = tonumber(LocalPlayer:GetAttribute("RagdollEndTime"))
            if ragdollEndTime then
                recoverySeconds = math.clamp(
                    ragdollEndTime - Workspace:GetServerTimeNow() + 0.15,
                    0.2,
                    2.0
                )
            end
            AutoStealV2.RecoveryUntil = os.clock() + recoverySeconds
            AutoStealV2.RecoverySerial += 1
            local recoverySerial = AutoStealV2.RecoverySerial
            if reason == "guard" then AutoStealV2.LastGuardUid = uid end
            if not preserveTween then
                local activeTween = AutoStealV2.ActiveTween
                AutoStealV2.ActiveTween = nil
                if activeTween then pcall(function() activeTween:Cancel() end) end
            end
            recoverFromStun(true)

            task.spawn(function()
                while os.clock() < AutoStealV2.RecoveryUntil
                    and AutoStealV2.RecoverySerial == recoverySerial and isEnabled()
                do
                    recoverFromStun(false)
                    task.wait(0.05)
                end
            end)
        end

        local function startGuardRecovery(uid, customLossPos)
            local activeTween = AutoStealV2.ActiveTween
            AutoStealV2.ActiveTween = nil
            if activeTween then pcall(function() activeTween:Cancel() end) end

            task.spawn(function()
                startRecoveryBurst(uid, "guard", false)
                local stunDeadline = os.clock() + 1.2
                while os.clock() < stunDeadline and isRagdolledNow() do
                    recoverFromStun(true)
                    task.wait(0.05)
                end
                recoverFromStun(true)

                local root = characterParts()
                local eggPos = liveEggPosition(uid)
                local isNearby = root and eggPos and (eggPos - root.Position).Magnitude <= 100

                if isNearby and not AutoStealV2.Carrying then
                    AutoStealV2.Status = "Re-grabbing dropped egg..."
                    local pin = true
                    task.spawn(function()
                        while pin do
                            local curRoot = characterParts()
                            if curRoot then
                                curRoot.CFrame = CFrame.new(eggPos)
                                curRoot.AssemblyLinearVelocity = Vector3.zero
                            end
                            RunService.Heartbeat:Wait()
                        end
                    end)
                    local grabDeadline = os.clock() + 1.5
                    while not AutoStealV2.Carrying and os.clock() < grabDeadline do
                        pcall(EggState.CarryFieldEgg, uid)
                        if RawCarryRemote then rawCarryUid(uid) end
                        task.wait(0.06)
                    end
                    pin = false
                end

                if AutoStealV2.Carrying then
                    AutoStealV2.ScriptCarry = true
                    AutoStealV2.GuardLossPending = false
                    AutoStealV2.Status = "Egg re-grabbed! Continuing to safe zone..."
                else
                    AutoStealV2.Carrying = false
                    AutoStealV2.ScriptCarry = false
                    AutoStealV2.ReturningToSafe = false
                    AutoStealV2.GuardLossPending = false
                    AutoStealV2.RetryTargetUid = uid
                    AutoStealV2.RetryTargetSince = os.clock()
                    AutoStealV2.ActiveTargetUid = nil
                    AutoStealV2.Busy = false
                    AutoStealV2.Status = "Egg lost - re-stealing via Instant Steal"
                end
            end)
        end

        local function movePath(points, token, requireCarry)
            local moveSpeed = AutoStealV2.Speed
            local expanded = {}
            local lastRoot = characterParts()
            local previous = lastRoot and lastRoot.Position or nil
            for _, point in ipairs(points) do
                if previous then
                    local distance = (point - previous).Magnitude
                    local steps = math.max(1, math.ceil(distance / 600))
                    for step = 1, steps do
                        table.insert(expanded, previous:Lerp(point, step / steps))
                    end
                else
                    table.insert(expanded, point)
                end
                previous = point
            end

            for _, point in ipairs(expanded) do
                local segmentDone = false
                for attempt = 1, 3 do
                    local finishingCarry = requireCarry == true
                    local night, resetSoon, _, dayReady = refreshCycleState()
                    if AutoStealV2.GuardLossPending and finishingCarry then
                        while AutoStealV2.CarrySpamActive and not AutoStealV2.Carrying do
                            task.wait(0.02)
                        end
                        return false, AutoStealV2.Carrying
                            and "remote regrabbed" or "guard caught egg"
                    end
                    if night then
                        return false, "night"
                    end
                    if AutoStealV2.StopRequested and not finishingCarry then
                        return false, "stop requested"
                    end

                    local root, humanoid = characterParts()
                    if not root or not humanoid then return false, "character unavailable" end
                    local delta = point - root.Position
                    local distance = delta.Magnitude
                    if distance <= 2 then segmentDone = true break end
                    local oldSpeed, oldRotate = humanoid.WalkSpeed, humanoid.AutoRotate
                    local flat = Vector3.new(delta.X, 0, delta.Z)
                    local goal = flat.Magnitude > 0.01 and CFrame.lookAt(point, point + flat.Unit) or CFrame.new(point)
                    local duration = math.max(distance / AutoStealV2.Speed, 0.04)
                    local tween = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Linear), { CFrame = goal })
                    local carryLossSerialBefore = AutoStealV2.CarryLossSerial
                    local completed, playbackState = false, nil
                    local connection = tween.Completed:Connect(function(state)
                        completed, playbackState = true, state
                    end)
                    AutoStealV2.ActiveTween = tween
                    humanoid.Sit = false
                    humanoid.PlatformStand = true
                    humanoid.AutoRotate = false
                    humanoid.WalkSpeed = AutoStealV2.Speed
                    root.AssemblyLinearVelocity = Vector3.zero
                    root.AssemblyAngularVelocity = Vector3.zero
                    tween:Play()

                    local deadline = os.clock() + duration + 0.8
                    while not completed and os.clock() < deadline do
                        local currentRoot = characterParts()
                        local isNightNow, resetSoonNow, _, dayReadyNow = refreshCycleState()
                        if finishingCarry
                            and (not AutoStealV2.Carrying or AutoStealV2.CarryLossSerial ~= carryLossSerialBefore)
                        then break end
                        if isNightNow or not root.Parent or currentRoot ~= root
                            or (AutoStealV2.StopRequested and not finishingCarry)
                        then break end
                        task.wait(0.02)
                    end

                    if not completed then pcall(function() tween:Cancel() end) end
                    connection:Disconnect()
                    AutoStealV2.ActiveTween = nil
                    restoreHumanoid(humanoid, oldSpeed, oldRotate)
                    if finishingCarry
                        and (not AutoStealV2.Carrying or AutoStealV2.CarryLossSerial ~= carryLossSerialBefore)
                    then
                        while AutoStealV2.CarrySpamActive and not AutoStealV2.Carrying do
                            task.wait(0.02)
                        end
                        recoverFromStun()
                        return false, AutoStealV2.Carrying
                            and "remote regrabbed" or "guard caught egg"
                    end
                    if not completed or playbackState ~= Enum.PlaybackState.Completed then
                        return false, completed and "movement cancelled" or "movement timeout"
                    end

                    root.CFrame = goal
                    root.AssemblyLinearVelocity = Vector3.zero
                    root.AssemblyAngularVelocity = Vector3.zero
                    RunService.Heartbeat:Wait()
                    if root.Parent and (root.Position - point).Magnitude <= 45 then
                        segmentDone = true
                        break
                    end
                    AutoStealV2.Rollbacks += 1
                    recoverFromStun()
                    if attempt < 3 then task.wait(0.02) end
                end
                if not segmentDone then return false, "rollback persisted after 3 retries" end
            end
            return true
        end

        local function pathTo(target)
            local root = characterParts()
            if not root then return {} end
            local x, z = getGateway()
            local y = math.max(root.Position.Y, target.Y + 3)
            local points = {}

            if root.Position.X > x + 12 then
                table.insert(points, Vector3.new(root.Position.X, y, z))
            else
                table.insert(points, Vector3.new(x, y, z))
            end
            table.insert(points, Vector3.new(target.X, y, z))
            table.insert(points, Vector3.new(target.X, target.Y + 3, target.Z))
            return points
        end

        local function getLegalWalkSpeed()
            local character = LocalPlayer.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            local humSpeed = humanoid and humanoid.WalkSpeed or 16

            local ok, result = pcall(function()
                local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
                local speedStat = leaderstats and leaderstats:FindFirstChild("Speed")
                local TreadmillUtil = require(ReplicatedStorage.Shared.Util.TreadmillUtil)
                return speedStat and TreadmillUtil.SpeedPowerToWalkSpeed(speedStat.Value) or nil
            end)

            if ok and tonumber(result) then
                return math.max(humSpeed, tonumber(result))
            end
            return humSpeed
        end

        local cachedDangers = {}
        local lastDangersAt = 0

        local function refreshDangers()
            if os.clock() - lastDangersAt < 1.5 then return cachedDangers end
            lastDangersAt = os.clock()
            local dangers = {}

            local function addDangerBox(inst)
                local ok, cf, sz = pcall(function()
                    if inst:IsA("Model") then
                        local bcf, bsz = inst:GetBoundingBox()
                        return bcf, bsz
                    elseif inst:IsA("BasePart") then
                        return inst.CFrame, inst.Size
                    end
                end)
                if ok and cf and sz then
                    local ext = Vector3.new(math.abs(sz.X), 0, math.abs(sz.Z)) * 0.5
                    local margin = math.max(ext.X, ext.Z)
                    table.insert(dangers, {
                        MinX = cf.Position.X - margin,
                        MaxX = cf.Position.X + margin,
                        MinZ = cf.Position.Z - margin,
                        MaxZ = cf.Position.Z + margin,
                        Name = inst.Name,
                    })
                end
            end

            local function isDangerName(name)
                if name == "ScrambleLocalVisuals" or name == "DrScrambleEvent" then return false end
                local lower = string.lower(tostring(name))
                return string.find(lower, "portal", 1, true)
                    or string.find(lower, "teleport", 1, true)
                    or string.find(lower, "mech", 1, true)
                    or string.find(lower, "arena", 1, true)
                    or string.find(lower, "scramble", 1, true)
            end

            for _, child in ipairs(Workspace:GetChildren()) do
                if isDangerName(child.Name) then
                    if child:IsA("Folder") then
                        for _, sub in ipairs(child:GetChildren()) do addDangerBox(sub) end
                    else
                        addDangerBox(child)
                    end
                end
            end

            local world = Workspace:FindFirstChild("World")
            local build = world and world:FindFirstChild("Build")
            if build then
                for _, child in ipairs(build:GetChildren()) do
                    if isDangerName(child.Name) then addDangerBox(child) end
                end
            end

            cachedDangers = dangers
            return dangers
        end

        local function avoidDangers(fromPos, toPos)
            for _, danger in ipairs(refreshDangers()) do
                local minX = danger.MinX - 12
                local maxX = danger.MaxX + 12
                local minZ = danger.MinZ - 12
                local maxZ = danger.MaxZ + 12

                local segs = {
                    { fromPos.X, toPos.X - fromPos.X, minX, maxX },
                    { fromPos.Z, toPos.Z - fromPos.Z, minZ, maxZ }
                }
                local hit = true
                local t0, t1 = 0, 1

                for _, seg in ipairs(segs) do
                    local p, d, dmin, dmax = seg[1], seg[2], seg[3], seg[4]
                    if math.abs(d) < 1e-6 then
                        if p < dmin or p > dmax then hit = false end
                    else
                        local tNear = (dmin - p) / d
                        local tFar = (dmax - p) / d
                        if tNear > tFar then tNear, tFar = tFar, tNear end
                        t0 = math.max(t0, tNear)
                        t1 = math.min(t1, tFar)
                        if t0 > t1 then hit = false end
                    end
                end

                if hit and not (fromPos.X >= minX and fromPos.X <= maxX and fromPos.Z >= minZ and fromPos.Z <= maxZ) then
                    local edgeZ = math.abs(fromPos.Z - (minZ - 2)) <= math.abs(fromPos.Z - (maxZ + 2)) and (minZ - 2) or (maxZ + 2)
                    if edgeZ < -440 or edgeZ > -290 then
                        edgeZ = (edgeZ == minZ - 2) and (maxZ + 2) or (minZ - 2)
                    end
                    local edgeX = math.abs(fromPos.X - minX) <= math.abs(fromPos.X - maxX) and minX or maxX
                    return Vector3.new(edgeX, toPos.Y, edgeZ), danger.Name
                end
            end

            return toPos, nil
        end

        local function groundYAt(x, z, fallback)
            local root = characterParts()
            if not root then return fallback end
            local params = RaycastParams.new()
            params.FilterDescendantsInstances = { root.Parent }
            params.FilterType = Enum.RaycastFilterType.Exclude
            params.RespectCanCollide = true
            local origin = Vector3.new(x, root.Position.Y + 80, z)
            local hit = Workspace:Raycast(origin, Vector3.new(0, -160, 0), params)
            if hit then return hit.Position.Y end
            return fallback
        end

        local function runToEgg(targetPos, token)
            local root, humanoid = characterParts()
            if not root or not humanoid then return false, "character unavailable" end

            humanoid.PlatformStand = false
            humanoid.Sit = false

            local character = LocalPlayer.Character
            if character and character:FindFirstChildWhichIsA("Tool") then
                pcall(function() humanoid:UnequipTools() end)
            end

            AutoStealV2.Moving = true

            local waypoints = pathTo(targetPos)
            if #waypoints == 0 then
                AutoStealV2.Moving = false
                return false, "no path"
            end

            local now = os.clock()
            local lastStuckAt = os.clock()
            local lastStuckPos = root.Position

            for idx, wp in ipairs(waypoints) do
                local isFinal = (idx == #waypoints)
                local arriveDist = isFinal and 3.0 or 5.0

                while os.clock() - now < 180 and token == AutoStealV2.Token do
                    if AutoStealV2.StopRequested then
                        AutoStealV2.Moving = false
                        return false, "stop requested"
                    end
                    local curRoot, curHum = characterParts()
                    if not curRoot or not curHum then
                        AutoStealV2.Moving = false
                        return false, "character unavailable"
                    end

                    curHum.PlatformStand = false
                    curHum.Sit = false

                    local delta = Vector3.new(wp.X - curRoot.Position.X, 0, wp.Z - curRoot.Position.Z)
                    local dist = delta.Magnitude

                    if dist <= arriveDist then
                        break
                    end

                    local safeWp, danger = avoidDangers(curRoot.Position, wp)
                    local toTarget = Vector3.new(safeWp.X - curRoot.Position.X, 0, safeWp.Z - curRoot.Position.Z)
                    local wpDist = toTarget.Magnitude
                    local unit = wpDist > 0.01 and toTarget.Unit or Vector3.zero

                    local dt = RunService.Heartbeat:Wait()
                    local travelSpeed = tonumber(AutoStealV2.Speed) or 750
                    travelSpeed = math.clamp(travelSpeed, 100, 1200)

                    local stepDist = math.min(travelSpeed * dt, wpDist)
                    local nextPos = curRoot.Position + unit * stepDist
                    local gy = groundYAt(nextPos.X, nextPos.Z, curRoot.Position.Y) + 3

                    pcall(function()
                        curRoot.CFrame = CFrame.new(nextPos.X, gy, nextPos.Z) * CFrame.Angles(0, math.atan2(-unit.X, -unit.Z), 0)
                        curRoot.AssemblyLinearVelocity = Vector3.zero
                    end)

                    local totalDistToEgg = (Vector3.new(targetPos.X - curRoot.Position.X, 0, targetPos.Z - curRoot.Position.Z)).Magnitude
                    AutoStealV2.Status = string.format("Running to egg (%d studs left) [%.0f spd]", math.floor(totalDistToEgg + 0.5), travelSpeed)

                    if os.clock() - lastStuckAt >= 1.2 then
                        if (curRoot.Position - lastStuckPos).Magnitude < 2.0 then
                            pcall(function() curHum.Jump = true end)
                        end
                        lastStuckPos = curRoot.Position
                        lastStuckAt = os.clock()
                    end
                end

                if token ~= AutoStealV2.Token then
                    AutoStealV2.Moving = false
                    return false, "token cancelled"
                end
            end

            local curRoot, curHum = characterParts()
            if curRoot then
                pcall(function()
                    curRoot.AssemblyLinearVelocity = Vector3.new(0, math.min(curRoot.AssemblyLinearVelocity.Y, 0), 0)
                    if curHum then curHum:Move(Vector3.zero, false) end
                    local gy = groundYAt(targetPos.X, targetPos.Z, curRoot.Position.Y) + 3
                    curRoot.CFrame = CFrame.new(targetPos.X, gy, targetPos.Z)
                end)
            end

            AutoStealV2.Moving = false
            return true
        end

        local function pathSafe(target)
            local x, z = getGateway()
            local root = characterParts()
            local safe = getSafePoint()
            local start = root and root.Position or target
            local points = {}

            local function addGroundPoint(px, pz, fallbackY)
                local gy = groundYAt(px, pz, fallbackY)
                table.insert(points, Vector3.new(px, gy + 3, pz))
            end

            local function addDense(from, to)
                local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
                local steps = math.max(1, math.ceil(flat.Magnitude / 45))
                for step = 1, steps do
                    local alpha = step / steps
                    addGroundPoint(
                        from.X + (to.X - from.X) * alpha,
                        from.Z + (to.Z - from.Z) * alpha,
                        from.Y + (to.Y - from.Y) * alpha
                    )
                end
            end

            local laneStart = Vector3.new(start.X, start.Y, z)
            local gatewayPoint = Vector3.new(x, start.Y, z)
            addDense(start, laneStart)
            addDense(laneStart, gatewayPoint)
            addDense(gatewayPoint, safe)
            table.insert(points, safe)
            return points
        end

        local function lineDropDeliver(token, carryUid, slotKey, before)
            local root, humanoid = characterParts()
            if not root or not humanoid then return false, "character unavailable" end
            before = before or getInventoryCount()
            local safePos = getSafePoint()
            local gatewayX, laneZ = getGateway()
            local lineX = gatewayX or 552.2
            laneZ = math.clamp(laneZ or -364.5, -425, -300)

            local disabledUGI = {}
            pcall(function()
                for _, runSignal in ipairs({ RunService.Heartbeat, RunService.PreSimulation, RunService.PostSimulation }) do
                    for _, conn in ipairs(getconnections(runSignal)) do
                        local okFn, fn = pcall(function() return conn.Function end)
                        if okFn and type(fn) == "function" then
                            local okInfo, src = pcall(debug.info, fn, "s")
                            if okInfo and string.find(tostring(src), "UGI", 1, true) then
                                local okEnabled, isEnabledConn = pcall(function() return conn.Enabled end)
                                if not okEnabled or isEnabledConn ~= false then
                                    if pcall(function() conn:Disable() end) then
                                        table.insert(disabledUGI, conn)
                                    end
                                end
                            end
                        end
                    end
                end
            end)

            local function restoreUGI()
                for _, conn in ipairs(disabledUGI) do
                    pcall(function() conn:Enable() end)
                end
                table.clear(disabledUGI)
            end

            local function regrabDroppedEgg(allowWaitDrop)
                if allowWaitDrop then
                    if not AutoStealV2.Carrying then
                        return false
                    end
                    pcall(function()
                        local EggState = require(ReplicatedStorage.Client.EggState)
                        EggState.DropFieldEgg("PlayerRequest")
                    end)
                    local waitDrop = 0
                    while AutoStealV2.Carrying and waitDrop < 0.4 and token == AutoStealV2.Token do
                        waitDrop = waitDrop + RunService.Heartbeat:Wait()
                    end
                    if AutoStealV2.Carrying then
                        return true
                    end
                end

                local grabDeadline = os.clock() + 2.5
                while not AutoStealV2.Carrying and os.clock() < grabDeadline and token == AutoStealV2.Token do
                    if RawCarryRemote then
                        queueRawCarry(carryUid, slotKey)
                    end
                    pcall(function()
                        local EggState = require(ReplicatedStorage.Client.EggState)
                        EggState.CarryFieldEgg(carryUid, slotKey)
                    end)
                    task.wait(0.03)
                end

                local currentRoot = characterParts()
                if currentRoot then
                    pcall(function()
                        currentRoot.AssemblyLinearVelocity = Vector3.zero
                        currentRoot.AssemblyAngularVelocity = Vector3.zero
                    end)
                end

                return AutoStealV2.Carrying == true
            end

            local lineStopX = lineX + 48
            local vector = Vector3.new(lineStopX, groundYAt(lineStopX, laneZ) + 3, laneZ)

            local currentRoot = characterParts()
            if not currentRoot then
                restoreUGI()
                return false, "character unavailable"
            end

            local startX = currentRoot.Position.X
            local startZ = currentRoot.Position.Z

            if math.abs(startZ - laneZ) > 8 then
                local stepsZ = math.max(1, math.ceil(math.abs(startZ - laneZ) / 40))
                for i = 1, stepsZ do
                    if token ~= AutoStealV2.Token or not AutoStealV2.Carrying then break end
                    local curZ = startZ + (laneZ - startZ) * (i / stepsZ)
                    local gY = groundYAt(startX, curZ, currentRoot.Position.Y) + 3
                    local r = characterParts()
                    if r then
                        pcall(function()
                            r.CFrame = CFrame.new(startX, gY, curZ) * CFrame.Angles(0, math.rad(90), 0)
                            r.AssemblyLinearVelocity = Vector3.zero
                            r.AssemblyAngularVelocity = Vector3.zero
                        end)
                    end
                    RunService.Heartbeat:Wait()
                end
            end

            local hopStep = 35
            local hopGap = 0.02
            local rInit = characterParts()
            local x2 = rInit and rInit.Position.X or startX
            if AutoStealV2.Carrying and token == AutoStealV2.Token then
                regrabDroppedEgg(true)
            end
            local lastRefreshX = x2

            while x2 > vector.X and token == AutoStealV2.Token do
                if not AutoStealV2.Carrying then
                    AutoStealV2.Status = "Server dropped egg, regrabbing..."
                    if not regrabDroppedEgg(false) then
                        restoreUGI()
                        return false, "lost egg during hopping"
                    end
                    local r = characterParts()
                    if r then
                        x2 = r.Position.X
                        lastRefreshX = x2
                    end
                end

                x2 = math.max(x2 - hopStep, vector.X)
                local gY = groundYAt(x2, laneZ, currentRoot.Position.Y) + 3
                AutoStealV2.Status = string.format("Hopping home (X: %d)", math.floor(x2))

                local r = characterParts()
                if r then
                    pcall(function()
                        r.CFrame = CFrame.new(x2, gY, laneZ) * CFrame.Angles(0, math.rad(90), 0)
                        r.AssemblyLinearVelocity = Vector3.zero
                        r.AssemblyAngularVelocity = Vector3.zero
                    end)
                end

                if (lastRefreshX - x2) >= 50 and x2 > vector.X then
                    AutoStealV2.Status = string.format("Refreshing egg at X: %d...", math.floor(x2))
                    if AutoStealV2.Carrying then
                        regrabDroppedEgg(true)
                        lastRefreshX = x2
                    end
                end

                local hopWait = 0
                while hopWait < hopGap do
                    hopWait = hopWait + RunService.Heartbeat:Wait()
                end
            end

            if not AutoStealV2.Carrying and token == AutoStealV2.Token then
                AutoStealV2.Status = "Regrabbing egg before line..."
                regrabDroppedEgg(false)
            end

            AutoStealV2.Status = "Landing next to line..."
            local r = characterParts()
            if r then
                pcall(function()
                    r.CFrame = CFrame.new(vector.X, groundYAt(vector.X, laneZ) + 3, laneZ) * CFrame.Angles(0, math.rad(90), 0)
                    r.AssemblyLinearVelocity = Vector3.zero
                    r.AssemblyAngularVelocity = Vector3.zero
                end)
            end

            if AutoStealV2.Carrying and token == AutoStealV2.Token then
                AutoStealV2.Status = "Line drop: refreshing egg at line..."
                regrabDroppedEgg(true)
                task.wait(0.04)
            end

            AutoStealV2.Status = "Stepping into safe zone..."
            r = characterParts()
            if r then
                local tCross = os.clock()
                while os.clock() - tCross < 1.2 and token == AutoStealV2.Token do
                    local dt = RunService.Heartbeat:Wait()
                    local pos = r.Position
                    if pos.X <= 540 then break end
                    local step = 150 * dt
                    r.CFrame = CFrame.new(pos.X - step, pos.Y, laneZ)
                    r.AssemblyLinearVelocity = Vector3.zero
                end
            end

            local depositDeadline = os.clock() + 3.0
            local deposited = false
            while os.clock() < depositDeadline and token == AutoStealV2.Token do
                local curCount = getInventoryCount()
                if curCount > before then
                    deposited = true
                    break
                end
                if not AutoStealV2.Carrying then
                    task.wait(0.2)
                    if getInventoryCount() > before or before < 0 then
                        deposited = true
                    end
                    break
                end
                RunService.Heartbeat:Wait()
            end

            restoreUGI()

            if deposited then
                AutoStealV2.Status = "Egg delivered to safe zone!"
                return true
            else
                if AutoStealV2.Carrying then
                    pcall(function()
                        local EggState = require(ReplicatedStorage.Client.EggState)
                        EggState.DropFieldEgg("PlayerRequest")
                    end)
                end
                return false, "deposit timeout"
            end
        end

        local function firstAreaGuardRoot()
            local objects = Workspace:FindFirstChild("World")
            local areas = objects and objects:FindFirstChild("Areas")
            local guardAreas = areas and areas:FindFirstChild("GuardAreas")
            local forest = guardAreas and guardAreas:FindFirstChild("Forest")
            local guard = forest and forest:FindFirstChild("Guard")
            if not guard then return nil, nil end
            local part = guard.PrimaryPart
                or guard:FindFirstChild("HumanoidRootPart")
                or guard:FindFirstChildWhichIsA("BasePart", true)
            if not part then return nil, nil end
            return part, "Forest"
        end

        local function pickBaitEgg(snapshot, excludeUid, areaId, allowOwn)
            local root = characterParts()
            if not root then return nil end
            local best, bestScore
            for _, record in pairs(snapshot) do
                local cf = recordCFrame(record)
                if isStealableState(record) and type(record.Uid) == "string" and cf
                    and record.Uid ~= excludeUid
                    and (allowOwn == true or not isOwnEgg(record.Uid))
                    and (areaId == nil or tostring(record.AreaId) == tostring(areaId))
                then
                    local score = -getEarningRate(record) * 1000
                        - (cf.Position - root.Position).Magnitude
                    if not bestScore or score > bestScore then
                        best, bestScore = record, score
                    end
                end
            end
            return best
        end

        local visualHold = {
            Clone = nil,
            Subject = nil,
            Restore = {},
            Effects = {},
            Sounds = {},
            Connection = nil,
            Active = false,
        }

        local function isLeakingEffect(item)
            return item:IsA("Trail") or item:IsA("ParticleEmitter") or item:IsA("Beam")
                or item:IsA("Fire") or item:IsA("Smoke") or item:IsA("Sparkles")
        end

        local function hideRigVisuals(character)
            for _, item in ipairs(character:GetDescendants()) do
                if item:IsA("BasePart") or item:IsA("Decal") then
                    if visualHold.Restore[item] == nil then
                        visualHold.Restore[item] = item.LocalTransparencyModifier
                    end
                    item.LocalTransparencyModifier = 1
                elseif isLeakingEffect(item) then
                    if visualHold.Effects[item] == nil then
                        visualHold.Effects[item] = item.Enabled
                    end
                    if item.Enabled then item.Enabled = false end
                elseif item:IsA("Sound") then
                    if visualHold.Sounds[item] == nil then
                        visualHold.Sounds[item] = item.Volume
                    end
                    if item.Volume ~= 0 then item.Volume = 0 end
                end
            end
        end

        local function endVisualHold()
            visualHold.Active = false
            if visualHold.Connection then
                pcall(function() visualHold.Connection:Disconnect() end)
                visualHold.Connection = nil
            end
            if visualHold.Clone then
                pcall(function() visualHold.Clone:Destroy() end)
                visualHold.Clone = nil
            end
            visualHold.Subject = nil
            for part, value in pairs(visualHold.Restore) do
                pcall(function() part.LocalTransparencyModifier = value end)
            end
            for effect, value in pairs(visualHold.Effects) do
                pcall(function() effect.Enabled = value end)
            end
            for sound, value in pairs(visualHold.Sounds) do
                pcall(function() sound.Volume = value end)
            end
            visualHold.Restore = {}
            visualHold.Effects = {}
            visualHold.Sounds = {}
            local _, humanoid = characterParts()
            if Workspace.CurrentCamera and humanoid then
                pcall(function() Workspace.CurrentCamera.CameraSubject = humanoid end)
            end
        end

        local function beginVisualHold()
            endVisualHold()
            local character = LocalPlayer.Character
            local root = characterParts()
            if not character or not root then return false end

            character.Archivable = true
            local ok, clone = pcall(function() return character:Clone() end)
            if not ok or not clone then return false end
            clone.Name = "StandInCharacter"
            for _, item in ipairs(clone:GetDescendants()) do
                if item:IsA("LocalScript") or item:IsA("Script") then
                    pcall(function() item:Destroy() end)
                elseif item:IsA("BasePart") then
                    item.Anchored = true
                    item.CanCollide = false
                    item.CanTouch = false
                    item.CanQuery = false
                end
            end
            local cloneHumanoid = clone:FindFirstChildOfClass("Humanoid")
            if cloneHumanoid then
                cloneHumanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
                cloneHumanoid.HealthDisplayDistance = 0
                cloneHumanoid.NameDisplayDistance = 0
                pcall(function() cloneHumanoid:ChangeState(Enum.HumanoidStateType.Physics) end)
            end
            clone.Parent = Workspace

            hideRigVisuals(character)

            if Workspace.CurrentCamera then
                local subject = cloneHumanoid or clone:FindFirstChild("Head") or clone.PrimaryPart
                if subject then
                    visualHold.Subject = subject
                    pcall(function() Workspace.CurrentCamera.CameraSubject = subject end)
                end
            end

            visualHold.Clone = clone
            visualHold.Active = true
            visualHold.Connection = RunService.RenderStepped:Connect(function()
                if not visualHold.Active then return end
                local camera = Workspace.CurrentCamera
                local subject = visualHold.Subject
                if camera and subject and subject.Parent and camera.CameraSubject ~= subject then
                    camera.CameraSubject = subject
                end
                local live = LocalPlayer.Character
                if not live then return end
                hideRigVisuals(live)
            end)
            return true
        end

        AutoStealV2.BeginVisualHold = beginVisualHold
        AutoStealV2.EndVisualHold = endVisualHold

        local function tpPinCarry(uid, position, seconds, slotKey)
            local key = slotKey or slotKeyForUid(uid)
            local deadline = os.clock() + (seconds or 2.0)
            local pinning = true
            task.spawn(function()
                while pinning do
                    local root, humanoid = characterParts()
                    if not root then break end
                    if humanoid then humanoid.Sit = false end
                    root.CFrame = CFrame.new(position)
                    root.AssemblyLinearVelocity = Vector3.zero
                    root.AssemblyAngularVelocity = Vector3.zero
                    RunService.Heartbeat:Wait()
                end
            end)

            local carried = false
            while not carried and os.clock() < deadline do
                AutoStealV2.CarrySpamRequests += 1
                local okEgg, resEgg = pcall(EggState.CarryFieldEgg, uid, key)
                if okEgg and resEgg == true then
                    AutoStealV2.CarrySpamSuccesses += 1
                    carried = true
                    break
                end
                if RawCarryRemote then
                    local ok, result = pcall(function()
                        return RawCarryRemote:InvokeServer({ Uid = uid, FirstAreaSlotKey = key })
                    end)
                    if ok and result == true then
                        AutoStealV2.CarrySpamSuccesses += 1
                        carried = true
                        break
                    end
                end
                if AutoStealV2.LastCarryEvent and AutoStealV2.LastCarryEvent.Uid == uid and AutoStealV2.Carrying then
                    carried = true
                    break
                end
                task.wait(0.06)
            end

            pinning = false
            if carried then
                AutoStealV2.Carrying = true
                AutoStealV2.ScriptCarry = true
            end
            return carried
        end

        local function dropHeldEgg(pinPosition)
            if not AutoStealV2.Carrying then return true end
            local pinning = pinPosition ~= nil
            if pinning then
                task.spawn(function()
                    while pinning do
                        local root, humanoid = characterParts()
                        if not root then break end
                        if humanoid then humanoid.Sit = false end
                        root.CFrame = CFrame.new(pinPosition)
                        root.AssemblyLinearVelocity = Vector3.zero
                        root.AssemblyAngularVelocity = Vector3.zero
                        RunService.Heartbeat:Wait()
                    end
                end)
            end
            pcall(EggState.DropFieldEgg, "PlayerRequest")
            local deadline = os.clock() + 0.5
            while AutoStealV2.Carrying and os.clock() < deadline do
                RunService.Heartbeat:Wait()
            end
            if AutoStealV2.Carrying then
                pcall(EggState.DropFieldEgg, "PlayerRequest")
                local retry = os.clock() + 0.3
                while AutoStealV2.Carrying and os.clock() < retry do
                    RunService.Heartbeat:Wait()
                end
            end
            pinning = false
            AutoStealV2.Carrying = false
            AutoStealV2.ScriptCarry = false
            return true
        end

        local function resolveTargetPosition(uid, fallback, areaId, nestId)
            local live = liveEggPosition(uid)
            if live then return uid, live, slotKeyForUid(uid) end
            local snapshot = getFreshRecords()
            for _, record in pairs(snapshot) do
                if type(record) == "table" and record.Uid == uid then
                    local cf = recordCFrame(record)
                    if cf then return uid, cf.Position, firstAreaSlotKey(record) end
                end
            end
            for _, record in pairs(snapshot) do
                local cf = recordCFrame(record)
                if isStealableState(record) and cf
                    and tostring(record.AreaId) == tostring(areaId)
                    and tostring(record.NestId) == tostring(nestId)
                then
                    return record.Uid, cf.Position, firstAreaSlotKey(record)
                end
            end
            return uid, fallback, slotKeyForUid(uid)
        end

        local function runToSafe(token)
            local safePos = getSafePoint()
            local root, humanoid = characterParts()
            if not root or not humanoid then return false, "character unavailable" end

            AutoStealV2.Moving = true
            local now = os.clock()
            local lastJump = os.clock()
            local lastPos = root.Position

            while os.clock() - now < 30 and token == AutoStealV2.Token and AutoStealV2.Carrying do
                local curRoot, curHum = characterParts()
                if not curRoot or not curHum then break end

                curHum.PlatformStand = false
                curHum.Sit = false

                local diff = Vector3.new(safePos.X - curRoot.Position.X, 0, safePos.Z - curRoot.Position.Z)
                local dist = diff.Magnitude
                if dist <= 8 then break end

                local unit = diff.Unit
                local legalSpeed = getLegalWalkSpeed()
                local runRatio = math.clamp(tonumber(AutoStealV2.RunSpeed) or 1.0, 0.5, 1.2)
                local speed = math.max(legalSpeed * runRatio, 16)
                local vel = unit * math.min(speed, dist / 0.05)

                pcall(function()
                    curRoot.AssemblyLinearVelocity = Vector3.new(vel.X, curRoot.AssemblyLinearVelocity.Y, vel.Z)
                    curHum:Move(unit, false)
                end)

                AutoStealV2.Status = string.format("Running into safe zone (%d studs left)", math.floor(dist + 0.5))

                if os.clock() - lastJump >= 1.2 then
                    if (curRoot.Position - lastPos).Magnitude < 2.0 then
                        pcall(function() curHum.Jump = true end)
                    end
                    lastPos = curRoot.Position
                    lastJump = os.clock()
                end

                RunService.Heartbeat:Wait()
            end

            local curRoot, curHum = characterParts()
            if curRoot then
                pcall(function()
                    curRoot.AssemblyLinearVelocity = Vector3.zero
                    if curHum then curHum:Move(Vector3.zero, false) end
                end)
            end

            AutoStealV2.Moving = false
            return true
        end

        local function runTpStealOnce(token, target)
            AutoStealV2.TpAttempts += 1
            local targetUid = target.Uid
            local targetCFrame = recordCFrame(target)
            if not targetCFrame then
                AutoStealV2.TpFails += 1
                AutoStealV2.TpStatus = "Target has no position"
                return false
            end
            local targetPos = targetCFrame.Position
            local slotKey = firstAreaSlotKey(target)

            AutoStealV2.StopRequested = false
            AutoStealV2.Carrying = false
            AutoStealV2.ScriptCarry = false
            AutoStealV2.ReturningToSafe = false
            AutoStealV2.GuardLossPending = false
            AutoStealV2.RetryTargetUid = nil
            AutoStealV2.RetryTargetSince = nil
            AutoStealV2.ActiveTargetUid = targetUid
            AutoStealV2.ActiveTargetCategory = target.AssetCategory
            AutoStealV2.ActiveTargetAreaId = target.AreaId
            AutoStealV2.ActiveTargetNestId = target.NestId
            AutoStealV2.ActiveTargetEarningRate = getEarningRate(target)

            -- 1. Run to egg at normal run speed
            local legalSpd = getLegalWalkSpeed()
            local runRatio = math.clamp(tonumber(AutoStealV2.RunSpeed) or 1.0, 0.5, 1.2)
            AutoStealV2.TpStatus = string.format(
                "Running to %s %s at %.0f studs/s",
                getRarity(target), tostring(target.AssetCategory), legalSpd * runRatio
            )
            AutoStealV2.Status = AutoStealV2.TpStatus

            local reached, moveErr = runToEgg(targetPos, token)
            if not reached then
                AutoStealV2.TpFails += 1
                AutoStealV2.TpStatus = "Route stopped: " .. tostring(moveErr)
                AutoStealV2.Status = AutoStealV2.TpStatus
                return false
            end

            -- 2. Grab the egg
            AutoStealV2.TpStatus = "Grabbing " .. tostring(target.AssetCategory)
            AutoStealV2.Status = AutoStealV2.TpStatus
            local carried = AutoStealV2.Carrying
            local grabDeadline = os.clock() + 1.2
            repeat
                if RawCarryRemote then queueRawCarry(targetUid, slotKey) end
                carried = AutoStealV2.Carrying
                if not carried and not RawCarryRemote then
                    local ok, result = pcall(EggState.CarryFieldEgg, targetUid, slotKey)
                    carried = (ok and result == true) or AutoStealV2.Carrying
                end
                task.wait(0.02)
            until carried or os.clock() >= grabDeadline or token ~= AutoStealV2.Token

            if not carried then
                AutoStealV2.TpFails += 1
                AutoStealV2.Failed += 1
                AutoStealV2.TpStatus = "Carry request rejected"
                AutoStealV2.Status = AutoStealV2.TpStatus
                return false
            end
            AutoStealV2.Carrying = true
            AutoStealV2.ScriptCarry = true

            local before = getInventoryCount()

            -- 3. Inbound: Tween to Arena 1 along lane at safe speed (max 350 studs/s to avoid AC displacement penalty)
            local gatewayX, laneZ = getGateway()
            local lineX = gatewayX or 552.2
            laneZ = math.clamp(laneZ or -364.5, -425, -300)
            local arena1X = lineX + 16 -- Inside Arena 1, right next to line
            local arena1Pos = Vector3.new(arena1X, groundYAt(arena1X, laneZ) + 3, laneZ)

            AutoStealV2.TpStatus = "Tweening egg back to Arena 1..."
            AutoStealV2.Status = AutoStealV2.TpStatus

            -- Disable UGI during carry tween to bypass movement detection
            local disabledUGI = {}
            pcall(function()
                for _, runSignal in ipairs({ RunService.Heartbeat, RunService.PreSimulation, RunService.PostSimulation }) do
                    for _, conn in ipairs(getconnections(runSignal)) do
                        local okFn, fn = pcall(function() return conn.Function end)
                        if okFn and type(fn) == "function" then
                            local okInfo, src = pcall(debug.info, fn, "s")
                            if okInfo and string.find(tostring(src), "UGI", 1, true) then
                                local okEnabled, isEnabledConn = pcall(function() return conn.Enabled end)
                                if not okEnabled or isEnabledConn ~= false then
                                    if pcall(function() conn:Disable() end) then
                                        table.insert(disabledUGI, conn)
                                    end
                                end
                            end
                        end
                    end
                end
            end)

            local function restoreUGI()
                for _, conn in ipairs(disabledUGI) do
                    pcall(function() conn:Enable() end)
                end
                table.clear(disabledUGI)
            end

            -- Fast tween path to Arena 1 along lane
            local curRoot, curHum = characterParts()
            local safeCarrySpeed = math.clamp(tonumber(AutoStealV2.Speed) or 350, 100, 350)
            if curRoot and curHum then
                curHum.PlatformStand = true
                curRoot.AssemblyLinearVelocity = Vector3.zero
                curRoot.AssemblyAngularVelocity = Vector3.zero

                -- Align to laneZ first if off lane
                if math.abs(curRoot.Position.Z - laneZ) > 8 then
                    local alignPt = Vector3.new(curRoot.Position.X, groundYAt(curRoot.Position.X, laneZ) + 3, laneZ)
                    local distZ = (curRoot.Position - alignPt).Magnitude
                    local durZ = math.clamp(distZ / safeCarrySpeed, 0.04, 1.0)
                    local twZ = TweenService:Create(curRoot, TweenInfo.new(durZ, Enum.EasingStyle.Linear), { CFrame = CFrame.new(alignPt) })
                    twZ:Play()
                    twZ.Completed:Wait()
                end

                -- Tween along X to Arena 1
                curRoot = characterParts()
                if curRoot then
                    local distX = math.abs(curRoot.Position.X - arena1X)
                    local durX = math.clamp(distX / safeCarrySpeed, 0.05, 12.0)
                    local twX = TweenService:Create(curRoot, TweenInfo.new(durX, Enum.EasingStyle.Linear), {
                        CFrame = CFrame.new(arena1Pos) * CFrame.Angles(0, math.rad(90), 0)
                    })
                    twX:Play()
                    local dl = os.clock() + durX + 0.5
                    while twX.PlaybackState == Enum.PlaybackState.Playing and os.clock() < dl do
                        if token ~= AutoStealV2.Token then pcall(function() twX:Cancel() end) break end
                        RunService.Heartbeat:Wait()
                    end
                    pcall(function() twX:Cancel() end)
                end

                local r, h = characterParts()
                if h then
                    h.PlatformStand = false
                    pcall(function() h:ChangeState(Enum.HumanoidStateType.Running) end)
                end
                if r then
                    r.CFrame = CFrame.new(arena1Pos) * CFrame.Angles(0, math.rad(90), 0)
                    r.AssemblyLinearVelocity = Vector3.zero
                    r.AssemblyAngularVelocity = Vector3.zero
                end
            end

            -- 4. Settle firmly on ground and wait for ping replication before attempting drop
            AutoStealV2.TpStatus = "Arena 1 reached: Settling on ground..."
            AutoStealV2.Status = AutoStealV2.TpStatus
            task.wait(0.4)

            -- Attempt drop to reset carry displacement
            local dropAttempted = false
            if AutoStealV2.Carrying then
                local okDrop = pcall(function()
                    local EggState = require(ReplicatedStorage.Client.EggState)
                    return EggState.DropFieldEgg("PlayerRequest")
                end)
                dropAttempted = true
                local waitDrop = os.clock() + 0.6
                while AutoStealV2.Carrying and os.clock() < waitDrop and token == AutoStealV2.Token do
                    RunService.Heartbeat:Wait()
                end
            end

            -- 5. If dropped, regrab immediately
            if not AutoStealV2.Carrying and dropAttempted then
                AutoStealV2.TpStatus = "Regrabbing egg at Arena 1..."
                AutoStealV2.Status = AutoStealV2.TpStatus

                local regrabDeadline = os.clock() + 2.5
                while not AutoStealV2.Carrying and os.clock() < regrabDeadline and token == AutoStealV2.Token do
                    local r = characterParts()
                    if r then
                        r.CFrame = CFrame.new(arena1Pos) * CFrame.Angles(0, math.rad(90), 0)
                        r.AssemblyLinearVelocity = Vector3.zero
                    end
                    if RawCarryRemote then queueRawCarry(targetUid, slotKey) end
                    pcall(function()
                        local EggState = require(ReplicatedStorage.Client.EggState)
                        EggState.CarryFieldEgg(targetUid, slotKey)
                    end)
                    task.wait(0.04)
                end
            end

            -- Restore UGI connections
            restoreUGI()

            -- 6. Run speed into safe zone to deposit (whether regrabbed or still holding)
            if AutoStealV2.Carrying then
                AutoStealV2.TpStatus = "Running into safe zone..."
                AutoStealV2.Status = AutoStealV2.TpStatus
                runToSafe(token)
            end

            -- Wait for deposit
            local depositDeadline = os.clock() + 3.0
            local deposited = false
            while os.clock() < depositDeadline and token == AutoStealV2.Token do
                local curCount = getInventoryCount()
                if curCount > before then
                    deposited = true
                    break
                end
                if not AutoStealV2.Carrying then
                    task.wait(0.2)
                    if getInventoryCount() > before or before < 0 then
                        deposited = true
                    end
                    break
                end
                RunService.Heartbeat:Wait()
            end

            if deposited then
                AutoStealV2.TpSteals += 1
                AutoStealV2.Stolen += 1
                AutoStealV2.Carrying = false
                AutoStealV2.ScriptCarry = false
                AutoStealV2.ActiveTargetUid = nil
                AutoStealV2.ActiveTargetCategory = nil
                AutoStealV2.ActiveTargetAreaId = nil
                AutoStealV2.ActiveTargetNestId = nil
                AutoStealV2.TpStatus = string.format("Instant stolen %d egg(s)", AutoStealV2.TpSteals)
                AutoStealV2.Status = string.format("Stolen %d egg(s)", AutoStealV2.Stolen)
                if ScriptEnv.SAE_OnEggStolen then pcall(ScriptEnv.SAE_OnEggStolen, target) end
                return true
            else
                if AutoStealV2.Carrying then
                    pcall(function()
                        local EggState = require(ReplicatedStorage.Client.EggState)
                        EggState.DropFieldEgg("PlayerRequest")
                    end)
                end
                AutoStealV2.TpFails += 1
                AutoStealV2.Failed += 1
                AutoStealV2.TpStatus = "Delivery timed out"
                AutoStealV2.Status = AutoStealV2.TpStatus
                return false
            end
        end
        local function stealFieldEggByInstantSteal(record)
            if not record or not record.Uid then return false end
            if not prepareStealHumanoid() then return false end
            AutoStealV2.StopRequested = false
            escapeTreadmill(AutoStealV2.Token)
            AutoStealV2.GuardLossPending = false
            AutoStealV2.ActiveTargetUid = record.Uid
            AutoStealV2.ActiveTargetCategory = record.AssetCategory
            AutoStealV2.ActiveTargetAreaId = record.AreaId
            AutoStealV2.ActiveTargetNestId = record.NestId
            AutoStealV2.ActiveTargetEarningRate = getEarningRate(record)
            return runTpStealOnce(AutoStealV2.Token, record)
        end
        AutoStealV2.StealFieldEggByInstantSteal = stealFieldEggByInstantSteal

        local runOnce
        local function stealFieldEggGeneral(record)
            if not record or not record.Uid then return false end
            if AutoStealV2.TpStealEnabled then
                return stealFieldEggByInstantSteal(record)
            else
                if not prepareStealHumanoid() then return false end
                AutoStealV2.StopRequested = false
                escapeTreadmill(AutoStealV2.Token)
                AutoStealV2.GuardLossPending = false
                AutoStealV2.ActiveTargetUid = record.Uid
                AutoStealV2.ActiveTargetCategory = record.AssetCategory
                AutoStealV2.ActiveTargetAreaId = record.AreaId
                AutoStealV2.ActiveTargetNestId = record.NestId
                AutoStealV2.ActiveTargetEarningRate = getEarningRate(record)
                return runOnce(AutoStealV2.Token, record)
            end
        end
        AutoStealV2.StealFieldEgg = stealFieldEggGeneral

        function AutoStealV2.RagdollWarpTo(destination)
            if typeof(destination) ~= "Vector3" then return false end
            if not prepareStealHumanoid() then return false end
            AutoStealV2.StopRequested = false
            escapeTreadmill(AutoStealV2.Token)

            do
                local character = LocalPlayer.Character
                local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    pcall(function() humanoid:UnequipTools() end)
                    task.wait(0.1)
                end
            end

            local guardRoot = firstAreaGuardRoot()
            if not guardRoot then
                AutoStealV2.TpStatus = "RagdollWarp: guard not found"
                return false
            end

            local clearDeadline = os.clock() + 2.0
            while (isRagdolledNow() or ragdollWindowLeft() > 0.05) and os.clock() < clearDeadline do
                local character = LocalPlayer.Character
                if Ragdoll and character then
                    pcall(Ragdoll.ClearClientRagdoll, character)
                end
                local _, humanoid = characterParts()
                if humanoid then
                    humanoid.Sit = false
                    humanoid.PlatformStand = false
                    pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end)
                    pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Running) end)
                end
                RunService.Heartbeat:Wait()
            end
            if isRagdolledNow() or ragdollWindowLeft() > 0.05 then
                AutoStealV2.TpStatus = "RagdollWarp: old ragdoll stuck"
                return false
            end

            local snapshot = getFreshRecords()
            local bait = pickBaitEgg(snapshot, nil, "Forest", false)
                or pickBaitEgg(snapshot, nil, "Forest", true)
            if not bait then
                AutoStealV2.TpStatus = "RagdollWarp: no bait egg"
                return false
            end
            local baitPos = recordCFrame(bait).Position
            local baitSlotKey = firstAreaSlotKey(bait)

            local reached = movePath(pathTo(baitPos), AutoStealV2.Token, false)
            if not reached then
                AutoStealV2.TpStatus = "RagdollWarp: bait route stopped"
                return false
            end
            if not tpPinCarry(bait.Uid, baitPos, 2.0, baitSlotKey) then
                AutoStealV2.TpStatus = "RagdollWarp: bait carry rejected"
                return false
            end

            local baseWindow = ragdollWindowLeft()
            local hitDeadline = os.clock() + 6
            local ragdolled = false
            local pinnedFrames = 0
            while os.clock() < hitDeadline do
                local root, humanoid = characterParts()
                if not root then break end
                if humanoid then
                    humanoid.Sit = false
                    humanoid.PlatformStand = false
                end
                if not guardRoot.Parent then
                    guardRoot = firstAreaGuardRoot()
                    if not guardRoot then break end
                end
                root.CFrame = CFrame.new(guardRoot.Position + Vector3.new(0, 1, 0))
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
                pinnedFrames += 1
                if pinnedFrames >= 3
                    and (isRagdolledNow() or ragdollWindowLeft() > baseWindow + 0.15)
                then
                    ragdolled = true
                    break
                end
                RunService.Heartbeat:Wait()
            end

            pcall(function()
                local EggState = require(ReplicatedStorage.Client.EggState)
                EggState.DropFieldEgg("PlayerRequest")
            end)
            AutoStealV2.Carrying = false
            AutoStealV2.ScriptCarry = false

            if not ragdolled then
                AutoStealV2.TpStatus = "RagdollWarp: guard never hit"
                return false
            end

            local windowLeft = ragdollWindowLeft()
            if windowLeft <= 0.05 then windowLeft = 1.2 end
            AutoStealV2.TpStatus = string.format("RagdollWarp: riding %.2fs window", windowLeft)

            local rideDeadline = os.clock() + 3
            while os.clock() < rideDeadline
                and (isRagdolledNow() or ragdollWindowLeft() > 0.05)
            do
                local root, humanoid = characterParts()
                if not root then break end
                if humanoid then humanoid.Sit = false end
                root.CFrame = CFrame.new(destination)
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
                RunService.Heartbeat:Wait()
            end

            local settleDeadline = os.clock() + 3.5
            while os.clock() < settleDeadline
                and (isRagdolledNow() or ragdollWindowLeft() > 0.05)
            do
                local root = characterParts()
                if root then
                    root.CFrame = CFrame.new(destination)
                    root.AssemblyLinearVelocity = Vector3.zero
                end
                RunService.Heartbeat:Wait()
            end

            local _, humanoid = characterParts()
            if humanoid then
                humanoid.Sit = false
                humanoid.PlatformStand = false
                pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end)
                pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Running) end)
            end

            local root = characterParts()
            local arrived = root and (root.Position - destination).Magnitude <= 12
            AutoStealV2.TpStatus = arrived
                and "RagdollWarp: arrived"
                or "RagdollWarp: position rolled back"
            return arrived == true
        end

        local function infestedInventoryUids()
            local fn = Save and (Save.Get or Save.Peek)
            local ok, save = pcall(fn)
            local result = {}
            if not ok or type(save) ~= "table" or type(save.EggInventory) ~= "table" then
                return result
            end
            for uid, record in pairs(save.EggInventory) do
                if type(uid) == "string" and type(record) == "table"
                    and record.HasParasite == true and record.Placement == nil
                    and eventRarityAllowed(getRarity(record))
                then
                    table.insert(result, uid)
                end
            end
            return result
        end

        local function findMonsterModel()
            local folder = Workspace:FindFirstChild("MonsterParasiteMonsters")
            if not folder then return nil end
            local mine = folder:FindFirstChild("Monster_" .. tostring(LocalPlayer.UserId))
            if mine then return mine end
            return folder:FindFirstChildOfClass("Model")
        end

        local function monsterPosition()
            local monster = findMonsterModel()
            if not monster then return nil end
            local ok, pivot = pcall(monster.GetPivot, monster)
            if ok and pivot then return pivot.Position end
            local part = monster.PrimaryPart or monster:FindFirstChildWhichIsA("BasePart", true)
            return part and part.Position or nil
        end

        local function heldEggTool()
            local character = LocalPlayer.Character
            if not character then return nil end
            for _, child in ipairs(character:GetChildren()) do
                if child:IsA("Tool") then return child end
            end
            return nil
        end

        local function equipEggTool(uid)
            pcall(function() EggState.WearEggTool(uid) end)
            local character = LocalPlayer.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            if not character or not humanoid then return false end
            local deadline = os.clock() + 1.2
            while os.clock() < deadline do
                local tool = heldEggTool()
                if tool then return true end
                local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
                if backpack then
                    for _, child in ipairs(backpack:GetChildren()) do
                        if child:IsA("Tool") then
                            pcall(function() humanoid:EquipTool(child) end)
                            break
                        end
                    end
                end
                task.wait(0.08)
            end
            return heldEggTool() ~= nil
        end

        local function unequipEggTool()
            pcall(function() EggState.DoffEggTool() end)
            local character = LocalPlayer.Character
            local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
            local tool = heldEggTool()
            if tool and backpack and character then
                pcall(function() tool.Parent = backpack end)
            end
        end

        local function moveToMonster(token)
            local position = monsterPosition()
            if not position then return false, "monster not spawned" end
            local root = characterParts()
            if not root then return false, "character unavailable" end
            local flat = (root.Position - position) * Vector3.new(1, 0, 1)
            local direction = flat.Magnitude > 0.01 and flat.Unit or Vector3.new(1, 0, 0)
            local stand = Vector3.new(
                position.X + direction.X * 9,
                position.Y + 2,
                position.Z + direction.Z * 9
            )
            if AutoStealV2.TpStealEnabled then
                local deadline = os.clock() + 0.6
                while os.clock() < deadline do
                    if token ~= AutoStealV2.Token then return false, "cancelled" end
                    local liveRoot, humanoid = characterParts()
                    if not liveRoot then return false, "character unavailable" end
                    if humanoid then humanoid.Sit = false end
                    liveRoot.CFrame = CFrame.new(stand)
                    liveRoot.AssemblyLinearVelocity = Vector3.zero
                    liveRoot.AssemblyAngularVelocity = Vector3.zero
                    RunService.Heartbeat:Wait()
                end
                local finalRoot = characterParts()
                if finalRoot and (finalRoot.Position - position).Magnitude <= 14 then
                    return true
                end
                return false, "could not hold position next to monster"
            end
            return movePath({ Vector3.new(root.Position.X, stand.Y, root.Position.Z), stand }, token, true)
        end

        local function feedInfestedEggs(token)
            local pending = infestedInventoryUids()
            if #pending == 0 then
                AutoStealV2.EventStatus = "No infested egg in inventory"
                return false
            end
            if not monsterPosition() then
                AutoStealV2.EventStatus = "Monster not spawned yet"
                return false
            end
            AutoStealV2.EventFeeding = true
            local fed = 0
            for index, uid in ipairs(pending) do
                if token ~= AutoStealV2.Token or not AutoStealV2.EventEnabled then break end
                AutoStealV2.EventStatus = string.format(
                    "Feeding infested egg %d/%d", index, #pending
                )
                if equipEggTool(uid) then
                    local moved = moveToMonster(token)
                    if moved then
                        task.wait(0.15)
                        local ok, result = pcall(function()
                            return FeedRemote:InvokeServer()
                        end)
                        if ok and type(result) == "table" and result.Success == true then
                            fed += 1
                            AutoStealV2.EventFeeds += 1
                            AutoStealV2.EventStatus = string.format(
                                "Fed %d egg(s) - charge %s",
                                AutoStealV2.EventFeeds, tostring(result.Charge)
                            )
                        else
                            AutoStealV2.EventStatus = "Feed rejected: " .. tostring(
                                type(result) == "table" and result.Message or result
                            )
                        end
                    else
                        AutoStealV2.EventStatus = "Could not reach monster"
                    end
                else
                    AutoStealV2.EventStatus = "Could not hold infested egg"
                end
                unequipEggTool()
                task.wait(0.2)
            end
            AutoStealV2.EventFeeding = false
            endVisualHold()
            if fed > 0 then
                AutoStealV2.EventStatus = string.format(
                    "Fed %d egg(s) this pass (%d total)", fed, AutoStealV2.EventFeeds
                )
                return true
            end
            return false
        end

        runOnce = function(token, specificRecord)
            local night, resetSoon, seconds, dayReady, dayReadyIn = refreshCycleState()
            if night or resetSoon or not dayReady then
                AutoStealV2.Status = night and "Night reset - waiting in safe zone"
                    or (resetSoon and string.format("Reset in %.0fs - waiting", seconds)
                    or string.format("Day preparing/wall opening - %.1fs", dayReadyIn))
                return false
            end

            AutoStealV2.StopRequested = false

            local record = specificRecord or pickTarget()
            if not record then
                AutoStealV2.Status = AutoStealV2.RetryTargetUid
                    and "Waiting for guard-returned egg UID"
                    or "No egg matches the enabled modes"
                return false
            end

            if not prepareStealHumanoid() then
                AutoStealV2.Status = "Steal humanoid unavailable"
                return false
            end
            if not escapeTreadmill(token) then
                return false
            end
            AutoStealV2.GuardLossPending = false
            AutoStealV2.ActiveTargetUid = record.Uid
            AutoStealV2.ActiveTargetCategory = record.AssetCategory
            AutoStealV2.ActiveTargetAreaId = record.AreaId
            AutoStealV2.ActiveTargetNestId = record.NestId
            AutoStealV2.ActiveTargetEarningRate = getEarningRate(record)
            local target = recordCFrame(record).Position
            if AutoStealV2.TpStealEnabled then
                return runTpStealOnce(token, record)
            end
            local guardRetry = AutoStealV2.RetryTargetUid == record.Uid
            if guardRetry then
                if AutoStealV2.RetryReason == "guard" then
                    AutoStealV2.GuardRetryAttempts += 1
                    AutoStealV2.Status = string.format(
                        "Guard retry #%d - same %s %s",
                        AutoStealV2.GuardRetryAttempts, getRarity(record), tostring(record.AssetCategory)
                    )
                else
                    AutoStealV2.AntiRagdollRetryAttempts += 1
                    AutoStealV2.Status = string.format(
                        "Anti-ragdoll retry #%d - same %s %s",
                        AutoStealV2.AntiRagdollRetryAttempts, getRarity(record), tostring(record.AssetCategory)
                    )
                end
            else
                local legalSpd = getLegalWalkSpeed()
                local runRatio = math.clamp(tonumber(AutoStealV2.RunSpeed) or 1.0, 0.5, 1.2)
                AutoStealV2.Status = string.format(
                    "Running to %s %s (%g/s) at %.0f studs/s",
                    getRarity(record), tostring(record.AssetCategory),
                    AutoStealV2.ActiveTargetEarningRate, legalSpd * runRatio
                )
            end
            local reached, moveError = runToEgg(target, token)
            if not reached then
                AutoStealV2.Status = "Route stopped: " .. tostring(moveError)
                return false
            end

            if isOnTreadmill() and not escapeTreadmill(token) then
                return false
            end

            task.wait(0.2)
            AutoStealV2.Status = "Grabbing " .. tostring(record.AssetCategory)
            local slotKey = firstAreaSlotKey(record)
            local carried = AutoStealV2.Carrying
            local grabDeadline = os.clock() + 2.0
            repeat
                if RawCarryRemote then queueRawCarry(record.Uid, slotKey) end
                carried = AutoStealV2.Carrying
                if not carried and not RawCarryRemote then
                    local ok, result = pcall(EggState.CarryFieldEgg, record.Uid, slotKey)
                    carried = (ok and result == true) or AutoStealV2.Carrying
                end
                task.wait(0.03)
            until carried or os.clock() >= grabDeadline or token ~= AutoStealV2.Token
            if not carried then
                AutoStealV2.Failed += 1
                AutoStealV2.Status = "Carry request rejected"
                return false
            end
            AutoStealV2.Carrying = true
            AutoStealV2.ScriptCarry = true
            AutoStealV2.RetryTargetUid = nil
            AutoStealV2.RetryTargetSince = nil
            AutoStealV2.RetryReason = nil
            AutoStealV2.RetryTargetCategory = nil
            AutoStealV2.RetryTargetAreaId = nil
            AutoStealV2.RetryTargetNestId = nil
            AutoStealV2.RetryLossPosition = nil

            local before = getInventoryCount()
            AutoStealV2.Status = "Returning egg to safe zone"
            AutoStealV2.ReturningToSafe = true
            startReturnRace(record.Uid)
            local returned, returnError = lineDropDeliver(
                token, record.Uid, slotKey, before
            )
            stopReturnRace()
            AutoStealV2.ReturningToSafe = false
            if not returned then
                AutoStealV2.Status = "Return stopped: " .. tostring(returnError)
            end
            if returnError == "remote regrabbed" then
                AutoStealV2.Status = "Egg confirmed - resuming safe from current position"
                return false
            end
            if returnError == "guard caught egg" then
                recoverFromStun()
                AutoStealV2.Status = "Guard caught egg - retrying same UID"
                return false
            end

            local after = getInventoryCount()
            local finalRoot = characterParts()
            local reachedSafe = returned or (finalRoot and (finalRoot.Position - getSafePoint()).Magnitude <= 35)
            if (returned or reachedSafe) and (after > before or before < 0) then
                AutoStealV2.Carrying = false
                AutoStealV2.ScriptCarry = false
                AutoStealV2.ActiveTargetUid = nil
                AutoStealV2.ActiveTargetCategory = nil
                AutoStealV2.ActiveTargetAreaId = nil
                AutoStealV2.ActiveTargetNestId = nil
                AutoStealV2.RetryTargetUid = nil
                AutoStealV2.RetryTargetSince = nil
                AutoStealV2.GuardLossPending = false
                AutoStealV2.RetryReason = nil
                AutoStealV2.RetryTargetCategory = nil
                AutoStealV2.RetryTargetAreaId = nil
                AutoStealV2.RetryTargetNestId = nil
                AutoStealV2.RetryLossPosition = nil
                AutoStealV2.Stolen += 1
                AutoStealV2.Status = string.format("Stolen %d egg(s)", AutoStealV2.Stolen)
                if ScriptEnv.SAE_OnEggStolen then pcall(ScriptEnv.SAE_OnEggStolen, record) end
                return true
            end
            AutoStealV2.Failed += 1
            AutoStealV2.Status = "Step-hop delivery failed: " .. tostring(returnError or "not deposited")
            return false
        end

        local function returnHeldEgg(token)
            local root = characterParts()
            if not root then
                AutoStealV2.Status = "Cannot recover held egg: character unavailable"
                return false
            end
            local before = getInventoryCount()
            AutoStealV2.Status = "Recovering held egg to safe zone"
            AutoStealV2.ReturningToSafe = true
            startReturnRace(AutoStealV2.ActiveTargetUid)
            local returned, returnError = lineDropDeliver(
                token,
                AutoStealV2.ActiveTargetUid,
                nil,
                before
            )
            stopReturnRace()
            AutoStealV2.ReturningToSafe = false

            local after = getInventoryCount()
            local finalRoot = characterParts()
            local reachedSafe = returned or (finalRoot and (finalRoot.Position - getSafePoint()).Magnitude <= 35)
            if (returned or reachedSafe) and after > before then
                AutoStealV2.Carrying = false
                AutoStealV2.ScriptCarry = false
                AutoStealV2.StopRequested = false
                AutoStealV2.Stolen += 1
                AutoStealV2.Status = string.format("Recovered held egg (%d total)", AutoStealV2.Stolen)
                return true
            end
            if (returned or reachedSafe) and not AutoStealV2.Carrying then
                AutoStealV2.StopRequested = false
                AutoStealV2.Status = "Held egg cleared"
                return true
            end
            AutoStealV2.Status = "Held egg delivery failed: " .. tostring(returnError or "deposit timeout")
            return false
        end

        function AutoStealV2.SetMode(key, value)
            AutoStealV2[key] = value == true
            if key == "TpStealEnabled" then
                AutoStealV2.RagdollWindowActive = false
                if not AutoStealV2.TpStealEnabled then endVisualHold() end
                AutoStealV2.TpStatus = AutoStealV2.TpStealEnabled
                    and "Instant steal armed" or "Idle"
                return
            end
            if not isEnabled() then
                stopCarrySpam()
                stopCarryChase()
                stopReturnRace()
                AutoStealV2.RetryTargetUid = nil
                AutoStealV2.RetryTargetSince = nil
                AutoStealV2.RetryReason = nil
                AutoStealV2.ActiveTargetUid = nil
                AutoStealV2.ActiveTargetCategory = nil
                AutoStealV2.ActiveTargetAreaId = nil
                AutoStealV2.ActiveTargetNestId = nil
                AutoStealV2.RetryLossPosition = nil
                AutoStealV2.GuardLossPending = false
                AutoStealV2.RecoveryUntil = 0
                if not AutoStealV2.Busy then
                    AutoStealV2.Carrying = false
                    AutoStealV2.ScriptCarry = false
                    AutoStealV2.ReturningToSafe = false
                    AutoStealV2.StopRequested = false
                    AutoStealV2.Token += 1
                    if AutoStealV2.ActiveTween then pcall(function() AutoStealV2.ActiveTween:Cancel() end) end
                    AutoStealV2.Status = "Stopped"
                else
                    AutoStealV2.StopRequested = true
                    AutoStealV2.Status = "Stopping after reaching safe zone"
                end
                return
            end
            AutoStealV2.StopRequested = false
            AutoStealV2.Token += 1
            removeAutoStealTrapHitboxes()
        end

        function AutoStealV2.SetAutoTreadmill(value)
            AutoStealV2.AutoTreadmill = value == true
            if not value and AutoStealV2.TreadmillTraining then
                escapeTreadmill(AutoStealV2.Token)
            end
        end

        local function disableAllGuardColliders()
            local ga = Workspace:FindFirstChild("World")
            ga = ga and ga:FindFirstChild("Areas")
            ga = ga and ga:FindFirstChild("GuardAreas")
            if ga then
                for _, area in ipairs(ga:GetChildren()) do
                    local g = area:FindFirstChild("Guard")
                    if g then
                        for _, part in ipairs(g:GetDescendants()) do
                            if part:IsA("BasePart") then
                                pcall(function()
                                    part.CanCollide = false
                                    part.CanTouch = false
                                end)
                            end
                        end
                    end
                end
            end
        end

        task.spawn(function()
            while not AutoStealV2.SchedulerClosed and ScriptEnv.SAE_RunToken == entryToken do
                task.wait(0.2)
                if isEnabled() then
                    removeAutoStealTrapHitboxes()
                    disableAllGuardColliders()
                end
                local night, resetSoon, seconds, dayReady, dayReadyIn = refreshCycleState()
                local utilityRuntime = ScriptEnv.SAE_UtilityAutomation
                local utilityBusy = type(utilityRuntime) == "table" and utilityRuntime.Busy == true

                local targetAvailable = false
                if not night and not resetSoon and dayReady and isEnabled() then
                    targetAvailable = hasAvailableStealTarget()
                end

                if isEnabled() and (night or resetSoon or not dayReady) and not AutoStealV2.Busy then
                    AutoStealV2.Running = false
                    if not AutoStealV2.TreadmillTraining then
                        AutoStealV2.Status = night and "Night reset - waiting in safe zone"
                            or (resetSoon and string.format("Reset in %.0fs - waiting", seconds)
                            or string.format("Day preparing/wall opening - %.1fs", dayReadyIn))
                    end
                elseif AutoStealV2.Ready
                    and ((targetAvailable and isEnabled()) or AutoStealV2.Carrying or (AutoStealV2.StopRequested and AutoStealV2.Carrying))
                    and not AutoStealV2.Busy
                    and (not utilityBusy or AutoStealV2.Carrying)
                then
                    AutoStealV2.Busy = true
                    AutoStealV2.Running = true
                    local token = AutoStealV2.Token
                    local ok, err = xpcall(function()
                        if AutoStealV2.Carrying then
                            if AutoStealV2.ActiveTargetUid ~= nil or AutoStealV2.ReturningToSafe or AutoStealV2.GuardLossPending then
                                AutoStealV2.ScriptCarry = true
                            end
                            if not AutoStealV2.ScriptCarry then
                                AutoStealV2.Status = "Holding your egg - script paused"
                                return false
                            end
                            return returnHeldEgg(token)
                        else
                            return runOnce(token)
                        end
                    end, debug.traceback)
                    AutoStealV2.Busy = false
                    AutoStealV2.Running = false
                    AutoStealV2.ReturningToSafe = false
                    if not ok then
                        AutoStealV2.Failed += 1
                        AutoStealV2.Status = "Error: " .. tostring(err):match("^[^\n]+")
                    elseif not isEnabled() then
                        AutoStealV2.Status = "Stopped"
                    end
                else
                    if isEnabled() and not AutoStealV2.Busy and not AutoStealV2.Carrying and not targetAvailable then
                        AutoStealV2.Running = false
                        if not AutoStealV2.TreadmillTraining and not AutoStealV2.Carrying then
                            AutoStealV2.Status = "No egg matches the enabled modes (Idle)"
                        end
                    end
                end
            end
            AutoStealV2.Busy = false
            AutoStealV2.Running = false
        end)

        AutoStealV2.TrapAddedConnection = Workspace.DescendantAdded:Connect(function(instance)
            if not isEnabled() then return end
            local debris = Workspace:FindFirstChild("__DEBRIS")
            if instance.Name == "Hitbox" and instance.Parent
                and instance.Parent.Name == "PlayerTrap"
                and instance.Parent.Parent == debris
            then
                task.defer(function()
                    if isEnabled() and instance.Parent then
                        instance:Destroy()
                        AutoStealV2.TrapHitboxesRemoved += 1
                    end
                end)
            elseif instance.Name == "PlayerTrap" and instance.Parent == debris then
                task.defer(function()
                    if isEnabled() then removeAutoStealTrapHitboxes() end
                end)
            end
        end)

        if AutoStealV2.Ready then
            pcall(function()
                AutoStealV2.CarryConnection = EggState.CarryChanged:Connect(function(state)
                    if not isEnabled()
                        and not AutoStealV2.Busy
                        and not AutoStealV2.Running
                        and not AutoStealV2.ReturningToSafe
                    then
                        AutoStealV2.Carrying = false
                        AutoStealV2.GuardLossPending = false
                        return
                    end
                    AutoStealV2.LastCarryEvent = state
                    local wasCarrying = AutoStealV2.Carrying
                    local nowCarrying = false
                    if AutoStealV2.EventFeeding ~= true then
                        if type(state) == "table" then
                            nowCarrying = state.IsCarrying == true
                                or (state.Uid ~= nil and state.IsCarrying ~= false)
                        else
                            nowCarrying = state == true
                        end
                    end
                    AutoStealV2.Carrying = nowCarrying
                    if nowCarrying then
                        if AutoStealV2.Busy or AutoStealV2.Running or AutoStealV2.ReturningToSafe or AutoStealV2.GuardLossPending or AutoStealV2.ActiveTargetUid ~= nil then
                            AutoStealV2.ScriptCarry = true
                        end
                    elseif not AutoStealV2.GuardLossPending then
                        AutoStealV2.ScriptCarry = false
                    end
                    if nowCarrying and AutoStealV2.GuardLossPending
                        and AutoStealV2.ActiveTargetUid
                    then
                        AutoStealV2.GuardLossPending = false
                        AutoStealV2.ScriptCarry = true
                        stopCarrySpam()
                        stopCarryChase()
                        AutoStealV2.RetryTargetUid = nil
                        AutoStealV2.RetryTargetSince = nil
                        AutoStealV2.RetryReason = nil
                        AutoStealV2.RetryTargetCategory = nil
                        AutoStealV2.RetryTargetAreaId = nil
                        AutoStealV2.RetryTargetNestId = nil
                        AutoStealV2.RetryLossPosition = nil
                        AutoStealV2.Status = "Re-grabbed same egg - continuing safe"
                    end
                    if not nowCarrying and AutoStealV2.ReturningToSafe
                        and AutoStealV2.ActiveTargetUid
                        and not AutoStealV2.GuardLossPending
                    then
                        local root = characterParts()
                        local outsideSafe = not root or (root.Position - getSafePoint()).Magnitude > 45
                        if outsideSafe then
                            AutoStealV2.GuardLossPending = true
                            AutoStealV2.RetryTargetUid = AutoStealV2.ActiveTargetUid
                            AutoStealV2.RetryTargetSince = os.clock()
                            AutoStealV2.RetryReason = "guard"
                            AutoStealV2.RetryTargetCategory = AutoStealV2.ActiveTargetCategory
                            AutoStealV2.RetryTargetAreaId = AutoStealV2.ActiveTargetAreaId
                            AutoStealV2.RetryTargetNestId = AutoStealV2.ActiveTargetNestId
                            AutoStealV2.RetryLossPosition = root and root.Position or nil
                            AutoStealV2.GuardLosses += 1
                            AutoStealV2.CarryLossSerial += 1
                            AutoStealV2.Status = "Egg lost on return - recovering..."
                            startGuardRecovery(AutoStealV2.ActiveTargetUid, root and root.Position)
                        end
                    end
                end)
            end)

            pcall(function()
                AutoStealV2.AntiStunConnection = RunService.Heartbeat:Connect(function()
                    if not isEnabled() then return end
                    if AutoStealV2.RagdollWindowActive then return end
                    local _, humanoid = characterParts()
                    if not humanoid then return end
                    local state = humanoid:GetState()
                    local character = LocalPlayer.Character
                    local okRagdoll, gameRagdolled = false, false
                    if Ragdoll and character then
                        okRagdoll, gameRagdolled = pcall(Ragdoll.IsRagdolled, character)
                    end
                    local hardStun = (okRagdoll and gameRagdolled == true)
                        or state == Enum.HumanoidStateType.FallingDown
                        or state == Enum.HumanoidStateType.Ragdoll
                        or state == Enum.HumanoidStateType.Physics
                    local softStun = not AutoStealV2.ActiveTween
                        and not AutoStealV2.CarryChaseActive
                        and not AutoStealV2.Moving
                        and (humanoid.Sit or humanoid.PlatformStand)
                    local recovering = os.clock() < AutoStealV2.RecoveryUntil
                    if (hardStun or softStun) and not recovering
                        and os.clock() - AutoStealV2.LastAntiRagdollAt >= 0.15
                    then
                        AutoStealV2.LastAntiRagdollAt = os.clock()
                        if not AutoStealV2.Carrying and not AutoStealV2.ReturningToSafe
                            and AutoStealV2.ActiveTargetUid
                        then
                            AutoStealV2.RetryTargetUid = AutoStealV2.ActiveTargetUid
                            AutoStealV2.RetryTargetSince = os.clock()
                            AutoStealV2.RetryReason = "ragdoll"
                            AutoStealV2.RetryTargetCategory = AutoStealV2.ActiveTargetCategory
                            AutoStealV2.RetryTargetAreaId = AutoStealV2.ActiveTargetAreaId
                            AutoStealV2.RetryTargetNestId = AutoStealV2.ActiveTargetNestId
                        end
                        AutoStealV2.Status = AutoStealV2.Carrying
                            and "Anti-ragdoll active - keeping held egg"
                            or "Anti-ragdoll active - retrying same target"
                        startRecoveryBurst(
                            AutoStealV2.ActiveTargetUid,
                            "ragdoll",
                            AutoStealV2.ReturningToSafe
                        )
                    elseif recovering and not AutoStealV2.ActiveTween
                        and not AutoStealV2.Moving
                    then
                        recoverFromStun(false)
                    end

                    if humanoid.Sit and isEnabled() and hasHigherPriorityWork() then
                        humanoid.Sit = false
                        pcall(function()
                            local Remotes = require(ReplicatedStorage.Shared.Remotes)
                            if Remotes and Remotes.Treadmill and Remotes.Treadmill.AskDoff then
                                Remotes.Treadmill.AskDoff:InvokeServer()
                            end
                        end)
                    end
                end)
            end)

            pcall(function()
                local Remotes = require(ReplicatedStorage.Shared.Remotes)
                if Remotes and Remotes.Treadmill and Remotes.Treadmill.AssignedBeltShifted then
                    AutoStealV2.BeltShiftedConn = Remotes.Treadmill.AssignedBeltShifted.OnClientEvent:Connect(function(belt)
                        AutoStealV2.ActiveBelt = belt
                        if belt ~= nil then
                            if isEnabled() and hasHigherPriorityWork() then
                                escapeTreadmill(AutoStealV2.Token)
                            elseif AutoStealV2.AutoTreadmill then
                                AutoStealV2.TreadmillTraining = true
                            end
                        else
                            AutoStealV2.TreadmillTraining = false
                        end
                    end)
                end
            end)

            task.spawn(function()
                local lastTry = 0
                while not AutoStealV2.SchedulerClosed and ScriptEnv.SAE_RunToken == entryToken do
                    task.wait(0.25)
                    if AutoStealV2.AutoTreadmill then
                        local work = hasHigherPriorityWork()
                        if work then
                            if isOnTreadmill() or AutoStealV2.TreadmillTraining then
                                escapeTreadmill(AutoStealV2.Token)
                            end
                        else
                            local onBelt = isOnTreadmill()
                            if not onBelt and not AutoStealV2.Busy and not AutoStealV2.Carrying then
                                if os.clock() - lastTry >= 1.5 then
                                    lastTry = os.clock()
                                    local bottom = getMyTreadmillPart()
                                    local root, hum = characterParts()
                                    if bottom and root and hum and hum.Health > 0 then
                                        AutoStealV2.Status = "Auto Treadmill: Moving to treadmill..."
                                        local standPos = bottom.Position + Vector3.new(0, bottom.Size.Y * 0.5 + 3, 0)
                                        local dist = (root.Position - standPos).Magnitude
                                        if dist > 3 then
                                            local speed = math.clamp(tonumber(AutoStealV2.Speed) or 800, 200, 1000)
                                            local duration = math.clamp(dist / speed, 0.05, 3)
                                            local oldPlat = hum.PlatformStand
                                            hum.PlatformStand = true
                                            root.AssemblyLinearVelocity = Vector3.zero
                                            root.AssemblyAngularVelocity = Vector3.zero
                                            local tween = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
                                                CFrame = CFrame.new(standPos) * bottom.CFrame.Rotation
                                            })
                                            local done = false
                                            local conn = tween.Completed:Connect(function() done = true end)
                                            tween:Play()
                                            local dl = os.clock() + duration + 0.5
                                            while not done and os.clock() < dl and AutoStealV2.AutoTreadmill do
                                                if hasHigherPriorityWork() then
                                                    pcall(function() tween:Cancel() end)
                                                    break
                                                end
                                                RunService.Heartbeat:Wait()
                                            end
                                            pcall(function() tween:Cancel() end)
                                            conn:Disconnect()
                                            hum.PlatformStand = oldPlat
                                            pcall(function() hum:ChangeState(Enum.HumanoidStateType.Running) end)
                                        end
                                        task.wait(0.15)
                                        if isOnTreadmill() and not hasHigherPriorityWork() then
                                            pcall(function()
                                                local Remotes = require(ReplicatedStorage.Shared.Remotes)
                                                if Remotes and Remotes.Treadmill and Remotes.Treadmill.AskWearStill then
                                                    Remotes.Treadmill.AskWearStill:InvokeServer()
                                                else
                                                    local req = ReplicatedStorage.Packages.Networking:FindFirstChild("RF/Treadmill/AskWearStill")
                                                    if req then req:InvokeServer() end
                                                end
                                            end)
                                            AutoStealV2.TreadmillTraining = true
                                            AutoStealV2.Status = "Auto Treadmill: Training speed (Idle)"
                                        end
                                    end
                                end
                            elseif onBelt then
                                if not AutoStealV2.TreadmillTraining then
                                    pcall(function()
                                        local Remotes = require(ReplicatedStorage.Shared.Remotes)
                                        if Remotes and Remotes.Treadmill and Remotes.Treadmill.AskWearStill then
                                            Remotes.Treadmill.AskWearStill:InvokeServer()
                                        else
                                            local req = ReplicatedStorage.Packages.Networking:FindFirstChild("RF/Treadmill/AskWearStill")
                                            if req then req:InvokeServer() end
                                        end
                                    end)
                                    AutoStealV2.TreadmillTraining = true
                                end
                                if not AutoStealV2.Busy and not AutoStealV2.Carrying then
                                    AutoStealV2.Status = "Auto Treadmill: Training speed (Idle)"
                                end
                            end
                        end
                    elseif AutoStealV2.TreadmillTraining then
                        escapeTreadmill(AutoStealV2.Token)
                    end
                end
                if AutoStealV2.TreadmillTraining then
                    escapeTreadmill(0)
                end
            end)
        end

        ScriptEnv.SAE_AutoSteal = AutoStealV2
        ScriptEnv.SAE_AutoStealBuild = AutoStealV2.Build
        AutoStealV2.PreviewTarget = pickTarget
        AutoStealV2.InfestedInventoryUids = infestedInventoryUids
        AutoStealV2.MonsterPosition = monsterPosition
        AutoStealV2.FeedInfestedEggs = feedInfestedEggs
        AutoStealV2.GetCycleState = getCycleState
        AutoStealV2.GetDawnReadyIn = getDawnReadyIn
        AutoStealV2.GetSafePoint = getSafePoint
        AutoStealV2.RefreshCycleState = refreshCycleState
        AutoStealV2.PreviewPath = pathTo
        AutoStealV2.IsOnTreadmill = isOnTreadmill
        AutoStealV2.EscapeTreadmill = escapeTreadmill
        AutoStealV2.ForceExitTreadmill = escapeTreadmill
        AutoStealV2.GetEarningRate = getEarningRate
        AutoStealV2.RemoveTrapHitboxes = removeAutoStealTrapHitboxes
        ScriptEnv.SAE_StealCleanup = function()
            AutoStealV2.SelectedEnabled = false
            AutoStealV2.SecretEnabled = false
            AutoStealV2.BigEnabled = false
            AutoStealV2.RarestEnabled = false
            AutoStealV2.TpStealEnabled = false
            AutoStealV2.AutoTreadmill = false
            if AutoStealV2.TreadmillTraining then
                escapeTreadmill(0)
            end
            AutoStealV2.RagdollWindowActive = false
            endVisualHold()
            AutoStealV2.EventEnabled = false
            AutoStealV2.EventFeeding = false
            AutoStealV2.ScriptCarry = false
            AutoStealV2.SchedulerClosed = true
            AutoStealV2.Token += 1
            AutoStealV2.RecoverySerial += 1
            stopCarrySpam()
            stopCarryChase()
            stopReturnRace()
            if AutoStealV2.ActiveTween then
                pcall(function() AutoStealV2.ActiveTween:Cancel() end)
                AutoStealV2.ActiveTween = nil
            end
            if AutoStealV2.CarryConnection then
                pcall(function() AutoStealV2.CarryConnection:Disconnect() end)
                AutoStealV2.CarryConnection = nil
            end
            if AutoStealV2.AntiStunConnection then
                pcall(function() AutoStealV2.AntiStunConnection:Disconnect() end)
                AutoStealV2.AntiStunConnection = nil
            end
            if AutoStealV2.BeltShiftedConn then
                pcall(function() AutoStealV2.BeltShiftedConn:Disconnect() end)
                AutoStealV2.BeltShiftedConn = nil
            end
            if AutoStealV2.TrapAddedConnection then
                pcall(function() AutoStealV2.TrapAddedConnection:Disconnect() end)
                AutoStealV2.TrapAddedConnection = nil
            end
            local _, humanoid = characterParts()
            if humanoid then
                pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true) end)
                pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true) end)
                pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true) end)
            end
        end

        task.wait()

        local section = AutoStealMainSection

        if not AutoStealV2.Ready then
            section:Paragraph({
                Title = "Game modules unavailable",
                Desc = "Expected Client.EggState, Client.PlotState, Shared.Save and Data modules.",
                Image = "triangle-alert",
                ImageSize = 34,
            })
        else
            local areaNames = {}
            local seenAreas = {}
            local function addArea(name)
                if type(name) == "string" and name ~= "" and not seenAreas[name] then
                    seenAreas[name] = true
                    table.insert(areaNames, name)
                end
            end

            if type(AreaDirectory) == "table" then
                for name, data in pairs(AreaDirectory) do
                    local sName = tostring(name)
                    addArea(sName)
                    local disp = type(data) == "table" and (data.DisplayName or data.Name)
                    if disp and tostring(disp) ~= sName then
                        addArea(tostring(disp))
                    end
                end
            end

            addArea("Angels & Demons")
            addArea("Light Dark")
            addArea("Titan Temple")
            addArea("Cherry Blossom")
            addArea("Cosmic")
            addArea("Abyss Ocean")
            addArea("Prehistoric")
            addArea("Volcano")
            addArea("Snow")
            addArea("Jungle")
            addArea("Desert")
            addArea("Lake")
            addArea("Forest")

            table.sort(areaNames)
            table.insert(areaNames, 1, AUTO_STEAL_ALL_OPTION)
            local rarityNames = {}
            for name in pairs(RarityRank) do table.insert(rarityNames, name) end
            table.sort(rarityNames, function(a, b)
                return (RarityRank[a] or 0) < (RarityRank[b] or 0)
            end)
            table.insert(rarityNames, 1, AUTO_STEAL_ALL_OPTION)

            local function setOf(value)
                local result = {}
                local function addKey(k)
                    result[k] = true
                end
                if type(value) == "string" then
                    addKey(value)
                elseif type(value) == "table" then
                    for key, item in pairs(value) do
                        local selected = item == true and tostring(key)
                            or (type(item) == "string" and item or nil)

                        if selected and selected ~= SELECT_ALL_OPTION
                            and selected ~= AUTO_STEAL_ALL_OPTION
                            and selected ~= "All Areas" and selected ~= "All Rarities"
                        then
                            addKey(selected)
                        end
                    end
                end
                return result
            end

            local status = section:Paragraph({
                Title = "Idle",
                Desc = "1000 studs/s - built-in anti-ragdoll + same-egg guard retry",
                Image = "egg",
                ImageSize = 38,
            })
            local function setDebugVisible(value)
                ScriptEnv.SAE_AutoStealDebug = value == true
                if status.ElementFrame then
                    status.ElementFrame.Visible = ScriptEnv.SAE_AutoStealDebug
                end
            end
            AutoStealV2.SetDebugVisible = setDebugVisible
            AutoStealV2.DebugStatusFrame = status.ElementFrame
            setDebugVisible(ScriptEnv.SAE_AutoStealDebug)
            section:Dropdown({
                Title = "Areas to Steal",
                Flag = "Main_StealV2Areas",
                Values = areaNames, Multi = true, AllowNone = true,
                NativeSelectAll = true,
                Value = {},
                Callback = function(value) AutoStealV2.SelectedAreas = setOf(value) end,
            })
            section:Dropdown({
                Title = "Egg Rarities to Steal",
                Flag = "Main_StealV2Rarities",
                Values = rarityNames, Multi = true, AllowNone = true,
                NativeSelectAll = true,
                Value = {},
                Callback = function(value) AutoStealV2.SelectedRarities = setOf(value) end,
            })
            section:Toggle({
                Title = "Auto Steal Selected Eggs",
                Flag = "Main_AutoStealV2Selected", Value = false,
                Callback = function(value) AutoStealV2.SetMode("SelectedEnabled", value) end,
            })
            section:Divider()
            section:Toggle({
                Title = "Auto Steal Secret Egg",
                Flag = "Main_AutoStealV2Secret", Value = false,
                Callback = function(value) AutoStealV2.SetMode("SecretEnabled", value) end,
            })
            section:Toggle({
                Title = "Auto Steal Big Egg",
                Flag = "Main_AutoStealV2Big", Value = false,
                Callback = function(value) AutoStealV2.SetMode("BigEnabled", value) end,
            })
            section:Toggle({
                Title = "Auto Steal Rarest Egg",
                Flag = "Main_AutoStealV2Rarest", Value = false,
                Callback = function(value) AutoStealV2.SetMode("RarestEnabled", value) end,
            })
            section:Divider()
            --[[
            section:Toggle({
                Title = "Instant Steal",
                Flag = "Main_AutoStealV2TpSteal", Value = false,
                Callback = function(value) AutoStealV2.SetMode("TpStealEnabled", value) end,
            })
            ]]
            section:Slider({
                Title = "Steal Speed",
                Flag = "Main_AutoStealV2Speed",
                Value = { Min = 100, Max = 1200, Default = 800 },
                Step = 25,
                Callback = function(value)
                    local speed = tonumber(value) or AutoStealV2.Speed
                    AutoStealV2.Speed = math.clamp(math.floor(speed), 100, 1200)
                end,
            })
            section:Slider({
                Title = "Run Speed (To Egg)",
                Flag = "Main_AutoStealV2RunSpeed",
                Value = { Min = 50, Max = 120, Default = 100 },
                Step = 1,
                Callback = function(value)
                    local pct = tonumber(value) or 100
                    AutoStealV2.RunSpeed = math.clamp(pct / 100, 0.5, 1.2)
                end,
            })
            section:Divider()
            section:Toggle({
                Title = "Auto Treadmill (When Idle)",
                Flag = "Main_AutoTreadmill",
                Value = false,
                Callback = function(value) AutoStealV2.SetAutoTreadmill(value) end,
            })

            pcall(function()
                local frame = section.ElementFrame
                local content = frame and frame:FindFirstChild("Content", true)
                if content then content.Visible = true end
                if section.Open then section:Open() end
            end)
            task.defer(function()
                pcall(function()
                    local frame = section.ElementFrame
                    local content = frame and frame:FindFirstChild("Content", true)
                    if content then content.Visible = true end
                    if section.Open then section:Open() end
                end)
            end)

            task.spawn(function()
                while ScriptEnv.SAE_RunToken == entryToken do
                    task.wait(0.5)
                    pcall(function()
                        status:SetTitle(AutoStealV2.Status)
                        status:SetDesc(string.format(
                            "Speed <b>%d</b> - Stolen <b>%d</b> - Failed <b>%d</b> - Carrying <b>%s</b>\nGuard <b>%d</b> - Same egg retries <b>%d</b> - Anti-ragdoll <b>%d</b> - Hit retries <b>%d</b>",
                            AutoStealV2.Speed, AutoStealV2.Stolen,
                            AutoStealV2.Failed, tostring(AutoStealV2.Carrying),
                            AutoStealV2.GuardLosses, AutoStealV2.GuardRetryAttempts,
                            AutoStealV2.StunRecoveries, AutoStealV2.AntiRagdollRetryAttempts
                        ))
                    end)
                end
            end)
        end
    end

    task.wait()

    do
        local AutoIndex = {
            Enabled = false,
            SelectedArena = "All Arenas",
            AutoClaim = true,
            Status = "Idle",
            TargetPet = nil,
            TargetArea = nil,
            Closed = false,
            Busy = false,
            LastCheck = 0,
        }

        local indexArenaList = {
            "All Arenas",
            "Forest",
            "Lake",
            "Desert",
            "Jungle",
            "Snow",
            "Volcano",
            "Prehistoric",
            "Abyss Ocean",
            "Cosmic",
            "Cherry Blossom",
            "Titan Temple",
            "Light Dark",
        }

        local function getEggState()
            return require(ReplicatedStorage.Client.EggState)
        end

        local function getPlotState()
            return require(ReplicatedStorage.Client.PlotState)
        end

        local function getAreasData()
            return require(ReplicatedStorage.Data.Areas)
        end

        local function getSaveData()
            local Save = require(ReplicatedStorage.Shared.Save)
            local fn = Save.Get or Save.Peek
            local ok, data = pcall(fn)
            return ok and type(data) == "table" and data or nil
        end

        local function getOwnedEggs()
            local EggState = getEggState()
            pcall(EggState.SyncOwnedEggs)
            local ok, records = pcall(EggState.ReadOwnerEggs, LocalPlayer.UserId)
            if ok and type(records) == "table" then return records end
            local save = getSaveData()
            return save and type(save.EggInventory) == "table" and save.EggInventory or {}
        end

        local function getPlacementSlots(records)
            local PlotState = getPlotState()
            local plot = PlotState.ResolvePlot()
            if not plot or not plot.PetArea or not plot.CenterPoint then return {} end
            local occupied = {}
            for _, record in pairs(records or {}) do
                local placement = type(record) == "table" and record.Placement
                local cf = type(placement) == "table" and placement.LocalCFrame
                if typeof(cf) == "CFrame" then table.insert(occupied, cf.Position) end
            end
            local slots = {}
            local size = plot.PetArea.Size
            for x = -size.X * 0.5 + 5, size.X * 0.5 - 5, 7 do
                for z = -size.Z * 0.5 + 5, size.Z * 0.5 - 5, 7 do
                    local world = plot.PetArea.CFrame:PointToWorldSpace(Vector3.new(x, 1, z))
                    local localCF = plot.CenterPoint.CFrame:ToObjectSpace(CFrame.new(world))
                    local free = true
                    for _, p in ipairs(occupied) do
                        if (p - localCF.Position).Magnitude < 3 then free = false break end
                    end
                    if free then table.insert(slots, localCF) end
                end
            end
            return slots
        end

        local function isScrambleEventBusy()
            local scramble = ScriptEnv.SAE_ScrambleAuto
            if type(scramble) == "table" and (scramble.AutoFight == true or scramble.AutoParts == true) then
                local outbreakAttr = Workspace:GetAttribute("ScrambleOutbreakActive") == true
                local droneCount = tonumber(Workspace:GetAttribute("ScrambleActiveDrones")) or 0
                local status = tostring(scramble.Status or "")
                if outbreakAttr or droneCount > 0
                    or status:find("Fighting") or status:find("traveling") or status:find("patrolling")
                    or status:find("Holding") or status:find("Part") or scramble.CollectingBusy == true
                then
                    return true
                end
            end
            return false
        end

        local function ensureAtPen()
            if isScrambleEventBusy() then return false end
            local PlotState = getPlotState()
            local okPlot, plot = pcall(function() return PlotState.ResolvePlot() end)
            local area = okPlot and plot and plot.PetArea
            if not area or not area:IsA("BasePart") then return false end
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if root and (root.Position - area.Position).Magnitude <= 30 then return true end

            local targetPos = area.Position + Vector3.new(0, 4, 0)
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if not root or not hum then return false end
            local dist = (root.Position - targetPos).Magnitude
            local duration = math.clamp(dist / 800, 0.05, 4)
            local oldPlat = hum.PlatformStand
            hum.PlatformStand = true
            root.AssemblyLinearVelocity = Vector3.zero
            local tw = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Linear), { CFrame = CFrame.new(targetPos) })
            tw:Play()
            tw.Completed:Wait()
            hum.PlatformStand = oldPlat
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.Running) end)
            return (root.Position - targetPos).Magnitude <= 35
        end

        function AutoIndex.plantEgg(uid)
            if isScrambleEventBusy() then return false, "scramble active" end
            local EggState = getEggState()
            local records = getOwnedEggs()
            local slots = getPlacementSlots(records)
            if #slots == 0 then return false, "pen is full" end
            if not ensureAtPen() then return false, "cannot reach pen" end
            pcall(EggState.WearEggTool, uid)
            task.wait(0.08)
            for _, localCF in ipairs(slots) do
                local ok, accepted = pcall(EggState.PlantEgg, uid, localCF)
                if ok and accepted == true then
                    pcall(EggState.DoffEggTool)
                    return true, "planted"
                end
            end
            pcall(EggState.DoffEggTool)
            return false, "rejected"
        end

        function AutoIndex.hatchEgg(uid)
            local EggState = getEggState()
            local readyOk, ready = pcall(EggState.IsReadyToHatch, uid)
            if readyOk and ready == true then
                local bOk = pcall(EggState.BeginHatch, uid)
                if bOk then
                    task.wait(0.12)
                    local fOk = pcall(EggState.FinishHatch, uid)
                    return fOk == true
                end
            end
            return false
        end

        function AutoIndex.getMissingPets(arenaScope)
            local save = getSaveData()
            local playerIndex = save and save.Index or {}
            local missing = {}
            local missingSet = {}
            local totalCount = 0
            local unlockedCount = 0

            local Areas = getAreasData()
            local targetAreas = {}
            if arenaScope == "All Arenas" or arenaScope == "All" or not arenaScope then
                for areaName in pairs(Areas.Directory or {}) do
                    table.insert(targetAreas, areaName)
                end
            else
                local mapped = arenaScope == "Angels & Demons" and "Light Dark" or arenaScope
                table.insert(targetAreas, mapped)
            end

            for _, aName in ipairs(targetAreas) do
                local aData = Areas.Directory and Areas.Directory[aName]
                local dropTable = aData and aData.DropTable or {}
                for _, entry in ipairs(dropTable) do
                    local petName = entry[1]
                    totalCount = totalCount + 1
                    if playerIndex[petName] == true then
                        unlockedCount = unlockedCount + 1
                    else
                        table.insert(missing, {
                            Name = petName,
                            Area = aName,
                            DropWeight = tonumber(entry[2]) or 1,
                        })
                        missingSet[petName] = true
                    end
                end
            end

            return missing, missingSet, unlockedCount, totalCount
        end

        function AutoIndex.ClaimRewards()
            local remotes = require(ReplicatedStorage.Shared.Remotes)
            if remotes and remotes.Codex and remotes.Codex.AskRedeemAll then
                local ok, res = pcall(function() return remotes.Codex.AskRedeemAll:InvokeServer() end)
                if ok and res ~= false then
                    Notify("Index", "Claimed all pending Index rewards!", "gift", 3)
                else
                    Notify("Index", "No pending rewards to claim.", "info", 2)
                end
            end
        end

        local function isScrambleEventBusy()
            local scramble = ScriptEnv.SAE_ScrambleAuto
            if type(scramble) == "table" and (scramble.AutoFight == true or scramble.AutoParts == true) then
                local outbreakAttr = Workspace:GetAttribute("ScrambleOutbreakActive") == true
                local droneCount = tonumber(Workspace:GetAttribute("ScrambleActiveDrones")) or 0
                local status = tostring(scramble.Status or "")
                if outbreakAttr or droneCount > 0
                    or status:find("Fighting") or status:find("traveling") or status:find("patrolling")
                    or status:find("Holding") or status:find("Part") or scramble.CollectingBusy == true
                then
                    return true
                end
            end
            return false
        end

        local function isStealBusy()
            local steal = ScriptEnv.SAE_AutoSteal
            return type(steal) == "table" and (steal.Busy == true or steal.Carrying == true)
        end

        local function runAutoIndexCycle()
            if not AutoIndex.Enabled or AutoIndex.Busy then return end

            if isScrambleEventBusy() then
                AutoIndex.Status = "Paused: Dr. Scramble Event active (Event Priority)"
                return
            end

            if isStealBusy() then
                AutoIndex.Status = "Paused: Auto Steal in progress"
                return
            end

            local missingList, missingSet, unlockedCount, totalCount = AutoIndex.getMissingPets(AutoIndex.SelectedArena)
            AutoIndex.UnlockedCount = unlockedCount
            AutoIndex.TotalCount = totalCount

            if #missingList == 0 then
                AutoIndex.Status = string.format("Full Index Complete (%d/%d)!", unlockedCount, totalCount)
                if AutoIndex.AutoClaim then
                    pcall(function()
                        local remotes = require(ReplicatedStorage.Shared.Remotes)
                        if remotes and remotes.Codex and remotes.Codex.AskRedeemAll then
                            remotes.Codex.AskRedeemAll:InvokeServer()
                        end
                    end)
                end
                return
            end

            local plotEggs = getOwnedEggs()
            local hatchedAny = false
            for uid, egg in pairs(plotEggs) do
                if type(egg) == "table" and egg.Placement ~= nil and missingSet[tostring(egg.AssetCategory)] then
                    if AutoIndex.hatchEgg(uid) then
                        AutoIndex.Status = "Hatched " .. tostring(egg.AssetCategory) .. "! Index unlocked!"
                        if ScriptEnv.SAE_OnEggHatched then
                            pcall(ScriptEnv.SAE_OnEggHatched, tostring(egg.AssetCategory), "Index Pet", 0, true)
                        end
                        hatchedAny = true
                        task.wait(0.5)
                        break
                    end
                end
            end
            if hatchedAny then return end

            local plantedAny = false
            for uid, egg in pairs(plotEggs) do
                if type(egg) == "table" and egg.Placement == nil and missingSet[tostring(egg.AssetCategory)] then
                    AutoIndex.Status = "Planting " .. tostring(egg.AssetCategory) .. " on plot..."
                    local planted, reason = AutoIndex.plantEgg(uid)
                    if planted then
                        AutoIndex.Status = "Planted " .. tostring(egg.AssetCategory) .. "! Incubating..."
                        plantedAny = true
                        task.wait(0.5)
                        break
                    elseif reason == "pen is full" then
                        AutoIndex.Status = "Plot pen is full! Make room for eggs."
                        return
                    end
                end
            end
            if plantedAny then return end

            local incubatingCat = nil
            for uid, egg in pairs(plotEggs) do
                if type(egg) == "table" and egg.Placement ~= nil and missingSet[tostring(egg.AssetCategory)] then
                    incubatingCat = tostring(egg.AssetCategory)
                    break
                end
            end

            local EggState = getEggState()
            pcall(EggState.SyncFieldEggs)
            task.wait(0.15)
            local okSnap, snapshot = pcall(EggState.ReadFieldEggs)
            local fieldRecords = okSnap and type(snapshot) == "table" and (snapshot.Records or snapshot) or {}

            local targetEgg = nil
            local targetDist = nil
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local myPos = root and root.Position or Vector3.zero

            for _, record in pairs(fieldRecords) do
                if type(record) == "table" and (record.State == "Slot" or record.State == "Dropped")
                    and type(record.Uid) == "string"
                    and tonumber(tostring(record.Uid):match("^FirstAreaEgg_(%d+)_")) ~= LocalPlayer.UserId
                then
                    local cat = tostring(record.AssetCategory)
                    if missingSet[cat] then
                        local cf = record.BottomCFrame or record.BoundsCFrame
                        local dist = cf and (cf.Position - myPos).Magnitude or 9999
                        if targetDist == nil or dist < targetDist then
                            targetEgg = record
                            targetDist = dist
                        end
                    end
                end
            end

            if targetEgg then
                if isScrambleEventBusy() then
                    AutoIndex.Status = "Paused: Dr. Scramble Event active (Event Priority)"
                    return
                end
                AutoIndex.Busy = true
                AutoIndex.TargetPet = tostring(targetEgg.AssetCategory)
                AutoIndex.TargetArea = tostring(targetEgg.AreaId)
                AutoIndex.Status = string.format("Stealing %s (%s)...", AutoIndex.TargetPet, AutoIndex.TargetArea)

                local stealEngine = ScriptEnv.SAE_AutoSteal
                local stolen = false
                if stealEngine and type(stealEngine.StealFieldEgg) == "function" then
                    stolen = stealEngine.StealFieldEgg(targetEgg)
                end

                if stolen then
                    AutoIndex.Status = "Stolen " .. AutoIndex.TargetPet .. "! Planting on plot..."
                    task.wait(0.6)
                    local freshSave = getSaveData()
                    for uid, egg in pairs(freshSave and freshSave.EggInventory or {}) do
                        if tostring(egg.AssetCategory) == tostring(targetEgg.AssetCategory) and egg.Placement == nil then
                            AutoIndex.plantEgg(uid)
                            break
                        end
                    end
                else
                    AutoIndex.Status = "Steal failed: " .. AutoIndex.TargetPet .. " (retrying)"
                end
                AutoIndex.Busy = false
            elseif incubatingCat then
                AutoIndex.Status = string.format("Incubating %s on plot...", incubatingCat)
            else
                AutoIndex.Status = string.format("No missing eggs on map (%d missing in %s)", #missingList, AutoIndex.SelectedArena)
            end
        end

        local IndexSection = MiscTab:Section({
            Title = "Auto Index",
            ConfigFlagKey = "AutoIndex",
            Icon = "book-marked",
            Box = true,
            BoxBorder = true,
            Opened = true,
        })

        local indexStatusParagraph = IndexSection:Paragraph({
            Title = "Auto Index: Idle",
            Desc = "Reads Codex, steals missing pet eggs, plants and hatches them automatically.",
            Image = "book-marked",
            ImageSize = 34,
        })

        IndexSection:Toggle({
            Title = "Auto Index",
            Flag = "Misc_AutoIndexEnabled",
            Value = false,
            Callback = function(v)
                AutoIndex.Enabled = v == true
            end,
        })

        IndexSection:Dropdown({
            Title = "Target Arena",
            Flag = "Misc_AutoIndexArena",
            Values = indexArenaList,
            Value = "All Arenas",
            Callback = function(v)
                AutoIndex.SelectedArena = tostring(v or "All Arenas")
            end,
        })

        IndexSection:Toggle({
            Title = "Auto Claim Index Rewards",
            Flag = "Misc_AutoIndexClaimRewards",
            Value = true,
            Callback = function(v)
                AutoIndex.AutoClaim = v == true
            end,
        })

        IndexSection:Button({
            Title = "Claim All Index Rewards Now",
            Icon = "gift",
            Callback = function()
                AutoIndex.ClaimRewards()
            end,
        })

        task.spawn(function()
            while not AutoIndex.Closed and ScriptEnv.SAE_RunToken == entryToken do
                task.wait(1.5)
                pcall(function()
                    if AutoIndex.Enabled then
                        if isScrambleEventBusy() then
                            AutoIndex.Status = "Paused: Dr. Scramble Event active (Event Priority)"
                        else
                            runAutoIndexCycle()
                        end
                    else
                        AutoIndex.Status = "Idle"
                    end

                    local _, _, un, tot = AutoIndex.getMissingPets(AutoIndex.SelectedArena)
                    local pct = tot > 0 and math.floor(un / tot * 100) or 0
                    indexStatusParagraph:SetTitle(string.format("Auto Index: %s", AutoIndex.Status))
                    indexStatusParagraph:SetDesc(string.format(
                        "Scope: <b>%s</b> | Progress: <b>%d / %d (%d%%)</b>\nTarget: <b>%s</b>",
                        AutoIndex.SelectedArena or "All Arenas",
                        un or 0, tot or 0, pct,
                        AutoIndex.TargetPet and (AutoIndex.TargetPet .. " (" .. tostring(AutoIndex.TargetArea) .. ")") or "None"
                    ))
                end)
            end
        end)

        ScriptEnv.SAE_AutoIndex = AutoIndex
        ScriptEnv.SAE_IndexCleanup = function()
            AutoIndex.Closed = true
            AutoIndex.Enabled = false
            if ScriptEnv.SAE_AutoIndex == AutoIndex then ScriptEnv.SAE_AutoIndex = nil end
        end
    end

    task.wait()

    do
        local ScrambleAuto = {
            AutoFarm = false,
            AutoRarest = true,
            AutoDrops = true,
            AutoQuest = false,
            AutoShop = false,
            ShopPicks = { ["Scrambled Mutation"] = true },
            KeepSamples = 0,
            AutoLab = false,
            LabBanners = {},
            AutoLabReroll = false,
            AutoLabPlace = true,
            AutoBoss = false,
            AutoBossMastery = true,
            AutoPlaceBossEgg = true,
            AutoMutate = false,
            MutateKind = "Scrambled",
            MutateEggs = {},

            Status = "Idle",
            Closed = false,
            Busy = false,
            LastActivate = 0,
            LastShopCheck = 0,
            LastLabCheck = 0,
            LastBossCheck = 0,
            LastMutateCheck = 0,
            LastMasteryCheck = 0,
            LastPlaceCheck = 0,
            ShopLastBought = "",
            LabLastTraded = "",
            BossLastStatus = "",
        }

        local VIM = game:GetService("VirtualInputManager")

        local activeTween = nil
        local function cancelActiveTween()
            if activeTween then
                pcall(function() activeTween:Cancel() end)
                activeTween = nil
            end
        end

        local function tweenTo(pos, tolerance)
            cancelActiveTween()
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if not root or not hum or hum.Health <= 0 then return false end

            local dist = (root.Position - pos).Magnitude
            if dist <= (tolerance or 8) then return true end

            local speed = (ScriptEnv.SAE_AutoSteal and tonumber(ScriptEnv.SAE_AutoSteal.Speed)) or 800
            speed = math.clamp(speed, 200, 1000)
            local duration = math.clamp(dist / speed, 0.05, 6)

            local oldPlat = hum.PlatformStand
            hum.PlatformStand = true
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero

            local targetCFrame = CFrame.new(pos.X, pos.Y + 1.5, pos.Z)
            local tween = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
                CFrame = targetCFrame
            })
            activeTween = tween
            tween:Play()

            local done = false
            local conn = tween.Completed:Connect(function() done = true end)
            local deadline = os.clock() + duration + 0.3
            while not done and os.clock() < deadline and not ScrambleAuto.Closed do
                RunService.Heartbeat:Wait()
            end
            conn:Disconnect()
            cancelActiveTween()

            hum.PlatformStand = oldPlat
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.Running) end)

            local curRoot = char and char:FindFirstChild("HumanoidRootPart")
            return curRoot and (curRoot.Position - pos).Magnitude <= math.max(tolerance or 8, 15)
        end

        local function getNetworking()
            local pkgs = ReplicatedStorage:FindFirstChild("Packages")
            return pkgs and pkgs:FindFirstChild("Networking")
        end

        local function getRemote(name)
            local net = getNetworking()
            return net and net:FindFirstChild(name)
        end

        local cachedSnapshot = nil
        local lastSnapshotTime = 0
        local function getEventSnapshot(force)
            if not force and cachedSnapshot and (os.clock() - lastSnapshotTime < 2.5) then
                return cachedSnapshot
            end
            local req = getRemote("RF/Scramble/Request")
            if not req then return cachedSnapshot end
            lastSnapshotTime = os.clock()
            local ok, res = pcall(function() return req:InvokeServer("Snapshot") end)
            if ok and type(res) == "table" then
                cachedSnapshot = res
                return res
            end
            return cachedSnapshot
        end

        local cachedTradeState = nil
        local lastTradeStateTime = 0
        local function getTradeState(force)
            if not force and cachedTradeState and (os.clock() - lastTradeStateTime < 3.0) then
                return cachedTradeState
            end
            local req = getRemote("RF/ScrambleTradeIn/AskState")
            if not req then return cachedTradeState end
            lastTradeStateTime = os.clock()
            local ok, res = pcall(function() return req:InvokeServer() end)
            if ok and type(res) == "table" then
                cachedTradeState = res
                return res
            end
            return cachedTradeState
        end

        local Drones = {}
        local Drops = {}
        local connections = {}

        local function bindRemoteEvent(remoteName, callback)
            local remote = getRemote(remoteName)
            if remote and remote:IsA("RemoteEvent") then
                local conn = remote.OnClientEvent:Connect(function(...)
                    pcall(callback, ...)
                end)
                table.insert(connections, conn)
            end
        end

        bindRemoteEvent("RE/Scramble/Drones", function(payload)
            if type(payload) ~= "table" then return end
            if type(payload.Upserts) == "table" then
                for _, upsert in pairs(payload.Upserts) do
                    if type(upsert) == "table" and upsert.Id ~= nil then
                        local id = tostring(upsert.Id)
                        local attrs = type(upsert.Attributes) == "table" and upsert.Attributes or {}
                        local cf = upsert.CFrame
                        local pos = (typeof(cf) == "CFrame" and cf.Position) or (typeof(cf) == "Vector3" and cf) or nil
                        local existing = Drones[id] or {}
                        existing.Id = id
                        existing.Position = pos or existing.Position
                        existing.Health = tonumber(upsert.Health) or existing.Health or 1
                        existing.Tier = tostring(attrs.ScrambleTier or existing.Tier or "")
                        existing.Area = tostring(attrs.ScrambleArea or existing.Area or "")
                        Drones[id] = existing
                    end
                end
            end
            if type(payload.Removed) == "table" then
                for k, v in pairs(payload.Removed) do
                    local rid = tostring(type(v) == "string" and v or k)
                    Drones[rid] = nil
                end
            end
        end)

        bindRemoteEvent("RE/Scramble/Effect", function(act, cframe, meta)
            if act == "Hit" and type(meta) == "table" and meta.DroneId ~= nil then
                local id = tostring(meta.DroneId)
                local d = Drones[id]
                if d then
                    d.Health = math.max(0, (tonumber(d.Health) or 1) - (tonumber(meta.Amount) or 1))
                    if d.Health <= 0 then
                        Drones[id] = nil
                    end
                end
            end
        end)

        bindRemoteEvent("RE/Scramble/Drops", function(payload)
            if type(payload) ~= "table" then return end
            for _, drop in pairs(payload) do
                if type(drop) == "table" and drop.Id ~= nil then
                    local pos = drop.Position or drop.Origin
                    local v3 = (typeof(pos) == "CFrame" and pos.Position) or (typeof(pos) == "Vector3" and pos) or nil
                    if v3 then
                        Drops[tostring(drop.Id)] = {
                            Position = v3,
                            Radius = tonumber(drop.Radius) or 6,
                            ExpiresAt = tonumber(drop.ExpiresAt),
                            Kind = drop.Kind or "Samples",
                        }
                    end
                end
            end
        end)

        bindRemoteEvent("RE/Scramble/RemoveDrops", function(payload)
            if type(payload) == "table" then
                for _, id in pairs(payload) do
                    Drops[tostring(id)] = nil
                end
            elseif type(payload) == "string" then
                Drops[payload] = nil
            end
        end)

        local function isOutbreakActive()
            if Workspace:GetAttribute("ScrambleOutbreakActive") == true then
                return true
            end
            local snap = getEventSnapshot()
            local window = snap and snap.Window
            if type(window) == "table" and window.Active == true then
                return true
            end
            return false
        end

        local function isBatTool(tool)
            if not tool or not tool:IsA("Tool") then return false end
            if tool:GetAttribute("IsBat") == true then return true end
            local name = tool.Name:lower()
            local gearName = tostring(tool:GetAttribute("GearName") or ""):lower()
            if name:find("katana") or gearName:find("katana")
                or name:find("bat") or gearName:find("bat")
                or name:find("sword") or gearName:find("sword")
                or name:find("axe") or gearName:find("axe")
            then
                return true
            end
            local ok, Gears = pcall(function() return require(ReplicatedStorage.Data.Gears) end)
            if ok and Gears and Gears.Directory then
                local gData = Gears.Directory[tool.Name] or Gears.Directory[tool:GetAttribute("GearName")]
                if gData and gData.BatControllerData then
                    return true
                end
            end
            return false
        end

        local function bossBat()
            local character = LocalPlayer.Character
            local sources = { character, LocalPlayer:FindFirstChild("Backpack") }
            for _, src in ipairs(sources) do
                if src then
                    for _, tool in ipairs(src:GetChildren()) do
                        if isBatTool(tool) then
                            if tool.Parent ~= character then
                                local hum = character and character:FindFirstChildOfClass("Humanoid")
                                if hum then pcall(function() hum:EquipTool(tool) end) end
                            end
                            return tool
                        end
                    end
                end
            end
            return nil
        end

        local function bossOnCooldown(tool)
            if not tool then return true end
            if tool:GetAttribute("CooldownActive") ~= true then return false end
            return Workspace:GetServerTimeNow() < (tonumber(tool:GetAttribute("CooldownEndTime")) or 0)
        end

        local function quickSwing()
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if not hum then return false end
            local bat = bossBat()
            if not bat or bossOnCooldown(bat) then return false end
            if bat.Parent ~= char then
                pcall(function() hum:EquipTool(bat) end)
            end
            pcall(function() bat:Activate() end)
            return true
        end

        local function triggerPrompt(prompt)
            if not prompt or not prompt:IsA("ProximityPrompt") then return false end
            if typeof(fireproximityprompt) == "function" then
                pcall(fireproximityprompt, prompt)
            end
            pcall(function()
                prompt:InputHoldBegin()
                task.wait((tonumber(prompt.HoldDuration) or 0) + 0.1)
                prompt:InputHoldEnd()
            end)
            return true
        end

        -- ==================== DR. SCRAMBLE BOSS ENGINE (EXACT FROM STEAL AN EGG) ====================
        local ScrBoss = {
            running = false,
            entering = false,
            enterAt = 0,
            masteryAt = 0,
            off = {},
            seenStart = nil,
            ballKey = nil,
            ballSpot = nil,
        }

        local function plantEggOnPlot(uid)
            local EggState = require(ReplicatedStorage.Client.EggState)
            local PlotState = require(ReplicatedStorage.Client.PlotState)
            local plot = PlotState.ResolvePlot()
            if not plot or not plot.PetArea or not plot.CenterPoint then return false, "no plot found" end

            local saveData = Save and (Save.Get or Save.Peek)
            local okS, save = pcall(saveData)
            local records = okS and type(save) == "table" and save.EggInventory or {}

            local occupied = {}
            for _, r in pairs(records) do
                local plc = type(r) == "table" and r.Placement
                local cf = type(plc) == "table" and plc.LocalCFrame
                if typeof(cf) == "CFrame" then table.insert(occupied, cf.Position) end
            end

            local slots = {}
            local size = plot.PetArea.Size
            local yOffset = size.Y * 0.5
            for x = -size.X * 0.5 + 5, size.X * 0.5 - 5, 7 do
                for z = -size.Z * 0.5 + 5, size.Z * 0.5 - 5, 7 do
                    local world = (plot.PetArea.CFrame * CFrame.new(x, yOffset, z)).Position
                    local localCF = plot.CenterPoint.CFrame:ToObjectSpace(CFrame.new(world))
                    local free = true
                    for _, p in ipairs(occupied) do
                        if (p - localCF.Position).Magnitude < 3 then free = false break end
                    end
                    if free then table.insert(slots, localCF) end
                end
            end

            if #slots == 0 then return false, "pen is full" end

            local areaPos = plot.PetArea.Position + Vector3.new(0, 4, 0)
            tweenTo(areaPos, 20)
            task.wait(0.2)

            pcall(EggState.WearEggTool, uid)
            task.wait(0.2)
            for _, localCF in ipairs(slots) do
                local ok, accepted = pcall(EggState.PlantEgg, uid, localCF)
                if ok and accepted == true then
                    pcall(EggState.DoffEggTool)
                    return true, "planted"
                end
            end
            pcall(EggState.DoffEggTool)
            return false, "failed to plant"
        end

        local function plantAllUnplacedEggs()
            local saveData = Save and (Save.Get or Save.Peek)
            local okS, save = pcall(saveData)
            if not okS or type(save) ~= "table" or type(save.EggInventory) ~= "table" then return 0 end
            local unplaced = {}
            for uid, egg in pairs(save.EggInventory) do
                if type(egg) == "table" and egg.Placement == nil then
                    table.insert(unplaced, uid)
                end
            end
            local count = 0
            for _, uid in ipairs(unplaced) do
                local okPlant = plantEggOnPlot(uid)
                if okPlant then
                    count = count + 1
                    task.wait(0.25)
                end
            end
            return count
        end

        local function claimAllMasteries()
            -- 1. Scramble Mastery (Milestones & Infinite)
            local snap = getEventSnapshot(true)
            local state = snap and snap.State
            if type(state) == "table" and type(state.ClaimedMilestoneIds) == "table" then
                local okSM, sm = pcall(require, ReplicatedStorage.Data.ScrambleMastery)
                if okSM and sm and type(sm.Milestones) == "table" then
                    local kills = tonumber(state.Mastery) or 0
                    local req = getRemote("RF/Scramble/Request")
                    if req then
                        for _, m in ipairs(sm.Milestones) do
                            if type(m) == "table" and m.Id and kills >= (tonumber(m.Kills) or math.huge) and state.ClaimedMilestoneIds[m.Id] ~= true then
                                pcall(function() req:InvokeServer("Milestone", m.Id) end)
                            end
                        end
                        if type(sm.ClaimableInfiniteCount) == "function" then
                            local okCount, count = pcall(sm.ClaimableInfiniteCount, state)
                            if okCount and (tonumber(count) or 0) > 0 and sm.InfiniteMilestoneId then
                                pcall(function() req:InvokeServer("Milestone", sm.InfiniteMilestoneId) end)
                            end
                        end
                    end
                end
            end

            -- 2. Boss Mastery (General / Abyss Overlord milestones)
            local saveData = Save and (Save.Get or Save.Peek)
            local okSave, save = pcall(saveData)
            if okSave and save and type(save.BossMastery) == "table" then
                local bmState = save.BossMastery
                local okBM, bm = pcall(require, ReplicatedStorage.Data.BossMastery)
                if okBM and bm and type(bm.Milestones) == "table" then
                    local kills = tonumber(bmState.Mastery) or 0
                    local claimed = type(bmState.ClaimedMilestoneIds) == "table" and bmState.ClaimedMilestoneIds or {}
                    local bmRemote = getRemote("RF/BossMastery/AskClaimMilestone")
                    if bmRemote then
                        for _, m in ipairs(bm.Milestones) do
                            if type(m) == "table" and m.Id and kills >= (tonumber(m.Kills) or math.huge) and claimed[m.Id] ~= true then
                                pcall(function() bmRemote:InvokeServer(m.Id) end)
                            end
                        end
                        if type(bm.ClaimableInfiniteCount) == "function" then
                            local okCount, count = pcall(bm.ClaimableInfiniteCount, bmState)
                            if okCount and (tonumber(count) or 0) > 0 and bm.InfiniteMilestoneId then
                                pcall(function() bmRemote:InvokeServer(bm.InfiniteMilestoneId) end)
                            end
                        end
                    end
                end
            end
        end

        local function scrBossArena()
            local arena = Workspace:FindFirstChild("ScrambleArena")
            return (arena and arena:IsA("Model")) and arena or nil
        end

        local function scrBossInArena()
            return LocalPlayer:GetAttribute("InScrambleArena") == true
        end

        local function scrBossPortalUp()
            local portal = Workspace:FindFirstChild("ScrambleArenaPortal")
            return portal ~= nil and portal:FindFirstChild("Portal") ~= nil
        end

        local ScrBoss = {
            running = false,
            entering = false,
            enterAt = 0,
            masteryAt = 0,
            off = {},
            seenStart = nil,
            ballKey = nil,
            ballSpot = nil,
        }

        local bossNoclipConn = nil
        local bossNoclipAdd = nil
        local function bossNoclip(enable)
            if enable then
                if bossNoclipConn then return end
                local parts = {}
                local lastChar = nil
                bossNoclipConn = RunService.PreSimulation:Connect(function()
                    local char = LocalPlayer.Character
                    if not char then return end
                    if char ~= lastChar then
                        parts = {}
                        lastChar = char
                        for _, p in ipairs(char:GetDescendants()) do
                            if p:IsA("BasePart") then table.insert(parts, p) end
                        end
                        if bossNoclipAdd then bossNoclipAdd:Disconnect() end
                        bossNoclipAdd = char.DescendantAdded:Connect(function(p)
                            if p:IsA("BasePart") then table.insert(parts, p) end
                        end)
                    end
                    for i = 1, #parts do
                        local p = parts[i]
                        if p and p.Parent and p.CanCollide then
                            p.CanCollide = false
                        end
                    end
                end)
            else
                if bossNoclipConn then
                    bossNoclipConn:Disconnect()
                    bossNoclipConn = nil
                end
                if bossNoclipAdd then
                    bossNoclipAdd:Disconnect()
                    bossNoclipAdd = nil
                end
            end
        end

        local traceSeq = 0
        local function getTraceId()
            traceSeq = traceSeq + 1
            local nowMs = 0
            pcall(function()
                nowMs = math.floor(Workspace:GetServerTimeNow() * 1000)
            end)
            return string.format("%d:%d:%d", LocalPlayer.UserId, traceSeq, nowMs)
        end

        local lastScrSwing = 0
        local function doScrSwing(tool)
            if os.clock() - lastScrSwing < 0.25 then return false end
            lastScrSwing = os.clock()
            local trigger = getRemote("RE/BatSwing/Trigger")
            if trigger then
                pcall(function() trigger:FireServer(nil, getTraceId()) end)
            end
            if tool and tool.Parent then
                pcall(function() tool:Activate() end)
            end
            return true
        end

        local function scrBossHazards(enableDisable)
            if not enableDisable then
                for conn in pairs(ScrBoss.off) do
                    pcall(function() conn:Enable() end)
                end
                table.clear(ScrBoss.off)
                return
            end
            if type(getconnections) ~= "function" then return end
            local ok, conns = pcall(getconnections, RunService.RenderStepped)
            if not ok or type(conns) ~= "table" then return end
            for _, conn in ipairs(conns) do
                local fn = conn.Function
                if fn ~= nil and ScrBoss.off[conn] == nil then
                    local okInfo, src = pcall(debug.info, fn, "s")
                    if okInfo and type(src) == "string" and src:find("HazardView", 1, true) then
                        pcall(function() conn:Disable() end)
                        ScrBoss.off[conn] = true
                    end
                end
            end
        end

        local function scrBallRadius(arena)
            local ball = arena:FindFirstChild("Ball")
            if not ball then return 3 end
            if ball:IsA("Model") then
                local ok, size = pcall(ball.GetBoundingBox, ball)
                if ok and size then return math.max(size.X, size.Z) * 0.5 end
            elseif ball:IsA("BasePart") then
                return math.max(ball.Size.X, ball.Size.Z) * 0.5
            end
            return 3
        end

        local function scrLitCoil(arena)
            local coils = arena:FindFirstChild("Coils")
            local coilName = tostring(arena:GetAttribute("BallCoil") or "")
            local coil = coils and coils:FindFirstChild(coilName)
            if not coil then return nil end
            if coil:IsA("BasePart") then
                return { p = coil.Position, r = math.max(coil.Size.X, coil.Size.Z) * 0.5 }
            elseif coil:IsA("Model") then
                local ok, pos, size = pcall(coil.GetBoundingBox, coil)
                if ok and pos and size then
                    return { p = pos.Position, r = math.max(size.X, size.Z) * 0.5 }
                end
            end
            return nil
        end

        local function scrDetour(arena, myPos, targetPos, targetName)
            if arena:GetAttribute("Phase") ~= "Ball" then return targetPos end
            if targetName == "the ball" or tostring(targetName):find("ball", 1, true) then
                return targetPos
            end
            local obstacles = {}
            local litCoil = scrLitCoil(arena)
            if litCoil then
                table.insert(obstacles, { p = litCoil.p, r = litCoil.r + 2 })
            end
            local ball = arena:FindFirstChild("Ball")
            local prim = ball and (ball:IsA("Model") and ball.PrimaryPart or (ball:IsA("BasePart") and ball))
            if prim then
                table.insert(obstacles, { p = prim.Position, r = scrBallRadius(arena) + 4 })
            end

            local startX, startZ = myPos.X, myPos.Z
            local dx, dz = targetPos.X - startX, targetPos.Z - startZ
            local dist = math.sqrt(dx * dx + dz * dz)
            if dist < 0.1 then return targetPos end
            dx = dx / dist
            dz = dz / dist

            local bestDist, bestDetour = math.huge, nil
            for _, obs in ipairs(obstacles) do
                local ox, oz, radius = obs.p.X, obs.p.Z, obs.r
                local toObsX, toObsZ = targetPos.X - ox, targetPos.Z - oz
                if toObsX * toObsX + toObsZ * toObsZ >= radius * radius then
                    local u = math.clamp((ox - startX) * dx + (oz - startZ) * dz, 0, dist)
                    local px, pz = ox - (startX + dx * u), oz - (startZ + dz * u)
                    if u < bestDist and px * px + pz * pz < radius * radius then
                        local nx, nz = -dz, dx
                        if px * (-dz) + pz * dx > 0 then
                            nx, nz = dz, -dx
                        end
                        bestDist = u
                        bestDetour = Vector3.new(ox + nx * (radius + 4), myPos.Y, oz + nz * (radius + 4))
                    end
                end
            end
            return bestDetour or targetPos
        end

        local function scrBossTarget(arena, myPos)
            local function getPos(inst)
                if not inst then return nil end
                if inst:IsA("BasePart") then return inst.Position end
                if inst:IsA("Model") then
                    local ok, piv = pcall(inst.GetPivot, inst)
                    return ok and piv.Position or nil
                end
                return nil
            end

            local phase = arena:GetAttribute("Phase")
            local victim = arena:GetAttribute("GrabVictim")
            if victim ~= nil and victim ~= 0 and victim ~= "" and tostring(victim) ~= tostring(LocalPlayer.UserId) then
                local mech = arena:FindFirstChild("Mech")
                local rescue = mech and mech:FindFirstChild("GrabRescue", true)
                if rescue then return getPos(rescue), "the grabbed player" end
            end

            -- Only target drones during Mech phase (never during Ball phase)
            if phase ~= "Ball" then
                local drones = arena:FindFirstChild("Drones")
                if drones then
                    local bestPos, bestArmed, bestDist = nil, false, math.huge
                    for _, drone in ipairs(drones:GetChildren()) do
                        local hb = drone:FindFirstChild("Hitbox")
                        local hp = hb and (tonumber(hb:GetAttribute("Health")) or tonumber(drone:GetAttribute("Health")) or 1) or 0
                        local state = tostring(drone:GetAttribute("DroneState") or "")
                        if hp > 0 and state ~= "Dead" and state ~= "Death" and hb ~= nil then
                            local p = getPos(hb)
                            local armed = drone:GetAttribute("Armed") == true
                            local d = p and (p - myPos).Magnitude or math.huge
                            if p and (bestPos == nil or (armed and not bestArmed) or (armed == bestArmed and d < bestDist)) then
                                bestPos, bestArmed, bestDist = p, armed, d
                            end
                        end
                    end
                    if bestPos then return bestPos, "a drone" end
                end
            end

            if phase == "Ball" then
                local ball = arena:FindFirstChild("Ball")
                local isStunned = arena:GetAttribute("BallStunned") == true
                    or (tonumber(arena:GetAttribute("CoreHealth")) or 0) > 0
                    or (ball and ball:GetAttribute("Stunned") == true)
                    or arena:GetAttribute("Overheated") == true
                if ball and isStunned then
                    local prim = ball:IsA("Model") and ball.PrimaryPart or nil
                    return prim and prim.Position or getPos(ball), "the ball"
                end
                return nil, "ball"
            end

            if phase == "Human" or phase == "Final" then
                local human = arena:FindFirstChild("ScrambleHuman")
                if human and human:GetAttribute("Immune") ~= true then
                    return getPos(human), "the Scramble Human"
                else
                    local mech = arena:FindFirstChild("Mech")
                    if mech then return getPos(mech), "the Mech" end
                end
            end

            if phase == "Mech" or phase == "Final" then
                local mech = arena:FindFirstChild("Mech")
                if mech then return getPos(mech), "the Mech" end
            end

            return nil, tostring(phase or "waiting")
        end

        local function scrBossBallSpot(arena, myPos)
            local ball = arena:FindFirstChild("Ball")
            local ballPos = ball and (ball:IsA("BasePart") and ball.Position or (ball:IsA("Model") and ball:GetPivot().Position)) or nil
            if ballPos == nil then return nil end

            if tostring(arena:GetAttribute("BallTarget")) == tostring(LocalPlayer.UserId) then
                local coilKey = tostring(arena:GetAttribute("BallCoil")) .. "|" .. tostring(arena:GetAttribute("BallTargetEnds"))
                if ScrBoss.ballKey == coilKey and ScrBoss.ballSpot ~= nil then
                    return ScrBoss.ballSpot, "leading the ball into the coil"
                end
                local coils = arena:FindFirstChild("Coils")
                local coilName = tostring(arena:GetAttribute("BallCoil") or "")
                local coil = coils and coils:FindFirstChild(coilName)
                local coilPos = coil and (coil:IsA("BasePart") and coil.Position or (coil:IsA("Model") and coil:GetPivot().Position)) or nil
                if coilPos ~= nil then
                    local toCoil = Vector3.new(coilPos.X - ballPos.X, 0, coilPos.Z - ballPos.Z)
                    local dir = toCoil.Magnitude < 0.5 and Vector3.new(1, 0, 0) or toCoil.Unit
                    local lit = scrLitCoil(arena)
                    local r = lit and lit.r or 10
                    ScrBoss.ballKey = coilKey
                    ScrBoss.ballSpot = coilPos + dir * (r + 3)
                    return ScrBoss.ballSpot, "leading the ball into the coil"
                end
            end

            ScrBoss.ballKey = nil
            ScrBoss.ballSpot = nil
            local away = Vector3.new(myPos.X - ballPos.X, 0, myPos.Z - ballPos.Z)
            if away.Magnitude >= 45 then return myPos, "keeping clear of the ball" end
            local pushDir = away.Magnitude < 0.5 and Vector3.new(0, 0, 1) or away.Unit
            return ballPos + pushDir * 50, "keeping clear of the ball"
        end

        local function scrBossEnter()
            local portal = Workspace:FindFirstChild("ScrambleArenaPortal")
            local f = portal and portal:FindFirstChild("Hitbox")
            if not f or not f:IsA("BasePart") then
                local enterRemote = getRemote("RF/ScrambleBoss/EnterArena")
                if enterRemote then pcall(function() enterRemote:InvokeServer() end) end
                return
            end

            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if not hrp then return end

            -- Move near portal
            tweenTo(f.Position + f.CFrame.LookVector * 10, 4)
            local deadline = os.clock() + 5
            while os.clock() < deadline and not scrBossInArena() do
                local curChar = LocalPlayer.Character
                local curHrp = curChar and curChar:FindFirstChild("HumanoidRootPart")
                if not curHrp then return end
                local dist = (curHrp.Position - f.Position).Magnitude
                if dist > 60 then break end
                if dist > 3 then
                    curHrp.CFrame = f.CFrame
                    curHrp.AssemblyLinearVelocity = Vector3.zero
                end
                RunService.PostSimulation:Wait()
            end

            local dl2 = os.clock() + 3
            while os.clock() < dl2 and not scrBossInArena() do
                task.wait(0.1)
            end

            if not scrBossInArena() and type(firetouchinterest) == "function" then
                local curChar = LocalPlayer.Character
                local curHrp = curChar and curChar:FindFirstChild("HumanoidRootPart")
                if curHrp then
                    pcall(firetouchinterest, curHrp, f, 0)
                    pcall(firetouchinterest, curHrp, f, 1)
                end
                local dl3 = os.clock() + 3
                while os.clock() < dl3 and not scrBossInArena() do
                    task.wait(0.1)
                end
            end
        end

        local function scrBossFight()
            local speed = 500
            local minRange = 6
            local attackRange = 12
            ScrambleAuto.Busy = true
            ScrBoss.running = true
            bossNoclip(true)

            local lastHazardCheck = 0
            local lastTargetCheck = 0
            local targetPos, targetName = nil, nil

            while ScrambleAuto.AutoBoss and scrBossInArena() and not ScrambleAuto.Closed do
                local dt = math.min(RunService.PostSimulation:Wait(), 0.03333333333333333)
                local arena = scrBossArena()
                local char = LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if not arena or not char or not hrp then
                    continue
                end

                if os.clock() - lastHazardCheck > 1.0 then
                    lastHazardCheck = os.clock()
                    pcall(scrBossHazards, true)
                end

                local center = arena:GetAttribute("Center")
                local radius = tonumber(arena:GetAttribute("Radius")) or 450
                if typeof(center) == "Vector3" and (hrp.Position - center).Magnitude > radius + 200 then
                    ScrambleAuto.Status = (hrp.Position.Y < -10000) and "Phase change -- waiting..." or "Waiting for arena teleport..."
                    continue
                end

                if LocalPlayer:GetAttribute("ScrambleGrabbed") == true then
                    local hitRemote = getRemote("RE/ScrambleBoss/HazardHit")
                    if hitRemote then pcall(function() hitRemote:FireServer(-2) end) end
                    ScrambleAuto.Status = "Grabbed -- breaking free!"
                    continue
                end

                local phase = arena:GetAttribute("Phase")
                if phase == "Defeated" then
                    local leave = arena:FindFirstChild("LeaveTeleport")
                    local leavePart = nil
                    if leave ~= nil then
                        for _, d in ipairs(leave:GetDescendants()) do
                            if d:IsA("TouchTransmitter") and d.Parent and d.Parent:IsA("BasePart") then
                                leavePart = d.Parent
                                break
                            end
                        end
                        leavePart = leavePart or leave:FindFirstChild("Hitbox") or leave:FindFirstChildWhichIsA("BasePart", true)
                    end

                    ScrambleAuto.Status = "Boss down -- leaving the arena."
                    if leavePart == nil then
                        continue
                    end

                    if (leavePart.Position - hrp.Position).Magnitude <= 12 then
                        hrp.CFrame = leavePart.CFrame
                        hrp.AssemblyLinearVelocity = Vector3.zero
                        continue
                    end

                    targetPos, targetName = leavePart.Position, "leave"
                elseif os.clock() - lastTargetCheck > 0.3 then
                    lastTargetCheck = os.clock()
                    targetPos, targetName = scrBossTarget(arena, hrp.Position)
                    if targetPos == nil and phase == "Ball" then
                        targetPos, targetName = scrBossBallSpot(arena, hrp.Position)
                    end
                end

                -- Dynamic live tracking for moving targets
                if targetName == "the Scramble Human" then
                    local human = arena:FindFirstChild("ScrambleHuman")
                    if human and human:GetAttribute("Immune") ~= true then
                        local okP, piv = pcall(human.GetPivot, human)
                        targetPos = okP and piv.Position or targetPos
                    else
                        local mech = arena:FindFirstChild("Mech")
                        if mech then
                            local okP, piv = pcall(mech.GetPivot, mech)
                            targetPos = okP and piv.Position or targetPos
                            targetName = "the Mech"
                        end
                    end
                elseif targetName == "the Mech" then
                    local mech = arena:FindFirstChild("Mech")
                    if mech then
                        local okP, piv = pcall(mech.GetPivot, mech)
                        targetPos = okP and piv.Position or targetPos
                    end
                elseif targetName == "the ball" then
                    local ball = arena:FindFirstChild("Ball")
                    local ballPos = ball and (ball:IsA("BasePart") and ball.Position or (ball:IsA("Model") and ball:GetPivot().Position))
                    targetPos = ballPos or targetPos
                end

                if targetPos == nil then
                    ScrambleAuto.Status = string.format("Phase: %s -- waiting for target...", tostring(targetName or phase))
                    continue
                end

                local diff = Vector3.new(targetPos.X - hrp.Position.X, 0, targetPos.Z - hrp.Position.Z)
                local stopDist = minRange
                if targetName == "leave" or tostring(targetName):find("ball", 1, true) then
                    stopDist = 0
                end
                if targetName == "the ball" then
                    stopDist = 4
                end

                local goal = (diff.Magnitude > stopDist and diff.Magnitude > 0.5) and (Vector3.new(targetPos.X, hrp.Position.Y, targetPos.Z) - diff.Unit * stopDist) or hrp.Position
                local detour = scrDetour(arena, hrp.Position, goal, targetName)
                local step = detour - hrp.Position

                if step.Magnitude > 0.5 then
                    local maxStep = speed * dt
                    -- Snap directly when near human or ball so player is never lagging behind
                    if (targetName == "the Scramble Human" or targetName == "the Mech") and diff.Magnitude <= 40 then
                        maxStep = step.Magnitude
                    elseif targetName == "the ball" and diff.Magnitude <= 40 then
                        maxStep = step.Magnitude
                    end
                    local newPos = hrp.Position + step.Unit * math.min(maxStep, step.Magnitude)
                    local lookVec = Vector3.new(targetPos.X - newPos.X, 0, targetPos.Z - newPos.Z)
                    if lookVec.Magnitude > 0.1 then
                        hrp.CFrame = CFrame.lookAt(newPos, newPos + lookVec.Unit)
                    else
                        hrp.CFrame = CFrame.new(newPos) * hrp.CFrame.Rotation
                    end
                    hrp.AssemblyLinearVelocity = Vector3.zero
                end

                if targetName ~= "leave" and diff.Magnitude <= math.max(attackRange, stopDist + 5) then
                    local bat = bossBat()
                    if bat and not bossOnCooldown(bat) then
                        doScrSwing(bat)
                    end
                    ScrambleAuto.Status = string.format("Hitting %s (phase %s)", tostring(targetName), tostring(phase))
                elseif targetName ~= "leave" then
                    ScrambleAuto.Status = string.format("Moving to %s (%.0f studs)", tostring(targetName), diff.Magnitude)
                end
            end

            bossNoclip(false)
            pcall(scrBossHazards, false)
            ScrambleAuto.Busy = false
            ScrBoss.running = false

            -- Post-boss defeat actions: claim rewards and plant reward eggs
            task.spawn(function()
                task.wait(1.5)
                if ScrambleAuto.AutoBossMastery then
                    ScrambleAuto.Status = "Boss defeated: Claiming mastery rewards..."
                    pcall(claimAllMasteries)
                end
                if ScrambleAuto.AutoPlaceBossEgg or ScrambleAuto.AutoLabPlace then
                    ScrambleAuto.Status = "Boss defeated: Planting reward egg on plot..."
                    task.wait(0.5)
                    pcall(plantAllUnplacedEggs)
                end
            end)
        end
        local function scrBossMastery()
            if not ScrambleAuto.AutoBossMastery or os.clock() - ScrBoss.masteryAt < 10 then return end
            ScrBoss.masteryAt = os.clock()
            pcall(claimAllMasteries)
        end

        local function scrBossTick()
            pcall(scrBossMastery)
            if not ScrambleAuto.AutoBoss then
                if not ScrBoss.running and next(ScrBoss.off) ~= nil then
                    pcall(scrBossHazards, false)
                end
                return
            end

            -- 1. If in arena, run fight
            if scrBossInArena() then
                if not ScrBoss.running then
                    ScrBoss.running = true
                    task.spawn(function()
                        pcall(scrBossFight)
                        ScrBoss.running = false
                        ScrambleAuto.Busy = false
                    end)
                end
                return
            end

            -- 2. If portal not up, show countdown
            if not scrBossPortalUp() then
                ScrBoss.portalSeen = false
                local now, seen = Workspace:GetServerTimeNow(), ScrBoss.seenStart or 0
                local nextFight = seen + math.ceil((now - seen) / 1800) * 1800
                local left = math.max(0, math.floor(nextFight - now))
                ScrambleAuto.BossLastStatus = string.format("Next fight in %d:%02d%s", math.floor(left / 60), left % 60, ScrBoss.seenStart and "" or " (est)")
                return
            end

            if not ScrBoss.portalSeen then
                ScrBoss.portalSeen = true
                ScrBoss.seenStart = Workspace:GetServerTimeNow()
            end

            if ScrambleAuto.Busy then
                ScrambleAuto.BossLastStatus = "Portal is UP -- waiting for current action to finish"
                return
            end

            if os.clock() - ScrBoss.enterAt < 5 then return end

            local bat = bossBat()
            if not bat then
                ScrambleAuto.BossLastStatus = "No bat found in inventory"
                return
            end

            ScrBoss.enterAt = os.clock()
            ScrambleAuto.BossLastStatus = "Portal is UP -- entering arena..."
            ScrBoss.entering = true
            ScrambleAuto.Busy = true

            pcall(scrBossEnter)

            if not scrBossInArena() then
                ScrBoss.entering = false
                ScrambleAuto.Busy = false
                ScrambleAuto.BossLastStatus = "Could not enter portal -- retrying"
                return
            end

            ScrBoss.running = true
            task.spawn(function()
                pcall(scrBossFight)
                ScrBoss.running = false
                ScrBoss.entering = false
                ScrambleAuto.Busy = false
            end)
        end

        -- ==================== DR. SCRAMBLE FARM & QUEST ENGINE ====================
        local function getLiveDrones()
            local list = {}
            for id, d in pairs(Drones) do
                if (tonumber(d.Health) or 0) > 0 and d.Position then
                    table.insert(list, d)
                end
            end
            if #list == 0 then
                local folder = Workspace:FindFirstChild("ScrambleLocalVisuals")
                if folder then
                    for _, child in ipairs(folder:GetChildren()) do
                        if child:IsA("Model") and (child.Name:find("PersonalDrone") or child:GetAttribute("ScrambleDroneId")) then
                            local hitbox = child:FindFirstChild("Hitbox") or child.PrimaryPart
                            local hp = hitbox and tonumber(hitbox:GetAttribute("Health")) or 1
                            if hp > 0 and hitbox then
                                table.insert(list, {
                                    Id = child.Name,
                                    Position = hitbox.Position,
                                    Health = hp,
                                    Tier = tostring(child:GetAttribute("ScrambleTier") or ""),
                                })
                            end
                        end
                    end
                end
            end
            return list
        end

        local function collectDrops()
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if not root then return false end

            local nearestId, nearestDrop, nearestDist = nil, nil, math.huge
            for id, drop in pairs(Drops) do
                if drop.Position then
                    local d = (root.Position - drop.Position).Magnitude
                    if d < nearestDist then
                        nearestId, nearestDrop, nearestDist = id, drop, d
                    end
                end
            end

            if nearestDrop then
                ScrambleAuto.Status = "Collecting " .. tostring(nearestDrop.Kind or "Samples")
                local reached = tweenTo(nearestDrop.Position + Vector3.new(0, 1.5, 0), 4)
                if reached or (root.Position - nearestDrop.Position).Magnitude <= 8 then
                    Drops[nearestId] = nil
                    task.wait(0.08)
                    return true
                end
            end
            return false
        end

        local function farmDrones()
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if not root then return false end

            local drones = getLiveDrones()
            if #drones == 0 then return false end

            local tierRank = { AugmentedDrone = 3, ReactorDrone = 2, ScrapDrone = 1 }
            local bestDrone, bestDist = nil, math.huge
            for _, d in ipairs(drones) do
                local dist = (root.Position - d.Position).Magnitude
                if not bestDrone then
                    bestDrone, bestDist = d, dist
                else
                    if ScrambleAuto.AutoRarest then
                        local r1 = tierRank[d.Tier] or 0
                        local r2 = tierRank[bestDrone.Tier] or 0
                        if r1 > r2 then
                            bestDrone, bestDist = d, dist
                        elseif r1 == r2 and dist < bestDist then
                            bestDrone, bestDist = d, dist
                        end
                    else
                        if dist < bestDist then
                            bestDrone, bestDist = d, dist
                        end
                    end
                end
            end

            if not bestDrone then return false end

            local tool = bossBat()
            if not tool then
                ScrambleAuto.Status = "No bat/weapon found in inventory"
                return false
            end

            local targetPos = bestDrone.Position
            tweenTo(targetPos + Vector3.new(0, 1.5, 0), 8)

            quickSwing()

            local tierLabel = bestDrone.Tier ~= "" and bestDrone.Tier or "Drone"
            ScrambleAuto.Status = string.format("Smashing %s (%d HP)", tierLabel, math.ceil(bestDrone.Health or 1))
            return true
        end

        local function runQuestStep()
            local snap = getEventSnapshot(true)
            local state = snap and snap.State
            if not state then return end

            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if not root then return end

            -- Step 1: Discover
            if state.Discovered ~= true then
                ScrambleAuto.Status = "Quest: Entering Secret Cave to discover NPC..."
                tweenTo(Vector3.new(2125.7, 73.1, -295.4), 6)
                local cave = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("SecretZones") and workspace.World.SecretZones:FindFirstChild("Cave")
                local tele = cave and cave:FindFirstChild("Teleporter") and cave.Teleporter:FindFirstChild("Entry")
                local prompt = tele and tele:FindFirstChildWhichIsA("ProximityPrompt", true)
                if prompt then triggerPrompt(prompt) end
                task.wait(1.5)

                local req = getRemote("RF/Scramble/Request")
                if req then
                    local ok, disc = pcall(function() return req:InvokeServer("Discover") end)
                    if ok then
                        getEventSnapshot(true)
                        ScrambleAuto.Status = "Quest: Discovered Escaped Experiment!"
                    end
                end
                return
            end

            -- Step 2: Lost Parts
            local lostParts = state.LostParts or {}
            if not lostParts.LostPart1 then
                ScrambleAuto.Status = "Quest: Collecting Lost Part 1 (Mechanical Gear)..."
                local p1Pos = Vector3.new(1781.2, 70.9, -298.9)
                tweenTo(p1Pos, 4)
                task.wait(0.3)
                local dr = Workspace:FindFirstChild("DrScrambleEvent")
                local p1 = dr and dr:FindFirstChild("LostPart1")
                local prompt = p1 and p1:FindFirstChildWhichIsA("ProximityPrompt", true)
                if prompt then
                    triggerPrompt(prompt)
                else
                    pcall(function() VIM:SendKeyEvent(true, Enum.KeyCode.E, false, game) end)
                    task.wait(1.5)
                    pcall(function() VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game) end)
                end
                task.wait(0.5)
                getEventSnapshot(true)
                return
            end

            if not lostParts.LostPart2 then
                ScrambleAuto.Status = "Quest: Collecting Lost Part 2 (Wiring Harness)..."
                local p2Pos = Vector3.new(2782.4, 69.3, -429.3)
                tweenTo(p2Pos, 4)
                task.wait(0.3)
                local dr = Workspace:FindFirstChild("DrScrambleEvent")
                local p2 = dr and dr:FindFirstChild("LostPart2")
                local prompt = p2 and p2:FindFirstChildWhichIsA("ProximityPrompt", true)
                if prompt then
                    triggerPrompt(prompt)
                else
                    pcall(function() VIM:SendKeyEvent(true, Enum.KeyCode.E, false, game) end)
                    task.wait(1.5)
                    pcall(function() VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game) end)
                end
                task.wait(0.5)
                getEventSnapshot(true)
                return
            end

            -- Step 3: Vault
            local totalParts = tonumber(state.TotalParts) or 0
            if totalParts >= 5 and state.Completed ~= true then
                ScrambleAuto.Status = "Quest: 5/5 parts collected! Opening Experiment Vault..."
                tweenTo(Vector3.new(2125.7, 73.1, -295.4), 6)
                local cave = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("SecretZones") and workspace.World.SecretZones:FindFirstChild("Cave")
                local tele = cave and cave:FindFirstChild("Teleporter") and cave.Teleporter:FindFirstChild("Entry")
                local prompt = tele and tele:FindFirstChildWhichIsA("ProximityPrompt", true)
                if prompt then triggerPrompt(prompt) end
                task.wait(1.5)

                local req = getRemote("RF/Scramble/Request")
                if req then
                    local ok, vRes = pcall(function() return req:InvokeServer("Vault") end)
                    if ok then
                        getEventSnapshot(true)
                        ScrambleAuto.Status = "Quest: Vault opened! The Scrambler unlocked!"
                    end
                end
            end
        end

        local function runShopStep()
            local snap = getEventSnapshot()
            local state = snap and snap.State
            local shop = snap and snap.Shop
            if not state or not shop then return end

            local currentSamples = tonumber(state.Samples) or 0
            local keep = tonumber(ScrambleAuto.KeepSamples) or 0

            local idMap = {
                ["Scrambled Mutation"] = "MutationConsumable",
                ["2x Cash Booster"] = "CashBooster",
                ["1.25x Speed"] = "SpeedBoost",
                ["2x Treadmill Booster"] = "TreadmillBooster",
            }

            for _, item in ipairs(shop) do
                local wanted = false
                for label, selected in pairs(ScrambleAuto.ShopPicks) do
                    if selected and (idMap[label] == item.Id or label == item.Id) then
                        wanted = true
                        break
                    end
                end

                if wanted then
                    local price = tonumber(item.Price) or 999999
                    if currentSamples - price >= keep then
                        local req = getRemote("RF/Scramble/Request")
                        if req then
                            local ok, res = pcall(function()
                                return req:InvokeServer("Shop", item.Id, {
                                    Quote = item.Quote,
                                    Sequence = tonumber(state.ShopSequence) or 0,
                                })
                            end)
                            if ok and type(res) == "table" and res.Ok == true then
                                ScrambleAuto.ShopLastBought = tostring(item.Id)
                                currentSamples = currentSamples - price
                                getEventSnapshot(true)
                                task.wait(0.4)
                            end
                        end
                    end
                end
            end
        end

        local function getOwnedInventoryEggs()
            local fn = Save and (Save.Get or Save.Peek)
            local ok, save = pcall(fn)
            if not ok or type(save) ~= "table" or type(save.EggInventory) ~= "table" then
                return {}
            end
            local list = {}
            for uid, egg in pairs(save.EggInventory) do
                if type(egg) == "table" and egg.Placement == nil then
                    table.insert(list, { Uid = uid, Category = tostring(egg.AssetCategory) })
                end
            end
            return list
        end

        local function runLabStep()
            local tradeState = getTradeState()
            if not tradeState then return end

            local req = getRemote("RF/ScrambleTradeIn/AskFinishReveal")
            if tradeState.PendingReward == true and req then
                pcall(function() req:InvokeServer() end)
                cachedTradeState = nil
                getTradeState(true)
            end

            local bannerId = tostring(tradeState.BannerId or "")
            local bannerDisplayName = tostring(tradeState.BannerDisplayName or bannerId)

            local bannerMatches = true
            if next(ScrambleAuto.LabBanners) ~= nil then
                bannerMatches = (ScrambleAuto.LabBanners[bannerId] == true)
                    or (ScrambleAuto.LabBanners[bannerDisplayName] == true)
            end

            if not bannerMatches then
                if ScrambleAuto.AutoLabReroll and (tonumber(tradeState.FreeRefreshesRemaining) or 0) > 0 then
                    local refRemote = getRemote("RF/ScrambleTradeIn/AskRefresh")
                    if refRemote then
                        pcall(function() refRemote:InvokeServer() end)
                        cachedTradeState = nil
                        getTradeState(true)
                    end
                end
                return
            end

            local requirements = tradeState.Requirements
            if type(requirements) == "table" and #requirements >= 3 then
                local inv = getOwnedInventoryEggs()
                local usedUids = {}
                local chosenPets = {}

                for i = 1, 3 do
                    local reqCat = tostring(requirements[i])
                    local foundUid = nil
                    for _, egg in ipairs(inv) do
                        if not usedUids[egg.Uid] and egg.Category == reqCat then
                            foundUid = egg.Uid
                            break
                        end
                    end
                    if foundUid then
                        usedUids[foundUid] = true
                        table.insert(chosenPets, foundUid)
                    end
                end

                if #chosenPets == 3 then
                    ScrambleAuto.Status = "Lab: Sacrificing 3 pets for " .. bannerDisplayName .. "..."
                    local tradeRemote = getRemote("RF/ScrambleTradeIn/AskTradeIn")
                    if tradeRemote then
                        local ok, res = pcall(function() return tradeRemote:InvokeServer(chosenPets) end)
                        if ok and res ~= false then
                            pcall(function()
                                local finishRemote = getRemote("RF/ScrambleTradeIn/AskFinishReveal")
                                if finishRemote then finishRemote:InvokeServer() end
                            end)
                            ScrambleAuto.LabLastTraded = bannerDisplayName
                            cachedTradeState = nil
                            getTradeState(true)
                            task.wait(0.5)
                            if ScrambleAuto.AutoLabPlace or ScrambleAuto.AutoPlaceBossEgg then
                                task.spawn(function()
                                    task.wait(0.5)
                                    pcall(plantAllUnplacedEggs)
                                end)
                            end
                        end
                    end
                end
            end
        end

        local function findMutationConsumable(kind)
            local search = kind:lower()
            local char = LocalPlayer.Character
            if char then
                for _, t in ipairs(char:GetChildren()) do
                    if t:IsA("Tool") and (t.Name:lower():find(search) or tostring(t:GetAttribute("MutationId")):lower():find(search)) then
                        return t
                    end
                end
            end
            local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
            if bp then
                for _, t in ipairs(bp:GetChildren()) do
                    if t:IsA("Tool") and (t.Name:lower():find(search) or tostring(t:GetAttribute("MutationId")):lower():find(search)) then
                        return t
                    end
                end
            end
            return nil
        end

        local function runMutateStep()
            local tool = findMutationConsumable(ScrambleAuto.MutateKind)
            if not tool then return end

            local EggState = require(ReplicatedStorage.Client.EggState)
            local ok, records = pcall(function() return EggState.ReadOwnerEggs(LocalPlayer.UserId) end)
            if not ok or type(records) ~= "table" then return end

            local targetEgg = nil
            for uid, egg in pairs(records) do
                if type(egg) == "table" and egg.Placement ~= nil then
                    local cat = tostring(egg.AssetCategory)
                    local allowed = true
                    if next(ScrambleAuto.MutateEggs) ~= nil then
                        allowed = (ScrambleAuto.MutateEggs[cat] == true)
                    end
                    if allowed then
                        local hasMut = (tostring(egg.BaseMutation or "") == ScrambleAuto.MutateKind)
                        if not hasMut then
                            targetEgg = egg
                            break
                        end
                    end
                end
            end

            if targetEgg and targetEgg.Placement and targetEgg.Placement.LocalCFrame then
                local PlotState = require(ReplicatedStorage.Client.PlotState)
                local okP, plot = pcall(PlotState.ResolvePlot)
                if okP and plot and plot.CenterPoint then
                    local worldCF = plot.CenterPoint.CFrame * targetEgg.Placement.LocalCFrame
                    local char = LocalPlayer.Character
                    local hum = char and char:FindFirstChildOfClass("Humanoid")
                    if hum and tool.Parent ~= char then
                        pcall(function() hum:EquipTool(tool) end)
                        task.wait(0.2)
                    end
                    tweenTo(worldCF.Position + Vector3.new(0, 2, 0), 4)

                    local useRemote = getRemote("RF/BossMastery/AskUseMutationConsumable")
                    if useRemote then
                        pcall(function() useRemote:InvokeServer(targetEgg.Uid) end)
                    end
                    pcall(function() tool:Activate() end)
                    ScrambleAuto.Status = "Mutating egg with " .. ScrambleAuto.MutateKind
                    task.wait(1.0)
                end
            end
        end

        local function setOf(value)
            local result = {}
            if type(value) == "string" then
                if value ~= "Select All" and value ~= "All" then result[value] = true end
            elseif type(value) == "table" then
                for key, item in pairs(value) do
                    local selected = item == true and tostring(key) or (type(item) == "string" and item or nil)
                    if selected and selected ~= "Select All" and selected ~= "All" then
                        result[selected] = true
                    end
                end
            end
            return result
        end

        local scrambleStatus = EventMainSection:Paragraph({
            Title = "Dr Scramble: Idle",
            Desc = "Initializing event tracker...",
            Image = "zap",
            ImageSize = 34,
        })

        EventMainSection:Toggle({
            Title = "Auto Collect (Drones and Drops)",
            Flag = "Event_ScrambleFarm",
            Value = false,
            Callback = function(v) ScrambleAuto.AutoFarm = v == true end,
        })

        EventMainSection:Toggle({
            Title = "Prioritize Rarest Drones",
            Flag = "Event_ScrambleRarest",
            Value = true,
            Callback = function(v) ScrambleAuto.AutoRarest = v == true end,
        })

        EventMainSection:Toggle({
            Title = "Auto Pick Up Drops",
            Flag = "Event_ScrambleDrops",
            Value = true,
            Callback = function(v) ScrambleAuto.AutoDrops = v == true end,
        })

        EventMainSection:Toggle({
            Title = "Auto Quest (Cave, Parts, Vault)",
            Flag = "Event_ScrambleQuest",
            Value = false,
            Callback = function(v) ScrambleAuto.AutoQuest = v == true end,
        })

        EventMainSection:Divider()

        EventMainSection:Toggle({
            Title = "Auto Buy Event Shop",
            Flag = "Event_ScrambleBuy",
            Value = false,
            Callback = function(v) ScrambleAuto.AutoShop = v == true end,
        })

        EventMainSection:Dropdown({
            Title = "Shop Items to Buy",
            Flag = "Event_ScrambleBuyPicks",
            Values = { "Scrambled Mutation", "2x Cash Booster", "1.25x Speed", "2x Treadmill Booster" },
            Multi = true,
            AllowNone = true,
            NativeSelectAll = true,
            Value = { ["Scrambled Mutation"] = true },
            Callback = function(v) ScrambleAuto.ShopPicks = setOf(v) end,
        })

        EventMainSection:Slider({
            Title = "Keep Samples Reserve",
            Flag = "Event_ScrambleKeepSamples",
            Value = { Min = 0, Max = 5000, Default = 0 },
            Step = 25,
            Callback = function(v) ScrambleAuto.KeepSamples = tonumber(v) or 0 end,
        })

        EventMainSection:Divider()

        EventMainSection:Toggle({
            Title = "Auto Lab Trade-In (The Scrambler)",
            Flag = "Event_LabTradeIn",
            Value = false,
            Callback = function(v) ScrambleAuto.AutoLab = v == true end,
        })

        EventMainSection:Dropdown({
            Title = "Banners to Keep (empty = all)",
            Flag = "Event_LabBanners",
            Values = { "Experimental", "Mutated", "Cosmic", "Mythic", "Divine", "Secret" },
            Multi = true,
            AllowNone = true,
            NativeSelectAll = true,
            Value = {},
            Callback = function(v) ScrambleAuto.LabBanners = setOf(v) end,
        })

        EventMainSection:Toggle({
            Title = "Auto Reroll Lab Recipe",
            Flag = "Event_LabReroll",
            Value = false,
            Callback = function(v) ScrambleAuto.AutoLabReroll = v == true end,
        })

        EventMainSection:Toggle({
            Title = "Auto Place Lab Reward Eggs",
            Flag = "Event_LabPlaceEgg",
            Value = true,
            Callback = function(v) ScrambleAuto.AutoLabPlace = v == true end,
        })

        EventMainSection:Divider()

        EventMainSection:Toggle({
            Title = "Auto Fight Boss",
            Flag = "Event_BossFight",
            Value = false,
            Callback = function(v) ScrambleAuto.AutoBoss = v == true end,
        })

        EventMainSection:Toggle({
            Title = "Auto Claim Boss Mastery",
            Flag = "Event_BossMastery",
            Value = true,
            Callback = function(v) ScrambleAuto.AutoBossMastery = v == true end,
        })

        EventMainSection:Toggle({
            Title = "Auto Place Boss & Event Eggs",
            Flag = "Event_BossPlaceEgg",
            Value = true,
            Callback = function(v) ScrambleAuto.AutoPlaceBossEgg = v == true end,
        })

        EventMainSection:Divider()

        EventMainSection:Toggle({
            Title = "Auto Apply Mutation",
            Flag = "Event_AutoMutate",
            Value = false,
            Callback = function(v) ScrambleAuto.AutoMutate = v == true end,
        })

        EventMainSection:Dropdown({
            Title = "Mutation Type",
            Flag = "Event_MutateKind",
            Values = { "Scrambled", "Fractured (Boss)" },
            Value = "Scrambled",
            Callback = function(v) ScrambleAuto.MutateKind = tostring(v) end,
        })

        local eggOptions = {}
        pcall(function()
            local Assets = require(ReplicatedStorage.Data.Assets)
            if Assets and Assets.Directory then
                for cat, data in pairs(Assets.Directory) do
                    table.insert(eggOptions, tostring(data.DisplayName or cat))
                end
            end
        end)
        table.sort(eggOptions)

        EventMainSection:Dropdown({
            Title = "Target Eggs to Mutate (empty = all)",
            Flag = "Event_MutateEggs",
            Values = eggOptions,
            Multi = true,
            AllowNone = true,
            NativeSelectAll = true,
            Value = {},
            Callback = function(v) ScrambleAuto.MutateEggs = setOf(v) end,
        })

        local function isAutoStealActive()
            local steal = ScriptEnv.SAE_AutoSteal
            if not steal then return false end
            if steal.Busy == true or steal.Carrying == true or steal.ReturningToSafe == true
                or steal.Moving == true or steal.ActiveTargetUid ~= nil
            then
                return true
            end
            local normalEnabled = steal.SelectedEnabled or steal.SecretEnabled or steal.BigEnabled or steal.RarestEnabled
            if normalEnabled and type(steal.hasAvailableStealTarget) == "function" and steal.hasAvailableStealTarget() then
                local night, resetSoon, _, dayReady = steal.refreshCycleState()
                if not night and not resetSoon and dayReady then
                    return true
                end
            end
            return false
        end

        task.spawn(function()
            while not ScrambleAuto.Closed and ScriptEnv.SAE_RunToken == entryToken do
                task.wait(0.25)
                pcall(function()
                    -- Priority: Auto Steal is #1. If Auto Steal is active, Event yields completely!
                    if isAutoStealActive() then
                        ScrambleAuto.Busy = false
                        if not scrBossInArena() then
                            scrambleStatus:SetTitle("Dr Scramble: Paused (Auto Steal in progress)")
                            return
                        end
                    end
                    -- Boss check takes priority if in arena or portal up
                    if ScrambleAuto.AutoBoss then
                        scrBossTick()
                    end

                    -- If inside arena, don't do outside tasks
                    if scrBossInArena() then
                        return
                    end

                    local hasWork = ScrambleAuto.AutoFarm or ScrambleAuto.AutoQuest
                        or ScrambleAuto.AutoShop or ScrambleAuto.AutoLab
                        or ScrambleAuto.AutoMutate

                    if hasWork then
                        ScrambleAuto.Busy = true

                        -- 1. Drops collection
                        if ScrambleAuto.AutoDrops and next(Drops) ~= nil then
                            collectDrops()
                        end

                        -- 2. Drones farming
                        if ScrambleAuto.AutoFarm and #getLiveDrones() > 0 then
                            farmDrones()
                        end

                        -- 3. Quests
                        if ScrambleAuto.AutoQuest then
                            runQuestStep()
                        end

                        -- 4. Shop
                        if ScrambleAuto.AutoShop and os.clock() - ScrambleAuto.LastShopCheck >= 3.0 then
                            ScrambleAuto.LastShopCheck = os.clock()
                            runShopStep()
                        end

                        -- 5. Lab Trade-In
                        if ScrambleAuto.AutoLab and os.clock() - ScrambleAuto.LastLabCheck >= 3.0 then
                            ScrambleAuto.LastLabCheck = os.clock()
                            runLabStep()
                        end

                        -- 6. Mutation
                        if ScrambleAuto.AutoMutate and os.clock() - ScrambleAuto.LastMutateCheck >= 5.0 then
                            ScrambleAuto.LastMutateCheck = os.clock()
                            runMutateStep()
                        end

                        -- 7. Continuous Auto Claim Mastery
                        if ScrambleAuto.AutoBossMastery and os.clock() - ScrambleAuto.LastMasteryCheck >= 4.0 then
                            ScrambleAuto.LastMasteryCheck = os.clock()
                            pcall(claimAllMasteries)
                        end

                        -- 8. Continuous Auto Place Unplaced Eggs
                        if (ScrambleAuto.AutoPlaceBossEgg or ScrambleAuto.AutoLabPlace) and os.clock() - ScrambleAuto.LastPlaceCheck >= 3.0 then
                            ScrambleAuto.LastPlaceCheck = os.clock()
                            pcall(plantAllUnplacedEggs)
                        end

                        ScrambleAuto.Busy = false
                    else
                        if not scrBossPortalUp() then
                            ScrambleAuto.Status = "Idle"
                        end
                        ScrambleAuto.Busy = false
                    end

                    -- Update status dashboard
                    local snap = getEventSnapshot()
                    local state = snap and snap.State
                    local samples = state and tonumber(state.Samples) or 0
                    local totalParts = state and tonumber(state.TotalParts) or 0
                    local lostParts = state and state.LostParts or {}
                    local lpCount = (lostParts.LostPart1 and 1 or 0) + (lostParts.LostPart2 and 1 or 0)
                    local dpCount = state and tonumber(state.DroneParts) or 0
                    local droneCount = #getLiveDrones()
                    local dropCount = 0
                    for _ in pairs(Drops) do dropCount = dropCount + 1 end

                    local tradeState = getTradeState()
                    local bannerName = tradeState and tostring(tradeState.BannerDisplayName or tradeState.BannerId or "None") or "N/A"
                    local reqList = {}
                    if tradeState and type(tradeState.Requirements) == "table" then
                        for _, r in ipairs(tradeState.Requirements) do table.insert(reqList, tostring(r)) end
                    end

                    local bossStatusText = scrBossInArena() and "IN ARENA" or (scrBossPortalUp() and "PORTAL UP" or (ScrambleAuto.BossLastStatus ~= "" and ScrambleAuto.BossLastStatus or "Closed"))

                    scrambleStatus:SetTitle("Dr Scramble: " .. ScrambleAuto.Status)
                    scrambleStatus:SetDesc(string.format(
                        "Samples: <b>%d</b> - Drones: <b>%d</b> - Drops: <b>%d</b>\nParts: <b>%d/5</b> (Lost: %d/2, Drone: %d/3) - Outbreak: <b>%s</b>\nLab: <b>%s</b> (%s) - Boss: <b>%s</b>",
                        samples, droneCount, dropCount,
                        totalParts, lpCount, dpCount, isOutbreakActive() and "Active" or "Waiting",
                        bannerName, #reqList > 0 and table.concat(reqList, ", ") or "none",
                        bossStatusText
                    ))
                end)
            end
        end)

        pcall(function()
            local frame = EventMainSection.ElementFrame
            local content = frame and frame:FindFirstChild("Content", true)
            if content then content.Visible = true end
            if EventMainSection.Open then EventMainSection:Open() end
        end)

        ScriptEnv.SAE_ScrambleAuto = ScrambleAuto
        ScriptEnv.SAE_ScrambleCleanup = function()
            ScrambleAuto.Closed = true
            ScrambleAuto.AutoFarm = false
            ScrambleAuto.AutoQuest = false
            ScrambleAuto.AutoShop = false
            ScrambleAuto.AutoLab = false
            ScrambleAuto.AutoBoss = false
            ScrambleAuto.AutoMutate = false
            cancelActiveTween()
            pcall(scrBossHazards, false)
            for _, conn in ipairs(connections) do
                pcall(function() conn:Disconnect() end)
            end
            table.clear(connections)
            if ScriptEnv.SAE_ScrambleAuto == ScrambleAuto then ScriptEnv.SAE_ScrambleAuto = nil end
        end
    end

    local restored = false
    if CfgSystem.autoSaveEnabled then
        restored = CfgSystem.RestoreConfigSnapshot()
        if restored then
            Notify("Config", "Auto save restored", "check", 3)
        end
    end
    if not restored and CfgSystem.autoLoadState.enabled and CfgSystem.validConfigName(CfgSystem.autoLoadState.name) then
        local autoPath = CfgSystem.GetConfigFilePath(CfgSystem.autoLoadState.name)
        local ok = CfgSystem.RestoreConfigSnapshot(autoPath)
        if ok then
            Notify("Config", "Auto loaded: " .. CfgSystem.autoLoadState.name, "check", 3)
        end
    end

local Players = game:GetService("Players")
local player = Players.LocalPlayer

local originalHumanoidMaster = nil

local function captureOriginalHumanoid()
    if originalHumanoidMaster then
        return
    end
    local character = player.Character
    if not character then
        return
    end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        return
    end
    if character:FindFirstChild("UpperTorso") and humanoid.RigType == Enum.HumanoidRigType.R6 then
        return
    end
    pcall(function()
        humanoid.Archivable = true
        originalHumanoidMaster = humanoid:Clone()
    end)
end

local function stashHeldTools(character)
    local backpack = player:FindFirstChildOfClass("Backpack")
    local heldTools = {}
    for _, child in ipairs(character:GetChildren()) do
        if child:IsA("Tool") then
            table.insert(heldTools, child)
        end
    end

    if #heldTools == 0 then
        return
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        pcall(function()
            humanoid:UnequipTools()
        end)
    end

    local deadline = os.clock() + 0.5
    while os.clock() < deadline do
        local stillHeld = false
        for _, tool in ipairs(heldTools) do
            if tool.Parent == character then
                stillHeld = true
                break
            end
        end
        if not stillHeld then
            break
        end
        task.wait(0.05)
    end

    if backpack then
        for _, tool in ipairs(heldTools) do
            if tool.Parent == character then
                tool.Parent = backpack
            end
        end
    end
end

local function enableBypass()
    local character = player.Character
    if not character then
        return
    end

    captureOriginalHumanoid()

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        stashHeldTools(character)
        humanoid:Destroy()
    end

    local newHumanoid = Instance.new("Humanoid")
    if character:FindFirstChild("UpperTorso") then
        newHumanoid.RigType = Enum.HumanoidRigType.R15
        newHumanoid.HipHeight = 1.8
    end
    newHumanoid.Parent = character
end

local function disableBypass()
    local character = player.Character
    if not character then
        return
    end

    stashHeldTools(character)
    local bareHumanoid = character:FindFirstChildOfClass("Humanoid")
    if bareHumanoid then
        bareHumanoid:Destroy()
    end

    local isR15 = character:FindFirstChild("UpperTorso") ~= nil
    local humanoid
    if originalHumanoidMaster then
        pcall(function()
            humanoid = originalHumanoidMaster:Clone()
            humanoid.Parent = character
        end)
    end

    if not humanoid then
        humanoid = Instance.new("Humanoid")
        humanoid.Parent = character
    end

    if isR15 then
        pcall(function()
            humanoid.RigType = Enum.HumanoidRigType.R15
            if humanoid.HipHeight <= 0 then
                humanoid.HipHeight = 1.8
            end
        end)
    end

    if not humanoid:FindFirstChildOfClass("Animator") then
        local animator = Instance.new("Animator")
        animator.Parent = humanoid
    end

    humanoid:SetAttribute("SpeedBypassApplied", true)

    local animate = character:FindFirstChild("Animate")
    if animate and animate:IsA("LocalScript") then
        animate.Disabled = true
        task.wait(0.1)
        animate.Disabled = false
    end

    pcall(function()
        local playerModule = require(player.PlayerScripts:WaitForChild("PlayerModule"))
        local controls = playerModule.controls or (playerModule.GetControls and playerModule:GetControls())
        if controls then
            if controls.OnCharacterAdded then
                controls:OnCharacterAdded(character)
            end
            if controls.Disable and controls.Enable then
                controls:Disable()
                task.wait(0.05)
                controls:Enable()
            end
        end
    end)

    if workspace.CurrentCamera then
        workspace.CurrentCamera.CameraSubject = humanoid
    end
end

local function runBypassCycle()
    local character = player.Character
    if not character then
        character = player.CharacterAdded:Wait()
    end
    local currentHum = character:FindFirstChildOfClass("Humanoid")
    if currentHum and currentHum:GetAttribute("SpeedBypassApplied") == true then
        return true
    end

    character:WaitForChild("Humanoid", 10)

    captureOriginalHumanoid()
    enableBypass()
    task.wait(0.15)
    disableBypass()
end

local bypassCycleBusy = false
local bypassWatcherClosed = false
local bypassScheduleId = 0
local watchedCharacter = nil
local watchedChildAdded = nil
local characterAddedConnection = nil
local appearanceLoadedConnection = nil

local function scheduleBypass(character, delaySeconds)
    if bypassWatcherClosed or not character then return end
    local humNow = character:FindFirstChildOfClass("Humanoid")
    if humNow and humNow:GetAttribute("SpeedBypassApplied") == true then return end

    bypassScheduleId += 1
    local requestId = bypassScheduleId
    task.delay(delaySeconds or 0.35, function()
        if bypassWatcherClosed or requestId ~= bypassScheduleId then return end
        if player.Character ~= character or bypassCycleBusy then return end
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid:GetAttribute("SpeedBypassApplied") == true then return end

        bypassCycleBusy = true
        originalHumanoidMaster = nil
        local ok, err = pcall(runBypassCycle)
        bypassCycleBusy = false

        local env = (getgenv and getgenv() or _G)
        if ok then
            env.SAE_BypassReapplyCount = (tonumber(env.SAE_BypassReapplyCount) or 0) + 1
            env.SAE_BypassLastError = nil
        else
            env.SAE_BypassLastError = tostring(err)
            warn("[Fn Bypass] Reapply failed: " .. tostring(err))
        end
    end)
end

local function watchCharacter(character)
    watchedCharacter = character
    if watchedChildAdded then
        watchedChildAdded:Disconnect()
        watchedChildAdded = nil
    end

    watchedChildAdded = character.ChildAdded:Connect(function(child)
        if child:IsA("Humanoid") and not bypassCycleBusy and child:GetAttribute("SpeedBypassApplied") ~= true then
            scheduleBypass(character, 0.35)
        end
    end)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid:GetAttribute("SpeedBypassApplied") ~= true then
        scheduleBypass(character, 0.5)
    end
end

task.spawn(function()
    task.wait(0.5)
    local curChar = player.Character
    local curHum = curChar and curChar:FindFirstChildOfClass("Humanoid")
    if not curHum or curHum:GetAttribute("SpeedBypassApplied") ~= true then
        bypassCycleBusy = true
        originalHumanoidMaster = nil
        local initialBypassOk, initialBypassError = pcall(runBypassCycle)
        bypassCycleBusy = false
        if initialBypassOk then
            ScriptEnv.SAE_BypassReapplyCount = (tonumber(ScriptEnv.SAE_BypassReapplyCount) or 0) + 1
            ScriptEnv.SAE_BypassLastError = nil
        else
            ScriptEnv.SAE_BypassLastError = tostring(initialBypassError)
        end
    end
end)

characterAddedConnection = player.CharacterAdded:Connect(watchCharacter)
appearanceLoadedConnection = player.CharacterAppearanceLoaded:Connect(function(character)
    if character == watchedCharacter and not bypassCycleBusy then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid:GetAttribute("SpeedBypassApplied") ~= true then
            scheduleBypass(character, 0.25)
        end
    end
end)

if player.Character then
    watchCharacter(player.Character)
end

task.spawn(function()
    while not bypassWatcherClosed do
        task.wait(0.75)
        local character = player.Character
        if character and character ~= watchedCharacter then
            watchCharacter(character)
        elseif character and not bypassCycleBusy then
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid:GetAttribute("SpeedBypassApplied") ~= true then
                scheduleBypass(character, 0.1)
            end
        end
    end
end)

ScriptEnv.SAE_BypassCleanup = function()
    bypassWatcherClosed = true
    bypassScheduleId += 1
    if watchedChildAdded then watchedChildAdded:Disconnect() watchedChildAdded = nil end
    if characterAddedConnection then characterAddedConnection:Disconnect() characterAddedConnection = nil end
    if appearanceLoadedConnection then appearanceLoadedConnection:Disconnect() appearanceLoadedConnection = nil end
end

ScriptEnv.SAE_BypassWatchCharacter = watchCharacter

ScriptEnv.SAE_RunBypassCycle = function()
    if bypassCycleBusy then return end
    bypassCycleBusy = true
    originalHumanoidMaster = nil
    pcall(runBypassCycle)
    bypassCycleBusy = false
end

ScriptEnv.SAE_BypassResume = function(char)
    bypassWatcherClosed = false
    bypassScheduleId += 1
    if watchedChildAdded then watchedChildAdded:Disconnect() watchedChildAdded = nil end
    if characterAddedConnection then characterAddedConnection:Disconnect() characterAddedConnection = nil end
    if appearanceLoadedConnection then appearanceLoadedConnection:Disconnect() appearanceLoadedConnection = nil end

    characterAddedConnection = player.CharacterAdded:Connect(watchCharacter)
    appearanceLoadedConnection = player.CharacterAppearanceLoaded:Connect(function(character)
        if character == watchedCharacter and not bypassCycleBusy then
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if not humanoid or humanoid:GetAttribute("SpeedBypassApplied") ~= true then
                scheduleBypass(character, 0.25)
            end
        end
    end)

    local targetChar = char or player.Character
    if targetChar then
        watchCharacter(targetChar)
    end
end

    local function ResetFnRunning()
        local env = (getgenv and getgenv() or _G)
        if env.SAE_RunToken ~= entryToken then return end
        if type(env.SAE_StealCleanup) == "function" then
            pcall(env.SAE_StealCleanup)
        end
        if type(env.SAE_LocalMovementCleanup) == "function" then
            pcall(env.SAE_LocalMovementCleanup)
        end
        if type(env.SAE_EspCleanup) == "function" then
            pcall(env.SAE_EspCleanup)
        end
        if type(env.SAE_PerformanceCleanup) == "function" then
            pcall(env.SAE_PerformanceCleanup)
        end
        if type(env.SAE_GodmodeCleanup) == "function" then
            pcall(env.SAE_GodmodeCleanup)
        end
        if type(env.SAE_BatAuraCleanup) == "function" then
            pcall(env.SAE_BatAuraCleanup)
        end
        if type(env.SAE_UtilityCleanup) == "function" then
            pcall(env.SAE_UtilityCleanup)
        end
        if type(env.SAE_ScrambleCleanup) == "function" then
            pcall(env.SAE_ScrambleCleanup)
        end
        if type(env.SAE_IndexCleanup) == "function" then
            pcall(env.SAE_IndexCleanup)
        end
        if type(env.SAE_WebhookCleanup) == "function" then
            pcall(env.SAE_WebhookCleanup)
        end
        if type(env.SAE_BypassCleanup) == "function" then
            pcall(env.SAE_BypassCleanup)
        end
        env.SAE_StealCleanup = nil
        env.SAE_LocalMovementCleanup = nil
        env.SAE_EspCleanup = nil
        env.SAE_PerformanceCleanup = nil
        env.SAE_GodmodeCleanup = nil
        env.SAE_BatAuraCleanup = nil
        env.SAE_UtilityCleanup = nil
        env.SAE_ScrambleCleanup = nil
        env.SAE_IndexCleanup = nil
        env.SAE_WebhookCleanup = nil
        env.SAE_BypassCleanup = nil
        env.SAE_BypassResume = nil
        env.SAE_RunBypassCycle = nil
        env.SAE_BypassWatchCharacter = nil
        env.SAE_RunToken = nil
        env.SAE_Running = false
        env.sae_running = false
    end

    end, debug.traceback)
    if not entryOk then
        local env = (getgenv and getgenv() or _G)
        if env.SAE_RunToken == entryToken then
            env.SAE_LastError = tostring(entryError)
            env.SAE_RunToken = nil
            env.SAE_Running = false
            env.sae_running = false
        end
        warn("[Fn] Runtime error: " .. tostring(entryError))
    end
end)
