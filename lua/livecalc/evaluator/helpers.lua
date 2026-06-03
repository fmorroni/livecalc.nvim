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

---@param errors_left EvalError[]?
---@param errors_right EvalError[]?
function M.join_result_errors(errors_left, errors_right)
	---@type ResultError
	return {
		type = "error",
		errors = vim.list_extend(errors_left or {}, errors_right or {}),
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

---@param value boolean
function M.runtime_boolean(value)
	---@type RuntimeBoolean
	return {
		type = "boolean",
		value = value,
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
---@param expected_type RuntimeType
---@param actual_type RuntimeType
function M.expected_type(node, expected_type, actual_type)
	if expected_type ~= actual_type then
		return M.result_error({
			M.eval_error(node, ("expected `%s` found `%s`"):format(expected_type, actual_type)),
		})
	end
	return nil
end

---@param node AstNode
---@param expected_type RuntimeType[]
---@param actual_type RuntimeType
function M.expected_types(node, expected_type, actual_type)
	if not vim.tbl_contains(expected_type, actual_type) then
		return M.result_error({
			M.eval_error(node, ("expected `%s` found `%s`"):format(table.concat(expected_type, " or "), actual_type)),
		})
	end

	return nil
end

---@param node AstNode
---@param value RuntimeValue
---@return RuntimeNumber|ResultError
function M.assert_number(node, value)
	local error = M.expected_type(node, "number", value.type)
	if error then
		return error
	end
	return value --[[@as RuntimeNumber]]
end

---@param node AstNode
---@param value RuntimeValue
---@return RuntimeBoolean|ResultError
function M.assert_boolean(node, value)
	local error = M.expected_type(node, "boolean", value.type)
	if error then
		return error
	end
	return value --[[@as RuntimeBoolean]]
end

------@param left RuntimeValue
------@param right RuntimeValue
------@param node BinaryNode
------@return boolean error
------@return ResultError|{left: RuntimeNumber, right: RuntimeNumber}
---function M.validate_numbers(left, right, node)
---	local left_val = M.assert_numeric(node.left, left)
---	local right_val = M.assert_numeric(node.right, right)
---
---	if left_val.type == "error" or right_val.type == "error" then
---		return true, M.join_result_errors(left_val.errors, right_val.errors)
---	end
---
---	return false, { left = left_val, right = right_val }
---end

return M
