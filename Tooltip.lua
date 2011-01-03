local private = select(2, ...)
local Scrooge = Scrooge

local LibQTip = LibStub("LibQTip-1.0")
if not LibQTip then return end

local L = LibStub:GetLibrary("AceLocale-3.0"):GetLocale(private.addonname)

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
	return wealthlist[a].money < wealthlist[b].money
end

function Scrooge:UpdateTooltip()
	if not self.tipanchor then return end

	local pref = self.db.profile
	if (self.db.profile.alt.modifier == "alt" and IsAltKeyDown()) or
	   (self.db.profile.alt.modifier == "ctrl" and IsControlKeyDown()) or
	   (self.db.profile.alt.modifier == "shift" and IsShiftKeyDown()) then
		pref = self.db.profile.alt
	end

	if self.tip then
		LibQTip:Release(self.tip)
	end
	self.tip = LibQTip:Acquire("ScroogeTip")
	local tip = self.tip
	local hourly = pref.perhour
	local today = self:Today()

	tip:SmartAnchorTo(self.tipanchor)
	tip:SetHeaderFont(GameTooltipText)

	tip:Clear()
	tip:SetCellMarginH(20)
	tip:SetColumnLayout(hourly and 3 or 2, "LEFT", "RIGHT", "RIGHT")

	tip:AddHeader(L["This Session"], L["Amount"], hourly and L["Per Hour"] or nil)
	self:AddMoneyLines(pref, self.session)

	local data
	if pref.cashflow == "character" then
		data = self.chardb
	else
		data = {}
		private.mkdata(data)
		local rkeys = {}
		if pref.cashflow == "all" then
			for k, _ in pairs(self.data) do
				table.insert(rkeys, k)
			end
		elseif pref.cashflow == "realm" then
			table.insert(rkeys, self.realmkey)
		end

		local fkeys = { self.factionkey }
		if pref.crossfaction then
			table.insert(fkeys, self.otherfaction)
		end

		for _, realm in ipairs(rkeys) do
			for _, faction in ipairs(fkeys) do
				local frdata = self.data[realm] and self.data[realm][faction]
				accumulate(data, frdata)
			end
		end
	end

	if pref.today then
		tip:AddLine(" ")
		tip:AddHeader(L["Today"], L["Amount"], hourly and L["Per Hour"] or nil)
		self:AddMoneyLines(pref, data, today)
	end

	if pref.yesterday then
		tip:AddLine(" ")
		tip:AddHeader(L["Yesterday"], L["Amount"], hourly and L["Per Hour"] or nil)
		self:AddMoneyLines(pref, data, today - 1)
	end

	local cdata
	if pref.last7 then
		cdata = consolidate(data, today - 6, today)
		tip:AddLine(" ")
		tip:AddHeader(L["Last 7 Days"],  L["Amount"], hourly and L["Per Hour"] or nil)
		self:AddMoneyLines(pref, cdata)
	end

	if pref.last30 then
		cdata = consolidate(data, today - 29, today)
		tip:AddLine(" ")
		tip:AddHeader(L["Last 30 Days"],  L["Amount"], hourly and L["Per Hour"] or nil)
		self:AddMoneyLines(pref, cdata)
	end

	local total = 0
	if pref.charlist then
		total = total + self:AddWealthList(pref, "chars", L["Characters"], pref.hideplayer)
	end
	if pref.guildlist then
		total = total + self:AddWealthList(pref, "guilds", L["Guilds"])
	end

	if pref.charlist or pref.guildlist then
		tip:AddLine(" ")
		local line = tip:AddLine(L["Total"])
		tip:SetCell(line, 2, self:FormatMoneyTip(pref, total), hourly and 2 or 1)
	
	end
	tip:Show()
end

function Scrooge:AddMoneyLines(pref, tbl, when)
	local hourly = pref.perhour
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
	if not pref.simple then
		line = tip:AddLine(nil, self:FormatMoneyTip(pref, gained),
			hourly and self:FormatMoneyTip(pref, gained / time) or nil)
		tip:SetCell(line, 1, L["Gained"], self.yellowfont)
		line = tip:AddLine(nil, self:FormatMoneyTip(pref, spent),
			hourly and self:FormatMoneyTip(pref, spent / time) or nil)
		tip:SetCell(line, 1, L["Spent"], self.yellowfont)
	end
	local profit = gained - spent
	line = tip:AddLine(nil, self:FormatMoneyTip(pref, profit, true),
		hourly and self:FormatMoneyTip(pref, profit / time, true) or nil)
	tip:SetCell(line, 1, profit >= 0 and L["Profit"] or L["Loss"], self.yellowfont)
end

function Scrooge:AddWealthList(pref, tblname, header, ignoreplayer)
	local tip = self.tip
	local colspan = pref.perhour and 2 or 1
	local total = ignoreplayer and GetMoney() or 0
	local line

	wipe(wealthlist)
	for k, v in pairs(self.realmdb[tblname]) do
		if not ignoreplayer or k ~= self.playername then
			wealthlist[k] = v
		end
	end
	if pref.crossfaction and self.data[self.realmkey][self.otherfaction] then
		for k, v in pairs(self.data[self.realmkey][self.otherfaction][tblname]) do
			wealthlist[k] = v
		end
	end
	if next(wealthlist) then
		local t = {}
		for name in pairs(wealthlist) do
			table.insert(t, name)
		end
		table.sort(t, wealthsort)
		tip:AddLine(" ")
		line = tip:AddHeader(header)
		tip:SetCell(line, 2, L["Amount"], colspan)
		for _, name in pairs(t) do
			local w = wealthlist[name]
			line = tip:AddLine()
			if pref.classcolor and w.class then
				local cc = RAID_CLASS_COLORS[w.class]
				tip:SetCell(line, 1, format("|c%s%s|r", format("ff%.2x%.2x%.2x", cc.r * 255, cc.g * 255, cc.b * 255), name))
			else
				tip:SetCell(line, 1, name, self.yellowfont)
			end
			tip:SetCell(line, 2, self:FormatMoneyTip(pref, w.money), colspan)
			total = total + w.money
		end
	end

	return total
end

function Scrooge.OnLDBEnter(frame)
	Scrooge.tipanchor = frame
	Scrooge:UpdateTooltip()
end

function Scrooge.OnLDBLeave(frame)
	LibQTip:Release(Scrooge.tip)
	Scrooge.tip = nil
	Scrooge.tipanchor = nil
end
