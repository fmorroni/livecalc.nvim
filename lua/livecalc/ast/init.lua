---@alias AstConversionFun<T> fun(bufnr: integer, node: TSNode): T

local M = {}

local h = require("livecalc.ast.helpers")
local u = require("livecalc.ast.units")

--------------------------------------------------------------------------------
-- AST Builder
--------------------------------------------------------------------------------

local ast_conversion
ast_conversion = {
	---@type AstConversionFun<NumberNode>
	number = function(bufnr, node)
		---@type NumberNode
		return {
			type = "number",
			value = h.assert_number(h.text(bufnr, node)),
			range = h.range(node),
		}
	end,

	---@type AstConversionFun<IdentifierNode>
	identifier = function(bufnr, node)
		---@type IdentifierNode
		return {
			type = "identifier",
			name = h.text(bufnr, node),
			range = h.range(node),
		}
	end,

	---@type AstConversionFun<AstNode>
	parenthesized_expression = function(bufnr, node)
		---@type AstNode
		return M.build(bufnr, h.assert_named_child(node, 0))
	end,

	---@type AstConversionFun<UnaryNode>
	unary_expression = function(bufnr, node)
		---@type UnaryNode
		return {
			type = "unary",
			op = h.text(bufnr, h.assert_field(node, "operator")),
			expr = M.build(bufnr, h.assert_field(node, "expr")),
			range = h.range(node),
		}
	end,

	---@type AstConversionFun<BinaryNode>
	binary_expression = function(bufnr, node)
		local left = h.assert_field(node, "left")
		local right = h.assert_field(node, "right")

		---@type BinaryNode
		return {
			type = "binary",
			op = h.text(bufnr, h.assert_field(node, "operator")),
			left = M.build(bufnr, left),
			right = M.build(bufnr, right),
			range = h.range(node),
		}
	end,

	---@type AstConversionFun<AssignmentNode>
	assignment = function(bufnr, node)
		---@type AssignmentNode
		return {
			type = "assignment",
			identifier = h.text(bufnr, h.assert_field(node, "left")),
			value = M.build(bufnr, h.assert_field(node, "right")),
			range = h.range(node),
		}
	end,

	---@type AstConversionFun<UnitAttachNode|ErrorNode>
	expression_with_units = function(bufnr, node)
		local units = u.normalize(bufnr, h.assert_named_child(h.assert_field(node, "units"), 0))
		if units.type == "error" then
			return units
		end

		---@type UnitAttachNode
		return {
			type = "unit_attach",
			expr = M.build(bufnr, h.assert_field(node, "expr")),
			units = units.value,
			range = h.range(node),
		}
	end,

	---@type AstConversionFun<FunctionCallNode|BuiltinCallNode>
	function_call = function(bufnr, node)
		local name = h.assert_field(node, "name")

		---@type AstNode[]
		local args = {}
		---@type TSNode?
		local args_node = node:field("args")[1]
		if args_node then
			for _, child in ipairs(args_node:named_children()) do
				table.insert(args, M.build(bufnr, child))
			end
		end

		if name:type() == "builtin" then
			---@type BuiltinCallNode
			return {
				type = "builtin_call",
				identifier = ast_conversion.identifier(bufnr, h.assert_named_child(name, 0)),
				args = args,
				range = h.range(node),
			}
		else
			---@type FunctionCallNode
			return {
				type = "function_call",
				identifier = ast_conversion.identifier(bufnr, name),
				args = args,
				range = h.range(node),
			}
		end
	end,

	---@type AstConversionFun<BuiltinConstant>
	builtin = function(bufnr, node)
		---@type BuiltinConstant
		return {
			type = "builtin_constant",
			identifier = ast_conversion.identifier(bufnr, h.assert_named_child(node, 0)),
			range = h.range(node),
		}
	end,
}

---@param bufnr integer
---@param node TSNode
function M.build(bufnr, node)
	-- TODO: better error managment. If I have for example a binary expr with an error in `left` and an error in
	-- `right` this method will return a single error node with the first error it encounters instead of a binary
	-- node with an error in each child.
	local err = h.find_error(node)
	if err then
		local msg
		if err:missing() then
			msg = string.format("missing `%s`", err:type())
		else
			msg = string.format("syntax error near `%s`", vim.treesitter.get_node_text(err, bufnr))
		end

		---@type ErrorNode
		return {
			type = "error",
			msg = msg,
			range = h.range(err),
		}
	end

	local type = node:type()
	local conversion_fun = ast_conversion[type]
	-- assert(conversion_fun ~= nil, "No conversion function found for type: " .. type)
	-- TODO: this is more useful during development but I don't think it's the
	-- best in production, probably use the assert then.
	if conversion_fun == nil then
		return {
			type = "error",
			msg = "no conversion function found for type: " .. type,
			range = h.range(node),
		}
	end

	return conversion_fun(bufnr, node)
end

return M
