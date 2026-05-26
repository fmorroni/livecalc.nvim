local M = {}

local parser = require("livecalc.parser")
local evaluator = require("livecalc.evaluator")
local renderer = require("livecalc.render")

--------------------------------------------------------------------------------
-- Main update pipeline
--------------------------------------------------------------------------------

---@param bufnr? integer
function M.update(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	local ast_lines = parser.parse_document(bufnr)
	if not ast_lines then
		-- TODO: better error handling
		return
	end

	local state = evaluator.evaluate_document(ast_lines)

	renderer.render(bufnr, state)
end

--------------------------------------------------------------------------------
-- Setup
--------------------------------------------------------------------------------

---@param opts? table
function M.setup(opts)
	opts = opts or {}

	local group = vim.api.nvim_create_augroup("livecalc", { clear = true })

	vim.api.nvim_create_autocmd("FileType", {
		group = group,
		pattern = "livecalc",
		callback = function(ft_args)
			-- Trigger when opening new buffer. `BufReadPost` doesn't work here because we are already
      -- inside a `FileType` autocmd which triggers after the `BufReadPost` event.
			M.update(ft_args.buf)

			vim.api.nvim_create_autocmd({
				"VimEnter",
				"TextChanged",
				"InsertLeave",
			}, {
				group = group,
				buffer = ft_args.buf,
				callback = function(args)
					M.update(args.buf)
				end,
			})
		end,
	})
end

return M
