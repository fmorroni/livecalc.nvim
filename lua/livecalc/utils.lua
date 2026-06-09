local M = {}

-- Source - https://stackoverflow.com/a/67976046
-- Posted by Wolf, modified by community. See post 'Timeline' for change history
-- Retrieved 2026-06-09, License - CC BY-SA 4.0
---@param number number
---@param decimals integer
function M.round(number, decimals)
	local scale = 10 ^ decimals
	local c = 2 ^ 52 + 2 ^ 51
	return ((number * scale + c) - c) / scale
end

return M
