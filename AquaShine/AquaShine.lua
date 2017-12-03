-- Aquashine loader. Base layer of Live Simulator: 2

--[[---------------------------------------------------------------------------
-- Copyright (c) 2038 Dark Energy Processor Corporation
-- 
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to
-- deal in the Software without restriction, including without limitation the
-- rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
-- sell copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
-- 
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
-- 
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
-- FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
-- IN THE SOFTWARE.
--]]---------------------------------------------------------------------------

local weak_table = {__mode = "v"}
local AquaShine = {
	CurrentEntryPoint = nil,
	Arguments = ASArg,
	AlwaysRunUnfocus = false,
	SleepDisabled = false,
	
	-- Cache table. Anything inside this table can be cleared at any time when running under low memory
	CacheTable = setmetatable({}, weak_table),
	-- Preload entry points
	PreloadedEntryPoint = {},
	-- LOVE 0.11 (NewLove) or LOVE 0.10
	NewLove = love._version >= "0.11.0"
}

local ffi = require("ffi")
local love = require("love")

local ScreenshotThreadCode = [[
local lt = require("love.timer")
local li = require("love.image")
local arg = ...
local name = string.format("screenshots/screenshot_%s_%d.png",
	os.date("%Y_%m_%d_%H_%M_%S"),
	math.floor((lt.getTime() % 1) * 1000)
)

require("debug").getregistry().ImageData.encode(arg, "png", name)
print("Screenshot saved as", name)
]]

----------------------------------
-- AquaShine Utilities Function --
----------------------------------

--! @brief Calculates touch position to take letterboxing into account
--! @param x Uncalculated X position
--! @param y Uncalculated Y position
--! @returns Calculated X and Y positions (2 values)
function AquaShine.CalculateTouchPosition(x, y)
	if AquaShine.LogicalScale then
		return
			(x - AquaShine.LogicalScale.OffX) / AquaShine.LogicalScale.ScaleOverall,
			(y - AquaShine.LogicalScale.OffY) / AquaShine.LogicalScale.ScaleOverall
	else
		return x, y
	end
end

local mount_target = {}
--! @brief Counted ZIP mounting. Mounts ZIP file
--! @param path The Zip file path
--! @param target The Zip mount point (or nil to unmount)
--! @returns true on success, false on failure
function AquaShine.MountZip(path, target)
	assert(type(path) == "string")
	
	if target == nil then
		if mount_target[path] then
			mount_target[path] = mount_target[path] - 1
			
			if mount_target[path] == 0 then
				mount_target[path] = nil
				AquaShine.Log("AquaShine", "Attempt to unmount %s", path)
				assert(love.filesystem.unmount(path), "Unmount failed")
			end
			
			return true
		else
			return false
		end
	else
		if not(mount_target[path]) then
			local r = love.filesystem.mount(path, target)
			
			if r then
				mount_target[path] = 1
				AquaShine.Log("AquaShine", "New mount %s", path)
			end
			
			return r
		else
			mount_target[path] = mount_target[path] + 1
			return true
		end
	end
end

local config_list = {}
--! @brief Parses configuration passed from command line
--!        Configuration passed via "/<key>[=<value=true>]" <key> is case-insensitive.
--!        If multiple <key> is found, only the first one takes effect.
--! @param argv Argument vector
--! @note This function modifies the `argv` table
function AquaShine.ParseCommandLineConfig(argv)
	if love.filesystem.isFused() == false then
		table.remove(argv, 1)
	end
	
	local arglen = #arg
	
	for i = arglen, 1, -1 do
		local k, v = arg[i]:match("^%-(%w+)=?(.*)")
		
		if k and v then
			config_list[k:lower()] = #v == 0 and true or tonumber(v) or v
			table.remove(arg, i)
		end
	end
end

--! @brief Get configuration argument passed from command line
--! @param key The configuration key (case-insensitive)
--! @returns The configuration value or `nil` if it's not set
function AquaShine.GetCommandLineConfig(key)
	return config_list[key:lower()]
end

