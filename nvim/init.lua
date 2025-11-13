-- Bootstrap lazy.nvim (plugin manager - auto-installs on first run)
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Basic editor settings
vim.opt.number = true              -- Show line numbers
vim.opt.relativenumber = true      -- Show relative line numbers (distance from cursor)
vim.opt.clipboard = "unnamedplus"  -- Use system clipboard for yank/paste
vim.g.mapleader = " "              -- Leader key is space (for custom keybindings)
vim.opt.hlsearch = true            -- Highlight search matches
vim.opt.incsearch = true           -- Show search results as you type
vim.opt.ignorecase = true          -- Case-insensitive search
vim.opt.smartcase = true           -- Case-sensitive if search contains uppercase

-- File handling
vim.opt.encoding = "utf-8"         -- Use UTF-8 encoding
vim.opt.fileencoding = "utf-8"     -- Default file encoding
vim.opt.backup = false             -- Don't create backup files
vim.opt.writebackup = false        -- Don't create backup before overwriting
vim.opt.swapfile = false           -- Don't create swap files

-- Editing behavior
vim.opt.autoindent = true          -- Copy indent from previous line
vim.opt.smartindent = true         -- Smart auto-indenting
vim.opt.wrap = false               -- Don't wrap long lines
vim.opt.scrolloff = 8              -- Keep 8 lines above/below cursor when scrolling
vim.opt.sidescrolloff = 8          -- Keep 8 columns left/right when scrolling horizontally

-- Tab settings
vim.opt.tabstop = 2                -- Tab displays as 2 spaces
vim.opt.shiftwidth = 2             -- Indent with 2 spaces
vim.opt.expandtab = true           -- Use spaces instead of tabs

-- Visual improvements
vim.opt.cursorline = true          -- Highlight current line
vim.opt.termguicolors = true       -- Enable 24-bit RGB colors (better colors)
vim.opt.showmode = false           -- Don't show mode (statusline can show it)
vim.opt.signcolumn = "yes"         -- Always show sign column (for diagnostics)

-- Completion settings
vim.opt.completeopt = { "menu", "menuone", "noselect" }  -- Completion menu options

-- Enable diagnostics (LSP errors/warnings)
vim.diagnostic.config({
  virtual_text = true,             -- Show errors inline as virtual text
  signs = true,                     -- Show error signs in sign column
  update_in_insert = false,        -- Don't update diagnostics while typing
})

-- LSP Configuration - Go
vim.api.nvim_create_autocmd("FileType", {
  pattern = "go",
  callback = function()
    -- Find project root (go.mod, go.work, or .git directory)
    local root_dir = vim.fs.dirname(vim.fs.find({ "go.mod", "go.work", ".git" }, { upward = true })[1] or vim.fn.getcwd())
    
    -- Start gopls language server
    vim.lsp.start({
      name = "gopls",
      cmd = { "gopls" },
      root_dir = root_dir,
    })
  end,
})

-- LSP Configuration - C
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "c", "h" },
  callback = function()
    -- Find project root (.git, Makefile, CMakeLists.txt, or compile_commands.json)
    local root_dir = vim.fs.dirname(vim.fs.find({ ".git", "Makefile", "CMakeLists.txt", "compile_commands.json" }, { upward = true })[1] or vim.fn.getcwd())
    
    -- Start clangd language server (works with gcc)
    vim.lsp.start({
      name = "clangd",
      cmd = { "clangd" },
      root_dir = root_dir,
    })
  end,
})

-- Key mappings and format on save
vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("UserLspConfig", {}),
  callback = function(args)
    local opts = { buffer = args.buf }  -- Buffer-local keybindings
    
    -- LSP navigation
    vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)           -- Go to definition
    vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)                  -- Show hover documentation
    vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)       -- Go to implementation
    vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)           -- Find all references
    vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)          -- Go to declaration
    vim.keymap.set("n", "<leader>td", vim.lsp.buf.type_definition, opts) -- Go to type definition
    
    -- LSP actions
    vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)       -- Rename symbol
    
    -- Enable LSP completion (omnifunc)
    vim.bo[args.buf].omnifunc = "v:lua.vim.lsp.omnifunc"
    
    -- Enter to confirm completion (or insert newline if no completion menu)
    vim.keymap.set("i", "<CR>", function()
      if vim.fn.pumvisible() == 1 then
        return "<C-Y>"  -- Confirm completion
      else
        return "<CR>"   -- Insert newline
      end
    end, { expr = true, buffer = args.buf })
    
    -- Format on save (only for files with LSP attached)
    vim.api.nvim_create_autocmd("BufWritePre", {
      buffer = args.buf,
      callback = function()
        vim.lsp.buf.format({ async = false })  -- Format synchronously before saving
      end,
    })
  end,
})

-- General keybindings
vim.keymap.set("n", "<leader>fs", "<cmd>w<cr>", { desc = "Save file" })
vim.keymap.set("n", "<leader>fq", "<cmd>q<cr>", { desc = "Quit" })
vim.keymap.set("n", "<leader>fx", "<cmd>wq<cr>", { desc = "Save file and quit" })
vim.keymap.set("n", "<leader>ne", function()
  vim.diagnostic.goto_next()  -- Jump to next diagnostic (error/warning)
end, { desc = "Next error" })
vim.keymap.set("n", "]q", function()
  vim.diagnostic.goto_next()  -- Next diagnostic
end, { desc = "Next diagnostic" })
vim.keymap.set("n", "[q", function()
  vim.diagnostic.goto_prev()  -- Previous diagnostic
end, { desc = "Previous diagnostic" })

-- Clear search highlights with Escape
vim.keymap.set("n", "<Esc>", "<cmd>noh<cr><Esc>", { desc = "Clear search highlights" })

-- Quickfix list management
vim.keymap.set("n", "<leader>co", "<cmd>copen<cr>", { desc = "Open quickfix list" })
vim.keymap.set("n", "<leader>cc", "<cmd>cclose<cr>", { desc = "Close quickfix list" })
vim.keymap.set("n", "<leader>cx", function()
  vim.fn.setqflist({})  -- Clear quickfix list
end, { desc = "Clear quickfix list" })
vim.keymap.set("n", "]Q", "<cmd>cnext<cr>", { desc = "Next quickfix item" })
vim.keymap.set("n", "[Q", "<cmd>cprev<cr>", { desc = "Previous quickfix item" })
