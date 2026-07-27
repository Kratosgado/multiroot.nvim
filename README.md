# multiroot.nvim

VSCode-style multi-root workspaces for Neovim. Group N folders under one workspace file, and get:

- LSP servers that see every folder as a workspace root
- Fuzzy-find and live-grep across all folders
- Per-workspace session save/restore (open buffers, layout, cursor)
- Recent workspaces picker
- Auto-load a workspace when `nvim` is launched inside a folder with a `.nvim-workspace.json`
- Folder-scoped and named terminals declared in the workspace file
- One-shot tasks (build, test, deploy...) picked from the workspace file
- Per-workspace env vars (auto-applied, auto-restored on close)
- Per-workspace LSP settings overrides
- Statusline component
- Clean handoff on close/switch: wipes workspace file buffers and terminals, keeps unrelated buffers
- Git integration — `:WorkspaceGit` opens Neogit (or your custom tool) at the buffer's owning folder; optional auto-lcd on BufEnter for any cwd-based tool
- Ships a JSON schema — auto-registered with `jsonls` for completion + validation inside `.nvim-workspace.json`

> **Status:** v1. File tree with multiple roots is planned for v2 (requires a custom neo-tree source).

## Requirements

- Neovim 0.9+
- One of: [snacks.nvim](https://github.com/folke/snacks.nvim) or [fzf-lua](https://github.com/ibhagwan/fzf-lua) (for `:WorkspaceFiles` / `:WorkspaceGrep`)

## Install (lazy.nvim)

```lua
{
  "kratosgado/multiroot.nvim",
  event = "VeryLazy",
  opts = {
    -- these keys only exist while a workspace is active; removed on close
    keys_when_active = {
      { "<leader>qc", "<cmd>WorkspaceClose<cr>",     desc = "Workspace: close" },
      { "<leader>qf", "<cmd>WorkspaceFiles<cr>",     desc = "Workspace: files" },
      { "<leader>qg", "<cmd>WorkspaceGrep<cr>",      desc = "Workspace: grep" },
      { "<leader>qa", "<cmd>WorkspaceAddFolder<cr>", desc = "Workspace: add folder" },
      { "<leader>qi", "<cmd>WorkspaceList<cr>",      desc = "Workspace: info" },
    },
  },
  -- always-visible entry-point keys
  keys = {
    { "<leader>qo", "<cmd>WorkspaceOpen<cr>",   desc = "Workspace: open" },
    { "<leader>qr", "<cmd>WorkspaceRecent<cr>", desc = "Workspace: recent" },
  },
}
```

## Workspace file

A workspace is a JSON file. Place it anywhere; conventionally named `.nvim-workspace.json` at the parent directory of your repos:

```json
{
  "name": "acme",
  "folders": [
    "~/projects/acme-frontend",
    "~/projects/acme-backend",
    "~/projects/acme-shared"
  ],
  "terminals": [
    {
      "name": "backend-dev",
      "folder": "acme-backend",
      "cmd": "npm run dev",
      "env": "dev",
      "autostart": true
    },
    {
      "name": "backend-prod",
      "folder": "acme-backend",
      "cmd": "npm start",
      "env": "prod"
    },
    { "name": "shell", "folder": "acme-shared" }
  ],
  "tasks": [
    { "name": "build", "folder": "acme-backend", "cmd": "make" },
    { "name": "test", "folder": "acme-backend", "cmd": "pytest -q" },
    { "name": "deploy-prod", "cmd": "./scripts/deploy.sh", "env": "prod" }
  ],
  "env": {
    "AWS_PROFILE": "acme-dev",
    "DATABASE_URL": "postgres://localhost/acme"
  },
  "envs": {
    "dev": { "API_URL": "http://localhost:3000", "NODE_ENV": "development" },
    "staging": { "API_URL": "https://staging.acme.com", "NODE_ENV": "staging" },
    "prod": { "API_URL": "https://api.acme.com", "NODE_ENV": "production" }
  },
  "settings": {
    "lsp": {
      "lua_ls": {
        "settings": { "Lua": { "diagnostics": { "globals": ["vim"] } } }
      },
      "pyright": {
        "settings": { "python": { "pythonPath": "./venv/bin/python" } }
      }
    }
  }
}
```

`folder` may be the folder's basename (matched against the workspace `folders` list) or an absolute path. Paths can be absolute or use `~`. When a workspace is opened, Neovim `cd`s into the first folder.

- **terminals** — long-running processes; reopening a named terminal focuses the existing buffer. `autostart: true` launches on open. Omit `cmd` for a plain shell. `env: "profile"` layers a named profile onto the spawned process.
- **tasks** — one-shot commands run in a fresh terminal split each time. No autostart; no reuse. Also supports `env: "profile"`.
- **env** — always-on base env for the workspace. Set on open (previous values snapshotted), restored on close. Inherited by all terminals/tasks automatically.
- **envs** — named profiles. Referenced per-terminal / per-task via `"env": "<name>"`. Vars flow only into that child process — Neovim's own `vim.env` stays on the base. This means you can run `backend-dev` and `backend-prod` terminals side by side in different profiles.
- **keymaps** — team-shared keymaps applied on open, removed on close. `[{lhs, rhs, mode?, desc?}]`. Same trust model as `:h exrc` since `rhs` can be any Ex command — disable via `opts.workspace_keymaps.enabled = false`.
- **settings.lsp** — per-server config patch merged into `vim.lsp.config`; attached clients are notified via `workspace/didChangeConfiguration`. Reverted on close. Requires Neovim 0.11+.

## Commands

| Command                                | Description                                                   |
| -------------------------------------- | ------------------------------------------------------------- |
| `:WorkspaceOpen [file]`                | Open a workspace by path, or pick from recent                 |
| `:WorkspaceClose`                      | Close the active workspace (saves session)                    |
| `:WorkspaceReload`                     | Re-read the current workspace file from disk                  |
| `:WorkspaceGit`                        | Open the configured git tool at the buffer's workspace folder |
| `:WorkspaceEdit`                       | Open the current workspace's JSON file for editing            |
| `:WorkspaceCreate [folders...]`        | Create `.nvim-workspace.json` at cwd (defaults to cwd)         |
| `:WorkspaceAddFolder [dir]`            | Add a folder to the active workspace                          |
| `:WorkspaceRemoveFolder <dir>`         | Remove a folder from the active workspace                     |
| `:WorkspaceList`                       | Print the active workspace                                    |
| `:WorkspaceRecent`                     | Pick from recent workspaces                                   |
| `:WorkspaceFiles`                      | Fuzzy-find files across all folders                           |
| `:WorkspaceGrep`                       | Live-grep across all folders                                  |
| `:WorkspaceTerm [folder]`              | Open a terminal in a workspace folder (picker if omitted)     |
| `:WorkspaceTermRun [name]`             | Launch (or focus) a named terminal from the workspace file    |
| `:WorkspaceTermList`                   | List named terminals declared in the workspace                |
| `:WorkspaceTask [name]`                | Run a task (picker if omitted)                                |
| `:WorkspaceTaskList`                   | List workspace tasks                                          |
| `:WorkspaceSaveSession`                | Force save the current session                                |
| `:WorkspaceLoadSession`                | Restore the active workspace's session                        |

## Configuration

```lua
require("multiroot").setup({
  workspace_file = ".nvim-workspace.json", -- filename auto-detected in cwd
  data_dir = vim.fn.stdpath("data") .. "/multiroot",
  auto_load = true,           -- auto-open when cwd contains workspace_file
  session = {
    enabled = true,
    autosave = true,          -- save on VimLeavePre
    autoload = true,          -- load on WorkspaceOpen
  },
  lsp = {
    enabled = true,           -- add folders to LSP workspace roots
  },
  picker = "auto",            -- "snacks" | "fzf" | "auto"
  notify = true,
  -- keymaps registered on MultirootLoaded, deleted on MultirootClosed
  keys_when_active = {
    -- { "<leader>qf", "<cmd>WorkspaceFiles<cr>", desc = "Workspace: files", mode = "n" },
  },
  terminal = {
    autostart = true,         -- run terminals with autostart: true on open
  },
  on_close = {
    wipe_buffers = true,      -- delete file buffers under the workspace folders (skips modified)
    close_terminals = true,   -- kill named-terminal buffers for the workspace
  },
  schema = {
    register = true,          -- auto-register workspace.json schema with jsonls
  },
  git = {
    -- called by :WorkspaceGit with the buffer's owning workspace folder.
    -- Default: opens Neogit if installed. Override for lazygit / fugitive / etc.
    open = nil,
  },
  workspace_keymaps = {
    enabled = true,           -- respect the 'keymaps' field in workspace JSON
                              -- (same trust model as :h exrc)
  },
  on_buf_enter = {
    lcd = false,              -- if true, sets window-local cwd to the buffer's
                              -- workspace folder on BufEnter. Any cwd-based
                              -- tool (Neogit, lazygit, :!git) then Just Works.
  },
})
```

## API

```lua
local mr = require("multiroot")
mr.open(path)         -- open a workspace file
mr.close()            -- close current workspace
mr.create(folders?, name?)   -- always writes cwd/<workspace_file>
mr.reload()                  -- re-read the current workspace file
mr.folder_for_buffer(bufnr?) -- absolute path of the buffer's owning folder
mr.git(bufnr?)               -- open the configured git tool at that folder
mr.add_folder(path)
mr.remove_folder(path)
mr.current()          -- current workspace table or nil
mr.folders()          -- list of active folder paths
mr.files()            -- open files picker
mr.grep()             -- open grep picker
mr.recent()           -- open recent-workspaces picker
mr.terminal(folder?)  -- open terminal in folder (picker if nil)
mr.terminal_run(name?)-- launch/focus a named terminal (picker if nil)
mr.task(name?)        -- run a task (picker if nil)
mr.edit()             -- open the current workspace file for editing
mr.statusline(opts?)  -- string for lualine/heirline/etc. opts: { icon = true, folder = true, bufnr = 0 }
```

### Statusline

```lua
-- lualine
sections = {
  lualine_c = {
    { function() return require("multiroot").statusline() end },
  },
}
```

Returns `" acme:backend"` when a workspace is open (folder segment reflects the current buffer's owning folder), empty string otherwise. Also exposed: `require("multiroot.statusline").name()` and `.folder(bufnr)` for finer control.

## Events

`User` autocmds fired on state changes:

- `MultirootLoaded` — after opening a workspace (`data` = workspace table)
- `MultirootClosed` — after closing (`data` = workspace table that was closed)

```lua
vim.api.nvim_create_autocmd("User", {
  pattern = "MultirootLoaded",
  callback = function(args)
    print("opened workspace:", args.data.name)
  end,
})
```

## Closing / switching workspaces

`:WorkspaceClose` (and opening a different workspace on top of an active one) does the following, in order:

1. Saves the workspace session (if `session.autosave` is enabled)
2. Kills the workspace's named terminals (`on_close.close_terminals`)
3. Wipes file buffers whose path is under any of the workspace folders (`on_close.wipe_buffers`) — modified buffers are kept, and the count is included in the notification
4. Removes each folder from every attached LSP client
5. Fires `User MultirootClosed`

Buffers outside the workspace folders (help pages, scratch buffers, unrelated files) are untouched. Set either `on_close.wipe_buffers = false` or `on_close.close_terminals = false` to opt out.

## How multi-root LSP works

When a workspace is opened, each folder is added to every attached LSP client via `workspace/didChangeWorkspaceFolders`. For LSP clients that attach later (e.g. when you open a file in a different folder), an `LspAttach` autocmd adds the workspace folders automatically.

Not every language server honors multi-root — some indexes are still cwd-scoped. For those, use `:WorkspaceFiles` / `:WorkspaceGrep` to jump between folders.

## Git integration

`:WorkspaceGit` opens the configured git tool at the current buffer's owning folder — solving the multi-root problem where Neogit / lazygit / fugitive would otherwise always show the workspace's primary folder regardless of which file you're editing.

```lua
opts = {
  git = {
    open = function(cwd)
      require("neogit").open({ cwd = cwd })
      -- or: Snacks.terminal.open("lazygit", { cwd = cwd })
    end,
  },
}
```
Default falls back to Neogit when installed.

For workflows where you want *any* cwd-based tool to Just Work (not just git), enable `on_buf_enter.lcd = true` — a `BufEnter` autocmd sets the window-local cwd to the buffer's workspace folder. Off by default because it also changes what `:e some/path` resolves to.

## JSON schema

A schema at `schemas/workspace.json` describes every valid field of the workspace file. On `setup()` it's auto-registered with `jsonls` so `.nvim-workspace.json` gets completion, hover docs, and validation.

To disable: `opts.schema.register = false`. To grab the path for manual registration (e.g. with SchemaStore.nvim):

```lua
require("multiroot").schema_path()
```

## Roadmap

- **v2:** neo-tree custom source showing all roots as siblings in one tree view
- `:WorkspaceRename`, `:WorkspaceDelete`
- File pinning per workspace (harpoon-style)

## License

MIT
