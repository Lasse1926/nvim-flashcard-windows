local state = require("flashcard.state")

local function tmp_deck_path()
  return vim.fn.tempname() .. ".md"
end

describe("state.load — missing sidecar", function()
  it("returns an empty map", function()
    local result = state.load(tmp_deck_path())
    assert.same({}, result)
  end)
end)

describe("state.save + load round trip", function()
  it("persists and retrieves card state", function()
    local deck_path = tmp_deck_path()
    local original = {
      abc123 = {
        ease = 2.5,
        interval = 6,
        reps = 3,
        due = "2026-04-25",
        last_reviewed = "2026-04-21",
      },
      def456 = {
        ease = 1.9,
        interval = 1,
        reps = 0,
        due = "2026-04-22",
        last_reviewed = "2026-04-21",
      },
    }
    state.save(deck_path, original)
    assert.same(original, state.load(deck_path))
  end)

  it("overwrites an existing sidecar", function()
    local deck_path = tmp_deck_path()
    state.save(deck_path, {
      a = { ease = 2.5, interval = 1, reps = 1, due = "2026-04-22", last_reviewed = "2026-04-21" },
    })
    state.save(deck_path, {
      b = { ease = 2.0, interval = 2, reps = 2, due = "2026-04-23", last_reviewed = "2026-04-21" },
    })
    local loaded = state.load(deck_path)
    assert.is_nil(loaded.a)
    assert.equals(2.0, loaded.b.ease)
  end)
end)

describe("state.load — corrupt sidecar", function()
  it("returns empty and renames the corrupt file", function()
    local deck_path = tmp_deck_path()
    local sidecar = deck_path:gsub("%.md$", ".state.json")
    local f = assert(io.open(sidecar, "w"))
    f:write("{not valid json")
    f:close()

    local result = state.load(deck_path)
    assert.same({}, result)
    -- original corrupt file should no longer exist under its normal name
    assert.equals(0, vim.fn.filereadable(sidecar))
    -- a renamed backup should exist
    local matches = vim.fn.glob(sidecar .. ".corrupt-*", false, true)
    assert.is_true(#matches >= 1)
  end)
end)

describe("state.sidecar_path", function()
  it("derives sidecar from a POSIX deck path", function()
    assert.equals("/a/b/geography.state.json", state.sidecar_path("/a/b/geography.md"))
  end)

  it("derives sidecar from a Windows deck path", function()
    assert.equals("C:\\decks\\geography.state.json", state.sidecar_path("C:\\decks\\geography.md"))
  end)
end)
