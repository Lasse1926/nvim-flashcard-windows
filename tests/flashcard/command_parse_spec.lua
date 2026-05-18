local command = require("flashcard.command")

describe("command.parse", function()
  it("returns learn with no args for empty fargs", function()
    assert.same({ verb = "learn", name = nil }, command.parse({}))
  end)

  it("treats first arg as a verb when it matches a reserved name", function()
    assert.same({ verb = "learn", name = nil }, command.parse({ "learn" }))
    assert.same({ verb = "edit", name = nil }, command.parse({ "edit" }))
    assert.same({ verb = "create", name = nil }, command.parse({ "create" }))
    assert.same({ verb = "overview", name = nil }, command.parse({ "overview" }))
    assert.same({ verb = "reset", name = nil }, command.parse({ "reset" }))
  end)

  it("takes the second arg as the deck name for known verbs", function()
    assert.same({ verb = "learn", name = "geography" }, command.parse({ "learn", "geography" }))
    assert.same({ verb = "edit", name = "geography" }, command.parse({ "edit", "geography" }))
    assert.same({ verb = "create", name = "spanish" }, command.parse({ "create", "spanish" }))
    assert.same(
      { verb = "overview", name = "geography" },
      command.parse({ "overview", "geography" })
    )
    assert.same(
      { verb = "reset", name = "geography" },
      command.parse({ "reset", "geography" })
    )
  end)

  it("treats a non-verb first arg as a deck name for backward compat", function()
    assert.same({ verb = "learn", name = "geography" }, command.parse({ "geography" }))
  end)
end)

describe("command.complete — position 1", function()
  local function names_fn()
    return { "geography", "history", "learning-theory" }
  end

  it("includes reserved verbs and deck names", function()
    local matches = command.complete("", names_fn)
    table.sort(matches)
    -- verbs + decks, sorted
    assert.same(
      { "create", "edit", "geography", "history", "learn", "learning-theory", "overview", "reset" },
      matches
    )
  end)

  it("filters by prefix", function()
    local matches = command.complete("le", names_fn)
    table.sort(matches)
    assert.same({ "learn", "learning-theory" }, matches)
  end)
end)

describe("command.complete_arg — position 2", function()
  local function names_fn()
    return { "geography", "history" }
  end

  it("returns deck names for learn", function()
    local matches = command.complete_arg("learn", "", names_fn)
    table.sort(matches)
    assert.same({ "geography", "history" }, matches)
  end)

  it("returns deck names for edit filtered by prefix", function()
    local matches = command.complete_arg("edit", "hi", names_fn)
    assert.same({ "history" }, matches)
  end)

  it("returns nothing for create", function()
    assert.same({}, command.complete_arg("create", "", names_fn))
    assert.same({}, command.complete_arg("create", "spa", names_fn))
  end)

  it("returns deck names for overview", function()
    local matches = command.complete_arg("overview", "", names_fn)
    table.sort(matches)
    assert.same({ "geography", "history" }, matches)
  end)

  it("returns deck names for reset", function()
    local matches = command.complete_arg("reset", "", names_fn)
    table.sort(matches)
    assert.same({ "geography", "history" }, matches)
  end)
end)
