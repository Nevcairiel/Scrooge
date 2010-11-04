local addonname = "Broker_MoneyFu"
BrokerMoneyFu = LibStub("AceAddon-3.0"):NewAddon(addonname, "AceEvent-3.0")
local BMF = BrokerMoneyFu

local LibQTip = LibStub("LibQTip-1.0")
local LDB = LibStub('LibDataBroker-1.1')
if not LDB or not LibQTip then return end

--local L = LibStub:GetLibrary("AceLocale-3.0"):GetLocale(addonname)

local historysize = 29
local realmkey = GetRealmName()
local factionkey = UnitFactionGroup("player")
local otherfaction = (factionkey == "Alliance") and "Horde" or "Alliance"

local function mkdata(tbl)
	tbl.spent = {}
	tbl.gained = {}
	tbl.time = {}
end

local offset
local function serveroffset()
	if offset then
		return offset
	end
	local shour, sminute = GetGameTime()
	local ser = shour + sminute / 60
	local utc = tonumber(date("!%H")) + tonumber(date("!%M")) / 60
	offset = floor((ser - utc) * 2 + 0.5) / 2
	if offset >= 12 then
		offset = offset - 24
	elseif offset < -12 then
		offset = offset + 24
	end
	return offset
end

local function clearmoney(tbl, when)
	tbl.gained[when] = nil
	tbl.spent[when] = nil
	tbl.time[when] = nil
end

local function purgemoney(tbl)
	local cutoff = BMF:Today() - historysize
	for k in pairs(tbl.gained) do
		if k < cutoff then
			tbl.gained[k] = nil
		end
	end
	for k in pairs(tbl.spent) do
		if k < cutoff then
			tbl.spent[k] = nil
		end
	end
	for k in pairs(tbl.time) do
		if k < cutoff then
			tbl.time[k] = nil
		end
	end
end

local function storemoney(tbl, amount, elapsed, when)
	local gained = ((amount > 0) and amount or 0)
	local spent = ((amount < 0) and -amount or 0)
	local elapsed = elapsed or 0
	if when then
		if BMF:Today() - when > historysize then return end
		tbl.gained[when] = (tbl.gained[when] or 0) + gained
		tbl.spent[when] = (tbl.spent[when] or 0) + spent
		tbl.time[when] = (tbl.time[when] or 0) + elapsed
	else
		tbl.gained = (tbl.gained or 0) + gained
		tbl.spent = (tbl.spent or 0) + spent
		tbl.time = (tbl.time or 0) + elapsed
	end
end

local datakeys = {"gained", "spent", "time"}
local function accumulate(dest, src)
	if not src then return end

	for _, subv in ipairs(datakeys) do
		for k, v in pairs(src[subv]) do
			dest[subv][k] = (dest[subv][k] or 0) + v
		end
	end
end

local function consolidate(src, dstart, dend)
	if not src then return end
	local ret = {}
	for i = dstart, dend do
		for _, subv in ipairs(datakeys) do
			ret[subv] = (ret[subv] or 0) + (src[subv][i] or 0)
		end
	end
	return ret
end

local wealthlist = {}
local function wealthsort(a, b)
	return wealthlist[a] < wealthlist[b]
end

function BMF:OnInitialize()
	local defaults = {
		profile = {
			style = "graphical",
			perchar = false,
			perhour = true,
			crossfaction = false,
			allrealms = false,
			today = true,
			yesterday = true,
			last7 = true,
			last30 = true,
			charlist = true,
			guildlist = true,
		},
	}

	self.db = LibStub("AceDB-3.0"):New("BrokerMoneyFuDB", defaults, true)
	self.ldb = LDB:NewDataObject(addonname, {
		type = "data source",
		icon = "Interface\\Minimap\\Tracking\\Auctioneer",
		label = "MoneyFu",
		text = "MoneyFu",
		OnEnter = self.OnLDBEnter,
		OnLeave = self.OnLDBLeave,
		OnClick = self.OnLDBClick,
	})

	self.yellowfont = CreateFont("MoneyFuYellow")
	self.yellowfont:CopyFontObject(GameTooltipText)
	self.yellowfont:SetTextColor(1, 1, 0)

	self:CreateMenu()
end

function BMF:ResetSession()
	self.session = {}
end

