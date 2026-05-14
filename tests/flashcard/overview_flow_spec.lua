local fc = require("flashcard")

local function make_tmpdir()
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  return dir
end

local function write_file(path, content)
  local f = assert(io.open(path, "w"))
  f:write(content)
  f:close()
end

local function stub_vim_cmd_edit()
  local captured = {}
  local orig = vim.cmd.edit
  vim.cmd.edit = function(arg)
    table.insert(captured, arg)
  end
  return captured, function()
    vim.cmd.edit = orig
  end
end

local function stub_vim_notify()
  local captured = {}
  local orig = vim.notify
  vim.notify = function(msg, level)
    table.insert(captured, { msg = msg, level = level })
  end
  return captured, function()
    vim.notify = orig
  end
end

local function stub_ui_overview()
  local ui = require("flashcard.ui_overview")
  local captured = {}
  local orig = ui.run
  ui.run = function(cfg, ctx)
    captured.cfg = cfg
    captured.ctx = ctx
  end
  return captured, function()
    ui.run = orig
  end
end

local function simple_deck_body()
  return "What is the capital of France?\n?\nParis.\n\n---\n\nWhat is 2+2?\n?\n4\n"
end

describe("flashcard.overview — by name", function()
  it("builds rows and hands them to ui_overview", function()
    local dir = make_tmpdir()
    write_file(dir .. "/geo.md", simple_deck_body())
    fc.setup({ decks_dir = dir })

    local ui_calls, restore_ui = stub_ui_overview()
    fc.overview("geo")
    restore_ui()

    assert.equals("geo", ui_calls.ctx.deck_name)
    assert.equals(2, #ui_calls.ctx.rows)
    assert.is_function(ui_calls.ctx.on_select)
  end)

  it("notifies ERROR when the named deck does not exist", function()
    local dir = make_tmpdir()
    write_file(dir .. "/geo.md", simple_deck_body())
    fc.setup({ decks_dir = dir })

    local notifs, restore_notify = stub_vim_notify()
    local ui_calls, restore_ui = stub_ui_overview()
    fc.overview("missing")
    restore_ui()
    restore_notify()

    assert.is_nil(ui_calls.ctx)
    assert.equals(1, #notifs)
    assert.equals(vim.log.levels.ERROR, notifs[1].level)
    assert.truthy(notifs[1].msg:match("deck not found"))
  end)

  it("on_select edits the deck file and jumps to front_line", function()
    local dir = make_tmpdir()
    write_file(dir .. "/geo.md", simple_deck_body())
    fc.setup({ decks_dir = dir })

    local ui_calls, restore_ui = stub_ui_overview()
    fc.overview("geo")
    restore_ui()

    local second_row = ui_calls.ctx.rows[2] -- "What is 2+2?" at line 7
    assert.equals(7, second_row.front_line)

    -- Stub edit and notify both — with edit stubbed, the buffer isn't actually
    -- loaded, so nvim_win_set_cursor will fail and the pcall fallback will
    -- emit a WARN. Capturing it keeps test stdout clean.
    local edits, restore_edit = stub_vim_cmd_edit()
    local _, restore_notify = stub_vim_notify()
    ui_calls.ctx.on_select(second_row)
    restore_notify()
    restore_edit()

    assert.equals(1, #edits)
    assert.truthy(edits[1]:match("[/\\]geo%.md$"))
  end)
end)

describe("flashcard.overview — picker flow", function()
  it("dispatches the picker with prompt 'Overview deck'", function()
    local dir = make_tmpdir()
    write_file(dir .. "/geo.md", simple_deck_body())
    write_file(dir .. "/hist.md", simple_deck_body())
    fc.setup({ decks_dir = dir })

    local picker = require("flashcard.picker")
    local picked = {}
    local orig_pick = picker.pick
    picker.pick = function(items, opts, on_choose)
      picked.items = items
      picked.opts = opts
      on_choose(items[1])
    end

    local ui_calls, restore_ui = stub_ui_overview()
    fc.overview()
    restore_ui()
    picker.pick = orig_pick

    assert.equals("Overview deck", picked.opts.prompt)
    assert.equals(2, #picked.items)
    assert.truthy(ui_calls.ctx)
  end)

  it("notifies WARN when decks_dir is empty", function()
    local dir = make_tmpdir()
    fc.setup({ decks_dir = dir })

    local notifs, restore_notify = stub_vim_notify()
    local ui_calls, restore_ui = stub_ui_overview()
    fc.overview()
    restore_ui()
    restore_notify()

    assert.is_nil(ui_calls.ctx)
    assert.equals(1, #notifs)
    assert.equals(vim.log.levels.WARN, notifs[1].level)
    assert.truthy(notifs[1].msg:match("no decks found"))
  end)
end)
