
local isRunning
local counter
local timeLoop
local hostNameResult
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
		["counter"] 	= nil

	}


function OnBeforeStart(config)

	--Code...
	timeLoop 	= config['timeLoopMilli']

	myResultMessage["testRunInfo"]["project"]			= config['project']
	myResultMessage["testRunInfo"]["testRunID"]  	= config['testRunID']
	myResultMessage["testRunInfo"]["valoVersion"] = config['valoVersion']

	isRunning = true
	print("The counter bundle is running")

end

function OnStart()

	hostNameResult = Collector.Network.getHostName()
	counter = 1.0

	if hostNameResult[0] ~= 0 then
		print("error while calling method ('" .. hostNameResult[1] .. "')")
	else

		while (isRunning)  do

			myResultMessage["timestamp"] = os.time()*1000
			myResultMessage["hostname"] = hostNameResult[1]
			myResultMessage["counter"] = counter

			result = Collector.Connector.send("MSG_COUNTER", myResultMessage)
			if result[0] ~= 0 then
				print("error while calling method ('" .. result[1] .. "')")
			end

			counter = counter+1

			Collector.DateTime.sleepMilliseconds(timeLoop)

		end

	end

end

function OnBeforeStop()

	isRunning = false

end
