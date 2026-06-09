---@alias BuiltinFun fun(args: RuntimeValue[], node: BuiltinCallNode): Result

local h = require("livecalc.evaluator.helpers")
local constants = require("livecalc.evaluator.builtin_constants")
local u = require("livecalc.units_helper")
local unit_render = require("livecalc.render.units")
local utils = require("livecalc.utils")

---@param expected_min integer
---@param expected_max? integer
---@param actual integer
---@param node BuiltinCallNode
local function unexpected_arg_count(expected_min, expected_max, actual, node)
	local arguments_str = "arguments"
	local expected
	if expected_min == expected_max then
		expected = tostring(expected_min)
		if expected_min == 1 then
			arguments_str = "argument"
		end
	elseif expected_max ~= nil then
		expected = ("%d-%d"):format(expected_min, expected_max)
	else
		expected = ("at least %d"):format(expected_min)
		if expected_min == 1 then
			arguments_str = "argument"
		end
	end
	return h.result_error({
		h.eval_error(
			node,
			("builtin `@%s` expects %s %s, got %d"):format(node.identifier.name, expected, arguments_str, actual)
		),
	})
end

local M
M = {
	---@type BuiltinFun
	sin = function(args, node)
		if #args ~= 1 then
			return unexpected_arg_count(1, 1, #args, node)
		end
		local value = h.assert_number(node.args[1], args[1])
		if value.type == "error" then
			return value
		end
		local err = h.expected_unitless(node.args[1], value)
		if err then
			return err
		end
		return h.result_success(h.runtime_number(math.sin(value.value), value.units))
	end,

	---@type BuiltinFun
	cos = function(args, node)
		if #args ~= 1 then
			return unexpected_arg_count(1, 1, #args, node)
		end
		local value = h.assert_number(node.args[1], args[1])
		if value.type == "error" then
			return value
		end
		local err = h.expected_unitless(node.args[1], value)
		if err then
			return err
		end
		return h.result_success(h.runtime_number(math.cos(value.value), value.units))
	end,

	---@type BuiltinFun
	max = function(args, node)
		if #args == 0 then
			return unexpected_arg_count(1, nil, #args, node)
		end
		---@type number[]
		local arg_values = {}
		for i, arg in ipairs(args) do
			local value = h.assert_number(node.args[i], arg)
			if value.type == "error" then
				return value
			end
			if not u.units_equal(args[1].units, value.units) then
				return h.result_error({
					h.eval_error(
						node,
						("builtin `@%s` expects all arguments to have same units"):format(node.identifier.name)
					),
				})
			end
			table.insert(arg_values, value.value)
		end
		return h.result_success(h.runtime_number(math.max(unpack(arg_values)), args[1].units))
	end,

	---@type BuiltinFun
	log = function(args, node)
		if #args < 1 or #args > 2 then
			return unexpected_arg_count(1, 2, #args, node)
		end
		local x = h.assert_number(node.args[1], args[1])
		local base = args[2] and h.assert_number(node.args[2], args[2]) or h.result_success(h.runtime_number(10, {}))
		if x.type == "error" or base.type == "error" then
			return h.join_result_errors(x.errors, base.errors)
		end
		local error_x = h.expected_unitless(node.args[1], x)
		local error_base = h.expected_unitless(node.args[2], base)
		if error_x or error_base then
			return h.join_result_errors(error_x and error_x.errors, error_base and error_base.errors)
		end
		return h.result_success(h.runtime_number(math.log(x.value, base.value), {}))
	end,

	---@type BuiltinFun
	ln = function(args, node)
		if #args ~= 1 then
			return unexpected_arg_count(1, 1, #args, node)
		end
		local value = h.assert_number(node.args[1], args[1])
		if value.type == "error" then
			return value
		end
		return M.log({ value, h.runtime_number(constants.e, {}) }, node)
	end,

	---@type BuiltinFun
	unitless = function(args, node)
		if #args ~= 1 then
			return unexpected_arg_count(1, 1, #args, node)
		end
		local value = h.assert_number(node.args[1], args[1])
		if value.type == "error" then
			return value
		end
		return h.result_success(h.runtime_number(value.value, {}))
	end,

	---@type BuiltinFun
	abs = function(args, node)
		if #args ~= 1 then
			return unexpected_arg_count(1, 1, #args, node)
		end
		local value = h.assert_number(node.args[1], args[1])
		if value.type == "error" then
			return value
		end
		return h.result_success(h.runtime_number(math.abs(value.value), value.units))
	end,

	---@type BuiltinFun
	["if"] = function(args, node)
		if #args ~= 3 then
			return unexpected_arg_count(3, 3, #args, node)
		end
		local cond = h.assert_boolean(node.args[1], args[1])
		if cond.type == "error" then
			return cond
		end
		if cond.value then
			return h.result_success(args[2])
		else
			return h.result_success(args[3])
		end
	end,

	---@type BuiltinFun
	round = function(args, node)
		if #args ~= 2 then
			return unexpected_arg_count(2, 2, #args, node)
		end
		local value = h.assert_number(node.args[1], args[1])
		local digits = h.assert_integer(node.args[2], args[2])
		if value.type == "error" or digits.type == "error" then
			return h.join_result_errors(value.errors, digits.errors)
		end
		local err = h.expected_unitless(node.args[2], digits)
		if err then
			return err
		end
		return h.result_success(h.runtime_number(utils.round(value.value, digits.value), value.units))
	end,
}

return M
