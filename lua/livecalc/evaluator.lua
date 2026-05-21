local M = {}
local M_priv = {}

---@class ResultSuccess
---@field type "success"
---@field value number
---@field units string?

---@class EvalError
---@field msg string
---@field range NodeRange

---@class ResultError
---@field type "error"
---@field errors EvalError[]

---@alias Result
---| ResultSuccess
---| ResultError

---@alias Env table<string, number>

---@class EvalState
---@field env Env
---@field line_results table<integer, Result>

---@return EvalState
local function new_state()
	return {
		env = {},
		line_results = {},
	}
end

---@param node AstNode
---@param msg string
local function eval_error(node, msg)
	---@type EvalError
	return {
		msg = msg,
		range = node.range,
	}
end

local unary_operations = {
	---@type fun(value: number): number
	["-"] = function(value)
		return -value
	end,
	---@type fun(value: number): number
	["+"] = function(value)
		return value
	end,
}

local binary_operations = {
	---@type fun(left: number, right:number): number
	["-"] = function(left, right)
		return left - right
	end,
	---@type fun(left: number, right:number): number
	["+"] = function(left, right)
		return left + right
	end,
	---@type fun(left: number, right:number): number
	["*"] = function(left, right)
		return left * right
	end,
	---@type fun(left: number, right:number): number
	["/"] = function(left, right)
		return left / right
	end,
	["**"] = function(left, right)
		return left ^ right
	end,
}

local node_eval = {
	---@param node ErrorNode
	error = function(node)
		---@type ResultError
		return {
			type = "error",
			errors = { eval_error(node, node.msg) },
		}
	end,

	---@param node NumberNode
	number = function(node)
		---@type ResultSuccess
		return {
			type = "success",
			value = node.value,
		}
	end,

	---@param node IdentifierNode
	---@param env Env
	identifier = function(node, env)
		local value = env[node.name]

		if value == nil then
			---@type ResultError
			return {
				type = "error",
				errors = { eval_error(node, "undefined variable `" .. node.name .. "`") },
			}
		end

		---@type ResultSuccess
		return {
			type = "success",
			value = value,
		}
	end,

	---@param node UnaryNode
	---@param env Env
	---@return Result
	unary = function(node, env)
		local result = M_priv.eval(node.expr, env)
		if result.type == "error" then
			return result
		end

		local op = unary_operations[node.op]
		if not op then
			---@type ResultError
			return {
				type = "error",
				errors = { eval_error(node, "unknown operator: " .. node.op) },
			}
		end
		result.value = op(result.value)

		return result
	end,

	---@param node BinaryNode
	---@param env Env
	binary = function(node, env)
		local left = M_priv.eval(node.left, env)
		local right = M_priv.eval(node.right, env)

		if left.type == "error" or right.type == "error" then
			---@type ResultError
			return {
				type = "error",
				errors = vim.list_extend(left.errors or {}, right.errors or {}),
			}
		end

		local op = binary_operations[node.op]

		if not op then
			---@type ResultError
			return {
				type = "error",
				errors = {
					eval_error(node, "Unknown operator `" .. node.op .. "`"),
				},
			}
		end

		---@type ResultSuccess
		return {
			type = "success",
			value = op(left.value, right.value),
		}
	end,

	---@param node AssignmentNode
	---@param env Env
	assignment = function(node, env)
		local result = M_priv.eval(node.value, env)

		if result.type == "error" then
			return result
		end

		env[node.identifier] = result.value

		return result
	end,

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
}

---@param node AstNode
---@param env table<string, number>
---@return Result
function M_priv.eval(node, env)
	local eval_fun = node_eval[node.type]
	assert(eval_fun ~= nil, "Unknown node type: " .. tostring(node.type))
	return eval_fun(node, env)
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

---@param ast_lines AstLine[]
---@return EvalState
function M.evaluate_document(ast_lines)
	local state = new_state()

	for _, ast_line in ipairs(ast_lines) do
		state.line_results[ast_line.line] = M_priv.eval(ast_line.node, state.env)
	end

	return state
end

return M
