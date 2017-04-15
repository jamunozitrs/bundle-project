--- @Functions Helper System Info

local systemInfo =
	{
		["os-description"] = "",
		["architecture"] = "",
		["os-version"] = "",
		["os-name"] = "",
	}


function loadSystemInfo()
	return Collector.Core.getSystemInformation()[1]
end


function getJPSPID(proccessName, jpsFile)

	local linesFromFile
	local pid = -1

	os.execute("jps > " .. jpsFile)
	linesFromFile = lines_from(jpsFile)

	found = false
	i = 1


	while (linesFromFile[i]~=nil and (not found)) do

		if (string.find(linesFromFile[i], proccessName) ~=nil) then
			tokens = Collector.String.tokenize(linesFromFile[i], " ")
			pid = tokens[1][0]
			print("The " .. tokens[1][1] .. " proccess has the PID: " .. pid .. "\n")
			found = true
		end

		i=i+1

	end

	return pid

end


function jmap(param, pid, outFile)

	print("-------------------- jmap -" .. param .. "--------------------")

	if (param == "heap") then
		os.execute("jmap -".. param .. " " .. pid .. " > " .. outFile)
	else
		os.execute("jmap -".. param .. ":format=b,file=" .. outFile .. " " .. pid)
	end

	print("jmap -".. param .. " info should be sent to " .. outFile .. "\n")

end


function jstack(pid, outFile)

	print("-------------------- jstack --------------------")
	os.execute("jstack " .. pid .. " > " .. outFile)
	print("jstack info should be sent to " .. outFile .. "\n")

end


function pmap(pid, outFile)

	print("-------------------- pmap --------------------")
	os.execute("pmap -x " .. pid .. " > " .. outFile)
	print("pmap -x info sent to " .. outFile .. "\n")

end


function vmmap(pid, outFile)

	print("-------------------- vmmap --------------------")
	os.execute("vmmap -p " .. pid .. " " .. outFile)
	print("vmmap info should be sent to " .. outFile .. "\n")

end


function smaps(pid, outFile)

	print("-------------------- smaps --------------------")
	os.execute("cat /proc/" .. pid .. "/smaps > " .. outFile)
	print("smaps info should be sent to " .. outFile .. "\n")

end


systemInfo = loadSystemInfo()

return systemInfo
