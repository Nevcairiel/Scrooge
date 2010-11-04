local l = select(2, ...)
local BMF = BrokerMoneyFu

local LibQTip = LibStub("LibQTip-1.0")
if not LibQTip then return end

--local L = LibStub:GetLibrary("AceLocale-3.0"):GetLocale(addonname)

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
		l.mkdata(data)
		local rkeys
		if self.db.profile.allrealms then
			rkeys = {}
			for k, _ in pairs(self.db.global) do
				table.insert(rkeys, k)
			end
		else
			rkeys = { self.realmkey }
		end

		local fkeys = { self.factionkey }
		if self.db.profile.crossfaction then
			table.insert(fkeys, self.otherfaction)
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

function BMF:AddWealthList(tblname, header, ignoreplayer)
	local tip = self.tip
	local colspan = self.db.profile.perhour and 2 or 1
	local total = 0
	local line

	wipe(wealthlist)
	for k, v in pairs(self.realmdb[tblname]) do
		wealthlist[k] = v.money
	end
	if self.db.profile.crossfaction and self.db.global[self.realmkey][self.otherfaction] then
		for k, v in pairs(self.db.global[self.realmkey][self.otherfaction][tblname]) do
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