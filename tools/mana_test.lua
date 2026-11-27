-- spells we can't pay for must not count as usable
local dummy = setmetatable({}, { __index = function() return function() end end })
CreateFrame = function() return dummy end; SlashCmdList = {}; GetLocale = function() return "enUS" end
local answer, mana, cost = {}, 500, { [1] = 120, [2] = 400, [3] = 0 }
C_Spell = {
  IsSpellUsable = function(id) return answer[id][1], answer[id][2] end,
  GetSpellPowerCost = function(id) return { { type = 0, cost = cost[id] } } end,
}
UnitPower = function() return mana end
local ns = {}
assert(loadfile(arg[1] .. "/Locales/Locales.lua"))("x", ns)
assert(loadfile(arg[1] .. "/Modules/Core.lua"))("x", ns)
local function try(label, id, usable, noMana, m)
  answer[id] = { usable, noMana }; mana = m or 500
  print(("%-48s -> %s"):format(label, tostring(ns.IsUsable(id))))
end
try("client: usable, mana ok", 1, true, false)
try("client: not usable (no mana)", 1, false, true)
try("client says usable but noMana=true (classic style)", 1, true, true)
try("client: nil, noMana=1 (old API style)", 1, nil, 1)
try("client says usable, cost 400 > mana 300", 2, true, false, 300)
try("client says usable, cost 400 <= mana 500", 2, true, false, 500)
try("free spell, mana 0", 3, true, false, 0)
