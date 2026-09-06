return {
  {
    "folke/noice.nvim",
    enabled = false,
  },
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      opts.formatters_by_ft.gdscript = { "gdscript-formatter" }
    end,
  },
  {
    "mfussenegger/nvim-lint",
    opts = function(_, opts)
      opts.linters_by_ft.gdscript = { "gdlint" }
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      table.insert(opts.ensure_installed, "gdscript")
    end,
  },
  {
    "saghen/blink.cmp",
    opts = function(_, opts)
      opts.signature = { enabled = true }
    end,
  },
}
