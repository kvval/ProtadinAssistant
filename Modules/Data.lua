local ADDON, ns = ...

--[[ Spell data by ID.
  Everything is identified by spell ID; the client turns IDs into names in its
  own language, so the addon works on any locale. Any rank's ID gives the same
  name. English name patterns stay as a last-resort fallback for spells that
  aren't in these tables (e.g. new Forever-only spells), and seals are also
  learned at runtime (see Timeline.lua).
  IDs marked "Forever" were taken from a WoW Forever character.
]]
local D = {
	RIGHTEOUS_FURY = 25780,
	WELL_FED       = 19705,
	WELL_FED_ICON  = 136000,
	WELL_RESTED    = 429959,          -- Cozy Sleeping Bag buff (Forever)
	SLEEPING_BAG   = 211527,          -- item
	CAMP_BENEFITS  = nil,             -- Forever camp-object buff; ID not known yet, name fallback below
	-- cooked food that gives Well Fed (+5% kill XP on Forever). Not complete:
	-- bag food is also recognised by its tooltip mentioning Well Fed.
	-- Sources: method.gg / seemeta.com recipe tables + in-game examples.
	XP_FOOD = {
		12210, 3665, 2679, 2681, 6888, 6290, 12224, 787, 17197, 5472,
		2680, 5473, 249865, 263509, 249871, 250079, 2888, 263512, 5474, 17198,
		6890, 5525, 2684, 5476, 724, 6316, 4592, 5095, 5477, 3220,
		7676, 250080, 250077, 2683, 733, 3662, 2687, 21072, 2682, 6657,
		251525, 5526, 5478, 3663, 249872, 249866, 1082, 4593, 5479, 1017,
		2685, 3726, 3666, 5480, 3664, 249873, 250068, 17222, 286152, 250071,
		250070, 250072, 250069, 13935, 6887, 13932, 13934, 13928, 13929, 250067,
		250066, 13930, 8957, 267341, 249876, 249875, 249870, 249869, 10841, 249868,
		249867, 249874,
	},
	CAMPFIRE_KIT   = 279981,          -- item "Basic Campfire Kit" (Forever): used from bags
	CAMPFIRE       = { 1229737, 1307227, 818 }, -- Basic Campfire spell (Forever, Forever, Classic): icon only

	-- { base, greater }
	BLESSINGS = {
		{ 19740, 25782 }, -- Might
		{ 19742, 25894 }, -- Wisdom
		{ 20217, 25898 }, -- Kings
		{ 1038,  25895 }, -- Salvation
		{ 19977, 25890 }, -- Light
		{ 20911, 25899 }, -- Sanctuary
	},
	HAND_BLESSINGS      = { 1044, 1022, 6940 }, -- Freedom, Protection, Sacrifice
	PREFERRED_BLESSINGS = { 20911, 20217, 19740, 19742 },

	AURAS        = { 465, 7294, 19746, 19876, 19888, 19891, 20218 },
	DEFAULT_AURA = 465, -- Devotion Aura

	-- Righteousness, Crusader, Light, Wisdom, Justice, Command, Fury (Forever)
	SEALS = { 20289, 20305, 20165, 20166, 20164, 20375, 20163 },

	TRACKING         = { 2580, 2383, 2481, 5502 }, -- Minerals, Herbs, Treasure, Sense Undead
	DEFAULT_TRACKING = 2580,

	-- Judgement, Holy Strike (Forever), Consecration, Holy Shield, Exorcism
	DEFAULT_TIMELINE = { 20271, 5569, 20922, 20927, 10312 },
	-- default "press this" priority: Holy Shield, Judgement, Consecration, Holy Strike, Exorcism
	DEFAULT_PRIORITY = { 20927, 20271, 20922, 5569, 10312 },
	-- only used if the client can't report base cooldowns
	FALLBACK_TIMELINE = { 20271, 5569, 14517, 20922, 20927, 10312, 24275, 5588, 2812, 31935 },
}
ns.D = D

local function Name(id)
	return id and (ns.GetSpellInfo(id)) or nil
end

local function NameSet(ids)
	local set = {}
	for _, id in ipairs(ids) do
		local n = Name(id)
		if n then set[n] = true end
	end
	return set
end

