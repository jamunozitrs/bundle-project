local helperFile = require('common/HelperFile')

local isRunning
local counter
local hostNameResult
local cpuResult
local memoryResult
local resultSend
local timeLoop
local file

local myResultMessage =
	{

		testRunInfo =
			{
				["project"] 		= "",
				["testRunID"] 	= "",
				["valoVersion"] = ""
			},

		["counter"] 	= "",
		["timestamp"] = "",
		["hostname"] 	= "",
		["cpu_global_percent"] 	= "",
		["mem_global_percent"] 	= "",
		["mem_total_physical"] 	= "",
		["mem_free_physical"] 	= "",
		["mem_total_paging"] 		= "",
		["mem_free_paging"] 		= "",
		["mem_total_virtual"] 	= "",
		["mem_free_virtual"] 		= "",
		["mem_free_extended"] 	= ""
	}

function OnBeforeStart(config)

	--Code...
	timeLoop = config['timeLoopMilli']
	csvPath = config['csvPath']

	myResultMessage["testRunInfo"]["project"]			= config['project']
	myResultMessage["testRunInfo"]["testRunID"]  	= config['testRunID']
	myResultMessage["testRunInfo"]["valoVersion"] = config['valoVersion']

	isRunning = true

end

function OnStart()

	counter = 1
	writeHeadCSV(myResultMessage, csvPath)

	while (isRunning)  do

		hostNameResult = Collector.Network.getHostName()
		cpuResult = Collector.Process.getGlobalCpuUsage()
		memoryResult = Collector.Process.getGlobalMemoryUsage()

		myResultMessage["counter"] = counter
		myResultMessage["timestamp"] = (os.time() * 1000)
		myResultMessage["hostname"] = hostNameResult[1]
		myResultMessage["cpu_global_percent"] = (cpuResult * 100)
		myResultMessage["mem_global_percent"] = (memoryResult[1]["memory-usage"] * 100)
		myResultMessage["mem_total_physical"] = memoryResult[1]["total-physical"]
		myResultMessage["mem_free_physical"] = memoryResult[1]["free-physical"]
		myResultMessage["mem_total_paging"] = memoryResult[1]["total-paging"]
		myResultMessage["mem_free_paging"] = memoryResult[1]["free-paging"]
		myResultMessage["mem_total_virtual"] = memoryResult[1]["total-virtual"]
		myResultMessage["mem_free_virtual"] = memoryResult[1]["free-virtual"]
		myResultMessage["mem_free_extended"] = memoryResult[1]["free-extended"]

		resultSend = Collector.Connector.send("MSG_CPUMEM", myResultMessage)
		if resultSend[0] ~= 0 then
			print("error while calling method ('" .. resultSend[1] .. "')")
		end

		writeBodyCSV(myResultMessage, csvPath)

		Collector.DateTime.sleepMilliseconds(timeLoop)
		counter = counter+1

	end

end

function OnBeforeStop()

	isRunning = false

end
