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
		info.func = BMF.MenuToggleProfile
		info.isNotRadio = true
		info.checked = BMF.db.profile.crossfaction
		info.arg1 = "crossfaction"
		info.text = "Show both factions"
		UIDropDownMenu_AddButton(info, level)

		wipe(info)
		info.func = BMF.MenuSetCashflow
		info.arg1 = "all"
		info.checked = BMF.db.profile.cashflow == "all"
		info.text = format("%s %s", "Show cashflow:", "Across all realms")
		UIDropDownMenu_AddButton(info, level)

		info.arg1 = "character"
		info.checked = BMF.db.profile.cashflow == "character"
		info.text = format("%s %s", "Show cashflow:", "Per-character")
		UIDropDownMenu_AddButton(info, level)

		info.arg1 = "realm"
		info.checked = BMF.db.profile.cashflow == "realm"
		info.text = format("%s %s", "Show cashflow:", "Per-realm")
		UIDropDownMenu_AddButton(info, level)

		wipe(info)
		info.notCheckable = 1
		info.disabled = 1
		UIDropDownMenu_AddButton(info, level)

		info.disabled = nil
		info.func = BMF.MenuResetSession
		info.text = "Reset Session"
		UIDropDownMenu_AddButton(info, level)

		info.func = BMF.MenuSettings
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

function BMF.MenuSetCashflow(frame, cname)
	BMF:SetProfile("cashflow", cname)
end

function BMF.MenuToggleProfile(frame, pname)
	BMF:SetProfile(pname, not BMF.db.profile[pname])
end

function BMF.MenuResetSession()
	BMF:ResetSession()
end

function BMF.MenuSettings()
	InterfaceOptionsFrame_OpenToCategory(BMF.optref)
end
