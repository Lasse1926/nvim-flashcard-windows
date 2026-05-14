local deck_mod = require("flashcard.deck")
local state_mod = require("flashcard.state")
local util = require("flashcard.util")

local M = {}

function M.is_available()
  return pcall(require, "snacks.picker")
end

local function classify(state_row, today)
  if not state_row then
    return "new"
  end
  if state_row.due <= today then
    return "due"
  end
  return "scheduled"
end

local function show_preview(ctx)
  ctx.preview:reset()
  ctx.preview:minimal()

  local item = ctx.item
  if not item or not item.path then
    ctx.preview:set_lines({ "No deck selected" })
    return
  end

  local parsed = deck_mod.parse(item.path)
  if parsed.err then
    ctx.preview:set_lines({ parsed.err })
    return
  end

  local today = util.today()
  local st = state_mod.load(item.path)

  local due, new, scheduled = {}, {}, {}
  for _, card in ipairs(parsed.cards) do
    local row = st[card.id]
    local status = classify(row, today)
    local front = card.front:gsub("\n", " ")
    if status == "due" then
      table.insert(due, front)
    elseif status == "new" then
      table.insert(new, front)
    else
      table.insert(scheduled, { front = front, due = row.due })
    end
  end

  local lines = {}
  table.insert(lines, "# " .. (item.name or "Deck"))
  table.insert(lines, "")
  table.insert(lines, string.format(
    "**%d cards** — %d due · %d new · %d scheduled",
    #parsed.cards, #due, #new, #scheduled
  ))
  table.insert(lines, "")

  table.insert(lines, "## DUE")
  if #due > 0 then
    for _, f in ipairs(due) do
      table.insert(lines, "- " .. f)
    end
  else
    table.insert(lines, "_None_")
  end
  table.insert(lines, "")

  table.insert(lines, "## NEW")
  if #new > 0 then
    for _, f in ipairs(new) do
      table.insert(lines, "- " .. f)
    end
  else
    table.insert(lines, "_None_")
  end
  table.insert(lines, "")

  table.insert(lines, "## SCHEDULED")
  if #scheduled > 0 then
    table.sort(scheduled, function(a, b)
      return a.due < b.due
    end)
    for _, s in ipairs(scheduled) do
      table.insert(lines, "- `[" .. s.due .. "]` " .. s.front)
    end
  else
    table.insert(lines, "_None_")
  end

  ctx.preview:set_lines(lines)
  ctx.preview:highlight({ ft = "markdown" })
end

--- @param items      table[]   list of { name, path }
--- @param opts       { prompt: string }
--- @param on_choose  fun(item: table)
function M.pick(items, opts, on_choose)
  require("snacks.picker").pick({
    source = "flashcard_decks",
    items = items,
    format = function(item)
      return { { item.name, "Normal" } }
    end,
    preview = show_preview,
    confirm = function(picker, item)
      picker:close()
      if item then
        on_choose(item)
      end
    end,
    title = opts.prompt,
  })
end

return M
