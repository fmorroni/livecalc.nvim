local M = {}
local M_priv = {}

local h = require("livecalc.evaluator.helpers")
local u = require("livecalc.units_helper")
local unit_render = require("livecalc.render.units")
local builtins = require("livecalc.evaluator.builtins")

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
		return h.result_error({
			h.eval_error(node, "left and right expressions must have same units, found: " .. units),
		})
	end

	return h.result_success((op == "+") and left.value + right.value or left.value - right.value, left.units)
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
		return h.result_success(left.value * right.value, u.units_times(left.units, right.units, 1))
	end,
	---@type BinaryOp
	["/"] = function(left, right)
		return h.result_success(left.value / right.value, u.units_times(left.units, right.units, -1))
	end,
	---@type BinaryOp
	["**"] = function(left, right, node)
		if not u.units_empty(right.units) then
			local units = ("[%s]"):format(unit_render.render_units(right.units))
			return h.result_error({ h.eval_error(node.right, "exponent can't have units, found: " .. units) })
		end

		return h.result_success(left.value ^ right.value, u.units_exp(left.units, right.value))
	end,
}

---@alias NodeEvalFun<T> fun(node: T, env: Env): Result

local node_eval = {
	---@type NodeEvalFun<ErrorNode>
	error = function(node)
		return h.result_error({ h.eval_error(node, node.msg) })
	end,

	---@type NodeEvalFun<NumberNode>
	number = function(node)
		return h.result_success(node.value, {})
	end,

	---@type NodeEvalFun<IdentifierNode>
	identifier = function(node, env)
		local id = env[node.name]

		if id == nil then
			return h.result_error({ h.eval_error(node, "undefined variable `" .. node.name .. "`") })
		end

		return h.result_success(id.value, id.units)
	end,

	---@type NodeEvalFun<UnaryNode>
	unary = function(node, env)
		local result = M_priv.eval(node.expr, env)
		if result.type == "error" then
			return result
		end

		local op = unary_operations[node.op]
		if not op then
			return h.result_error({ h.eval_error(node, "unknown operator: " .. node.op) })
		end
		result.value = op(result.value)

		return result
	end,

	---@type NodeEvalFun<BinaryNode>
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
			return h.result_error({ h.eval_error(node, "unknown operator `" .. node.op .. "`") })
		end

		return op(left, right, node)
	end,

	---@type NodeEvalFun<AssignmentNode>
	assignment = function(node, env)
		local result = M_priv.eval(node.value, env)

		if result.type == "error" then
			return result
		end

		env[node.identifier] = result

		return result
	end,

	---@type NodeEvalFun<UnitAttachNode>
	unit_attach = function(node, env)
		local result = M_priv.eval(node.expr, env)

		if result.type == "error" then
			return result
		end

		result.units = u.units_times(result.units, node.units, 1)

		return result
	end,

	---@type NodeEvalFun<BuiltinCallNode>
	builtin_call = function(node, env)
		local builtin = builtins[node.identifier.name]
		if builtin == nil then
			return h.result_error({
				h.eval_error(node.identifier, ("invalid builtin function `@%s`"):format(node.identifier.name)),
			})
		end

		---@type ResultSuccess[]
		local args = {}
		---@type ResultError?
		local error = nil

		for i, arg in ipairs(node.args) do
			local result = M_priv.eval(arg, env)

			if result.type == "error" then
				error = error or h.result_error({})
				vim.list_extend(error.errors, result.errors)
			else
				args[i] = result
			end
		end

		if error then
			return error
		end

		return builtin(args, node)
	end,

	function_call = function(node)
		return h.result_error({ h.eval_error(node, "Custom functions not supported yet") })
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
