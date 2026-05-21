-- lua/livecalc/ast/init.lua

local M = {}

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

---@param bufnr integer
---@param node TSNode
local function text(bufnr, node)
	return vim.treesitter.get_node_text(node, bufnr)
end

---@param node TSNode
---@param field string
local function assert_field(node, field)
	local field_node = node:field(field)
	assert(#field_node > 0, "Unexpected parsing error. Named child not found.")
	return field_node[1]
end

---@param node TSNode
---@param idx integer
local function assert_named_child(node, idx)
	local named_child = node:named_child(idx)
	assert(named_child ~= nil, "Unexpected parsing error. Named child not found.")
	return named_child
end

-- ---@param node TSNode
-- ---@param idx integer
-- local function assert_child(node, idx)
-- 	local child = node:child(idx)
-- 	assert(child ~= nil, "Unexpected parsing error. Child not found.")
-- 	return child
-- end

---@param number_str string
local function assert_number(number_str)
	local number = tonumber(number_str)
	assert(number, "Unexpected number: " .. number_str)
	return number
end

---@param node TSNode
---@return TSNode?
local function find_error(node)
	if not node:has_error() then
		return nil
	end

	if node:type() == "ERROR" or node:missing() then
		return node
	end

	for child in node:iter_children() do
		local err = find_error(child)

		if err then
			return err
		end
	end
end

---@param node TSNode
local function range(node)
	local start_row, start_col, end_row, end_col = node:range()

	---@type NodeRange
	return {
		start_row = start_row,
		end_row = end_row,
		start_col = start_col,
		end_col = end_col,
	}
end
--------------------------------------------------------------------------------
-- AST Builder
--------------------------------------------------------------------------------

---@type table<string, AstConversionFun>
local ast_conversion = {
	number = function(bufnr, node)
		---@type NumberNode
		return {
			type = "number",
			value = assert_number(text(bufnr, node)),
			range = range(node),
		}
	end,

	identifier = function(bufnr, node)
		---@type IdentifierNode
		return {
			type = "identifier",
			name = text(bufnr, node),
			range = range(node),
		}
	end,

	parenthesized_expression = function(bufnr, node)
		---@type AstNode
		return M.build(bufnr, assert_named_child(node, 0))
	end,

	unary_expression = function(bufnr, node)
		---@type UnaryNode
		return {
			type = "unary",
			op = text(bufnr, assert_field(node, "operator")),
			expr = M.build(bufnr, assert_field(node, "argument")),
			range = range(node),
		}
	end,

	binary_expression = function(bufnr, node)
		local left = assert_field(node, "left")
		local right = assert_field(node, "right")

		---@type BinaryNode
		return {
			type = "binary",
			op = text(bufnr, assert_field(node, "operator")),
			left = M.build(bufnr, left),
			right = M.build(bufnr, right),
			range = range(node),
		}
	end,

	assignment = function(bufnr, node)
		---@type AssignmentNode
		return {
			type = "assignment",
			identifier = text(bufnr, assert_field(node, "left")),
			value = M.build(bufnr, assert_field(node, "right")),
			range = range(node),
		}
	end,
}

---@param bufnr integer
---@param node TSNode
function M.build(bufnr, node)
	local err = find_error(node)

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
			range = range(node),
		}
	end

	local type = node:type()
	local conversion_fun = ast_conversion[type]
	assert(conversion_fun ~= nil, "No conversion function found for type: " .. type)
	return conversion_fun(bufnr, node)
end

return M