function BMF:OnEnable()
	self.playername = UnitName("player")

	self.db.global[realmkey] = self.db.global[realmkey] or {}
	if not self.db.global[realmkey][factionkey] then
		self.db.global[realmkey][factionkey] = {
			guilds = {},
			chars = {},
		}
		mkdata(self.db.global[realmkey][factionkey])
	end

	self.realmdb = self.db.global[realmkey][factionkey]

	if not self.realmdb.chars[self.playername] then
		self.realmdb.chars[self.playername] = {}
		mkdata(self.realmdb.chars[self.playername])
	end
	self.chardb = self.realmdb.chars[self.playername]

	if not self.chardb.day then
		self.chardb.money = GetMoney()
		self.chardb.day = self:Today()
	end

	purgemoney(self.chardb)
	purgemoney(self.realmdb)

	self:ResetSession()
	self:CheckMoney()

	self:RegisterEvent("PLAYER_MONEY", "CheckMoney")
	self:RegisterEvent("PLAYER_TRADE_MONEY", "CheckMoney")
	self:RegisterEvent("TRADE_MONEY_CHANGED", "UpdateText")
	self:RegisterEvent("SEND_MAIL_MONEY_CHANGED", "UpdateText")
	self:RegisterEvent("SEND_MAIL_COD_CHANGED", "UpdateText")
	self:RegisterEvent("GUILDBANKFRAME_OPENED", "CheckGuildMoney")
	self:RegisterEvent("GUILDBANK_UPDATE_MONEY", "CheckGuildMoney")
end

local lastupdate
function BMF:CheckMoney()
	local now = time()
	local today = self:Today()
	local money = GetMoney()
	local initial = not lastupdate

	lastupdate = lastupdate or now

	if initial then
		today = self.chardb.day
	elseif today > self.chardb.day then
		clearmoney(self.chardb, today - historysize - 1)
		clearmoney(self.realmdb, today - historysize - 1)
		self.chardb.day = today
	end

	if money ~= self.chardb.money then
		local amount = money - self.chardb.money
		local elapsed = now - lastupdate
		if not initial then
			storemoney(self.session, amount, elapsed)
		end
		storemoney(self.chardb, amount, elapsed, today)
		storemoney(self.realmdb, amount, elapsed, today)
		self.chardb.money = money
	end

	lastupdate = now

	self:UpdateText()
	self:UpdateTooltip()
end

local lastguild
function BMF:CheckGuildMoney()
	if not IsInGuild() then return end

	local guildname = GetGuildInfo("player")
	if not self.realmdb.guilds[guildname] then return end

	local today = self:Today()
	local money = GetGuildBankMoney()
	lastguild = lastguild or money

	if money ~= lastguild then
		local amount = money - lastguild
		storemoney(self.session, amount)
		storemoney(self.realmdb, amount, 0, today)
	end

	lastguild = money
	self.realmdb.guilds[guildname].money = money

	self:CheckMoney()
end

function BMF:UpdateText()
	local money = GetMoney()

	self.ldb.text = self:FormatMoney(money)
end

local COLOR_GREEN = "00ff00"
local COLOR_RED = "ff0000"
local COLOR_COPPER = "eda55f"
local COLOR_SILVER = "c7c7cf"
local COLOR_GOLD = "ffd700"
function BMF:FormatMoney(amount, colorize)
	local style = self.db.profile.style
	local prefix = (amount < 0) and "-" or ""
	local color = (amount < 0) and COLOR_RED or COLOR_GREEN

	if not style or style == "graphical" then
		if colorize and amount ~= 0 then
			return format("|cff%s%s%s|r", color, prefix, GetCoinTextureString(abs(amount), 0))
		else
			return prefix..GetCoinTextureString(abs(amount), 0)
		end
	end

	local gold = abs(value / 10000)
	local silver = abs(mod(value / 100, 100))
	local copper = abs(mod(value, 100))
end

function BMF:AddMoneyLines(tbl, when)
	local hourly = self.db.profile.perhour
	local tip = self.tip
	local gained, spent, time
	if when then
		gained = tbl.gained[when] or 0
		spent = tbl.spent[when] or 0
		time = tbl.time[when] or 0
	else
		gained = tbl.gained or 0
		spent = tbl.spent or 0
		time = tbl.time or 0
	end
	if time <= 0 then hourly = false end
	time = time / 3600

	local line
	line = tip:AddLine(nil, self:FormatMoney(gained),
		hourly and self:FormatMoney(gained / time) or nil)
	tip:SetCell(line, 1, "Gained", self.yellowfont)
	line = tip:AddLine(nil, self:FormatMoney(spent),
		hourly and self:FormatMoney(spent / time) or nil)
	tip:SetCell(line, 1, "Spent", self.yellowfont)
	local profit = gained - spent
	line = tip:AddLine(nil, self:FormatMoney(profit, true),
		hourly and self:FormatMoney(profit / time, true) or nil)
	tip:SetCell(line, 1, profit >= 0 and "Profit" or "Loss", self.yellowfont)