--! @brief Set configuration
--! @param key The configuration name (case-insensitive)
--! @param val The configuration value
function AquaShine.SaveConfig(key, val)
	local file = assert(love.filesystem.newFile(key:upper()..".txt", "w"))
	
	file:write(tostring(val))
	file:close()
end

--! @brief Get configuration
--! @param key The configuration name (case-insensitive)
--! @param defval The configuration default value
function AquaShine.LoadConfig(key, defval)
	AquaShine.Log("AquaShine", "LoadConfig %s", key)
	local file = love.filesystem.newFile(key:upper()..".txt")
	
	if not(file:open("r")) then
		assert(file:open("w"))
		file:write(tostring(defval))
		file:close()
		
		return defval
	end
	
	local data = file:read()
	file:close()
	
	return tonumber(data) or data
end

local TemporaryEntryPoint
--! @brief Loads entry point
--! @param name The entry point Lua script file
--! @param arg Additional argument to be passed
function AquaShine.LoadEntryPoint(name, arg)
	local scriptdata, title
	
	if AquaShine.SplashData then
		local data = AquaShine.SplashData
		AquaShine.SplashData = nil
		
		if type(data) == "string" then
			return AquaShine.LoadEntryPoint(data, {name, arg})
		else
			TemporaryEntryPoint = data
			return data.Start({name, arg})
		end
	end
	
	AquaShine.SleepDisabled = false
	love.window.setDisplaySleepEnabled(true)
	
	if name:sub(1, 1) == ":" then
		-- Predefined entry point
		if AquaShine.Config.AllowEntryPointPreload then
			scriptdata, title = assert(assert(AquaShine.PreloadedEntryPoint[name:sub(2)], "Entry point not found")(AquaShine))
		else
			scriptdata, title = assert(assert(love.filesystem.load(
				assert(AquaShine.Config.Entries[name:sub(2)], "Entry point not found")[2]
			))(AquaShine))
		end
	else
		scriptdata, title = assert(assert(love.filesystem.load(name))(AquaShine))
	end
	
	scriptdata.Start(arg or {})
	TemporaryEntryPoint = scriptdata
	
	if title then
		love.window.setTitle(AquaShine.WindowName .. " - "..title)
	else
		love.window.setTitle(AquaShine.WindowName)
	end
end