local function NameList(ids)
	local list = {}
	for _, id in ipairs(ids) do
		local n = Name(id)
		if n then list[#list + 1] = n end
	end
	return list
end

-- Called at login (spell names are available then).
function ns.BuildNames()
	local N = {}
	N.RF          = Name(D.RIGHTEOUS_FURY) or "Righteous Fury"
	N.WellFed     = Name(D.WELL_FED) or "Well Fed"
	N.WellRested  = Name(D.WELL_RESTED) or "Well-Rested"
	N.CampBenefits = Name(D.CAMP_BENEFITS)
		or Name(ns.db and ns.db.buffs and ns.db.buffs.campBenefitsId) or "Camp Benefits"
	N.campfire    = NameList(D.CAMPFIRE)

	N.blessingBase = {}
	for _, pair in ipairs(D.BLESSINGS) do
		local base, greater = Name(pair[1]), Name(pair[2])
		if base then
			N.blessingBase[base] = base
			if greater then N.blessingBase[greater] = base end
		end
	end
	N.hand      = NameSet(D.HAND_BLESSINGS)
	N.preferred = NameList(D.PREFERRED_BLESSINGS)

	N.auras       = NameSet(D.AURAS)
	N.defaultAura = Name(D.DEFAULT_AURA)

	N.seals = NameSet(D.SEALS)

	N.tracking        = NameSet(D.TRACKING)
	N.defaultTracking = Name(D.DEFAULT_TRACKING)

	N.defaultTimeline  = NameSet(D.DEFAULT_TIMELINE)
	N.fallbackTimeline = NameList(D.FALLBACK_TIMELINE)
	N.defaultPriority  = NameList(D.DEFAULT_PRIORITY)

	ns.N = N
	ns.defaultTimelineSpells = N.defaultTimeline
end

---------------------------------------------------------------------------
-- Classifiers (ID tables first, English patterns as fallback)
---------------------------------------------------------------------------
-- base blessing name for a blessing or greater blessing, else nil
function ns.BlessingBase(name)
	local N = ns.N
	local b = N and N.blessingBase[name]
	if b then return b end
	local g = name:match("^Greater (Blessing of .+)$")
	if g then return g end
	if name:find("^Blessing of ") then return name end
end

function ns.IsHandBlessing(name)
	return ns.N.hand[name] or name == "Blessing of Freedom" or name == "Blessing of Protection"
		or name == "Blessing of Sacrifice"
end

function ns.IsAuraName(name)
	return ns.N.auras[name] or name:find(" Aura$") ~= nil
end

function ns.IsSealName(name)
	if ns.N.seals[name] or name:find("^Seal of") then return true end
	local learned = ns.db and ns.db.timeline.learnedSeals
	return learned and learned[name] or false
end

function ns.IsTrackingName(name)
	return ns.N.tracking[name] or name:find("^Find ") or name:find("^Sense ") or name:find("^Track ")
end

-- the Basic Campfire spell this character knows, or nil
function ns.CampfireSpell()
	for _, n in ipairs(ns.N.campfire) do
		if ns.IsKnownName(n) then return n end
	end
end

function ns.ItemIcon(id)
	local icon = (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id))
		or (GetItemIcon and GetItemIcon(id))
	return icon or 134400
end

-- localized item name (may be nil until the client has cached the item)
function ns.ItemName(id, fallback)
	local n = (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id))
		or (GetItemInfo and GetItemInfo(id))
	return n or fallback
end

