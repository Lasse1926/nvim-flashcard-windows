local M = {}

--- Derive the sidecar JSON path for a deck file.
--- @param deck_path string e.g. "/x/geography.md"
--- @return string e.g. "/x/geography.state.json"
function M.sidecar_path(deck_path)
  return (deck_path:gsub("%.md$", ".state.json"))
end

local function read_file(path)
  local f = io.open(path, "r")
  if not f then
    return nil
  end
  local content = f:read("*a")
  f:close()
  return content
end

--- Load the per-card state map for a deck.
--- Returns an empty table for missing files. Corrupt files are renamed to
--- `<sidecar>.corrupt-<timestamp>` and an empty table is returned.
--- @param deck_path string
--- @return table<string, table>  card-id -> { ease, interval, reps, due, last_reviewed }
function M.load(deck_path)
  local path = M.sidecar_path(deck_path)
  local content = read_file(path)
  if not content then
    return {}
  end

  local ok, decoded = pcall(vim.json.decode, content)
  if not ok or type(decoded) ~= "table" then
    local backup = path .. ".corrupt-" .. os.time()
    os.remove(backup)
    local rename_ok = os.rename(path, backup)
    if rename_ok then
      vim.notify("[flashcard] corrupt sidecar, moved to " .. backup, vim.log.levels.WARN)
    else
      vim.notify("[flashcard] corrupt sidecar at " .. path, vim.log.levels.WARN)
    end
    return {}
  end

  return decoded.cards or {}
end

--- Atomically save the per-card state map for a deck.
--- Writes to `<sidecar>.tmp` then renames over the target so a partial write
--- never overwrites a good sidecar.
--- @param deck_path string
--- @param cards table<string, table>
function M.save(deck_path, cards)
  local path = M.sidecar_path(deck_path)
  local payload = vim.json.encode({ version = 1, cards = cards })

  local tmp = path .. ".tmp"
  local f, err = io.open(tmp, "w")
  if not f then
    error("flashcard: cannot open " .. tmp .. " for writing: " .. tostring(err))
  end
  f:write(payload)
  f:close()

  -- Windows-safe atomic replace
  os.remove(path) -- ignore error if file doesn't exist

  local ok, rename_err = os.rename(tmp, path)
  if not ok then
    error("flashcard: cannot rename " .. tmp .. " to " .. path .. ": " .. tostring(rename_err))
  end
end

return M
