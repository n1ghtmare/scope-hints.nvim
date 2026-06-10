-- scope-hints.nvim
-- "Code biscuits": grayed-out virtual text on a scope's closing line, echoing
-- the line that opened it (the `}`/`end`/dedent). Driven entirely by treesitter
-- fold queries, so it's language-agnostic and self-enabling: any buffer that
-- treesitter can parse (and that ships a fold query) just works.
local M = {}
local ns = vim.api.nvim_create_namespace("scope_hints")

local cfg = {
	mode = "always", -- "always": every visible scope. "cursor": only the scope the cursor is in.
	min_lines = 15, -- only annotate scopes at least this tall
	max_len = 80, -- ellipsize hints longer than this
	hl = "Comment", -- subtle gray
	debounce = 120,
}

local function refresh(buf)
	if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].buftype ~= "" then
		return
	end

	local ok, parser = pcall(vim.treesitter.get_parser, buf)
	if not ok or not parser then
		return
	end -- treesitter not active for this buffer

	local query = vim.treesitter.query.get(parser:lang(), "folds")
	if not query then
		return
	end -- this language ships no fold query

	local top, bot = vim.fn.line("w0") - 1, vim.fn.line("w$")
	local root = parser:parse()[1]:root()
	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

	local cursor_row = cfg.mode == "cursor" and (vim.api.nvim_win_get_cursor(0)[1] - 1) or nil

	-- best: closing-row -> opening-row. Per closing line we keep the innermost
	-- scope (largest start row) so the hint matches the scope closest to it.
	local best = {}
	if cursor_row then
		-- Cursor mode: only the innermost scope whose range contains the cursor's line.
		local inner_srow, inner_erow
		for id, node in query:iter_captures(root, buf, top, bot) do
			if query.captures[id] == "fold" then
				local srow, _, erow = node:range()
				if
					srow <= cursor_row
					and cursor_row <= erow
					and erow >= top
					and erow < bot
					and erow - srow >= cfg.min_lines
				then
					if not inner_srow or srow > inner_srow then
						inner_srow, inner_erow = srow, erow
					end
				end
			end
		end
		if inner_srow then
			best[inner_erow] = inner_srow
		end
	else
		for id, node in query:iter_captures(root, buf, top, bot) do
			if query.captures[id] == "fold" then
				local srow, _, erow = node:range()
				if erow >= top and erow < bot and erow - srow >= cfg.min_lines then
					if not best[erow] or srow > best[erow] then
						best[erow] = srow
					end
				end
			end
		end
	end

	for erow, srow in pairs(best) do
		local open = vim.api.nvim_buf_get_lines(buf, srow, srow + 1, false)[1]
		local text = open and vim.trim(open) or ""
		if vim.fn.strchars(text) > cfg.max_len then
			text = vim.fn.strcharpart(text, 0, cfg.max_len) .. "…"
		end
		if text ~= "" then
			vim.api.nvim_buf_set_extmark(buf, ns, erow, -1, {
				virt_text = { { "  " .. text, cfg.hl } },
				virt_text_pos = "eol",
				hl_mode = "combine",
			})
		end
	end
end

function M.setup(opts)
	cfg = vim.tbl_deep_extend("force", cfg, opts or {})

	local events = { "BufWinEnter", "WinScrolled", "TextChanged", "TextChangedI", "InsertLeave", "CursorHold" }
	if cfg.mode == "cursor" then
		vim.list_extend(events, { "CursorMoved", "CursorMovedI" })
	end

	local timer = (vim.uv or vim.loop).new_timer()
	vim.api.nvim_create_autocmd(events, {
		group = vim.api.nvim_create_augroup("ScopeHints", { clear = true }),
		callback = function()
			timer:stop()
			timer:start(
				cfg.debounce,
				0,
				vim.schedule_wrap(function()
					refresh(vim.api.nvim_get_current_buf())
				end)
			)
		end,
	})

	-- Lazy loads us on an event, so the current buffer may be unannotated. Do
	-- one immediate refresh to catch it.
	vim.schedule(function()
		refresh(vim.api.nvim_get_current_buf())
	end)
end

return M
