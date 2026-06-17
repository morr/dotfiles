-- UTF-8-correct replacements for nvim-spider's string helpers.
--
-- nvim-spider only handles multibyte text when the `lua-utf8` luarock is
-- installed (see lua/spider/extras/utf8-support.lua); otherwise it works on raw
-- bytes. With byte positions, end-of-word motions (`e`/`ge`) land on the last
-- *byte* of a multibyte char — i.e. mid-character. Neovim then snaps the cursor
-- back to the char boundary, after which spider re-finds the same word's end and
-- the cursor gets stuck.
--
-- These drop-in helpers make every position a CHARACTER index (1-based), the
-- same contract `lua-utf8` provides, so motions land on character boundaries and
-- advance correctly — no native luarock needed. Assign the returned table to
-- `require("spider.extras.utf8-support").stringFuncs` after `spider.setup()`.
local CHAR = "[%z\1-\127\194-\244][\128-\191]*" -- one UTF-8 char

local function starts(s)
  local t = {}
  for p in s:gmatch("()" .. CHAR) do
    t[#t + 1] = p
  end
  t[#t + 1] = #s + 1 -- sentinel: one past the end
  return t
end

local function byte2char(s, b) -- 1-based byte pos -> 1-based char index
  local st = starts(s)
  for i = 1, #st - 1 do
    if b < st[i + 1] then
      return i
    end
  end
  return #st -- len + 1 (position past end)
end

local M = {}

M.len = function(s)
  return #starts(s) - 1
end

M.offset = function(s, n) -- char index -> 1-based byte pos
  local st = starts(s)
  return st[math.min(n, #st)]
end

M.initPos = function(s, col) -- col is 0-based byte
  local offset = 1
  for p in s:gmatch("()" .. CHAR) do
    if p > col then
      break
    end
    offset = offset + 1
  end
  return offset, offset
end

M.find = function(s, pat)
  local a, b = s:find(pat)
  if not a then
    return nil
  end
  return byte2char(s, a), byte2char(s, b)
end

M.gmatch = function(s, pat)
  local it = s:gmatch(pat)
  return function()
    local v = it()
    if type(v) == "number" then
      return byte2char(s, v)
    end
    return v
  end
end

M.reverse = function(s)
  local chars = {}
  for c in s:gmatch(CHAR) do
    chars[#chars + 1] = c
  end
  local out = {}
  for i = #chars, 1, -1 do
    out[#out + 1] = chars[i]
  end
  return table.concat(out)
end

return M
