--! @file logger.lua
--! @brief logger helper class that prints out typical log coloured information
--!        with severity, date and message.
--! @author David Torelli (dtorelli@itrsgroup.com)
--! @copyright ITRS Group all rights reserved.

------------------------------------------------------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------------------------------------------------------

--! @brief convert value into string
function table.val_to_str ( v )
  if "string" == type( v ) then
    v = string.gsub( v, "\n", "\\n" )
    if string.match( string.gsub(v,"[^'\"]",""), '^"+$' ) then
      return "'" .. v .. "'"
    end
    return '"' .. string.gsub(v,'"', '\\"' ) .. '"'
  else
    return "table" == type( v ) and table.tostring( v ) or
      tostring( v )
  end
end

--! @brief trasnform key into string
--! @param k key to stringify
--! @return key serialised into string format
function table.key_to_str ( k )
  if "string" == type( k ) and string.match( k, "^[_%a][_%a%d]*$" ) then
    return k
  else
    return "[" .. table.val_to_str( k ) .. "]"
  end
end

--! @brief trasnform table into string
--! @param tbl table to stringify
--! @return table serialised into string format
function table.tostring( tbl )
  local result, done = {}, {}
  for k, v in ipairs( tbl ) do
    table.insert( result, table.val_to_str( v ) )
    done[ k ] = true
  end
  for k, v in pairs( tbl ) do
    if not done[ k ] then
      table.insert( result,
        table.key_to_str( k ) .. "=" .. table.val_to_str( v ) )
    end
  end
  return "{" .. table.concat( result, "," ) .. "}"
end

------------------------------------------------------------------------------------------------------------------------
-- Globals
------------------------------------------------------------------------------------------------------------------------

--! @brief This is the logger module, and is in charge of providing log capabilities to console assigning colors to
--!        the different log severity levels.
--!        You can specify the log level to be printed out to console by setting the logger.level to any of the
--!        available levels (kFatal, kErr, kWarn, kInfo, kWarn, kTrace and kDebug)
--! @code lua
--! logger = require(logger)
--! logger.debug("This is a debug trace")
--! logger.trace("This is a simple trace")
--! logger.info("This is an information trace")
--! logger.warn("This is a warning trace")
--! logger.err("This is an errpr trace")
--! logger.fatal("This is a fatal trace")
--! @endcode
local logger = {
	['kFatal'] = 1,
	['kErr']   = 2,
	['kWarn']  = 3,
	['kInfo']  = 4,
	['kTrace'] = 5,
	['kDebug'] = 6
}

--! Init trace level to Trace by default
logger.level = logger.kDebug

------------------------------------------------------------------------------------------------------------------------
-- Locals
------------------------------------------------------------------------------------------------------------------------

--! Log level to string map 
local kSeverityString = {
	[logger.kDebug] = "DEBUG",
	[logger.kTrace] = "TRACE",
	[logger.kInfo]  = "INFO",
	[logger.kWarn]  = "WARN",
	[logger.kErr]   = "ERROR",
	[logger.kFatal] = "FATAL",
}

--! Log level to color map
local kSeverityColor = {
	[logger.kDebug] = Collector.Constants.Console.ForegroundColor.Gray,
	[logger.kTrace] = Collector.Constants.Console.ForegroundColor.White,
	[logger.kInfo]  = Collector.Constants.Console.ForegroundColor.Green,
	[logger.kWarn]  = Collector.Constants.Console.ForegroundColor.Yellow,
	[logger.kErr]   = Collector.Constants.Console.ForegroundColor.Red,
	[logger.kFatal] = Collector.Constants.Console.ForegroundColor.Red,
}

--! @brief Prints a line to console
--! @param sev: The severity (@see kDebug, kInfo, ...)
--! @param msg: The content of the message to be printed out
function logger.log ( sev, msg )
	-- Discard non declared log severities
	if(sev > logger.kDebug) then
		return
	end 
	if(sev < logger.kFatal) then
		return
	end
	
	-- Discard severity message with lower priority than configured
	if sev > logger.level then
		return
	end

	-- Transform table to string
	if(type(msg) == "table") then
		msg = table.tostring(msg)
	end

	-- Create log trace
	local log_msg = "[" .. kSeverityString[sev] .. "]\t" 
						.. os.date("%Y/%m/%d %H:%M:%S") .. "\t" .. msg .. "\n"
	
	-- Print out a formatted message!
	local result = Collector.Console.print(kSeverityColor[sev], log_msg)
	if result[0] ~= 0 then
		print("Error printing out to console ('" .. result[1] .. "')")
	end
end

--! @brief Prints a debug trace
--! @param msg the message to be printed
logger.debug = function (msg) logger.log(logger.kDebug, msg) end

--! @brief Prints a simple trace
--! @param msg the message to be printed
logger.trace = function (msg) logger.log(logger.kTrace, msg) end

--! @brief Prints an information trace
--! @param msg the message to be printed
logger.info = function (msg) logger.log(logger.kInfo, msg) end

--! @brief Prints a warning trace
--! @param msg the message to be printed
logger.warn = function (msg) logger.log(logger.kWarn, msg) end

--! @brief Prints an error trace
--! @param msg the message to be printed
logger.err = function (msg) logger.log(logger.kErr, msg) end

--! @brief Prints a fatal error trace
--! @param msg the message to be printed
logger.fatal = function (msg) logger.log(logger.kFatal, msg) end

-- Return the module instance
return logger