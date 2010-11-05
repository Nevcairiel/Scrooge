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

local function deletechar(info)
	BMF:DeleteCharacter(info.arg.realm, info.arg.faction, info.arg.char)
end

local function deleteguild(info)
	BMF:DeleteGuild(info.arg.realm, info.arg.faction, info.arg.guild)
end

local function addguild(info, value)
	BMF:AddGuild(value)
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

local lastorder = 0
local function poprealm(realm, faction, data, callback)
	local ret = {}

	ret.type = "group"
	ret.name = realm .. " - " .. faction
	ret.order = lastorder
	ret.args = {}

	local corder = 10
	for k, v in pairs(data) do
		ret.args[k] = {
			type = "group",
			name = k,
			order = corder,
			args = callback(realm, faction, k, v)
		}
		corder = corder + 10
	end

	lastorder = lastorder + 10
	return ret
end

local function charcb(realm, faction, name, data)
	local ndays = BMF:Today() - data.day
	local lastonline
	if ndays < 1 then
		lastonline = "Today"
	elseif ndays == 1 then
		lastonline = "Yesterday"
	else
		lastonline = format("%d days ago", ndays)
	end

	return {
		money = {
			type = "description",
			name = format("Money: %s", BMF:FormatMoney(BMF.db.profile.tipstyle, data.money)),
			order = 10,
		},
		lastseen = {
			type = "description",
			name = format("Last online: %s", lastonline),
			order = 20,
		},
		spacer = {
			type = "description",
			name = " ",
			order = 30,
		},
		delete = {
			type = "execute",
			name = "Delete",
			desc = "Delete this character from the database, wiping out all cashflow statistics.",
			func = deletechar,
			arg = {
				realm = realm,
				faction = faction,
				char = name,
			},
			confirm = true,
			confirmText = format("Are you sure you wish to delete %s? All saved cashflow statistics will be purged from the database.", name),
			disabled = realm == BMF.realmkey and faction == BMF.factionkey and name == BMF.playername,
			order = 40,
		},
	}
end

local function guildcb(realm, faction, name, data)
	return {
		money = {
			type = "description",
			name = format("Guild Bank: %s", BMF:FormatMoney(BMF.db.profile.tipstyle, data.money)),
			order = 10,
		},
		spacer = {
			type = "description",
			name = " ",
			order = 20,
		},
		delete = {
			type = "execute",
			name = "Delete",
			desc = "Delete this guild from the database, preventing it from being tracked as a personal guild.",
			func = deleteguild,
			arg = {
				realm = realm,
				faction = faction,
				guild = name,
			},
			order = 30,
		},
	}
end

local function mkcharoptions()
	wipe(options.chars.args)
	local c = options.chars.args

	c.charlist = {
		type = "toggle",
		name = "Show character list on tooltip",
		desc = "Show a list of all your characters on the current realm and how much money they have on the tooltip.",
		get = profileget,
		set = profileset,
		arg = "charlist",
		width = "full",
		order = 10,
	}

	lastorder = 20

	c.current = poprealm(BMF.realmkey, BMF.factionkey, BMF.realmdb.chars, charcb)
	for rname, rdata in pairs(BMF.data) do
		for fname, fdata in pairs(rdata) do
			if not (rname == BMF.realmkey and fname == BMF.factionkey) and next(fdata.chars) then
				c[rname.." - "..fname] = poprealm(rname, fname, fdata.chars, charcb)
			end
		end
	end

	return options.chars
end

local function mkguildoptions()
	wipe(options.guilds.args)
	local c = options.guilds.args

	c.guildlist = {
		type = "toggle",
		name = "Show guild list on tooltip",
		desc = "Show a list of all your defined personal guilds on the current realm and how much money is in the guild bank on the tooltip.",
		get = profileget,
		set = profileset,
		arg = "guildlist",
		width = "full",
		order = 10,
	}
	c.spacer = {
		type = "description",
		name = " ",
		order = 20,
	}
	c.helptext = {
		type = "description",
		name = "Entering a guild name below will cause MoneyFu to consider it to be a 'personal guild'. It will add the guild bank balance when calculating your total wealth, and also include bank deposits and withdrawls in your cashflow summary. This feature should only be used on guilds that you control completely and have exclusive access to the bank.",
		order = 30,
	}
	c.addguild = {
		type = "input",
		name = "Add Personal Guild",
		width = "double",
		get = false,
		set = addguild,
		order = 40,
	}

	lastorder = 50

	if next(BMF.realmdb.guilds) then
		c.current = poprealm(BMF.realmkey, BMF.factionkey, BMF.realmdb.guilds, guildcb)
	end
	for rname, rdata in pairs(BMF.data) do
		for fname, fdata in pairs(rdata) do
			if not (rname == BMF.realmkey and fname == BMF.factionkey) and next(fdata.guilds) then
				c[rname.." - "..fname] = poprealm(rname, fname, fdata.guilds, guildcb)
			end
		end
	end

	return options.guilds
end

function BMF:SetupConfig()
	ACR:RegisterOptionsTable("Broker: MoneyFu", options.global)
	self.optref = ACD:AddToBlizOptions("Broker: MoneyFu", "Broker: MoneyFu")
	ACR:RegisterOptionsTable("Broker: MoneyFu - Characters", mkcharoptions)
	ACD:AddToBlizOptions("Broker: MoneyFu - Characters", "Characters", "Broker: MoneyFu")
	ACR:RegisterOptionsTable("Broker: MoneyFu - Guilds", mkguildoptions)
	ACD:AddToBlizOptions("Broker: MoneyFu - Guilds", "Guilds", "Broker: MoneyFu")
end
