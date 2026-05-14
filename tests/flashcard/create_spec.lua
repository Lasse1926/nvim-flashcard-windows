local fc = require("flashcard")

local function make_tmpdir()
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  return dir
end

local function read_file(path)
  local f = assert(io.open(path, "r"))
  local content = f:read("*a")
  f:close()
  return content
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

describe("flashcard.create — name validation", function()
  local function assert_rejected(name)
    local dir = make_tmpdir()
    fc.setup({ decks_dir = dir })
    local notifs, restore_notify = stub_vim_notify()
    local edits, restore_edit = stub_vim_cmd_edit()
    fc.create(name)
    restore_edit()
    restore_notify()
    assert.equals(0, #edits, "expected no :edit for name '" .. tostring(name) .. "'")
    assert.equals(1, #notifs)
    assert.equals(vim.log.levels.WARN, notifs[1].level)
    assert.truthy(notifs[1].msg:match("invalid deck name"))
  end

  it("rejects empty name", function()
    assert_rejected("")
  end)
  it("rejects whitespace-only name", function()
    assert_rejected("   ")
  end)
  it("rejects name with forward slash", function()
    assert_rejected("foo/bar")
  end)
  it("rejects name with backslash", function()
    assert_rejected("foo\\bar")
  end)
  it("rejects name starting with dot", function()
    assert_rejected(".hidden")
  end)
  it("rejects name ending with .md", function()
    assert_rejected("spanish.md")
  end)
end)

describe("flashcard.create — happy path", function()
  it("writes the template and opens the file when the deck is new", function()
    local dir = make_tmpdir()
    fc.setup({ decks_dir = dir })
    local edits, restore_edit = stub_vim_cmd_edit()
    fc.create("spanish")
    restore_edit()

    local target = dir .. "/spanish.md"
    assert.equals(1, vim.fn.filereadable(target))
    local content = read_file(target)
    assert.truthy(content:match("# spanish"))
    assert.truthy(content:match("What is an example question%?"))
    assert.truthy(content:match("%-%-%-"))
    assert.equals(1, #edits)
    assert.truthy(edits[1]:match("[/\\]spanish%.md$"))
  end)

  it("mkdir -p's a missing decks_dir", function()
    local parent = vim.fn.tempname()
    local dir = parent .. "/deep/nested"
    -- do not mkdir `dir`; create should do it
    fc.setup({ decks_dir = dir })
    local edits, restore_edit = stub_vim_cmd_edit()
    fc.create("spanish")
    restore_edit()

    assert.equals(1, vim.fn.isdirectory(dir))
    assert.equals(1, vim.fn.filereadable(dir .. "/spanish.md"))
  end)
end)

describe("flashcard.create — existing deck", function()
  it("does not overwrite; opens the existing file; notifies INFO", function()
    local dir = make_tmpdir()
    fc.setup({ decks_dir = dir })

    local target = dir .. "/spanish.md"
    local original = "existing content that must not be clobbered\n"
    local f = assert(io.open(target, "w"))
    f:write(original)
    f:close()

    local edits, restore_edit = stub_vim_cmd_edit()
    local notifs, restore_notify = stub_vim_notify()
    fc.create("spanish")
    restore_edit()
    restore_notify()

    assert.equals(original, read_file(target))
    assert.equals(1, #edits)
    assert.truthy(edits[1]:match("[/\\]spanish%.md$"))
    assert.equals(1, #notifs)
    assert.equals(vim.log.levels.INFO, notifs[1].level)
    assert.truthy(notifs[1].msg:match("already exists"))
  end)
end)

describe("flashcard.create — prompt flow", function()
  it("uses vim.ui.input when deck_name is nil, then creates", function()
    local dir = make_tmpdir()
    fc.setup({ decks_dir = dir })

    local orig_input = vim.ui.input
    vim.ui.input = function(opts, cb)
      assert.truthy(opts.prompt:match("Deck name"))
      cb("french")
    end

    local edits, restore_edit = stub_vim_cmd_edit()
    fc.create()
    restore_edit()
    vim.ui.input = orig_input

    assert.equals(1, vim.fn.filereadable(dir .. "/french.md"))
    assert.equals(1, #edits)
  end)

  it("aborts silently when vim.ui.input is cancelled", function()
    local dir = make_tmpdir()
    fc.setup({ decks_dir = dir })

    local orig_input = vim.ui.input
    vim.ui.input = function(_, cb)
      cb(nil)
    end

    local edits, restore_edit = stub_vim_cmd_edit()
    local notifs, restore_notify = stub_vim_notify()
    fc.create()
    restore_edit()
    restore_notify()
    vim.ui.input = orig_input

    assert.equals(0, #edits)
    assert.equals(0, #notifs)
  end)
end)
