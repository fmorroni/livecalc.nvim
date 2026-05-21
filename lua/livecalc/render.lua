-- lua/livecalc/render.lua

local M = {}

local ns = vim.api.nvim_create_namespace("livecalc")

--------------------------------------------------------------------------------
-- Render virtual text
--------------------------------------------------------------------------------

---@param bufnr integer
---@param state EvalState
function M.render(bufnr, state)
	vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

	for line, result in pairs(state.line_results) do
		if result.type == "error" then
			for _, err in ipairs(result.errors) do
				local text = "✗ " .. err.msg

				vim.api.nvim_buf_set_extmark(bufnr, ns, line - 1, 0, {
					virt_text = {
						{ text, "Error" },
					},
					virt_text_pos = "eol",
				})

				vim.api.nvim_buf_set_extmark(bufnr, ns, err.range.start_row, err.range.start_col, {
					end_row = err.range.end_row,
					end_col = err.range.end_col,
					hl_group = "DiagnosticUnderlineError",
				})
			end
		else
			local text = "= " .. tostring(result.value)

			vim.api.nvim_buf_set_extmark(bufnr, ns, line - 1, 0, {
				virt_text = {
					{ text, "@comment.info" },
				},
				virt_text_pos = "eol",
			})
		end
	end
end

return M
