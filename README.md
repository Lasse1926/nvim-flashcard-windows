# nvim-flashcard

A Neovim plugin for learning with flashcards, backed by SM-2 spaced repetition.
Decks are plain markdown files you edit in the same editor you study in.

## Features

- Markdown decks — one file per deck, `---` between cards, `?` between front and back
- SM-2 scheduling with the familiar Again / Hard / Good / Easy ratings
- Centered floating-window review UI
- Picker auto-detects snacks.nvim or telescope.nvim (falls back to `vim.ui.select`)
- Per-deck JSON sidecar for scheduling state; your markdown is never modified
- Subcommands: `:Flashcard learn`, `:Flashcard edit`, `:Flashcard create`, `:Flashcard overview`

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "Lasse1926/nvim-flashcard-windows",
  opts = {},  -- see Configuration below
  cmd = "Flashcard",
}
```

snacks.nvim or telescope.nvim are optional; without either, the picker uses `vim.ui.select`.

## Configuration

```lua
require("flashcard").setup({
  decks_dir = vim.fn.stdpath("data") .. "/flashcard/decks",
  new_cards_per_day = 20,
  picker = nil, -- nil=auto | "snacks" | "telescope" | "select" | function
  keymaps = {
    reveal = "<Space>",
    again  = "1",
    hard   = "2",
    good   = "3",
    easy   = "4",
    quit   = "q",
  },
  window = { width = 0.5, height = 0.4, border = "rounded" },
})
```

## Usage

- `:Flashcard` — open the picker, then start a study session on the chosen deck (bare form = learn).
- `:Flashcard <deck-name>` — skip the picker; study the named deck.
- `:Flashcard learn [<deck-name>]` — same as above; explicit verb form.
- `:Flashcard edit [<deck-name>]` — open a deck markdown file in the current window. With no name, pick via the picker.
- `:Flashcard create [<deck-name>]` — create a new deck (prompts for the name if omitted) and open it for editing. A small starter template is written on first creation. If the deck already exists, it's opened without overwriting.
- `:Flashcard overview [<deck-name>]` — open a read-only list of every card in the deck, sorted by how long since you last reviewed it (never-reviewed cards at the top). Press `<CR>` to jump to the card in the deck file; `q` to close.

Tab completion:

- `:Flashcard <Tab>` → verbs (`learn`, `edit`, `create`, `overview`) plus existing deck names.
- `:Flashcard learn|edit|overview <Tab>` → deck names.
- `:Flashcard create <Tab>` → nothing (you're typing a new name).

Review keymaps:

- `<Space>` reveals the back
- `1` / `2` / `3` / `4` rates the card (Again / Hard / Good / Easy)
- `q` closes the session

## Deck format

- Each file is one deck.
- Cards are separated by a standalone `---` line (markdown horizontal rule).
- Within a card, a standalone `?` line separates the front from the back.
- Content before the first card (e.g. a `# Title`) is ignored.
- Multi-line fronts and backs are supported; leading/trailing whitespace is trimmed.

## State

For each deck `foo.md`, scheduling lives in a sibling `foo.state.json` file —
card ease, interval, reps, and next-due date. Writes are atomic (`.tmp` + rename).

## Development

```bash
make test     # run plenary/busted specs
make lint     # stylua --check
make format   # stylua in-place
```

## License

MIT
