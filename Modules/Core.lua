local ADDON, ns = ...

ns.modules = {}

ns.defaults = {
	locked = true, -- /protadin unlock (or the options) to move the frames
	minimap = { hide = false }, -- LibDBIcon keeps its position here too
	buffs = {
		point = { "TOPRIGHT", "TOPRIGHT", -30, -230 }, -- right side, under the minimap
		enabled = true,
		iconSize = 32,
		scale = 1,
		chat = true,
		blessingOn = true, auraOn = true, rfOn = true, trackingOn = true, foodOn = true, bagOn = true, campOn = true,
		-- blessing / aura / tracking: chosen names, filled on first login
	},
	timeline = {
		point = { "CENTER", "CENTER", 0, -200 },
		enabled = true,
		onlyInCombat = false,  -- new installs see the timeline; the welcome message points to this option
		width = 320,
		iconSize = 28,
		scale = 1,
		horizon = 10,
		sealDuration = 30,
		seal = true,
		showNext = true,       -- "press this": best ready spell at "now"
		highlightSoon = true,  -- enlarge spells ready within one GCD
		priority = {},         -- spell names, most important first
		-- "from your play": wins[A][B] = times A was cast while B was also ready
		learn = { wins = {}, choices = 0 },
		announceStyle = true,  -- chat notice when the learned order changes notably
		spells = {}, -- [spellName] = true/false; missing entry -> ns.defaultTimelineSpells
		learnedSeals = {}, -- seal names discovered at runtime (any locale)
	},
}

-- Rotation spells enabled on the timeline by default; filled from spell IDs at login (Data.lua)
ns.defaultTimelineSpells = {}

---------------------------------------------------------------------------
-- Utils
---------------------------------------------------------------------------
function ns.Print(...)
	print("|cfff58cbaProtadin|r:", ...)
end

-- Midnight-engine "secret values": unreadable in combat on some clients
ns.IsSecret = _G.issecretvalue or function() return false end

function ns.GetSpellInfo(spell)
	if not spell then return end
	if C_Spell and C_Spell.GetSpellInfo then
		local info = C_Spell.GetSpellInfo(spell)
		if info then return info.name, info.iconID, info.spellID end
		return
	end
	local name, _, icon, _, _, _, id = GetSpellInfo(spell)
	return name, icon, id
end

-- returns table { startTime, duration, isEnabled, isOnGCD } or nil
function ns.GetCooldown(spellID)
	if C_Spell and C_Spell.GetSpellCooldown then
		return C_Spell.GetSpellCooldown(spellID)
	end
	local s, d, e = GetSpellCooldown(spellID)
	if s then return { startTime = s, duration = d, isEnabled = (e == 1 or e == true) } end
end

-- duration object for secret-safe display (Midnight API), or nil
function ns.GetCooldownDuration(spellID)
	if C_Spell and C_Spell.GetSpellCooldownDuration then
		return C_Spell.GetSpellCooldownDuration(spellID)
	end
end

-- can the spell be cast right now (target type, health threshold, mana)?
-- unknown / secret -> assume yes
function ns.IsUsable(spellID)
	local f = (C_Spell and C_Spell.IsSpellUsable) or IsUsableSpell
	if not f then return true end
	local ok, usable = pcall(f, spellID)
	if not ok or usable == nil or ns.IsSecret(usable) then return true end
	return usable and true or false
end

-- does the spell have a range at all (needs a target)? Consecration / Holy Shield don't.
function ns.HasRange(spellID)
	if C_Spell and C_Spell.SpellHasRange then
		local ok, r = pcall(C_Spell.SpellHasRange, spellID)
		if ok and r ~= nil and not ns.IsSecret(r) then return r and true or false end
	end
	if C_Spell and C_Spell.GetSpellInfo then
		local info = C_Spell.GetSpellInfo(spellID)
		local maxR = info and info.maxRange
		if maxR ~= nil and not ns.IsSecret(maxR) then return maxR > 0 end
	end
	if SpellHasRange then
		local ok, r = pcall(SpellHasRange, (ns.GetSpellInfo(spellID)))
		if ok and r ~= nil and not ns.IsSecret(r) then return r and true or false end
	end
	return false
