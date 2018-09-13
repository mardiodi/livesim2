-- Default SIF Live UI
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local Luaoop = require("libs.Luaoop")
local lily = require("libs.lily")
local timer = require("libs.hump.timer")
local vector = require("libs.hump.vector")
local assetCache = require("asset_cache")
local async = require("async")
local color = require("color")
local uibase = require("game.live.uibase")
local sifui = Luaoop.class("livesim2.SIFLiveUI", uibase)

-- luacheck: no max line length

-----------------
-- Base system --
-----------------

local scoreAddTweenTarget = {{x = 570, scale = 1}, {opacity = 0}}

function sifui:__construct()
	-- as per uibase definition, constructor can use
	-- any asynchronous operation (async lib)
	local fontImageDataList = lily.loadMulti({
		{lily.newImageData, "assets/image/live/score_num/score.png"},
		{lily.newImageData, "assets/image/live/score_num/addscore.png"},
		{lily.newImageData, "assets/image/live/hp_num.png"}
	})
	self.timer = timer.new()
	self.images = assetCache.loadMultipleImages({
		-- live header
		"assets/image/live/live_header.png", -- 1
		"assets/image/live/live_pause.png",
		-- score gauge
		"assets/image/live/live_gauge_03_02.png", -- 3
		"assets/image/live/live_gauge_03_03.png",
		"assets/image/live/live_gauge_03_04.png",
		"assets/image/live/live_gauge_03_05.png",
		"assets/image/live/live_gauge_03_06.png",
		"assets/image/live/live_gauge_03_07.png",
		"assets/image/live/l_gauge_17.png",
		-- scoring
		"assets/image/live/l_etc_46.png", -- 10
		"assets/image/live/ef_318_000.png",
		-- stamina
		"assets/image/live/live_gauge_02_01.png", -- 12
		"assets/image/live/live_gauge_02_02.png",
		"assets/image/live/live_gauge_02_03.png",
		"assets/image/live/live_gauge_02_04.png",
		"assets/image/live/live_gauge_02_05.png",
		"assets/image/live/live_gauge_02_06.png",
		-- effects
		"assets/image/live/circleeffect.png", -- 18
		"assets/image/live/ef_308.png",
		"noteImage:assets/image/tap_circle/notes.png",
		-- judgement
		"assets/image/live/ef_313_004_w2x.png", -- 21
		"assets/image/live/ef_313_003_w2x.png",
		"assets/image/live/ef_313_002_w2x.png",
		"assets/image/live/ef_313_001_w2x.png",
		"assets/image/live/ef_313_000_w2x.png",
		-- combo
		"assets/image/live/combo/1.png", -- 22
		"assets/image/live/combo/2.png",
		"assets/image/live/combo/3.png",
		"assets/image/live/combo/4.png",
		"assets/image/live/combo/5.png",
		"assets/image/live/combo/6.png",
		"assets/image/live/combo/7.png",
		"assets/image/live/combo/8.png",
		"assets/image/live/combo/9.png",
		"assets/image/live/combo/10.png",
	}, {mipmaps = true})
	while fontImageDataList:isComplete() == false do
		async.wait()
	end
	-- fonts
	self.scoreFont = love.graphics.newImageFont(fontImageDataList:getValues(1), "0123456789", -4)
	self.addScoreFont = love.graphics.newImageFont(fontImageDataList:getValues(2), "0123456789+", -5)
	self.staminaFont = love.graphics.newImageFont(fontImageDataList:getValues(3), "0123456789+- ")
	-- quads
	self.comboQuad = {
		[0] = love.graphics.newQuad(0, 0, 48, 48, 240, 130),
		love.graphics.newQuad(48, 0, 48, 48, 240, 130),
		love.graphics.newQuad(96, 0, 48, 48, 240, 130),
		love.graphics.newQuad(144, 0, 48, 48, 240, 130),
		love.graphics.newQuad(192, 0, 48, 48, 240, 130),
		love.graphics.newQuad(0, 48, 48, 48, 240, 130),
		love.graphics.newQuad(48, 48, 48, 48, 240, 130),
		love.graphics.newQuad(96, 48, 48, 48, 240, 130),
		love.graphics.newQuad(144, 48, 48, 48, 240, 130),
		love.graphics.newQuad(192, 48, 48, 48, 240, 130),
		combo = love.graphics.newQuad(0, 96, 123, 34, 240, 130)
	}
	-- variable setup
	self.opacity = 1
	self.textScaling = 1
	self.minimalEffect = false
	self.noteIconTime = 0
	self.noteIconQuad = {
		notation = love.graphics.newQuad(0, 0, 108, 104, 256, 128),
		circle = love.graphics.newQuad(128, 0, 68, 68, 256, 128)
	}
	self.tapEffectList = {}
	self.tapEffectQuad = {
		star = love.graphics.newQuad(0, 1948, 100, 100, 2048, 2048),
		circle = love.graphics.newQuad(100, 1973, 75, 75, 2048, 2048)
	}
	-- score variable setup
	self.currentScore = 0
	self.currentScoreAdd = 0 -- also as dirty flag
	self.currentScoreText = love.graphics.newText(self.scoreFont, "0")
	self.scoreBorders = {1, 2, 3, 4}
	self.scoreAddAnimationList = {}
	self.scoreFlashTimer = nil
	self.scoreFlashScale = 1
	self.scoreFlashOpacity = 1
	self.scoreBarFlashTimer = nil
	self.scoreBarFlashOpacity = 0
	self.scoreIsMax = false
	self.scoreBarImage = self.images[4]
	self.scoreBarQuad = love.graphics.newQuad(0, 0, 880, 38, 880, 38)
	self.scoreBarQuad:setViewport(0, 0, 42, 38)
	-- combo variable setup
	self.currentCombo = 0
	self.maxCombo = 0
	self.comboSpriteBatch = love.graphics.newSpriteBatch(self.images[26], 12, "stream")
	self.currentComboTextureIndex = 1
	self.comboNumberScale1 = 1.15
	self.comboNumberScale2 = 1.25
	self.comboNumberOpacity2 = 0.5
	self.comboNumberTimer = nil
	self.comboNumberTimer2 = nil
	-- SB pre-allocate (combo)
	for _ = 1, 12 do
		self.comboSpriteBatch:add(0, 0, 0, 0, 0)
	end
	-- judgement system variable setup
	self.judgementCenterPosition = {
		[self.images[21]] = {198, 38},
		[self.images[22]] = {147, 35},
		[self.images[23]] = {127, 35},
		[self.images[24]] = {86, 33},
		[self.images[25]] = {93, 30}
	}
	self.currentJudgement = self.images[21]
	self.judgementOpacity = 0
	self.judgementScale = 0
	self.judgementTimer = nil
	do
		local target = {judgementOpacity = 1, judgementScale = 1}
		local target2 = {judgementOpacity = 0}
		local showTimer, delayTimer, hideTimer
		self.judgementResetTimer = function()
			if showTimer then
				self.timer:cancel(showTimer)
			end
			if delayTimer then
				self.timer:cancel(delayTimer)
			end
			if hideTimer then
				self.timer:cancel(hideTimer)
			end

			self.judgementOpacity = 0
			self.judgementScale = 0
		end
		local hideFunc = function()
			self.judgementOpacity = 1
			hideTimer = self.timer:tween(0.2, self, target2)
		end
		local delayFunc = function()
			delayTimer = self.timer:after(0.17, hideFunc)
		end
		self.judgementStartTimer = function()
			showTimer = self.timer:tween(0.05, self, target, "out-sine", delayFunc)
		end
	end
	-- stamina
	self.maxStamina = 45
	self.stamina = 45
	self.staminaInterpolate = 45
	self.staminaLerpVal = 1
	self.staminaMode = 1
	self.staminaTimer = nil
	self.staminaQuad = love.graphics.newQuad(0, 0, 271, 29, 271, 29)
	self.staminaImage = self.images[13]
	self.staminaFlashTime = 0 -- limits at 1
	self.staminaAddText = love.graphics.newText(self.staminaFont, "+ 1")
	self.staminaText = love.graphics.newText(self.staminaFont, "45")
	-- pause system
	self.pauseEnabled = true
