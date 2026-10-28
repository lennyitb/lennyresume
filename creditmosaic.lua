-- creditmosaic.lua: draws the degree credit mosaic as TikZ.
--
-- One rounded square per credit, packed course by course, outlined per
-- course and shaded by grade; under it a bar that splits the same credits by
-- term with each term's GPA. \creditmosaic in mosaicresume.cls calls draw()
-- with the data file (courses.lua) and the line width; you should not need
-- to edit this file. All sizes are in pt.

local M = {}

-- ---------- proportions ----------
-- Everything scales with the pitch (center-to-center square spacing), which
-- is chosen so the mosaic exactly fills the line width.
local SQ_RATIO  = 30 / 38     -- square side / pitch
local RAD_RATIO = 3.9 / 30    -- square corner radius / square side
local GRADED    = 0.85        -- graded squares are drawn this much smaller,
                              -- centered in their cell, so outlines have room
local LW        = 1.2         -- outline line width (solid and dotted alike)
local DOT_PITCH = 2.0         -- center-to-center spacing of in-progress dots

local FILL   = { Ap = "gradeAp", A = "gradeA", B = "gradeB",   C = "gradeC" }
local PFILL  = { Ap = "pieceAp", A = "pieceA", B = "pieceB",   C = "pieceC" }
local STROKE = { Ap = "gradeAp", A = "gradeA", B = "strokeBC", C = "strokeBC" }

local function fmt(x) return string.format("%.2f", x) end

local function fail(msg) error({ mosaic = msg }) end

local function warn(msg)
  texio.write_nl("term and log", "Credit mosaic warning: " .. msg)
  texio.write_nl("term and log", "")
end

-- A+ -> Ap, A/A- -> A, B+/B/B- -> B, anything else -> C
local function band(g)
  g = tostring(g or "")
  if g == "A+" or g == "Ap" then return "Ap" end
  local l = g:sub(1, 1):upper()
  if l == "A" or l == "B" then return l end
  return "C"
end

-- Course label to TeX: "\n" breaks the line; bare &, % and # are escaped.
local function texlabel(s)
  s = tostring(s):gsub("\\?[&%%#]", function(m)
    if #m == 2 then return m end
    return "\\" .. m
  end)
  return (s:gsub("\n", "\\\\"))
end

-- ---------- data ----------
local function load(name)
  local path = kpse.find_file(name, "lua") or name
  local chunk, err = loadfile(path)
  if not chunk then fail("cannot read " .. name .. ": " .. tostring(err)) end
  if kpse.record_input_file then kpse.record_input_file(path) end
  local d = chunk()
  if type(d) ~= "table" then fail(name .. " must return a table") end
  d.rows = d.rows or 5
  if not d.total then fail(name .. " needs total = <credits for the degree>") end

  local courses, seen = {}, {}
  for n, t in ipairs(d.courses or {}) do
    local c = {
      id = t.id or t[1], label = t.label or t[2],
      credits = t.credits or t[3], grade = t.grade or t[4],
      current = t.current or false,
    }
    local what = "course " .. n .. " (" .. tostring(c.label or c.id) .. ")"
    if type(c.id) ~= "string" or not c.id:match("^%S+$") or c.id == "." then
      fail(what .. " needs an id: a short code with no spaces, used in the layout map")
    end
    if seen[c.id] then fail("two courses have the id " .. c.id) end
    seen[c.id] = true
    if type(c.credits) ~= "number" or c.credits < 1 or c.credits % 1 ~= 0 then
      fail(what .. " needs a whole number of credits")
    end
    c.label = texlabel(c.label or c.id)
    c.band = band(c.grade)
    courses[n] = c
  end
  d.courses = courses
  return d
end

-- ---------- packing ----------
-- Cells are (c, r): column from the left, row from the top. The grid fills
-- column by column, so cell (c, r) is credit number c * rows + r.
local function packer(rows, total)
  local P = { rows = rows, total = total, cols = math.ceil(total / rows), owner = {} }
  function P.idx(c, r) return c * rows + r end
  function P.exists(c, r)
    return r >= 0 and r < rows and c >= 0 and c < P.cols and P.idx(c, r) < total
  end
  function P.free(c, r) return P.exists(c, r) and P.owner[P.idx(c, r)] == nil end
  return P
end

