---@class LiveCalcEvaluator
---@field new_env fun(): LiveCalcEnv
---@field eval_assignment fun(node: LiveCalcAssignment, env: LiveCalcEnv): boolean, any

---@class LiveCalcEnv : table<string, any>

---@class LiveCalcEvalResult
---@field ok boolean
---@field value any

local M = {}

---@return LiveCalcEnv
function M.new_env()
	return {
		math = math,
	}
end

---@param node LiveCalcAssignment
---@param env LiveCalcEnv
---@return boolean ok, any result
function M.eval_assignment(node, env)
	local fn, err = load(node.code, "livecalc", "t", env)
	if not fn then
		return false, err
	end

	local ok, exec_err = pcall(fn)
	if not ok then
		return false, exec_err
	end

	local value_fn = load("return " .. node.expr, "livecalc", "t", env)
	if not value_fn then
		return false, "invalid RHS"
	end

	local ok2, result = pcall(value_fn)
	if not ok2 then
		return false, result
	end

	return true, result
end

return M