end

function sifui:update(dt)
	-- timer
	self.timer:update(dt)
	-- score effect
	if self.currentScoreAdd > 0 then
		if not(self.minimalEffect) then
			local emptyObj
			-- get unused one first
			for i = 1, #self.scoreAddAnimationList do
				local obj = self.scoreAddAnimationList[i]
				if obj.done then
					emptyObj = table.remove(self.scoreAddAnimationList, i)
					break
				end
			end

			if not(emptyObj) then
				-- create new one
				emptyObj = {
					timerHandle = nil,
					done = false,
					text = love.graphics.newText(self.addScoreFont),
					opacity = 1,
					scale = 1.125,
					x = 520,
				}
				emptyObj.func = function(wait)
					self.timer:tween(0.1, emptyObj, scoreAddTweenTarget[1])
					wait(0.2)
					self.timer:tween(0.2, emptyObj, scoreAddTweenTarget[2])
					wait(0.2)
					emptyObj.done = true
				end
			end

			-- set displayed text
			emptyObj.text:clear()
			emptyObj.text:add("+"..self.currentScoreAdd)
			-- start timer
			emptyObj.done = false
			emptyObj.opacity = 1
			emptyObj.scale = 1.125
			emptyObj.x = 520
			emptyObj.timerHandle = self.timer:script(emptyObj.func)
			-- insert
			self.scoreAddAnimationList[#self.scoreAddAnimationList + 1] = emptyObj
		end
		-- reset flag
		self.currentScoreAdd = 0
	end
	-- combo counter
	if self.currentCombo > 0 then
		-- set "combo" text
		self.comboSpriteBatch:setColor(color.compat(255, 255, 255, self.comboNumberOpacity2))
		self.comboSpriteBatch:set(2, self.comboQuad.combo, 61, -54, 0, self.comboNumberScale2, self.comboNumberScale2, 61, 17)
		self.comboSpriteBatch:setColor(color.white[1], color.white[2], color.white[3])
		self.comboSpriteBatch:set(1, self.comboQuad.combo, 61, -54, 0, self.comboNumberScale1, self.comboNumberScale1, 61, 17)
		-- set numbers
		local num = self.currentCombo
		local i = 3
		while num > 0 do
			self.comboSpriteBatch:set(
				i, self.comboQuad[num % 10],
				-29 - (i - 3) * 43, -53, 0,
				self.comboNumberScale1, self.comboNumberScale1, 24, 24
			)
			num = math.floor(num * 0.1)
			i = i + 1
		end
	end
	-- stamina
	local noteiconMultipler = 1
	local staminaPercentage = self.staminaInterpolate / self.maxStamina
	if staminaPercentage >= 0.8 then
		self.staminaImage = self.images[13]
	elseif staminaPercentage >= 0.6 then
		self.staminaImage = self.images[14]
	elseif staminaPercentage >= 0.4 then
		self.staminaImage = self.images[15]
	elseif staminaPercentage >= 0.2 then
		self.staminaImage = self.images[16]
		noteiconMultipler = 4
	elseif staminaPercentage > 0 then
		self.staminaImage = self.images[17]
		noteiconMultipler = 8
	else
		noteiconMultipler = 8
		self.staminaImage = nil
	end
	self.staminaFlashTime = (self.staminaFlashTime + dt) % 1
	self.staminaQuad:setViewport(0, 0, 36 + 235 * staminaPercentage, 29)
	-- note icon
	self.noteIconTime = self.noteIconTime + dt * noteiconMultipler
	while self.noteIconTime >= 2.2 do
		self.noteIconTime = self.noteIconTime - 2.2
	end
end

function sifui.getNoteSpawnPosition()
	return vector(480, 160)
end

function sifui.getLanePosition()
	return {
		vector(816+64, 96+64 ),
		vector(785+64, 249+64),
		vector(698+64, 378+64),
		vector(569+64, 465+64),
		vector(416+64, 496+64),
		vector(262+64, 465+64),
		vector(133+64, 378+64),
		vector(46+64 , 249+64),
		vector(16+64 , 96+64 ),
	}
end

--------------------
-- Scoring System --
--------------------

local flashTweenTarget = {scoreFlashScale = 1.6, scoreFlashOpacity = 0}
local barFlashTweenTarget = {scoreBarFlashOpacity = 0}

function sifui:setScoreRange(c, b, a, s)
	self.scoreBorders[1], self.scoreBorders[2], self.scoreBorders[3], self.scoreBorders[4] = c, b, a, s
end

function sifui:addScore(amount)
	amount = math.floor(amount)
	self.currentScore = self.currentScore + amount
	self.currentScoreAdd = self.currentScoreAdd + amount

	-- update text
	self.currentScoreText:clear()
	self.currentScoreText:add(tostring(self.currentScore))
	-- replay score flash
	if self.scoreFlashTimer then
		self.timer:cancel(self.scoreFlashTimer)
		self.scoreFlashScale = 1
		self.scoreFlashOpacity = 1
	end
	self.scoreFlashTimer = self.timer:tween(0.5, self, flashTweenTarget, "out-sine")
	-- update score quad
	if self.currentScore >= self.scoreBorders[4] and not(self.scoreIsMax) then
		-- S score
		self.scoreIsMax = true
		self.scoreBarImage = self.images[8]
		self.scoreBarQuad:setViewport(0, 0, 880, 38)
		-- add timer for S score flashing effect
		if self.scoreBarFlashTimer then
			self.timer:cancel(self.scoreBarFlashTimer)
		end
		self.scoreBarFlashTimer = self.timer:script(function(wait)
			local target = {scoreBarFlashOpacity = 0.5}
			while true do
				self.scoreBarFlashOpacity = 0.75
				self.timer:tween(1, self, target)
				wait(1)
			end
		end)
	elseif not(self.scoreIsMax) then
		local w
		-- calculate viewport width
		if self.currentScore >= self.scoreBorders[3] then
			-- A score
			w = 790 + math.floor((self.scoreBorders[3] - self.currentScore) / (self.scoreBorders[3] - self.scoreBorders[4]) * 84 + 0.5)
			self.scoreBarImage = self.images[7]
		elseif self.currentScore >= self.scoreBorders[2] then
			-- B score
			w = 665 + math.floor((self.scoreBorders[2] - self.currentScore) / (self.scoreBorders[2] - self.scoreBorders[3]) * 125 + 0.5)
			self.scoreBarImage = self.images[6]
		elseif self.currentScore >= self.scoreBorders[1] then
			-- C score
			w = 502 + math.floor((self.scoreBorders[1] - self.currentScore) / (self.scoreBorders[1] - self.scoreBorders[2]) * 163 + 0.5)
			self.scoreBarImage = self.images[5]
		else
			-- No score
			w = 42 + math.floor(self.currentScore / self.scoreBorders[1] * 460 + 0.5)
			self.scoreBarImage = self.images[4]
		end

		-- set quad viewport
		self.scoreBarQuad:setViewport(0, 0, w, 38)
		-- reset score bar flash effect (non-S score)
		if self.scoreBarFlashTimer then
			self.timer:cancel(self.scoreBarFlashTimer)
			self.scoreBarFlashOpacity = 1
		end
		self.scoreBarFlashTimer = self.timer:tween(0.5, self, barFlashTweenTarget)
	end
end

function sifui:getScore()
	return self.currentScore
end

------------------
-- Combo System --
------------------

local comboNumber1Target = {comboNumberScale1 = 1}
local comboNumber2Target = {comboNumberScale2 = 1.65, comboNumberOpacity2 = 0}

local function getComboNumberIndex(combo)
	if combo < 50 then
		-- 0-49
		return 1
	elseif combo < 100 then
		-- 50-99
		return 2
	elseif combo < 200 then
		-- 100-199
		return 3
	elseif combo < 300 then
		-- 200-299
		return 4
	elseif combo < 400 then
		-- 300-399
		return 5
	elseif combo < 500 then
		-- 400-499
		return 6
	elseif combo < 600 then
		-- 500-599
		return 7
	elseif combo < 1000 then
		-- 600-999
		return 8
	elseif combo < 2000 then
		-- 1000-1999
		return 9
	else
		-- >= 2000
		return 10
	end
end

function sifui:comboJudgement(judgement, addcombo)
	local breakCombo = false

	if judgement == "perfect" then
		self.currentJudgement = self.images[21]
	elseif judgement == "great" then
		self.currentJudgement = self.images[22]
	elseif judgement == "good" then
		self.currentJudgement = self.images[23]
		breakCombo = true
	elseif judgement == "bad" then
		self.currentJudgement = self.images[24]
		breakCombo = true
	elseif judgement == "miss" then
		self.currentJudgement = self.images[25]
		breakCombo = true
	else
		error("invalid judgement '"..judgement.."'", 2)
	end

	-- reset judgement animation
	self.judgementResetTimer()
	self.judgementStartTimer()

	if breakCombo then
		-- break combo
		-- clear all numbers in SB
		for i = 3, 12 do
			self.comboSpriteBatch:set(i, 0, 0, 0, 0, 0)
		end
		-- reset texture
		self.currentComboTextureIndex = 1
		self.comboSpriteBatch:setTexture(self.images[26])
	elseif addcombo then
		-- increment combo
		self.currentCombo = self.currentCombo + 1
		self.maxCombo = math.max(self.maxCombo, self.currentCombo)

		-- set combo texture when needed
		local idx = getComboNumberIndex(self.currentCombo)
		if self.currentComboTextureIndex ~= idx then
			self.comboSpriteBatch:setTexture(self.images[25 + idx])
			self.currentComboTextureIndex = idx
		end

		-- animate combo
		if self.comboNumberTimer then
			self.timer:cancel(self.comboNumberTimer)
			self.comboNumberScale1 = 1.15
		end
		if self.comboNumberTimer2 then
			self.timer:cancel(self.comboNumberTimer2)
			self.comboNumberScale2 = 1.25
			self.comboNumberOpacity2 = 0.5
		end
		self.comboNumberTimer = self.timer:tween(0.15, self, comboNumber1Target, "in-out-sine")
		self.comboNumberTimer2 = self.timer:tween(0.33, self, comboNumber2Target)
	end
end

function sifui:getCurrentCombo()
	return self.currentCombo
end

function sifui:getMaxCombo()
	return self.maxCombo
end

-------------
-- Stamina --
-------------

function sifui:setMaxStamina(val)
	self.maxStamina = math.min(assert(val > 0 and val, "invalid value"), 99)
end

function sifui:getMaxStamina()
	return self.maxStamina
end

function sifui:getStamina()
	return self.stamina
end

function sifui:addStamina(val)
	val = math.floor(val)
	if val == 0 then return end

	-- set up timer
	self.staminaMode = val
	if self.staminaTimer then
		self.timer:cancel(self.staminaTimer)
	end
	self.staminaLerpVal = 0
	self.stamina = math.max(math.min(self.stamina + val, self.maxStamina), 0)
	self.staminaTimer = self.timer:tween(1, self, {staminaLerpVal = 1, staminaInterpolate = self.stamina})
	self.staminaText:clear()
	self.staminaText:add(string.format("%2d", self.stamina))
	self.staminaAddText:clear()
	self.staminaAddText:add((val > 0 and "+" or "-")..string.format("%2d", math.abs(val)))
end

------------------
-- Pause button --
------------------

function sifui:enablePause()
	self.pauseEnabled = true
end

function sifui:disablePause()
	self.pauseEnabled = false
end

function sifui.checkPause(_, x, y)
	return x >= 898 and y >= -12 and x < 970 and y < 60
end

------------------
-- Other things --
------------------

local starEffectTweenTarget = {starEffectOpacity = 0, starEffectScale = 2.6}
local circle1TweenTarget = {circle1Opacity = 0, circle1Scale = 4}
local circle2TweenTarget = {circle2Opacity = 0, circle2Scale = 4}
local circle3TweenTarget = {circle3Opacity = 0, circle3Scale = 4}

function sifui:addTapEffect(x, y, r, g, b, a)
	local tap
	for i = 1, #self.tapEffectList do
		local w = self.tapEffectList[i]
		if w.done then
			tap = table.remove(self.tapEffectList, i)
			break
		end
	end

	if not(tap) then
		tap = {
			x = 0, y = 0, r = 255, g = 255, b = 255,
			opacity = 1,
			starEffectOpacity = 1,
			starEffectScale = 2,
			circle1Opacity = 1,
			circle1Scale = 2.427,
			circle2Opacity = 1,
			circle2Scale = 2.427,
			circle3Opacity = 1,
			circle3Scale = 2.427,
			done = false
		}
		tap.func = function()
			tap.done = true
		end
	end

	tap.x, tap.y, tap.r, tap.g, tap.b = x, y, r, g, b
	tap.opacity = a
	tap.starEffectOpacity = 1
	tap.starEffectScale = 2
	tap.circle1Opacity = 1
	tap.circle1Scale = 2.427
	tap.circle2Opacity = 1
	tap.circle2Scale = 2.427
	tap.circle3Opacity = 1
	tap.circle3Scale = 2.427
	tap.timer = self.timer:script(tap.func)
	tap.done = false
	self.timer:tween(0.8, tap, starEffectTweenTarget, "out-expo", tap.func)
	self.timer:tween(0.2, tap, circle1TweenTarget, "out-expo")
	self.timer:tween(0.45, tap, circle2TweenTarget, "out-expo")
	self.timer:tween(0.7, tap, circle3TweenTarget, "out-expo")

	self.tapEffectList[#self.tapEffectList + 1] = tap
end

function sifui:setOpacity(opacity)
	self.opacity = opacity
end

function sifui:setMinimalEffect(min)
	self.minimalEffect = min
end

-------------
-- Drawing --
-------------

local function triangle(x)
	return math.abs((x - 1) % 4 - 2) - 1
end

function sifui:drawHeader()
	-- draw live header
	love.graphics.setColor(color.compat(255, 255, 255, self.opacity))
	love.graphics.draw(self.images[1])
	love.graphics.draw(self.images[3], 5, 8, 0, 0.99545454, 0.86842105)
	-- score bar
	love.graphics.draw(self.scoreBarImage, self.scoreBarQuad, 5, 8, 0, 0.99545454, 0.86842105)
	if self.scoreIsMax then
		love.graphics.setColor(color.compat(255, 255, 255, self.scoreBarFlashOpacity * self.opacity))
		love.graphics.draw(self.images[11], 36, 3)
	elseif self.scoreBarFlashOpacity > 0 then
		love.graphics.setColor(color.compat(255, 255, 255, self.scoreBarFlashOpacity * self.opacity))
		love.graphics.draw(self.images[9], 5, 8)
	end
	-- score number
	love.graphics.setColor(color.compat(255, 255, 255, self.opacity))
	love.graphics.draw(self.currentScoreText, 476, 53, 0, 1, 1, self.currentScoreText:getWidth() * 0.5, 0)
	-- score flash
	if self.scoreBarFlashOpacity > 0 then
		love.graphics.setColor(color.compat(255, 255, 255, self.opacity * self.scoreFlashOpacity))
		love.graphics.draw(self.images[10], 484, 72, 0, self.scoreFlashScale, self.scoreFlashScale, 159, 34)
	end
	-- score add effect
	for i = #self.scoreAddAnimationList, 1, -1 do
		local obj = self.scoreAddAnimationList[i]
		if obj.done then break end
		love.graphics.setColor(color.compat(255, 255, 255, self.opacity * obj.opacity))
		love.graphics.draw(obj.text, obj.x, 72, 0, obj.scale, obj.scale, 0, 16)
	end
	-- stamina (confusion & some edge case incoming)
	local stOff = 0
	local stRedTint = 255
	local stGreenTint = 255
	if self.staminaMode < 0 then
		-- control the offset
		local d = self.staminaLerpVal * 2
		local e = d * 2
		stOff = triangle(e * 4) * 4
		stRedTint = 255 * math.max(math.abs(math.sin(d * math.pi)), math.abs(math.cos(d * math.pi)))
	elseif self.staminaMode > 0 then
		stGreenTint = 127 + (1 - math.sin(self.staminaLerpVal * math.pi)) * 128
	end
	love.graphics.setColor(color.compat(255, stRedTint, stRedTint, self.opacity))
	love.graphics.draw(self.images[12], 16 + stOff, 62 + stOff)
	if self.staminaImage then
		-- if it's yellow, then 2Hz. if it's red, then 4Hz
		local freq = 0
		if self.staminaImage == self.images[17] then
			-- red
			freq = 4
		elseif self.staminaImage == self.images[16] then
			-- yellow
			freq = 2
		end

		-- flash to black, in range 64...255
		local col = math.cos(self.staminaFlashTime * math.pi * freq) * 0.5 + 0.5
		love.graphics.setColor(color.compat(255, stRedTint, stRedTint, self.opacity * col))
		love.graphics.draw(self.staminaImage, self.staminaQuad, 16 + stOff, 62 + stOff)
	end
	love.graphics.draw(self.staminaText, 306, 64)
	love.graphics.setColor(color.compat(stGreenTint, 255, stGreenTint, self.opacity * math.sin(self.staminaLerpVal * math.pi)))
	love.graphics.draw(self.staminaAddText, 290, 90)
end

function sifui:drawStatus()
	-- judgement
	if self.judgementOpacity > 0 then
		love.graphics.setColor(color.compat(255, 255, 255, self.judgementOpacity * self.opacity))
		love.graphics.draw(
			self.currentJudgement, 480, 320, 0,
			self.judgementScale * self.textScaling,
			self.judgementScale * self.textScaling,
			self.judgementCenterPosition[self.currentJudgement][1],
			self.judgementCenterPosition[self.currentJudgement][2]
		)
	end

	-- combo
	if self.currentCombo > 0 then
		love.graphics.setColor(color.compat(255, 255, 255, self.opacity))
		love.graphics.draw(self.comboSpriteBatch, 480, 320 - 8 * (1 - self.textScaling), 0, self.textScaling)
	end
	-- note icon
	do
		-- draw circles (each needs 1.6s with 0s, 0.3s, and 0.6s delay respectively)
		for i = 0, 600, 300 do
			-- this value is used for scaling and opacity
			local v = math.min(math.max(self.noteIconTime - (i * 0.001), 0) / 1.6, 1)
			if v > 0 then
				local s = v * 1.9 + 0.6
				love.graphics.setColor(color.compat(255, 255, 255, self.opacity * (1-v)))
				love.graphics.draw(self.images[19], self.noteIconQuad.circle, 480, 160, 0, s, s, 34, 34)
			end
		end
		-- Note icon notation is pulsating indicator.
		-- It's scaling down to 0.8 first (tween in 0.8s) then back to 1 (tween in 1.4s)
		-- which gives total of 2.2 seconds elapsed time.
		local secondScale = timer.tween["out-sine"](math.max(self.noteIconTime - 0.8, 0) / 1.4) * 0.2
		local scale = 1 - math.min(self.noteIconTime, 0.8) / 4 + secondScale
		love.graphics.setColor(color.compat(255, 255, 255, self.opacity))
		love.graphics.draw(self.images[19], self.noteIconQuad.notation, 480, 160, 0, scale, scale, 54, 52)
	end

	-- tap effect
	for i = #self.tapEffectList, 1, -1 do
		local tap = self.tapEffectList[i]
		if tap.done then break end
		if tap.starEffectOpacity > 0 then
			love.graphics.setColor(color.compat(
				255 * tap.r / 255,
				255 * tap.g / 255,
				255 * tap.b / 255,
				tap.starEffectOpacity * tap.opacity * self.opacity
			))
			love.graphics.draw(self.images[20], self.tapEffectQuad.star, tap.x, tap.y, 0, tap.starEffectScale, tap.starEffectScale, 50, 50)
		end
		if tap.circle1Opacity > 0 then
			love.graphics.setColor(color.compat(
				255 * tap.r / 255,
				255 * tap.g / 255,
				255 * tap.b / 255,
				tap.circle1Opacity * tap.opacity * self.opacity
			))
			love.graphics.draw(self.images[20], self.tapEffectQuad.circle, tap.x, tap.y, 0, tap.circle1Scale, tap.circle1Scale, 37.5, 37.5)
		end
		if tap.circle2Opacity > 0 then
			love.graphics.setColor(color.compat(
				255 * tap.r / 255,
				255 * tap.g / 255,
				255 * tap.b / 255,
				tap.circle2Opacity * tap.opacity * self.opacity
			))
			love.graphics.draw(self.images[20], self.tapEffectQuad.circle, tap.x, tap.y, 0, tap.circle2Scale, tap.circle2Scale, 37.5, 37.5)
		end
		if tap.circle3Opacity > 0 then
			love.graphics.setColor(color.compat(
				255 * tap.r / 255,
				255 * tap.g / 255,
				255 * tap.b / 255,
				tap.circle3Opacity * tap.opacity * self.opacity
			))
			love.graphics.draw(self.images[20], self.tapEffectQuad.circle, tap.x, tap.y, 0, tap.circle3Scale, tap.circle3Scale, 37.5, 37.5)
		end
	end
end

return sifui