return {
  {
    "jameswolensky/marker-groups.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim", -- Required
      "folke/snacks.nvim", -- Optional: Snacks picker
    },
    config = function()
      require("marker-groups").setup({
        -- Default picker is 'vim' (built-in vim.ui)
        -- Accepted values: 'vim' | 'snacks' | 'fzf-lua' | 'mini.pick' | 'telescope'
        picker = "snacks",
      })
    end,
  },
}
