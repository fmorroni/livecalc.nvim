---@class LiveCalcTS
---@field get_assignments fun(buf: integer): LiveCalcAssignment[]
---@field get_errors fun(buf: integer): LiveCalcError[]

---@class LiveCalcAssignment
---@field line integer
---@field var string
---@field expr string
---@field code string

local M = {}

local ts = vim.treesitter

---@param node TSNode
---@return boolean
local function has_error(node)
	if node:type() == "ERROR" then
		return true
	end

	for child in node:iter_children() do
		if has_error(child) then
			return true
		end
	end

	return false
end

---@param buf integer
---@return LiveCalcAssignment[]
-- TODO: this will change completely when using custom DSL.
function M.get_assignments(buf)
	local parser = ts.get_parser(buf, "lua")
	if not parser then
		return {}
	end

	local trees = parser:parse()
	if not trees or not trees[1] then
		return {}
	end

	local root = trees[1]:root()

	local ok, query = pcall(
		ts.query.parse,
		"lua",
		[[
    (assignment_statement
      (variable_list) @var
      (expression_list) @expr)
    ]]
	)

	if not ok then
		return {}
	end

	---@type LiveCalcAssignment[]
	local results = {}

	for _, match in query:iter_matches(root, buf, 0, -1) do
		local var_nodes = match[1]
		local expr_nodes = match[2]

		if var_nodes and expr_nodes then
			local var_node = var_nodes[1]
			local expr_node = expr_nodes[1]

			if var_node and expr_node then
				local assignment_node = var_node:parent()
				if not assignment_node then
					goto continue
				end

				-- Reject multiline assignments.
				local start_row, _, end_row, _ = assignment_node:range()
				if start_row ~= end_row then
					goto continue
				end

				-- Reject anything containing syntax errors
				if has_error(assignment_node) then
					goto continue
				end

				local var_text = ts.get_node_text(var_node, buf)
				local expr_text = ts.get_node_text(expr_node, buf)

				table.insert(results, {
					line = start_row,
					var = var_text,
					expr = expr_text,
					code = var_text .. " = " .. expr_text,
				})
			end
		end

		::continue::
	end

	table.sort(results, function(a, b)
		return a.line < b.line
	end)

	return results
end

---@class LiveCalcError
---@field line integer
---@field message string

---@param buf integer
---@return LiveCalcError[]
function M.get_errors(buf)
	local parser = ts.get_parser(buf, "lua")
	if not parser then
		return {}
	end

	local trees = parser:parse()
	if not trees or not trees[1] then
		return {}
	end

	local root = trees[1]:root()

	local ok, query = pcall(
		ts.query.parse,
		"lua",
		[[
    (ERROR) @err
    ]]
	)

	if not ok then
		return {}
	end

	---@type LiveCalcError[]
	local results = {}

	for _, match in query:iter_matches(root, buf, 0, -1) do
		local nodes = match[1]
		if nodes then
			for _, node in ipairs(nodes) do
				local line = node:range()
				local text = ts.get_node_text(node, buf)

				table.insert(results, {
					line = line,
					message = "syntax error: " .. text,
				})
			end
		end
	end

	return results
end

return M
