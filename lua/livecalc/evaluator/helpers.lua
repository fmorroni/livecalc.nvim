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

---@param value RuntimeValue
function M.result_success(value)
	---@type ResultSuccess
	return {
		type = "success",
		value = value,
	}
end

---@param value number
---@param units Units
function M.runtime_number(value, units)
	---@type RuntimeNumber
	return {
		type = "number",
		value = value,
		units = units,
	}
end

---@param node FunctionNode
---@param env Env
function M.runtime_function(node, env)
	---@type RuntimeFunction
	return {
		type = "function",
		params = node.params,
		body = node.body,
		return_units = {},
		closure = vim.tbl_extend("keep", {}, env),
	}
end

---@param node AstNode
---@param actual_type string
function M.expected_numeric(node, actual_type)
	return M.result_error({
		M.eval_error(node, ("expected numeric value, found `%s`"):format(actual_type)),
	})
end

return M
