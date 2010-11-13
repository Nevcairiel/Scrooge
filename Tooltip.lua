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
	local tip = self.tip
	local hourly = self.db.profile.perhour
	local today = self:Today()
	if not tip then return end

	tip:Clear()
	tip:SetCellMarginH(20)
	tip:SetColumnLayout(hourly and 3 or 2, "LEFT", "RIGHT", "RIGHT")

	tip:AddHeader(L["This Session"], L["Amount"], hourly and L["Per Hour"] or nil)
	self:AddMoneyLines(self.session)

	local data
	if self.db.profile.cashflow == "character" then
		data = self.chardb
	else
		data = {}
		private.mkdata(data)
		local rkeys = {}
		if self.db.profile.cashflow == "all" then
			for k, _ in pairs(self.data) do
				table.insert(rkeys, k)
			end
		elseif self.db.profile.cashflow == "realm" then
			table.insert(rkeys, self.realmkey)
		end

		local fkeys = { self.factionkey }
		if self.db.profile.crossfaction then
			table.insert(fkeys, self.otherfaction)
		end

		for _, realm in ipairs(rkeys) do
			for _, faction in ipairs(fkeys) do
				local frdata = self.data[realm] and self.data[realm][faction]
				accumulate(data, frdata)
			end
		end
	end

	if self.db.profile.today then
		tip:AddLine(" ")
		tip:AddHeader(L["Today"], L["Amount"], hourly and L["Per Hour"] or nil)
		self:AddMoneyLines(data, today)
	end

	if self.db.profile.yesterday then
		tip:AddLine(" ")
		tip:AddHeader(L["Yesterday"], L["Amount"], hourly and L["Per Hour"] or nil)
		self:AddMoneyLines(data, today - 1)
	end

	local cdata
	if self.db.profile.last7 then
		cdata = consolidate(data, today - 6, today)
		tip:AddLine(" ")
		tip:AddHeader(L["Last 7 Days"],  L["Amount"], hourly and L["Per Hour"] or nil)
		self:AddMoneyLines(cdata)
	end

	if self.db.profile.last30 then
		cdata = consolidate(data, today - 29, today)
		tip:AddLine(" ")
		tip:AddHeader(L["Last 30 Days"],  L["Amount"], hourly and L["Per Hour"] or nil)
		self:AddMoneyLines(cdata)
	end

	local total = 0
	if self.db.profile.charlist then
		total = total + self:AddWealthList("chars", L["Characters"], true)
	end
	if self.db.profile.guildlist then
		total = total + self:AddWealthList("guilds", L["Guilds"])
	end

	if self.db.profile.charlist or self.db.profile.guildlist then
		tip:AddLine(" ")
		local line = tip:AddLine(L["Total"])
		tip:SetCell(line, 2, self:FormatMoneyTip(total), hourly and 2 or 1)
	
	end
end

function Scrooge:AddMoneyLines(tbl, when)
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
	line = tip:AddLine(nil, self:FormatMoneyTip(gained),
		hourly and self:FormatMoneyTip(gained / time) or nil)
	tip:SetCell(line, 1, L["Gained"], self.yellowfont)
	line = tip:AddLine(nil, self:FormatMoneyTip(spent),
		hourly and self:FormatMoneyTip(spent / time) or nil)
	tip:SetCell(line, 1, L["Spent"], self.yellowfont)
	local profit = gained - spent
	line = tip:AddLine(nil, self:FormatMoneyTip(profit, true),
		hourly and self:FormatMoneyTip(profit / time, true) or nil)
	tip:SetCell(line, 1, profit >= 0 and L["Profit"] or L["Loss"], self.yellowfont)
end

function Scrooge:AddWealthList(tblname, header, ignoreplayer)
	local tip = self.tip
	local colspan = self.db.profile.perhour and 2 or 1
	local total = ignoreplayer and GetMoney() or 0
	local line

	wipe(wealthlist)
	for k, v in pairs(self.realmdb[tblname]) do
		if not ignoreplayer or k ~= self.playername then
			wealthlist[k] = v
		end
	end
	if self.db.profile.crossfaction and self.data[self.realmkey][self.otherfaction] then
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
			if self.db.profile.classcolor and w.class then
				local cc = RAID_CLASS_COLORS[w.class]
				tip:SetCell(line, 1, format("|c%s%s|r", format("ff%.2x%.2x%.2x", cc.r * 255, cc.g * 255, cc.b * 255), name))
			else
				tip:SetCell(line, 1, name, self.yellowfont)
			end
			tip:SetCell(line, 2, self:FormatMoneyTip(w.money), colspan)
			total = total + w.money
		end
	end

	return total
end

function Scrooge.OnLDBEnter(frame)
	Scrooge.tip = LibQTip:Acquire("ScroogeTip")
	Scrooge.tip:SmartAnchorTo(frame)
	Scrooge.tip:SetHeaderFont(GameTooltipText)

	Scrooge:UpdateTooltip()
	Scrooge.tip:Show()
end

function Scrooge.OnLDBLeave(frame)
	LibQTip:Release(Scrooge.tip)
	Scrooge.tip = nil
end
