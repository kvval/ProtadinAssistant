local ADDON, ns = ...

local T = {}
ns.timeline = T
table.insert(ns.modules, T)

-- talent changes can change cooldowns (see T:OnEvent)
local TALENT_EVENTS = { "CHARACTER_POINTS_CHANGED", "PLAYER_TALENT_UPDATE",
	"ACTIVE_TALENT_GROUP_CHANGED", "TRAIT_CONFIG_UPDATED" }

local L = ns.L
local SEAL_KEY = "__seal"
local NEXT_SCALE = 1.32  -- "press this" icon size vs. normal icons
local SOON_SCALE = NEXT_SCALE -- upcoming spells grow to exactly the "press this" size

--[[ How cooldowns are known
  In combat this client returns cooldowns as secret values. So:
  - whenever the real cooldown is readable (out of combat), it is copied into
    self.cd[name] and its full duration is remembered in db.learned[name];
  - in combat, a successful cast of a tracked spell starts our own timer
    (learned duration, else base cooldown);
  - if even the cast events are secret, fall back to Blizzard's secret-safe
    widgets (status bar position + alpha curve, no numbers).
]]

---------------------------------------------------------------------------
-- Which spells can go on the timeline
---------------------------------------------------------------------------
local function IsBuffSpell(name)
	return ns.IsSealName(name) or ns.BlessingBase(name) ~= nil or ns.IsAuraName(name) or name == ns.N.RF
end

