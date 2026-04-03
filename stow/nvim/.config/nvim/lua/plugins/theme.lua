-- Ember colorscheme — catppuccin with custom palette override.
-- Maps all catppuccin color slots to the Ember warm-amber palette.
return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    opts = {
      flavour = "mocha",
      transparent_background = true,
      term_colors = true,
      no_italic = false,
      no_bold = false,

      color_overrides = {
        mocha = {
          -- Base surfaces
          crust = "#0a0b10",
          mantle = "#0e1016",
          base = "#13151c",
          surface0 = "#1d2029",
          surface1 = "#282c38",
          surface2 = "#353a48",
          overlay0 = "#525866",
          overlay1 = "#656b79",

          -- Text
          subtext0 = "#817c72",
          subtext1 = "#a8a299",
          text = "#cdc8bc",

          -- Accent colors — remapped to Ember palette
          rosewater = "#cf8e5e", -- cursor, winbar (warm peach)
          flamingo = "#c47a9e", -- brackets, punctuation (dusty rose)
          pink = "#c47a9e", -- tags (dusty rose)
          mauve = "#a687c4", -- keywords, control flow (muted purple)
          red = "#c45c5c", -- errors, deletions (brick red)
          maroon = "#b05050", -- alt red contexts
          peach = "#cf8e5e", -- numbers, operators (warm peach)
          yellow = "#c9943e", -- types, THE signature amber
          green = "#7ab87f", -- strings, additions (sage)
          teal = "#6bb5a2", -- regex, special
          sky = "#6aadcf", -- operator alt (soft sky)
          sapphire = "#6a9fb5", -- constructors (steel blue)
          blue = "#6a9fb5", -- functions, methods (steel blue)
          lavender = "#c9943e", -- cursor line, visual sel (amber)
        },
      },

      styles = {
        comments = { "italic" },
        conditionals = { "italic" },
        functions = {},
        keywords = { "bold" },
        strings = {},
        variables = {},
      },

      integrations = {
        cmp = true,
        gitsigns = true,
        indent_blankline = { enabled = true },
        mason = true,
        mini = { enabled = true },
        native_lsp = {
          enabled = true,
          underlines = {
            errors = { "undercurl" },
            hints = { "undercurl" },
            warnings = { "undercurl" },
            information = { "undercurl" },
          },
        },
        neotree = true,
        noice = true,
        notify = true,
        snacks = true,
        telescope = { enabled = true },
        treesitter = true,
        which_key = true,
      },

      custom_highlights = function(colors)
        return {
          -- Cursor & selection — amber signature
          CursorLine = { bg = colors.surface0 },
          CursorLineNr = { fg = colors.yellow, bold = true },
          Visual = { bg = "#2a2520" },
          VisualNOS = { bg = "#2a2520" },

          -- Line numbers
          LineNr = { fg = colors.surface2 },

          -- Search
          Search = { bg = "#3a2e1a", fg = colors.yellow },
          IncSearch = { bg = colors.yellow, fg = colors.base },
          CurSearch = { bg = colors.yellow, fg = colors.base, bold = true },

          -- Matching parens
          MatchParen = { fg = colors.yellow, bold = true, underline = true },

          -- Window separators
          WinSeparator = { fg = colors.surface1 },

          -- Pmenu (completion)
          PmenuSel = { bg = colors.surface1, fg = colors.text },
          PmenuThumb = { bg = colors.surface2 },

          -- Float borders
          FloatBorder = { fg = colors.surface2 },

          -- Telescope
          TelescopeSelection = { bg = colors.surface0, fg = colors.text },
          TelescopeMatching = { fg = colors.yellow, bold = true },
          TelescopePromptPrefix = { fg = colors.yellow },

          -- Git signs
          GitSignsAdd = { fg = colors.green },
          GitSignsChange = { fg = colors.yellow },
          GitSignsDelete = { fg = colors.red },

          -- Indent guides
          IblIndent = { fg = colors.surface0 },
          IblScope = { fg = colors.surface2 },

          -- Mini.indentscope
          MiniIndentscopeSymbol = { fg = colors.surface2 },

          -- Dashboard/alpha
          DashboardHeader = { fg = colors.yellow },
          DashboardIcon = { fg = colors.yellow },

          -- Which-key
          WhichKey = { fg = colors.yellow },
          WhichKeyDesc = { fg = colors.text },
          WhichKeyGroup = { fg = colors.blue },

          -- Lazy.nvim
          LazyH1 = { bg = colors.yellow, fg = colors.base, bold = true },
          LazyButton = { bg = colors.surface0 },
          LazyButtonActive = { bg = colors.surface1, bold = true },
          LazySpecial = { fg = colors.yellow },

          -- Diagnostic virtual text
          DiagnosticVirtualTextError = { fg = colors.red, bg = "#1c1517" },
          DiagnosticVirtualTextWarn = { fg = colors.yellow, bg = "#1c1a14" },
          DiagnosticVirtualTextInfo = { fg = colors.blue, bg = "#141a1c" },
          DiagnosticVirtualTextHint = { fg = colors.teal, bg = "#141c1a" },
        }
      end,
    },
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin",
    },
  },
}
