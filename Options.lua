local ADDON, ns = ...

local L = ns.L

local O = {}
table.insert(ns.modules, O)

---------------------------------------------------------------------------
-- Widgets
---------------------------------------------------------------------------
local function AddTooltip(frame, text)
	if not text then return end
	frame:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(text, 1, 1, 1, 1, true)
		GameTooltip:Show()
	end)
	frame:SetScript("OnLeave", GameTooltip_Hide)
end

local function Checkbox(parent, label, get, set, tooltip)
	local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	cb:SetSize(26, 26)
	local fs = cb.Text or cb.text
	if not fs then
		fs = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		fs:SetPoint("LEFT", cb, "RIGHT", 2, 0)
	end
	fs:SetText(label)
	cb.label = fs
	cb:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
	cb.Refresh = function(self) self:SetChecked(get() and true or false) end
	AddTooltip(cb, tooltip)
	return cb
end

local function Dropdown(parent, width, getList, get, set)
	local dd = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
	dd:SetWidth(width)
	dd:SetupMenu(function(_, root)
		local list = getList()
		if #list == 0 then
			root:CreateTitle(L["(none known)"])
		end
		for _, v in ipairs(list) do
			-- items are plain strings or { value = ..., text = ... }
			local value, text = v, v
			if type(v) == "table" then value, text = v.value, v.text end
			root:CreateRadio(text, function() return get() == value end, function() set(value) end)
		end
	end)
	dd.Refresh = function(self) self:GenerateMenu() end
	return dd
end

local function Slider(parent, label, minV, maxV, step, fmt, get, set)
	local s = CreateFrame("Slider", nil, parent, "BackdropTemplate")
	s:SetOrientation("HORIZONTAL")
	s:SetSize(220, 16)
	s:SetBackdrop({
		bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
		edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
		tile = true, tileSize = 8, edgeSize = 8,
		insets = { left = 3, right = 3, top = 6, bottom = 6 },
	})
	s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
	s:SetMinMaxValues(minV, maxV)
	s:SetValueStep(step)
	s:SetObeyStepOnDrag(true)
	s.label = s:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	s.label:SetPoint("BOTTOMLEFT", s, "TOPLEFT", 0, 2)
	local function show(v) s.label:SetText(("%s: " .. fmt):format(label, v)) end
	s:SetScript("OnValueChanged", function(self, v)
		v = math.floor(v / step + 0.5) * step
		show(v)
		if self.live then set(v) end
	end)
	s.Refresh = function(self)
		self.live = false
		self:SetValue(get())
		show(get())
		self.live = true
	end
	return s
end

--[[ A bordered section.
  Widgets anchor to the section title. The box is anchored by its top-left
  corner only; its width and height are computed by O:Layout() once the
  widgets are placed (WoW can't anchor "bottom = last widget" without also
  pinning x). The next section's title anchors to this box's bottom.
]]
local function Section(content, title, anchor, gap)
	local box = CreateFrame("Frame", nil, content, "BackdropTemplate")
	box:SetFrameLevel(content:GetFrameLevel())
	box:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		edgeSize = 14,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	box:SetBackdropColor(0, 0, 0, 0.25)
	box:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.9)

	local holder = CreateFrame("Frame", nil, content)
	holder:SetFrameLevel(content:GetFrameLevel() + 3)
	holder:SetSize(1, 1)
	local fs = holder:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	fs:SetText(title)
	if anchor then
		fs:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 12, -(gap or 22))
	else
		fs:SetPoint("TOPLEFT", content, "TOPLEFT", 26, -(gap or 22))
	end

	box:SetPoint("TOPLEFT", fs, "TOPLEFT", -12, 10)
	box:SetSize(400, 60) -- real size set in O:Layout()
	box.title = fs
	-- the section's last widget, used to compute the height
	box.Close = function(self, last, pad)
		self.last, self.pad = last, pad or 12
	end
	return box, fs
end

local function Indent(widget, anchor, x, y)
	widget:ClearAllPoints()
	widget:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", x or 0, y or -4)
	return widget
end

