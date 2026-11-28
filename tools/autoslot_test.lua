strmatch, strfind, strsub, strlower, strupper, format, strjoin = string.match, string.find, string.sub, string.lower, string.upper, string.format, function(sep, ...) return table.concat({...}, sep) end
tinsert, tremove, unpack = table.insert, table.remove, unpack
geterrorhandler = function() return function(e) print("ERRHANDLER:", e) end end
securecall = function(f, ...) return pcall(f, ...) end
hooksecurefunc = function() end
GetCursorPosition = function() return 0, 0 end
GetTime = function() return 1000 end
C_AddOns = { IsAddOnLoaded = function() return false end }
-- Fake WoW environment: every frame method exists; numeric getters return numbers.
local NUM = { GetTop=500, GetBottom=100, GetLeft=10, GetRight=600, GetWidth=600, GetHeight=400,
  GetFrameLevel=1, GetNumPoints=1, GetScale=1, GetAlpha=1 }
local function mock(name)
  local o = { __name = name, scripts = {} }
  return setmetatable(o, { __index = function(t, k)
    if k == "Text" or k == "text" then return nil end
    if k:match("^[a-z_]") then return nil end -- plain fields, not methods
    if NUM[k] then return function() return NUM[k] end end
    if k == "GetFont" then return function() return "Fonts\\FRIZQT__.TTF", 12, "" end end
    if k == "GetChecked" then return function() return t.checked end end
    if k == "SetChecked" then return function(_, v) t.checked = v end end
    if k == "SetScript" then return function(_, ev, fn) t.scripts[ev] = fn end end
    if k == "GetScript" then return function(_, ev) return t.scripts[ev] end end
    if k == "IsShown" or k == "IsPlaying" then return function() return t.shown end end
    if k == "Show" then return function() t.shown = true end end
    if k == "Hide" then return function() t.shown = false end end
    if k == "SetShown" then return function(_, v) t.shown = v end end
    if k == "GetPoint" then return function() return "CENTER", nil, "CENTER", 0, 0 end end
    if k == "SetupMenu" then return function(_, gen) t.gen = gen end end
    if k == "GenerateMenu" then return function()
      if t.gen then
        local root = { CreateRadio = function(_, text, isSel, setSel) assert(type(text)=="string"); isSel(); end,
                       CreateTitle = function() end }
        t.gen(t, root)
      end end end
    if k == "GetParent" then return function() return t.__parent end end
    if k:match("^Create") then return function() local c = mock(k); c.__parent = t; return c end end
    if k:match("^Get") then return function() return mock(k) end end
    return function() end
  end })
end
CreateFrame = function(kind, name, parent, template)
  local f = mock(kind); f.__parent = parent; if name then _G[name] = f end; return f
end
UIParent = mock("UIParent"); Minimap = mock("Minimap"); IsShiftKeyDown = function() return SHIFT end; IsControlKeyDown = function() return CTRL end; GameTooltip = mock("GameTooltip"); GameTooltip_Hide = function() end
SlashCmdList = {}; GetLocale = function() return arg[2] or "enUS" end
UnitClass = function() return "Paladin", "PALADIN" end
UnitExists = function() return false end; UnitIsDeadOrGhost = function() return false end
UnitCreatureType = function() return "Beast" end
InCombatLockdown = function() return false end
GetTime = function() return 1000 end
C_Timer = { After = function(_, fn) fn() end }
tContains = function(t, v) for _, x in ipairs(t) do if x == v then return true end end return false end
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
Enum = { SpellBookSpellBank = { Player = 0 }, SpellBookItemType = { Spell = 1 }, LuaCurveType = { Step = 1 } }
C_CurveUtil = { CreateCurve = function() return mock("curve") end }
C_Secrets = { ShouldAurasBeSecret = function() return false end }
local book = {
  { "Holy Strike", 5569, 0 }, { "Judgement", 20271, 8000 }, { "Hammer of Justice", 5589, 60000 },
  { "Holy Shield", 20927, 10000 }, { "Consecration", 20922, 8000 }, { "Exorcism", 10312, 15000 },
  { "Hammer of Wrath", 24275, 6000 }, { "Seal of Righteousness", 20289, 0 }, { "Blessing of Wisdom", 19742, 0 },
  { "Blessing of Kings", 20217, 0 }, { "Devotion Aura", 465, 0 }, { "Retribution Aura", 7294, 0 },
  { "Righteous Fury", 25780, 0 }, { "Find Minerals", 2580, 0 }, { "Sense Undead", 5502, 0 },
}
local byId = {}; for _, b in ipairs(book) do byId[b[2]] = b end
local names = { [25782]="Greater Blessing of Might", [19740]="Blessing of Might", [25894]="Greater Blessing of Wisdom",
  [25898]="Greater Blessing of Kings", [19705]="Well Fed", [429959]="Well-Rested", [1229737]="Basic Campfire" }
