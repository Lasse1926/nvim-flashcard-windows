local M = {}

local function defaults()
  return {
    decks_dir = vim.fn.stdpath("data") .. "/flashcard/decks",
    new_cards_per_day = 20,
    picker = nil,
    keymaps = {
      reveal = "<Space>",
      again = "1",
      hard = "2",
      good = "3",
      easy = "4",
      quit = "q",
    },
    window = {
      width = 0.5,
      height = 0.4,
      border = "rounded",
    },
  }
end

--- Merge user opts on top of defaults and expand paths.
--- @param user_opts table|nil
--- @return table config
function M.setup(user_opts)
  local cfg = vim.tbl_deep_extend("force", defaults(), user_opts or {})
  cfg.decks_dir = vim.fn.expand(cfg.decks_dir):gsub("\\", "/")
  return cfg
end

return M
