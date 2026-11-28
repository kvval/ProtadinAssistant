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


-- learned order sticks: pairs near 50/50 never swap, a clear habit does
local T = ns.timeline
local function order()
  local o = T:LearnedOrder(); local out = {}
  for i, n in ipairs(o) do out[i] = n end
  return table.concat(out, ",")
end
local list = {}
for _, s in ipairs(T:EnabledByPriority()) do list[#list + 1] = s.name end
local A, B = list[1], list[2]
T.db.learn = { wins = {}, choices = 300, avail = {} }
local W = T.db.learn.wins
local before = order()
-- the lower spell B wins 55:45 over A: near 50/50, nothing moves
W[B] = { [A] = 55 }; W[A] = { [B] = 45 }
print("close pair stays:", order() == before)
-- B wins 17:10 (like the seal's pairs in real data, Wilson ~0.49): stays
W[B] = { [A] = 17 }; W[A] = { [B] = 10 }
print("borderline stays:", order() == before)
-- B wins 40:8: clear habit, B goes above A
W[B] = { [A] = 40 }; W[A] = { [B] = 8 }
local o = T:LearnedOrder()
print("clear habit swaps:", o[1] == B and o[2] == A)
-- after the swap, a 55:45 drift back to A does not swap again
T:ApplyLearned()
W[A] = { [B] = 55 }; W[B] = { [A] = 45 }
local o2 = T:LearnedOrder()
print("no flip back:", o2[1] == B and o2[2] == A)
-- auto-adapt waits for 100 choices after a fresh start
T.db.autoAdapt = true
T.db.learn = { wins = { [list[3]] = { [list[1]] = 40 } }, choices = 60, avail = {} }
local p0 = table.concat(T.db.priority, ",")
T:AutoAdapt()
print("waits for 100:", table.concat(T.db.priority, ",") == p0)
