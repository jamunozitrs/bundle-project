--- @Functions Helper File

local helperString = require "common/HelperString"


	-- See if the file exists
	function file_exists(file)

		local f = io.open(file, "rb")

		if f then f:close() end

		return f ~= nil

	end


-- Get all lines from a file, returns an empty
-- list/table if the file does not exist
function lines_from(file)

	local lines = {}

  if not file_exists(file) then
		return {}
	end

  for line in io.lines(file) do
    lines[#lines + 1] = line
  end

  return lines

end


function writeHeadCSV(table, csvPath)

	file = io.open(csvPath, 'w')
	str = ""

	for k,v in pairs(table) do

		if type(v)~="table" then
			str = str .. k .. ","
		else
			str = str .. getKeysTableToString(k, v)
		end

	end

	file:write(str:sub(1, -2), "\n")
	file:close()

end


function writeBodyCSV(table, csvPath)

	file = io.open(csvPath, 'a')
	str = ""

	for k,v in pairs(table) do

		if type(v)~="table" then
			str = str .. v .. ","
		else
			str = str .. getValuesTableToString(v)
		end

	end

	file:write(str:sub(1, -2), "\n")
	file:close()

end
