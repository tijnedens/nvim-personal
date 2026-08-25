-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")
local mouse_name = "SteelSeries Rival 3"

local colors = {
  [vim.diagnostic.severity.ERROR] = { 255, 0, 0 },
  [vim.diagnostic.severity.WARN] = { 255, 165, 0 },
  [vim.diagnostic.severity.INFO] = { 0, 128, 255 },
  [vim.diagnostic.severity.HINT] = { 0, 255, 0 },
}

local last_severity = nil
local update_pending = false

local function openrgb(args)
  vim.fn.jobstart({
    "cmd.exe",
    "/c",
    "openrgb.exe " .. args .. " >NUL 2>&1",
  }, {
    detach = true,
  })
end

local function set_mouse_color(rgb)
  local hex = string.format("%02X%02X%02X", rgb[1], rgb[2], rgb[3])

  openrgb(string.format('--device "%s" --mode Direct --color %s', mouse_name, hex))
end

local function set_mouse_brightness(value)
  openrgb(string.format('--device "%s" --brightness %d', mouse_name, value))
end

local function get_worst_diagnostic()
  local worst = nil

  for _, diagnostic in ipairs(vim.diagnostic.get(vim.api.nvim_get_current_buf())) do
    if not worst or diagnostic.severity < worst then
      worst = diagnostic.severity
    end
  end

  return worst
end

local function update_mouse()
  -- Don't touch OpenRGB while editing
  if vim.api.nvim_get_mode().mode ~= "n" then
    update_pending = true
    return
  end

  update_pending = false

  local severity = get_worst_diagnostic()

  -- Nothing changed
  if severity == last_severity then
    return
  end

  last_severity = severity

  if severity then
    -- Turn brightness back on before setting the color
    set_mouse_brightness(100)
    set_mouse_color(colors[severity])
  else
    -- No diagnostics: turn LEDs off
    set_mouse_brightness(0)
  end
end

-- Diagnostics changed
vim.api.nvim_create_autocmd("DiagnosticChanged", {
  callback = update_mouse,
})

-- Switched buffer
vim.api.nvim_create_autocmd("BufEnter", {
  callback = update_mouse,
})

-- Returned to Normal mode
vim.api.nvim_create_autocmd("ModeChanged", {
  pattern = "*:n",
  callback = function()
    if update_pending then
      update_mouse()
    end
  end,
})