C_Spell = {
  GetSpellInfo = function(id)
    if type(id) == "string" then for _, b in ipairs(book) do if b[1] == id then id = b[2] end end end
    local b = byId[id]; local n = b and b[1] or names[id]
    if n then return { name = n, iconID = 100 + (tonumber(id) or 0), spellID = id, maxRange = 30 } end
  end,
  GetSpellCooldown = function() return { startTime = 0, duration = 0, isEnabled = true } end,
  IsSpellUsable = function() return true, false end,
  IsSpellInRange = function() return nil end,
}
GetSpellBaseCooldown = function(id) local b = byId[id]; return b and b[3] or 0 end
C_SpellBook = {
  GetNumSpellBookSkillLines = function() return 1 end,
  GetSpellBookSkillLineInfo = function() return { itemIndexOffset = 0, numSpellBookItems = #book } end,
  GetSpellBookItemInfo = function(i) local b = book[i]; return { name = b[1], spellID = b[2], iconID = b[2], itemType = 1, isPassive = false } end,
}
C_UnitAuras = { GetAuraDataByIndex = function(_, i) if i == 1 then return { name = "Blessing of Wisdom", sourceUnit = "player", icon = 1, expirationTime = 1200, duration = 300, auraInstanceID = 5 } end end,
  GetAuraDataByAuraInstanceID = function() return nil end }
C_Minimap = { GetNumTrackingTypes = function() return 2 end,
  GetTrackingInfo = function(i) return ({ { name="Find Minerals", texture=1, active=true, type="spell" }, { name="Sense Undead", texture=2, active=false, type="spell" } })[i] end }
C_Item = { GetItemIconByID = function() return 1 end, GetItemNameByID = function() return "Item" end }
Settings = { RegisterCanvasLayoutCategory = function() return { GetID = function() return 1 end } end,
  RegisterAddOnCategory = function() end, OpenToCategory = function() end }

local ns = {}
local dir = arg[1]
for line in io.lines(dir .. "/ProtadinAssistant.toc") do
  if line:match("%.lua$") then assert(loadfile(dir .. "/" .. line:gsub("\\", "/")))("ProtadinAssistant", ns) end
end
-- fire load events through the Core event frame: find it by running handlers on all created frames is hard,
-- so emulate what Core does
ProtadinAssistantDB = {}
ns.MergeDefaults(ProtadinAssistantDB, ns.defaults); ns.db = ProtadinAssistantDB
ns.enabled = true; ns.BuildNames(); ns.ScanSpellbook()
for _, m in ipairs(ns.modules) do m:Enable() end
print("modules enabled:", #ns.modules)


BAGS = { [0] = { {12210, 3}, {2683, 15} }, [1] = { {99999, 2}, {4540, 1} } }
local TIPS = { [99999] = { "Mystery Stew", "Use: Restores health. If you eat for 10 sec you will become well fed and gain 5% experience." },
               [4540] = { "Tough Hunk of Bread", "Use: Restores 61 health over 18 sec." } }
C_Container = {
  GetContainerNumSlots = function(bag) return BAGS[bag] and #BAGS[bag] or 0 end,
  GetContainerItemInfo = function(bag, slot) local e = BAGS[bag] and BAGS[bag][slot]; if e then return { itemID = e[1], stackCount = e[2] } end end,
}
C_Item.GetItemCount = function(id) for _, b in pairs(BAGS) do for _, e in ipairs(b) do if e[1] == id then return e[2] end end end return 0 end
C_TooltipInfo = { GetBagItem = function(bag, slot) local id = BAGS[bag][slot][1]; local l = {}; for _, t in ipairs(TIPS[id] or { "x" }) do l[#l+1] = { leftText = t } end; return { lines = l } end }

local B = ns.buffs
local function show(label) B:AutoSlots(); print(("%-28s foodOn=%s bagOn=%s"):format(label, tostring(ns.db.buffs.foodOn), tostring(ns.db.buffs.bagOn))) end
show("XP food, no sleeping bag:")
BAGS[1][2] = { 211527, 1 }
show("XP food + sleeping bag:")
BAGS = { [0] = { {4540, 5} } }
show("only bread, no bag:")
ns.db.buffs.foodOn = false; ns.db.buffs.foodManual = true
BAGS = { [0] = { {12210, 3}, {211527, 1} } }
show("food off by hand, food in bags:")
print("default buffs point:", table.concat(ns.defaults.buffs.point, " "), "| onlyInCombat default:", tostring(ns.defaults.timeline.onlyInCombat))
-- top level: XP food and sleeping bag are about levelling
ns.db.buffs.foodManual = nil; ns.db.buffs.bagManual = nil
BAGS = { [0] = { {12210, 3}, {211527, 1} } }
UnitLevel = function() return 60 end
GetMaxPlayerLevel = function() return 60 end
show("level 60, food + bag:")
ns.db.buffs.bagOn = true; ns.db.buffs.bagManual = true
show("level 60, bag on by hand:")
UnitLevel = function() return 59 end
ns.db.buffs.bagManual = nil
B:OnEvent("PLAYER_LEVEL_UP", 60)
print(("%-28s foodOn=%s bagOn=%s"):format("level up 59 -> 60:", tostring(ns.db.buffs.foodOn), tostring(ns.db.buffs.bagOn)))
print("AUTOSLOT TEST DONE")