end

function BMF:UpdateTooltip()
	local tip = self.tip
	local hourly = self.db.profile.perhour
	local today = self:Today()
	if not tip then return end

	tip:Clear()
	tip:SetCellMarginH(20)
	tip:SetColumnLayout(hourly and 3 or 2, "LEFT", "RIGHT", "RIGHT")

	tip:AddHeader("This Session", "Amount", hourly and "Per Hour" or nil)
	self:AddMoneyLines(self.session)

	local data
	if self.db.profile.perchar then
		data = self.chardb
	else
		data = {}
		mkdata(data)
		local rkeys
		if self.db.profile.allrealms then
			rkeys = {}
			for k, _ in pairs(self.db.global) do
				table.insert(rkeys, k)
			end
		else
			rkeys = { realmkey }
		end

		local fkeys = { factionkey }
		if self.db.profile.crossfaction then
			table.insert(fkeys, otherfaction)
		end

		for _, realm in ipairs(rkeys) do
			for _, faction in ipairs(fkeys) do
				local frdata = self.db.global[realm] and self.db.global[realm][faction]
				accumulate(data, frdata)
			end
		end
	end

	if self.db.profile.today then
		tip:AddLine(" ")
		tip:AddHeader("Today", "Amount", hourly and "Per Hour" or nil)
		self:AddMoneyLines(data, today)
	end

	if self.db.profile.yesterday then
		tip:AddLine(" ")
		tip:AddHeader("Yesterday", "Amount", hourly and "Per Hour" or nil)
		self:AddMoneyLines(data, today - 1)
	end

	local cdata
	if self.db.profile.last7 then
		cdata = consolidate(data, today - 6, today)
		tip:AddLine(" ")
		tip:AddHeader("Last 7 Days",  "Amount", hourly and "Per Hour" or nil)
		self:AddMoneyLines(cdata)
	end

	if self.db.profile.last30 then
		cdata = consolidate(data, today - 29, today)
		tip:AddLine(" ")
		tip:AddHeader("Last 30 Days",  "Amount", hourly and "Per Hour" or nil)
		self:AddMoneyLines(cdata)
	end

	local total = 0
	if self.db.profile.charlist then
		total = total + self:AddWealthList("chars", "Characters", true)
	end
	if self.db.profile.guildlist then
		total = total + self:AddWealthList("guilds", "Guilds")
	end

	if self.db.profile.charlist or self.db.profile.guildlist then
		tip:AddLine(" ")
		local line = tip:AddLine("Total")
		tip:SetCell(line, 2, self:FormatMoney(total), hourly and 2 or 1)
	
	end
end

function BMF:AddWealthList(tblname, header, ignoreplayer)
	local tip = self.tip
	local colspan = self.db.profile.perhour and 2 or 1
	local total = 0
	local line

	wipe(wealthlist)
	for k, v in pairs(self.realmdb[tblname]) do
		wealthlist[k] = v.money
	end
	if self.db.profile.crossfaction and self.db.global[realmkey][otherfaction] then
		for k, v in pairs(self.db.global[realmkey][otherfaction][tblname]) do
			wealthlist[k] = v.money
		end
	end
	if (not ignoreplayer and next(wealthlist)) or ignoreplayer and (next(wealthlist) ~= self.playername or next(wealthlist, self.playername)) then
		local t = {}
		for name in pairs(wealthlist) do
			table.insert(t, name)
		end
		table.sort(t, wealthsort)
		tip:AddLine(" ")
		line = tip:AddHeader(header)
		tip:SetCell(line, 2, "Amount", colspan)
		for _, name in pairs(t) do
			line = tip:AddLine()
			tip:SetCell(line, 1, name, self.yellowfont)
			tip:SetCell(line, 2, self:FormatMoney(wealthlist[name]), colspan)
			total = total + wealthlist[name]
		end
	elseif ignoreplayer then
		total = wealthlist[self.playername]
	end

	return total
end

function BMF:Today()
	return floor((time() / 3600 + serveroffset()) / 24)
end

function BMF.OnLDBEnter(frame)
	BMF.tip = LibQTip:Acquire("BrokerMoneyFuTip")
	BMF.tip:SmartAnchorTo(frame)
	BMF.tip:SetHeaderFont(GameTooltipText)

	BMF:UpdateTooltip()
	BMF.tip:Show()
end

function BMF.OnLDBLeave(frame)
	LibQTip:Release(BMF.tip)
	BMF.tip = nil
end

function BMF.OnLDBClick(frame, button)
	if button == "RightButton" then
		BMF.OnLDBLeave(frame)
		BMF:ShowMenu(frame)
	end
end
