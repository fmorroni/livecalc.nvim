local M = {}

local h = require("livecalc.evaluator.helpers")
local u = require("livecalc.units_helper")
local unit_render = require("livecalc.render.units")

M.unary_numeric = {
	---@type fun(value: number): number
	["-"] = function(value)
		return -value
	end,
	---@type fun(value: number): number
	["+"] = function(value)
		return value
	end,
}

M.unary_boolean = {
	---@type fun(value: boolean): boolean
	["!"] = function(value)
		return not value
	end,
}

---@type fun(left: RuntimeNumber, right: RuntimeNumber, node: BinaryNode, op: "+" | "-"): Result
local function addition_subraction(left, right, node, op)
	if not u.units_equal(left.units, right.units) then
		local left_units = unit_render.render_units(left.units)
		local right_units = unit_render.render_units(right.units)
		local units = ("[%s] %s [%s]"):format(left_units, op, right_units)
		return h.result_error({
			h.eval_error(node, "left and right expressions must have same units, found: " .. units),
		})
	end

	return h.result_success(
		h.runtime_number((op == "+") and left.value + right.value or left.value - right.value, left.units)
	)
end

---@alias BinaryNumericOp  fun(left: RuntimeNumber, right: RuntimeNumber, node: BinaryNode): Result
M.binary_numeric = {
	---@type BinaryNumericOp
	["-"] = function(left, right, node)
		return addition_subraction(left, right, node, "-")
	end,
	---@type BinaryNumericOp
	["+"] = function(left, right, node)
		return addition_subraction(left, right, node, "+")
	end,
	---@type BinaryNumericOp
	["*"] = function(left, right)
		return h.result_success(h.runtime_number(left.value * right.value, u.units_times(left.units, right.units, 1)))
	end,
	---@type BinaryNumericOp
	["/"] = function(left, right)
		return h.result_success(h.runtime_number(left.value / right.value, u.units_times(left.units, right.units, -1)))
	end,
	---@type BinaryNumericOp
	["**"] = function(left, right, node)
		if not u.units_empty(right.units) then
			local units = ("[%s]"):format(unit_render.render_units(right.units))
			return h.result_error({ h.eval_error(node.right, "exponent can't have units, found: " .. units) })
		end

		return h.result_success(h.runtime_number(left.value ^ right.value, u.units_exp(left.units, right.value)))
	end,
	---@type BinaryNumericOp
	["%"] = function(left, right, node)
		if not u.units_empty(right.units) then
			local units = ("[%s]"):format(unit_render.render_units(right.units))
			return h.result_error({ h.eval_error(node.right, "divisor can't have units, found: " .. units) })
		end

		return h.result_success(h.runtime_number(left.value % right.value, left.units))
	end,
}

---@alias BinaryBooleanOp fun(left: RuntimeValue, right: RuntimeValue, node: BinaryNode): Result
M.binary_boolean = {
	---@type BinaryBooleanOp
	["||"] = function(left_value, right_value, node)
		local left = h.assert_boolean(node.left, left_value)
		local right = h.assert_boolean(node.right, right_value)
		if left.type == "error" or right.type == "error" then
			return h.join_result_errors(left.errors, right.errors)
		end
		return h.result_success(h.runtime_boolean(left.value or right.value))
	end,
	---@type BinaryBooleanOp
	["&&"] = function(left_value, right_value, node)
		local left = h.assert_boolean(node.left, left_value)
		local right = h.assert_boolean(node.right, right_value)
		if left.type == "error" or right.type == "error" then
			return h.join_result_errors(left.errors, right.errors)
		end
		return h.result_success(h.runtime_boolean(left.value and right.value))
	end,
	---@type BinaryBooleanOp
	["=="] = function(left, right, node)
		local left_err = h.expected_types(node.left, { "number", "boolean" }, left.type)
		local right_err = h.expected_types(node.right, { "number", "boolean" }, right.type)
		if left_err or right_err then
			return h.join_result_errors(left_err and left_err.errors, right_err and right_err.errors)
		end
		---@cast left RuntimeNumber|RuntimeBoolean
		---@cast right RuntimeNumber|RuntimeBoolean
		return h.result_success(h.runtime_boolean(left.value == right.value))
	end,
	---@type BinaryBooleanOp
	["!="] = function(left, right, node)
		local left_err = h.expected_types(node.left, { "number", "boolean" }, left.type)
		local right_err = h.expected_types(node.right, { "number", "boolean" }, right.type)
		if left_err or right_err then
			return h.join_result_errors(left_err and left_err.errors, right_err and right_err.errors)
		end
		---@cast left RuntimeNumber|RuntimeBoolean
		---@cast right RuntimeNumber|RuntimeBoolean
		return h.result_success(h.runtime_boolean(left.value ~= right.value))
	end,
	---@type BinaryBooleanOp
	["<"] = function(left_value, right_value, node)
		local left = h.assert_number(node.left, left_value)
		local right = h.assert_number(node.right, right_value)
		if left.type == "error" or right.type == "error" then
			return h.join_result_errors(left.errors, right.errors)
		end
		return h.result_success(h.runtime_boolean(left.value < right.value))
	end,
	---@type BinaryBooleanOp
	["<="] = function(left_value, right_value, node)
		local left = h.assert_number(node.left, left_value)
		local right = h.assert_number(node.right, right_value)
		if left.type == "error" or right.type == "error" then
			return h.join_result_errors(left.errors, right.errors)
		end
		return h.result_success(h.runtime_boolean(left.value <= right.value))
	end,
	---@type BinaryBooleanOp
	[">"] = function(left_value, right_value, node)
		local left = h.assert_number(node.left, left_value)
		local right = h.assert_number(node.right, right_value)
		if left.type == "error" or right.type == "error" then
			return h.join_result_errors(left.errors, right.errors)
		end
		return h.result_success(h.runtime_boolean(left.value > right.value))
	end,
	---@type BinaryBooleanOp
	[">="] = function(left_value, right_value, node)
		local left = h.assert_number(node.left, left_value)
		local right = h.assert_number(node.right, right_value)
		if left.type == "error" or right.type == "error" then
			return h.join_result_errors(left.errors, right.errors)
		end
		return h.result_success(h.runtime_boolean(left.value >= right.value))
	end,
}

return M
