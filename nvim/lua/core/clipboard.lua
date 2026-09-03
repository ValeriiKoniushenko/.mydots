-- Guarded system clipboard.
--
-- Issues this covers:
--   * unnamedplus with no provider (errors on every yank)
--   * unnamedplus disabling Neovim's automatic OSC 52 fallback
--   * OSC 52 paste blocking 1–10s (never used)
--   * SSH using the remote clipboard instead of the local terminal
--   * stale DISPLAY / xclip / xsel hanging the UI
--   * huge yanks blowing the terminal (OSC 52)
--   * clipboard calls going through a slow/interactive zsh (`:h system()` List form)
--   * headless / VSCode-neovim (no TUI clipboard)

local MAX_OSC52_BYTES = 256 * 1024
local CMD_TIMEOUT_MS = 1000
local X11_PROBE_MS = 250

local warned = {}

local function warn_once(key, msg)
  if warned[key] then
    return
  end
  warned[key] = true
  vim.notify(msg, vim.log.levels.WARN)
end

local function is_ssh()
  return vim.env.SSH_TTY ~= nil or vim.env.SSH_CONNECTION ~= nil or vim.env.SSH_CLIENT ~= nil
end

local function byte_len(lines)
  local n = 0
  for i, line in ipairs(lines) do
    n = n + #line
    if i < #lines then
      n = n + 1
    end
  end
  return n
end

local function run(cmd, opts)
  opts = opts or {}
  local sys_opts = {
    timeout = opts.timeout or CMD_TIMEOUT_MS,
    text = true,
  }
  if opts.stdin then
    sys_opts.stdin = opts.stdin
  end

  local ok, proc = pcall(vim.system, cmd, sys_opts)
  if not ok then
    return nil, proc
  end

  local result = proc:wait()
  if result.code ~= 0 then
    local err = (result.stderr and result.stderr ~= "" and result.stderr)
      or ("exit " .. tostring(result.code))
    return nil, err
  end
  return result.stdout or "", nil
end

local function make_copy(cmd)
  return function(lines)
    local text = table.concat(lines, "\n")
    local _, err = run(cmd, { stdin = text })
    if err then
      warn_once("copy", "Clipboard copy failed: " .. tostring(err))
    end
  end
end

local function make_paste(cmd)
  return function()
    local out, err = run(cmd)
    if not out then
      warn_once("paste", "Clipboard paste failed: " .. tostring(err))
      return { "" }
    end
    -- Keep a final empty line if the clipboard ended with a newline.
    return vim.split(out, "\n", { plain = true })
  end
end

local function provider_spec(name, copy_cmd, paste_cmd)
  local copy = make_copy(copy_cmd)
  local paste = make_paste(paste_cmd)
  return {
    name = name,
    copy = { ["+"] = copy, ["*"] = copy },
    paste = { ["+"] = paste, ["*"] = paste },
    cache_enabled = true,
  }
end

local function probe_x11(bin)
  if not vim.env.DISPLAY or vim.env.DISPLAY == "" then
    return false
  end
  if vim.fn.executable(bin) ~= 1 then
    return false
  end

  local cmd
  if bin == "xsel" then
    cmd = { "xsel", "-o", "-b" }
  else
    cmd = { "xclip", "-o", "-selection", "clipboard" }
  end

  local ok, proc = pcall(vim.system, cmd, { timeout = X11_PROBE_MS, text = true })
  if not ok then
    return false
  end
  local result = proc:wait()
  -- Non-zero can mean "empty clipboard"; timeout / missing X is the failure.
  -- vim.system uses -1 / signal when killed by timeout.
  if result.signal and result.signal ~= 0 then
    return false
  end
  if result.code == -1 then
    return false
  end
  return true
end

local function native_spec()
  if vim.fn.has("mac") == 1
    and vim.fn.executable("pbcopy") == 1
    and vim.fn.executable("pbpaste") == 1
  then
    return provider_spec("pbcopy", { "pbcopy" }, { "pbpaste" })
  end

  if vim.env.WAYLAND_DISPLAY
    and vim.env.WAYLAND_DISPLAY ~= ""
    and vim.fn.executable("wl-copy") == 1
    and vim.fn.executable("wl-paste") == 1
  then
    return provider_spec(
      "wl-copy",
      { "wl-copy", "--type", "text/plain" },
      { "wl-paste", "--no-newline" }
    )
  end

  if probe_x11("xsel") then
    -- Builtin jobstart provider: xsel --nodetach is a long-lived owner process.
    return "xsel"
  end

  if probe_x11("xclip") then
    return "xclip"
  end

  if vim.fn.executable("win32yank.exe") == 1 then
    return provider_spec(
      "win32yank",
      { "win32yank.exe", "-i", "--crlf" },
      { "win32yank.exe", "-o", "--lf" }
    )
  end

  return nil