---------------------------------------------------------------------------
-- Panel
---------------------------------------------------------------------------
function O:Enable()
	local panel = CreateFrame("Frame")
	panel.name = "Protadin Assistant"
	panel:SetScript("OnShow", function() O:Refresh() end)
	self.panel = panel

	-- everything lives in a scrollable content frame
	local ok, scroll = pcall(CreateFrame, "ScrollFrame", nil, panel, "ScrollFrameTemplate")
	if not ok then scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate") end
	scroll:SetPoint("TOPLEFT", 0, -4)
	scroll:SetPoint("BOTTOMRIGHT", -26, 4)
	local content = CreateFrame("Frame", nil, scroll)
	content:SetSize(600, 1200)
	scroll:SetScrollChild(content)
	scroll:SetScript("OnSizeChanged", function(_, w)
		if w and w > 0 then content:SetWidth(w); if O.boxes then O:Layout() end end
	end)
	self.scroll, self.content = scroll, content
	self.widgets = {}

	if Settings and Settings.RegisterCanvasLayoutCategory then
		local cat = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
		Settings.RegisterAddOnCategory(cat)
		self.category = cat
	elseif InterfaceOptions_AddCategory then
		InterfaceOptions_AddCategory(panel)
	end

	self:Build()
end

-- redraw the panel if it is open (e.g. after the minimap button applied a priority)
function ns.RefreshOptions()
	if O.panel and O.panel:IsVisible() then O:Refresh() end
end

function ns.OpenOptions()
	if O.category and Settings and Settings.OpenToCategory then
		Settings.OpenToCategory(O.category:GetID())
	elseif InterfaceOptionsFrame_OpenToCategory then
		InterfaceOptionsFrame_OpenToCategory(O.panel)
	end
end

local function NoteCombat()
	if InCombatLockdown() then ns.Print(L["Buff buttons will update after combat."]) end
end

