local ns = { L = setmetatable({}, {__index=function(_,k) return k end}), modules = {} }
ns.N = { defaultPriority = { "Holy Shield", "Judgement", "Consecration", "Holy Strike", "Exorcism" } }
ns.defaultTimelineSpells = { ["Holy Shield"]=true, ["Judgement"]=true, ["Consecration"]=true, ["Holy Strike"]=true, ["Exorcism"]=true }
assert(loadfile(arg[1] .. "/Modules/Timeline.lua"))("x", ns)
local T = ns.timeline
T.RebuildEntries = function() end
T.db = { spells = {}, priority = {} }
local c = {}
for _, n in ipairs({ "Holy Strike", "Judgement", "Hammer of Justice", "Holy Shield", "Consecration", "Exorcism", "Hammer of Wrath" }) do c[#c+1] = { name = n } end
T.candidates = c
local function show() local t = {} for i, s in ipairs(T:EnabledByPriority()) do t[i] = s.name end return table.concat(t, " > ") end
print("default:            ", show())
T:ReplaceAt(5, "");                   print("5 := none           ", show())
T:AddSpell("Hammer of Wrath");        print("add HoW             ", show())
T:ReplaceAt(1, "Hammer of Justice");  print("1 := HoJ (new)      ", show())
T:ReplaceAt(2, "Holy Strike");        print("2 := Holy Strike    ", show())
T:AddSpell("Holy Shield");            print("add Holy Shield     ", show())
