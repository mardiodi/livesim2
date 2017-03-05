-- Added score, update routine using the new EffectPlayer
local tween = require("tween")
local DEPLS = ({...})[1]
local ScoreNode = {}

local _common_meta = {__index = ScoreNode}
local graphics = love.graphics

function ScoreNode.Create(score)
	local out = {}
	local Images = DEPLS.Images
	
	out.score_canvas = graphics.newCanvas(500, 32)
	out.score_info = {opacity = 0, scale = 0.9, x = 530}
	out.opacity_tw = tween.new(100, out.score_info, {opacity = 255})
	out.scale_tw = tween.new(200, out.score_info, {scale = 1}, "inOutSine")
	out.xpos_tw = tween.new(250, out.score_info, {x = 570}, "outSine")
	out.elapsed_time = 0
	
	-- Draw all in canvas
	graphics.setCanvas(out.score_canvas)
	graphics.setBlendMode("alpha", "premultiplied")
	graphics.setColor(255, 255, 255, DEPLS.LiveOpacity)
	graphics.draw(Images.ScoreNode.Plus)
	
	do
		local i = 1
		for w in tostring(score):gmatch("%d") do
			graphics.draw(Images.ScoreNode[tonumber(w)], i * 24, 0)
			i = i + 1
		end
	end
	
	graphics.setColor(255, 255, 255, 255)
	graphics.setBlendMode("alpha")
	graphics.setCanvas()
	
	return setmetatable(out, _common_meta)
end
jit.off(ScoreNode.Create)

function ScoreNode.Update(this, deltaT)
	this.xpos_tw:update(deltaT)
	this.opacity_tw:update(this.elapsed_time > 350 and -deltaT or deltaT)
	this.scale_tw:update(this.elapsed_time > 200 and -deltaT or deltaT)
	
	this.elapsed_time = this.elapsed_time + deltaT
	
	return this.elapsed_time >= 500
end

function ScoreNode.Draw(this)
	graphics.setColor(255, 255, 255, this.score_info.opacity * DEPLS.LiveOpacity / 255)
	graphics.draw(this.score_canvas, this.score_info.x, 72, 0, this.score_info.scale, this.score_info.scale, 0, 16)
	graphics.setColor(255, 255, 255, 255)
end
jit.off(ScoreNode.Draw)

return ScoreNode