end

-- is the current target valid and in range for the spell?
-- The client answers nil for a targeted spell when the target doesn't fit it
-- (Exorcism on a beast, Holy Strike on a friend), so nil there means "no".
-- No target / spell without range / secret answer -> true
function ns.InRange(spellID)
	if not UnitExists("target") then return true end
	local ok, r
	if C_Spell and C_Spell.IsSpellInRange then
		ok, r = pcall(C_Spell.IsSpellInRange, spellID, "target")
	elseif IsSpellInRange then
		ok, r = pcall(IsSpellInRange, (ns.GetSpellInfo(spellID)), "target")
	end
	if not ok or ns.IsSecret(r) then return true end
	if r == nil then return not ns.HasRange(spellID) end
	return r == true or r == 1
end

-- raw answers for /protadin debug
function ns.DescribeUsable(spellID)
	local function raw(f, ...)
		if not f then return "n/a" end
		local ok, a, b = pcall(f, ...)
		if not ok then return "error" end
		local function show(v)
			if ns.IsSecret(v) then return "SECRET" end
			return tostring(v)
		end
		return show(a) .. "/" .. show(b)
	end
	local usable = raw((C_Spell and C_Spell.IsSpellUsable) or IsUsableSpell, spellID)
	local range = C_Spell and C_Spell.IsSpellInRange and raw(C_Spell.IsSpellInRange, spellID, "target")
		or raw(IsSpellInRange, (ns.GetSpellInfo(spellID)), "target")
	return ("usable=%s range=%s hasRange=%s inRange=%s"):format(usable, range,
		tostring(ns.HasRange(spellID)), tostring(ns.InRange(spellID)))
end

function ns.GetBaseCooldown(spellID)
	if GetSpellBaseCooldown then
		local ms = GetSpellBaseCooldown(spellID)
		if ms and not ns.IsSecret(ms) then return ms end
	end
end

function ns.FormatTime(sec)
	if sec >= 3600 then return ns.L["%dh"]:format(math.ceil(sec / 3600)) end
	if sec >= 60 then return ns.L["%dm"]:format(math.ceil(sec / 60)) end
	if sec >= 1.5 then return ("%d"):format(math.ceil(sec)) end
	return ("%.1f"):format(sec)
end

-- Spellbook scan: list of { name, spellID, icon, isPassive }, one entry per name (highest rank wins)
function ns.ScanSpellbook()
	local byName, list = {}, {}
	local function add(name, id, icon, passive)
		if not name or not id then return end
		local e = byName[name]
		if not e then
			e = { name = name }
			byName[name] = e
			list[#list + 1] = e
		end
		e.spellID, e.icon, e.isPassive = id, icon, passive
	end

	if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines then
		local bank = Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
		for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
			local li = C_SpellBook.GetSpellBookSkillLineInfo(line)
			if li then
				for slot = li.itemIndexOffset + 1, li.itemIndexOffset + li.numSpellBookItems do
					local it = C_SpellBook.GetSpellBookItemInfo(slot, bank)
					if it and it.itemType == Enum.SpellBookItemType.Spell then
						add(it.name, it.spellID or it.actionID, it.iconID, it.isPassive)
					end
				end
			end
		end
	elseif GetNumSpellTabs then
		for tab = 1, GetNumSpellTabs() do
			local _, _, offset, num = GetSpellTabInfo(tab)
			for slot = offset + 1, offset + num do
				local kind, id = GetSpellBookItemInfo(slot, BOOKTYPE_SPELL or "spell")
				if kind == "SPELL" then
					local name = GetSpellBookItemName(slot, BOOKTYPE_SPELL or "spell")
					add(name, id, GetSpellTexture(id), IsPassiveSpell and IsPassiveSpell(id))
				end
			end
		end
	end
	ns.spellbook = byName
	return list
end

function ns.IsKnownName(name)
	return ns.spellbook and ns.spellbook[name] ~= nil
end

-- In instances / encounters the Midnight engine forbids addons from reading
-- auras at all: the query functions raise an error. Check before asking.
function ns.AurasRestricted()
	return (C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret()) and true or false
end

-- Calls fn(aura) for every helpful aura on the player. aura fields may be secret.
-- Returns false if auras can't be read right now (restricted), true otherwise.
function ns.ForEachPlayerAura(fn)
	if ns.AurasRestricted() then return false end
	if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
		local get = C_UnitAuras.GetAuraDataByIndex
		for i = 1, 40 do
			local ok, a = pcall(get, "player", i, "HELPFUL")
			if not ok then return false end -- restricted after all
			if not a then break end
			if fn(a) then break end
		end
	else
		for i = 1, 40 do
			local name, icon, _, _, duration, expirationTime, source, _, _, spellId = UnitAura("player", i, "HELPFUL")
			if not name then break end
			if fn({ name = name, icon = icon, duration = duration, expirationTime = expirationTime,
				sourceUnit = source, spellId = spellId }) then break end
		end
	end
	return true
end

-- true = aura still there, false = gone, nil = can't tell right now
function ns.AuraExists(instanceID)
	if not instanceID then return false end
	if not (C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID) then return nil end
	if ns.AurasRestricted() then return nil end
	local ok, a = pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, "player", instanceID)
	if not ok then return nil end
	return a ~= nil
