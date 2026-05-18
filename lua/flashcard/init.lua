local config_mod = require("flashcard.config")
local deck_mod = require("flashcard.deck")
local state_mod = require("flashcard.state")
local srs_mod = require("flashcard.srs")
local scheduler_mod = require("flashcard.scheduler")
local picker_mod = require("flashcard.picker")
local ui_mod = require("flashcard.ui")
local overview_mod = require("flashcard.overview")
local ui_overview_mod = require("flashcard.ui_overview")
local util = require("flashcard.util")

local CREATE_TEMPLATE = [[# %s

<!--
How to author cards:
  - Separate cards with a line that is just '---'
  - Within a card, separate front and back with a line that is just '?'
  - Front/back may span multiple lines
Delete this comment block once you're comfortable with the format.
-->

What is an example question?
?
An example answer.

---

Front of the second card
?
Back of the second card
]]

local M = {}

local cfg

--- Merge user options over defaults. Call once from user config.
function M.setup(opts)
  cfg = config_mod.setup(opts)
end

local function ensure_cfg()
  if not cfg then
    cfg = config_mod.setup(nil)
  end
  return cfg
end

local function new_card_defaults(today)
  return { ease = 2.5, interval = 0, reps = 0, due = today, last_reviewed = nil }
end

local function start_session(deck_info)
  local parsed = deck_mod.parse(deck_info.path)
  if parsed.err then
    vim.notify("[flashcard] " .. parsed.err, vim.log.levels.ERROR)
    return
  end
  for _, w in ipairs(parsed.warnings or {}) do
    vim.notify("[flashcard] " .. deck_info.name .. ": " .. w, vim.log.levels.WARN)
  end

  local today = util.today()
  local st = state_mod.load(deck_info.path)
  local budget = cfg.new_cards_per_day

  -- Compute expected session size up front so the UI can show "Card N of M"
  -- based on this session rather than the whole deck.
  local due_count, new_count = 0, 0
  for _, c in ipairs(parsed.cards) do
    local row = st[c.id]
    if row then
      if row.due <= today then
        due_count = due_count + 1
      end
    else
      new_count = new_count + 1
    end
  end
  local total = due_count + math.min(new_count, budget)
  local seen_this_session = 0

  local function next_card()
    local card = scheduler_mod.next_due(parsed.cards, st, today, budget)
    if not card then
      return nil
    end
    if not st[card.id] then
      budget = budget - 1
    end
    seen_this_session = seen_this_session + 1
    return { card = card, index = seen_this_session, total = total }
  end

  local function rate(card, rating)
    local prev = st[card.id] or new_card_defaults(today)
    st[card.id] = srs_mod.rate(prev, rating, today)
    local ok, err = pcall(state_mod.save, deck_info.path, st)
    if not ok then
      vim.notify("[flashcard] state save failed: " .. tostring(err), vim.log.levels.ERROR)
    end
  end

  ui_mod.run(cfg, {
    next = next_card,
    rate = rate,
    on_close = function() end,
  })
end

--- Start a review session. If `deck_name` is given, skip the picker.
function M.start(deck_name)
  ensure_cfg()
  local decks = deck_mod.list(cfg.decks_dir)
  if #decks == 0 then
    vim.notify("[flashcard] no decks found at " .. cfg.decks_dir, vim.log.levels.WARN)
    return
  end

  if deck_name and deck_name ~= "" then
    for _, d in ipairs(decks) do
      if d.name == deck_name then
        start_session(d)
        return
      end
    end
    vim.notify("[flashcard] deck not found: " .. deck_name, vim.log.levels.ERROR)
    return
  end

  picker_mod.pick(decks, { prompt = "Study deck", cfg = cfg }, start_session)
end

--- Alias: the canonical name going forward is `learn`. `start` is preserved
--- for any existing external callers.
M.learn = M.start

--- Open a deck file for editing. If `deck_name` is nil, show the picker.
function M.edit(deck_name)
  ensure_cfg()
  local decks = deck_mod.list(cfg.decks_dir)

  if deck_name and deck_name ~= "" then
    for _, d in ipairs(decks) do
      if d.name == deck_name then
        vim.cmd.edit(vim.fn.fnameescape(d.path))
        return
      end
    end
    vim.notify("[flashcard] deck not found: " .. deck_name, vim.log.levels.ERROR)
    return
  end

  if #decks == 0 then
    vim.notify("[flashcard] no decks found at " .. cfg.decks_dir, vim.log.levels.WARN)
    return
  end

  picker_mod.pick(decks, { prompt = "Edit deck", cfg = cfg }, function(item)
    vim.cmd.edit(vim.fn.fnameescape(item.path))
  end)
end

local function validate_name(raw)
  if type(raw) ~= "string" then
    return nil, "expected string"
  end
  local name = raw:gsub("^%s+", ""):gsub("%s+$", "")
  if name == "" then
    return nil, "empty"
  end
  if name:find("[/\\]") then
    return nil, "contains slash"
  end
  if name:sub(1, 1) == "." then
    return nil, "starts with '.'"
  end
  if name:sub(-3) == ".md" then
    return nil, "ends with '.md' (extension added automatically)"
  end
  return name
