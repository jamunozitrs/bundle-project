local logger = require "common/Logger"

local isRunning
local counter
local hostNameResult
local cpuResult
local memoryResult
local result
local timeLoop

local myResultMessage =
	{

		osInfo =
			{
				["name"] 					= nil,
				["version"] 			= nil,
				["description"] 	= nil,
				["architecture"] 	= nil
			},

		testRunInfo =
			{
				["project"] 		= nil,
				["testRunID"] 	= nil,
				["valoVersion"] = nil,
				["collectorVersion"] = nil
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

	logger.level = config['logLevelBundle']

	if (logger.level == nil or logger.level < 1 or logger.level > 6) then
		logger.level = 4
	end

	timeLoop = config['timeLoopMilli']

	myResultMessage["testRunInfo"]["project"]			= config['project']
	myResultMessage["testRunInfo"]["testRunID"]  	= config['testRunID']
	myResultMessage["testRunInfo"]["valoVersion"] = config['valoVersion']

	bundleInfo = Collector.Core.getBundleInformation()
	if bundleInfo[0] == 0 then
		myResultMessage["testRunInfo"]["collectorVersion"] = bundleInfo[1]["collector-version"]
	else
		logger.err("[PROCESS][getBundleInformation] error while calling method ('" .. bundleInfo[1] .. "')")
	end

	systemInfo = Collector.Core.getSystemInformation()
	if systemInfo[0] == 0 then
		myResultMessage["osInfo"]["name"] = systemInfo[1]["os-name"]
		myResultMessage["osInfo"]["description"] = systemInfo[1]["os-description"]
		myResultMessage["osInfo"]["version"] = systemInfo[1]["os-version"]
		myResultMessage["osInfo"]["architecture"] = systemInfo[1]["architecture"]
	else
		logger.err("[PROCESS][getSystemInformation] error while calling method ('" .. systemInfo[1] .. "')")
	end

	isRunning = true
	logger.info("[CPUMEM][OnBeforeStart] The cpumem bundle is running on " .. systemInfo[1]["os-name"])

end

function OnStart()

	counter = 1

	hostNameResult = Collector.Network.getHostName()

	if hostNameResult[0] == 0 then

		while (isRunning)  do

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
				logger.err("[CPUMEM][send] error while calling method ('" .. result[1] .. "')")
			end

			Collector.DateTime.sleepMilliseconds(timeLoop)
			counter = counter+1

		end

	else
		logger.err("[CPUMEM][getHostName] error while calling method ('" .. hostNameResult[1] .. "')")
	end

end

function OnBeforeStop()
	isRunning = false
	logger.info("[CPUMEM][OnBeforeStop] The cpumem bundle is closing")
end
