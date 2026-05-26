---@alias NormalizationFun fun(bufnr: integer, node: TSNode): Units

---@class UnitNode
---@field type "units"
---@field value Units

local M = {}

local h = require("livecalc.ast.helpers")
local u = require("livecalc.units_helper")

local times_operations = {
	---@type fun(left: Units, right: Units): Units
	["*"] = function(left, right)
		return u.units_times(left, right, 1)
	end,
	---@type fun(left: Units, right: Units): Units
	["/"] = function(left, right)
		return u.units_times(left, right, -1)
	end,
}

---@type table<string, NormalizationFun>
local unit_normalize = {
	identifier = function(bufnr, node)
		local unit = h.text(bufnr, node)
		---@type Units
		return {
			[unit] = 1,
		}
	end,

	unit_times_expression = function(bufnr, node)
		local left = M.normalize(bufnr, h.assert_field(node, "left"))
		if left.type == "error" then
			return left
		end

		local right = M.normalize(bufnr, h.assert_field(node, "right"))
		if right.type == "error" then
			return right
		end

		local operator = h.text(bufnr, h.assert_field(node, "operator"))
		local op = times_operations[operator]

		return op(left.value, right.value)
	end,

	unit_inverse = function(bufnr, node)
		local denominator = M.normalize(bufnr, h.assert_field(node, "denominator"))
		if denominator.type == "error" then
			return denominator
		end

		---@type Units
		local res = {}
		for unit, exp in pairs(denominator.value) do
			res[unit] = -exp
		end

		return res
	end,

	unit_pow_expression = function(bufnr, node)
		local base = M.normalize(bufnr, h.assert_field(node, "base"))
		if base.type == "error" then
			return base
		end

		local exponent_str = h.text(bufnr, h.assert_field(node, "exponent"))
		local exponent = tonumber(exponent_str)
		assert(exponent ~= nil, "Failed to parse exponent: " .. exponent_str)

		return u.units_exp(base.value, exponent)
	end,

	unit_parenthesized_expression = function(bufnr, node)
		local expr = M.normalize(bufnr, h.assert_named_child(node, 0))
		if expr.type == "error" then
			return expr
		end
    return expr.value
	end,
}

---@param bufnr integer
---@param node TSNode
function M.normalize(bufnr, node)
	local err = h.find_error(node)

	if err then
		local msg
		if err:missing() then
			msg = string.format("Missing `%s`", err:type())
		else
			msg = string.format("Syntax error near `%s`", vim.treesitter.get_node_text(err, bufnr))
		end

		---@type ErrorNode
		return {
			type = "error",
			msg = msg,
			range = h.range(node),
		}
	end

	local type = node:type()
	local norm_fun = unit_normalize[type]
	-- assert(conversion_fun ~= nil, "No conversion function found for type: " .. type)
	-- TODO: this is more useful during development but I don't think it's the
	-- best in production, probably use the assert then.
	if norm_fun == nil then
		return {
			type = "error",
			msg = "No conversion function found for type: " .. type,
			range = h.range(node),
		}
	end

	---@type UnitNode
	return {
		type = "units",
		value = norm_fun(bufnr, node),
	}
end

return M
