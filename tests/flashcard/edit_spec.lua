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

describe("flashcard.edit — by name", function()
  it("opens the deck file when the name matches", function()
    local dir = make_tmpdir()
    write_file(dir .. "/geo.md", "q\n?\na")
    fc.setup({ decks_dir = dir })

    local edits, restore_edit = stub_vim_cmd_edit()
    fc.edit("geo")
    restore_edit()

    assert.equals(1, #edits)
    assert.truthy(edits[1]:match("[/\\]geo%.md$"))
  end)

  it("notifies ERROR when the named deck does not exist", function()
    local dir = make_tmpdir()
    write_file(dir .. "/geo.md", "q\n?\na")
    fc.setup({ decks_dir = dir })

    local notifs, restore_notify = stub_vim_notify()
    local edits, restore_edit = stub_vim_cmd_edit()
    fc.edit("missing")
    restore_edit()
    restore_notify()

    assert.equals(0, #edits)
    assert.equals(1, #notifs)
    assert.equals(vim.log.levels.ERROR, notifs[1].level)
    assert.truthy(notifs[1].msg:match("deck not found"))
  end)
end)

describe("flashcard.edit — picker flow", function()
  it("dispatches the picker with prompt 'Edit deck' and edits on select", function()
    local dir = make_tmpdir()
    write_file(dir .. "/geo.md", "q\n?\na")
    write_file(dir .. "/hist.md", "q\n?\na")
    fc.setup({ decks_dir = dir })

    -- Stub the picker module
    local picker = require("flashcard.picker")
    local captured = {}
    local orig_pick = picker.pick
    picker.pick = function(items, opts, on_choose)
      captured.items = items
      captured.opts = opts
      -- simulate the user picking the first deck
      on_choose(items[1])
    end

    local edits, restore_edit = stub_vim_cmd_edit()
    fc.edit()
    restore_edit()
    picker.pick = orig_pick

    assert.equals("Edit deck", captured.opts.prompt)
    assert.equals(2, #captured.items)
    assert.equals(1, #edits)
    assert.truthy(edits[1]:match("%.md$"))
  end)

  it("notifies WARN when decks_dir is empty", function()
    local dir = make_tmpdir()
    fc.setup({ decks_dir = dir })

    local notifs, restore_notify = stub_vim_notify()
    local edits, restore_edit = stub_vim_cmd_edit()
    fc.edit()
    restore_edit()
    restore_notify()

    assert.equals(0, #edits)
    assert.equals(1, #notifs)
    assert.equals(vim.log.levels.WARN, notifs[1].level)
    assert.truthy(notifs[1].msg:match("no decks found"))
  end)
end)
