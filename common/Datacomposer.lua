--! @file: datacomposer
--! @brief The purpose of this module is to collect chunks of information and return it as a whole piece of data
--!        when all of the chunks are collected. The chunks can be received with no ordering and thus, every chunk
--!        will hold a chunk numeric identifier indicating the ordering position (from 0.0 to N).
--! @author David Torelli (dtorelli@itrsgroup.com)
--! @copyright ITRS Group all rights reserved.

------------------------------------------------------------------------------------------------------------------------
-- Dependencies
------------------------------------------------------------------------------------------------------------------------
logger = require "common/Logger"

------------------------------------------------------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------
-- Locals
------------------------------------------------------------------------------------------------------------------------

--! @brief The purpose of this module is to collect chunks of information and return it as a whole piece of data
--!        when all of the chunks are collected. The chunks can be received with no ordering and thus, every chunk
--!        will hold a chunk numeric identifier indicating the ordering position (from 0.0 to N).
--!        Note that every collection of chunks will be also followed by the data identifier (e.g. filename, uri, ...)
--!        To use this module, just invoke the add method providing the data identifier, the total number of chunks for
--!        the data, the chunk identifier for the given chunk and the chunk it self (@see add).
--! @code lua
--! datacomposer = require(datacomposer)
--!
--! logger.info("Testing ordered chunks")
--! datacomposer.add("file.txt", 3.0, 0.0, "Hello")
--! datacomposer.add("file.txt", 3.0, 1.0, " lua ")
--! assert(datacomposer.add("file.txt", 3.0, 2.0, "rocks!") == "Hello lua rocks!", "Ordered chunks failed!")
--!
--! logger.info("Testing unordered chunks")
--! datacomposer.add("file.txt", 3.0, 2.0, "rocks!")
--! datacomposer.add("file.txt", 3.0, 1.0, " lua ")
--! assert(datacomposer.add("file.txt", 3.0, 0.0, "Hello") == "Hello lua rocks!", "Unordered chunks failed!")
--! @endcode
local datacomposer = {}

------------------------------------------------------------------------------------------------------------------------
-- Globals
------------------------------------------------------------------------------------------------------------------------

--! Data composers map organised by data_id
composers = {}

--! @brief add chunk to given data identifier and return full data if it is complete.
--! @param data_id the data identifier.
--! @param chunk_count the num of chunks for
--! @param chunk_id
--! @param content
--! @return This method returns the full data composed for the given data_id when all data is ready,
--!         in the case of missing chunks nil will be returned.
function datacomposer.add(data_id, chunk_count, chunk_id, content)
	logger.debug(">>> datacomposer.add <<<")

	-- Create new composer if no match for the given data identifier
	local composer = composers[data_id]
	if composer == nil then
		composer = {
			['chunk_count'] = chunk_count,
			['chunks'] = {},
			['chunks_received'] = 0
		}
		logger.trace("New composer for data " .. data_id)
		composers[data_id] = composer
	end

	-- Add the chunk to the composer
	logger.trace("Adding chunk " .. chunk_id .. " for " .. data_id)
	composer.chunks[tostring(chunk_id)] = content
	composer.chunks_received = composer.chunks_received + 1
	logger.debug(composer)

	-- Check for data completed
	if composer.chunks_received == composer.chunk_count then
		logger.trace("All chunks received")
		logger.debug(composer.chunks)

		-- Compose the data in order (by chunk id)
		ordered_data = {}
		for chunk_id = 0.0, composer.chunk_count, 1.0 do
			table.insert(ordered_data, composer.chunks[tostring(chunk_id)])
		end
		local data = table.concat(ordered_data)
		logger.debug("data: " .. data)

		-- Release the composer and return the data
		composers[data_id] = nil
		return data
	end

	return nil
end

------------------------------------------------------------------------------------------------------------------------
-- Tests
------------------------------------------------------------------------------------------------------------------------

-- Ordered chunks
-- logger.info("Testing ordered chunks")
-- composers = {}
-- datacomposer.add("file.txt", 3.0, 0.0, "Hello")
-- datacomposer.add("file.txt", 3.0, 1.0, " lua ")
-- assert(datacomposer.add("file.txt", 3.0, 2.0, "rocks!") == "Hello lua rocks!", "Ordered chunks failed!")

-- Unordered chunks
-- logger.info("Testing unordered chunks")
-- composers = {}
-- datacomposer.add("file.txt", 3.0, 2.0, "rocks!")
-- datacomposer.add("file.txt", 3.0, 1.0, " lua ")
-- assert(datacomposer.add("file.txt", 3.0, 0.0, "Hello") == "Hello lua rocks!", "Unordered chunks failed!")

-- Missing chunk
-- logger.info("Testing missing chunk")
-- composers = {}
-- datacomposer.add("file.txt", 3.0, 2.0, "rocks!")
-- assert(datacomposer.add("file.txt", 3.0, 1.0, " lua ") == nil, "Missing chunk failed!")

--! Return module
return datacomposer
