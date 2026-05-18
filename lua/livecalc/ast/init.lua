-- Converts tree-sitter nodes into your own AST.

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
---@param idx integer
local function assert_named_child(node, idx)
	local named_child = node:named_child(idx)
	assert(named_child ~= nil, "Unexpected parsing error. Named child not found.")
	return named_child
end

---@param node TSNode
---@param idx integer
local function assert_child(node, idx)
	local child = node:child(idx)
	assert(child ~= nil, "Unexpected parsing error. Child not found.")
	return child
end

--------------------------------------------------------------------------------
-- AST Builder
--------------------------------------------------------------------------------

---@type table<AstNodeType, AstConversionFun>
local ast_conversion = {
	number = function(bufnr, node)
		return {
			type = "number",
			value = tonumber(text(bufnr, node)),
		}
	end,

	identifier = function(bufnr, node)
		return {
			type = "identifier",
			name = text(bufnr, node),
		}
	end,

	expression = function(bufnr, node)
		return M.build(bufnr, assert_named_child(node, 0))
	end,

	parenthesized_expression = function(bufnr, node)
		return M.build(bufnr, assert_named_child(node, 0))
	end,

	unary_expression = function(bufnr, node)
		return {
			type = "unary",
			op = text(bufnr, assert_child(node, 0)),
			expr = M.build(bufnr, assert_named_child(node, 0)),
		}
	end,

	binary_expression = function(bufnr, node)
		local left = assert_named_child(node, 0)
		local right = assert_named_child(node, 1)

		return {
			type = "binary",
			op = text(bufnr, assert_child(node, 1)),
			left = M.build(bufnr, left),
			right = M.build(bufnr, right),
		}
	end,

	assignment = function(bufnr, node)
		return {
			type = "assignment",
			name = text(bufnr, assert_child(node, 0)),
			value = M.build(bufnr, assert_named_child(node, 1)),
		}
	end,

	-- TODO: handle this properly. Add MISSING node handling too.
	error = function(bufnr, node)
		return {
			type = "assignment",
			name = text(bufnr, assert_child(node, 0)),
			value = M.build(bufnr, assert_named_child(node, 1)),
		}
	end,
}

---@param bufnr integer
---@param node TSNode
function M.build(bufnr, node)
	local type = node:type()

	local conversion_fun = ast_conversion[type]
	assert(conversion_fun ~= nil, "No conversion function found for type: " .. type)
	return conversion_fun(bufnr, node)
end

return M
