local config = require("flashcard.config")

describe("config.setup", function()
  it("returns defaults when called with nil", function()
    local c = config.setup(nil)
    assert.equals(20, c.new_cards_per_day)
    assert.equals("<Space>", c.keymaps.reveal)
    assert.equals("rounded", c.window.border)
  end)

  it("deep-merges user overrides", function()
    local c = config.setup({
      new_cards_per_day = 5,
      keymaps = { reveal = "<CR>" },
      window = { width = 0.7 },
    })
    assert.equals(5, c.new_cards_per_day)
    assert.equals("<CR>", c.keymaps.reveal)
    -- keys not overridden keep their defaults
    assert.equals("1", c.keymaps.again)
    assert.equals(0.7, c.window.width)
    assert.equals(0.4, c.window.height)
    assert.equals("rounded", c.window.border)
  end)

  it("expands the decks_dir path", function()
    local c = config.setup({ decks_dir = "~/flashcards" })
    assert.truthy(c.decks_dir:match("^[/\\a-zA-Z]"))
    assert.equals(0, (c.decks_dir:find("~") or 0))
  end)

  it("defaults picker to nil (auto-detect)", function()
    local c = config.setup(nil)
    assert.is_nil(c.picker)
  end)

  it("preserves a string picker override", function()
    local c = config.setup({ picker = "snacks" })
    assert.equals("snacks", c.picker)
  end)

  it("preserves a function picker override", function()
    local fn = function() end
    local c = config.setup({ picker = fn })
    assert.equals(fn, c.picker)
  end)
end)
