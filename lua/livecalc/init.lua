local M = {}

local ns = vim.api.nvim_create_namespace("livecalc")

---@param opts? table
function M.setup(opts)
	vim.api.nvim_create_autocmd({
		"VimEnter",
		"BufReadPost",
		"TextChanged",
		"InsertLeave",
	}, {
		pattern = "*.lc",
		callback = function(args)
			M.update(args.buf)
		end,
	})
end

---@param buf? integer
function M.update(buf)
	buf = buf or vim.api.nvim_get_current_buf()

	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

	---@type LiveCalcEvaluator
	local evaluator = require("livecalc.evaluator")
	---@type LiveCalcTS
	local ts_mod = require("livecalc.ts")

	local env = evaluator.new_env()

	local nodes = ts_mod.get_assignments(buf)

	---@type vim.Diagnostic[]
	local diagnostics = {}

	for _, node in ipairs(nodes) do
		local ok, result = evaluator.eval_assignment(node, env)

		if ok then
			if result ~= nil then
				local text = "= " .. tostring(result)
				local hl = "@comment.info"

				vim.api.nvim_buf_set_extmark(buf, ns, node.line, -1, {
					virt_text = { { text, hl } },
					virt_text_pos = "eol",
				})
			end
		else
			table.insert(diagnostics, {
				lnum = node.line,
				col = 0,
				end_lnum = node.line,
				end_col = 0,
				severity = vim.diagnostic.severity.ERROR,
				message = tostring(result),
				source = "livecalc",
			})
		end
	end

	local errors = ts_mod.get_errors(buf)
	for _, err in ipairs(errors) do
		table.insert(diagnostics, {
			lnum = err.line,
			col = 0,
			end_lnum = err.line,
			end_col = 0,
			severity = vim.diagnostic.severity.ERROR,
			message = err.message,
			source = "livecalc",
		})
	end

	vim.diagnostic.set(ns, buf, diagnostics)
end

return M
