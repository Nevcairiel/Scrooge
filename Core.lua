BrokerMoneyFu = LibStub("AceAddon-3.0"):NewAddon("Broker_MoneyFu", "AceEvent-3.0")
local BMF = BrokerMoneyFu

local LibQTip = LibStub("LibQTip-1.0")
local LDB = LibStub('LibDataBroker-1.1')
if not LDB or not LibQTip then return end

--local L = LibStub:GetLibrary("AceLocale-3.0"):GetLocale("Broker_MoneyFu")

function BMF:OnInitialize()
	local defaults = {
		profile = {
			char_cashflow = false,
			perhour = false,
			crossfaction = false,
			allrealms = false,
		},
		char = {
			spent = {},
			gained = {},
			time = {},
		}
	}
	self.db = LibStub("AceDB-3.0"):New("BrokerMoneyFuDB", defaults, true)
end
