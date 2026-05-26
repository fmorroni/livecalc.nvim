local M = {}
local M_priv = {}

local u = require("livecalc.units_helper")
local unit_render = require("livecalc.render.units")

---@class ResultSuccess
---@field type "success"
---@field value number
---@field units Units

---@class EvalError
---@field msg string
---@field range NodeRange

---@class ResultError
---@field type "error"
---@field errors EvalError[]

---@alias Result
---| ResultSuccess
---| ResultError

---@alias Env table<string, ResultSuccess>

---@class LineResult
---@field line integer
---@field result Result

---@class EvalState
---@field env Env
---@field line_results LineResult[]

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

---@type fun(left: ResultSuccess, right:ResultSuccess, node: BinaryNode, op: "+" | "-"): Result
local function addition_subraction(left, right, node, op)
	if not u.units_equal(left.units, right.units) then
		local left_units = unit_render.render_units(left.units)
		local right_units = unit_render.render_units(right.units)
		local units = ("[%s] %s [%s]"):format(left_units, op, right_units)
		---@type ResultError
		return {
			type = "error",
			errors = {
				eval_error(node, "Left and right expressions must have same units, found: " .. units),
			},
		}
	end

	---@type ResultSuccess
	return {
		type = "success",
		value = (op == "+") and left.value + right.value or left.value - right.value,
		units = left.units,
	}
end

---@alias BinaryOp fun(left: ResultSuccess, right:ResultSuccess, node: BinaryNode): Result
local binary_operations = {
	---@type BinaryOp
	["-"] = function(left, right, node)
		return addition_subraction(left, right, node, "-")
	end,
	---@type BinaryOp
	["+"] = function(left, right, node)
		return addition_subraction(left, right, node, "+")
	end,
	---@type BinaryOp
	["*"] = function(left, right)
		---@type ResultSuccess
		return {
			type = "success",
			value = left.value * right.value,
			units = u.units_times(left.units, right.units, 1),
		}
	end,
	---@type BinaryOp
	["/"] = function(left, right)
		---@type ResultSuccess
		return {
			type = "success",
			value = left.value / right.value,
			units = u.units_times(left.units, right.units, -1),
		}
	end,
	---@type BinaryOp
	["**"] = function(left, right, node)
		if not u.units_empty(right.units) then
			---@type ResultError
			return {
				type = "error",
				errors = {
					eval_error(node.right, "Exponent can't have units"),
				},
			}
		end

		---@type ResultSuccess
		return {
			type = "success",
			value = left.value ^ right.value,
			units = u.units_exp(left.units, right.value),
		}
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
			units = {},
		}
	end,

	---@param node IdentifierNode
	---@param env Env
	identifier = function(node, env)
		local id = env[node.name]

		if id == nil then
			---@type ResultError
			return {
				type = "error",
				errors = { eval_error(node, "undefined variable `" .. node.name .. "`") },
			}
		end

		---@type ResultSuccess
		return {
			type = "success",
			value = id.value,
			units = id.units,
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

		return op(left, right, node)
	end,

	---@param node AssignmentNode
	---@param env Env
	assignment = function(node, env)
		local result = M_priv.eval(node.value, env)

		if result.type == "error" then
			return result
		end

		env[node.identifier] = result

		return result
	end,

	---@param node UnitAttachNode
	---@param env Env
	unit_attach = function(node, env)
		local result = M_priv.eval(node.expr, env)

		if result.type == "error" then
			return result
		end

		result.units = u.units_times(result.units, node.units, 1)

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
---@param env Env
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
		---@type LineResult
		local line_result = {
			line = ast_line.line,
			result = M_priv.eval(ast_line.node, state.env),
		}

		table.insert(state.line_results, line_result)
	end

	return state
end

return M
