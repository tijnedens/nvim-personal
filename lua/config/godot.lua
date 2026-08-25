local M = {}

local group = vim.api.nvim_create_augroup("GodotLsp", { clear = true })
local connected_projects = {} -- Track connected project roots

local function get_root()
  return vim.fs.root(0, { "project.godot" })
end

local function get_client()
  for _, client in ipairs(vim.lsp.get_clients({ name = "godot" })) do
    return client
  end
end

-- Function to attach LSP to current buffer
local function attach_to_current_buffer()
  local client = get_client()
  if not client then
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()

  -- Check if LSP is already attached to this buffer
  local clients = vim.lsp.get_clients({ bufnr = bufnr, name = "godot" })
  if #clients > 0 then
    return
  end

  -- Attach LSP to current buffer
  vim.lsp.buf_attach_client(bufnr, client.id)
end

function M.connect()
  local root = get_root()

  if not root then
    vim.notify("Not inside a Godot project", vim.log.levels.WARN)
    return
  end

  -- Check if we already have a client for this project
  if get_client() then
    vim.notify("Godot LSP already connected for this project")
    -- Still try to attach to current buffer if not already attached
    attach_to_current_buffer()
    return
  end

  -- Check if we've already connected to this project before (to prevent reconnection attempts)
  if connected_projects[root] then
    vim.notify("Godot LSP was previously connected to this project")
    return
  end

  local client_id = vim.lsp.start({
    name = "godot",
    cmd = vim.lsp.rpc.connect("127.0.0.1", 6005),
    root_dir = root,
  })

  if client_id then
    connected_projects[root] = true
    vim.notify("Godot LSP connected")
    -- Attach to current buffer
    attach_to_current_buffer()
  else
    vim.notify("Failed to connect to Godot LSP", vim.log.levels.ERROR)
  end
end

function M.disconnect()
  local client = get_client()

  if client then
    -- Remove from tracking when disconnecting
    local root = get_root()
    if root then
      connected_projects[root] = nil
    end
    client:stop()
    vim.notify("Godot LSP disconnected")
  end
end

function M.restart()
  M.disconnect()

  vim.defer_fn(function()
    M.connect()
  end, 100)
end

-- Function to attach LSP to all open buffers in the project
function M.attach_to_all_buffers()
  local client = get_client()
  if not client then
    vim.notify("Godot LSP not connected", vim.log.levels.WARN)
    return
  end

  local root = get_root()
  if not root then
    return
  end

  -- Get all loaded buffers
  local buffers = vim.api.nvim_list_bufs()
  for _, bufnr in ipairs(buffers) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      local bufname = vim.api.nvim_buf_get_name(bufnr)
      -- Check if buffer is in the project
      if bufname:match(root) then
        -- Check if LSP is already attached
        local clients = vim.lsp.get_clients({ bufnr = bufnr, name = "godot" })
        if #clients == 0 then
          vim.lsp.buf_attach_client(bufnr, client.id)
        end
      end
    end
  end
  vim.notify("Godot LSP attached to all project buffers")
end

-- User commands
vim.api.nvim_create_user_command("GodotLspConnect", M.connect, {})
vim.api.nvim_create_user_command("GodotLspDisconnect", M.disconnect, {})
vim.api.nvim_create_user_command("GodotLspRestart", M.restart, {})
vim.api.nvim_create_user_command("GodotLspAttachAll", M.attach_to_all_buffers, {})

-- Autocmd to attach LSP to new Godot buffers when they're opened
vim.api.nvim_create_autocmd({ "BufEnter", "BufNewFile" }, {
  group = group,
  pattern = "*.gd",
  callback = function()
    -- Only attach if we're in a Godot project and LSP is connected
    if get_root() and get_client() then
      attach_to_current_buffer()
    end
  end,
})

-- Remove DirChanged autocmd since you want manual control
-- vim.api.nvim_create_autocmd("DirChanged", {
--   group = group,
--   callback = function()
--     if get_root() then
--       M.connect()
--     else
--       M.disconnect()
--     end
--   end,
-- })

return M
