
local isRunning
local counter
local text
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
		["text"] 			= nil

	}


function OnBeforeStart(config)

	--Code...
	timeLoop 		= config['timeLoopMilli']
	counterEnd 	= config['counterEnd']

	myResultMessage["testRunInfo"]["project"]			= config['project']
	myResultMessage["testRunInfo"]["testRunID"]  	= config['testRunID']
	myResultMessage["testRunInfo"]["valoVersion"] = config['valoVersion']

	isRunning = true

	print("This bundle is bundleWithEnd")
	print("Must stop with counter  = " .. counterEnd)

end

function OnStart()

	hostNameResult = Collector.Network.getHostName()
	counter = 1.0
	text = "This is a test text..."
	textSend = text


	if hostNameResult[0] ~= 0 then
		print("error while calling method ('" .. hostNameResult[1] .. "')")
	else

		while (counter <= counterEnd)  do

			myResultMessage["timestamp"] = os.time()*1000
			myResultMessage["hostname"] = hostNameResult[1]
			myResultMessage["counter"] = counter
			myResultMessage["text"] = textSend

			result = Collector.Connector.send("MSG_PERFORMANCE", myResultMessage)
			if result[0] ~= 0 then
				print("error while calling method ('" .. result[1] .. "')")
			end

			counter = counter+1
			textSend = textSend .. text

			Collector.DateTime.sleepMilliseconds(timeLoop)

		end

	end

end

function OnBeforeStop()

	print("This bundle will be stoped")
	isRunning = false

end
