-- lua/livecalc/evaluator.lua

local M = {}

--------------------------------------------------------------------------------
-- Environment
--------------------------------------------------------------------------------

---@class EvalState
---@field env table<string, number>
---@field line_results table<integer, any>

---@return EvalState
function M.new_state()
	return {
		env = {},
		line_results = {},
	}
end

--------------------------------------------------------------------------------
-- AST Evaluation
--------------------------------------------------------------------------------

---@param node AstNode
---@param env table<string, number>
local function eval(node, env)
	if not node then
		return nil
	end

	if node.type == "number" then
		return node.value
	end

	if node.type == "identifier" then
		local value = env[node.name]

		if value == nil then
			error("undefined variable: " .. node.name)
		end

		return value
	end

	if node.type == "unary" then
		local value = eval(node.expr, env)

		if node.op == "-" then
			return -value
		end

		error("unknown unary operator: " .. node.op)
	end

	if node.type == "binary" then
		local left = eval(node.left, env)
		local right = eval(node.right, env)

		if node.op == "+" then
			return left + right
		elseif node.op == "-" then
			return left - right
		elseif node.op == "*" then
			return left * right
		elseif node.op == "/" then
			return left / right
		elseif node.op == "^" then
			return left ^ right
		end

		error("unknown binary operator: " .. node.op)
	end

	if node.type == "assignment" then
		local value = eval(node.value, env)

		env[node.name] = value

		return value
	end

	-- if node.type == "call" then
	-- 	local fn = math[node.name]
	--
	-- 	if type(fn) ~= "function" then
	-- 		error("unknown function: " .. node.name)
	-- 	end
	--
	-- 	local args = {}
	--
	-- 	for i, arg in ipairs(node.args) do
	-- 		args[i] = eval(arg, env)
	-- 	end
	--
	-- 	return fn(unpack(args))
	-- end

	error("unknown node type: " .. tostring(node.type))
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

---@param ast_lines AstLine[]
---@return EvalState
function M.evaluate_document(ast_lines)
	local state = M.new_state()

	for _, ast_line in ipairs(ast_lines) do
		local ok, result = pcall(eval, ast_line.node, state.env)

		if ok then
			state.line_results[ast_line.line] = result
		else
			state.line_results[ast_line.line] = {
				error = result,
			}
		end
	end

	return state
end

return M
