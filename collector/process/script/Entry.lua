local logger = require "common/Logger"

local isRunning
local timeLoop
local processToMonitor
local sampleInterval
local hostname
local systemInfo
local bundleInfo
local result
local processTable = {}


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

		["timestamp"] = nil,
		["hostname"] 	= nil,
		["name"] 			= nil,
		["pid"] 			= nil,
		["cpu"] 			= nil,
		["memory"] 		=	nil
	}


function OnBeforeStart(config)

	--Code...

	logger.level = config['logLevelBundle']

	if (logger.level == nil or logger.level < 1 or logger.level > 6) then
		logger.level = 4
	end

	timeLoop = config['timeLoopMilli']
	processToMonitor = config['process']
	sampleInterval = config['sampleInterval']

	if sampleInterval == nil then
		sampleInterval = 100
	end

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
	logger.info("[PROCESS][OnBeforeStart] The process bundle is running on " .. systemInfo[1]["os-name"])

end


function OnStart()

	hostname = Collector.Network.getHostName()

	if hostname[0] == 0 then

		myResultMessage["hostname"] = hostname[1]

		while (isRunning)  do

			processTable[1] = processToMonitor
			result = Collector.Process.getProcessesInformation(processTable, sampleInterval)

			if result[0] ~= 0 then
				logger.err("[PROCESS][getProcessesInformation] error while calling method ('" .. result[1] .. "')")
			else

				for pid, proc_info in pairs(result[1]) do

					if pid > 0 then

						myResultMessage["timestamp"] = (os.time()*1000)
						myResultMessage["pid"] = pid
						myResultMessage["name"] = proc_info["name"]
						myResultMessage["memory"] = proc_info["ram-usage"]
						myResultMessage["cpu"] = (proc_info["cpu-percentage"])

						result = Collector.Connector.send("MSG_PROCESS", myResultMessage)
						if result[0] ~= 0 then
							logger.err("[PROCESS][send] error while calling method ('" .. result[1] .. "')")
						end

					end

				end

			end

			Collector.DateTime.sleepMilliseconds(timeLoop)

		end

	else
		logger.err("[PROCESS][getHostName] error while calling method ('" .. hostname[1] .. "')")
	end

end


function OnBeforeStop()

	isRunning = false
	logger.info("[PROCESS][OnBeforeStop] The process bundle is closing")

end
