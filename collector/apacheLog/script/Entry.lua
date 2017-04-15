--! @file: apachemonitor.lua
--! @brief Fixed file tail monitor
--! @author David Torelli (dtorelli@itrsgroup.com)
--! @copyright ITRS Group all rights reserved.

------------------------------------------------------------------------------------------------------------------------
-- Dependencies
------------------------------------------------------------------------------------------------------------------------
datacomposer = require "common/Datacomposer"
logger       = require "common/Logger"

------------------------------------------------------------------------------------------------------------------------
-- Globals
------------------------------------------------------------------------------------------------------------------------
--! @ Directories containing the files to be monitored
dirs = nil

--! App main loop running status flag
continue_running = true

--! Connector mail box
mailbox = "MSG_APACHE"

--! File config from filename
file_from_filename = {}

--! @brief Bundle lifecycle OnStart @see API
--! @param config configuration holding the files to be tailed grouped by directory
function OnBeforeStart(config)
	--logger.level = logger.kInfo
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

			-- Run the monitor
			local directory_monitoring_result = Collector.File.startMonitoringDirectory(
				directory.monitor.result[1],
				directory.path,
				Collector.Constants.File.EventType.Added |
				Collector.Constants.File.EventType.Modified )
			if directory_monitoring_result[0] ~= 0 then
				logger.fatal("error while calling method ('" .. directory_monitoring_result[1] .. "')")
				return
			end

			-- Initialise the tailing monitors
			for key_file, file in pairs(directory.files) do
				logger.debug(file)
				if key_file ~= nil and file ~= nil then
					-- Start tailing on given file regex
					logger.trace("Monitoring files matching regex: " .. file["filename"])
					local res = Collector.File.startTailingFile(
							directory.monitor.result[1],    -- our previously obtained monitor-resource-id.
							file.filename,
							true)
					if ( res[0] == 0) then -- the file in which we’re interested.
						logger.info("Start monitoring directory " .. directory.path)
					else
						logger.fatal("Could not start monitoring directory " .. directory.path)
						return
					end

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
					file_from_filename[file.filename] = file
				end
			end
		end
	end
end

--! @brief Bundle lifecycle OnStart @see API
function OnStart()
	logger.debug(">>> OnStart <<<")
	logger.info("Tailing monitor started.")

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
					Collector.File.stopTailingFile(directory.monitor.result[1], file.filename)
					-- Release regex
					Collector.RegEx.destroyPattern(file.content_regex_pattern[1])
				end
			end
			Collector.File.destroyMonitor(directory.monitor.result[1])
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
			for i = 0, count-2, 1 do
				file.msg[file.fields[i]] = next_match_result[1]["data"][i]["string"]
				logger.trace("'" .. next_match_result[1]["data"][i]["string"] ..
					  "' , at[" .. next_match_result[1]["data"][i]["position"] .. "]")
			end

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
	logger.debug(">>> OnTailDetected <<<")
	logger.debug(events_table)
	for event_number, event_info in pairs(events_table) do
		logger.debug(event_info)
		filename = event_info["filename"]
		chunk_count = event_info["chunk-count"]
		chunk_id = event_info["chunk-id"]
		content = event_info["tail-content"]

		-- Process chunk if all inputs are ok
		if filename and chunk_count and chunk_id and content then
			-- Check file is being monitored
			local file = file_from_filename[filename]
			if file ~= nil then
				logger.trace("Checking file ...")
				logger.debug(file)
				local data = datacomposer.add(event_info["tail-parent-code"], chunk_count, chunk_id, content)
				if data ~= nil then
					SendMatchingText(file, data)
				end
			else
				logger.err("File is not being monitored")
			end
		else
			logger.debug("Cannot process chunk! inputs not found (filename, tail-content, chunk_id, chunk_count")
		end
	end
end
