local units = require("livecalc.render.units")

local M = {}

---@param fn RuntimeFunction
---@return string
function M.render_function(fn)
	local params = {}

	for _, param in ipairs(fn.params) do
		if param.unit == nil then
			table.insert(params, "any")
		else
			table.insert(params, "[" .. units.render_units(param.unit) .. "]")
		end
	end

	local return_type

	if fn.return_units == nil then
		return_type = "any"
	else
		return_type = "[" .. units.render_units(fn.return_units) .. "]"
	end

	return ("(%s) => %s"):format(table.concat(params, ", "), return_type)
end

return M
