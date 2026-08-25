return {
  {
    "serhez/teide.nvim",
    lazy = false,
    priority = 1000,
    opts = {},
  },
  {
    "tadaa/vimade",
    opts = {
      recipe = { "minimalist", { animate = true } },
      fadelevel = 0.4,
    },
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "teide-dark",
    },
  },
}
