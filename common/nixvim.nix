{ config, lib, pkgs, username, ... }:

let
  # Helper function to enable a list of attributes
  # Takes a list of attribute names and returns an attrset with each name enabled
  enable = attrs: builtins.listToAttrs (map (name: { name = name; value.enable = true; }) attrs);

  # Converts Lua code to Vim script with proper lua command prefix
  # This allows embedding Lua code in Vim configuration
  luaToViml = s: let
    lines = lib.splitString "\n" s;
    nonEmptyLines = builtins.filter (line: line != "") lines;
    processed = map (
      line: if line == builtins.head nonEmptyLines then "lua " + line else "\\ " + line
    ) nonEmptyLines;
  in lib.concatStringsSep "\n" processed;

  # Normalizes a list of sources to ensure they all have the proper structure
  # Converts simple strings to attribute sets with name field
  mkSources = sources: map (source: if lib.isAttrs source then source else { name = source; }) sources;
in
{
  programs.nixvim = {
    config = {
      enable = true;
      colorschemes.tokyonight = {
        enable = true;
        settings.style = "night";
      };
      extraConfigLua = ''
        vim.cmd.hi 'Comment gui=none'
        vim.g.have_nerd_font = true
        vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }
        vim.schedule(function()
          vim.opt.clipboard = 'unnamedplus'
        end)
        require('which-key').setup({
          icons = {
            mappings = vim.g.have_nerd_font,
            keys = vim.g.have_nerd_font and {} or {
              Up = '<Up> ',
              Down = '<Down> ',
              Left = '<Left> ',
              Right = '<Right> ',
              C = '<C-…> ',
              M = '<M-…> ',
              D = '<D-…> ',
              S = '<S-…> ',
              CR = '<CR> ',
              Esc = '<Esc> ',
              ScrollWheelDown = '<ScrollWheelDown> ',
              ScrollWheelUp = '<ScrollWheelUp> ',
              NL = '<NL> ',
              BS = '<BS> ',
              Space = '<Space> ',
              Tab = '<Tab> ',
              F1 = '<F1>',
              F2 = '<F2>',
              F3 = '<F3>',
              F4 = '<F4>',
              F5 = '<F5>',
              F6 = '<F6>',
              F7 = '<F7>',
              F8 = '<F8>',
              F9 = '<F9>',
              F10 = '<F10>',
              F11 = '<F11>',
              F12 = '<F12>',
            },
          },
          spec = {
            c = { name = '+code', mode = { 'n', 'x' } },
            d = { name = '+document' },
            r = { name = '+rename' },
            s = { name = '+search' },
            w = { name = '+workspace' },
            t = { name = '+toggle' },
            h = { name = '+hunks', mode = { 'n', 'v' } },
          }
        })
        require('conform').setup({
          format_on_save = {
            lsp_fallback = true,
            timeout_ms = 500,
          },
          formatters_by_ft = {
            lua = { 'stylua' },
          },
        })
        require('mason').setup()
        require('telescope').setup()
        require('telescope').load_extension('fzf')
        require('telescope').load_extension('ui-select')
        vim.keymap.set('n', '<leader>gf', function()
          require('telescope.builtin').git_files { recurse_submodules = true }
        end)
        vim.keymap.set('n', '<leader>/', function()
          require('telescope.builtin').current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
            winblend = 10,
            previewer = false,
          })
        end, { desc = '[/] Fuzzily search in current buffer' })
        vim.keymap.set('n', '<leader>s/', function()
          require('telescope.builtin').live_grep {
            grep_open_files = true,
            prompt_title = 'Live Grep in Open Files',
          }
        end, { desc = '[S]earch [/] in Open Files' })
        vim.keymap.set('n', '<leader>sn', function()
          require('telescope.builtin').find_files { cwd = vim.fn.stdpath 'config' }
        end, { desc = '[S]earch [N]eovim files' })
      '';
      globals = {
        mapleader = " ";
        maplocalleader = " ";
      };
      opts = {
        number = true;
        mouse = "a";
        showmode = false;
        clipboard = "unnamedplus";
        breakindent = true;
        undofile = true;
        ignorecase = true;
        smartcase = true;
        signcolumn = "yes";
        updatetime = 250;
        timeoutlen = 300;
        splitright = true;
        splitbelow = true;
        list = true;
        inccommand = "split";
        cursorline = true;
        scrolloff = 10;
      };
      extraPackages = with pkgs; [
        nodePackages.typescript-language-server
        lua-language-server
        stylua
        git
        ripgrep
      ];
      keymaps = [
        { mode = "n"; key = "<Esc>"; action = "<cmd>nohlsearch<CR>"; options.silent = true; }
        { mode = "n"; key = "<leader>q"; action = "vim.diagnostic.setloclist"; options = { desc = "Open diagnostic [Q]uickfix list"; silent = true; }; }
        { mode = "t"; key = "<Esc><Esc>"; action = "<C-\\><C-n>"; options = { desc = "Exit terminal mode"; silent = true; }; }
        { mode = "n"; key = "<C-h>"; action = "<C-w><C-h>"; options = { desc = "Move focus to the left window"; }; }
        { mode = "n"; key = "<C-l>"; action = "<C-w><C-l>"; options = { desc = "Move focus to the right window"; }; }
        { mode = "n"; key = "<C-j>"; action = "<C-w><C-j>"; options = { desc = "Move focus to the lower window"; }; }
        { mode = "n"; key = "<C-k>"; action = "<C-w><C-k>"; options = { desc = "Move focus to the upper window"; }; }
        { mode = "n"; key = "<C-x>"; action = "<cmd>silent !tmux neww tmux-sessionizer<CR>"; options.silent = true; }
        { mode = "v"; key = "J"; action = ":m '>+1<CR>gv=gv"; options.silent = true; }
        { mode = "v"; key = "K"; action = ":m '<-2<CR>gv=gv"; options.silent = true; }
        { mode = "n"; key = "<leader><leader><leader><leader><leader><leader>l"; action = "<Plug>NetrwRefresh"; options = { silent = true; noremap = false; }; }
      ];
      autoCmd = [
        {
          event = "TextYankPost";
          pattern = "*";
          callback = { __raw = ''function() vim.highlight.on_yank() end''; };
        }
      ];
      plugins = {
        web-devicons.enable = true;
        treesitter = {
          enable = true;
          settings = {
            ensure_installed = [ "bash" "c" "diff" "html" "lua" "luadoc" "markdown" "markdown_inline" "query" "vim" "vimdoc" ];
            incremental_selection.enable = true;
            indent = { enable = true; };
            highlight = { enable = true; disable = [ "ruby" ]; };
          };
        };
        lsp = {
          enable = true;
          servers = {
            lua_ls = {
              enable = true;
              settings = {
                Lua = { completion = { callSnippet = "Replace"; }; };
              };
            };
          };
          onAttach = ''
            local map = function(keys, func, desc, mode)
              mode = mode or 'n'
              vim.keymap.set(mode, keys, func, { buffer = bufnr, desc = 'LSP: ' .. desc })
            end
            map('gd', require('telescope.builtin').lsp_definitions, '[G]oto [D]efinition')
            map('gr', require('telescope.builtin').lsp_references, '[G]oto [R]eferences')
            map('gI', require('telescope.builtin').lsp_implementations, '[G]oto [I]mplementation')
            map('<leader>D', require('telescope.builtin').lsp_type_definitions, 'Type [D]efinition')
            map('<leader>ds', require('telescope.builtin').lsp_document_symbols, '[D]ocument [S]ymbols')
            map('<leader>ws', require('telescope.builtin').lsp_dynamic_workspace_symbols, '[W]orkspace [S]ymbols')
            map('<leader>rn', vim.lsp.buf.rename, '[R]e[n]ame')
            map('<leader>ca', vim.lsp.buf.code_action, '[C]ode [A]ction', { 'n', 'x' })
            map('gD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')
            local client = vim.lsp.get_client_by_id(client_id)
            if client and client.supports_method(vim.lsp.protocol.Methods.textDocument_documentHighlight) then
              local highlight_augroup = vim.api.nvim_create_augroup('kickstart-lsp-highlight', { clear = false })
              vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
                buffer = bufnr,
                group = highlight_augroup,
                callback = vim.lsp.buf.document_highlight,
              })
              vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
                buffer = bufnr,
                group = highlight_augroup,
                callback = vim.lsp.buf.clear_references,
              })
              vim.api.nvim_create_autocmd('LspDetach', {
                group = vim.api.nvim_create_augroup('kickstart-lsp-detach', { clear = true }),
                callback = function(event)
                  vim.lsp.buf.clear_references()
                  vim.api.nvim_clear_autocmds { group = 'kickstart-lsp-highlight', buffer = event.buf }
                end,
              })
            end
            if client and client.supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint) then
              map('<leader>th', function()
                vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = bufnr })
              end, '[T]oggle Inlay [H]ints')
            end
          '';
        };
        lsp-format.enable = true;
        fidget.enable = true;
        cmp = {
          enable = true;
          settings = {
            snippet = {
              expand = ''function(args) require('luasnip').lsp_expand(args.body) end'';
            };
            completion = { completeopt = "menu,menuone,noinsert"; };
            mapping = {
              "<C-n>" = "cmp.mapping.select_next_item()";
              "<C-p>" = "cmp.mapping.select_prev_item()";
              "<C-b>" = "cmp.mapping.scroll_docs(-4)";
              "<C-f>" = "cmp.mapping.scroll_docs(4)";
              "<C-y>" = "cmp.mapping.confirm({ select = true })";
              "<C-Space>" = "cmp.mapping.complete({})";
              "<C-l>" = ''cmp.mapping(function() if luasnip.expand_or_locally_jumpable() then luasnip.expand_or_jump() end end, { 'i', 's' })'';
              "<C-h>" = ''cmp.mapping(function() if luasnip.locally_jumpable(-1) then luasnip.jump(-1) end end, { 'i', 's' })'';
            };
            sources = [
              { name = "nvim_lsp"; }
              { name = "luasnip"; }
              { name = "path"; }
            ];
          };
        };
        luasnip.enable = true;
        telescope = {
          enable = true;
          keymaps = {
            "<leader>sh" = "help_tags";
            "<leader>sk" = "keymaps";
            "<leader>sf" = "find_files";
            "<leader>ss" = "builtin";
            "<leader>sw" = "grep_string";
            "<leader>sg" = "live_grep";
            "<leader>sd" = "diagnostics";
            "<leader>sr" = "resume";
            "<leader>s." = "oldfiles";
            "<leader><leader>" = "buffers";
          };
        };
        gitsigns = {
          enable = true;
          settings = {
            signs = {
              add = { text = "+"; };
              change = { text = "~"; };
              delete = { text = "_"; };
              topdelete = { text = "‾"; };
              changedelete = { text = "~"; };
            };
          };
        };
        which-key = {
          enable = true;
          settings = {
            icons = {
              breadcrumb = "»";
              separator = "➜";
              group = "+";
            };
          };
        };
        todo-comments.enable = true;
        mini.enable = true;
        mini.modules = {
          ai = {};
          surround = {};
          statusline = { use_icons = true; };
        };
        tmux-navigator.enable = true;
      };
      extraPlugins = with pkgs.vimPlugins; [
        vim-sleuth
        vim-commentary
        lazydev-nvim
        plenary-nvim
        luvit-meta
        conform-nvim
        mason-nvim
        mason-lspconfig-nvim
        telescope-fzf-native-nvim
        telescope-ui-select-nvim
      ];
    };
  };
}
