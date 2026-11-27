-- minimal WoW API mocks
local dummy = setmetatable({}, { __index = function() return function() end end })
CreateFrame = function() return dummy end
SlashCmdList = {}
GetLocale = function() return "enUS" end
local restricted, throw = false, false
C_Secrets = { ShouldAurasBeSecret = function() return restricted end }
local auras = { { name = "Blessing of Wisdom", auraInstanceID = 11 }, { name = "Retribution Aura", auraInstanceID = 12 } }
C_UnitAuras = {
  GetAuraDataByIndex = function(_, i)
    if throw then error("GetAuraDataByIndex(): Auras cannot be accessed when secret while tainted by 'ProtadinAssistant'") end
    return auras[i]
  end,
  GetAuraDataByAuraInstanceID = function(_, id)
    if throw then error("restricted") end
    for _, a in ipairs(auras) do if a.auraInstanceID == id then return a end end
  end,
}
local ns = {}
assert(loadfile(arg[1] .. "/Locales/Locales.lua"))("ProtadinAssistant", ns)
assert(loadfile(arg[1] .. "/Modules/Core.lua"))("ProtadinAssistant", ns)

local function count() local n = 0; local ok = ns.ForEachPlayerAura(function() n = n + 1 end); return ok, n end
print("normal:        ", count())                          -- true 2
restricted = true;  print("flag restricted:", count())     -- false 0
restricted = false; throw = true; print("api throws:    ", count()) -- false 0 (no error escapes)
print("AuraExists(11) while throwing:", tostring(ns.AuraExists(11))) -- nil
throw = false
print("AuraExists(11):", tostring(ns.AuraExists(11)), "AuraExists(99):", tostring(ns.AuraExists(99))) -- true false
local r = ns.RemovedAuraIDs({ removedAuraInstanceIDs = { 11, 13 } })
print("removed:", r and r[11], r and r[13], r and r[12])  -- true true nil
print("removed(nil):", tostring(ns.RemovedAuraIDs(nil)), "removed(empty):", tostring(ns.RemovedAuraIDs({})))
