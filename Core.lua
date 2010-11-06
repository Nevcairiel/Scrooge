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
			ldbstyle = "smart",
			ldbcoins = true,
			tipstyle = "full",
			tipcoins = true,
			cashflow = "realm",
			perhour = false,
			crossfaction = false,
			today = true,
			yesterday = true,
			last7 = false,
			last30 = false,
			charlist = true,
			guildlist = true,
		},
	}

	self.db = LibStub("AceDB-3.0"):New("BrokerMoneyFuDB", defaults, true)
	if not self.db.global.version then
		self.db.global.version = 1
	end
	self:UpgradeDB()

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
	self:SetupConfig()
end

function BMF:UpgradeDB()
	self.db.profile.perchar = nil
	self.db.profile.allrealms = nil
end

function BMF:ResetSession()
	self.session = {}
end

function BMF:OnEnable()
	self.playername = UnitName("player")
	self.realmkey = GetRealmName()
	self.factionkey = UnitFactionGroup("player")
	self.otherfaction = (self.factionkey == "Alliance") and "Horde" or "Alliance"

	if not self.db.global.data then
		self.db.global.data = {}
	end
	self.data = self.db.global.data

	self.data[self.realmkey] = self.data[self.realmkey] or {}
	if not self.data[self.realmkey][self.factionkey] then
		self.data[self.realmkey][self.factionkey] = {
			guilds = {},
			chars = {},
		}
		l.mkdata(self.data[self.realmkey][self.factionkey])
	end

	self.realmdb = self.data[self.realmkey][self.factionkey]

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
		self.chardb.day = self:Today()
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

	self.ldb.text = self:FormatMoneyLDB(money)
end

local COLOR_GREEN = "|cff00ff00"
local COLOR_RED = "|cffff0000"
local COLOR_COPPER = "|cffeda55f"
local COLOR_SILVER = "|cffc7c7cf"
local COLOR_GOLD = "|cffffd700"
local ICON_COPPER = "|TInterface\\MoneyFrame\\UI-CopperIcon:14:14:2:0|t"
local ICON_SILVER = "|TInterface\\MoneyFrame\\UI-SilverIcon:14:14:2:0|t"
local ICON_GOLD = "|TInterface\\MoneyFrame\\UI-GoldIcon:14:14:2:0|t"
function BMF:FormatMoney(amount, colorize, style, textonly)
	local prefix = (amount < 0) and "-" or ""
	local color = ""
	local coppername = textonly and format("%s%s|r", COLOR_COPPER, COPPER_AMOUNT_SYMBOL) or ICON_COPPER
	local silvername = textonly and format("%s%s|r", COLOR_SILVER, SILVER_AMOUNT_SYMBOL) or ICON_SILVER
	local goldname = textonly and format("%s%s|r", COLOR_GOLD, GOLD_AMOUNT_SYMBOL) or ICON_GOLD
	if colorize and amount ~= 0 then
		color = (amount < 0) and COLOR_RED or COLOR_GREEN
	end

	local value = abs(amount)
	local gold = floor(value / 10000)
	local silver = floor(mod(value / 100, 100))
	local copper = floor(mod(value, 100))

	if not style or style == "smart" then
		local str = format("%s%s", color, prefix)
		if gold > 0 then
			str = format("%s%d%s%s", str, gold, goldname, (silver > 0 or copper > 0) and " " or "")
		end
		if silver > 0 then
			str = format("%s%d%s%s", str, silver, silvername, copper > 0 and " " or "")
		end
		if copper > 0 or value == 0 then
			str = format("%s%d%s", str, copper, coppername)
		end
		return str.."|r"
	end

	if style == "full" then
		if gold > 0 then
			return format("%s%s%d|r%s %s%d|r%s %s%d|r%s", color, prefix, gold, goldname, color, silver, silvername, color, copper, coppername)
		elseif silver > 0 then
			return format("%s%s%d|r%s %s%d|r%s", color, prefix, silver, silvername, color, copper, coppername)
		else
			return format("%s%s%d|r%s", color, prefix, copper, coppername)
		end
	elseif style == "short" then
		if gold > 0 then
			return format("%s%.1f|r%s", color, amount / 10000, goldname)
		elseif silver > 0 then
			return format("%s%.1f|r%s", color, amount / 100, silvername)
		else
			return format("%s%d|r%s", color, amount, coppername)
		end
	elseif style == "shortint" then
		if gold > 0 then
			return format("%s%s%d|r%s", color, prefix, gold, goldname)
		elseif silver > 0 then
			return format("%s%s%d|r%s", color, prefix, silver, silvername)
		else
			return format("%s%s%d|r%s", color, prefix, copper, coppername)
		end
	elseif style == "condensed" then
		local postfix = ""
		if amount < 0 then
			prefix = COLOR_RED.."-(|r"
			postfix = COLOR_RED..")|r"
		end
		if gold > 0 then
			return format("%s%s%d|r.%s%02d|r.%s%02d|r%s", prefix, COLOR_GOLD, gold, COLOR_SILVER, silver, COLOR_COPPER, copper, postfix)
		elseif silver > 0 then
			return format("%s%s%d|r.%s%02d|r%s", prefix, COLOR_SILVER, silver, COLOR_COPPER, copper, postfix)
		else
			return format("%s%s%d|r%s", prefix, COLOR_COPPER, copper, postfix)
		end
	end

	-- Shouldn't be here; punt
	return self:FormatMoney(amount, colorize, "smart")
end

function BMF:FormatMoneyLDB(amount, colorize)
	return self:FormatMoney(amount, colorize, self.db.profile.ldbstyle, not self.db.profile.ldbcoins)
end

function BMF:FormatMoneyTip(amount, colorize)
	return self:FormatMoney(amount, colorize, self.db.profile.tipstyle, not self.db.profile.tipcoins)
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

function BMF:SetProfile(key, value)
	self.db.profile[key] = value

	self:UpdateText()
	self:UpdateTooltip()
end

function BMF:VacuumDB(realm, faction)
	if not self.data[realm] or not self.data[realm][faction] then
		return
	end

	if not next(self.data[realm][faction].chars) and not next(self.data[realm][faction].guilds) then
		self.data[realm][faction] = nil
	end
	if not next(self.data[realm]) then
		self.data[realm] = nil
	end
end

function BMF:AddGuild(name)
	self.realmdb.guilds[name] = {
		money = 0
	}
end

function BMF:DeleteCharacter(realm, faction, name)
	if not self.data[realm] or not self.data[realm][faction] then
		return
	end

	self.data[realm][faction].chars[name] = nil
	self:VacuumDB(realm, faction)
end

function BMF:DeleteGuild(realm, faction, name)
	if not self.data[realm] or not self.data[realm][faction] then
		return
	end

	self.data[realm][faction].guilds[name] = nil
	self:VacuumDB(realm, faction)
end

function BMF.OnLDBClick(frame, button)
	if button == "RightButton" then
		BMF.OnLDBLeave(frame)
		BMF:ShowMenu(frame)
	end
end
