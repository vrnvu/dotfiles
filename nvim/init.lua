-- Bootstrap lazy.nvim
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

-- Plugins
require("lazy").setup({
  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
  },
})

-- ============================================================================
-- Editor settings
-- ============================================================================
vim.g.mapleader = " "
vim.opt.background = "light"
vim.cmd("colorscheme default")

-- Display
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.cursorline = true
vim.opt.signcolumn = "auto"
vim.opt.colorcolumn = "80"
vim.opt.scrolloff = 8

-- Search
vim.opt.hlsearch = true
vim.opt.incsearch = true
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- Editing
vim.opt.smartindent = true
vim.opt.wrap = true
vim.opt.linebreak = true

-- Files
vim.opt.backup = false
vim.opt.swapfile = false
vim.opt.clipboard = "unnamedplus"

-- UI
vim.opt.termguicolors = true
vim.opt.showmode = false

-- Completion
vim.opt.completeopt = { "menu", "menuone", "noselect" }

-- ============================================================================
-- Diagnostics
-- ============================================================================
vim.diagnostic.config({
  virtual_text = true,
  signs = true,
  update_in_insert = false,
})

-- ============================================================================
-- LSP
-- ============================================================================
local function find_root(files)
  local root = vim.fs.dirname(vim.fs.find(files, { upward = true })[1] or vim.fn.getcwd())
  return root
end

-- Go
vim.api.nvim_create_autocmd("FileType", {
  pattern = "go",
  callback = function()
    vim.lsp.start({
      name = "gopls",
      cmd = { "gopls" },
      root_dir = find_root({ "go.mod", "go.work", ".git" }),
    })
  end,
})

-- C
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "c", "h" },
  callback = function()
    vim.lsp.start({
      name = "clangd",
      cmd = { "clangd" },
      root_dir = find_root({ ".git", "Makefile", "CMakeLists.txt", "compile_commands.json" }),
    })
  end,
})

-- LSP keybindings
vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("UserLspConfig", {}),
  callback = function(args)
    local opts = { buffer = args.buf }
    
    -- Navigation
    vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
    vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
    vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
    vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
    vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)
    vim.keymap.set("n", "<leader>td", vim.lsp.buf.type_definition, opts)
    
    -- Actions
    vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
    
    -- Completion
    vim.bo[args.buf].omnifunc = "v:lua.vim.lsp.omnifunc"
    vim.keymap.set("i", "<CR>", function()
      return vim.fn.pumvisible() == 1 and "<C-Y>" or "<CR>"
    end, { expr = true, buffer = args.buf })
    
    -- Format on save
    vim.api.nvim_create_autocmd("BufWritePre", {
      buffer = args.buf,
      callback = function()
        vim.lsp.buf.format({ async = false })
      end,
    })
  end,
})

-- ============================================================================
-- Keybindings
-- ============================================================================
-- File operations
vim.keymap.set("n", "<leader>fs", "<cmd>w<cr>", { desc = "Save file" })
vim.keymap.set("n", "<leader>fq", "<cmd>q<cr>", { desc = "Quit" })
vim.keymap.set("n", "<leader>fx", "<cmd>wq<cr>", { desc = "Save and quit" })

-- Diagnostics
vim.keymap.set("n", "]q", vim.diagnostic.goto_next, { desc = "Next diagnostic" })
vim.keymap.set("n", "[q", vim.diagnostic.goto_prev, { desc = "Previous diagnostic" })

-- Search
vim.keymap.set("n", "<Esc>", "<cmd>noh<cr><Esc>", { desc = "Clear search highlights" })

-- Quickfix
vim.keymap.set("n", "<leader>co", "<cmd>copen<cr>", { desc = "Open quickfix" })
vim.keymap.set("n", "<leader>cc", "<cmd>cclose<cr>", { desc = "Close quickfix" })
vim.keymap.set("n", "<leader>cx", function()
  vim.fn.setqflist({})
end, { desc = "Clear quickfix" })
vim.keymap.set("n", "]Q", "<cmd>cnext<cr>", { desc = "Next quickfix item" })
vim.keymap.set("n", "[Q", "<cmd>cprev<cr>", { desc = "Previous quickfix item" })

-- Telescope
vim.keymap.set("n", "<leader>ff", function()
  require("telescope.builtin").find_files()
end, { desc = "Find files" })
vim.keymap.set("n", "<leader>fg", function()
  require("telescope.builtin").live_grep()
end, { desc = "Live grep" })
vim.keymap.set("n", "<leader>fb", function()
  require("telescope.builtin").buffers()
end, { desc = "Find buffers" })
vim.keymap.set("n", "<leader>fh", function()
  require("telescope.builtin").help_tags()
end, { desc = "Help tags" })
