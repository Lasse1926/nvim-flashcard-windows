local M = {}

function M.is_available()
  return pcall(require, "telescope")
end

--- @param items table[]   list of { name, path }
--- @param opts  { prompt: string }
--- @param on_choose fun(item: table)
function M.pick(items, opts, on_choose)
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  pickers
    .new({}, {
      prompt_title = opts.prompt,
      finder = finders.new_table({
        results = items,
        entry_maker = function(d)
          return { value = d, display = d.name, ordinal = d.name, file = d.path }
        end,
      }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(bufnr)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          actions.close(bufnr)
          if selection then
            on_choose(selection.value)
          end
        end)
        return true
      end,
    })
    :find()
end

return M
