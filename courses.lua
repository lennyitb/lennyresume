-- courses.lua: the data behind the credit mosaic.
-- One square is one credit; each course is a shape of that many squares.

return {
  total = 123,   -- credits the degree needs; the grid has this many squares
  rows  = 5,     -- squares per column

  -- Every course, in the order taken:
  --   { id, label, credits, grade }
  --   id       a short code for the layout map below (no spaces)
  --   label    the text on the course; "\n" breaks the line
  --   credits  how many squares
  --   grade    A+, A, A-, B+, B, ...: A+ is darkest, then A, then B, then
  --            C and anything lower. For a course in progress, the grade you
  --            expect, and add current = true to give it a dotted outline.
  courses = {
    -- Spring 2025
    { "TS", "Turn\nSignals",        3, "B" },
    { "B1", "Breathing I",          4, "A" },
    { "HT", "Honk Theory",          3, "A-" },
    { "NP", "Naps",                 1, "A" },
    -- Fall 2025
    { "RS", "Road Signs",           2, "B" },
    { "B2", "Breathing II",         4, "A" },
    { "LT", "Left Turns",           3, "C+" },
    { "PS", "Primal\nScream",       3, "A" },
    { "RB", "Roundabouts",          3, "B" },
    -- Spring 2026
    { "CT", "Counting\nto Ten",     3, "A" },
    { "PP", "Parallel\nParking",    3, "A" },
    { "SN", "Serenity\nNow",        3, "A" },
    { "ZM", "Zipper\nMerge",        3, "A+" },
    { "SB", "Stress Balls",         3, "A" },
    -- Summer 2026
    { "DT", "Drive-Thru",           3, "A" },
    -- Fall 2026
    { "CD", "Cul-de-sacs",          3, "A" },
    { "PA", "Passive\nAggression",  3, "A", current = true },
    { "RR", "Road Rage I",          4, "A", current = true },
    { "FW", "Four-Way\nStops",      4, "A", current = true },
    { "YG", "Yoga",                 1, "A", current = true },
  },

  -- Where each course goes: the grid as you'll see it, top row first, one
  -- id per square. Write each id once per credit, in squares that touch
  -- side to side. "." leaves a square empty. Courses you leave out are
  -- placed automatically in the free squares, and every build writes the
  -- full map to the log (resume.log), so you can start without a layout,
  -- copy the map from the log, and rearrange it.
  layout = [[
    TS TS HT B2 PP PS PS SB SB PA PA FW FW
    TS HT HT B2 PP PP PS SB DT DT PA FW
    B1 B1 B2 B2 RB RB SN SN DT RR RR FW
    B1 RS RS LT CT RB SN ZM CD CD RR
    B1 NP LT LT CT CT ZM ZM CD YG RR
  ]],

  -- The bar under the grid: the same credits split by term, in order.
  --   { label, credits = n, gpa = "3.50", grade = "A" }
  --   grade    colors the bar like a course square
  --   note     a line under the label; honor = true sets it in the highlight color
  --   current  true for the term in progress: its in-progress credits get a
  --            dotted box
  -- In any label, {credits}, {total}, {remaining} and {inprogress} become
  -- those numbers. {credits} counts courses in progress.
  terms = {
    { "Spring 2025 · 11 cr",   credits = 11, gpa = "3.65", grade = "A" },
    { "Fall 2025 · 15 cr",     credits = 15, gpa = "3.33", grade = "B",
      note = "The left turn incident" },
    { "Spring 2026 · 15 cr",   credits = 15, gpa = "4.00", grade = "A",
      note = "Road Scholar's List", honor = true },
    { "Summer 2026 · 3 cr",    credits = 3,  gpa = "4.00", grade = "A" },
    { "Fall 2026 · 15 cr",     credits = 15, gpa = "4.00", grade = "A", current = true,
      note = "3 completed · {inprogress} in progress" },
  },
  -- The gray end of the bar, and the line under it
  remaining = "Spring 2027 – Winter 2028 · {remaining} credits remaining",
  summary   = "GPA 3.70 cumulative · {credits} of {total} credits · B.S. Winter 2028",
}
