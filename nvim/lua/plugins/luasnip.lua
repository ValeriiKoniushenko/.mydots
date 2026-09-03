local ok = pcall(require, "luasnip")
if not ok then
  return
end

-- Community snippets (friendly-snippets). Expansion/jumps are handled by
-- cmp.lua Tab / S-Tab when nvim-cmp is installed; otherwise insert Tab is default.
pcall(function()
  require("luasnip.loaders.from_vscode").lazy_load()
end)
