-- Exorcism is castable only ~10% of the time it's off cooldown; when it is, the
-- player presses it first. It must be detected as situational and keep its
-- current place, while the other spells are ordered by the player's choices.
local ns = { L = setmetatable({}, {__index=function(_,k) return k end}), modules = {} }
ns.N = { defaultPriority = {} }
ns.defaultTimelineSpells = { ["Judgement"]=true, ["Holy Strike"]=true, ["Consecration"]=true, ["Holy Shield"]=true, ["Exorcism"]=true }
local usableNow = {}
ns.IsUsable = function(id) return usableNow[id] ~= false end
ns.InRange = function() return true end
assert(loadfile(arg[1] .. "/Modules/Timeline.lua"))("x", ns)
local T = ns.timeline
T.RebuildEntries = function() end
-- current priority: Exorcism placed 4th by the player
T.db = { spells = {}, learn = { wins = {}, choices = 0 },
  priority = { "Holy Strike", "Judgement", "Holy Shield", "Exorcism", "Consecration" } }
local ids = {}
T.candidates = {}
for i, n in ipairs(T.db.priority) do T.candidates[i] = { name = n }; ids[n] = i end
T.entries = {}
for _, s in ipairs(T:EnabledByPriority()) do T.entries[#T.entries+1] = { name = s.name, id = ids[s.name], key = s.name } end
local taste = { "Exorcism", "Consecration", "Holy Shield", "Judgement", "Holy Strike" }
local ready = {}
T.Remaining = function(_, o) return ready[o.name] and 0 or 5 end
T.inCombat = true
math.randomseed(7)
for _ = 1, 400 do
  ready, usableNow = {}, {}
  for _, n in ipairs(taste) do if math.random() < 0.6 then ready[n] = true end end
  usableNow[ids["Exorcism"]] = math.random() < 0.1   -- undead only, rarely
  local pick
  for _, n in ipairs(taste) do
    if ready[n] and (n ~= "Exorcism" or usableNow[ids["Exorcism"]]) then pick = pick or n end
  end
  if pick then
    local e; for _, x in ipairs(T.entries) do if x.name == pick then e = x end end
    T:LearnFromCast(e, 0)
  end
end
local a = T.db.learn.avail.Exorcism
print(("Exorcism castable when ready: %.0f%% -> situational: %s"):format(100 * a.usable / a.ready, tostring(T:IsSituational("Exorcism"))))
print("Consecration situational:", T:IsSituational("Consecration"))
local order = T:LearnedOrder()
print("current: " .. table.concat(T.db.priority, " > "))
print("learned: " .. T:FormatOrder(order))
print("Exorcism kept 4th:", order[4] == "Exorcism")
print("regular spells follow the taste (Consecration > Holy Shield > Judgement > Holy Strike):",
  table.concat({ order[1], order[2], order[3], order[5] }, ">") == "Consecration>Holy Shield>Judgement>Holy Strike")
