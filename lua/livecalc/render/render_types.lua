local u = require("livecalc.render.units")

return {
	---@param number RuntimeNumber
	number = function(number)
		local text = "= " .. tostring(number.value)

		local units = u.render_units(number.units)

		if units ~= "" then
			text = ("%s [%s]"):format(text, units)
		end

		return text
	end,

	---@param bool RuntimeBoolean
	boolean = function(bool)
		return "= " .. tostring(bool.value)
	end,

	---@param fn RuntimeFunction
	["function"] = function(fn)
		local params = {}

		for _, param in ipairs(fn.params) do
			if param.unit == nil then
				table.insert(params, "any")
			else
				table.insert(params, "[" .. u.render_units(param.unit) .. "]")
			end
		end

		local return_type

		if fn.return_units == nil then
			return_type = "any"
		else
			return_type = "[" .. u.render_units(fn.return_units) .. "]"
		end

		return ("(%s) => %s"):format(table.concat(params, ", "), return_type)
	end,
}
