local M = {}

local u = require("livecalc.render.units")

local ns = vim.api.nvim_create_namespace("livecalc")
local diag_ns = vim.api.nvim_create_namespace("livecalc_diagnostics")

---@param bufnr integer
---@param state EvalState
function M.render(bufnr, state)
	vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
	vim.diagnostic.reset(diag_ns, bufnr)

	---@type vim.Diagnostic[]
	local diagnostics = {}

	for _, line_result in ipairs(state.line_results) do
		local result = line_result.result

		if result.type == "error" then
			for _, err in ipairs(result.errors) do
				table.insert(diagnostics, {
					lnum = err.range.start_row,
					col = err.range.start_col,
					end_lnum = err.range.end_row,
					end_col = err.range.end_col,
					message = err.msg,
					severity = vim.diagnostic.severity.ERROR,
					source = "livecalc",
				})
			end
		else
			local text = "= " .. tostring(result.value)

			local units = u.render_units(result.units)

			if units ~= "" then
				text = text .. " [" .. units .. "]"
			end

			vim.api.nvim_buf_set_extmark(bufnr, ns, line_result.line - 1, 0, {
				virt_text = {
					{ text, "@comment.info" },
				},
				virt_text_pos = "eol",
			})
		end
	end

	vim.diagnostic.set(diag_ns, bufnr, diagnostics)
end

vim.diagnostic.config({
	virtual_text = {
		source = "if_many",
		prefix = "✗",
	},
	underline = true,
	signs = true,
	update_in_insert = true,
}, diag_ns)

return M
