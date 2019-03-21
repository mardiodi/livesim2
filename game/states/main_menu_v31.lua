-- Main Menu (v3.1)
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

-- luacheck: read_globals DEPLS_VERSION DEPLS_VERSION_NUMBER DEPLS_VERSION_CODENAME

local love = require("love")
local Luaoop = require("libs.Luaoop")

local color = require("color")
local gamestate = require("gamestate")
local loadingInstance = require("loading_instance")
local util = require("util")
local L = require("language")

local backgroundLoader = require("game.background_loader")
-- UI stuff
local glow = require("game.afterglow")
-- These UIs are declared directly here because
-- they're one-specific use. It's not worth to have it in separate file
-- because they're not reusable

local playButton = Luaoop.class("Livesim2.MainMenu.PlayButton", glow.element)

function playButton:new(state)
	local text = L"menu:play"
	self.image = state.assets.images.play
	self.playText = love.graphics.newText(state.assets.fonts.playText)
	self.playText:add(text, -state.assets.fonts.playText:getWidth(text) * 0.5, 0)
	self.width, self.height = 404, 512
	self.isPressed = false

	self:addEventListener("mousepressed", playButton._pressed)
	self:addEventListener("mousereleased", playButton._released)
	self:addEventListener("mousecanceled", playButton._released)
end

function playButton:_pressed(_)
	self.isPressed = true
end

function playButton:_released(_)
	self.isPressed = false
end

function playButton:render(x, y)
	love.graphics.setColor(color.hex55CAFD)
	love.graphics.rectangle("fill", x, y, self.width, self.height)
	love.graphics.setColor(color.white)
	love.graphics.draw(self.playText, x + 218, y + 212)
	love.graphics.rectangle("fill", x + 6, y, 34, self.height)
	love.graphics.rectangle("fill", x + 50, y, 34, self.height)
	love.graphics.circle("fill", x + 146, y + 114, 35)
	love.graphics.circle("fill", x + 216, y + 54, 35)
	love.graphics.circle("line", x + 146, y + 114, 35)
	love.graphics.circle("line", x + 216, y + 54, 35)
	love.graphics.setColor(color.hexFFFFFF8A)
	love.graphics.draw(self.image, x + 252, y + 364, 0, 1.1, 1.1)

	if self.isPressed then
		love.graphics.rectangle("fill", x, y, self.width, self.height)
	end
end

local changeUnitsButton = Luaoop.class("Livesim2.MainMenu.ChangeUnitsButton", glow.element)

function changeUnitsButton:new(state)
	local text = L"menu:changeUnits"
	self.image = state.assets.images.changeUnits
	self.text = love.graphics.newText(state.assets.fonts.menuButton)
	self.text:add(text, -state.assets.fonts.menuButton:getWidth(text), 0)
	self.width, self.height = 404, 156
	self.isPressed = false

	self:addEventListener("mousepressed", changeUnitsButton._pressed)
	self:addEventListener("mousereleased", changeUnitsButton._released)
	self:addEventListener("mousecanceled", changeUnitsButton._released)
end

function changeUnitsButton:_pressed(_)
	self.isPressed = true
end

function changeUnitsButton:_released(_)
	self.isPressed = false
end

function changeUnitsButton:render(x, y)
	love.graphics.setColor(color.hexFF4FAE)
	love.graphics.rectangle("fill", x, y, self.width, self.height)
	love.graphics.setColor(color.white)
	love.graphics.draw(self.text, x + 395, y + 100)
	love.graphics.draw(self.image, x + 11, y + 22, 0, 0.16, 0.16)

	if self.isPressed then
		love.graphics.rectangle("fill", x, y, self.width, self.height)
	end
end

local settingsButton = Luaoop.class("Livesim2.MainMenu.SettingsButton", glow.element)

function settingsButton:new(state)
	local text = L"menu:settings"
	self.image = state.assets.images.settingsDualGear
	self.text = love.graphics.newText(state.assets.fonts.menuButton)
	self.text:add(text, -state.assets.fonts.menuButton:getWidth(text), 0)
	self.width, self.height = 404, 156
	self.isPressed = false

	self:addEventListener("mousepressed", settingsButton._pressed)
	self:addEventListener("mousereleased", settingsButton._released)
	self:addEventListener("mousecanceled", settingsButton._released)
end

