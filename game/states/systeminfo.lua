-- System Information (for bug reporting)
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

-- luacheck: read_globals DEPLS_VERSION DEPLS_VERSION_NUMBER DEPLS_VERSION_CODENAME

local love = require("love")
local color = require("color")
local mainFont = require("font")
local gamestate = require("gamestate")

local backgroundLoader = require("game.background_loader")

local glow = require("game.afterglow")
local backNavigation = require("game.ui.back_navigation")

local androidCodenames = setmetatable({
	-- LOVE only supports Android 4.0 and later
	-- https://source.android.com/setup/start/build-numbers
	[14] = "Ice Cream Sandwich",
	[15] = "Ice Cream Sandwich",
	[16] = "Jelly Bean",
	[17] = "Jelly Bean",
	[18] = "Jelly Bean",
	[19] = "KitKat",
	[20] = "KitKat", -- https://developer.android.com/studio/releases/platforms#4.4
	[21] = "Lollipop",
	[22] = "Lollipop",
	[23] = "Marshmallow",
	[24] = "Nougat",
	[25] = "Nougat",
	[26] = "Oreo",
	[27] = "Oreo",
	[28] = "Pie"
}, {__index = function() return "Unknown" end})

local sysInfo = gamestate.create {
	images = {},
	fonts = {}
}

local osVersionString
do
	local sos = love._os
	if sos == "Windows" then
		-- Get Windows Version
		local ffi = require("ffi")
		local ntdll = ffi.load("ntdll")

		ffi.cdef[[
		typedef struct livesim2Win_osVersionInfoExW
		{
			uint32_t  dwOSVersionInfoSize;
			uint32_t  dwMajorVersion;
			uint32_t  dwMinorVersion;
			uint32_t  dwBuildNumber;
			uint32_t  dwPlatformId;
			int16_t  szCSDVersion[128];
			uint16_t wServicePackMajor;
			uint16_t wServicePackMinor;
			uint16_t wSuiteMask;
			uint8_t  wProductType;
			uint8_t  wReserved;
		} livesim2Win_osVersionInfoExW;
		int32_t __stdcall RtlGetVersion(livesim2Win_osVersionInfoExW *);
		]]

		local ver = ffi.new("livesim2Win_osVersionInfoExW")
		if ntdll.RtlGetVersion(ver) == 0 then
			local build = string.format("%d.%d.%d", ver.dwMajorVersion, ver.dwMinorVersion, ver.dwBuildNumber)

			-- List of hardcoded Windows version strings :P
			if ver.dwMajorVersion == 10 then
				local relidf = io.popen("reg query \"HKLM\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\" /v ReleaseId")
				local buildf = io.popen("reg query \"HKLM\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\" /v UBR")
				local release = tonumber(relidf:read("*a"):match("ReleaseId%s+REG_SZ%s+(%d+)"))
				local ubr = tonumber(buildf:read("*a"):match("0x%x+"))
				buildf:close()
				relidf:close()

				if release then
					if ubr then
						osVersionString = string.format("OS: Windows 10 %d (%s.%d)", release, build, ubr)
					else
						osVersionString = string.format("OS: Windows 10 %d (%s)", release, build)
					end
				else
					osVersionString = string.format("OS: Windows 10 (%s)", build)
				end
			elseif ver.dwMajorVersion == 6 then
				if ver.dwMinorVersion == 3 then
					osVersionString = string.format("OS: Windows 8.1 (%s)", build)
				elseif ver.dwMinorVersion == 2 then
					osVersionString = string.format("OS: Windows 8 (%s)", build)
				elseif ver.dwMinorVersion == 1 then
					osVersionString = string.format("OS: Windows 7 (%s)", build)
				elseif ver.dwMinorVersion == 0 then
					osVersionString = string.format("OS: Windows Vista (%s)", build)
				else
					osVersionString = string.format("OS: Windows (%s)", build)
				end
			elseif ver.dwMajorVersion == 5 then
				if ver.dwMinorVersion == 2 then
					-- Probably not
					osVersionString = string.format("OS: Windows XP Professional 64-bit (%s)", build)
				elseif ver.dwMinorVersion == 1 then
					osVersionString = string.format("OS: Windows XP (%s)", build)
				else
					osVersionString = string.format("OS: Windows (%s)", build)
				end
			else
				osVersionString = string.format("OS: Windows (%s)", build)
			end
		else
			osVersionString = "OS: Windows"
		end
	elseif sos == "Android" then
		-- Get Android API level
		local sdkf = io.popen("getprop ro.build.version.sdk", "r")
		local relf = io.popen("getprop ro.build.version.release", "r")
		local sdk = tonumber(sdkf:read("*l"))
		local rel = relf:read("*l")
		sdkf:close()
		relf:close()

		osVersionString = string.format("OS: Android %s/%s (API Level %d)", rel, androidCodenames[sdk], sdk)
	else
		osVersionString = "OS: "..sos
	end
