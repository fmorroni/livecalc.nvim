local M = {}

---@param left Units
---@param right Units
---@param sign integer -- +1 or -1
function M.units_times(left, right, sign)
	local out = vim.deepcopy(left)

	for unit, exp in pairs(right) do
		out[unit] = (out[unit] or 0) + exp * sign

		if out[unit] == 0 then
			out[unit] = nil
		end
	end

	return out
end

---@param base Units
---@param exponent number
function M.units_exp(base, exponent)
	local res = {}
	for unit, exp in pairs(base) do
		res[unit] = exp * exponent
	end
	return res
end

---@param units Units
function M.units_empty(units)
	return next(units) == nil
end

---@param left Units
---@param right Units
function M.units_equal(left, right)
	for k, v in pairs(left) do
		if right[k] ~= v then
			return false
		end
	end

	for k, v in pairs(right) do
		if left[k] ~= v then
			return false
		end
	end

	return true
end

return M
