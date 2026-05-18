local M = {}

local VERBS = { learn = true, edit = true, create = true, overview = true, reset = true }

--- Parse :Flashcard args into a {verb, name} pair.
--- @param fargs string[]    args from vim.api user-command opts
--- @return { verb: string, name: string? }
function M.parse(fargs)
  local a1 = fargs[1]
  if a1 == nil then
    return { verb = "learn", name = nil }
  end
  if VERBS[a1] then
    return { verb = a1, name = fargs[2] }
  end
  -- Backward-compat: :Flashcard <deck-name> → learn that deck
  return { verb = "learn", name = a1 }
end

local function prefix_filter(candidates, prefix)
  if prefix == "" then
    return vim.list_extend({}, candidates)
  end
  local out = {}
  for _, c in ipairs(candidates) do
    if c:sub(1, #prefix) == prefix then
      table.insert(out, c)
    end
  end
  return out
end

--- Completions for the first positional token: verbs ∪ deck names.
--- @param arg_lead string
--- @param names_fn fun(): string[]
function M.complete(arg_lead, names_fn)
  local candidates = { "learn", "edit", "create", "overview", "reset" }
  for _, n in ipairs(names_fn()) do
    table.insert(candidates, n)
  end
  return prefix_filter(candidates, arg_lead)
end

--- Completions for the second positional token.
--- @param verb string
--- @param arg_lead string
--- @param names_fn fun(): string[]
function M.complete_arg(verb, arg_lead, names_fn)
  if verb == "learn" or verb == "edit" or verb == "overview" or verb == "reset" then
    return prefix_filter(names_fn(), arg_lead)
  end
  -- `create` takes a new name; nothing to complete
  return {}
end

return M
