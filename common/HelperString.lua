--- @Functions Helper String


function trim(str)
  return (str:gsub("^%s*(.-)%s*$", "%1"))
end


function regexFind(str, patternId)

	local result = {}
	local count
	local matchResult
	local nextMatchResult

	result[0] = -1
	matchResult = Collector.RegEx.createMatch(str, patternId)
	nextMatchResult = Collector.RegEx.getNextMatchResult(matchResult[1])

  if (nextMatchResult[0] == 0.0) then

		result[0] = 1
    count = nextMatchResult[1]["count"]

    for i = 1, count-1, 1 do
			result[i] = nextMatchResult[1]["data"][i]["string"]
    end

  end

	Collector.RegEx.destroyMatch(matchResult[1])
	return result

end


function getKeysTableToString(nameTable, table)

	local str = ""

	for k,v in pairs(table) do
		str = str .. nameTable .. "." .. k  .. ","
	end

	return str

end


function getValuesTableToString(table)

	local str = ""

	for k,v in pairs(table) do
		str = str .. v  .. ","
	end

	return str

end
