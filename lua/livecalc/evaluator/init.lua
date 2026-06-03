local M = {}
local M_priv = {}

local h = require("livecalc.evaluator.helpers")
local u = require("livecalc.units_helper")
local unit_render = require("livecalc.render.units")
local ops = require("livecalc.evaluator.operators")
local builtin_functions = require("livecalc.evaluator.builtin_functions")
local builtin_constants = require("livecalc.evaluator.builtin_constants")

---@return EvalState
local function new_state()
	return {
		env = {},
		line_results = {},
	}
end

---@alias NodeEvalFun<T> fun(node: T, env: Env): Result

local node_eval
node_eval = {
	---@type NodeEvalFun<ErrorNode>
	error = function(node)
		return h.result_error({ h.eval_error(node, node.msg) })
	end,

	---@type NodeEvalFun<NumberNode>
	number = function(node)
		return h.result_success(h.runtime_number(node.value, {}))
	end,

	---@type NodeEvalFun<BooleanNode>
	boolean = function(node)
		return h.result_success(h.runtime_boolean(node.value))
	end,

	---@type NodeEvalFun<IdentifierNode>
	identifier = function(node, env)
		local id = env[node.name]

		if id == nil then
			return h.result_error({ h.eval_error(node, "undefined variable `" .. node.name .. "`") })
		end

		return h.result_success(id)
	end,

	---@type NodeEvalFun<UnaryNode>
	unary_numeric = function(node, env)
		local result = M_priv.eval(node.expr, env)
		if result.type == "error" then
			return result
		end

		local value = h.assert_number(node, result.value)
		if value.type == "error" then
			return value
		end

		local op = ops.unary_numeric[node.op]
		if not op then
			return h.result_error({ h.eval_error(node, ("unknown operator `%s`"):format(node.op)) })
		end
		return h.result_success(h.runtime_number(op(value.value), value.units))
	end,

	---@type NodeEvalFun<UnaryNode>
	unary_boolean = function(node, env)
		local result = M_priv.eval(node.expr, env)
		if result.type == "error" then
			return result
		end

		local value = h.assert_boolean(node, result.value)
		if value.type == "error" then
			return value
		end

		local op = ops.unary_boolean[node.op]
		if not op then
			return h.result_error({ h.eval_error(node, ("unknown operator `%s`"):format(node.op)) })
		end
		value.value = op(value.value)

		return result
	end,

	---@type NodeEvalFun<BinaryNode>
	binary_numeric = function(node, env)
		local left_node = M_priv.eval(node.left, env)
		local right_node = M_priv.eval(node.right, env)

		if left_node.type == "error" or right_node.type == "error" then
			---@type ResultError
			return {
				type = "error",
				errors = vim.list_extend(left_node.errors or {}, right_node.errors or {}),
			}
		end

		local left = h.assert_number(node.left, left_node.value)
		local right = h.assert_number(node.right, right_node.value)
		if left.type == "error" or right.type == "error" then
			return h.join_result_errors(left.errors, right.errors)
		end

		local op = ops.binary_numeric[node.op]
		if not op then
			return h.result_error({ h.eval_error(node, ("unknown operator `%s`"):format(node.op)) })
		end

		return op(left, right, node)
	end,

	---@type NodeEvalFun<BinaryNode>
	binary_boolean = function(node, env)
		local left_node = M_priv.eval(node.left, env)
		local right_node = M_priv.eval(node.right, env)

		if left_node.type == "error" or right_node.type == "error" then
			---@type ResultError
			return {
				type = "error",
				errors = vim.list_extend(left_node.errors or {}, right_node.errors or {}),
			}
		end

		local op = ops.binary_boolean[node.op]
		if not op then
			return h.result_error({ h.eval_error(node, ("unknown operator `%s`"):format(node.op)) })
		end

		return op(left_node.value, right_node.value, node)
	end,

	---@type NodeEvalFun<AssignmentNode>
	assignment = function(node, env)
		local result = M_priv.eval(node.value, env)

		if result.type == "error" then
			return result
		end

		env[node.identifier] = result.value

		return result
	end,

	---@type NodeEvalFun<UnitAttachNode>
	unit_attach = function(node, env)
		local result = M_priv.eval(node.expr, env)

		if result.type == "error" then
			return result
		end

		local value = result.value
		if value.type ~= "number" then
			return h.result_error({ h.eval_error(node, ("%s can't have units"):format(value.type)) })
		end

		local new_value = h.runtime_number(value.value, u.units_times(value.units, node.units, 1))

		return h.result_success(new_value)
	end,

	---@type NodeEvalFun<BuiltinCallNode>
	builtin_call = function(node, env)
		local builtin = builtin_functions[node.identifier.name]
		if builtin == nil then
			return h.result_error({
				h.eval_error(node.identifier, ("invalid builtin function `@%s`"):format(node.identifier.name)),
			})
		end

		---@type RuntimeValue[]
		local args = {}
		---@type ResultError?
		local error = nil

		for i, arg in ipairs(node.args) do
			local result = M_priv.eval(arg, env)

			if result.type == "error" then
				error = error or h.result_error({})
				vim.list_extend(error.errors, result.errors)
			else
				-- local value = h.assert_number(node.args[i], result.value)
				-- if value.type == "error" then
				-- 	return value
				-- end
				-- args[i] = value
				args[i] = result.value
			end
		end

		if error then
			return error
		end

		return builtin(args, node)
	end,

	---@type NodeEvalFun<IdentifierCallNode>
	identifier_call = function(node, env)
		local result = node_eval.identifier(node.identifier, env)
		if result.type == "error" then
			return result
		end
		local fn = result.value
		if fn.type ~= "function" then
			return h.result_error({
				h.eval_error(node, ("expected function, found `%s`"):format(fn.type)),
			})
		end
		return M_priv.eval_runtime_function(fn, node, env)
	end,

	---@type NodeEvalFun<BuiltinConstant>
	builtin_constant = function(node)
		local constant = builtin_constants[node.identifier.name]
		if constant == nil then
			return h.result_error({
				h.eval_error(node.identifier, ("invalid builtin constant `@%s`"):format(node.identifier.name)),
			})
		end
		return h.result_success(h.runtime_number(constant, {}))
	end,

	---@type NodeEvalFun<InlineFunctionCallNode>
	inline_function_call = function(node, env)
		local fn = h.runtime_function(node.fn, env)
		return M_priv.eval_runtime_function(fn, node, env)
	end,

	---@type NodeEvalFun<FunctionNode>
	function_def = function(node, env)
		local fn = h.runtime_function(node, env)

		local can_infer = true

		for _, param in ipairs(fn.params) do
			if param.unit == nil then
				can_infer = false
				break
			end
		end

		---@type Units?
		local return_units = nil
		if can_infer then
			local bindings = {}

			for _, param in ipairs(fn.params) do
				bindings[param.name] = {
					type = "number",
					value = 1,
					units = vim.deepcopy(param.unit),
				}
			end

			local result = M_priv.eval_function_body(fn, bindings)
			if result.type == "error" then
				return result
			end
			local value = result.value
			assert(value.type == "number", "Expected to infer numeric value")
			return_units = value.units
		end

		fn.return_units = return_units

		return h.result_success(fn)
	end,
}

