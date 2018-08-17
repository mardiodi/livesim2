-- Live Simulator: 2 binary beatmap loader
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local Luaoop = require("libs.Luaoop")
local love = require("love")
local ls2 = require("libs.ls2")
local util = require("util")
local baseLoader = require("game.beatmap.base")

------------------------------
-- Setup LS2 Stream Wrapper --
------------------------------
ls2.setstreamwrapper {
	read = function(stream, val)
		return (stream:read(assert(val)))
	end,
	write = function(stream, data)
		return stream:write(data)
	end,
	seek = function(stream, whence, offset)
		local set = 0

		if whence == "cur" then
			set = stream:tell()
		elseif whence == "end" then
			set = stream:getSize()
		elseif whence ~= "set" then
			error("Invalid whence")
		end

		stream:seek(set + (offset or 0))
		return stream:tell()
	end
}

-----------------------
-- LS2 Beatmap Class --
-----------------------

local ls2Loader = Luaoop.class("beatmap.LS2", baseLoader)

function ls2Loader:__construct(file)
	local internal = ls2Loader^self
	internal.ls2 = ls2.loadstream(file)
	internal.file = file
end

function ls2Loader:getFormatName()
	local internal = ls2Loader^self
	return string.format("Live Simulator: 2 v%s Beatmap", internal.ls2.version_2 and "2.0" or "1.x"), "ls2"
end

function ls2Loader:getNotesList()
	local internal = ls2Loader^self
	local nlist = {}

	-- Select and process BMPM and BMPT sections
	-- We don't have to check if notes data were
	-- empty or not, since it's already handled when
	-- loading the beatmap file.
	if internal.ls2.sections.BMPM then
		for _, v in ipairs(internal.ls2.sections.BMPM) do
			local notes_data

			internal.file:seek(v)
			notes_data = ls2.section_processor.BMPM[1](internal.file, internal.ls2.version_2)

			for _, n in ipairs(notes_data) do
				nlist[#nlist + 1] = n
			end
		end
	end

	if internal.ls2.sections.BMPT then
		for _, v in ipairs(internal.ls2.sections.BMPT) do
			local notes_data

			internal.file:seek(v)
			notes_data = ls2.section_processor.BMPT[1](internal.file, internal.ls2.version_2)

			for _, n in ipairs(notes_data) do
				nlist[#nlist + 1] = n
			end
		end
	end

	table.sort(nlist, function(a, b) return a.timing_sec < b.timing_sec end)
	return nlist
end

function ls2Loader:_getMetadata()
	local internal = ls2Loader^self

	if not(internal.metadata) then
		if internal.ls2.sections.MTDT then
			internal.file:seek(internal.ls2.sections.MTDT[1])
			internal.metadata = ls2.section_processor.MTDT[1](internal.file, internal.ls2.version_2)
		else
			internal.metadata = {}
		end
	end

	return assert(internal.metadata)
end

function ls2Loader:getName()
	local metadata = self:_getMetadata()

	if metadata.name then
		return metadata.name
	end

	local cover = self:getCoverArt()
	if cover and cover.title then
		return cover.title
	end

	return nil
end

function ls2Loader:getCoverArt()
	local internal = ls2Loader^self

	if not(internal.coverArtLoaded) then
		if internal.ls2.sections.COVR then
			internal.file:seek(internal.ls2.sections.COVR[1])
			internal.coverArt = ls2.section_processor.COVR[1](internal.file, internal.ls2.version_2)
			internal.coverArt.image = love.filesystem.newFileData(internal.coverArt.image, "")
		end
		internal.coverArtLoaded = true
	end

	return internal.coverArt
end

function ls2Loader:getScoreInformation()
	local internal = ls2Loader^self
	local metadata = self:_getMetadata()

	-- Try to get from metadata first (v1 or v2)
	if internal.ls2.version_2 or metadata.score then
		return metadata.score
	-- For version 1 (only), get from SCRI
	elseif internal.ls2.sections.SCRI and internal.ls2.sections.SCRI[1] then
		internal.file:seek(internal.ls2.sections.SCRI[1])
		return ls2.section_processor.SCRI[1](internal.file)
	end
end

function ls2Loader:getComboInformation()
	return self:_getMetadata().combo
end

function ls2Loader:getStarDifficultyInfo()
	local metadata = self:_getMetadata()

	if metadata.star then
		if metadata.random_star and metadata.random_star ~= metadata.star then
			return metadata.star, metadata.random_star
		end
		return metadata.star
	end

	return 0
end

function ls2Loader:getAudio()
	local internal = ls2Loader^self

	if internal.ls2.sections.ADIO then
		internal.file:seek(internal.ls2.sections.ADIO[1])
		local ext, data, ff = ls2.section_processor.ADIO[1](internal.file, internal.ls2.version_2)
		if ext then
			if ff then
				-- TODO
				return nil
			end
			return love.filesystem.newFileData(data, "_."..ext)
		end
	end

	return baseLoader.getAudio(self)
end

function ls2Loader:getAudioPathList()
	local metadata = self:_getMetadata()
	local paths = {}

	if metadata.song_file then
		paths[1] = util.removeExtension("audio/"..metadata.song_file)
	end

	return paths
end

return ls2Loader, "file"
