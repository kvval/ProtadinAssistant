-- automatic adaptation: after a fight, every 25 new choices, apply the learned
-- order and print only the swaps
local ns = { L = setmetatable({}, {__index=function(_,k) return k end}), modules = {} }
ns.N = { defaultPriority = {} }
ns.defaultTimelineSpells = { ["Judgement"]=true, ["Holy Strike"]=true, ["Consecration"]=true, ["Holy Shield"]=true }
local printed = {}
ns.Print = function(msg) printed[#printed+1] = msg end
ns.SpellLink = function(spell) return "[" .. tostring(spell) .. "]" end
assert(loadfile(arg[1] .. "/Modules/Timeline.lua"))("x", ns)
local T = ns.timeline
T.RebuildEntries = function() end
T.db = { spells = {}, autoAdapt = true, learn = { wins = {}, choices = 0 },
  priority = { "Judgement", "Holy Shield", "Consecration", "Holy Strike" } }
T.candidates = {}
for i, n in ipairs(T.db.priority) do T.candidates[i] = { name = n } end
local function teach(order, times)
  for _ = 1, times do
    for i = 1, #order do for j = i + 1, #order do
      local w = T.db.learn.wins[order[i]] or {}; T.db.learn.wins[order[i]] = w
      w[order[j]] = (w[order[j]] or 0) + 1
    end end
    T.db.learn.choices = T.db.learn.choices + 1
  end
end
local function fight(label)
  local n = #printed; T:AutoAdapt()
  local cur = {}; for i, s in ipairs(T:EnabledByPriority()) do cur[i] = s.name end
  print(("%-32s %-55s | %s"):format(label, #printed > n and printed[#printed] or "-", table.concat(cur, " > ")))
end
teach({ "Judgement", "Holy Shield", "Consecration", "Holy Strike" }, 30)
fight("learned == current:")
teach({ "Holy Shield", "Judgement", "Consecration", "Holy Strike" }, 10)
fight("only 10 new choices -> wait:")
teach({ "Holy Shield", "Judgement", "Consecration", "Holy Strike" }, 200)
fight("HoSh now beats Judgement:")
teach({ "Holy Shield", "Judgement", "Consecration", "Holy Strike" }, 30)
fight("same order again -> silent:")
teach({ "Holy Strike", "Consecration", "Holy Shield", "Judgement" }, 3000)
fight("whole order reversed:")
T.db.autoAdapt = false; teach({ "Judgement", "Holy Shield", "Consecration", "Holy Strike" }, 9000)
fight("option off:")
print("swaps A B C -> B C A:", table.concat(T.Swaps({ "A", "B", "C" }, { "B", "C", "A" }), ", "))
