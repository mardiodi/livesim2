-- Language Setting
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")

local color = require("color")
local gamestate = require("gamestate")
local mainFont = require("font")
local util = require("util")
local L = require("language")

local backgroundLoader = require("game.background_loader")

local glow = require("game.afterglow")
local backNavigation = require("game.ui.back_navigation")
local longButtonUI = require("game.ui.long_button")

local gameLang = gamestate.create {
	fonts = {},
	images = {},
}

local restartButton = {"Yes", "No", enterbutton = 1, escapebutton = 2}

local function updateLanguagString(text, lang)
	text:clear()
	util.addTextWithShadow(text, L("setting:language:current", lang), 0, 0)
end

local function setLanguage(_, value)
	L.set(value.language.code)
	value.instance.persist.currentLanguage = value.language.code
	return updateLanguagString(value.instance.persist.languageText, value.language)
end

local function leave()
	return gamestate.leave(nil)
end

function gameLang:load()
	glow.clear()

	if self.persist.languageText == nil then
		self.persist.languageText = love.graphics.newText(mainFont.get(26))
	end

	if self.data.buttonFrame == nil then
		local frame = glow.frame(101, 50, 800, 546)
		for i, v in ipairs(L.enum()) do
			local elem = longButtonUI(v.name)
			elem:addEventListener("mousereleased", setLanguage)
			elem:setData({language = v, instance = self})
			frame:addElement(elem, 0, (i - 1) * 78)
		end
		self.data.buttonFrame = frame
	end
	glow.addFrame(self.data.buttonFrame)

	if self.data.background == nil then
		self.data.background = backgroundLoader.load(14)
	end

	if self.data.back == nil then
		self.data.back = backNavigation(L"setting:language")
		self.data.back:addEventListener("mousereleased", function()
			if
				self.persist.currentLanguage ~= self.persist.previousLanguage and
				util.compareLOVEVersion(0, 10, 2) >= 0 and
				love.window.showMessageBox("Restart", L"setting:language:restart", restartButton, "info") == 1
			then
				love.event.quit("restart")
			end

			return leave()
		end)
	end
	glow.addFixedElement(self.data.back, 0, 0)
end

function gameLang:start()
	self.persist.previousLanguage = L.get()
	self.persist.currentLanguage = self.persist.previousLanguage
	for _, v in ipairs(L.enum()) do
		if v.code == self.persist.previousLanguage then
			return updateLanguagString(self.persist.languageText, v)
		end
	end
end

function gameLang:update(dt)
	return self.data.buttonFrame:update(dt)
end

function gameLang:draw()
	love.graphics.setColor(color.white)
	love.graphics.draw(self.data.background)
	love.graphics.draw(self.persist.languageText, 480, 8)

	self.data.buttonFrame:draw()
	glow.draw()
end

gameLang:registerEvent("keyreleased", function(_, key)
	if key == "escape" then
		leave()
	end
end)

return gameLang
