local ADDON, ns = ...
local L = ns.L

local B = {}
ns.buffs = B
table.insert(ns.modules, B)

-- spell / item names come from ns.N (Data.lua), already in the client's language

B.SLOTS = {
	{ key = "aura" },
	{ key = "blessing" },
	{ key = "rf" },
	{ key = "tracking" },
	{ key = "food" },
	{ key = "bag" },
	{ key = "camp" },
}

-- what the player should have in a slot (shown in tooltips / chat)
function B:WantName(key)
	local N = ns.N
	if key == "food" then return N.WellFed end
	if key == "bag" then return N.WellRested end
	if key == "camp" then return N.CampBenefits end
	return self:ExpectedSpell(key)
end

---------------------------------------------------------------------------
-- Known options (from spellbook / minimap)
---------------------------------------------------------------------------
function B:RefreshKnown()
	local N = ns.N
	local blessings, auras = {}, {}
	for name, s in pairs(ns.spellbook or {}) do
		local base = ns.BlessingBase(name)
		if base then
			if not ns.IsHandBlessing(base) then blessings[base] = true end
		elseif ns.IsAuraName(name) and not s.isPassive then
			auras[name] = true
		end
	end
	local function sorted(set)
		local t = {}
		for k in pairs(set) do t[#t + 1] = k end
		table.sort(t)
		return t
	end
	self.blessingList, self.blessingSet = sorted(blessings), blessings
	self.auraList, self.auraSet = sorted(auras), auras
	self.trackingList = {}
	for _, t in ipairs(ns.GetTrackingList()) do self.trackingList[#self.trackingList + 1] = t.name end

	-- pick sensible defaults if nothing chosen yet (or the choice is unknown).
	-- empty lists = spellbook not loaded yet: keep the saved choice.
	-- such a default is marked "auto": AdoptActive() replaces it with whatever
	-- the player actually has up, as soon as auras are visible.
	local db = self.db
	if #self.blessingList > 0 and not (db.blessing and blessings[db.blessing]) then
		db.blessing = nil
		for _, n in ipairs(N.preferred) do if blessings[n] then db.blessing = n break end end
		db.blessing = db.blessing or self.blessingList[1]
		db.blessingAuto = true
	end
	if #self.auraList > 0 and not (db.aura and auras[db.aura]) then
		db.aura = (N.defaultAura and auras[N.defaultAura]) and N.defaultAura or self.auraList[1]
		db.auraAuto = true
	end
	if #self.trackingList > 0 and (not db.tracking or not tContains(self.trackingList, db.tracking)) then
		local def = N.defaultTracking
		db.tracking = (def and tContains(self.trackingList, def)) and def or self.trackingList[1]
		db.trackingAuto = true
	end
end

-- first run: take the blessing / aura / tracking that is currently active
function B:AdoptActive()
	local db = self.db
	if not (db.blessingAuto or db.auraAuto or db.trackingAuto) then return end
	local changed = false
	ns.ForEachPlayerAura(function(a)
		if ns.IsSecret(a.name) then return true end
		if not ns.AuraFromPlayer(a) then return end
		local base = ns.BlessingBase(a.name)
		if db.blessingAuto and base and self.blessingSet[base] then
			db.blessing, db.blessingAuto, changed = base, nil, true
		elseif db.auraAuto and self.auraSet[a.name] then
			db.aura, db.auraAuto, changed = a.name, nil, true
		end
	end)
	if db.trackingAuto then
		for _, tr in ipairs(ns.GetTrackingList()) do
			if tr.active then db.tracking, db.trackingAuto, changed = tr.name, nil, true break end
		end
	end
	if changed then self:ApplySettings() end
end

-- spell to cast / icon to show for a slot
function B:ExpectedSpell(key)
	local db = self.db
	if key == "blessing" then return db.blessing
	elseif key == "aura" then return db.aura
	elseif key == "rf" then return ns.IsKnownName(ns.N.RF) and ns.N.RF or nil
	elseif key == "tracking" then return db.tracking
	end
end

function B:SlotActive(key)
	local db = self.db
	if not db[key .. "On"] then return false end
	if key == "food" or key == "bag" or key == "camp" then return true end
	return self:ExpectedSpell(key) ~= nil
end

---------------------------------------------------------------------------
-- Frames
---------------------------------------------------------------------------
local function CreateSlotButton(parent, key)
	local b = CreateFrame("Button", "ProtadinBuff_" .. key, parent, "SecureActionButtonTemplate")
	b:RegisterForClicks("AnyUp", "AnyDown")
	b:SetAttribute("unit", "player")

	b.border = b:CreateTexture(nil, "BACKGROUND")
	b.border:SetPoint("TOPLEFT", -2, 2)
	b.border:SetPoint("BOTTOMRIGHT", 2, -2)
	b.border:SetColorTexture(0, 0, 0, 1)

	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetAllPoints()
	b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	b.text = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	b.text:SetPoint("TOP", b, "BOTTOM", 0, -2)

	local ag = b.icon:CreateAnimationGroup()
	ag:SetLooping("BOUNCE")
	local a = ag:CreateAnimation("Alpha")
	a:SetFromAlpha(1)
	a:SetToAlpha(0.15)
	a:SetDuration(0.45)
	b.blink = ag

	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
		GameTooltip:AddLine(self.tipTitle or "")
		if self.tipText then GameTooltip:AddLine(self.tipText, 1, 1, 1, true) end
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", GameTooltip_Hide)
	b.key = key
	return b
end

function B:Enable()
	self.db = ns.db.buffs
	self.state = {}

	local f = CreateFrame("Frame", "ProtadinBuffFrame", UIParent)
	f:SetSize(10, 10)
	self.frame = f
	ns.MakeMovable(f, self.db, L["Protadin: buffs"])

	self.buttons = {}
	for _, s in ipairs(self.SLOTS) do
		self.buttons[s.key] = CreateSlotButton(f, s.key)
	end

	-- start in "loading" mode: between login/reload and entering the world the
	-- client may report empty buff and tracking lists (looked like drops)
	self.loading = true
	self.loadSerial = 0

	self:RefreshKnown()
	self:ApplySettings()
	self:OnLockChanged()

	C_Timer.After(10, function() -- safety net if PLAYER_ENTERING_WORLD never comes
		if self.loading and self.loadSerial == 0 then self.loading = false; self:Scan() end
	end)

	f:RegisterUnitEvent("UNIT_AURA", "player")
	f:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
	f:RegisterEvent("PLAYER_ENTERING_WORLD")
	f:RegisterEvent("PLAYER_LEAVING_WORLD")
	pcall(f.RegisterEvent, f, "LOADING_SCREEN_ENABLED")
	pcall(f.RegisterEvent, f, "LOADING_SCREEN_DISABLED")
	f:RegisterEvent("SPELLS_CHANGED")
	f:RegisterEvent("MINIMAP_UPDATE_TRACKING")
	f:RegisterEvent("BAG_UPDATE_DELAYED")
	f:RegisterEvent("PLAYER_REGEN_ENABLED")
	f:SetScript("OnEvent", function(_, event, ...) B:OnEvent(event, ...) end)

	local acc = 0
	f:SetScript("OnUpdate", function(_, el)
		acc = acc + el
		if acc >= 0.25 then acc = 0; B:UpdateTimers() end
	end)

	self:Scan()
end

-- layout & secure attributes: only out of combat
function B:ApplySettings()
	ns.RunOutOfCombat("buffs_layout", function()
		local db, size, x = self.db, self.db.iconSize, 0
		ns.ApplyPosition(self.frame, db)
		if not db.enabled then
			self.frame:Hide()
			self.state = {} -- no "dropped" messages when switched back on
			return
		end
		self.frame:Show()
		for _, s in ipairs(self.SLOTS) do
			local b = self.buttons[s.key]
			local spell = self:ExpectedSpell(s.key)
			if s.key == "bag" then
				b:SetAttribute("type", "item")
				b:SetAttribute("item", "item:" .. ns.D.SLEEPING_BAG)
			elseif s.key == "camp" then
				b:SetAttribute("type", "item")
				b:SetAttribute("item", "item:" .. ns.D.CAMPFIRE_KIT)
			elseif s.key == "food" then
				-- eat the XP food we have the least of
				self.foodItem = ns.PickXPFood()
				if self.foodItem then
					b:SetAttribute("type", "item")
					b:SetAttribute("item", "item:" .. self.foodItem)
				else
					b:SetAttribute("type", nil)
				end
			elseif spell then
				b:SetAttribute("type", "spell")
				b:SetAttribute("spell", spell)
			else
				b:SetAttribute("type", nil)
			end
			if self:SlotActive(s.key) then
				b:SetSize(size, size)
				b:ClearAllPoints()
				b:SetPoint("LEFT", self.frame, "LEFT", x, 0)
				b:Show()
				x = x + size + 6
			else
				b:Hide()
			end
		end
		self.frame:SetSize(math.max(x - 6, size), size)
		self:Scan()
	end)
end

function B:OnLockChanged()
	self.frame.mover:SetShown(not ns.db.locked)
end

-- Loading screens: the client briefly reports no buffs and no tracking, which
-- looked like everything had dropped. While loading we don't scan at all, and
-- after it we wait a moment, then compare with the state from before loading.
local SETTLE = 3

function B:BeginLoading()
	self.loading = true
	self.loadSerial = (self.loadSerial or 0) + 1
end

function B:EndLoading()
	local serial = (self.loadSerial or 0) + 1
	self.loadSerial = serial
	self.loading = true
	C_Timer.After(SETTLE, function()
		if self.loadSerial ~= serial then return end -- another loading screen started
		self.loading = false
		if not self.autoSlotsDone then
			self.autoSlotsDone = true
			self:AutoSlots()
		end
		self:Scan()
	end)
end

-- once per login (bags are loaded by now): show Well Fed only if there is XP
-- food in the bags, and Well-Rested only if the Cozy Sleeping Bag is there.
-- Once the player has switched a slot by hand (foodManual / bagManual), it is
-- left alone.
function B:AutoSlots()
	local db = self.db
	local changed = false
	if not db.foodManual then
		local hasFood = ns.PickXPFood() ~= nil
		if db.foodOn ~= hasFood then db.foodOn, changed = hasFood, true end
	end
	if not db.bagManual then
		local id = ns.D.SLEEPING_BAG
		local count = (C_Item and C_Item.GetItemCount and C_Item.GetItemCount(id))
			or (GetItemCount and GetItemCount(id)) or 0
		local hasBag = count > 0
		if db.bagOn ~= hasBag then db.bagOn, changed = hasBag, true end
	end
	if changed then self:ApplySettings() end
end

function B:OnEvent(event, ...)
	if event == "PLAYER_LEAVING_WORLD" or event == "LOADING_SCREEN_ENABLED" then
		self:BeginLoading()
		return
	end
	if event == "LOADING_SCREEN_DISABLED" then
		self:EndLoading()
		return
	end
	if event == "PLAYER_ENTERING_WORLD" then self:EndLoading() end
	if event == "BAG_UPDATE_DELAYED" then
		-- food in the bags changed: pick again (secure button -> out of combat)
		self:ApplySettings()
		return
	end
	if event == "SPELLS_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
		ns.ScanSpellbook()
		self:RefreshKnown()
		self:ApplySettings()
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		local _, _, spellID = ...
		if spellID and not ns.IsSecret(spellID) then self:OnCast(spellID) end
	elseif event == "UNIT_AURA" then
		local _, info = ...
		local removed = ns.RemovedAuraIDs(info)
		if removed then
			self.removedIDs = self.removedIDs or {}
			for id in pairs(removed) do self.removedIDs[id] = true end
		end
		self:Scan()
	else
		self:Scan()
	end
end

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------
-- full scan; when auras are secret or can't be read at all (instances), keeps
-- the previous state and only detects removals via aura instance ids
function B:Scan()
	if not self.db or not self.db.enabled then return end
	if self.loading then return end -- keep the pre-loading state, see EndLoading
	if not self.blessingSet then return end -- not initialised yet
	self:AdoptActive()
	local db, N, D = self.db, ns.N, ns.D
	local res = {}
	for _, s in ipairs(self.SLOTS) do res[s.key] = { ok = false } end
	local secret = false

	local readable = ns.ForEachPlayerAura(function(a)
		local name = a.name
		if ns.IsSecret(name) then secret = true return true end
		local fromMe = ns.AuraFromPlayer(a)
		local id = not ns.IsSecret(a.spellId) and a.spellId or nil
		local function take(key)
			local r = res[key]
			r.ok, r.icon, r.expires, r.duration, r.instance, r.wrong =
				true, a.icon, a.expirationTime, a.duration, a.auraInstanceID, nil
		end
		local base = ns.BlessingBase(name)
		if fromMe and base and base == db.blessing then
			take("blessing")
		elseif fromMe and base and self.blessingSet[base] and not res.blessing.ok then
			res.blessing.wrong = name
		elseif fromMe and name == db.aura then
			take("aura")
		elseif fromMe and self.auraSet[name] and not res.aura.ok then
			res.aura.wrong = name
		elseif name == N.RF then
			take("rf")
		elseif name == N.WellFed or (not ns.IsSecret(a.icon) and a.icon == D.WELL_FED_ICON) then
			take("food")
		elseif name == N.WellRested or id == D.WELL_RESTED then
			take("bag")
		elseif name == N.CampBenefits or (D.CAMP_BENEFITS and id == D.CAMP_BENEFITS) then
			take("camp")
		end
	end)

	local removed = self.removedIDs
	self.removedIDs = nil
	if secret or not readable then
		-- keep what we knew; drop buffs whose aura instance disappeared
		for _, s in ipairs(self.SLOTS) do
			local key = s.key
			if key ~= "tracking" then
				local old = self.state[key]
				local inst = old and old.ok and old.instance
				if inst and ((removed and removed[inst]) or ns.AuraExists(inst) == false) then
					res[key] = { ok = false }
				else
					res[key] = old or { ok = false }
				end
			end
		end
	end

	-- minimap tracking
	local t = res.tracking
	for _, tr in ipairs(ns.GetTrackingList()) do
		if tr.active then
			if tr.name == db.tracking then
				t.ok, t.icon, t.wrong = true, tr.icon, nil
			elseif not t.ok then
				t.wrong = tr.name
			end
		end
	end

	self:Commit(res)
end

-- a tracked buff was (re)cast while aura data is secret: assume it's up
function B:OnCast(spellID)
	local name = ns.GetSpellInfo(spellID)
	if not name then return end
	local base = ns.BlessingBase(name)
	local key
	if base and base == self.db.blessing then key = "blessing"
	elseif name == self.db.aura then key = "aura"
	elseif name == ns.N.RF then key = "rf" end
	if not key then return end
	C_Timer.After(0.2, function()
		local cur = self.state[key]
		if cur and cur.ok then return end -- normal scan already saw it
		local _, icon = ns.GetSpellInfo(spellID)
		local res = {}
		for k, v in pairs(self.state) do res[k] = v end
		res[key] = { ok = true, icon = icon }
		self:Commit(res)
	end)
end

function B:Commit(res)
	local prev = self.state
	self.state = res
	local dead = UnitIsDeadOrGhost("player")
	for _, s in ipairs(self.SLOTS) do
		local key = s.key
		local r, p = res[key], prev[key]
		-- warn on transition ok -> not ok (or to a wrong one)
		if self.db.chat and not dead and self:SlotActive(key) and p and not r.ok
			and (p.ok or (r.wrong and r.wrong ~= p.wrong)) then
			local want = self:WantName(key)
			if r.wrong then
				ns.Print(L["%s is up, expected %s"]:format("|cffff5555" .. r.wrong .. "|r", "|cffffd200" .. tostring(want) .. "|r"))
			else
				ns.Print(L["%s has faded"]:format("|cffffd200" .. tostring(want) .. "|r"))
			end
		end
		self:Render(key)
	end
end

function B:Render(key)
	local b = self.buttons[key]
	local r = self.state[key] or {}
	local want = self:WantName(key)
	b.tipTitle = want
	if r.ok then
		b.icon:SetTexture(r.icon)
		b.icon:SetDesaturated(false)
		b.border:SetColorTexture(0, 0, 0, 1)
		if b.blink:IsPlaying() then b.blink:Stop() end
		b.tipText = nil
	else
		local icon
		if key == "bag" then icon = ns.SleepingBagIcon()
		elseif key == "camp" then icon = ns.CampfireKitIcon()
		elseif key == "food" then icon = self.foodItem and ns.ItemIcon(self.foodItem) or ns.D.WELL_FED_ICON
		else icon = select(2, ns.GetSpellInfo(want)) end
		b.icon:SetTexture(icon or 134400)
		b.icon:SetDesaturated(true)
		b.border:SetColorTexture(1, 0.1, 0.1, 1)
		if not b.blink:IsPlaying() then b.blink:Play() end
		b.text:SetText("")
		if r.wrong then
			b.tipText = L["Active: %s. Click to cast %s."]:format(r.wrong, want or "?")
		elseif key == "food" then
			b.tipText = self.foodItem and L["Missing. Click to use %s."]:format(ns.ItemName(self.foodItem, "?"))
				or L["Missing. Eat something."]
		elseif key == "bag" then
			b.tipText = L["Missing. Click to use %s."]:format(ns.SleepingBagName())
		elseif key == "camp" then
			b.tipText = L["Missing. Click to use %s."]:format(ns.CampfireKitName())
		else
			b.tipText = L["Missing. Click to cast %s."]:format(want or "?")
		end
	end
	self:UpdateTimer(key)
end

function B:UpdateTimer(key)
	local b, r = self.buttons[key], self.state[key]
	if not (r and r.ok) then return end
	local exp = r.expires
	if exp and not ns.IsSecret(exp) and exp > 0 then
		local left = exp - GetTime()
		b.text:SetText(left > 0 and ns.FormatTime(left) or "")
	else
		b.text:SetText("")
	end
end

function B:UpdateTimers()
	for _, s in ipairs(self.SLOTS) do self:UpdateTimer(s.key) end
end

function B:Debug()
	ns.Print("buffs: blessing=", self.db.blessing, "aura=", self.db.aura, "tracking=", self.db.tracking)
	for _, s in ipairs(self.SLOTS) do
		local r = self.state[s.key] or {}
		ns.Print("  ", s.key, r.ok and "OK" or "MISSING", r.wrong or "")
	end
	ns.Print("  known blessings:", table.concat(self.blessingList, ", "))
	ns.Print("  known auras:", table.concat(self.auraList, ", "))
	ns.Print("  tracking:", table.concat(self.trackingList, ", "))
	ns.Print("  campfire kit:", ns.CampfireKitName(), " camp buff:", ns.N.CampBenefits)
end
