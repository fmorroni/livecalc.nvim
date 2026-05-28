local M = {}

---@param bufnr integer
---@param node TSNode
function M.text(bufnr, node)
	return vim.treesitter.get_node_text(node, bufnr)
end

---@param node TSNode
---@param field string
function M.assert_field(node, field)
	local field_node = node:field(field)
	assert(#field_node > 0, "Unexpected parsing error. Field not found.")
	return field_node[1]
end

---@param node TSNode
---@param idx integer
function M.assert_named_child(node, idx)
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
function M.assert_number(number_str)
	local number = tonumber(number_str)
	assert(number, "Unexpected number: " .. number_str)
	return number
end

---@param node TSNode
---@return TSNode?
function M.find_error(node)
	if not node:has_error() then
		return nil
	end

	if node:type() == "ERROR" or node:missing() then
		return node
	end

	for child in node:iter_children() do
		local err = M.find_error(child)

		if err then
			return err
		end
	end
end

---@param node TSNode
function M.range(node)
	local start_row, start_col, end_row, end_col = node:range()

	---@type NodeRange
	return {
		start_row = start_row,
		end_row = end_row,
		start_col = start_col,
		end_col = end_col,
	}
end

return M
