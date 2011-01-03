local private = select(2, ...)
local Scrooge = Scrooge
local ACR = LibStub("AceConfigRegistry-3.0")
local ACD = LibStub("AceConfigDialog-3.0")
if not ACR and ACD then return end

local L = LibStub:GetLibrary("AceLocale-3.0"):GetLocale(private.addonname)

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

local function altprofileget(info)
	return Scrooge.db.profile.alt[info.arg]
end

local function altprofileset(info, value)
	Scrooge:SetProfile(info.arg, value, true)
end

local function altcashflowget(info, key)
	return Scrooge.db.profile.alt[key]
end

local function altcashflowset(info, key, value)
	Scrooge:SetProfile(key, value, true)
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
	condensed = L["Condensed"],
	full = L["Full"],
	smart = L["Smart"],
	short = L["Short"],
	shortint = L["Short (whole numbers)"],
}

local options = {
    global = {
	type = "group",
	order = 10,
	name = L["Scrooge"],
	get = profileget,
	set = profileset,
	args = {
	    ldbstyle = {
		type = "select",
		name = L["Broker Money Style"],
		desc = L["Style to display the data broker text."],
		arg = "ldbstyle",
		values = styles,
		style = "dropdown",
		order = 10,
	    },
	    ldbcoins = {
		type = "toggle",
		name = L["Show coins"],
		desc = L["Show graphical coins instead of text."],
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
		name = L["Tooltip Money Style"],
		desc = L["Style to display money on the tooltip."],
		arg = "tipstyle",
		values = styles,
		style = "dropdown",
		order = 20,
	    },
	    tipcoins = {
		type = "toggle",
		name = L["Show coins"],
		desc = L["Show graphical coins instead of text."],
		arg = "tipcoins",
		order = 25,
	    },
	    sep1 = {
		type = "header",
		order = 30,
		name = "",
	    },
	    charlist = {
		type = "toggle",
		name = L["Show characters"],
		desc = L["Show a list of all your characters on the current realm and how much money they have on the tooltip."],
		arg = "charlist",
		order = 40,
	    },
	    guildlist = {
		type = "toggle",
		name = L["Show guilds"],
		desc = L["Show a list of all your defined personal guilds on the current realm and how much money is in the guild bank on the tooltip."],
		arg = "guildlist",
		order = 50,
	    },
	    hideplayer = {
		type = "toggle",
		name = L["Hide player"],
		desc = L["Don't display the current player in the character list, show only alts. The current player is included in the total regardless."],
		arg = "hideplayer",
		order = 60,
	    },
	    classcolor = {
		type = "toggle",
		name = L["Class colors"],
		desc = L["Colorize character names on the tooltip with the standard class colors."],
		arg = "classcolor",
		order = 70,
	    },
	    crossfaction = {
		type = "toggle",
		name = L["Cross-faction data"],
		desc = L["Include characters from the opposing faction in both the character list and the statistics totals."],
		arg = "crossfaction",
		order = 80,
	    },
	    perhour = {
		type = "toggle",
		name = L["Per-hour cashflow"],
		desc = L["Show an extra column in the tooltip with the hourly cashflow based on time played."],
		arg = "perhour",
		order = 90,
	    },
	    simple = {
		type = "toggle",
		name = L["Simple totals"],
		desc = L["Show only net profit/loss on the tooltip, don't show separate lines for amount gained and spent."],
		arg = "simple",
		width = "full",
		order = 95,
	    },
	    cashflow = {
		type = "select",
		name = L["Show cashflow:"],
		desc = L["Select which set of cashflow statistics to show on the tooltip."],
		arg = "cashflow",
		values = {
		    character = L["Per-character"],
		    realm = L["Per-realm"],
		    all = L["Across all realms"],
		},
		order = 100,
	    },
	    cashflowhist = {
		type = "multiselect",
		name = L["Show cashflow history:"],
		desc = L["Select which cashflow statistics to show on the tooltip."],
		values = {
		    today = L["Today"],
		    yesterday = L["Yesterday"],
		    last7 = L["Last 7 Days"],
		    last30 = L["Last 30 Days"],
		},
		get = cashflowget,
		set = cashflowset,
		order = 110,
	    },
	},
    },
    alt = {
	type = "group",
	name = L["Alternate Tooltip"],
	desc = L["Set options for an alternate tooltip display to show when holding a modifier key."],
	order = 20,
	get = altprofileget,
	set = altprofileset,
	args = {},
    },
    chars = {
	type = "group",
	name = L["Characters"],
	desc = L["View or remove characters from the database."],
	order = 30,
	args = {},
    },
    guilds = {
	type = "group",
	name = L["Guilds"],
	desc = L["Add or remove guilds from the database."],
	order = 40,
	args = {},
    },
}

