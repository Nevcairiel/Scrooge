local private = select(2, ...)
local Scrooge = Scrooge

local L = LibStub:GetLibrary("AceLocale-3.0"):GetLocale(private.addonname)

function Scrooge:CreateMenu()
	local menu = CreateFrame("Frame", "Scrooge_Menu")
	menu.displayMode = "MENU"
	menu.initialize = self.InitializeMenu

	self.menu = menu
end

function Scrooge:ShowMenu(anchor)
	self.menu.scale = UIParent:GetScale()
	ToggleDropDownMenu(1, nil, self.menu, anchor, 0, 0)
end

local info = {}
function Scrooge.InitializeMenu(frame, level)
	wipe(info)

	if level == 1 then
		info.isTitle = 1
		info.notCheckable = 1
		info.text = L["Scrooge"]
		UIDropDownMenu_AddButton(info, level)

		info.disabled = 1
		info.text = nil
		info.notCheckable = 1
		UIDropDownMenu_AddButton(info, level)

		wipe(info)
		info.func = Scrooge.MenuToggleProfile
		info.isNotRadio = true
		info.checked = Scrooge.db.profile.crossfaction
		info.arg1 = "crossfaction"
		info.text = L["Show both factions"]
		UIDropDownMenu_AddButton(info, level)

		wipe(info)
		info.func = Scrooge.MenuSetCashflow
		info.arg1 = "all"
		info.checked = Scrooge.db.profile.cashflow == "all"
		info.text = format("%s %s", L["Show cashflow:"], L["Across all realms"])
		UIDropDownMenu_AddButton(info, level)

		info.arg1 = "character"
		info.checked = Scrooge.db.profile.cashflow == "character"
		info.text = format("%s %s", L["Show cashflow:"], L["Per-character"])
		UIDropDownMenu_AddButton(info, level)

		info.arg1 = "realm"
		info.checked = Scrooge.db.profile.cashflow == "realm"
		info.text = format("%s %s", L["Show cashflow:"], L["Per-realm"])
		UIDropDownMenu_AddButton(info, level)

		wipe(info)
		info.notCheckable = 1
		info.disabled = 1
		UIDropDownMenu_AddButton(info, level)

		info.disabled = nil
		info.func = Scrooge.MenuResetSession
		info.text = L["Reset Session"]
		UIDropDownMenu_AddButton(info, level)

		info.func = Scrooge.MenuSettings
		info.text = L["Settings..."]
		UIDropDownMenu_AddButton(info, level)

		info.func = Scrooge.HideMenu
		info.text = CLOSE
		UIDropDownMenu_AddButton(info, level)
	end
end

function Scrooge.HideMenu()
	CloseDropDownMenus()
end

function Scrooge.MenuSetCashflow(frame, cname)
	Scrooge:SetProfile("cashflow", cname)
end

function Scrooge.MenuToggleProfile(frame, pname)
	Scrooge:SetProfile(pname, not Scrooge.db.profile[pname])
end

function Scrooge.MenuResetSession()
	Scrooge:ResetSession()
end

function Scrooge.MenuSettings()
	InterfaceOptionsFrame_OpenToCategory(Scrooge.optref)
end