end

local last_osc52 = { { "" }, "v" }

local function osc52_copy(lines, regtype)
  local n = byte_len(lines)
  if n > MAX_OSC52_BYTES then
    warn_once(
      "osc52-size",
      string.format("Clipboard: yank is %d bytes; skip OSC 52 (limit %d)", n, MAX_OSC52_BYTES)
    )
    return
  end
  if #vim.api.nvim_list_uis() == 0 then
    return
  end

  last_osc52 = { lines, regtype or "v" }

  local ok_osc, osc52 = pcall(require, "vim.ui.clipboard.osc52")
  if not ok_osc then
    return
  end
  local ok, err = pcall(osc52.copy("+"), lines)
  if not ok then
    warn_once("osc52-copy", "OSC 52 copy failed: " .. tostring(err))
  end
end

local function osc52_paste()
  -- Never call osc52.paste(): it waits up to 10s and many terminals block it.
  return last_osc52[1]
end

local function apply_spec(spec)
  vim.g.clipboard = spec
  if vim.g.loaded_clipboard_provider then
    vim.g.loaded_clipboard_provider = nil
    pcall(vim.cmd, "runtime autoload/provider/clipboard.vim")
  end
end

local configured = false

local function setup_osc52()
  apply_spec({
    name = "OSC 52 copy",
    copy = { ["+"] = osc52_copy, ["*"] = osc52_copy },
    paste = { ["+"] = osc52_paste, ["*"] = osc52_paste },
    cache_enabled = true,
  })
  -- No unnamedplus: deletes must not hit the terminal, and `p` must not wait
  -- on a paste provider. Regular `y` is forwarded below.
  vim.opt.clipboard = ""

  vim.api.nvim_create_autocmd("TextYankPost", {
    group = vim.api.nvim_create_augroup("UserClipboardOsc52", { clear = true }),
    callback = function()
      local ev = vim.v.event
      if ev.operator ~= "y" then
        return
      end
      -- Named registers (including "+ / "*) are handled by the provider.
      if ev.regname ~= "" then
        return
      end
      local lines = vim.deepcopy(ev.regcontents)
      local regtype = ev.regtype
      vim.schedule(function()
        osc52_copy(lines, regtype)
      end)
    end,
  })
end

local function setup_native(spec)
  apply_spec(spec)
  vim.opt.clipboard = "unnamedplus"
end

local function setup()
  if configured then
    return
  end

  if vim.g.vscode then
    configured = true
    vim.g.clipboard = nil
    vim.opt.clipboard = ""
    return
  end

  -- Over SSH the remote pbcopy/xclip/wl-copy is the wrong machine; OSC 52
  -- sends yank to the local terminal instead.
  if is_ssh() then
    if #vim.api.nvim_list_uis() == 0 then
      return
    end
    configured = true
    setup_osc52()
    return
  end

  local spec = native_spec()
  if spec then
    configured = true
    setup_native(spec)
    return
  end

  -- No native tool: copy-only OSC 52 once a UI exists.
  if #vim.api.nvim_list_uis() == 0 then
    return
  end

  configured = true
  setup_osc52()
end

local function safe_setup()
  local ok, err = pcall(setup)
  if not ok then
    vim.opt.clipboard = ""
    vim.notify("Clipboard setup failed: " .. tostring(err), vim.log.levels.WARN)
  end
end

local function block_builtin_until_ready()
  -- Neovim's builtin detector prefers pbcopy/xclip even over SSH. Pin a
  -- no-op so a yank before UIEnter cannot talk to the remote clipboard.
  vim.opt.clipboard = ""
  vim.g.clipboard = {
    name = "pending",
    copy = {
      ["+"] = function() end,
      ["*"] = function() end,
    },
    paste = {
      ["+"] = function()
        return { "" }
      end,
      ["*"] = function()
        return { "" }
      end,
    },
    cache_enabled = true,
  }
end

if is_ssh() then
  block_builtin_until_ready()
end

vim.api.nvim_create_autocmd("UIEnter", {
  group = vim.api.nvim_create_augroup("UserClipboardSetup", { clear = true }),
  once = true,
  callback = safe_setup,
})
safe_setup()
