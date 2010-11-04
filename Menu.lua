local BMF = BrokerMoneyFu

function BMF:CreateMenu()
	local menu = CreateFrame("Frame", "BrokerMoneyFu_Menu")
	menu.displayMode = "MENU"
	menu.initialize = self.InitializeMenu

	self.menu = menu
end

function BMF:ShowMenu(anchor)
	self.menu.scale = UIParent:GetScale()
	ToggleDropDownMenu(1, nil, self.menu, anchor, 0, 0)
end

local info = {}
function BMF.InitializeMenu(frame, level)
	wipe(info)

	if level == 1 then
		info.isTitle = 1
		info.notCheckable = 1
		info.text = "Broker: MoneyFu"
		UIDropDownMenu_AddButton(info, level)

		info.disabled = 1
		info.text = nil
		info.notCheckable = 1
		UIDropDownMenu_AddButton(info, level)

		wipe(info)
		info.isNotRadio = true
		info.func = BMF.MenuSetProfile
		info.arg1 = "perchar"
		info.checked = BMF.db.profile.perchar
		info.keepShownOnClick = 1
		info.text = "Show character-specific cashflow"
		UIDropDownMenu_AddButton(info, level)

		info.checked = BMF.db.profile.allrealms
		info.arg1 = "allrealms"
		info.text = "Show cashflow across all realms"
		UIDropDownMenu_AddButton(info, level)

		info.checked = BMF.db.profile.crossfaction
		info.arg1 = "crossfaction"
		info.text = "Show both factions"
		UIDropDownMenu_AddButton(info, level)

		wipe(info)
		info.isNotRadio = true
		info.notCheckable = 1
		info.disabled = 1
		UIDropDownMenu_AddButton(info, level)

		info.disabled = nil
		info.func = BMF.MenuResetSession
		info.text = "Reset Session"
		UIDropDownMenu_AddButton(info, level)

		info.func = nil
		info.text = "Settings..."
		UIDropDownMenu_AddButton(info, level)

		info.func = BMF.HideMenu
		info.text = "Close"
		UIDropDownMenu_AddButton(info, level)
	end
end

function BMF.HideMenu()
	CloseDropDownMenus()
end

function BMF.MenuSetProfile(frame, pname, _, checked)
	BMF.db.profile[pname] = checked
	BMF:UpdateText()
	BMF:UpdateTooltip()
end

function BMF.MenuResetSession()
	BMF:ResetSession()
end