local function connected(cells)
  local set, n = {}, 0
  for _, q in ipairs(cells) do set[q[1] .. "," .. q[2]] = true end
  local stack, seen = { cells[1] }, { [cells[1][1] .. "," .. cells[1][2]] = true }
  while #stack > 0 do
    local q = table.remove(stack)
    n = n + 1
    for _, d in ipairs({ { 0, 1 }, { 0, -1 }, { 1, 0 }, { -1, 0 } }) do
      local k = (q[1] + d[1]) .. "," .. (q[2] + d[2])
      if set[k] and not seen[k] then
        seen[k] = true
        stack[#stack + 1] = { q[1] + d[1], q[2] + d[2] }
      end
    end
  end
  return n == #cells
end

-- Cells drawn in the layout map, by course id.
local function read_layout(layout, P, byid)
  local cells = {}
  if not layout then return cells end
  local r = 0
  for line in (layout .. "\n"):gmatch("(.-)\r?\n") do
    if line:match("%S") then
      local c = 0
      for tok in line:gmatch("%S+") do
        if tok ~= "." then
          if not byid[tok] then
            fail("the layout map uses " .. tok .. ", but no course has that id")
          end
          if not P.exists(c, r) then
            fail(tok .. " at row " .. (r + 1) .. ", column " .. (c + 1) ..
                 " of the layout map is outside the grid (rows = " .. P.rows ..
                 ", total = " .. P.total .. ")")
          end
          cells[tok] = cells[tok] or {}
          table.insert(cells[tok], { c, r })
        end
        c = c + 1
      end
      r = r + 1
    end
  end
  return cells
end

-- Grow a piece from the first free cell (column by column) that has room,
-- going right of the start first so the label has a horizontal pair, then
-- to the lowest-numbered free neighbor.
local function greedy(P, credits)
  for c = 0, P.cols - 1 do
    for r = 0, P.rows - 1 do
      if P.free(c, r) then
        local piece, inp = { { c, r } }, { [P.idx(c, r)] = true }
        while #piece < credits do
          local best, bestkey
          for _, q in ipairs(piece) do
            for _, d in ipairs({ { 0, 1 }, { 0, -1 }, { 1, 0 }, { -1, 0 } }) do
              local x, y = q[1] + d[1], q[2] + d[2]
              if P.free(x, y) and not inp[P.idx(x, y)] then
                local key = ((x == c + 1 and y == r) and 0 or 1) * 1e6 + P.idx(x, y)
                if not bestkey or key < bestkey then best, bestkey = { x, y }, key end
              end
            end
          end
          if not best then break end
          piece[#piece + 1] = best
          inp[P.idx(best[1], best[2])] = true
        end
        if #piece == credits then return piece end
      end
    end
  end
end

local function pack(d)
  local P = packer(d.rows, d.total)
  local byid = {}
  for n, c in ipairs(d.courses) do byid[c.id] = n end
  local mapped = read_layout(d.layout, P, byid)
  local pieces, auto = {}, {}
  for n, c in ipairs(d.courses) do
    local cells = mapped[c.id]
    if cells then
      if #cells ~= c.credits then
        fail(c.id .. " has " .. c.credits .. " credits but " .. #cells ..
             " squares in the layout map")
      end
      if not connected(cells) then
        warn(c.id .. "'s squares in the layout map do not all touch side to side")
      end
      for _, q in ipairs(cells) do P.owner[P.idx(q[1], q[2])] = n end
      pieces[n] = cells
    end
  end
  for n, c in ipairs(d.courses) do
    if not pieces[n] then
      local cells = greedy(P, c.credits)
      if not cells then fail("no room left to place " .. c.id) end
      for _, q in ipairs(cells) do P.owner[P.idx(q[1], q[2])] = n end
      pieces[n] = cells
      auto[#auto + 1] = c.id
    end
  end
  return P, pieces, auto
end

-- The resolved layout as a map you can paste back into courses.lua.
local function report(P, d, auto)
  local w = 1
  for _, c in ipairs(d.courses) do w = math.max(w, #c.id) end
  local used = 0
  for c = 0, P.cols - 1 do
    for r = 0, P.rows - 1 do
      if P.owner[P.idx(c, r)] then used = math.max(used, c + 1) end
    end
  end
  local out = { "", "Credit mosaic layout (paste into layout = [[ ... ]] to arrange by hand):" }
  for r = 0, P.rows - 1 do
    local toks = {}
    for c = 0, used - 1 do
      local n = P.exists(c, r) and P.owner[P.idx(c, r)]
      local t = n and d.courses[n].id or "."
      toks[#toks + 1] = t .. string.rep(" ", w - #t)
    end
    out[#out + 1] = "    " .. table.concat(toks, " "):gsub("%s+$", "")
  end
  out[#out + 1] = ""
  local where = #auto > 0 and "term and log" or "log"
  if #auto > 0 then
    texio.write_nl(where, "Credit mosaic: placed automatically: " .. table.concat(auto, ", "))
  end
  for _, l in ipairs(out) do texio.write_nl(where, l) end
end

-- ---------- outline of a piece ----------
-- Vertices of the course outline: the piece's silhouette offset outward by
-- dist from the graded squares' edges. Returns {x, y, convex} in pt, y down.
local function outline(cells, dist, G)
  local edges, order = {}, {}
  local function k(a, b) return a[1] .. "," .. a[2] .. ">" .. b[1] .. "," .. b[2] end
  for _, q in ipairs(cells) do
    local x0, y0, x1, y1 = q[1], q[2], q[1] + 1, q[2] + 1
    for _, e in ipairs({ { { x0, y0 }, { x1, y0 } }, { { x1, y0 }, { x1, y1 } },
                         { { x1, y1 }, { x0, y1 } }, { { x0, y1 }, { x0, y0 } } }) do
      local rev = k(e[2], e[1])
      if edges[rev] then
        edges[rev] = nil
      else
        edges[k(e[1], e[2])] = e
        order[#order + 1] = k(e[1], e[2])
      end
    end
  end
  -- chain the boundary edges into a loop
  local nxt, start = {}, nil
  for _, key in ipairs(order) do
    local e = edges[key]
    if e then
      local a = e[1][1] .. "," .. e[1][2]
      nxt[a] = nxt[a] or {}
      table.insert(nxt[a], e[2])
      if not start or e[1][1] < start[1] or (e[1][1] == start[1] and e[1][2] < start[2]) then
        start = e[1]
      end
    end
  end
  local loop, cur, prev = { start }, start, nil
  while true do
    local ck = cur[1] .. "," .. cur[2]
    local outs = nxt[ck]
    local n = outs[1]
    -- at a vertex with two outgoing edges (touching corners) keep turning
    if #outs > 1 and prev and outs[1][1] == prev[1] and outs[1][2] == prev[2] then n = outs[2] end
    for i, o in ipairs(outs) do if o == n then table.remove(outs, i) break end end
    if n[1] == start[1] and n[2] == start[2] then break end
    loop[#loop + 1] = n
    prev, cur = cur, n
  end
  -- drop collinear points
  local pts, L = {}, #loop
  for i = 1, L do
    local a, b, c = loop[(i - 2) % L + 1], loop[i], loop[i % L + 1]
    if (b[1] - a[1]) * (c[2] - b[2]) - (b[2] - a[2]) * (c[1] - b[1]) ~= 0 then
      pts[#pts + 1] = b
    end
  end
  -- The loop runs clockwise in a y-down frame (the cell edges above go right,
  -- down, left, up), so inside is to the right of travel; the inward normal
  -- of (dx, dy) is (-dy, dx). The pitch-cell corner sits GAPF/2 outside a
  -- graded square, so moving it inward by GAPF/2 - dist leaves the outline
  -- dist outside the square's edge.
  local inset, out = G.GAPF / 2 - dist, {}
  L = #pts
  for i = 1, L do
    local a, b, c = pts[(i - 2) % L + 1], pts[i], pts[i % L + 1]
    local d1 = { b[1] - a[1], b[2] - a[2] }
    local d2 = { c[1] - b[1], c[2] - b[2] }
    local l1 = math.abs(d1[1]) + math.abs(d1[2])
    local l2 = math.abs(d2[1]) + math.abs(d2[2])
    local n1 = { -d1[2] / l1, d1[1] / l1 }
    local n2 = { -d2[2] / l2, d2[1] / l2 }
    local convex = (d1[1] * d2[2] - d1[2] * d2[1]) > 0
    local px, py = b[1] * G.PITCH - G.GAP / 2, b[2] * G.PITCH - G.GAP / 2
    out[#out + 1] = { px + inset * (n1[1] + n2[1]), py + inset * (n1[2] + n2[2]), convex }
  end
  return out
end

-- One rounded corner: the point where the arc starts and the arc itself.
local function corner(a, b, c, r)
  local l1 = math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2)
  local l2 = math.sqrt((c[1] - b[1]) ^ 2 + (c[2] - b[2]) ^ 2)
  local d1 = { (b[1] - a[1]) / l1, (b[2] - a[2]) / l1 }
  local d2 = { (c[1] - b[1]) / l2, (c[2] - b[2]) / l2 }
  local p_in = { b[1] - r * d1[1], b[2] - r * d1[2] }
  local p_out = { b[1] + r * d2[1], b[2] + r * d2[2] }
  local ctr = { p_in[1] + r * d2[1], p_in[2] + r * d2[2] }
  local a0 = math.deg(math.atan(p_in[2] - ctr[2], p_in[1] - ctr[1]))
  local turn = d1[1] * d2[2] - d1[2] * d2[1]
  local a1 = a0 + (turn > 0 and 90 or -90)
  local arc = string.format("-- (%spt,%spt) arc[start angle=%.0f, end angle=%.0f, radius=%.2fpt]",
                            fmt(p_in[1]), fmt(p_in[2]), a0, a1, r)
  return p_in, p_out, arc
end

-- TikZ path for an axis-aligned polygon with explicit corner arcs, so each
-- convex corner is concentric with the rounded square it wraps. Also returns
-- the path length, for fitting the dots of a dotted outline.
local function rounded_path(verts, r_convex, r_concave)
  local pts = {}
  for i, v in ipairs(verts) do pts[i] = { v[1], -v[2], v[3] } end   -- TikZ frame, y up
  local L, segs, length, prev_out = #pts, {}, 0, nil
  for i = 1, L + 1 do
    local j = (i - 1) % L + 1
    local a, b, c = pts[(j - 2) % L + 1], pts[j], pts[j % L + 1]
    local r = b[3] and r_convex or r_concave
    local p_in, p_out, arc = corner(a, b, c, r)
    if i == 1 then
      segs[1] = string.format("(%spt,%spt)", fmt(p_out[1]), fmt(p_out[2]))
    else
      length = length + math.sqrt((p_in[1] - prev_out[1]) ^ 2 + (p_in[2] - prev_out[2]) ^ 2)
                      + math.pi * r / 2
      segs[#segs + 1] = arc
    end
    prev_out = p_out
  end
  return table.concat(segs, " ") .. " -- cycle", length
end

-- Dash pattern for a dotted closed path: the dot pitch is nudged so a whole
-- number of dots fits the path length and the pattern closes without a seam.
-- The phase starts the path halfway through a gap, so if the drawn length
-- comes out a hair off the computed one the join lands in white space.
local function dots(length, pitch, on)
  on = on or 0.1
  local n = math.max(1, math.floor(length / pitch + 0.5))
  local off = length / n - on
  return string.format("dash pattern=on %spt off %.3fpt, dash phase=%.3fpt, line cap=round",
                       on, off, on + off / 2)
end

local function sq(G, c, r, color, side, off, radius)
  local x, y = c * G.PITCH + off, -(r * G.PITCH + off)
  return string.format("\\fill[fill=%s, rounded corners=%.2fpt] (%spt,%spt) rectangle (%spt,%spt);",
                       color, radius, fmt(x), fmt(y), fmt(x + side), fmt(y - side))
end

-- Center of the best horizontal pair (top row first), else of the top-left cell.
local function label_pos(G, piece)
  local set = {}
  for _, q in ipairs(piece) do set[q[1] .. "," .. q[2]] = true end
  local best
  for _, q in ipairs(piece) do
    if set[(q[1] + 1) .. "," .. q[2]] and
       (not best or q[2] < best[2] or (q[2] == best[2] and q[1] < best[1])) then
      best = q
    end
  end
  if best then
    return (best[1] + 1) * G.PITCH - G.GAP / 2, -(best[2] * G.PITCH + G.SQ / 2)
  end
  for _, q in ipairs(piece) do
    if not best or q[2] < best[2] or (q[2] == best[2] and q[1] < best[1]) then best = q end
  end
  return best[1] * G.PITCH + G.SQ / 2, -(best[2] * G.PITCH + G.SQ / 2)
end

-- ---------- drawing ----------
local function render(d, linewidth)
  local P, pieces, auto = pack(d)
  report(P, d, auto)

  local G = {}
  G.PITCH  = d.pitch or linewidth / (P.cols - 1 + SQ_RATIO)
  G.SQ     = G.PITCH * SQ_RATIO
  G.GAP    = G.PITCH - G.SQ
  G.RADIUS = G.SQ * RAD_RATIO
  G.SQF    = G.SQ * GRADED              -- graded square side
  G.OFF    = (G.SQ - G.SQF) / 2         -- its inset within the grid square
  G.GAPF   = G.PITCH - G.SQF            -- space between neighboring graded squares
  G.RF     = G.RADIUS * GRADED          -- graded square corner radius
  -- Clear space between a square and the inner edge of its outline, chosen
  -- to equal the white channel between two neighboring outlines:
  -- GAPW = GAPF - 2 * (GAPW + LW)
  G.GAPW   = (G.GAPF - 2 * LW) / 3

  local credits, inprog = 0, 0
  for _, c in ipairs(d.courses) do
    credits = credits + c.credits
    if c.current then inprog = inprog + c.credits end
  end
  local remaining = d.total - credits
  if remaining < 0 then fail("the courses add up to more than total = " .. d.total) end
  local function fill_in(s)
    return (tostring(s):gsub("{(%a+)}", {
      credits = credits, total = d.total, remaining = remaining, inprogress = inprog,
    }))
  end

  local o = {}
  local function w(s) o[#o + 1] = s end
  -- the outlines of the outer courses stand a little proud of the squares;
  -- trim them out of the width so the mosaic lines up with the text
  w(string.format("\\begin{tikzpicture}[x=1pt, y=1pt, trim left=0pt, trim right=%spt]",
                  fmt((P.cols - 1) * G.PITCH + G.SQ)))
  -- remaining credits first (behind)
  for c = 0, P.cols - 1 do
    for r = 0, P.rows - 1 do
      if P.free(c, r) then w(sq(G, c, r, "gradeRem", G.SQ, 0, G.RADIUS)) end
    end
  end
  for n, piece in ipairs(pieces) do
    local course = d.courses[n]
    local dist = G.GAPW + LW / 2        -- stroke center-line distance from the squares
    -- convex corners wrap the square concentrically; a notch corner is
    -- concentric with the convex corner of whatever sits in the notch, so the
    -- white channel between neighboring outlines keeps its width round the bend
    local path, plen = rounded_path(outline(piece, dist, G), G.RF + dist, G.RF + G.GAPF - dist)
    local style
    if course.current then
      -- in-progress courses: dotted outline only, no region tint
      style = string.format("draw=%s, line width=%spt, %s", STROKE[course.band], LW, dots(plen, DOT_PITCH))
    else
      style = string.format("fill=%s, draw=%s, line width=%spt", PFILL[course.band], STROKE[course.band], LW)
    end
    w("\\draw[" .. style .. "] " .. path .. ";")
    for _, q in ipairs(piece) do
      w(sq(G, q[1], q[2], FILL[course.band], G.SQF, G.OFF, G.RF))
    end
  end
  for n, piece in ipairs(pieces) do
    local x, y = label_pos(G, piece)
    w(string.format("\\node[plate] at (%spt,%spt) {%s};", fmt(x), fmt(y), d.courses[n].label))
  end

  -- ---------- term bar ----------
  local terms = d.terms or {}
  if #terms > 0 then
    local width = (P.cols - 1) * G.PITCH + G.SQ
    local bar_y = -(P.rows * G.PITCH + 17)   -- top of the bar; room for a label above it
    local bar_h, gap = 8.5, 2.0
    local bars, sum = {}, 0
    for _, t in ipairs(terms) do
      local b = { label = fill_in(t.label or t[1] or ""), credits = t.credits or 0,
                  gpa = t.gpa, band = band(t.grade), current = t.current,
                  note = t.note and fill_in(t.note), honor = t.honor }
      sum = sum + b.credits
      bars[#bars + 1] = b
    end
    if sum ~= credits then
      warn("the terms add up to " .. sum .. " credits but the courses to " .. credits)
    end
    if remaining > 0 then
      bars[#bars + 1] = { label = fill_in(d.remaining or "{remaining} credits remaining"),
                          credits = remaining, rest = true }
    end
    local per = (width - gap * (#bars - 1)) / d.total
    local x = 0
    for _, b in ipairs(bars) do
      local bw = per * b.credits
      local color = b.rest and "gradeRem" or FILL[b.band]
      w(string.format("\\fill[fill=%s, rounded corners=1.5pt] (%spt,%spt) rectangle (%spt,%spt);",
                      color, fmt(x), fmt(bar_y), fmt(x + bw), fmt(bar_y - bar_h)))
      if b.current and inprog > 0 then
        -- the dotted box marks only the credits still in progress, at the
        -- right (later) end of the term; credits already earned stay solid
        local n = type(b.current) == "number" and b.current or inprog
        local px = x + per * (b.credits - n)
        local bx_w = (x + bw - 1.6) - (px + 1.6)
        local bx_h, br = bar_h - 3.2, 1.0
        local box_len = 2 * (bx_w + bx_h) - 8 * br + 2 * math.pi * br
        w(string.format("\\draw[draw=white, line width=0.6pt, %s, rounded corners=%spt] (%spt,%spt) rectangle (%spt,%spt);",
                        dots(box_len, 1.7), br, fmt(px + 1.6), fmt(bar_y - 1.6), fmt(x + bw - 1.6), fmt(bar_y - bar_h + 1.6)))
      end
      local cx = x + bw / 2
      -- GPAs of A terms in the darkest grade color
      local gcolor = (b.band == "A" or b.band == "Ap") and "gradeAp" or "black"
      if b.rest then
        -- the credits still to come: term line, then the running totals
        w(string.format("\\node[eranote, anchor=north east] at (%spt,%spt) {%s};",
                        fmt(x + bw), fmt(bar_y - bar_h - 3.5), b.label))
        if d.summary then
          w(string.format("\\node[summary, anchor=north east] at (%spt,%spt) {%s};",
                          fmt(x + bw), fmt(bar_y - bar_h - 12), fill_in(d.summary)))
        end
      elseif bw < 40 then
        -- too narrow for a label below: tick and label above the bar
        w(string.format("\\draw[draw=rule, line width=0.6pt] (%spt,%spt) -- (%spt,%spt);",
                        fmt(cx), fmt(bar_y), fmt(cx), fmt(bar_y + 3)))
        local gpa = b.gpa and string.format("{\\gpafont\\color{%s}%s}\\,·\\,", gcolor, b.gpa) or ""
        w(string.format("\\node[eranote, anchor=south] at (%spt,%spt) {%s%s};",
                        fmt(cx), fmt(bar_y + 4.5), gpa, b.label))
      else
        local y = bar_y - bar_h - 3
        if b.gpa then
          w(string.format("\\node[gpa, anchor=north, text=%s] at (%spt,%spt) {%s};",
                          gcolor, fmt(cx), fmt(y), b.gpa))
          y = y - 8.5
        end
        w(string.format("\\node[eralabel, anchor=north] at (%spt,%spt) {%s};", fmt(cx), fmt(y), b.label))
        if b.note then
          w(string.format("\\node[eranote, anchor=north, text=%s] at (%spt,%spt) {%s};",
                          b.honor and "highlight" or "gradeA", fmt(cx), fmt(y - 7.5), b.note))
        end
      end
      x = x + bw + gap
    end
  elseif d.summary then
    w(string.format("\\node[summary, anchor=north east] at (%spt,%spt) {%s};",
                    fmt((P.cols - 1) * G.PITCH + G.SQ), fmt(-(P.rows * G.PITCH + 3)), fill_in(d.summary)))
  end
  w("\\end{tikzpicture}")
  return o
end

-- Entry point for \creditmosaic: file name, line width in sp.
function M.draw(file, linewidth_sp)
  local ok, res = pcall(function() return render(load(file), linewidth_sp / 65536) end)
  if ok then
    tex.print(res)
  elseif type(res) == "table" and res.mosaic then
    tex.error("Credit mosaic: " .. res.mosaic, { "Fix " .. file .. " and build again." })
  else
    error(res, 0)
  end
end

return M
