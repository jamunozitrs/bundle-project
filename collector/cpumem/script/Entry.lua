local isRunning
local counter
local hostNameResult
local cpuResult
local memoryResult
local result
local timeLoop

local myResultMessage =
	{

		testRunInfo =
			{
				["project"] 		= nil,
				["testRunID"] 	= nil,
				["valoVersion"] = nil
			},

		["counter"] 	= nil,
		["timestamp"] = nil,
		["hostname"] 	= nil,
		["cpu_global_percent"] 	= nil,
		["mem_global_percent"] 	= nil,
		["mem_total_physical"] 	= nil,
		["mem_free_physical"] 	= nil,
		["mem_total_paging"] 		= nil,
		["mem_free_paging"] 		= nil,
		["mem_total_virtual"] 	= nil,
		["mem_free_virtual"] 		= nil,
		["mem_free_extended"] 	= nil
	}

function OnBeforeStart(config)

	--Code...
	timeLoop = config['timeLoopMilli']

	myResultMessage["testRunInfo"]["project"]			= config['project']
	myResultMessage["testRunInfo"]["testRunID"]  	= config['testRunID']
	myResultMessage["testRunInfo"]["valoVersion"] = config['valoVersion']

	isRunning = true
	print("The cpumem bundle is running")

end

function OnStart()

	counter = 1

	while (isRunning)  do

		hostNameResult = Collector.Network.getHostName()
		cpuResult = Collector.Process.getGlobalCpuUsage()
		memoryResult = Collector.Process.getGlobalMemoryUsage()

		myResultMessage["counter"] 		= counter
		myResultMessage["timestamp"] 	= (os.time()*1000)
		myResultMessage["hostname"] 	= hostNameResult[1]
		myResultMessage["cpu_global_percent"] = cpuResult * 100
		myResultMessage["mem_global_percent"] = memoryResult[1]["memory-usage"] * 100
		myResultMessage["mem_total_physical"] = memoryResult[1]["total-physical"]
		myResultMessage["mem_free_physical"] 	= memoryResult[1]["free-physical"]
		myResultMessage["mem_total_paging"] 	= memoryResult[1]["total-paging"]
		myResultMessage["mem_free_paging"] 		= memoryResult[1]["free-paging"]
		myResultMessage["mem_total_virtual"]	= memoryResult[1]["total-virtual"]
		myResultMessage["mem_free_virtual"] 	= memoryResult[1]["free-virtual"]
		myResultMessage["mem_free_extended"] 	= memoryResult[1]["free-extended"]

		result = Collector.Connector.send("MSG_CPUMEM", myResultMessage)
		if result[0] ~= 0 then
			print("error while calling method ('" .. result[1] .. "')")
		end

		Collector.DateTime.sleepMilliseconds(timeLoop)
		counter = counter+1

	end

end

function OnBeforeStop()
	isRunning = false
end