---------------------------------------------------------------------------
-- Spell cooldown from its tooltip ("8 sec cooldown"). The tooltip shows the
-- cooldown with talents and gear already counted in. The text is matched with
-- the client's own strings, so it works in any language.
---------------------------------------------------------------------------
local cdPatterns
local function CooldownPatterns()
	if cdPatterns then return cdPatterns end
	cdPatterns = {}
	for _, g in ipairs({ { "SPELL_RECAST_TIME_SEC", 1 }, { "SPELL_RECAST_TIME_MIN", 60 },
		{ "SPELL_RECAST_TIME_HOURS", 3600 } }) do
		local fmt = _G[g[1]]
		if type(fmt) == "string" and not ns.IsSecret(fmt) then
			-- "%.3g sec cooldown" -> "^([%d%.,]+) sec cooldown$"
			local pat = fmt:gsub("([%(%)%.%[%]%*%+%-%?%^%$])", "%%%1")
			pat = pat:gsub("%%%%[%d%%.]*[sgdf]", "([%%d%%.,]+)")
			cdPatterns[#cdPatterns + 1] = { "^" .. pat .. "$", g[2] }
		end
	end
	return cdPatterns
end

local function CooldownFromText(t)
	if type(t) ~= "string" or ns.IsSecret(t) then return nil end
	for _, p in ipairs(CooldownPatterns()) do
		local n = t:match(p[1])
		n = n and tonumber((n:gsub(",", ".")))
		if n then return n * p[2] end
	end
end

local cdTip
local SIDES = { "Right", "Left" }
function ns.TooltipCooldown(spellID)
	if not spellID then return nil end
	if C_TooltipInfo and C_TooltipInfo.GetSpellByID then
		local ok, data = pcall(C_TooltipInfo.GetSpellByID, spellID)
		if ok and type(data) == "table" and data.lines then
			for _, l in ipairs(data.lines) do
				local cd = CooldownFromText(l.rightText) or CooldownFromText(l.leftText)
				if cd then return cd end
			end
			return nil
		end
	end
	if not cdTip then
		cdTip = CreateFrame("GameTooltip", "ProtadinCooldownTooltip", nil, "GameTooltipTemplate")
		cdTip:SetOwner(WorldFrame, "ANCHOR_NONE")
	end
	cdTip:ClearLines()
	if not pcall(cdTip.SetSpellByID, cdTip, spellID) then return nil end
	for i = 1, (cdTip:NumLines() or 0) do
		for _, side in ipairs(SIDES) do
			local fs = _G["ProtadinCooldownTooltipText" .. side .. i]
			local cd = fs and CooldownFromText(fs:GetText())
			if cd then return cd end
		end
	end
end

-- raw strings for /protadin debug
function ns.CooldownPatternInfo()
	local out = {}
	for _, p in ipairs(CooldownPatterns()) do out[#out + 1] = p[1] end
	return table.concat(out, " | ")
end

-- does the item's tooltip mention Well Fed (in the client's language)?
local tipCache = {}
local scanTip
local function TooltipLines(bag, slot)
	local out = {}
	if C_TooltipInfo and C_TooltipInfo.GetBagItem then
		local ok, data = pcall(C_TooltipInfo.GetBagItem, bag, slot)
		if ok and data and data.lines then
			for _, l in ipairs(data.lines) do
				if l.leftText and not ns.IsSecret(l.leftText) then out[#out + 1] = l.leftText end
			end
			return out
		end
	end
	if not scanTip then
		scanTip = CreateFrame("GameTooltip", "ProtadinScanTooltip", nil, "GameTooltipTemplate")
		scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
	end
	scanTip:ClearLines()
	scanTip:SetBagItem(bag, slot)
	for i = 1, scanTip:NumLines() do
		local fs = _G["ProtadinScanTooltipTextLeft" .. i]
		local t = fs and fs:GetText()
		if t then out[#out + 1] = t end
	end
	return out
end

local xpFood
function ns.IsXPFood(itemID, bag, slot)
	if not xpFood then
		xpFood = {}
		for _, id in ipairs(D.XP_FOOD) do xpFood[id] = true end
	end
	if xpFood[itemID] then return true end
	if tipCache[itemID] ~= nil then return tipCache[itemID] end
	local needle = (ns.N and ns.N.WellFed or "Well Fed"):lower()
	local found = false
	for _, t in ipairs(TooltipLines(bag, slot)) do
		if t:lower():find(needle, 1, true) then found = true break end
	end
	tipCache[itemID] = found
	return found
end

-- the XP food in the bags with the smallest total count (use leftovers first)
function ns.PickXPFood()
	local get = C_Container and C_Container.GetContainerItemInfo
	local slots = C_Container and C_Container.GetContainerNumSlots
	if not (get and slots) then return nil end
	local best, bestCount, seen = nil, nil, {}
	for bag = 0, NUM_BAG_SLOTS or 4 do
		for slot = 1, slots(bag) or 0 do
			local info = get(bag, slot)
			local id = info and info.itemID
			if id and not seen[id] then
				seen[id] = true
				if ns.IsXPFood(id, bag, slot) then
					local count = (C_Item and C_Item.GetItemCount and C_Item.GetItemCount(id))
						or (GetItemCount and GetItemCount(id)) or info.stackCount or 1
					if not best or count < bestCount then best, bestCount = id, count end
				end
			end
		end
	end
	return best
end

function ns.SleepingBagIcon() return ns.ItemIcon(D.SLEEPING_BAG) end
function ns.SleepingBagName() return ns.ItemName(D.SLEEPING_BAG, "Cozy Sleeping Bag") end
function ns.CampfireKitIcon() return ns.ItemIcon(D.CAMPFIRE_KIT) end
function ns.CampfireKitName() return ns.ItemName(D.CAMPFIRE_KIT, "Basic Campfire Kit") end
