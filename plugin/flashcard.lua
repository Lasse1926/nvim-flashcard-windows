if vim.g.loaded_flashcard == 1 then
  return
end
vim.g.loaded_flashcard = 1

local function dispatch(opts)
  local command = require("flashcard.command")
  local fc = require("flashcard")
  local parsed = command.parse(opts.fargs)
  if parsed.verb == "learn" then
    fc.learn(parsed.name)
  elseif parsed.verb == "edit" then
    fc.edit(parsed.name)
  elseif parsed.verb == "create" then
    fc.create(parsed.name)
  elseif parsed.verb == "overview" then
    fc.overview(parsed.name)
  elseif parsed.verb == "reset" then
    fc.reset(parsed.name)
  end
end

local function complete(arg_lead, cmd_line, cursor_pos)
  local command = require("flashcard.command")
  local fc = require("flashcard")

  -- Split the text before the cursor into tokens to decide position.
  local before = cmd_line:sub(1, cursor_pos)
  -- Strip the leading :Flashcard (or range prefix-free variant).
  local after_cmd = before:gsub("^%s*%S+%s*", "", 1)
  -- Count completed whitespace-separated tokens before arg_lead.
  local completed = 0
  for _ in after_cmd:sub(1, #after_cmd - #arg_lead):gmatch("%S+") do
    completed = completed + 1
  end

  if completed == 0 then
    return command.complete(arg_lead, fc._deck_names)
  end

  -- completed == 1: we have the verb; complete the second token.
  local verb_token = after_cmd:match("^%s*(%S+)")
  return command.complete_arg(verb_token, arg_lead, fc._deck_names)
end

vim.api.nvim_create_user_command("Flashcard", dispatch, {
  nargs = "*",
  desc = "Flashcard session — learn | edit | create | overview | reset (bare = learn)",
  complete = complete,
})
