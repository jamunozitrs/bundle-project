
local isRunning
local counter
local counterEnd
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
		["counter"] 	= nil,

	}


function OnBeforeStart(config)

	--Code...
	timeLoop 		= config['timeLoopMilli']
	counterEnd 	= config['counterEnd']

	myResultMessage["testRunInfo"]["project"]			= config['project']
	myResultMessage["testRunInfo"]["testRunID"]  	= config['testRunID']
	myResultMessage["testRunInfo"]["valoVersion"] = config['valoVersion']

	isRunning = true

	print("This bundle is counterWithEnd")
	print("Must stop with counter  = " .. counterEnd)

end

function OnStart()

	hostNameResult = Collector.Network.getHostName()
	counter = 1.0

	if hostNameResult[0] ~= 0 then
		print("error while calling method ('" .. hostNameResult[1] .. "')")
	else

		while (counter <= counterEnd)  do

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

	print("This bundle will be stoped")
	isRunning = false

end
