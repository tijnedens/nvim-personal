return {
  {
    "folke/snacks.nvim",
    opts = function(_, opts)
      opts.explorer = vim.tbl_deep_extend("force", opts.explorer or {}, {
        replace_netrw = true,
        trash = true,
      })

      opts.picker = opts.picker or {}
      opts.picker.sources = opts.picker.sources or {}

      local uv = vim.uv or vim.loop
      local git_cache = {}

      local function exists(path)
        return uv.fs_stat(path) ~= nil
      end

      local function mtime(path)
        local stat = uv.fs_stat(path)
        return stat and stat.mtime.sec or 0
      end

      local function display_path(path)
        return vim.fn.fnamemodify(path, ":~")
      end

      local function relative_time(timestamp)
        if timestamp == 0 then
          return "unknown"
        end

        local diff = os.time() - timestamp

        if diff < 60 then
          return "now"
        elseif diff < 3600 then
          return ("%dm"):format(math.floor(diff / 60))
        elseif diff < 86400 then
          return ("%dh"):format(math.floor(diff / 3600))
        elseif diff < 604800 then
          return ("%dd"):format(math.floor(diff / 86400))
        elseif diff < 2592000 then
          return ("%dw"):format(math.floor(diff / 604800))
        elseif diff < 31536000 then
          return ("%dmo"):format(math.floor(diff / 2592000))
        end

        return os.date("%Y-%m-%d", timestamp)
      end

      local function project_type(path)
        if exists(path .. "/project.godot") then
          return "Godot"
        elseif exists(path .. "/package.json") then
          if
            exists(path .. "/next.config.js")
            or exists(path .. "/next.config.mjs")
            or exists(path .. "/next.config.ts")
          then
            return "Next.js"
          elseif exists(path .. "/vite.config.js") or exists(path .. "/vite.config.ts") then
            return "Vite"
          end

          return "Node.js"
        elseif exists(path .. "/Cargo.toml") then
          return "Rust"
        elseif exists(path .. "/go.mod") then
          return "Go"
        elseif
          exists(path .. "/pyproject.toml")
          or exists(path .. "/requirements.txt")
          or exists(path .. "/uv.lock")
        then
          return "Python"
        elseif exists(path .. "/pom.xml") then
          return "Java"
        elseif exists(path .. "/build.gradle") or exists(path .. "/build.gradle.kts") then
          return "Gradle"
        elseif exists(path .. "/composer.json") then
          return "PHP"
        elseif exists(path .. "/mix.exs") then
          return "Elixir"
        elseif exists(path .. "/flake.nix") then
          return "Nix"
        elseif exists(path .. "/CMakeLists.txt") then
          return "C/C++"
        elseif exists(path .. "/Makefile") then
          return "Make"
        end

        return "Project"
      end

      local function request_git(path, picker)
        if git_cache[path] ~= nil then
          return
        end

        git_cache[path] = {
          loading = true,
        }

        vim.system({
          "git",
          "-C",
          path,
          "status",
          "--porcelain=v1",
          "--branch",
        }, { text = true }, function(result)
          vim.schedule(function()
            if result.code ~= 0 then
              git_cache[path] = {
                enabled = false,
                loading = false,
              }
            else
              local output = result.stdout or ""
              local branch = output:match("^## ([^%.%s]+)") or "detached"

              local staged = 0
              local modified = 0
              local untracked = 0
              local deleted = 0

              for line in output:gmatch("[^\r\n]+") do
                if not line:match("^##") then
                  local x = line:sub(1, 1)
                  local y = line:sub(2, 2)

                  if x == "?" and y == "?" then
                    untracked = untracked + 1
                  else
                    if x ~= " " then
                      staged = staged + 1
                    end

                    if y ~= " " then
                      modified = modified + 1
                    end

                    if x == "D" or y == "D" then
                      deleted = deleted + 1
                    end
                  end
                end
              end

              git_cache[path] = {
                enabled = true,
                loading = false,
                branch = branch,
                staged = staged,
                modified = modified,
                untracked = untracked,
                deleted = deleted,
                dirty = staged > 0 or modified > 0 or untracked > 0 or deleted > 0,
              }
            end

            if picker and not picker.closed then
              picker:refresh()
            end
          end)
        end)
      end

      local function git_status(git)
        if not git or git.loading then
          return "…"
        end

        if not git.enabled then
          return "—"
        end

        local parts = {}

        if git.staged > 0 then
          parts[#parts + 1] = "+" .. git.staged
        end

        if git.modified > 0 then
          parts[#parts + 1] = "~" .. git.modified
        end

        if git.untracked > 0 then
          parts[#parts + 1] = "?" .. git.untracked
        end

        if git.deleted > 0 then
          parts[#parts + 1] = "-" .. git.deleted
        end

        return #parts > 0 and table.concat(parts, " ") or "clean"
      end

      local function project_format(item, picker)
        local project = item.project
        local git = git_cache[project.path]

        if not git then
          request_git(project.path, picker)
          git = { loading = true }
        end

        local git_hl

        if git.loading then
          git_hl = "Comment"
        elseif not git.enabled then
          git_hl = "Comment"
        elseif git.dirty then
          git_hl = "DiagnosticWarn"
        else
          git_hl = "DiagnosticOk"
        end

        local branch = "—"

        if git.loading then
          branch = "󰊢 …"
        elseif git.enabled then
          branch = "󰊢 " .. (git.branch or "detached")
        end

        return {
          {
            string.format("%-28s", project.name),
            "SnacksPickerFile",
          },
          {
            string.format("%-12s", project.type),
            "Comment",
          },
          {
            string.format("%-8s", project.modified),
            "Comment",
          },
          {
            string.format("%-18s", branch),
            git_hl,
          },
          {
            git_status(git),
            git_hl,
          },
        }
      end

      local function project_preview(ctx)
        local item = ctx.item

        if not item or not item.project then
          return false
        end

        local project = item.project
        local git = git_cache[project.path]

        if not git then
          request_git(project.path, ctx.picker)
          git = { loading = true }
        end

        local lines = {
          project.name,
          string.rep("─", 60),
          "",
          "Path",
          "  " .. project.display_path,
          "",
          "Type",
          "  " .. project.type,
          "",
          "Last modified",
          "  " .. project.modified,
          "",
          "Git",
        }

        if git.loading then
          lines[#lines + 1] = "  Loading..."
        elseif not git.enabled then
          lines[#lines + 1] = "  Not a Git repository"
        else
          lines[#lines + 1] = "  Branch:  " .. git.branch
          lines[#lines + 1] = "  Status:  " .. git_status(git)
        end

        lines[#lines + 1] = ""
        lines[#lines + 1] = "Project markers"

        local markers = {
          ".git",
          "project.godot",
          "package.json",
          "next.config.js",
          "next.config.ts",
          "vite.config.js",
          "vite.config.ts",
          "Cargo.toml",
          "go.mod",
          "pyproject.toml",
          "requirements.txt",
          "uv.lock",
          "Makefile",
          "CMakeLists.txt",
          "pom.xml",
          "build.gradle",
          "build.gradle.kts",
          "composer.json",
          "mix.exs",
          "flake.nix",
        }

        local found = false

        for _, marker in ipairs(markers) do
          if exists(project.path .. "/" .. marker) then
            lines[#lines + 1] = "  ✓ " .. marker
            found = true
          end
        end

        if not found then
          lines[#lines + 1] = "  No known project marker"
        end

        ctx.preview:reset()
        ctx.preview:set_lines(lines)

        return true
      end

      local function open_project(picker, item)
        picker:close()

        if not item or not item.project then
          return
        end

        local dir = item.project.path

        vim.cmd("tabonly")
        vim.cmd("tcd " .. vim.fn.fnameescape(dir))

        vim.schedule(function()
          local persistence = require("persistence")

          persistence.load()

          vim.defer_fn(function()
            if #vim.api.nvim_list_wins() == 1 then
              Snacks.explorer()
            end
          end, 100)
        end)
      end

      opts.picker.sources.projects = vim.tbl_deep_extend("force", opts.picker.sources.projects or {}, {
        finder = "recent_projects",

        dev = {
          "~/dev",
          "~/projects",
        },

        patterns = {
          ".git",
          "_darcs",
          ".hg",
          ".bzr",
          ".svn",
          "package.json",
          "project.godot",
          "Cargo.toml",
          "go.mod",
          "pyproject.toml",
          "requirements.txt",
          "uv.lock",
          "Makefile",
          "CMakeLists.txt",
          "pom.xml",
          "build.gradle",
          "build.gradle.kts",
          "composer.json",
          "mix.exs",
          "flake.nix",
        },

        recent = true,
        max_depth = 2,

        transform = function(item)
          local path = vim.fn.fnamemodify(item.file or item.text, ":p"):gsub("[/\\]+$", "")

          item.file = path
          item.text = path

          item.project = {
            path = path,
            name = vim.fn.fnamemodify(path, ":t"),
            display_path = display_path(path),
            type = project_type(path),
            modified = relative_time(mtime(path)),
          }

          return item
        end,

        format = project_format,
        preview = project_preview,
        confirm = open_project,

        matcher = {
          frecency = true,
          sort_empty = true,
          cwd_bonus = false,
        },

        sort = {
          fields = {
            "score:desc",
            "idx",
          },
        },

        win = {
          preview = {
            minimal = true,
          },

          input = {
            keys = {
              ["<c-e>"] = {
                { "tcd", "picker_explorer" },
                mode = { "n", "i" },
                desc = "Explorer",
              },

              ["<c-f>"] = {
                { "tcd", "picker_files" },
                mode = { "n", "i" },
                desc = "Files",
              },

              ["<c-g>"] = {
                { "tcd", "picker_grep" },
                mode = { "n", "i" },
                desc = "Grep",
              },

              ["<c-r>"] = {
                { "tcd", "picker_recent" },
                mode = { "n", "i" },
                nowait = true,
                desc = "Recent",
              },

              ["<c-w>"] = {
                { "tcd" },
                mode = { "n", "i" },
                desc = "Change directory",
              },

              ["<c-t>"] = {
                function(picker)
                  vim.cmd("tabnew")
                  picker:close()
                  Snacks.picker.projects()
                end,
                mode = { "n", "i" },
                desc = "New tab",
              },

              ["?"] = {
                function()
                  Snacks.notify({
                    "Enter     Open project + restore session",
                    "<C-e>     Explorer",
                    "<C-f>     Files",
                    "<C-g>     Grep",
                    "<C-r>     Recent files",
                    "<C-w>     Change directory",
                    "<C-t>     Open picker in new tab",
                    "?         Show shortcuts",
                  }, {
                    title = "Project Picker",
                    level = "info",
                  })
                end,
                mode = { "n", "i" },
                desc = "Show shortcuts",
              },
            },
          },
        },
      })

      return opts
    end,
  },
}
