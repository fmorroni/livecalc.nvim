-- lua/livecalc/render.lua

local M = {}

local ns = vim.api.nvim_create_namespace("livecalc")

--------------------------------------------------------------------------------
-- Render virtual text
--------------------------------------------------------------------------------

---@param bufnr integer
---@param state table
function M.render(bufnr, state)
	vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

	for line, result in pairs(state.line_results) do
		local text

		if type(result) == "table" and result.error then
			text = " ✗ " .. result.error
		else
			text = " = " .. tostring(result)
		end

		vim.api.nvim_buf_set_extmark(bufnr, ns, line - 1, 0, {
			virt_text = {
				{ text, "@comment.info" },
			},
			virt_text_pos = "eol",
		})
	end
end

return M
