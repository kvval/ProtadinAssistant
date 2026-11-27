-- usage: lua5.1 loccheck2.lua <addon dir> <file with used keys, one per line>
local dir, usedFile = arg[1], arg[2]
GetLocale = function() return "enUS" end
local ns = {}
assert(loadfile(dir .. "/Locales/Locales.lua"))("x", ns)
local keys = {}
for _, k in ipairs(ns.LOCALE_KEYS) do keys[k] = true end
local bad = 0
for line in io.lines(usedFile) do
  if line ~= "" and not keys[line] then print("used in code but not in KEYS:", line); bad = bad + 1 end
end
local function ph(s) local t = {} for p in s:gmatch("%%[sd]") do t[#t+1] = p end return table.concat(t) end
for loc, t in pairs(ns.LOCALE_TABLES) do
  for _, k in ipairs(ns.LOCALE_KEYS) do
    if not t[k] then print(loc, "missing:", k); bad = bad + 1
    elseif ph(t[k]) ~= ph(k) then print(loc, "placeholder mismatch:", k); bad = bad + 1 end
  end
  for k in pairs(t) do if not keys[k] then print(loc, "unknown key:", k); bad = bad + 1 end end
end
print(bad == 0 and ("all OK: " .. #ns.LOCALE_KEYS .. " keys") or (bad .. " problems"))