local function altdisabled()
	return Scrooge.db.profile.alt.modifier == "none"
end

local function mkaltoptions()
	wipe(options.alt.args)
	for k, v in pairs(options.global.args) do
		options.alt.args[k] = {}
		for k2, v2 in pairs(v) do
			options.alt.args[k][k2] = v2
		end
		options.alt.args[k].disabled = altdisabled
	end
	options.alt.args.ldbstyle = nil
	options.alt.args.ldbcoins = nil
	options.alt.args.cashflowhist.get = altcashflowget
	options.alt.args.cashflowhist.set = altcashflowset

	options.alt.args.modifier = {
	    type = "select",
	    name = L["Modifier key:"],
	    desc = L["Select a modifier key that, when held down, will show the alternate tooltip view."],
	    arg = "modifier",
	    values = {
		none = L["None"],
		alt = L["Alt"],
		ctrl = L["Ctrl"],
		shift = L["Shift"],
	    },
	    order = 10,
	}
end

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
		lastonline = L["Today"]
	elseif ndays == 1 then
		lastonline = L["Yesterday"]
	else
		lastonline = format(L["%d days ago"], ndays)
	end

	local ret = {
		money = {
			type = "description",
			name = format(L["Money: %s"], Scrooge:FormatMoney(data.money)),
			order = 10,
		},
		lastseen = {
			type = "description",
			name = format(L["Last online: %s"], lastonline),
			order = 20,
		},
		spacer = {
			type = "description",
			name = " ",
			order = 30,
		},
		delete = {
			type = "execute",
			name = DELETE,
			desc = L["Delete this character from the database, wiping out all cashflow statistics."],
			func = deletechar,
			arg = {
				realm = realm,
				faction = faction,
				char = name,
			},
			confirm = true,
			confirmText = format(L["Are you sure you wish to delete %s? All saved cashflow statistics will be purged from the database."], name),
			disabled = realm == Scrooge.realmkey and faction == Scrooge.factionkey and name == Scrooge.playername,
			order = 40,
		},
	}

	if data.level and data.class then
		local cc = RAID_CLASS_COLORS[data.class]
		ret.charinfo = {
			type = "description",
			name = format(PLAYER_LEVEL_NO_SPEC, data.level, format("ff%.2x%.2x%.2x", cc.r * 255, cc.g * 255, cc.b * 255), data.localclass),
			order = 5,
		}
	end

	return ret
end

local function guildcb(realm, faction, name, data)
	return {
		money = {
			type = "description",
			name = format(L["Guild Bank: %s"], Scrooge:FormatMoney(data.money)),
			order = 10,
		},
		spacer = {
			type = "description",
			name = " ",
			order = 20,
		},
		delete = {
			type = "execute",
			name = DELETE,
			desc = L["Delete this guild from the database, preventing it from being tracked as a personal guild."],
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

	lastorder = 10

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

	c.helptext = {
		type = "description",
		name = L["GUILD_HELP_TEXT"],
		order = 10,
	}
	c.addguild = {
		type = "input",
		name = L["Add Personal Guild"],
		width = "full",
		get = false,
		set = addguild,
		order = 20,
	}

	lastorder = 30

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
	self.optref = ACD:AddToBlizOptions("Scrooge", L["Scrooge"])
	mkaltoptions()
	ACR:RegisterOptionsTable("Scrooge - Alternate Tooltip", options.alt)
	ACD:AddToBlizOptions("Scrooge - Alternate Tooltip", L["Alternate Tooltip"], L["Scrooge"])
	ACR:RegisterOptionsTable("Scrooge - Characters", mkcharoptions)
	ACD:AddToBlizOptions("Scrooge - Characters", L["Characters"], L["Scrooge"])
	ACR:RegisterOptionsTable("Scrooge - Guilds", mkguildoptions)
	ACD:AddToBlizOptions("Scrooge - Guilds", L["Guilds"], L["Scrooge"])
end
