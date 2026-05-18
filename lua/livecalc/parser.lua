---@class AstLine
---@field line integer
---@field node AstNode

local M = {}

local ast = require("livecalc.ast")

--------------------------------------------------------------------------------
-- Parse entire document into AST lines
--------------------------------------------------------------------------------

---@param bufnr integer
---@return table<integer, AstNode>?
function M.parse_document(bufnr)
	local parser = vim.treesitter.get_parser(bufnr, "livecalc")
	if not parser then
		return nil
	end

	local tree = parser:parse()[1]

	local root = tree:root()

	---@type AstLine[]
	local result = {}

	for node in root:iter_children() do
		if node:named() then
			---@type AstLine
			local ast_line = {
				line = node:start() + 1,
				node = ast.build(bufnr, node),
			}

			table.insert(result, ast_line)
		end
	end

	return result
end

return M
