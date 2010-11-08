local Scrooge = Scrooge
local ACR = LibStub("AceConfigRegistry-3.0")
local ACD = LibStub("AceConfigDialog-3.0")
if not ACR and ACD then return end

local function profileget(info)
	return Scrooge.db.profile[info.arg]
end

local function profileset(info, value)
	Scrooge:SetProfile(info.arg, value)
end

local function cashflowget(info, key)
	return Scrooge.db.profile[key]
end

local function cashflowset(info, key, value)
	Scrooge:SetProfile(key, value)
end

local function deletechar(info)
	Scrooge:DeleteCharacter(info.arg.realm, info.arg.faction, info.arg.char)
end

local function deleteguild(info)
	Scrooge:DeleteGuild(info.arg.realm, info.arg.faction, info.arg.guild)
end

local function addguild(info, value)
	Scrooge:AddGuild(value)
end

local styles = {
	condensed = "Condensed",
	full = "Full",
	smart = "Smart",
	short = "Short",
	shortint = "Short (whole numbers)",
}

local options = {
    global = {
	type = "group",
	order = 10,
	name = "Scrooge",
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
	    ldbcoins = {
		type = "toggle",
		name = "Show Coins",
		desc = "Show graphical coins instead of text.",
		arg = "ldbcoins",
		order = 15,
	    },
	    linebreak = {
		type = "description",
		name = "",
		order = 17,
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
	    tipcoins = {
		type = "toggle",
		name = "Show Coins",
		desc = "Show graphical coins instead of text.",
		arg = "tipcoins",
		order = 25,
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
	    cashflow = {
		type = "select",
		name = "Show cashflow:",
		desc = "Select which set of cashflow statistics to show on the tooltip.",
		arg = "cashflow",
		values = {
		    character = "Per-character",
		    realm = "Per-realm",
		    all = "Across all realms",
		},
		order = 60,
	    },
	    cashflowhist = {
		type = "multiselect",
		name = "Show cashflow history:",
		desc = "Select which cashflow statistics to show on the tooltip.",
		values = {
		    today = "Today",
		    yesterday = "Yesterday",
		    last7 = "Last 7 Days",
		    last30 = "Last 30 Days",
		},
		get = cashflowget,
		set = cashflowset,
		order = 70,
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
	local ndays = Scrooge:Today() - data.day
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
			name = format("Money: %s", Scrooge:FormatMoney(data.money)),
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
			disabled = realm == Scrooge.realmkey and faction == Scrooge.factionkey and name == Scrooge.playername,
			order = 40,
		},
	}
end

local function guildcb(realm, faction, name, data)
	return {
		money = {
			type = "description",
			name = format("Guild Bank: %s", Scrooge:FormatMoney(data.money)),
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

	c.current = poprealm(Scrooge.realmkey, Scrooge.factionkey, Scrooge.realmdb.chars, charcb)
	for rname, rdata in pairs(Scrooge.data) do
		for fname, fdata in pairs(rdata) do
			if not (rname == Scrooge.realmkey and fname == Scrooge.factionkey) and next(fdata.chars) then
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
		name = "Entering a guild name below will cause Scrooge to consider it to be a 'personal guild'. It will add the guild bank balance when calculating your total wealth, and also include bank deposits and withdrawls in your cashflow summary. This feature should only be used on guilds that you control completely and have exclusive access to the bank.",
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

	if next(Scrooge.realmdb.guilds) then
		c.current = poprealm(Scrooge.realmkey, Scrooge.factionkey, Scrooge.realmdb.guilds, guildcb)
	end
	for rname, rdata in pairs(Scrooge.data) do
		for fname, fdata in pairs(rdata) do
			if not (rname == Scrooge.realmkey and fname == Scrooge.factionkey) and next(fdata.guilds) then
				c[rname.." - "..fname] = poprealm(rname, fname, fdata.guilds, guildcb)
			end
		end
	end

	return options.guilds
end

function Scrooge:SetupConfig()
	ACR:RegisterOptionsTable("Scrooge", options.global)
	self.optref = ACD:AddToBlizOptions("Scrooge", "Scrooge")
	ACR:RegisterOptionsTable("Scrooge - Characters", mkcharoptions)
	ACD:AddToBlizOptions("Scrooge - Characters", "Characters", "Scrooge")
	ACR:RegisterOptionsTable("Scrooge - Guilds", mkguildoptions)
	ACD:AddToBlizOptions("Scrooge - Guilds", "Guilds", "Scrooge")
end