---@param node AstNode
---@param env Env
---@return Result
function M_priv.eval(node, env)
	local eval_fun = node_eval[node.type]
	if not eval_fun then
		return h.result_error({ h.eval_error(node, ("unknown node type `%s`"):format(node.type)) })
	end
	return eval_fun(node, env)
end

---@param fn RuntimeFunction
---@param bindings Env
---@return Result
function M_priv.eval_function_body(fn, bindings)
	local child_env = vim.tbl_extend("force", {}, fn.closure, bindings)
	return M_priv.eval(fn.body, child_env)
end

---@param fn RuntimeFunction
---@param node IdentifierCallNode | InlineFunctionCallNode
---@param env Env
function M_priv.eval_runtime_function(fn, node, env)
	if #node.args ~= #fn.params then
		return h.result_error({
			h.eval_error(node, ("expected %d args, got %d"):format(#fn.params, #node.args)),
		})
	end

	local bindings = {}

	for i, param in ipairs(fn.params) do
		local arg = M_priv.eval(node.args[i], env)

		if arg.type == "error" then
			return arg
		end

		local value = arg.value

		if param.unit then
			if value.type ~= "number" then
				return h.result_error({
					h.eval_error(node.args[i], "expected a numeric argument"),
				})
			end

			if not u.units_equal(value.units, param.unit) then
				return h.result_error({
					h.eval_error(
						node.args[i],
						("argument of type `[%s]` is not assignable to parameter of type `[%s]`"):format(
							unit_render.render_units(value.units),
							unit_render.render_units(param.unit)
						)
					),
				})
			end
		end

		bindings[param.name] = value
	end

	local res = M_priv.eval_function_body(fn, bindings)

	if res.type == "success" then
		return res
	end

	for _, error in ipairs(res.errors) do
		error.range = node.range
	end

	return res
end

------@type fun(node: BinaryNode, env: Env, type: "number" | "boolean"): Result
---function M_priv.eval_binary(node, env, type) end

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