end

-- aura instance ids removed in a UNIT_AURA update (readable even when aura
-- contents are not); returns a set or nil
function ns.RemovedAuraIDs(updateInfo)
	if type(updateInfo) ~= "table" then return nil end
	local ok, set = pcall(function()
		local ids = updateInfo.removedAuraInstanceIDs
		if not ids then return nil end
		local s
		for _, id in ipairs(ids) do
			if not ns.IsSecret(id) then
				s = s or {}
				s[id] = true
			end
		end
		return s
	end)
	return ok and set or nil
end

function ns.AuraFromPlayer(a)
	local src = a.sourceUnit
	if src ~= nil and not ns.IsSecret(src) and src == "player" then return true end
	local f = a.isFromPlayerOrPlayerPet
	if f ~= nil and not ns.IsSecret(f) then return f end
	return false
end

-- Minimap tracking types that come from spells: list of { name, icon, active }
function ns.GetTrackingList()
	local list = {}
	if C_Minimap and C_Minimap.GetNumTrackingTypes then
		for i = 1, C_Minimap.GetNumTrackingTypes() do
			local name, icon, active, ttype
			local info = C_Minimap.GetTrackingInfo(i)
			if type(info) == "table" then
				name, icon, active, ttype = info.name, info.texture, info.active, info.type
			else
				name, icon, active, ttype = C_Minimap.GetTrackingInfo(i)
			end
			if name and ttype == "spell" then
				list[#list + 1] = { name = name, icon = icon, active = active and true or false }
			end
		end
	end
	if #list == 0 and ns.spellbook then
		-- vanilla-style fallback: tracking spells from the spellbook, active one by texture
		local activeTex = GetTrackingTexture and GetTrackingTexture()
		for name, s in pairs(ns.spellbook) do
			if ns.IsTrackingName(name) then
				list[#list + 1] = { name = name, icon = s.icon, active = activeTex ~= nil and activeTex == s.icon }
			end
		end
		table.sort(list, function(a, b) return a.name < b.name end)
	end
	return list
end

---------------------------------------------------------------------------
-- Combat-safe execution (secure frames can't be changed in combat)
---------------------------------------------------------------------------
local pending = {}
function ns.RunOutOfCombat(key, fn)
	if InCombatLockdown() then
		pending[key] = fn
	else
		fn()
	end
end

---------------------------------------------------------------------------
-- Movable containers
---------------------------------------------------------------------------
function ns.MakeMovable(frame, db, label)
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)

	local mover = CreateFrame("Frame", nil, frame, "BackdropTemplate")
	mover:SetPoint("TOPLEFT", -4, 4)
	mover:SetPoint("BOTTOMRIGHT", 4, -4)
	mover:SetFrameLevel(frame:GetFrameLevel() + 20)
	mover:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
	mover:SetBackdropColor(0.96, 0.55, 0.73, 0.25)
	mover:SetBackdropBorderColor(0.96, 0.55, 0.73, 0.9)
	mover:EnableMouse(true)
	mover:RegisterForDrag("LeftButton")
	local txt = mover:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	txt:SetPoint("BOTTOM", mover, "TOP", 0, 2)
	txt:SetText(label)
	mover:SetScript("OnDragStart", function()
		if not InCombatLockdown() then frame:StartMoving() end
	end)
	mover:SetScript("OnDragStop", function()
		frame:StopMovingOrSizing()
		ns.SnapToGrid(frame, db)
	end)
	mover:Hide()
	frame.mover = mover
end

function ns.ApplyPosition(frame, db)
	frame:ClearAllPoints()
	local p = db.point
	frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
	frame:SetScale(db.scale or 1)
end

function ns.ResetPositions()
	if InCombatLockdown() then ns.Print(ns.L["Can't do that in combat."]) return end
	ns.db.buffs.point = { unpack(ns.defaults.buffs.point) }
	ns.db.timeline.point = { unpack(ns.defaults.timeline.point) }
	for _, m in ipairs(ns.modules) do if m.ApplySettings then m:ApplySettings() end end
	ns.Print(ns.L["Positions reset."])
end

function ns.SetLocked(locked)
	if InCombatLockdown() then ns.Print(ns.L["Can't do that in combat."]) return end
	ns.db.locked = locked
	for _, m in ipairs(ns.modules) do
		if m.OnLockChanged then m:OnLockChanged() end
	end
	ns.UpdateGrid()
end

---------------------------------------------------------------------------
-- Alignment grid: 8 px steps measured from the screen centre; the centre
-- lines are "sticky" (within 10 px a frame snaps exactly onto them)
---------------------------------------------------------------------------
local GRID, STICKY = 8, 10

local function round(v, step) return math.floor(v / step + 0.5) * step end

-- re-anchor a dragged frame by its centre, snapped to the grid
function ns.SnapToGrid(frame, db)
	local cx, cy = frame:GetCenter()
	local ux, uy = UIParent:GetCenter()
	if not (cx and ux) then
		local p, _, rp, x, y = frame:GetPoint()
		db.point = { p, rp, x, y }
		return
	end
	-- work in UIParent units (the grid is drawn there)
	local s = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
	local dx, dy = cx * s - ux, cy * s - uy
	dx = math.abs(dx) <= STICKY and 0 or round(dx, GRID)
	dy = math.abs(dy) <= STICKY and 0 or round(dy, GRID)
	-- SetPoint offsets are in the frame's own (scaled) units
	local fs = frame:GetScale()
	db.point = { "CENTER", "CENTER", dx / fs, dy / fs }
	frame:ClearAllPoints()
	frame:SetPoint("CENTER", UIParent, "CENTER", dx / fs, dy / fs)
end

local grid
local function BuildGrid()
	grid = CreateFrame("Frame", "ProtadinGrid", UIParent)
	grid:SetAllPoints(UIParent)
	grid:SetFrameStrata("BACKGROUND")
	grid.lines = {}
	local function line(vertical, offset, alpha, r, g, b, width)
		local t = grid:CreateTexture(nil, "BACKGROUND")
		t:SetColorTexture(r, g, b, alpha)
		if vertical then
			t:SetWidth(width)
			t:SetPoint("TOP", grid, "TOP", offset, 0)
			t:SetPoint("BOTTOM", grid, "BOTTOM", offset, 0)
		else
			t:SetHeight(width)
			t:SetPoint("LEFT", grid, "LEFT", 0, offset)
			t:SetPoint("RIGHT", grid, "RIGHT", 0, offset)
		end
		grid.lines[#grid.lines + 1] = t
	end
	local w, h = UIParent:GetWidth() / 2, UIParent:GetHeight() / 2
	for x = GRID, w, GRID do
		local a = (x % (GRID * 4) == 0) and 0.12 or 0.05
		line(true, x, a, 1, 1, 1, 1); line(true, -x, a, 1, 1, 1, 1)
	end
	for y = GRID, h, GRID do
		local a = (y % (GRID * 4) == 0) and 0.12 or 0.05
		line(false, y, a, 1, 1, 1, 1); line(false, -y, a, 1, 1, 1, 1)
	end
	line(true, 0, 0.7, 0.96, 0.55, 0.73, 2)
	line(false, 0, 0.7, 0.96, 0.55, 0.73, 2)
end

-- the grid is shown while frames are unlocked
function ns.UpdateGrid()
	if not ns.db then return end
	if ns.db.locked then
		if grid then grid:Hide() end
		return
	end
	if not grid then BuildGrid() end
	grid:Show()
end

---------------------------------------------------------------------------
-- SavedVariables & init
---------------------------------------------------------------------------
local function MergeDefaults(dst, src)
	for k, v in pairs(src) do
		if type(v) == "table" then
			if type(dst[k]) ~= "table" then
				dst[k] = {}
				MergeDefaults(dst[k], v)
			elseif #v == 0 then
				MergeDefaults(dst[k], v) -- don't merge into arrays (positions)
			end
		elseif dst[k] == nil then
			dst[k] = v
		end
	end
end
ns.MergeDefaults = MergeDefaults

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" and arg1 == ADDON then
		ns.firstRun = (ProtadinAssistantDB == nil)
		ProtadinAssistantDB = ProtadinAssistantDB or {}
		MergeDefaults(ProtadinAssistantDB, ns.defaults)
		ns.db = ProtadinAssistantDB
	elseif event == "PLAYER_LOGIN" then
		local _, class = UnitClass("player")
		if class ~= "PALADIN" then return end
		ns.enabled = true
		ns.BuildNames()
		ns.ScanSpellbook()
		for _, m in ipairs(ns.modules) do m:Enable() end
		ns.UpdateGrid()
		if ns.firstRun and not ns.db.welcomed then
			ns.db.welcomed = true
			-- after the login chat spam has scrolled by
			C_Timer.After(6, function()
				ns.Print(ns.L["Protadin Assistant loaded. Right-click the minimap button or type /protadin for options."])
				ns.Print(ns.L["The cooldown timeline is always shown for now. In the options you can show it only during combat."])
			end)
		end
	elseif event == "PLAYER_REGEN_ENABLED" then
		for key, fn in pairs(pending) do
			pending[key] = nil
			fn()
		end
	end
end)

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
SLASH_PROTADIN1 = "/protadin"
SLASH_PROTADIN2 = "/pda"
SlashCmdList.PROTADIN = function(msg)
	local L = ns.L
	if not ns.enabled then ns.Print(L["Protadin Assistant works only on paladins."]) return end
	local cmd = (msg or ""):match("^(%S*)"):lower()
	if cmd == "lock" then
		ns.SetLocked(true); ns.Print(L["Frames locked."])
	elseif cmd == "unlock" then
		ns.SetLocked(false); ns.Print(L["Frames unlocked: drag them, then /protadin lock."])
	elseif cmd == "reset" then
		ns.ResetPositions()
	elseif cmd == "auras" then
		ns.Print(L["buffs on you:"])
		local readable = ns.ForEachPlayerAura(function(a)
			if ns.IsSecret(a.name) then ns.Print("  " .. L["(hidden in combat)"]) return true end
			local id = not ns.IsSecret(a.spellId) and a.spellId or "?"
			local icon = not ns.IsSecret(a.icon) and a.icon or "?"
			ns.Print(("  %s  (spell %s, icon %s)"):format(a.name, tostring(id), tostring(icon)))
		end)
		if not readable then ns.Print("  " .. L["(hidden in combat)"]) end
	elseif cmd == "debug" then
		for _, m in ipairs(ns.modules) do if m.Debug then m:Debug() end end
	elseif cmd == "" or cmd == "options" or cmd == "config" then
		ns.OpenOptions()
	else
		ns.Print("/protadin [options] | lock | unlock | reset | auras | debug")
	end
end
