local ns = { L = setmetatable({}, {__index=function(_,k) return k end}), modules = {} }
ns.N = { defaultPriority = { "Holy Shield", "Judgement", "Consecration", "Holy Strike", "Exorcism" } }
ns.defaultTimelineSpells = { ["Holy Shield"]=true, ["Judgement"]=true, ["Consecration"]=true, ["Holy Strike"]=true, ["Exorcism"]=true }
ns.IsUsable = function() return true end
ns.InRange = function() return true end
assert(loadfile(arg[1] .. "/Modules/Timeline.lua"))("x", ns)
local T = ns.timeline
T.RebuildEntries = function() end
T.db = { spells = {}, priority = {}, learn = { wins = {}, choices = 0 } }
local c = {}
for _, n in ipairs({ "Holy Strike", "Judgement", "Holy Shield", "Consecration", "Exorcism" }) do c[#c+1] = { name = n } end
T.candidates = c
T.entries = {}
for _, s in ipairs(T:EnabledByPriority()) do T.entries[#T.entries+1] = { name = s.name, id = 1 } end

-- the player's real taste (unknown to the addon), with some noise
local taste = { "Consecration", "Holy Shield", "Judgement", "Holy Strike", "Exorcism" }
local rank = {}; for i, n in ipairs(taste) do rank[n] = i end
math.randomseed(42)
local ready = {}
T.Remaining = function(_, o) return ready[o.name] and 0 or 5 end
T.inCombat = true
local _, n0 = T:LearnedOrder(); print("choices before:", n0)
for fight = 1, 60 do
  ready = {}
  for _, n in ipairs(taste) do if math.random() < 0.6 then ready[n] = true end end
  local best
  for _, n in ipairs(taste) do if ready[n] then best = best or n end end
  if best then
    -- 15% of the time the player picks something else that's ready
    if math.random() < 0.15 then for n in pairs(ready) do best = n break end end
    local e; for _, x in ipairs(T.entries) do if x.name == best then e = x end end
    T:LearnFromCast(e, 0)
  end
end
local order, n = T:LearnedOrder()
print("choices:", n)
print("learned:", table.concat(order, " > "))
print("taste:  ", table.concat(taste, " > "))
-- casts that only follow the "Suggest next" hint are not learned
T.db.showNext = true
T.nextIcon = { key = "Holy Strike", IsShown = function() return true end }
local before = T.db.learn.choices
ready = { ["Holy Strike"] = true, ["Judgement"] = true }
local hs; for _, x in ipairs(T.entries) do if x.name == "Holy Strike" then hs = x end end
hs.key = "Holy Strike"
T:LearnFromCast(hs, 0)
print("followed the hint -> not learned:", T.db.learn.choices == before)
local j; for _, x in ipairs(T.entries) do if x.name == "Judgement" then j = x end end
j.key = "Judgement"
T:LearnFromCast(j, 0)
print("pressed something else -> learned:", T.db.learn.choices == before + 1)
T.nextIcon = nil
T:ApplyLearned()
local t = {}; for i, s in ipairs(T:EnabledByPriority()) do t[i] = s.name end
print("applied:", table.concat(t, " > "))
T.inCombat = false; local before = T.db.learn.choices; T:LearnFromCast(T.entries[1], 0)
print("out of combat ignored:", T.db.learn.choices == before)
T:ForgetLearned(); print("after forget:", select(2, T:LearnedOrder()))
