README.md

# scope-hints.nvim

Grayed-out virtual text on a scope's closing line, echoing the line that opened
it - so a long block's `}`/`end` tells you what it closes. Pure core-treesitter
(fold queries), so it's language-agnostic and adds no per-language config.

## Install (lazy.nvim)

```lua
{
  "n1ghtmare/scope-hints.nvim",
  event = { "BufReadPost", "BufNewFile" },
  opts = {
    -- mode = "cursor",  -- only annotate the scope the cursor is in
  },
}
```

## Options

| option      | default     | meaning                                                  |
| ----------- | ----------- | -------------------------------------------------------- |
| `mode`      | `"always"`  | `"always"` = every visible scope; `"cursor"` = current   |
| `min_lines` | `17`        | only annotate scopes at least this many lines tall       |
| `max_len`   | `80`        | ellipsize hints longer than this                         |
| `hl`        | `"Comment"` | highlight group for the hint                             |
| `debounce`  | `120`       | ms to coalesce redraws after an event                    |

## Requirements

Neovim with treesitter parsers installed for the languages you use (any parser
shipping a `folds.scm` works — most do).