end

local function do_create(name)
  local target = cfg.decks_dir .. "/" .. name .. ".md"

  vim.fn.mkdir(cfg.decks_dir, "p")

  if vim.fn.filereadable(target) == 1 then
    vim.cmd.edit(vim.fn.fnameescape(target))
    vim.notify("[flashcard] deck already exists — opened for editing", vim.log.levels.INFO)
    return
  end

  local f, open_err = io.open(target, "w")
  if not f then
    vim.notify("[flashcard] failed to create deck: " .. tostring(open_err), vim.log.levels.ERROR)
    return
  end
  local ok, write_err = pcall(function()
    f:write(CREATE_TEMPLATE:format(name))
  end)
  f:close()
  if not ok then
    vim.notify("[flashcard] failed to create deck: " .. tostring(write_err), vim.log.levels.ERROR)
    return
  end

  vim.cmd.edit(vim.fn.fnameescape(target))
end

--- Create a new deck (or open an existing one with the same name).
--- If `deck_name` is nil, prompts via vim.ui.input.
function M.create(deck_name)
  ensure_cfg()

  local function proceed(raw)
    if raw == nil then
      return -- cancelled; abort silently
    end
    local name, err = validate_name(raw)
    if not name then
      vim.notify("[flashcard] invalid deck name: " .. err, vim.log.levels.WARN)
      return
    end
    do_create(name)
  end

  if deck_name ~= nil then
    proceed(deck_name)
    return
  end

  vim.ui.input({ prompt = "Deck name: " }, proceed)
end

local function open_overview(deck_info)
  local parsed = deck_mod.parse(deck_info.path)
  if parsed.err then
    vim.notify("[flashcard] " .. parsed.err, vim.log.levels.ERROR)
    return
  end
  for _, w in ipairs(parsed.warnings or {}) do
    vim.notify("[flashcard] " .. deck_info.name .. ": " .. w, vim.log.levels.WARN)
  end

  local today = util.today()
  local st = state_mod.load(deck_info.path)
  local rows = overview_mod.build_rows(parsed.cards, st, today)

  ui_overview_mod.run(cfg, {
    deck_name = deck_info.name,
    rows = rows,
    on_select = function(row)
      vim.cmd.edit(vim.fn.fnameescape(deck_info.path))
      local ok = pcall(vim.api.nvim_win_set_cursor, 0, { row.front_line, 0 })
      if not ok then
        vim.notify(
          "[flashcard] could not jump to line "
            .. tostring(row.front_line)
            .. " — deck file may have shrunk",
          vim.log.levels.WARN
        )
        return
      end
      vim.cmd("normal! zz")
    end,
  })
end

--- Open the read-only overview for a deck. If `deck_name` is nil, show the picker.
function M.overview(deck_name)
  ensure_cfg()
  local decks = deck_mod.list(cfg.decks_dir)

  if deck_name and deck_name ~= "" then
    for _, d in ipairs(decks) do
      if d.name == deck_name then
        open_overview(d)
        return
      end
    end
    vim.notify("[flashcard] deck not found: " .. deck_name, vim.log.levels.ERROR)
    return
  end

  if #decks == 0 then
    vim.notify("[flashcard] no decks found at " .. cfg.decks_dir, vim.log.levels.WARN)
    return
  end

  picker_mod.pick(decks, { prompt = "Overview deck", cfg = cfg }, open_overview)
end

--- Reset scheduling data for a deck. If `deck_name` is nil, show the picker.
function M.reset(deck_name)
  ensure_cfg()
  local decks = deck_mod.list(cfg.decks_dir)

  local function do_reset(deck_info)
    local msg = "Reset scheduling data for '" .. deck_info.name .. "'?"
    local choice = vim.fn.confirm(msg, "&Yes\n&No", 2)
    if choice ~= 1 then
      return
    end
    state_mod.save(deck_info.path, {})
    vim.notify("[flashcard] reset scheduling data for " .. deck_info.name, vim.log.levels.INFO)
  end

  if deck_name and deck_name ~= "" then
    for _, d in ipairs(decks) do
      if d.name == deck_name then
        do_reset(d)
        return
      end
    end
    vim.notify("[flashcard] deck not found: " .. deck_name, vim.log.levels.ERROR)
    return
  end

  if #decks == 0 then
    vim.notify("[flashcard] no decks found at " .. cfg.decks_dir, vim.log.levels.WARN)
    return
  end

  picker_mod.pick(decks, { prompt = "Reset deck", cfg = cfg }, do_reset)
end

--- Internal: list deck names (for :Flashcard tab completion).
function M._deck_names()
  ensure_cfg()
  local out = {}
  for _, d in ipairs(deck_mod.list(cfg.decks_dir)) do
    table.insert(out, d.name)
  end
  return out
end

return M
