local isRunning
local timeLoop
local processToMonitor
local sampleInterval
local hostname
local result

local process_table = {}


local myResultMessage =
	{

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
	timeLoop = config['timeLoopMilli']
	processToMonitor = config['process']
	sampleInterval = config['sampleInterval']

	if sampleInterval == nil then
		sampleInterval = 100
	end

	myResultMessage["testRunInfo"]["project"]			= config['project']
	myResultMessage["testRunInfo"]["testRunID"]  	= config['testRunID']
	myResultMessage["testRunInfo"]["valoVersion"] = config['valoVersion']
	myResultMessage["testRunInfo"]["collectorVersion"] = Collector.Core.getBundleInformation()[1]["collector-version"]

	isRunning = true
	print("The process bundle is running")

end


function OnStart()

	hostname = Collector.Network.getHostName()

	if hostname[0] == 0 then

		myResultMessage["hostname"] = hostname[1]

		while (isRunning)  do

			process_table[1] = processToMonitor
			result = Collector.Process.getProcessesInformation(process_table, sampleInterval)

			if result[0] ~= 0 then
				print("[PROCESS][getProcessesInformation] error while calling method ('" .. result[1] .. "')")
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
							print("[PROCESS][send] error while calling method ('" .. result[1] .. "')")
						end

					end

				end

			end

			Collector.DateTime.sleepMilliseconds(timeLoop)

		end

	else

		print("[PROCESS][getHostName] error while calling method ('" .. hostname[1] .. "')")

	end

end


function OnBeforeStop()

	isRunning = false

end
