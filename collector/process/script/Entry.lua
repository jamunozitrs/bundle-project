local isRunning
local timeLoop
local processToMonitor
local result

local myResultMessage =
	{

		testRunInfo =
			{
				["project"] 		= nil,
				["testRunID"] 	= nil,
				["valoVersion"] = nil
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

	myResultMessage["testRunInfo"]["project"]			= config['project']
	myResultMessage["testRunInfo"]["testRunID"]  	= config['testRunID']
	myResultMessage["testRunInfo"]["valoVersion"] = config['valoVersion']

	isRunning = true
	print("The process bundle is running")

end

function OnStart()

	myResultMessage["hostname"] = Collector.Network.getHostName()[1]

	while (isRunning)  do

		result = Collector.Process.getProcessesInformation(processToMonitor)

		if result[0] ~= 0 then
			print("error while calling method ('" .. result[1] .. "')")
		else

			for pid, proc_info in pairs(result[1]) do

				myResultMessage["timestamp"] = (os.time()*1000)
				myResultMessage["pid"] = pid
				myResultMessage["name"] = proc_info["name"]
				myResultMessage["memory"] = proc_info["memory"]
				myResultMessage["cpu"] = (proc_info["cpu-percentage"]*100)

				result = Collector.Connector.send("MSG_PROCESS", myResultMessage)
				if result[0] ~= 0 then
					print("error while calling method ('" .. result[1] .. "')")
				end

			end

		end

		Collector.DateTime.sleepMilliseconds(timeLoop)

	end

end

function OnBeforeStop()

	isRunning = false

end
