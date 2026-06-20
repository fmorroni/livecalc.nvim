---@alias ParamTypeParseFun<T> fun(bufnr: integer, type_node: TSNode): T

local M = {}

local h = require("livecalc.ast.helpers")
local u = require("livecalc.ast.units")

local param_type_parsing

param_type_parsing = {
	---@type ParamTypeParseFun<FunctionParamNumeric|ErrorNode>
	units = function(bufnr, type_node)
		local units_node = h.assert_named_child(type_node, 0)
		local units = u.normalize(bufnr, units_node)
		if units.type == "error" then
			return units
		end
		---@type FunctionParamNumeric
		return {
			type = "param_numeric",
			unit = units.value,
			range = h.range(units_node),
		}
	end,
	---@type ParamTypeParseFun<FunctionParamBoolean>
	boolean_type = function(_, type_node)
		---@type FunctionParamBoolean
		return {
			type = "param_boolean",
			range = h.range(type_node),
		}
	end,
	---@type ParamTypeParseFun<FunctionParamFunction|ErrorNode>
	function_type = function(bufnr, type_node)
		---@type FunctionParamType[]
		local params = {}

		local param_types_node = type_node:field("param_types")[1]
		if param_types_node then
			for _, param_node in ipairs(param_types_node:named_children()) do
				local param_func = param_type_parsing[param_node:type()]
				if not param_func then
					---@type ErrorNode
					return {
						type = "error",
						msg = ("unkown type `%s`"):format(param_node:type()),
						range = h.range(type_node),
					}
				end
				local param = param_func(bufnr, param_node)
				if param.type == "error" then
					return param
				end
				table.insert(params, param)
			end
		end

		local return_type_node = h.assert_field(type_node, "return_type")
		local return_type = param_type_parsing[return_type_node:type()](bufnr, return_type_node)
		if return_type.type == "error" then
			return return_type
		end

		---@type FunctionParamFunction
		return {
			type = "param_function",
			params = params,
			return_type = return_type,
			range = h.range(type_node),
		}
	end,
	---@type ParamTypeParseFun<FunctionParamAny>
	any_type = function(_, type_node)
		---@type FunctionParamAny
		return {
			type = "param_any",
			range = h.range(type_node),
		}
	end,
}

---@type AstConversionFun<FunctionParamNode|ErrorNode>
function M.parameter(bufnr, node)
	local type_node = node:field("type")[1]

	---@type FunctionParamType
	local param_type
	if not type_node then
		param_type = param_type_parsing.any_type(bufnr, node)
	else
		local type = param_type_parsing[type_node:type()](bufnr, type_node)
		if type.type == "error" then
			return type
		end
		param_type = type
	end

	return {
		type = "function_parameter",
		name = h.text(bufnr, h.assert_field(node, "name")),
		param_type = param_type,
		range = h.range(node),
	}
end

return M
