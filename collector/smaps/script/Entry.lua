local helperFile = require('common/HelperFile')
local helperString = require('common/HelperString')
local helperSystemInfo = require('common/HelperSystemInfo')

local isRunning
local cron
local formatDate
local javaProcessName
local jpsFile
local smapsFile

local patternResult
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

		addressInfo =
			{
				["ID"] 				= nil,
				["perms"] 		= nil,
				["offset"] 		= nil,
				["dev"] 			= nil,
				["inode"] 		= nil,
				["pathname"] 	= nil
			},

		["Size"] 	= nil,
		["Rss"] 	= nil,
		["Pss"] 	= nil,
		["Shared_Clean"] 		= nil,
		["Shared_Dirty"] 		= nil,
		["Private_Clean"] 	= nil,
		["Private_Dirty"] 	= nil,
		["Referenced"] 			= nil,
		["Anonymous"] 			= nil,
		["AnonHugePages"] 	= nil,
		["Shared_Hugetlb"] 	= nil,
		["Private_Hugetlb"] = nil,
		["Swap"] 						= nil,
		["SwapPss"] 				= nil,
		["KernelPageSize"] 	= nil,
		["MMUPageSize"] 		= nil,
		["Locked"] 					= nil,
		["VmFlags"] 				= nil

	}


function processSmapsFile(fileName)

	local linesFromFile
	local tokens
	local resultSend
	local k,v,subv
	local sendMessage

	sendMessage = false
	linesFromFile = lines_from(fileName)

	i = 1
	while (linesFromFile[i]~=nil) do

		tokens = Collector.String.tokenize(linesFromFile[i], ": ")

		if (tokens[1][0] ~=nil) then

			k = tokens[1][0]
			v = tokens[1][1]

			if ( k == "VmFlags") then
				myResultMessage[trim(k)] =  trim(v)
				sendMessage = true
			else
				subv = string.sub(v,1,-3)
				myResultMessage[trim(k)] = trim(subv)
			end

		else

			regexAux = regexFind(linesFromFile[i], patternResult[1])

			myResultMessage["addressInfo"]["ID"] = regexAux[1]
			myResultMessage["addressInfo"]["perms"] = regexAux[2]
			myResultMessage["addressInfo"]["offset"] = regexAux[3]
			myResultMessage["addressInfo"]["dev"] = regexAux[4]
			myResultMessage["addressInfo"]["inode"] = regexAux[5]
			myResultMessage["addressInfo"]["pathname"] = regexAux[6]

		end

		if sendMessage then
			resultSend = Collector.Connector.send("MSG_SMAPS", myResultMessage)
			if resultSend[0] ~= 0 then
				print("error while calling send method ('" .. resultSend[1] .. "')")
			end
			sendMessage = false
		end

		i=i+1

	end

end


function taskToRun()

	local jPID
	local epochNow
	local timeFile
	local outFile

	jPID = getJPSPID(javaProcessName, jpsFile)

	if (jPID == -1) then
		print(javaProcessName .. " PID not found for smaps")
	else
		epochNow = os.time()
		timeFile = Collector.DateTime.epochToString("%Y-%m-%d_%H-%M-%S", epochNow)[1]
		outFile = smapsFile .. "_" .. timeFile .. ".out"

		myResultMessage["timestamp"] = (epochNow*1000)
		myResultMessage["fileName"] = outFile

		smaps(jPID, outFile)
		processSmapsFile(outFile)
	end

end


function OnBeforeStart(config)

	--Code...
	cron 						= config['cron']
	formatDate 			= config['formatDate']
	javaProcessName = config['javaProcessName']
	jpsFile					= config['jpsFile']
	smapsFile				= config['smapsFile']

	myResultMessage["testRunInfo"]["project"]			= config['project']
	myResultMessage["testRunInfo"]["testRunID"]  	= config['testRunID']
	myResultMessage["testRunInfo"]["valoVersion"] = config['valoVersion']
	myResultMessage["hostname"] = Collector.Network.getHostName()[1]

	patternResult = Collector.RegEx.createPattern("(\\S*) (\\S*) (\\S*) (\\S*) (\\S*)\\s*(\\S*)")
	schedulerResult = Collector.Scheduler.createScheduler(taskToRun)

	isRunning = true
	print("The smaps bundle is running in: " .. helperSystemInfo["os-name"] .. "\n")

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
