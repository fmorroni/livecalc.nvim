local M = {}

local superscript_map = {
	["0"] = "⁰",
	["1"] = "¹",
	["2"] = "²",
	["3"] = "³",
	["4"] = "⁴",
	["5"] = "⁵",
	["6"] = "⁶",
	["7"] = "⁷",
	["8"] = "⁸",
	["9"] = "⁹",
	["-"] = "⁻",
	["."] = "·",
}

---@param str string
---@return string
local function to_superscript(str)
	return (str:gsub(".", superscript_map))
end

---@param exp number
---@return string
local function format_exponent(exp)
	local rounded = math.floor(exp * 100 + 0.5) / 100

	-- normalize integers
	if rounded == math.floor(rounded) then
		rounded = math.floor(rounded)
	end

	if rounded == 1 then
		return ""
	end

	return to_superscript(tostring(rounded))
end

---@param entries { name: string, exp: number }[]
---@return string
local function render_group(entries)
	---@type table<string, string[]>
	local grouped = {}

	for _, entry in ipairs(entries) do
		local key = tostring(entry.exp)

		grouped[key] = grouped[key] or {}
		table.insert(grouped[key], entry.name)
	end

	---@type { exp: number, units: string[] }[]
	local ordered = {}

	for exp, names in pairs(grouped) do
		table.sort(names)

		table.insert(ordered, {
			exp = tonumber(exp),
			units = names,
		})
	end

	table.sort(ordered, function(a, b)
		if a.exp ~= b.exp then
			return a.exp > b.exp
		end

		return a.units[1] < b.units[1]
	end)

	local out = {}

	for _, group in ipairs(ordered) do
		local units = table.concat(group.units, " ")

		if #group.units > 1 and group.exp ~= 1 then
			units = "(" .. units .. ")"
		end

		table.insert(out, units .. format_exponent(group.exp))
	end

	return table.concat(out, " ")
end

---@param units table<string, number>
---@return string
function M.render_units(units)
	---@type { name: string, exp: number }[]
	local numerator = {}

	---@type { name: string, exp: number }[]
	local denominator = {}

	for name, exp in pairs(units) do
		if exp > 0 then
			table.insert(numerator, {
				name = name,
				exp = exp,
			})
		elseif exp < 0 then
			table.insert(denominator, {
				name = name,
				exp = -exp,
			})
		end
	end

	local function sorter(a, b)
		if a.exp ~= b.exp then
			return a.exp > b.exp
		end

		return a.name < b.name
	end

	table.sort(numerator, sorter)
	table.sort(denominator, sorter)

	local num = render_group(numerator)
	local den = render_group(denominator)

	if num ~= "" and den ~= "" then
		return num .. " / " .. den
	elseif den ~= "" then
		return "1 / " .. den
	else
		return num
	end
end

return M