function O:Build()
	local p, w = self.content, self.widgets
	local B, T = ns.buffs, ns.timeline
	local bdb, tdb = ns.db.buffs, ns.db.timeline
	local N = ns.N
	local function add(wd) w[#w + 1] = wd return wd end
	local function buffsChanged() NoteCombat(); B:ApplySettings() end

	local title = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightHuge")
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText("Protadin Assistant")

	-- General -----------------------------------------------------------------
	local gBox, gTitle = Section(p, L["General"], title, 26)
	local lock = add(Checkbox(p, L["Lock frames (unlock to drag them)"],
		function() return ns.db.locked end,
		function(v) ns.SetLocked(v) end))
	Indent(lock, gTitle, 0, -8)

	local mm = add(Checkbox(p, L["Show minimap button"],
		function() return not ns.db.minimap.hide end,
		function(v) ns.SetMinimapShown(v) end))
	Indent(mm, lock, 0, 0)

	local reset = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
	reset:SetSize(170, 22)
	reset:SetText(L["Reset positions"])
	reset:SetPoint("TOPLEFT", mm, "BOTTOMLEFT", 4, -6)
	reset:SetScript("OnClick", function() ns.ResetPositions() end)
	gBox:Close(reset)

	-- Buff tracker ------------------------------------------------------------
	local bBox, bTitle = Section(p, L["Buff tracker"], gBox, 26)

	local bOn = add(Checkbox(p, L["Show buff tracker"],
		function() return bdb.enabled end,
		function(v) bdb.enabled = v; buffsChanged() end))
	Indent(bOn, bTitle, 0, -8)

	local function slotRow(key, label, anchor, listKey, dbKey)
		local cb = add(Checkbox(p, label,
			function() return bdb[key .. "On"] end,
			function(v)
				bdb[key .. "On"] = v
				-- a hand-made choice: stop switching this slot automatically at login
				if key == "food" or key == "bag" then bdb[key .. "Manual"] = true end
				buffsChanged()
			end))
		Indent(cb, anchor, anchor == bOn and 20 or 0, -2)
		if listKey then
			local dd = add(Dropdown(p, 170,
				function() return B[listKey] or {} end,
				function() return bdb[dbKey] end,
				function(v) bdb[dbKey] = v; bdb[dbKey .. "Auto"] = nil; buffsChanged() end))
			dd:SetPoint("LEFT", cb, "LEFT", 170, 0)
		end
		return cb
	end
	local r = slotRow("aura", L["Aura"], bOn, "auraList", "aura")
	r = slotRow("blessing", L["Blessing"], r, "blessingList", "blessing")
	r = slotRow("rf", N.RF, r)
	r = slotRow("tracking", L["Tracking"], r, "trackingList", "tracking")
	r = slotRow("food", N.WellFed, r)
	r = slotRow("bag", N.WellRested, r)
	r = slotRow("camp", N.CampBenefits, r)

	local chat = add(Checkbox(p, L["Chat message when a buff drops"],
		function() return bdb.chat end, function(v) bdb.chat = v end))
	chat:SetPoint("TOPLEFT", r, "BOTTOMLEFT", -20, -8)

	local bsize = add(Slider(p, L["Icon size"], 16, 64, 1, "%d",
		function() return bdb.iconSize end,
		function(v) bdb.iconSize = v; buffsChanged() end))
	bsize:SetPoint("TOPLEFT", chat, "BOTTOMLEFT", 4, -22)

	local bscale = add(Slider(p, L["Scale"], 0.5, 2, 0.05, "%.2f",
		function() return bdb.scale end,
		function(v) bdb.scale = v; buffsChanged() end))
	bscale:SetPoint("TOPLEFT", bsize, "BOTTOMLEFT", 0, -26)
	bBox:Close(bscale, 14)

	-- Cooldown timeline -------------------------------------------------------
	local tBox, tTitle = Section(p, L["Cooldown timeline"], bBox, 26)

	local tOn, onlyCombat
	tOn = add(Checkbox(p, L["Show timeline"],
		function() return tdb.enabled end,
		function(v) tdb.enabled = v; T:UpdateVisibility(); onlyCombat:Refresh() end))
	Indent(tOn, tTitle, 0, -8)

	onlyCombat = add(Checkbox(p, L["Only during combat"],
		function() return tdb.onlyInCombat end,
		function(v) tdb.onlyInCombat = v; T:UpdateVisibility() end))
	Indent(onlyCombat, tOn, 20, 2)
	local baseRefresh = onlyCombat.Refresh
	onlyCombat.Refresh = function(self)
		baseRefresh(self)
		local on = tdb.enabled and true or false
		self:SetEnabled(on)
		self.label:SetTextColor(on and 1 or 0.5, on and 1 or 0.5, on and 1 or 0.5)
	end

	local tw = add(Slider(p, L["Width"], 150, 700, 10, "%d",
		function() return tdb.width end,
		function(v) tdb.width = v; T:ApplySettings() end))
	tw:SetPoint("TOPLEFT", onlyCombat, "BOTTOMLEFT", -16, -22)

	local ts = add(Slider(p, L["Icon size"], 16, 56, 1, "%d",
		function() return tdb.iconSize end,
		function(v) tdb.iconSize = v; T:ApplySettings() end))
	ts:SetPoint("TOPLEFT", tw, "BOTTOMLEFT", 0, -26)

	local tsc = add(Slider(p, L["Scale"], 0.5, 2, 0.05, "%.2f",
		function() return tdb.scale end,
		function(v) tdb.scale = v; T:ApplySettings() end))
	tsc:SetPoint("TOPLEFT", ts, "BOTTOMLEFT", 0, -26)

	local nextCb = add(Checkbox(p, L["Suggest next"],
		function() return tdb.showNext end,
		function(v) tdb.showNext = v end,
		L["Gold icon: the best spell to cast now."]))
	nextCb:SetPoint("TOPLEFT", tsc, "BOTTOMLEFT", -4, -12)

	local soonCb = add(Checkbox(p, L["Highlight upcoming"],
		function() return tdb.highlightSoon end,
		function(v) tdb.highlightSoon = v end,
		L["Spells ready within 1.5 s grow, so you can plan ahead."]))
	Indent(soonCb, nextCb, 0, 0)

	local seal = add(Checkbox(p, L["Track Seal"],
		function() return tdb.seal end,
		function(v) tdb.seal = v; T:RebuildEntries() end,
		L["Blinks when you have no seal."]))
	Indent(seal, soonCb, 0, 0)

	local holder = CreateFrame("Frame", nil, p)
	holder:SetFrameLevel(p:GetFrameLevel() + 3)
	holder:SetSize(1, 1)
	local ph = holder:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	ph:SetText(L["Rotation, by prio"])
	ph:SetPoint("TOPLEFT", seal, "BOTTOMLEFT", 4, -12)
	self.prioHeader = ph
	self.prioRows = {}
	self.tlBox = tBox

	-- "from your play" suggestion
	local lh = CreateFrame("Frame", nil, p)
	lh:SetFrameLevel(p:GetFrameLevel() + 3)
	lh:SetSize(1, 1)
	local lt = lh:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	lt:SetJustifyH("LEFT")
	lt:SetWordWrap(true)
	self.learnText = lt

	local apply = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
	apply:SetSize(120, 22)
	apply:SetText(L["Apply"])
	apply:SetScript("OnClick", function() T:ApplyLearned(); O:Refresh() end)
	AddTooltip(apply, L["Use this order for the rotation."])
	self.learnApply = apply

	local forget = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
	forget:SetSize(120, 22)
	forget:SetText(L["Forget"])
	forget:SetPoint("LEFT", apply, "RIGHT", 8, 0)
	forget:SetScript("OnClick", function() T:ForgetLearned(); O:Refresh() end)
	AddTooltip(forget, L["Forget what was learned from your play."])

	local announce = add(Checkbox(p, L["Announce play style change"],
		function() return tdb.announceStyle end,
		function(v) tdb.announceStyle = v end,
		L["At most once a day."]))
	announce:SetPoint("TOPLEFT", apply, "BOTTOMLEFT", -2, -6)
	self.learnAnnounce = announce
	self.boxes = { gBox, bBox, tBox }
end

-- size the section boxes to their content (top to bottom: each box's
-- position depends on the one above it)
function O:Layout()
	local content = self.content
	local cl, ct = content:GetLeft(), content:GetTop()
	if not (cl and ct) then return end
	for _, box in ipairs(self.boxes) do
		local top, left = box:GetTop(), box:GetLeft()
		local bottom = box.last and box.last:GetBottom()
		if top and left and bottom then
			box:SetWidth(math.max(300, content:GetWidth() - (left - cl) - 8))
			box:SetHeight(top - bottom + box.pad)
		end
	end
	local last = self.boxes[#self.boxes]:GetBottom()
	if last then content:SetHeight(ct - last + 24) end
end

function O:Refresh()
	for _, wd in ipairs(self.widgets) do wd:Refresh() end

	-- rotation list: position = priority; listed = shown on the timeline
	local T = ns.timeline
	local function label(sp) return ("|T%s:16|t %s"):format(sp.icon or 134400, sp.name) end

	local anchor = self.prioHeader
	for _, row in ipairs(self.prioRows) do row:Hide() end

	local enabled = T:EnabledByPriority()
	local all = T:OrderedCandidates()
	local rows = #enabled + ((#enabled < #all) and 1 or 0) -- + "add" row while something is left
	for k = 1, rows do
		local row = self.prioRows[k]
		if not row then
			row = CreateFrame("Frame", nil, self.content)
			row:SetSize(280, 28)
			row.num = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
			row.num:SetPoint("LEFT", 4, 0)
			row.dd = Dropdown(row, 220,
				function()
					local en = T:EnabledByPriority()
					local items = {}
					if k > #en then
						-- the "add" row: only spells that aren't listed yet
						items[1] = { value = "", text = L["+ add a spell"] }
						for _, sp in ipairs(T:OrderedCandidates()) do
							if not T:IsSpellEnabled(sp.name) then items[#items + 1] = { value = sp.name, text = label(sp) } end
						end
					else
						for _, sp in ipairs(T:OrderedCandidates()) do items[#items + 1] = { value = sp.name, text = label(sp) } end
						items[#items + 1] = { value = "", text = L["— none —"] }
					end
					return items
				end,
				function()
					local e = T:EnabledByPriority()[k]
					return e and e.name or ""
				end,
				function(v)
					if k > #T:EnabledByPriority() then T:AddSpell(v) else T:ReplaceAt(k, v) end
					O:Refresh()
				end)
			row.dd:SetPoint("LEFT", row, "LEFT", 28, 0)
			self.prioRows[k] = row
		end
		row.num:SetText(k <= #enabled and (k .. ".") or "")
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", k == 1 and -4 or 0, k == 1 and -6 or -2)
		row.dd:GenerateMenu()
		row:Show()
		anchor = row
	end
	-- "from your play"
	local lt, apply = self.learnText, self.learnApply
	lt:ClearAllPoints()
	lt:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 4, -12)
	lt:SetWidth(math.max(260, (self.content:GetWidth() or 600) - 90))
	local order, n = T:LearnedOrder()
	if n < T.LEARN_MIN then
		lt:SetText(L["Learning from your play: %d of %d choices."]:format(n, T.LEARN_MIN))
		apply:Disable()
	else
		local same = true
		for i, sp in ipairs(enabled) do if order[i] ~= sp.name then same = false end end
		lt:SetText(L["From your play:"] .. " " .. table.concat(order, " > ")
			.. (same and (" " .. L["(same as now)"]) or ""))
		apply:SetEnabled(not same)
	end
	apply:ClearAllPoints()
	apply:SetPoint("TOPLEFT", lt, "BOTTOMLEFT", -2, -6)
	self.tlBox:Close(self.learnAnnounce, 8)

	self:Layout()
	-- positions may only settle on the next frame after the panel is shown
	C_Timer.After(0, function() O:Layout() end)
end
