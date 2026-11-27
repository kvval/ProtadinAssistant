local dummy = setmetatable({}, { __index = function() return function() end end })
CreateFrame = function() return dummy end; SlashCmdList = {}; GetLocale = function() return "enUS" end
UIParent = { GetCenter = function() return 960, 540 end, GetEffectiveScale = function() return 0.8 end }
local ns = {}
assert(loadfile(arg[1] .. "/Locales.lua"))("x", ns)
assert(loadfile(arg[1] .. "/Core.lua"))("x", ns)
local function frame(cx, cy, scale)
  local f = { pts = nil }
  f.GetCenter = function() return cx, cy end
  f.GetScale = function() return scale end
  f.GetEffectiveScale = function() return 0.8 * scale end
  f.ClearAllPoints = function() end
  f.SetPoint = function(_, p, rel, rp, x, y) f.pts = { p, rp, x, y } end
  return f
end
local function try(label, cx, cy, scale)
  local f, db = frame(cx, cy, scale), {}
  ns.SnapToGrid(f, db)
  local p = db.point
  -- where the centre ends up, in UIParent units
  local ux, uy = 960 + p[3] * scale, 540 + p[4] * scale
  print(("%-28s -> offset %6.2f %7.2f | centre at %.1f, %.1f (dx %.1f, dy %.1f)"):format(label, p[3], p[4], ux, uy, ux - 960, uy - 540))
end
try("7 px right of centre", 967, 300, 1)
try("37 px right, 203 down", 997, 337, 1)
try("scale 1.5, near centre", 641.0 + 5 / 1.5, 360 - 100 / 1.5, 1.5) -- centre in own units: (960/1.5 + small)