end

-- Build version information
local function buildTextString()
	local sb = {
		"Before reporting bug, please screenshot this window",
		"",
		string.format("Live Simulator: 2 v%s \"%s\" %08d", DEPLS_VERSION, DEPLS_VERSION_CODENAME, DEPLS_VERSION_NUMBER),
		string.format("LOVE %d.%d.%d \"%s\"", love.getVersion())
	}

	do
		local feature = {}
		if os.getenv("LLA_IS_SET") then
			-- From modified Openal-Soft
			feature[#feature + 1] = "LLA: "..os.getenv("LLA_BUFSIZE").."smp/"..os.getenv("LLA_FREQUENCY").."Hz"
		end

		local hasJIT, jit = pcall(require, "jit")
		if hasJIT then
			feature[#feature + 1] = jit.version
			if jit.status() then
				feature[#feature + 1] = "JIT ON"
			end
		end

		sb[#sb + 1] = "Opts: "..table.concat(feature, " ")
	end

	-- System Information
	sb[#sb + 1] = osVersionString
	sb[#sb + 1] = "R/W Directory: "..love.filesystem.getSaveDirectory()
	sb[#sb + 1] = ""

	-- LOVE Information
	do
		local fmts = {}
		local fbos = {}
		local syslim = {}
		local gftr = {}
		local func = love.graphics.getImageFormats or love.graphics.getCompressedImageFormats

		for k, v in pairs(func()) do
			if v then
				fmts[#fmts + 1] = k
			end
		end

		for k, v in pairs(love.graphics.getCanvasFormats()) do
			if v then
				fbos[#fbos + 1] = k
			end
		end

		for k, v in pairs(love.graphics.getSystemLimits()) do
			syslim[#syslim + 1] = string.format("%s=%s", k, tostring(v))
		end

		for k, v in pairs(love.graphics.getSupported()) do
			if v then
				gftr[#gftr + 1] = k
			end
		end

		local dpiScale = love.graphics.getDPIScale and love.graphics.getDPIScale() or 1
		local orientation = love.window.getDisplayOrientation and love.window.getDisplayOrientation()
		local w, h = love.graphics.getDimensions()
		sb[#sb + 1] = string.format("Graphics Dimensions: %dx%d (DPI Scale %d)", w, h, dpiScale)
		sb[#sb + 1] = string.format("Window Dimensions: %dx%d", love.window.getMode())..
					  string.format(" Orientation: %s", orientation or "unknown")
		if love.window.getSafeArea then
			local a, b, c, d = love.window.getSafeArea()
			sb[#sb + 1] = string.format("Safe Area: %dx%d+%d+%d", c, d, a, b)
		else
			sb[#sb + 1] = string.format("Safe Area: %dx%d+0+0", w, h)
		end
		sb[#sb + 1] = ""
		sb[#sb + 1] = "Renderer: "..table.concat({love.graphics.getRendererInfo()}, " ")
		sb[#sb + 1] = "Image Formats: "..table.concat(fmts, " ")
		sb[#sb + 1] = "Canvas Formats: "..table.concat(fbos, " ")
		sb[#sb + 1] = "System Limits: "..table.concat(syslim, " ")
		sb[#sb + 1] = "Graphics Features: "..table.concat(gftr, " ")
	end

	return table.concat(sb, "\n")
end

local function leave()
	return gamestate.leave(nil)
end

function sysInfo:load()
	glow.clear()

	if self.data.background == nil then
		self.data.background = backgroundLoader.load(14)
	end

	if self.data.back == nil then
		self.data.back = backNavigation("System Information")
		self.data.back:addEventListener("mousereleased", leave)
	end

	if self.data.text == nil then
		local font = mainFont.get(20)
		local textString = buildTextString()
		self.data.text = love.graphics.newText(font)
		-- border
		for i = 0, 360, 45 do
			local mag = i % 90 == 0 and 1 or math.sqrt(2)
			local x, y = mag * math.cos(math.rad(i)), mag * math.sin(math.rad(i))
			self.data.text:addf({color.black, textString}, 956, "left", 2 + x, 50 + y)
		end
		self.data.text:addf({color.white, textString}, 956, "left", 2, 50)
	end
	glow.addFixedElement(self.data.back, 0, 0)
end

function sysInfo:draw()
	love.graphics.setColor(color.white)
	love.graphics.draw(self.data.background)
	love.graphics.push()
	love.graphics.origin()
	love.graphics.setColor(color.white80PT)
	love.graphics.rectangle("fill", 0, 0, love.graphics.getDimensions())
	love.graphics.pop()
	love.graphics.setColor(color.white)
	love.graphics.draw(self.data.text)
	glow.draw()
end

sysInfo:registerEvent("keyreleased", function(_, key)
	if key == "escape" then
		return leave()
	end
end)

return sysInfo
