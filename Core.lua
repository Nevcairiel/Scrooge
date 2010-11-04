local l = select(2, ...)
local addonname = "Broker_MoneyFu"
BrokerMoneyFu = LibStub("AceAddon-3.0"):NewAddon(addonname, "AceEvent-3.0")
local BMF = BrokerMoneyFu

local LDB = LibStub('LibDataBroker-1.1')
if not LDB then return end

--local L = LibStub:GetLibrary("AceLocale-3.0"):GetLocale(addonname)

local historysize = 29

function l.mkdata(tbl)
	tbl.spent = {}
	tbl.gained = {}
	tbl.time = {}
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
	self.realmkey = GetRealmName()
	self.factionkey = UnitFactionGroup("player")
	self.otherfaction = (self.factionkey == "Alliance") and "Horde" or "Alliance"

	self.db.global[self.realmkey] = self.db.global[self.realmkey] or {}
	if not self.db.global[self.realmkey][self.factionkey] then
		self.db.global[self.realmkey][self.factionkey] = {
			guilds = {},
			chars = {},
		}
		l.mkdata(self.db.global[self.realmkey][self.factionkey])
	end

	self.realmdb = self.db.global[self.realmkey][self.factionkey]

	if not self.realmdb.chars[self.playername] then
		self.realmdb.chars[self.playername] = {}
		l.mkdata(self.realmdb.chars[self.playername])
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

function BMF:Today()
	return floor((time() / 3600 + serveroffset()) / 24)
end

function BMF.OnLDBClick(frame, button)
	if button == "RightButton" then
		BMF.OnLDBLeave(frame)
		BMF:ShowMenu(frame)
	end
end
