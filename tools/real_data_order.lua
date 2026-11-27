-- usage: lua5.1 tools/real_data_order.lua . <path to SavedVariables/ProtadinAssistant.lua>
-- prints the learned order the current code computes from real saved data
local dir, sv = arg[1], arg[2]
local ns = { L = setmetatable({}, { __index = function(_, k) return k end }), modules = {} }
ns.N = { defaultPriority = {} }
ns.defaultTimelineSpells = { ["Judgement"] = true, ["Holy Strike"] = true, ["Consecration"] = true, ["Holy Shield"] = true, ["Exorcism"] = true }
assert(loadfile(dir .. "/Modules/Timeline.lua"))("x", ns)
assert(loadfile(sv))()
local T = ns.timeline
T.db = ProtadinAssistantDB.timeline
T.candidates = {}
for _, n in ipairs(T.db.priority) do T.candidates[#T.candidates + 1] = { name = n } end
local order, n = T:LearnedOrder()
print("choices:", n)
print("learned now: " .. table.concat(order, " > "))
print("pairs with Exorcism (wins:losses, Wilson low of the winner):")
local w = T.db.learn.wins
for _, b in ipairs(order) do
  if b ~= "Exorcism" then
    local ab = (w.Exorcism and w.Exorcism[b]) or 0
    local ba = (w[b] and w[b].Exorcism) or 0
    if ab + ba > 0 then
      print(("  Exorcism vs %-16s %5.1f : %-5.1f  low=%.2f"):format(b, ab, ba, T.WilsonLow(math.max(ab, ba), ab + ba)))
    end
  end
end
