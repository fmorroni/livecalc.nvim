local M = {}

---@param node AstNode
---@param msg string
function M.eval_error(node, msg)
	---@type EvalError
	return {
		msg = msg,
		range = node.range,
	}
end

---@param errors EvalError[]
function M.result_error(errors)
	---@type ResultError
	return {
		type = "error",
		errors = errors,
	}
end

---@param left ResultError
---@param right ResultError
function M.join_result_errors(left, right)
	---@type ResultError
	return {
		type = "error",
		errors = vim.list_extend(left.errors, right.errors),
	}
end

---@param value number
---@param units Units
function M.result_success(value, units)
	---@type ResultSuccess
	return {
		type = "success",
		value = value,
		units = units,
	}
end

return M
