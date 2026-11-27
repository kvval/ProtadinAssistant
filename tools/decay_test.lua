-- half-life check: after 500 more recorded choices an old count weighs half
local ns = { L = setmetatable({}, {__index=function(_,k) return k end}), modules = {} }
ns.N = { defaultPriority = {} }
ns.defaultTimelineSpells = { ["Judgement"]=true, ["Holy Strike"]=true }
ns.IsUsable = function() return true end
ns.InRange = function() return true end
assert(loadfile(arg[1] .. "/Modules/Timeline.lua"))("x", ns)
local T = ns.timeline
T.db = { spells = {}, priority = {}, learn = { wins = { Exorcism = { Judgement = 100 } }, choices = 0 } }
T.candidates = { { name = "Judgement" }, { name = "Holy Strike" } }
T.entries = { { name = "Judgement", id = 1, key = "Judgement" }, { name = "Holy Strike", id = 2, key = "Holy Strike" } }
T.Remaining = function() return 0 end
T.inCombat = true
for _ = 1, 500 do T:LearnFromCast(T.entries[1], 0) end
print(("old Exorcism>Judgement count after 500 choices: %.1f (expected ~50)"):format(T.db.learn.wins.Exorcism.Judgement))
print(("fresh Judgement>Holy Strike after 500 choices: %.1f (sum of a decaying series, < 500)"):format(T.db.learn.wins.Judgement["Holy Strike"]))
