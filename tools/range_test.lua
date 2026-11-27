local dummy = setmetatable({}, { __index = function() return function() end end })
CreateFrame = function() return dummy end; SlashCmdList = {}; GetLocale = function() return "enUS" end
local hasTarget = true
UnitExists = function() return hasTarget end
-- what the client answered in the user's log, target = Beast
local range = { [20927]=nil, [20271]=true, [20922]=nil, [5569]=true, [10312]=nil }
local maxR  = { [20927]=0, [20271]=10, [20922]=0, [5569]=5, [10312]=30 }
C_Spell = {
  IsSpellInRange = function(id) return range[id] end,
  GetSpellInfo = function(id) return { name = "s" .. id, maxRange = maxR[id], spellID = id } end,
}
local ns = {}
assert(loadfile(arg[1] .. "/Locales/Locales.lua"))("x", ns)
assert(loadfile(arg[1] .. "/Modules/Core.lua"))("x", ns)
for _, p in ipairs({ {20927,"Holy Shield",true}, {20271,"Judgement",true}, {20922,"Consecration",true}, {5569,"Holy Strike",true}, {10312,"Exorcism",false} }) do
  local got = ns.InRange(p[1])
  print(("%-13s InRange=%-5s expected=%-5s %s"):format(p[2], tostring(got), tostring(p[3]), got == p[3] and "OK" or "FAIL"))
end
hasTarget = false
print("no target, Exorcism:", ns.InRange(10312))