function settingsButton:_pressed(_)
	self.isPressed = true
end

function settingsButton:_released(_)
	self.isPressed = false
end

function settingsButton:render(x, y)
	love.graphics.setColor(color.hexFF6854)
	love.graphics.rectangle("fill", x, y, self.width, self.height)
	love.graphics.setColor(color.white)
	love.graphics.draw(self.text, x + 395, y + 100)
	love.graphics.draw(self.image, x + 5, y + 56, 0, 0.16, 0.16)

	if self.isPressed then
		love.graphics.rectangle("fill", x, y, self.width, self.height)
	end
end

-- End UI stuff

local function makeEnterGamestateFunction(name, noloading)
	if noloading then
		return function()
			return gamestate.enter(nil, name)
		end
	else
		return function()
			return gamestate.enter(loadingInstance.getInstance(), name)
		end
	end
end

local mipmaps = {mipmaps = true}
local mainMenu = gamestate.create {
	fonts = {
		title = {"fonts/Roboto-Regular.ttf", 46},
		playText = {"fonts/Roboto-Regular.ttf", 92},
		menuButton = {"fonts/Roboto-Regular.ttf", 41},
		versionSem = {"fonts/NotoSansCJKjp-Regular.otf", 23},
		versionCodename = {"fonts/NotoSansCJKjp-Regular.otf", 16}
	},
	images = {
		play = {"assets/image/ui/over_the_rainbow/play.png", mipmaps},
		settingsDualGear = {"assets/image/ui/over_the_rainbow/settings_main_menu.png", mipmaps},
		changeUnits = {"assets/image/ui/over_the_rainbow/people_outline_24px_outlined.png", mipmaps}
	},
}

function mainMenu:load()
	glow.clear()

	if not(self.data.titleText) then
		self.data.titleText = love.graphics.newText(self.assets.fonts.title, {
			color.hexFFA73D, "Live ",
			color.white, "Simulator: ",
			color.hexFF4FAE, "2"
		})
	end

	if not(self.data.verSemText) then
		local text = love.graphics.newText(self.assets.fonts.versionSem)
		local ver = "v"..DEPLS_VERSION
		text:add(ver, -self.assets.fonts.versionSem:getWidth(ver), 0)
		self.data.verSemText = text
	end

	if not(self.data.verCodeText) then
		local text = love.graphics.newText(self.assets.fonts.versionSem)
		text:add(DEPLS_VERSION_CODENAME, -self.assets.fonts.versionSem:getWidth(DEPLS_VERSION_CODENAME), 0)
		self.data.verCodeText = text
	end

	if not(self.data.playButton) then
		self.data.playButton = playButton(self)
		self.data.playButton:addEventListener("mousereleased", makeEnterGamestateFunction("beatmapSelect"))
	end
	glow.addElement(self.data.playButton, 46, 28)

	if not(self.data.changeUnitsButton) then
		self.data.changeUnitsButton = changeUnitsButton(self)
		self.data.changeUnitsButton:addEventListener("mousereleased", makeEnterGamestateFunction("changeUnits"))
	end
	glow.addElement(self.data.changeUnitsButton, 497, 29)

	if not(self.data.settingsButton) then
		self.data.settingsButton = settingsButton(self)
		self.data.settingsButton:addEventListener("mousereleased", makeEnterGamestateFunction("settings"))
	end
	glow.addElement(self.data.settingsButton, 497, 207)

	if not(self.data.background) then
		self.data.background = backgroundLoader.load(2)
	end

	if not(self.data.grayGradient) then
		self.data.grayGradient = util.gradient("vertical", color.transparent, color.hex6A6767F0)
	end
end

-- Title text "{ffa73d}Live {ffffff}Simulator: {ff4fae}2" is in 38x584 (text "title")
-- Version semantic is in 921x578 (text "versionSem")
-- Version codename is in 923x604 (text "verionCodename")

function mainMenu:draw()
	love.graphics.setColor(color.white)
	love.graphics.draw(self.data.background)
	love.graphics.draw(self.data.grayGradient, -90, 576, 0, 1140, 64, 0, 0)
	love.graphics.draw(self.data.titleText, 38, 584)
	love.graphics.draw(self.data.verSemText, 921, 578)
	love.graphics.draw(self.data.verCodeText, 923, 604)
	return glow.draw()
end

return mainMenu