function T:BuildCandidates()
	local list, seen = {}, {}
	local haveBaseCD = GetSpellBaseCooldown ~= nil
	for _, s in ipairs(ns.ScanSpellbook()) do
		if not s.isPassive and not IsBuffSpell(s.name) then
			local cd = ns.GetBaseCooldown(s.spellID)
			if ns.defaultTimelineSpells[s.name] or (cd and cd >= 2000 and cd <= 60000) then
				list[#list + 1] = s
				seen[s.name] = true
			end
		end
	end
	if not haveBaseCD then
		for _, name in ipairs(ns.N.fallbackTimeline) do
			local s = ns.spellbook[name]
			if s and not seen[name] then list[#list + 1] = s end
		end
	end
	-- the seal is one more entry of the rotation: "ready" while no seal is up
	list[#list + 1] = { name = SEAL_KEY, isSeal = true }
	self.candidates = list
end

-- Seal popularity: how often each seal is put up (older casts fade, half
-- weight after SEAL_HALF_LIFE casts). The most used one is what "Suggest
-- next" shows when no seal is up.
local SEAL_HALF_LIFE = 100
local SEAL_DECAY = 0.5 ^ (1 / SEAL_HALF_LIFE)

function T:NoteSeal(name)
	local seals = self.db.learn.seals or {}
	self.db.learn.seals = seals
	for n, v in pairs(seals) do
		v = v * SEAL_DECAY
		seals[n] = v >= 0.01 and v or nil
	end
	seals[name] = (seals[name] or 0) + 1
end

-- seals by use, most used first: { { name, share }, ... }
function T:SealStats()
	local seals = (self.db.learn and self.db.learn.seals) or {}
	local list, total = {}, 0
	for n, v in pairs(seals) do list[#list + 1] = { name = n, w = v }; total = total + v end
	table.sort(list, function(a, b) return a.w > b.w end)
	for _, x in ipairs(list) do x.share = total > 0 and x.w / total or 0 end
	return list
end

-- icon of the seal to suggest: the most used one the player knows
function T:PopularSealIcon()
	for _, x in ipairs(self:SealStats()) do
		local s = ns.spellbook and ns.spellbook[x.name]
		if s then return s.icon end
	end
	return self.sealIcon
end

-- what the player sees for an entry name (the seal has an internal key)
function T:DisplayName(name)
	if name == SEAL_KEY then return L["Seal"] end
	return name
end

function T:IsSpellEnabled(name)
	local v = self.db.spells[name]
	if v == nil then
		if name == SEAL_KEY then return self.db.seal ~= false end
		return ns.defaultTimelineSpells[name] or false
	end
	return v
end

function T:SetSpellEnabled(name, on)
	self.db.spells[name] = on and true or false
	self:RebuildEntries()
end

-- candidates in priority order: saved order first, then the default priority,
-- then spellbook order
function T:OrderedCandidates()
	local saved, def = {}, {}
	for i, n in ipairs(self.db.priority) do saved[n] = i end
	for i, n in ipairs(ns.N.defaultPriority or {}) do def[n] = i end
	local tmp = {}
	for i, s in ipairs(self.candidates or {}) do
		local k = saved[s.name] or (1000 + (def[s.name] or 500))
		if s.isSeal and not saved[s.name] then k = 0 end -- seal on top by default
		tmp[#tmp + 1] = { s = s, k = k, i = i }
	end
	table.sort(tmp, function(a, b)
		if a.k ~= b.k then return a.k < b.k end
		return a.i < b.i
	end)
	local out = {}
	for _, x in ipairs(tmp) do out[#out + 1] = x.s end
	return out
end

-- enabled spells in priority order (what the priority dropdowns show)
function T:EnabledByPriority()
	local out = {}
	for _, s in ipairs(self:OrderedCandidates()) do
		if self:IsSpellEnabled(s.name) then out[#out + 1] = s end
	end
	return out
end

-- put `name` at priority slot k (among enabled spells); the spell that held
-- slot k takes name's old place, so the order never gets duplicates
function T:SetPriorityAt(k, name)
	local all = {}
	for i, s in ipairs(self:OrderedCandidates()) do all[i] = s.name end
	local enabled = self:EnabledByPriority()
	local holder = enabled[k] and enabled[k].name
	if not holder or holder == name then return end
	local a, b
	for i, n in ipairs(all) do
		if n == holder then a = i elseif n == name then b = i end
	end
	if not (a and b) then return end
	all[a], all[b] = all[b], all[a]
	self.db.priority = all
	self:RebuildEntries()
end

local function Without(list, name)
	local out = {}
	for _, n in ipairs(list) do if n ~= name then out[#out + 1] = n end end
	return out
end

-- one priority list in the options: slot k gets `name` ("" = remove the spell)
function T:ReplaceAt(k, name)
	local enabled = self:EnabledByPriority()
	local holder = enabled[k] and enabled[k].name
	if not holder or holder == name then return end
	if name == "" then
		self.db.spells[holder] = false
	elseif self:IsSpellEnabled(name) then
		return self:SetPriorityAt(k, name)
	else
		-- a spell that wasn't shown takes the holder's place; the holder goes off
		local all = {}
		for i, s in ipairs(self:OrderedCandidates()) do all[i] = s.name end
		all = Without(all, name)
		for i, n in ipairs(all) do
			if n == holder then table.insert(all, i, name) break end
		end
		self.db.priority = all
		self.db.spells[holder] = false
		self.db.spells[name] = true
	end
	self:RebuildEntries()
end

-- add a spell at the end of the priority list
function T:AddSpell(name)
	if name == "" or self:IsSpellEnabled(name) then return end
	local enabled = self:EnabledByPriority()
	local last = enabled[#enabled] and enabled[#enabled].name
	local all = {}
	for i, s in ipairs(self:OrderedCandidates()) do all[i] = s.name end
	all = Without(all, name)
	local pos = 1
	for i, n in ipairs(all) do if n == last then pos = i + 1 break end end
	table.insert(all, pos, name)
	self.db.priority = all
	self.db.spells[name] = true
	self:RebuildEntries()
end

function T:RebuildEntries()
	local entries, byName = {}, {}
	for _, s in ipairs(self:OrderedCandidates()) do
		if self:IsSpellEnabled(s.name) then
			local e
			if s.isSeal then
				e = { key = SEAL_KEY, name = SEAL_KEY, isSeal = true, icon = self.sealIcon, id = self.sealSpellId }
			else
				local base = ns.GetBaseCooldown(s.spellID)
				e = { key = s.name, name = s.name, id = s.spellID, icon = s.icon,
					baseCD = base and base / 1000 or nil, tipCD = ns.TooltipCooldown(s.spellID) }
			end
			entries[#entries + 1] = e
			byName[e.name] = e
		end
	end
	self.entries, self.byName = entries, byName
	for i, e in ipairs(entries) do
		local ic = self:GetIcon(i)
		ic.entry = e
		ic.mode = nil
		ic.wasMoving = false
		if e.icon then ic.tex:SetTexture(e.icon) end
	end
	for i = #entries + 1, #self.icons do
		local ic = self.icons[i]
		ic:Hide(); ic.track:Hide(); ic.entry = nil
	end
end

---------------------------------------------------------------------------
-- Frames
---------------------------------------------------------------------------
function T:GetIcon(i)
	local ic = self.icons[i]
	if ic then return ic end
	local bar = self.bar
	ic = CreateFrame("Frame", nil, bar)
	ic:SetFrameLevel(bar:GetFrameLevel() + 5)
	ic.border = ic:CreateTexture(nil, "BACKGROUND")
	ic.border:SetPoint("TOPLEFT", -2, 2)
	ic.border:SetPoint("BOTTOMRIGHT", 2, -2)
	ic.border:SetColorTexture(0, 0, 0, 1)
	ic.tex = ic:CreateTexture(nil, "ARTWORK")
	ic.tex:SetAllPoints()
	ic.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	ic.text = ic:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	ic.text:SetPoint("CENTER", 0, 0)

	local ag = ic.tex:CreateAnimationGroup()
	ag:SetLooping("BOUNCE")
	local a = ag:CreateAnimation("Alpha")
	a:SetFromAlpha(1); a:SetToAlpha(0.15); a:SetDuration(0.45)
	ic.blink = ag

	-- fallback B: an invisible status bar whose fill end carries the icon
	-- (inset by half an icon, see T:PosX)
	local track = CreateFrame("StatusBar", nil, bar)
	track:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
	track:GetStatusBarTexture():SetAlpha(0)
	track:Hide()
	ic.track = track

	-- "ready" pop: a ghost copy that grows, brightens and fades out
	local pop = CreateFrame("Frame", nil, bar)
	pop:SetFrameLevel(bar:GetFrameLevel() + 8)
	pop.tex = pop:CreateTexture(nil, "ARTWORK")
	pop.tex:SetAllPoints()
	pop.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	pop.glow = pop:CreateTexture(nil, "OVERLAY")
	pop.glow:SetAllPoints()
	pop.glow:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	pop.glow:SetBlendMode("ADD")
	local pg = pop:CreateAnimationGroup()
	local sc = pg:CreateAnimation("Scale")
	sc:SetScaleFrom(1, 1); sc:SetScaleTo(1.6, 1.6)
	sc:SetOrigin("CENTER", 0, 0)
	sc:SetDuration(0.4); sc:SetSmoothing("OUT")
	local fade = pg:CreateAnimation("Alpha")
	fade:SetFromAlpha(1); fade:SetToAlpha(0)
	fade:SetDuration(0.4); fade:SetSmoothing("IN")
	pg:SetScript("OnFinished", function() pop:Hide() end)
	local gg = pop.glow:CreateAnimationGroup()
	local bright = gg:CreateAnimation("Alpha")
	bright:SetFromAlpha(0.2); bright:SetToAlpha(1)
	bright:SetDuration(0.25)
	pop.anim, pop.glowAnim = pg, gg
	pop:Hide()
	ic.pop = pop

	ic:Hide()
	self.icons[i] = ic
	self:SizeIcon(ic)
	return ic
end

function T:SizeIcon(ic)
	local s = self.db.iconSize
	ic:SetSize(s, s)
	ic.curSize = s
	ic.pop:SetSize(s, s)
	ic.track:ClearAllPoints()
	ic.track:SetPoint("TOPLEFT", self.bar, "TOPLEFT", s / 2, 0)
	ic.track:SetPoint("BOTTOMRIGHT", self.bar, "BOTTOMRIGHT", -s / 2, 0)
	ic.track:SetMinMaxValues(0, self.db.horizon)
	local font = ic.text:GetFont()
	if font then ic.text:SetFont(font, math.max(10, math.floor(s * 0.45)), "OUTLINE") end
end

function T:Enable()
	self.db = ns.db.timeline
	self.db.learned = self.db.learned or {}
	self.icons = {}
	self.cd = {}

	if C_CurveUtil and C_CurveUtil.CreateCurve and Enum.LuaCurveType then
		-- remaining 0 -> invisible, anything above -> visible
		local c = C_CurveUtil.CreateCurve()
		c:SetType(Enum.LuaCurveType.Step)
		c:AddPoint(0, 0)
		c:AddPoint(0.001, 1)
		self.alphaCurve = c
	end

	local f = CreateFrame("Frame", "ProtadinTimelineFrame", UIParent)
	self.frame = f
	ns.MakeMovable(f, self.db, L["Protadin: timeline"])

	local bar = CreateFrame("Frame", nil, f)
	bar:SetAllPoints()
	self.bar = bar

	bar.line = bar:CreateTexture(nil, "BACKGROUND")
	bar.line:SetColorTexture(1, 1, 1, 0.25)
	bar.line:SetPoint("LEFT")
	bar.line:SetPoint("RIGHT")
	bar.line:SetHeight(2)

	bar.now = bar:CreateTexture(nil, "BORDER")
	bar.now:SetColorTexture(0.96, 0.55, 0.73, 0.9)
	bar.now:SetWidth(2)
	bar.ticks = {}

	-- "press this": the most important ready spell, at "now"
	local nx = CreateFrame("Frame", nil, bar)
	nx:SetFrameLevel(bar:GetFrameLevel() + 7)
	nx.border = nx:CreateTexture(nil, "BACKGROUND")
	-- same border width as the timeline icons, so the hand-over doesn't jump
	nx.border:SetPoint("TOPLEFT", -2, 2)
	nx.border:SetPoint("BOTTOMRIGHT", 2, -2)
	nx.border:SetColorTexture(1, 0.82, 0, 1)
	nx.tex = nx:CreateTexture(nil, "ARTWORK")
	nx.tex:SetAllPoints()
	nx.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	local fa = nx:CreateAnimationGroup()
	local fi = fa:CreateAnimation("Alpha")
	fi:SetFromAlpha(0); fi:SetToAlpha(1); fi:SetDuration(0.15)
	nx.fadeIn = fa
	-- pulsing gold glow around it, like a proc highlight on the action bars.
	-- It sits on its own frame so it can fade in separately from the pulse.
	local gf = CreateFrame("Frame", nil, nx)
	gf:SetAllPoints()
	gf:SetFrameLevel(nx:GetFrameLevel() + 1)
	local gfa = gf:CreateAnimationGroup()
	local gfi = gfa:CreateAnimation("Alpha")
	gfi:SetFromAlpha(0); gfi:SetToAlpha(1); gfi:SetDuration(0.25)
	nx.glowIn = gfa
	nx.glow = gf:CreateTexture(nil, "OVERLAY")
	nx.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
	nx.glow:SetBlendMode("ADD")
	nx.glow:SetVertexColor(1, 0.82, 0.2)
	nx.glow:SetPoint("CENTER")
	local ga = nx.glow:CreateAnimationGroup()
	ga:SetLooping("BOUNCE")
	local gp = ga:CreateAnimation("Alpha")
	gp:SetFromAlpha(1); gp:SetToAlpha(0.35); gp:SetDuration(0.6)
	nx.pulse = ga
	nx:SetScript("OnShow", function() ga:Play() end)
	nx:SetScript("OnHide", function() ga:Stop() end)
	nx:Hide()
	self.nextIcon = nx

	self:BuildCandidates()
	self:ApplySettings()
	self:RebuildEntries()
	self:ScanSeal()
	self:OnLockChanged()

	f:RegisterEvent("PLAYER_REGEN_DISABLED")
	f:RegisterEvent("PLAYER_REGEN_ENABLED")
	f:RegisterEvent("SPELLS_CHANGED")
	f:RegisterEvent("SPELL_UPDATE_COOLDOWN")
	self.isTalentEvent = {}
	for _, ev in ipairs(TALENT_EVENTS) do
		if pcall(f.RegisterEvent, f, ev) then self.isTalentEvent[ev] = true end
	end
	self.talentsFrom = GetTime() + 5
	f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
	self.isSealAura = function(a)
		return ns.AuraFromPlayer(a) and (ns.IsSealName(a.name) or T:LooksLikeSeal(a)) or false
	end
	self.isSealInstance = function(id) return id == T.sealInstance end
	f:RegisterEvent("PLAYER_TARGET_CHANGED")
	f:RegisterUnitEvent("UNIT_AURA", "player")
	f:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
	f:SetScript("OnEvent", function(_, event, ...) T:OnEvent(event, ...) end)

	-- runs even while the timeline is hidden, so readable cooldowns are
	-- captured right up to the moment combat starts
	self.driver = CreateFrame("Frame")
	self.driver:SetScript("OnUpdate", function() T:Update() end)
end

-- x of an icon's centre for `sec` seconds remaining. Icons travel between
-- half an icon from each end, so they never stick out of the timeline.
function T:PosX(sec)
	local db = self.db
	local half = db.iconSize / 2
	return half + math.min(math.max(sec, 0), db.horizon) / db.horizon * (db.width - db.iconSize)
end

function T:ApplySettings()
	local db = self.db
	local f, bar = self.frame, self.bar
	f:SetSize(db.width, db.iconSize)
	ns.ApplyPosition(f, db)
	local x0 = self:PosX(0)
	bar.now:ClearAllPoints()
	bar.now:SetPoint("TOP", bar, "TOPLEFT", x0, 4)
	bar.now:SetPoint("BOTTOM", bar, "BOTTOMLEFT", x0, -4)

	-- ticks every 2 seconds
	for _, t in ipairs(bar.ticks) do t.mark:Hide(); t.label:Hide() end
	local n = 0
	for sec = 2, db.horizon, 2 do
		n = n + 1
		local t = bar.ticks[n]
		if not t then
			t = { mark = bar:CreateTexture(nil, "BACKGROUND"), label = bar:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall") }
			t.mark:SetColorTexture(1, 1, 1, 0.35)
			t.mark:SetSize(1, 8)
			bar.ticks[n] = t
		end
		local x = self:PosX(sec)
		t.mark:ClearAllPoints(); t.mark:SetPoint("CENTER", bar, "LEFT", x, 0); t.mark:Show()
		t.label:ClearAllPoints(); t.label:SetPoint("TOP", bar, "BOTTOMLEFT", x, -2); t.label:SetText(sec); t.label:Show()
	end

	for _, ic in ipairs(self.icons) do self:SizeIcon(ic) end
	-- "press this" is 20% bigger; its centre moves right just enough to keep
	-- it inside the timeline's left edge
	local nsz = db.iconSize * NEXT_SCALE
	self.nextIcon:SetSize(nsz, nsz)
	self.nextIcon.glow:SetSize(nsz * 1.9, nsz * 1.9)
	self.nextIcon:ClearAllPoints()
	self.nextIcon:SetPoint("CENTER", bar, "LEFT", math.max(x0, nsz / 2), 0)
	self:UpdateVisibility()
end

function T:OnLockChanged()
	self.frame.mover:SetShown(not ns.db.locked)
	self:UpdateVisibility()
end

function T:UpdateVisibility()
	local db = self.db
	self.frame:SetShown(db.enabled and (self.inCombat or not db.onlyInCombat or not ns.db.locked) or false)
end

function T:OnEvent(event, ...)
	-- something changed: ask the client again on the next frame (auras don't
	-- change cooldowns, only what's usable)
	if event ~= "UNIT_AURA" then self.queryTick = (self.queryTick or 0) + 1 end
	self.usableTick = (self.usableTick or 0) + 1
	if event == "SPELL_UPDATE_COOLDOWN" then return end
	if self.isTalentEvent[event] then
		-- talents can change cooldowns: forget the learned durations, the first
		-- cast out of combat learns them again (until then: the base cooldown).
		-- The client also sends these at login - ignore the first seconds.
		if GetTime() > (self.talentsFrom or 0) then wipe(self.db.learned) end
		self:RefreshTooltipCooldowns()
		return
	end
	if event == "PLAYER_EQUIPMENT_CHANGED" then self:RefreshTooltipCooldowns() return end
	if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then self.cdSecret = nil end
	if event == "PLAYER_REGEN_DISABLED" then
		self.inCombat = true
		self.castsSecret = nil
		self:UpdateVisibility()
	elseif event == "PLAYER_REGEN_ENABLED" then
		self.inCombat = false
		self:UpdateVisibility()
		self:ScanSeal()
		self:AutoAdapt()
	elseif event == "SPELLS_CHANGED" then
		ns.ClearSpellCache()
		self:BuildCandidates(); self:RebuildEntries()
	elseif event == "UNIT_AURA" then
		local _, info = ...
		if ns.AuraUpdateTouches(info, self.isSealAura, self.isSealInstance) then
			self:ScanSeal(ns.RemovedAuraIDs(info))
		end
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		local _, _, spellID = ...
		if spellID == nil then return end
		if ns.IsSecret(spellID) then
			self.castsSecret = true -- can't track casts: use fallback B
			return
		end
		self.castsSecret = false
		self:OnCast(spellID)
	end
end

-- talents or gear changed: the tooltip shows the new cooldown (the client
-- may update it a moment later, so read again after a short delay too)
function T:RefreshTooltipCooldowns()
	local function read()
		for _, e in ipairs(self.entries or {}) do
			if not e.isSeal then e.tipCD = ns.TooltipCooldown(e.id) end
		end
	end
	read()
	C_Timer.After(1, read)
end

function T:OnCast(spellID)
	local name, icon = ns.GetSpellInfo(spellID)
	if not name then return end
	local now = GetTime()
	if ns.IsSealName(name) then
		self:NoteSeal(name)
		self.sealSpellId = spellID
		local se = self.byName and self.byName[SEAL_KEY]
		if se then
			se.id, se.icon = spellID, icon
			self:LearnFromCast(se, now)
		end
		-- a real aura scan refines this if aura data is readable
		self.sealExpires = now + self.db.sealDuration
		self.sealIcon = icon
		self.sealInstance = nil
		C_Timer.After(0.2, function() T:ScanSeal() end)
		return
	end
	local e = self.byName and self.byName[name]
	if not e then return end
	self:LearnFromCast(e, now) -- before e's own cooldown starts
	-- tooltip first: it already counts talents and gear in
	local dur = e.tipCD or self.db.learned[name] or e.baseCD
	if dur and dur > 1.5 then
		self.cd[name] = { start = now, dur = dur }
	end
end

---------------------------------------------------------------------------
-- Priority from your play
---------------------------------------------------------------------------
T.LEARN_MIN = 20     -- choices needed before an order is offered
local MIN_PAIR = 5   -- (weighted) comparisons needed before a pair counts
local Z = 1.645      -- ~90% confidence for "this pair has a clear winner"
local OVERTURN = 0.6 -- the lower spell of a pair moves up only when its Wilson
                     -- lower bound is above this; pairs near 50/50 stay put
local HALF_LIFE = 500 -- choices after which old choices weigh half as much
local DECAY = 0.5 ^ (1 / HALF_LIFE)

-- how many choices actually count: each choice ages all earlier ones by DECAY,
-- so the total weight of n choices is 1 + d + d^2 + ... = (1 - d^n) / (1 - d),
-- which levels off at about 720 however long you play
function T:EffectiveChoices(n)
	n = n or (self.db.learn and self.db.learn.choices) or 0
	return (1 - DECAY ^ n) / (1 - DECAY)
end

-- lower bound of the Wilson score interval: a win rate we can trust given
-- how few comparisons there are (6 of 10 -> ~0.34, 378 of 442 -> ~0.83)
local function WilsonLow(won, n)
	if n <= 0 then return 0 end
	local p = won / n
	local z2 = Z * Z
	return (p + z2 / (2 * n) - Z * math.sqrt((p * (1 - p) + z2 / (4 * n)) / n)) / (1 + z2 / n)
end
T.WilsonLow = WilsonLow

-- a rotation spell was cast in combat: if other rotation spells were ready
-- too, the player preferred this one over each of them
function T:LearnFromCast(e, now)
	if not self.inCombat then return end
	local learn = self.db.learn

	-- which rotation spells are off cooldown, and which of those can be cast
	local readyNames, usable = {}, {}
	for _, o in ipairs(self.entries or {}) do
		if o ~= e then
			local rem, missing, secretDur = self:Remaining(o, now)
			if secretDur == nil and rem and rem <= 0 then
				readyNames[#readyNames + 1] = o.name
				usable[o.name] = ns.IsUsable(o.id) and ns.InRange(o.id) or false
			end
		end
	end
	readyNames[#readyNames + 1] = e.name
	usable[e.name] = true -- it was just cast
	self:NoteAvailability(readyNames, usable)

	-- pressing exactly what "Suggest next" showed is following the hint, not the
	-- player's own choice; counting it would make the order confirm itself
	local nx = self.nextIcon
	if self.db.showNext and nx and nx:IsShown() and nx.key == e.key then return end
	-- situational spells (usable only now and then) stay where the player put them
	if self:IsSituational(e.name) then return end
	local others = {}
	for _, n in ipairs(readyNames) do
		if n ~= e.name and usable[n] and not self:IsSituational(n) then others[#others + 1] = n end
	end
	if #others == 0 then return end
	learn.choices = (learn.choices or 0) + 1
	-- everything learned so far gets a little older (half weight after HALF_LIFE choices)
	for _, row in pairs(learn.wins) do
		for b, v in pairs(row) do
			v = v * DECAY
			row[b] = v >= 0.01 and v or nil
		end
	end
	local w = learn.wins[e.name] or {}
	learn.wins[e.name] = w
	for _, n in ipairs(others) do w[n] = (w[n] or 0) + 1 end
end

-- How often is a spell castable when it's off cooldown? Exorcism (undead and
-- demons only) and Hammer of Wrath (target below 20%) mostly are not: such
-- "situational" spells are left out of learning and keep their place.
local SITUATIONAL_SHARE = 0.5 -- castable in less than half of the cases
local SITUATIONAL_MIN = 10    -- (weighted) observations needed to decide

function T:NoteAvailability(names, usable)
	local learn = self.db.learn
	learn.avail = learn.avail or {}
	for _, a in pairs(learn.avail) do
		a.ready, a.usable = a.ready * DECAY, a.usable * DECAY
	end
	for _, n in ipairs(names) do
		local a = learn.avail[n] or { ready = 0, usable = 0 }
		learn.avail[n] = a
		a.ready = a.ready + 1
		if usable[n] then a.usable = a.usable + 1 end
	end
end

function T:IsSituational(name)
	local avail = self.db.learn.avail
	local a = avail and avail[name]
	if not a or a.ready < SITUATIONAL_MIN then return false end
	return a.usable / a.ready < SITUATIONAL_SHARE
end

-- an entry for chat: a clickable spell link (the seal: the most used seal,
-- plain "Seal" until there is any data)
function T:ChatName(name)
	if name == SEAL_KEY then
		local top = self:SealStats()[1]
		if top and ns.spellbook and ns.spellbook[top.name] then return ns.SpellLink(top.name) end
		return self:DisplayName(name)
	end
	local e = self.byName and self.byName[name]
	return ns.SpellLink((e and e.id) or name)
end

-- an order for chat, as links
function T:ChatOrder(order)
	local out = {}
	for i, n in ipairs(order) do out[i] = self:ChatName(n) end
	return table.concat(out, " > ")
end

-- an order as text; situational spells in [brackets]
function T:FormatOrder(order)
	local out = {}
	for i, n in ipairs(order) do
		local d = self:DisplayName(n)
		out[i] = self:IsSituational(n) and ("[" .. d .. "]") or d
	end
	return table.concat(out, " > ")
end

-- enabled spells ordered by the player's choices; returns names, #choices.
-- Situational spells keep their current positions; the rest are ordered by
-- the learned choices around them.
-- The current order stands; a pair swaps only when the lower spell was picked
-- over the upper one clearly: at least MIN_PAIR comparisons and a Wilson lower
-- bound above OVERTURN. Swapping back needs the same in the other direction,
-- so pairs near 50/50 don't flip back and forth. Ties keep the current order.
function T:LearnedOrder()
	local learn = self.db.learn
	local wins = learn.wins
	local function w(a, b) return (wins[a] and wins[a][b]) or 0 end
	local names, cur, score = {}, {}, {}
	local fixed = {} -- position -> situational spell
	local enabled = self:EnabledByPriority()
	for i, s in ipairs(enabled) do
		cur[s.name] = i
		if self:IsSituational(s.name) then fixed[i] = s.name
		else names[#names + 1] = s.name end
	end
	for _, a in ipairs(names) do
		score[a] = 0
		for _, b in ipairs(names) do
			if a ~= b then
				local ab, ba = w(a, b), w(b, a)
				local n = ab + ba
				local clear = n >= MIN_PAIR
				local aWins
				if cur[a] < cur[b] then -- a is above b now: stays unless b clearly wins
					aWins = not (clear and WilsonLow(ba, n) > OVERTURN)
				else -- a is below b: moves up only if it clearly wins
					aWins = clear and WilsonLow(ab, n) > OVERTURN
				end
				if aWins then score[a] = score[a] + 1 end
			end
		end
	end
	table.sort(names, function(a, b)
		if score[a] ~= score[b] then return score[a] > score[b] end
		return cur[a] < cur[b]
	end)
	local order, k = {}, 1
	for i = 1, #enabled do
		if fixed[i] then order[i] = fixed[i]
		else order[i] = names[k]; k = k + 1 end
	end
	return order, learn.choices or 0
end

-- the shortest list of swaps that turns `cur` into `new` ("A <-> B")
local function Swaps(cur, new)
	local a, pos, out = {}, {}, {}
	for i, n in ipairs(cur) do a[i], pos[n] = n, i end
	for i = 1, #new do
		if a[i] ~= new[i] and pos[new[i]] then
			local j = pos[new[i]]
			out[#out + 1] = T:ChatName(new[i]) .. " <-> " .. T:ChatName(a[i])
			a[i], a[j] = a[j], a[i]
			pos[a[i]], pos[a[j]] = i, j
		end
	end
	return out
end
T.Swaps = Swaps

local AUTO_EVERY = 25 -- new choices between automatic adjustments
local AUTO_MIN = 100  -- after a fresh start, the order is left alone until then

-- after a fight: if enough new choices came in and the learned order differs,
-- apply it and say in one chat line what moved
function T:AutoAdapt()
	if not self.db.autoAdapt then return end
	local learn = self.db.learn
	local n = learn.choices or 0
	if n < AUTO_MIN then return end
	if n - (learn.lastAutoChoices or 0) < AUTO_EVERY then return end
	learn.lastAutoChoices = n
	local order = self:LearnedOrder()
	local cur = {}
	for i, s in ipairs(self:EnabledByPriority()) do cur[i] = s.name end
	local swaps = Swaps(cur, order)
	if #swaps == 0 then return end
	self:ApplyLearned()
	local msg = L["priority %s."]:format(table.concat(swaps, ", "))
	-- the first adjustment after each login also says how to turn it off
	if not self.offHintShown then
		self.offHintShown = true
		msg = msg .. " " .. L["Turn it off in %s."]:format(ns.OptionsLink())
	end
	ns.Print(msg)
	if ns.RefreshOptions then ns.RefreshOptions() end
end

function T:ApplyLearned()
	local order = self:LearnedOrder()
	local listed, out = {}, {}
	for _, n in ipairs(order) do out[#out + 1] = n; listed[n] = true end
	for _, s in ipairs(self:OrderedCandidates()) do
		if not listed[s.name] then out[#out + 1] = s.name end
	end
	self.db.priority = out
	self:RebuildEntries()
end

-- minimap left-click: apply the learned order, telling the player what happened
function T:ApplyLearnedFromUI()
	local order, n = self:LearnedOrder()
	if n < self.LEARN_MIN then
		ns.Print(L["Not enough data yet: %d of %d choices."]:format(n, self.LEARN_MIN))
		return
	end
	local same = true
	for i, s in ipairs(self:EnabledByPriority()) do if order[i] ~= s.name then same = false end end
	if same then
		ns.Print(L["Priority already matches your play."])
		return
	end
	self:ApplyLearned()
	ns.Print(L["Priority applied: %s"]:format(self:ChatOrder(order)))
	if ns.RefreshOptions then ns.RefreshOptions() end
end

function T:ForgetLearned()
	self.db.learn = { wins = {}, choices = 0 }
end

---------------------------------------------------------------------------
-- Seal (any seal counts)
---------------------------------------------------------------------------
-- a seal we don't know by ID: our own 30-second buff from a spell in our
-- spellbook that is none of the other paladin buffs
function T:LooksLikeSeal(a)
	local dur, name = a.duration, a.name
	if not dur or ns.IsSecret(dur) or math.abs(dur - self.db.sealDuration) > 0.6 then return false end
	if not ns.IsKnownName(name) then return false end
	return not (ns.BlessingBase(name) or ns.IsAuraName(name) or name == ns.N.RF)
end

-- removed: optional set of aura instance ids that just went away
function T:ScanSeal(removed)
	local found, secret
	local readable = ns.ForEachPlayerAura(function(a)
		if ns.IsSecret(a.name) then secret = true return true end
		if ns.AuraFromPlayer(a) then
			if ns.IsSealName(a.name) then found = a return true end
			if self:LooksLikeSeal(a) then
				-- unknown seal (other language / new Forever seal): remember it
				self.db.learnedSeals[a.name] = true
				found = a
				return true
			end
		end
	end)
	if found then
		local exp = found.expirationTime
		if exp and not ns.IsSecret(exp) and exp > 0 then self.sealExpires = exp end
		self.sealIcon = found.icon
		self.sealInstance = found.auraInstanceID
		if found.spellId and not ns.IsSecret(found.spellId) then self.sealSpellId = found.spellId end
	elseif secret or not readable then
		local inst = self.sealInstance
		if inst and ((removed and removed[inst]) or ns.AuraExists(inst) == false) then
			self.sealExpires = nil
		end
	else
		self.sealExpires = nil
	end
	if not self.sealIcon or not self.sealSpellId then
		for name, s in pairs(ns.spellbook or {}) do
			if ns.IsSealName(name) then
				self.sealIcon = self.sealIcon or s.icon
				self.sealSpellId = self.sealSpellId or s.spellID
				break
			end
		end
	end
	local se = self.byName and self.byName[SEAL_KEY]
	if se then se.icon, se.id = self.sealIcon, self.sealSpellId end
end

---------------------------------------------------------------------------
-- Remaining time
---------------------------------------------------------------------------
-- returns: remaining seconds (number; for the seal: time left on it, 0 when no
-- seal is up = "ready"), or nil + false + durationObject when only fallback B
-- can show it
-- The client is asked about cooldowns only when something changed (any event
-- of ours: casts, SPELL_UPDATE_COOLDOWN, combat start / end, spells, target) -
-- never every frame: each answer is a new table, so asking every frame made
-- megabytes of garbage a minute. Between events the remaining time is worked
-- out from the stored end time. Usable / in range (plain true/false answers,
-- no garbage) are asked USABLE_EVERY seconds.
local USABLE_EVERY = 0.1

function T:Remaining(e, now)
	if e.isSeal then
		if self.sealExpires and self.sealExpires > now then return self.sealExpires - now end
		return 0
	end
	local tick = self.queryTick or 0
	if e.qTick ~= tick then
		e.qTick = tick
		local rem, _, dur = self:QueryRemaining(e, now)
		e.qSecret = rem == nil
		e.qDur = dur
		e.qEnd = rem and now + rem or nil
	end
	if e.qSecret then return nil, false, e.qDur end
	local rem = e.qEnd - now
	return rem > 0 and rem or 0
end

function T:QueryRemaining(e, now)
	-- in combat the answers are secret: after the first one, don't ask (each
	-- answer is a new table) - our own timers know the rest
	local info = not (self.inCombat and self.cdSecret) and ns.GetCooldown(e.id) or nil
	if info and self.inCombat and (ns.IsSecret(info.startTime) or ns.IsSecret(info.duration)) then
		self.cdSecret = true
	end
	local start, dur = info and info.startTime, info and info.duration
	if info and not ns.IsSecret(start) and not ns.IsSecret(dur) then
		-- readable: this is the truth, keep our tracker in sync with it
		local gcd = info.isOnGCD
		local onGCD = (gcd ~= nil and not ns.IsSecret(gcd) and gcd) or (dur and dur <= 1.5)
		if not start or start == 0 or not dur or dur == 0 or onGCD then
			self.cd[e.name] = nil
			return 0
		end
		local c = self.cd[e.name]
		if c then c.start, c.dur = start, dur else self.cd[e.name] = { start = start, dur = dur } end
		local learned = self.db.learned[e.name]
		if not learned or math.abs(learned - dur) > 0.05 then
			self.db.learned[e.name] = math.floor(dur * 10 + 0.5) / 10
		end
		return math.max(0, start + dur - now)
	end

	-- secret
	if self.castsSecret then
		return nil, false, ns.GetCooldownDuration(e.id) or false
	end
	local c = self.cd[e.name]
	if c then
		local rem = c.start + c.dur - now
		if rem > 0 then return rem end
		self.cd[e.name] = nil
	end
	return 0
end

---------------------------------------------------------------------------
-- Per-frame update
---------------------------------------------------------------------------
local moving = {}

local function Style(ic, mode)
	if ic.mode == mode then return end
	ic.mode = mode
	if mode == "missing" then
		ic.border:SetColorTexture(1, 0.1, 0.1, 1)
		if not ic.blink:IsPlaying() then ic.blink:Play() end
	else
		if ic.blink:IsPlaying() then ic.blink:Stop() end
		-- "soon" colours its border gradually in T:Update
		if mode ~= "soon" then ic.border:SetColorTexture(0, 0, 0, 1) end
	end
	ic.tex:SetDesaturated(mode == "far")
	if mode ~= "secret" and ic.track:IsShown() then ic.track:Hide() end
end

local function SetIconSize(ic, size)
	if not ic.curSize or math.abs(ic.curSize - size) > 0.05 then
		ic:SetSize(size, size)
		ic.curSize = size
	end
end

local justReady = {}
local function ByX(a, b) return a.x < b.x end

function T:Update()
	if not self.entries or not self.db.enabled then return end
	local shown = self.frame:IsShown()
	local db = self.db
	local now, S, H = GetTime(), db.iconSize, db.horizon
	local SOON = 1.5 -- one global cooldown
	self.queryTick = self.queryTick or 0
	if now - (self.lastUsable or 0) >= USABLE_EVERY then
		self.lastUsable = now
		self.usableTick = (self.usableTick or 0) + 1
	end
	-- hidden: nothing to draw; only look again when the client may have new
	-- answers (keeps learned cooldown durations up to date)
	if not shown then
		if self.hiddenTick == self.queryTick then return end
		self.hiddenTick = self.queryTick
	else
		self.hiddenTick = nil
	end
	wipe(moving)
	wipe(justReady)
	local nextEntry

	for i, e in ipairs(self.entries) do
		local ic = self.icons[i]
		local rem, _, secretDur = self:Remaining(e, now)

		if not shown then
			ic:Hide()
			ic.wasMoving = false
		elseif secretDur ~= nil then
			-- fallback B: status bar positions the icon, curve hides it at 0
			ic.wasMoving = false
			SetIconSize(ic, S)
			if ic.mode ~= "secret" then
				Style(ic, "secret")
				ic.track:Show()
				ic:ClearAllPoints()
				ic:SetPoint("CENTER", ic.track:GetStatusBarTexture(), "RIGHT", 0, 0)
				ic.text:SetText("")
			end
			ic:Show()
			if secretDur then
				ic.track:SetValue(secretDur:GetRemainingDuration())
				if self.alphaCurve then ic:SetAlpha(secretDur:EvaluateRemainingDuration(self.alphaCurve)) end
			else
				ic.track:SetValue(0)
				ic:SetAlpha(0)
			end
		elseif rem <= 0 then
			-- ready: hidden (visible on the action bars anyway). If it just came off
			-- cooldown it either turns into "press this" or pops (decided below).
			if ic.wasMoving then justReady[#justReady + 1] = ic end
			ic.wasMoving = false
			ic:Hide()
			-- entries are in priority order: the first usable ready one is "press this"
			-- (the seal: whenever no seal is up)
			if not nextEntry then
				-- asked once per query tick, like cooldowns
				if e.uTick ~= self.usableTick then
					e.uTick = self.usableTick
					if e.isSeal then e.uOk = not e.id or ns.IsUsable(e.id)
					else e.uOk = ns.IsUsable(e.id) and ns.InRange(e.id) end
				end
				if e.uOk then nextEntry = e end
			end
		else
			if e.isSeal and self.sealIcon then ic.tex:SetTexture(self.sealIcon) end
			ic.rem = rem
			ic.x = self:PosX(rem)
			moving[#moving + 1] = ic
		end
	end

	-- "press this"
	local nx = self.nextIcon
	local showNx = shown and db.showNext and nextEntry
	-- a spell that just arrived at "now" and becomes "press this" hands over
	-- without a pop: same place, same size, so it reads as one icon
	local handover = false
	for _, ic in ipairs(justReady) do
		if showNx and ic.entry == nextEntry then handover = true
		else self:Pop(ic) end
	end
	if showNx then
		if nx.key ~= nextEntry.key then
			nx.key = nextEntry.key
			nx.tex:SetTexture(nextEntry.isSeal and self:PopularSealIcon() or nextEntry.icon)
			nx.fadeIn:Stop()
			if handover then nx:SetAlpha(1) else nx.fadeIn:Play() end
			nx.glowIn:Stop(); nx.glowIn:Play()
		end
		nx:Show()
	else
		nx.key = nil
		nx:Hide()
	end
	if not shown then return end

	-- cooling down: positioned by remaining time; overlapping icons become translucent;
	-- spells ready within one GCD grow smoothly and their border turns gold ("next up")
	table.sort(moving, ByX)
	for k, ic in ipairs(moving) do
		local far = ic.rem > H
		local soon = db.highlightSoon and ic.rem <= SOON
		Style(ic, far and "far" or soon and "soon" or "cd")
		-- p goes 0 -> 1 over the last SOON seconds, so size and colour change smoothly
		local p = soon and math.min(1, math.max(0, (SOON - ic.rem) / SOON)) or 0
		SetIconSize(ic, S * (1 + (SOON_SCALE - 1) * p))
		if soon then ic.border:SetColorTexture(p, 0.82 * p, 0, 1) end
		local prev, nxt = moving[k - 1], moving[k + 1]
		local overlap = (prev and ic.x - prev.x < S * 0.9) or (nxt and nxt.x - ic.x < S * 0.9)
		ic:SetAlpha(far and 0.45 or soon and 1 or overlap and 0.6 or 1)
		ic:SetFrameLevel(self.bar:GetFrameLevel() + (soon and 6 or 5))
		-- while growing, never cross the left edge: at 0 s it sits exactly where
		-- "press this" appears
		local x = math.max(ic.x, (ic.curSize or S) / 2)
		ic.lastX = x
		ic:ClearAllPoints()
		ic:SetPoint("CENTER", self.bar, "LEFT", x, 0)
		local txt = ns.FormatTime(ic.rem)
		if ic.lastText ~= txt then ic.lastText = txt; ic.text:SetText(txt) end
		ic:Show()
		ic.wasMoving = true
	end
end

function T:Pop(ic)
	ic.wasMoving = false
	local pop = ic.pop
	local size = ic.curSize or self.db.iconSize
	pop:SetSize(size, size) -- same size the icon had grown to
	pop.tex:SetTexture(ic.tex:GetTexture())
	pop.glow:SetTexture(ic.tex:GetTexture())
	pop:ClearAllPoints()
	pop:SetPoint("CENTER", self.bar, "LEFT", ic.lastX or self:PosX(0), 0)
	pop.anim:Stop(); pop.glowAnim:Stop()
	pop:Show()
	pop.anim:Play(); pop.glowAnim:Play()
end

function T:Debug()
	local now = GetTime()
	local castMode = self.castsSecret == nil and "unknown" or self.castsSecret and "SECRET (fallback B)" or "readable"
	ns.Print("timeline entries (cast events:", castMode .. "):")
	for _, e in ipairs(self.entries or {}) do
		local info = not e.isSeal and ns.GetCooldown(e.id)
		local apiSecret = info and ns.IsSecret(info.startTime)
		local rem, missing, secretDur = self:Remaining(e, now)
		local state = secretDur ~= nil and "fallback B" or ("%.1f"):format(rem or 0)
		ns.Print("  ", e.isSeal and "Seal" or e.name, e.id or "", state,
			apiSecret and "(api secret, own timer)" or "",
			e.name and ("cd=" .. tostring(self.db.learned[e.name] or e.baseCD or "?")
				.. " tip=" .. tostring(e.tipCD)) or "",
			e.id and ns.DescribeUsable(e.id) or "")
	end
	local ctype = UnitExists("target") and UnitCreatureType("target")
	ns.Print("  target:", UnitExists("target") and (ns.IsSecret(ctype) and "SECRET" or tostring(ctype)) or "none",
		"  press-this:", tostring(self.nextIcon.key))
	ns.Print("  cooldown text patterns:", ns.CooldownPatternInfo())
	local c = {}
	for _, s in ipairs(self.candidates or {}) do c[#c + 1] = s.name end
	ns.Print("  candidates:", table.concat(c, ", "))
end
