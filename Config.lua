-- vim: set sts=4 sw=4:
local BMF = BrokerMoneyFu
local ACR = LibStub("AceConfigRegistry-3.0")
local ACD = LibStub("AceConfigDialog-3.0")
if not ACR and ACD then return end

local function profileget(info)
	return BMF.db.profile[info.arg]
end

local function profileset(info, value)
	BMF:SetProfile(info.arg, value)
end

local function cashflowget(info, key)
	return BMF.db.profile[key]
end

local function cashflowset(info, key, value)
	BMF:SetProfile(key, value)
end

local styles = {
	condensed = "Condensed",
	full = "Full",
	graphical = "Graphical",
	short = "Short",
}

local options = {
    global = {
	type = "group",
	order = 10,
	name = "Broker: MoneyFu",
	get = profileget,
	set = profileset,
	args = {
	    ldbstyle = {
		type = "select",
		name = "Broker Money Style",
		desc = "Style to display the data broker text.",
		arg = "ldbstyle",
		values = styles,
		style = "dropdown",
		order = 10,
	    },
	    tipstyle = {
		type = "select",
		name = "Tooltip Money Style",
		desc = "Style to display money on the tooltip.",
		arg = "tipstyle",
		values = styles,
		style = "dropdown",
		order = 20,
	    },
	    sep1 = {
		type = "header",
		order = 30,
		name = "",
	    },
	    crossfaction = {
		type = "toggle",
		name = "Show cross-faction data",
		desc = "Include characters from the opposing faction in both the character list and the statistics totals.",
		arg = "crossfaction",
		width = "full",
		order = 40,
	    },
	    perhour = {
		type = "toggle",
		name = "Show per-hour cashflow",
		desc = "Show an extra column in the tooltip with the hourly cashflow based on time played.",
		arg = "perhour",
		width = "full",
		order = 50,
	    },
	    perchar = {
		type = "toggle",
		name = "Show character-specific cashflow",
		desc = "Restrict the cashflow statistics to display only the current character.",
		arg = "perchar",
		width = "full",
		order = 60,
	    },
	    allrealms = {
		type = "toggle",
		name = "Show cashflow across all realms",
		desc = "Include data from all realms in the cashflow statistics rather than only the current realm.",
		arg = "allrealms",
		width = "full",
		order = 70,
	    },
	    cashflow = {
		type = "multiselect",
		name = "Show cashflow for:",
		desc = "Select which cashflow statistics to show on the tooltip.",
		values = {
		    today = "Today",
		    yesterday = "Yesterday",
		    last7 = "Last 7 Days",
		    last30 = "Last 30 Days",
		},
		get = cashflowget,
		set = cashflowset,
		order = 80,
	    },
	},
    },
    chars = {
	type = "group",
	name = "Characters",
	desc = "View or remove characters from the database.",
	order = 20,
	args = {},
    },
    guilds = {
	type = "group",
	name = "Guilds",
	desc = "Add or remove guilds from the database.",
	order = 30,
	args = {},
    },
}

function BMF:SetupConfig()
	ACR:RegisterOptionsTable("Broker: MoneyFu", options.global)
	self.optref = ACD:AddToBlizOptions("Broker: MoneyFu", "Broker: MoneyFu")
	ACR:RegisterOptionsTable("Broker: MoneyFu - Characters", options.chars)
	ACD:AddToBlizOptions("Broker: MoneyFu - Characters", "Characters", "Broker: MoneyFu")
	ACR:RegisterOptionsTable("Broker: MoneyFu - Guilds", options.guilds)
	ACD:AddToBlizOptions("Broker: MoneyFu - Guilds", "Guilds", "Broker: MoneyFu")
end