--! Function used to replace extension on file
local function substitute_extension(file, ext_without_dot)
	return file:sub(1, ((file:find("%.[^%.]*$")) or #file+1)-1).."."..ext_without_dot
end
--! @brief Load audio
--! @param path The audio path
--! @param noorder Force existing extension?
--! @returns Audio handle or `nil` plus error message on failure
function AquaShine.LoadAudio(path, noorder)
	local s, token_image
	
	if not(noorder) then
		local a = AquaShine.LoadAudio(substitute_extension(path, "wav"), true)
		
		if a == nil then
			a = AquaShine.LoadAudio(substitute_extension(path, "ogg"), true)
			
			if a == nil then
				return AquaShine.LoadAudio(substitute_extension(path, "mp3"), true)
			end
		end
		
		return a
	end
	
	s, token_image = pcall(love.sound.newSoundData, path)
	
	if s == false then
		if AquaShine.FFmpegExt then
			s, token_image = pcall(AquaShine.FFmpegExt, path)
			
			if s then
				return token_image
			end
		end
		
		return nil, token_image
	else
		return token_image
	end
end

--! @brief Load video
--! @param path The video path
--! @returns Video handle or `nil` plus error message on failure
--! @note Audio stream doesn't loaded
function AquaShine.LoadVideo(path)
	local s, a
	
	if AquaShine.FFmpegExt and (path:sub(-4) == ".ogg" or path:sub(-4) == ".ogv") or not(AquaShine.FFmpegExt) then
		AquaShine.Log("AquaShine", "LoadVideo love.graphics.newVideo %s", path)
		s, a = pcall(love.graphics.newVideo, path)
	
		if s then
			AquaShine.Log("AquaShine", "LoadVideo love.graphics.newVideo %s success", path)
			return a
		end
	end
	
	-- Possible incompatible format. Load with FFmpegExt if available
	if AquaShine.FFmpegExt then
		AquaShine.Log("AquaShine", "LoadVideo FFmpegExt %s", path)
		s, a = pcall(AquaShine.FFmpegExt.LoadVideo, path)
		
		if s then
			AquaShine.Log("AquaShine", "LoadVideo FFmpegExt %s success", path)
			return a
		end
	end
	
	return nil, a
end

--! @brief Creates new image with specificed position from specificed lists of layers
--! @param w Resulted generated image width
--! @param h Resulted generated image height
--! @param layers Lists of love.graphics.* calls in format {love.graphics.*, ...}
--! @param imagedata Returns ImageData instead of Image object?
--! @returns New Image/ImageData object
function AquaShine.ComposeImage(w, h, layers, imagedata)
	local canvas = love.graphics.newCanvas(w, h)
	
	love.graphics.push("all")
	love.graphics.setCanvas(canvas)
	
	for i = 1, #layers do
		table.remove(layers[i], 1)(unpack(layers[i]))
	end
	
	love.graphics.pop()
	
	local id = canvas:newImageData()
	
	if imagedata then
		return id
	else
		return love.graphics.newImage(id)
	end
end

--! @brief Stripes the directory and returns only the filename
function AquaShine.Basename(file)
	if not(file) then return end
	
	local _ = file:reverse()
	return _:sub(1, (_:find("/") or _:find("\\") or #_ + 1) - 1):reverse()
end

--! @brief Determines if runs under slow system (mobile devices)
function AquaShine.IsSlowSystem()
	return not(jit) or AquaShine.OperatingSystem == "Android" or AquaShine.OperatingSystem == "iOS"
end

--! @brief Disable screen sleep
--! @note Should be called only in Start function
function AquaShine.DisableSleep()
	-- tail call
	return love.window.setDisplaySleepEnabled(false)
end

--! @brief Disable touch particle effect
--! @note Should be called only in Start function
function AquaShine.DisableTouchEffect()
	if AquaShine.TouchEffect and AquaShine._TempTouchEffect == nil then
		AquaShine._TempTouchEffect, AquaShine.TouchEffect = AquaShine.TouchEffect, nil
	end
end

--! @brief Disable pause when loses focus
--! @param disable Always run even when losing focus (true) or not (false)
--! @note Should be called only in Start function
function AquaShine.RunUnfocused(disable)
	AquaShine.AlwaysRunUnfocus = not(not(disable))
end

--! @brief Gets cached data from cache table, or execute function to load and store in cache
--! @param name The cache name
--! @param onfailfunc Function to execute when cache is not found. The return value of the function
--!                   then stored in cache table and returned
--! @param ... additional data passed to `onfailfunc`
function AquaShine.GetCachedData(name, onfailfunc, ...)
	local val = AquaShine.CacheTable[name]
	AquaShine.Log("AquaShine", "GetCachedData %s", name)
	
	if val == nil then
		val = onfailfunc(...)
		AquaShine.Log("AquaShine", "CachedData, created & cached %s", name)
		AquaShine.CacheTable[name] = val
	end
	
	return val
end

--! @brief Check if current platform is desktop
--! @returns true if current platform is desktop platform, false oherwise
function AquaShine.IsDesktopSystem()
	return AquaShine.OperatingSystem == "Windows" or AquaShine.OperatingSystem == "Linux" or AquaShine.OperatingSystem == "OS X"
end

--! @brief Set touch effect callback
function AquaShine.SetTouchEffectCallback(c)
	assert(c.Update and c.Start and c.Pause and c.Draw and c.SetPosition, "Invalid callback")
	
	AquaShine.TouchEffect = c
end

-- Fo module that requires AquaShine parameter to be passed as 1st argument
local modules = {}
function AquaShine.LoadModule(name, ...)
	name = name:gsub("%.", "/")
	local x = modules[name]
	
	if x == nil then
		local y = {assert(love.filesystem.load(name..".lua"))(AquaShine, ...)}
		
		if #y == 0 then
			x = {}
		else
			x = {y[1]}
		end
		
		modules[name] = x
	end
	
	return x[1]
end

--! @brief Sets the splash screen before loading entry point (for once)
--! @param splash Splash screen Lua file path or table
function AquaShine.SetSplashScreen(file)
	AquaShine.SplashData = file
end

function AquaShine.Log() end

----------------------------
-- AquaShine Font Caching --
----------------------------
local FontList = setmetatable({}, weak_table)

--! @brief Load font
--! @param name The font name
--! @param size The font size
--! @returns Font object or nil on failure
function AquaShine.LoadFont(name, size)
	size = size or 12
	
	name = name or AquaShine.DefaultFont
	local cache_name = string.format("%s_%d", name or "LOVE default font", size)
	
	if not(FontList[cache_name]) then
		local s, a
		
		if name then s, a = pcall(love.graphics.newFont, name or AquaShine.DefaultFont, size)
		else s = true a = love.graphics.newFont(size) end
		
		if s then
			FontList[cache_name] = a
		else
			return nil, a
		end
	end
	
	return FontList[cache_name]
end

--! @brief Set default font to be used for AquaShine
--! @param name The font name
--! @returns Previous default font name
function AquaShine.SetDefaultFont(name)
	local a = AquaShine.DefaultFont
	AquaShine.DefaultFont = assert(type(name) == "string") and name
	return a
end

--------------------------------------
-- AquaShine Image Loader & Caching --
--------------------------------------
local LoadedImage = setmetatable({}, {__mode = "v"})

--! @brief Load image without caching
--! @param path The image path
--! @returns Drawable object
function AquaShine.LoadImageNoCache(path)
	assert(path:sub(-4) == ".png", "Only PNG image is supported")
	local x, y = pcall(love.graphics.newImage, path, ConstImageFlags)
	AquaShine.Log("AquaShine", "LoadImageNoCache %s", path)
	
	if x then
		return y
	end
	
	return nil, y
end

--! @brief Load image with caching
--! @param ... Paths of images to be loaded
--! @returns Drawable object
function AquaShine.LoadImage(...)
	local out = {...}
	
	for i = 1, #out do
		local path = out[i]
		
		if type(path) == "string" then
			local img = LoadedImage[path]
			
			if not(img) then
				img = AquaShine.LoadImageNoCache(path)
				LoadedImage[path] = img
			end
			
			out[i] = img
		else
			out[i] = path
		end
	end
	
	return unpack(out)
end

----------------------------------------------
-- AquaShine Scissor to handle letterboxing --
----------------------------------------------
function AquaShine.SetScissor(x, y, width, height)
	if not(x and y and width and height) then
		return love.graphics.setScissor()
	end
	
	if AquaShine.LogicalScale then
		return love.graphics.setScissor(
			x * AquaShine.LogicalScale.ScaleOverall + AquaShine.LogicalScale.OffX,
			y * AquaShine.LogicalScale.ScaleOverall + AquaShine.LogicalScale.OffY,
			width * AquaShine.LogicalScale.ScaleOverall,
			height * AquaShine.LogicalScale.ScaleOverall
		)
	else
		return love.graphics.setScissor(x, y, width, height)
	end
end

function AquaShine.ClearScissor()
	return love.graphics.setScissor()
end

function AquaShine.IntersectScissor(x, y, width, height)
	if AquaShine.LogicalScale then
		return love.graphics.intersectScissor(
			x * AquaShine.LogicalScale.ScaleOverall + AquaShine.LogicalScale.OffX,
			y * AquaShine.LogicalScale.ScaleOverall + AquaShine.LogicalScale.OffY,
			width * AquaShine.LogicalScale.ScaleOverall,
			height * AquaShine.LogicalScale.ScaleOverall
		)
	else
		return love.grphics.intersectScissor(x, y, width, height)
	end
end

function AquaShine.GetScissor()
	local x, y, w, h = love.graphics.getScissor()
	if not(x and y and w and h) then return end
	
	if AquaShine.LogicalScale then
		return
			x * AquaShine.LogicalScale.ScaleOverall + AquaShine.LogicalScale.OffX,
			y * AquaShine.LogicalScale.ScaleOverall + AquaShine.LogicalScale.OffY,
			w / AquaShine.LogicalScale.ScaleOverall,
			h / AquaShine.LogicalScale.ScaleOverall
	else
		return x, y, w, h
	end
end

------------------------------
-- Other Internal Functions --
------------------------------
function AquaShine.StepLoop()
	AquaShine.ExitStatus = nil
	
	-- Switch entry point
	if TemporaryEntryPoint then
		if AquaShine.CurrentEntryPoint and AquaShine.CurrentEntryPoint.Exit then
			pcall(AquaShine.CurrentEntryPoint.Exit)
		end
		
		AquaShine.CurrentEntryPoint = TemporaryEntryPoint
		TemporaryEntryPoint = nil
	end
	
	-- Process events.
	love.event.pump()
	for name, a, b, c, d, e, f in love.event.poll() do
		if name == "quit" then
			if AquaShine.CurrentEntryPoint and AquaShine.CurrentEntryPoint.Exit then
				AquaShine.CurrentEntryPoint.Exit(true)
			end
			
			AquaShine.ExitStatus = a or 0
			return AquaShine.ExitStatus
		end
		
		love.handlers[name](a, b, c, d, e, f)
	end
	
	-- Update dt, as we'll be passing it to update
	local dt = love.timer.step()
	
	if love.graphics.isActive() then
		love.graphics.clear()
		
		do
			love.graphics.setCanvas(AquaShine.MainCanvas)
			love.graphics.clear()
			
			if AquaShine.CurrentEntryPoint then
				dt = dt * 1000
				
				AquaShine.CurrentEntryPoint.Update(dt)
				love.graphics.push("all")
				
				if AquaShine.LogicalScale then
					love.graphics.translate(AquaShine.LogicalScale.OffX, AquaShine.LogicalScale.OffY)
					love.graphics.scale(AquaShine.LogicalScale.ScaleOverall)
					AquaShine.CurrentEntryPoint.Draw(dt)
				else
					AquaShine.CurrentEntryPoint.Draw(dt)
				end
				
				love.graphics.pop()
				love.graphics.setColor(1, 1, 1)
			else
				love.graphics.setFont(AquaShine.MainFont)
				love.graphics.print("AquaShine loader: No entry point specificed/entry point rejected", 10, 10)
			end
			love.graphics.setCanvas()
		end
		love.graphics.setShader(srgbshader)
		love.graphics.draw(AquaShine.MainCanvas)
		love.graphics.setShader()
		love.graphics.present()
	end
end

function AquaShine.MainLoop()
	AquaShine.MainFont = AquaShine.LoadFont(nil, 14)
	
	if AquaShine.NewLove then
		return AquaShine.StepLoop
	end
	
	while true do
		AquaShine.StepLoop()
		
		if AquaShine.ExitStatus then
			return AquaShine.ExitStatus
		end
	end
end

------------------------------------
-- AquaShine love.* override code --
------------------------------------
function love.run()
	local dt = 0
	
	if love.math then
		love.math.setRandomSeed(os.time())
		math.randomseed(os.time())
	end
 
	love.load(arg)
	
	-- We don't want the first frame's dt to include time taken by love.load.
	love.timer.step()
 
	-- Main loop time.
	return AquaShine.MainLoop()
end

local function error_printer(msg, layer)
	print((debug.traceback("Error: " .. tostring(msg), 1+(layer or 1)):gsub("\n[^\n]+$", "")))
end

-- TODO: Optimize error handler
function love.errhand(msg)
	msg = tostring(msg)
	error_printer(msg, 2)
 
	if not love.window or not love.graphics or not love.event then
		return
	end
 
	if not love.graphics.isCreated() or not love.window.isOpen() then
		local success, status = pcall(love.window.setMode, 800, 600)
		if not success or not status then
			return
		end
	end
 
	love.audio.stop()
	love.graphics.reset()
	
	local trace = debug.traceback()
 
	love.graphics.clear(love.graphics.getBackgroundColor())
	love.graphics.origin()
 
	local err = {}
 
	table.insert(err, "AquaShine Error Handler. An error has occured during execution\nPress Ctrl+C to copy error message to clipboard.")
	table.insert(err, msg.."\n")
 
	for l in string.gmatch(trace, "(.-)\n") do
		if not string.match(l, "boot.lua") then
			l = string.gsub(l, "stack traceback:", "Traceback\n")
			table.insert(err, l)
		end
	end
 
	local p = table.concat(err, "\n")
 
	p = string.gsub(p, "\t", "")
	p = string.gsub(p, "%[string \"(.-)\"%]", "%1")
	
	AquaShine.LoadEntryPoint("AquaShine/ErrorHandler.lua", {p})
	return AquaShine.MainLoop()
end

-- Inputs
function love.mousepressed(x, y, button, istouch)
	if istouch == true then return end
	x, y = AquaShine.CalculateTouchPosition(x, y)
	
	if AquaShine.TouchEffect then
		AquaShine.TouchEffect.Start()
		AquaShine.TouchEffect.SetPosition(x, y)
	end
	
	if AquaShine.CurrentEntryPoint and AquaShine.CurrentEntryPoint.MousePressed then
		AquaShine.CurrentEntryPoint.MousePressed(x, y, button, istouch)
	end
end

function love.mousemoved(x, y, dx, dy, istouch)
	if istouch == true then return end
	x, y = AquaShine.CalculateTouchPosition(x, y)
	
	if AquaShine.TouchEffect then
		AquaShine.TouchEffect.SetPosition(x, y)
	end
	
	if AquaShine.CurrentEntryPoint and AquaShine.CurrentEntryPoint.MouseMoved then
		if AquaShine.LogicalScale then
			return AquaShine.CurrentEntryPoint.MouseMoved(x, y, dx / AquaShine.LogicalScale.ScaleOverall, dy / AquaShine.LogicalScale.ScaleOverall, istouch)
		else
			return AquaShine.CurrentEntryPoint.MouseMoved(x, y, dx, dy, istouch)
		end
	end
end

function love.mousereleased(x, y, button, istouch)
	if istouch == true then return end
	
	if AquaShine.TouchEffect then
		AquaShine.TouchEffect.Pause()
	end
	
	if AquaShine.CurrentEntryPoint and AquaShine.CurrentEntryPoint.MouseReleased then
		x, y = AquaShine.CalculateTouchPosition(x, y)
		AquaShine.CurrentEntryPoint.MouseReleased(x, y, button, istouch)
	end
end

function love.touchpressed(id, x, y, dx, dy, pressure)
	return love.mousepressed(x, y, 1, id)
end

function love.touchreleased(id, x, y, dx, dy, pressure)
	return love.mousereleased(x, y, 1, id)
end

function love.touchmoved(id, x, y, dx, dy)
	return love.mousemoved(x, y, dx, dy, id)
end

function love.keypressed(key, scancode, repeat_bit)
	if AquaShine.CurrentEntryPoint and AquaShine.CurrentEntryPoint.KeyPressed then
		AquaShine.CurrentEntryPoint.KeyPressed(key, scancode, repeat_bit)
	end
end

function love.keyreleased(key, scancode)
	if key == "f12" and love.thread then
		love.thread.newThread(ScreenshotThreadCode):start(AquaShine.MainCanvas:newImageData())
	elseif key == "f10" then
		AquaShine.Log("AquaShine", "F10: collectgarbage")
		if jit then jit.flush() end
		collectgarbage("collect")
	end
	
	if AquaShine.CurrentEntryPoint and AquaShine.CurrentEntryPoint.KeyReleased then
		AquaShine.CurrentEntryPoint.KeyReleased(key, scancode)
	end
end

function love.focus(f)
	if AquaShine.CurrentEntryPoint and AquaShine.CurrentEntryPoint.Focus then
		AquaShine.CurrentEntryPoint.Focus(f)
	end
end

-- File/folder drag-drop support
function love.filedropped(file)
	if AquaShine.CurrentEntryPoint and AquaShine.CurrentEntryPoint.FileDropped then
		AquaShine.CurrentEntryPoint.FileDropped(file)
	end
end

function love.directorydropped(dir)
	if AquaShine.CurrentEntryPoint and AquaShine.CurrentEntryPoint.DirectoryDropped then
		AquaShine.CurrentEntryPoint.DirectoryDropped(dir)
	end
end

-- On thread error
function love.threaderror(t, msg)
	assert(false, msg)
end

-- Letterboxing recalculation
function love.resize(w, h)
	if AquaShine.LogicalScale then
		local lx, ly = AquaShine.Config.Letterboxing.LogicalWidth, AquaShine.Config.Letterboxing.LogicalHeight
		AquaShine.LogicalScale.ScreenX, AquaShine.LogicalScale.ScreenY = w, h
		AquaShine.LogicalScale.ScaleOverall = math.min(AquaShine.LogicalScale.ScreenX / lx, AquaShine.LogicalScale.ScreenY / ly)
		AquaShine.LogicalScale.OffX = (AquaShine.LogicalScale.ScreenX - AquaShine.LogicalScale.ScaleOverall * lx) / 2
		AquaShine.LogicalScale.OffY = (AquaShine.LogicalScale.ScreenY - AquaShine.LogicalScale.ScaleOverall * ly) / 2
	end
	
	AquaShine.MainCanvas = love.graphics.newCanvas()
	
	if AquaShine.CurrentEntryPoint and AquaShine.CurrentEntryPoint.Resize then
		AquaShine.CurrentEntryPoint.Resize(w, h)
	end
end

-- When running low memory
if jit then
	love.lowmemory = jit.flush
else
	love.lowmemory = collectgarbage
end

-- Initialization
function love.load(arg)
	-- Some LOVE 0.11.x functions in LOVE 0.10.x
	-- Game which uses AquaShine expects to use LOVE 0.11 API at some degree
	if not(AquaShine.NewLove) then
		local method = debug.getregistry()
		
		-- love.errorhandler is love.errhand
		love.errorhandler = love.errhand
		
		-- love.timer.step returns deltaT
		local step_time = love.timer.step
		function love.timer.step()
			step_time()
			return love.timer.getDelta()
		end
		
		-- love.filesystem.getInfo combines these:
		-- * love.filesystem.exists
		-- * love.filesystem.isDirectory
		-- * love.filesystem.isFile
		-- * love.filesystem.isSymlink
		-- * love.filesystem.getSize
		-- * love.filesystem.getLastModified
		function love.filesystem.getInfo(dir, t)
			if love.filesystem.exists(dir) then
				t = t or {}
				
				-- Type
				if love.filesystem.isFile(dir) then
					t.type = "file"
				elseif love.filesystem.isDirectory(dir) then
					t.type = "directory"
				elseif love.filesystem.isSymlink(dir) then
					t.type = "symlink"
				else
					t.type = "other"
				end
				
				if t.type == "directory" then
					t.size = 0
				else
					t.size = love.filesystem.getSize(dir) or -1
				end
				
				t.modtime = love.filesystem.getLastModified(dir) or -1
				return t
			end
			
			return nil
		end
		
		-- 0..1 range for love.graphics.setColor
		local setColor = love.graphics.setColor
		function love.graphics.setColor(r, g, b, a)
			if type(r) == "table" then
				return setColor(r[1] * 255, r[2] * 255, r[3] * 255, (r[4] or 1) * 255)
			else
				return setColor(r * 255, g * 255, b * 255, (a or 1) * 255)
			end
		end
		
		-- 0..1 range for love.graphics.getColor
		local getColor = love.graphics.getColor
		function love.graphics.getColor()
			local r, g, b, a = getColor()
			
			return r / 255, g / 255, b / 255, a / 255
		end
		
		-- 0..1 range for love.graphics.clear
		local clear = love.graphics.clear
		function love.graphics.clear(r, g, b, a, ...)
			if type(r) == "table" then
				-- Canvas clear (table)
				local tablist = {r, g, b, a}
				
				for i = 1, select("#", ...) do
					tablist[i + 4] = select(i, ...)
				end
				
				for i, v in ipairs(tablist) do
					local t = {}
					
					t[1] = v[1] * 255
					t[2] = v[2] * 255
					t[3] = v[3] * 255
					t[4] = (v[4] or 1) * 255
					tablist[i] = t
				end
				
				return clear(unpack(tablist))
			elseif r then
				return clear(r * 255, g * 255, b * 255, (a or 1) * 255)
			else
				return clear()
			end
		end
		
		-- 0..1 range for SpriteBatch:set/getColor
		local SpriteBatch = method.SpriteBatch
		local SpriteBatch_getColor = SpriteBatch.getColor
		local SpriteBatch_setColor = SpriteBatch.setColor
		function SpriteBatch.getColor(this)
			local r, g, b, a = SpriteBatch_getColor(this)
			return r / 255, g / 255, b / 255, a / 255
		end
		
		function SpriteBatch.setColor(this, r, g, b, a)
			if r then
				return SpriteBatch_setColor(this, r * 255, g * 255, b * 255, (a or 1) * 255)
			else
				return SpriteBatch_setColor(this)
			end
		end
		
		-- Image:replacePixels function
		local Image = method.Image
		function Image.replacePixels(this, imagedata)
			local id = this:getData()
			
			if id ~= imagedata then
				id:paste(imagedata, 0, 0)
			end
			
			return this:refresh()
		end
		
		-- SoundData:getChannelCount function
		method.SoundData.getChannelCount = method.SoundData.getChannels
		
		love.data = {}
		
		-- love.math.decompress is deprecated, replaced by love.data.decompress
		function love.data.decompress(fmt, data)
			-- Notice the argument order
			return love.math.decompress(data, fmt)
		end
		
		-- Shader:hasUniform
		function method.Shader.hasUniform(shader, name)
			return not(not(shader:getExternVariable(name)))
		end
	end
	
	-- Initialization
	local wx, wy = love.graphics.getDimensions()
	AquaShine.OperatingSystem = love.system.getOS()
	love.filesystem.setIdentity(love.filesystem.getIdentity(), true)
	
	if AquaShine.GetCommandLineConfig("debug") then
		function AquaShine.Log(part, msg, ...)
			if not(part) then
				local info = debug.getinfo(2)
				
				if info.short_src and info.currentline then
					part = info.short_src..":"..info.currentline
				end
			end
			
			io.stderr:write("[", part or "unknown", "] ", string.format(msg or "", ...), "\n")
		end
	end
	
	AquaShine.WindowName = love.window.getTitle()
	AquaShine.RendererInfo = {love.graphics.getRendererInfo()}
	AquaShine.LoadModule("AquaShine.InitExtensions")
	love.resize(wx, wy)
	
	if AquaShine.OperatingSystem == "Android" then
		jit[AquaShine.LoadConfig("JUST_IN_TIME", "off")]()
	end
	
	if jit and AquaShine.GetCommandLineConfig("interpreter") then
		jit.off()
	end
	
	-- Preload entry points
	if AquaShine.AllowEntryPointPreload then
		for n, v in pairs(AquaShine.Config.Entries) do
			AquaShine.PreloadedEntryPoint[n] = assert(love.filesystem.load(v[2]))
		end
	end
	
	-- Load entry point
	if arg[1] and AquaShine.Config.Entries[arg[1]] and AquaShine.Config.Entries[arg[1]][1] >= 0 and #arg > AquaShine.Config.Entries[arg[1]][1] then
		local entry = table.remove(arg, 1)
		
		AquaShine.LoadEntryPoint(AquaShine.Config.Entries[entry][2], arg)
	elseif AquaShine.Config.DefaultEntry then
		AquaShine.LoadEntryPoint(":"..AquaShine.Config.DefaultEntry, arg)
	end
end

function love._getAquaShineHandle()
	return AquaShine
end

-----------------------------------
-- AquaShine config loading code --
-----------------------------------
do
	local conf = AquaShine.LoadModule("AquaShineConfig")
	
	AquaShine.AllowEntryPointPreload = conf.EntryPointPreload
	AquaShine.Config = conf
	
	if conf.Letterboxing then
		AquaShine.LogicalScale = {
			ScreenX = assert(conf.Letterboxing.LogicalWidth),
			ScreenY = assert(conf.Letterboxing.LogicalHeight),
			OffX = 0,
			OffY = 0,
			ScaleOverall = 1
		}
	end
end

return AquaShine
