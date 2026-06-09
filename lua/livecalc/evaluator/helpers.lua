local u = require("livecalc.units_helper")
local unit_render = require("livecalc.render.units")

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
---@return RuntimeNumber|ResultError
function M.assert_integer(node, value)
	local error = M.expected_type(node, "number", value.type)
	if error then
		return error
	end
	local number = value --[[@as RuntimeNumber]]
	if number.value % 1 == 0 then
		return number
	end
	return M.result_error({ M.eval_error(node, ("expected an integer value, found `%s`"):format(number.value)) })
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

---@param node AstNode
---@param value RuntimeNumber
function M.expected_unitless(node, value)
	local units = value.units
	if not u.units_empty(units) then
		return M.result_error({
			M.eval_error(node, ("expected unitless value found `%s`"):format(unit_render.render_units(units))),
		})
	end
	return nil
end

return M
