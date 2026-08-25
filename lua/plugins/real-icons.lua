return {
  "Mirsmog/real-icons.nvim",
  build = ":RealIcons install",
  opts = {
    integrations = {
      neo_tree = true,
      snacks_picker = true,
    },
  },
}
