--! @file: Entry.lua
--! @brief Fixed file tail monitor
--! @author David Torelli (dtorelli@itrsgroup.com)
--! @copyright ITRS Group all rights reserved.

------------------------------------------------------------------------------------------------------------------------
-- Dependencies
------------------------------------------------------------------------------------------------------------------------
logger       = require "common/Logger"

------------------------------------------------------------------------------------------------------------------------
-- Globals
------------------------------------------------------------------------------------------------------------------------
--! @ Directories containing the files to be monitored
dirs = nil

--! App main loop running status flag
continue_running = true

--! Connector mail box
mailbox = "MSG_VALOLOG"

--! File config from filename
file_from_filename = {}

--! @brief Bundle lifecycle OnStart @see API
--! @param config configuration holding the files to be tailed grouped by directory
function OnBeforeStart(config)

	logger.level = config['logLevelBundle']
	logger.debug(">>> OnBeforeStart <<<")
	logger.trace("Configuring log rollover monitor")

	-- Cache data from configuration
	project			= config['project']
	testRunID  	= config['testRunID']
	valoVersion = config['valoVersion']
	dirs = config['dirs']
	logger.debug(dirs)

	-- Initialise data
	host_name_result = Collector.Network.getHostName()

	-- Iterate on each configuration entry in 'dirs'
	for key_dir,directory in pairs(dirs) do
		logger.debug(directory)

		-- Initialise the directory monitor
		if key_dir ~= nil and directory ~= nil then
			logger.info("Configure directory monitoring " .. directory["path"])

			-- Create the monitor
			directory['monitor'] = {}
			directory.monitor['result'] = {}
			directory.monitor.result = Collector.File.createMonitor(
				1, 		-- our batch size limit will be of 1 events.
				1000, 	-- our timeout will expire in 1 seconds.
				OnTailDetected) -- this is our function.
			if(directory.monitor.result[0] ~= 0) then
				logger.fatal("Could not create monitor for directory " .. directory.path)
				return
			end

			-- Initialise the tailing monitors
			for key_file, file in pairs(directory.files) do
				logger.debug(file)
				if key_file ~= nil and file ~= nil then

					-- Create the Regex for the file and content
					logger.trace("Searching for content matching regex: " .. file["content_regex"])
					file['content_regex_pattern'] = Collector.RegEx.createPattern(file.content_regex)

					-- Initialise the message's configuration
					msg = {

						testRunInfo =
						{
								["project"] = project,
								["testRunID"] = testRunID,
								["valoVersion"] = valoVersion
						},

						["timestamp"] = nil,
						["hostname"] 	= nil
					}
					for idx, field in pairs(file.fields) do
						msg[field] = ""
					end
					file['msg'] = msg
					logger.debug(file.msg)

					-- Initialise decoders list
					file.decoders = {}

					-- Add file config to map
					file_from_filename[directory.path .. file.filename] = file

					--Start tailing on given file regex
					--logger.trace("Monitoring files matching regex: " .. file["filename"])
					logger.info("Configure file monitoring: " .. file["filename"])
					local res = Collector.File.startTailingFile(
							directory.monitor.result[1],    -- our previously obtained monitor-resource-id.
							directory.path .. file.filename,
							true)
					--print("***** startTailingFile with file: " .. directory.path .. file.filename .. " *****" )
					if ( res[0] == 0) then -- the file in which we’re interested.
						logger.info("Start monitoring directory " .. directory.path)
					else
						logger.fatal("Could not start monitoring directory " .. directory.path)
						return
					end

				end
			end
		end
	end
end

--! @brief Bundle lifecycle OnStart @see API
function OnStart()
	logger.debug(">>> OnStart <<<")
	logger.info("File monitor started.")

	-- Main loop
	while continue_running do
		Collector.DateTime.sleepMilliseconds(1000)
	end
end

--! @brief Bundle lifecycle OnBeforeStop @see API
function OnBeforeStop()

	continue_running = false

	logger.debug(">>> OnBeforeStop <<<")
	logger.trace("Log rollover monitor Stopped")

	-- Iterate on each configuration entry in 'dirs'
	logger.trace("Stoping monitors")
	for key_dir,directory in pairs(dirs) do
		logger.debug(directory)
		-- Initialise the directory monitor
		if key_dir ~= nil and directory ~= nil then
			-- Release file resources
			for key_file, file in pairs(directory.files) do
				logger.debug(file)
				if key_file ~= nil and file ~= nil then
					-- Stop tailing
					Collector.File.stopTailingFile(directory.monitor.result[1], directory.path .. file.filename)
					-- Release regex
					Collector.RegEx.destroyPattern(file.content_regex_pattern[1])
				end
			end
			resultDestroy = Collector.File.destroyMonitor(directory.monitor.result[1])
			if (resultDestroy[0] ~= 0) then
				logger.err("Could not destroy monitor: " .. resultDestroy[1])
			end
		end
	end
end

--! @brief Send matching text for the specified file configuration
--! @param filename the filename to search the regex
--! @param file the file configuration object
--! @param content the content to match the regex
function SendMatchingText(file, content)
	logger.debug(">>> SendMatchingText <<<")
	logger.trace("Creating regex " .. file.content_regex)

	-- Create the match regex handler
	local create_match_res = Collector.RegEx.createMatch(content, file.content_regex_pattern[1])
	if(create_match_res[0] ==0) then
		logger.debug("Regex created " .. file.content_regex)

		-- Get next match
		local next_match_result = Collector.RegEx.getNextMatchResult(create_match_res[1])
		while (next_match_result[0] == 0.0) do
			logger.info("Match found on " .. file.filename)

			-- Fill message fields
			file.msg["timestamp"] = (os.time()*1000)
			file.msg["hostname"] = host_name_result[1]
			local count = next_match_result[1]["count"]
			logger.debug(count)
			logger.debug(next_match_result[1]["data"])
			file.msg[file.fields[0]] = next_match_result[1]["data"][0]["string"]

			-- Send the message to the connector
			logger.info("Sending info to " .. mailbox)
			logger.debug(file.msg)
			result = Collector.Connector.send(mailbox, file.msg)
			if result[0] ~= 0 then
				logger.err("Could not send information to end point [" .. mailbox .. "]")
			end
			next_match_result = Collector.RegEx.getNextMatchResult(create_match_res[1])
		end
	else
		logger.err("Could not create matching expression for content in file " .. filename)
	end
	logger.trace("Relesing regex " .. file.content_regex)
	Collector.RegEx.destroyMatch(file.content_regex_pattern[1])
end

--! Callback invoked on tail detected @see API
--! @param number_of_events @see API
--! @param events_table @see API
function OnTailDetected(number_of_events, events_table)

	local file
	local content
	logger.debug(">>> OnTailDetected <<<")
	logger.debug(events_table)

	for event_number, event_info in pairs(events_table) do

		if (event_info["type"] == Collector.Constants.File.EventType.Tail) then

			logger.debug(event_info)
			file = file_from_filename[event_info["filename"]]
			content = event_info["tail-content"]

			if file ~= nil and content then
				SendMatchingText(file, content)
			end

		end

	end

end
