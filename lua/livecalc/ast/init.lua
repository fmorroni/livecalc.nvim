---@alias AstConversionFun<T> fun(bufnr: integer, node: TSNode): T

local M = {}

local h = require("livecalc.ast.helpers")
local u = require("livecalc.ast.units")
local p = require("livecalc.ast.params")

--------------------------------------------------------------------------------
-- AST Builder
--------------------------------------------------------------------------------

local ast_conversion

local ast_conversion_extra = {
	---@type fun(bufnr: integer, node: TSNode, type: BinaryNodeType): BinaryNode
	binary_expression = function(bufnr, node, type)
		local left = h.assert_field(node, "left")
		local right = h.assert_field(node, "right")

		---@type BinaryNode
		return {
			type = type,
			op = h.text(bufnr, h.assert_field(node, "operator")),
			left = M.build(bufnr, left),
			right = M.build(bufnr, right),
			range = h.range(node),
		}
	end,
}

ast_conversion = {
	---@type AstConversionFun<AstNode>
	statement = function(bufnr, node)
		return M.build(bufnr, h.assert_named_child(node, 0))
	end,

	---@type AstConversionFun<NumberNode>
	number = function(bufnr, node)
		---@type NumberNode
		return {
			type = "number",
			value = h.assert_number(h.text(bufnr, node)),
			range = h.range(node),
		}
	end,

	---@type AstConversionFun<BooleanNode>
	boolean = function(bufnr, node)
		local value_str = h.text(bufnr, node)
		---@type BooleanNode
		return {
			type = "boolean",
			value = value_str == "true",
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
		local op = h.text(bufnr, h.assert_field(node, "operator"))
		---@type UnaryNode
		return {
			type = op == "!" and "unary_boolean" or "unary_numeric",
			op = op,
			expr = M.build(bufnr, h.assert_field(node, "expr")),
			range = h.range(node),
		}
	end,

	---@type AstConversionFun<BinaryNode>
	binary_numeric_expression = function(bufnr, node)
		return ast_conversion_extra.binary_expression(bufnr, node, "binary_numeric")
	end,

	---@type AstConversionFun<BinaryNode>
	binary_boolean_expression = function(bufnr, node)
		return ast_conversion_extra.binary_expression(bufnr, node, "binary_boolean")
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
		---@type Units
		local units = {}

		local asdf = h.assert_field(node, "units"):named_child(0)
		if asdf then
			local unit_node = u.normalize(bufnr, asdf)
			if unit_node.type == "error" then
				return unit_node
			end
			units = unit_node.value
		end

		---@type UnitAttachNode
		return {
			type = "unit_attach",
			expr = M.build(bufnr, h.assert_field(node, "expr")),
			units = units,
			range = h.range(node),
		}
	end,

	---@type AstConversionFun<IdentifierCallNode|BuiltinCallNode|InlineFunctionCallNode|ErrorNode>
	function_call = function(bufnr, node)
		local callee = h.assert_field(node, "callee")

		---@type AstNode[]
		local args = {}
		---@type TSNode?
		local args_node = node:field("args")[1]
		if args_node then
			for _, child in ipairs(args_node:named_children()) do
				table.insert(args, M.build(bufnr, child))
			end
		end

    -- FIXME: I need to handle the generic case of `<expression>(<params>)` since any
    -- expression could evaluate to a function.
		if callee:type() == "builtin" then
			---@type BuiltinCallNode
			return {
				type = "builtin_call",
				identifier = ast_conversion.identifier(bufnr, h.assert_named_child(callee, 0)),
				args = args,
				range = h.range(node),
			}
		elseif callee:type() == "identifier" then
			---@type IdentifierCallNode
			return {
				type = "identifier_call",
				identifier = ast_conversion.identifier(bufnr, callee),
				args = args,
				range = h.range(node),
			}
		elseif callee:type() == "parenthesized_expression" then
			---@param node2 TSNode
			local function find_function_node(node2)
				---@type TSNode?
				local child = h.assert_named_child(node2, 0)
				if not child then
					return nil
				end
				if child:type() == "parenthesized_expression" then
					child = find_function_node(child)
				elseif child:type() == "function" then
					return child
				end
				return nil
			end

			local callee_rec = find_function_node(callee)
			if not callee_rec then
				---@type ErrorNode
				return {
					type = "error",
					msg = "expression is not a function",
					range = h.range(callee),
				}
			end
			local function_node = ast_conversion["function"](bufnr, callee_rec)
			if function_node.type == "error" then
				return function_node
			end

			---@type InlineFunctionCallNode
			return {
				type = "inline_function_call",
				fn = function_node,
				args = args,
				range = h.range(node),
			}
		end

		---@type ErrorNode
		return {
			type = "error",
			msg = "expression is not a function",
			range = h.range(callee),
		}
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

	---@type AstConversionFun<FunctionNode|ErrorNode>
	["function"] = function(bufnr, node)
		---@type FunctionParamNode[]
		local params = {}

		local params_node = node:field("params")[1]
		if params_node then
			for _, child in ipairs(params_node:named_children()) do
				local param = p.parameter(bufnr, child)
				if param.type == "error" then
					return param
				end
				table.insert(params, param)
			end
		end

		local body = M.build(bufnr, h.assert_field(node, "body"))

		---@type FunctionNode
		return {
			type = "function_def",
			params = params,
			body = body,
			range = h.range(node),
		}
	end,
}

---@param bufnr integer
---@param node TSNode
function M.build(bufnr, node)
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
