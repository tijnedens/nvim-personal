return {
  {
    "yelog/i18n.nvim",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      -- optional pickers:
      -- 'ibhagwan/fzf-lua',
      -- 'nvim-telescope/telescope.nvim',
    },
    config = function()
      require("i18n").setup({
        locales = { "en", "zh" },
        sources = { "src/locales/{locales}.json" },
      })
    end,
  },
}
