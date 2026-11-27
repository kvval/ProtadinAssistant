local ns = { L = setmetatable({}, {__index=function(_,k) return k end}), modules = {} }
ns.N = { defaultPriority = { "Holy Shield", "Judgement", "Consecration", "Holy Strike", "Exorcism" } }
ns.defaultTimelineSpells = { ["Holy Shield"]=true, ["Judgement"]=true, ["Consecration"]=true, ["Holy Strike"]=true, ["Exorcism"]=true }
local printed = {}
ns.Print = function(msg) printed[#printed+1] = msg end
local clock = 1000000
time = function() return clock end
assert(loadfile(arg[1] .. "/Modules/Timeline.lua"))("x", ns)
local T = ns.timeline
T.RebuildEntries = function() end
T.db = { spells = {}, priority = {}, learn = { wins = {}, choices = 0 }, announceStyle = true }
local c = {}
for _, n in ipairs({ "Holy Strike", "Judgement", "Holy Shield", "Consecration", "Exorcism" }) do c[#c+1] = { name = n } end
T.candidates = c
local function teach(order, times)
  for _ = 1, times do
    for i = 1, #order do for j = i + 1, #order do
      local w = T.db.learn.wins[order[i]] or {}; T.db.learn.wins[order[i]] = w
      w[order[j]] = (w[order[j]] or 0) + 1
    end end
    T.db.learn.choices = T.db.learn.choices + 1
  end
end
local function step(label) local n = #printed; T:CheckLearnNotice(); print(("%-34s %s"):format(label, #printed > n and ("NOTICE: " .. printed[#printed]) or "-")) end
teach({ "Holy Shield", "Judgement", "Consecration", "Holy Strike", "Exorcism" }, 25)
step("learned == current:")
T.db.learn = { wins = {}, choices = 0 }
teach({ "Consecration", "Holy Shield", "Judgement", "Holy Strike", "Exorcism" }, 25)
step("different #1:")
step("same order again:")
T.db.learn.wins = {}; teach({ "Judgement", "Consecration", "Holy Shield", "Holy Strike", "Exorcism" }, 60)
clock = clock + 3600; step("new order after 1 hour:")
clock = clock + 24 * 3600; step("new order after 25 hours:")
T:ApplyLearned(); clock = clock + 48 * 3600; step("after Apply (matches now):")
