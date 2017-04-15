local helperFile = require('common/HelperFile')
local helperString = require('common/HelperString')
local helperSystemInfo = require('common/HelperSystemInfo')

local isRunning
local cron
local javaProcessName
local jpsFile
local jstackFile
local regexStandardToFind
local regexThreadToFind

local patternStandardResult
local patternThreadResult
local schedulerResult

local myResultMessage =
	{

		["timestamp"] = nil,
		["hostname"] = 	nil,
		["fileName"] 	= nil,

		testRunInfo =
			{
				["project"] 		= nil,
				["testRunID"] 	= nil,
				["valoVersion"] = nil
			},

		["description"] = nil,
		["number"] 			= nil,
		["deamon"] 			= nil,
		["prio"] 				= nil,
		["os_prio"] 		= nil,
		["tid"] 				= nil,
		["nid"] 				= nil,
		["info_mem"] 		= nil,
		["status_thread"] = nil,
		["info_more"] 		= nil
	}


function processJstackFile(jstackFile)

		local resultRegex
		local resultSend
		local linesFromFile
		local i
		local regexCad = ""
		local moreInfoCad = ""

		linesFromFile = lines_from(jstackFile)

		i = 4
		while linesFromFile[i]~= nil do

				regexCad = regexCad .. linesFromFile[i] .. "\n"
				resultRegex = regexFind(regexCad, patternStandardResult[1])

				if (resultRegex[0] == 1) then

					i=i+1
					while linesFromFile[i]~= "" do
						moreInfoCad = moreInfoCad .. linesFromFile[i] .. "\n"
						i=i+1
					end

					loadMessageStandard(resultRegex, moreInfoCad)
					resultSend = Collector.Connector.send("MSG_JSTACK", myResultMessage)
					if resultSend[0] ~= 0 then
						print("error while calling method ('" .. resultSend[1] .. "')")
					end

					regexCad = ""
					moreInfoCad = ""

				else

					resultRegex = regexFind(linesFromFile[i], patternThreadResult[1])

					if 	(resultRegex[0] == 1) then

						loadMessageThread(resultRegex)
						resultSend = Collector.Connector.send("MSG_JSTACK", myResultMessage)
						if resultSend[0] ~= 0 then
							print("error while calling method ('" .. resultSend[1] .. "')")
						end

						regexCad = ""

					end

				end

				i=i+1

		end

end


function loadMessageStandard(auxM, moreInfoCad)

		myResultMessage["description"] 	= auxM[1]
		myResultMessage["number"] 			= auxM[2]

		if (auxM[3] == "deamon") then
			myResultMessage["deamon"] = "true"
		else
			myResultMessage["deamon"] = "false"
		end

		myResultMessage["prio"] 					= auxM[4]
		myResultMessage["os_prio"] 				= auxM[5]
		myResultMessage["tid"] 						= auxM[6]
		myResultMessage["nid"] 						= auxM[7]
		myResultMessage["info_mem"] 			= auxM[8]
		myResultMessage["status_thread"] 	= auxM[9]
		myResultMessage["info_more"] 			= moreInfoCad

end


function loadMessageThread(auxM)

		myResultMessage["description"] 		= auxM[1]
		myResultMessage["os_prio"] 				= auxM[2]
		myResultMessage["tid"] 						= auxM[3]
		myResultMessage["nid"] 						= auxM[4]
		myResultMessage["status_thread"] 	= auxM[5]

		myResultMessage["number"] 		= nil
		myResultMessage["deamon"] 		= nil
		myResultMessage["prio"] 			= nil
		myResultMessage["info_mem"] 	= nil
		myResultMessage["info_more"] 	= nil

end


function taskToRun()

		local jPID
		local epochNow
		local timeFile
		local outFile

		jPID = getJPSPID(javaProcessName, jpsFile)

		if (jPID == -1) then

			print(javaProcessName .. " PID not found for jstack")

		else

			epochNow = os.time()
			timeFile = Collector.DateTime.epochToString("%Y-%m-%d_%H-%M-%S", epochNow)[1]
			outFile = jstackFile .. "_" .. timeFile .. ".out"

			myResultMessage["timestamp"] = (epochNow*1000)
			myResultMessage["fileName"] = outFile

			jstack(jPID, outFile)
			processJstackFile(outFile)

		end

end


function OnBeforeStart(config)

	--Code...

	cron 								= config['cron']
	javaProcessName 		= config['javaProcessName']
	jpsFile							= config['jpsFile']
	jstackFile					= config['jstackFile']

	myResultMessage["testRunInfo"]["project"]			= config['project']
	myResultMessage["testRunInfo"]["testRunID"]  	= config['testRunID']
	myResultMessage["testRunInfo"]["valoVersion"] = config['valoVersion']
	myResultMessage["hostname"] = Collector.Network.getHostName()[1]

	regexStandardToFind = "\\\"(.*)\\\" #(\\d+)(\\s\\S*\\s|\\s)prio=(\\d+) os_prio=(\\d+) tid=(\\S*) nid=(\\S*) (.*\\[\\S*\\])\n.*State: (.*)\n"
	regexThreadToFind = "\\\"(.*)\\\" os_prio=(\\d+) tid=(\\S*) nid=(\\S*) (.*)"
	patternStandardResult = Collector.RegEx.createPattern(regexStandardToFind)
	patternThreadResult = Collector.RegEx.createPattern(regexThreadToFind)
	schedulerResult = Collector.Scheduler.createScheduler(taskToRun)

	isRunning = true
	print("The jstack bundle is running in: " .. helperSystemInfo["os-name"] .. "\n")


end


function OnStart()

	Collector.Scheduler.addCronTask(schedulerResult[1], cron)

	while (isRunning)  do
		Collector.DateTime.sleepMilliseconds(100)
	end

end


function OnBeforeStop()
	isRunning = false
	Collector.Scheduler.destroyScheduler(schedulerResult[1])
	Collector.RegEx.destroyPattern(patternResult[1])
end
