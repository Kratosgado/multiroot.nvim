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

> **Status:** v1. File tree with multiple roots is planned for v2 (requires a custom neo-tree source).

## Requirements

- Neovim 0.9+
- One of: [snacks.nvim](https://github.com/folke/snacks.nvim) or [fzf-lua](https://github.com/ibhagwan/fzf-lua) (for `:WorkspaceFiles` / `:WorkspaceGrep`)

## Install (lazy.nvim)

```lua
{
  "multiroot.nvim",
  dir = "~/projects/configs/multiroot.nvim",
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
    { "name": "backend",  "folder": "acme-backend",  "cmd": "npm run dev", "autostart": true },
    { "name": "frontend", "folder": "acme-frontend", "cmd": "npm start" },
    { "name": "shell",    "folder": "acme-shared" }
  ],
  "tasks": [
    { "name": "build",  "folder": "acme-backend",  "cmd": "make" },
    { "name": "test",   "folder": "acme-backend",  "cmd": "pytest -q" },
    { "name": "deploy", "cmd": "./scripts/deploy.sh" }
  ],
  "env": {
    "AWS_PROFILE": "acme-dev",
    "DATABASE_URL": "postgres://localhost/acme"
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

- **terminals** — long-running processes; reopening a named terminal focuses the existing buffer. `autostart: true` launches on open. Omit `cmd` for a plain shell.
- **tasks** — one-shot commands run in a fresh terminal split each time. No autostart; no reuse.
- **env** — set on open (previous values snapshotted), restored on close.
- **settings.lsp** — per-server config patch merged into `vim.lsp.config`; attached clients are notified via `workspace/didChangeConfiguration`. Reverted on close. Requires Neovim 0.11+.

## Commands

| Command | Description |
|---|---|
| `:WorkspaceOpen [file]` | Open a workspace by path, or pick from recent |
| `:WorkspaceClose` | Close the active workspace (saves session) |
| `:WorkspaceCreate <file> [folders...]` | Create a workspace file (defaults to cwd if no folders given) |
| `:WorkspaceAddFolder [dir]` | Add a folder to the active workspace |
| `:WorkspaceRemoveFolder <dir>` | Remove a folder from the active workspace |
| `:WorkspaceList` | Print the active workspace |
| `:WorkspaceRecent` | Pick from recent workspaces |
| `:WorkspaceFiles` | Fuzzy-find files across all folders |
| `:WorkspaceGrep` | Live-grep across all folders |
| `:WorkspaceTerm [folder]` | Open a terminal in a workspace folder (picker if omitted) |
| `:WorkspaceTermRun [name]` | Launch (or focus) a named terminal from the workspace file |
| `:WorkspaceTermList` | List named terminals declared in the workspace |
| `:WorkspaceTask [name]` | Run a task (picker if omitted) |
| `:WorkspaceTaskList` | List workspace tasks |
| `:WorkspaceSaveSession` | Force save the current session |
| `:WorkspaceLoadSession` | Restore the active workspace's session |

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
})
```

## API

```lua
local mr = require("multiroot")
mr.open(path)         -- open a workspace file
mr.close()            -- close current workspace
mr.create(path, folders, name?)
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

## Roadmap

- **v2:** neo-tree custom source showing all roots as siblings in one tree view
- `:WorkspaceRename`, `:WorkspaceDelete`
- File pinning per workspace (harpoon-style)

## License

MIT
