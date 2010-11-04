BrokerMoneyFu = LibStub("AceAddon-3.0"):NewAddon("Broker_MoneyFu", "AceEvent-3.0")
local BMF = BrokerMoneyFu

local LibQTip = LibStub("LibQTip-1.0")
local LDB = LibStub('LibDataBroker-1.1')
if not LDB or not LibQTip then return end

--local L = LibStub:GetLibrary("AceLocale-3.0"):GetLocale("Broker_MoneyFu")

local realmkey = GetRealmName()
local factionkey = UnitFactionGroup("player")
local otherfaction = (factionkey == "Alliance") and "Horde" or factionKey

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
	local cutoff = BMF:Today() - 6
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
		if BMF:Today() - when > 6 then return end
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
			perhour = false,
			crossfaction = false,
			allrealms = false,
		},
		char = {},
	}
	mkdata(defaults.char)

	self.db = LibStub("AceDB-3.0"):New("BrokerMoneyFuDB", defaults, true)
	self.ldb = LDB:NewDataObject("Broker_MoneyFu", {
		type = "data source",
		icon = "Interface\\Minimap\\Tracking\\Auctioneer",
		label = "MoneyFu",
		text = "MoneyFu",
		OnEnter = self.OnLDBEnter,
		OnLeave = self.OnLDBLeave,
	})
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

	if not self.db.char.last then
		self.db.char.last = {
			money = GetMoney(),
			day = self:Today()
		}
	end
	self.last = self.db.char.last

	purgemoney(self.db.char)
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
		today = self.last.day
	elseif today > self.last.day then
		clearmoney(self.db.char, today - 7)
		clearmoney(self.realmdb, today - 7)
		self.last.day = today
	end

	if money ~= self.last.money then
		local amount = money - self.last.money
		local elapsed = now - lastupdate
		if not initial then
			storemoney(self.session, amount, elapsed)
		end
		storemoney(self.db.char, amount, elapsed, today)
		storemoney(self.realmdb, amount, elapsed, today)
		self.last.money = money
	end

	self.realmdb.chars[self.playername] = money
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
	self.realmdb.guilds[guildname] = money

	self:CheckMoney()
end

function BMF:UpdateText()
	local money = GetMoney()

	if self.db.profile.style == "graphical" then
		self.ldb.text = GetCoinTextureString(money, 0)
	end
end

function BMF:UpdateTooltip()
	local tip = BMF.tip
	if not tip then return end
end

function BMF:Today()
	return floor((time() / 3600 + serveroffset()) / 24)
end

function BMF.OnLDBEnter(self)
	BMF.tip = LibQTip:Acquire("BrokerMoneyFuTip", 3, "LEFT", "LEFT", "LEFT")
	BMF.tip:SmartAnchorTo(self)
	BMF:UpdateTooltip()
	BMF.tip:Show()
end

function BMF.OnLDBLeave(self)
	LibQTip:Release(BMF.tip)
	BMF.tip = nil
end
