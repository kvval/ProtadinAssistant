local ADDON, ns = ...
local L = ns.L

-- Minimap button via LibDataBroker + LibDBIcon (the standard: works with
-- ElvUI, minimap button collectors and broker bars)
local M = {}
table.insert(ns.modules, M)

local NAME = "ProtadinAssistant"
local FALLBACK_ICON = "Interface\\Icons\\Spell_Holy_SealOfFury"

local function Run(cmd) SlashCmdList.PROTADIN(cmd) end

function M:OnClick(button)
	local shift, ctrl = IsShiftKeyDown(), IsControlKeyDown()
	if button == "RightButton" then
		if ctrl then Run("debug")
		elseif shift then Run("reset")
		else Run("options") end
	else
		if shift then Run(ns.db.locked and "unlock" or "lock")
		else ns.timeline:ApplyLearnedFromUI() end
	end
end

local function Tooltip(tt)
	tt:AddLine("Protadin Assistant")
	local function line(keys, what) tt:AddDoubleLine(keys, what, 1, 0.82, 0, 1, 1, 1) end
	line(L["Left-click"], L["Apply priority from your play"])
	line(L["Right-click"], L["Options"])
	line(L["Shift + left-click"], L["Lock / unlock frames"])
	line(L["Shift + right-click"], L["Reset positions"])
	line(L["Ctrl + right-click"], L["Debug info"])
end

function M:Enable()
	local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
	local icon = LibStub and LibStub("LibDBIcon-1.0", true)
	if not (LDB and icon) then return end
	local _, rfIcon = ns.GetSpellInfo(ns.D.RIGHTEOUS_FURY)
	local obj = LDB:NewDataObject(NAME, {
		type = "launcher",
		text = "Protadin Assistant",
		icon = rfIcon or FALLBACK_ICON,
		OnClick = function(_, button) M:OnClick(button) end,
		OnTooltipShow = Tooltip,
	})
	icon:Register(NAME, obj, ns.db.minimap)
	self.icon = icon
end

function ns.SetMinimapShown(show)
	ns.db.minimap.hide = not show
	if not M.icon then return end
	if show then M.icon:Show(NAME) else M.icon:Hide(NAME) end
end
