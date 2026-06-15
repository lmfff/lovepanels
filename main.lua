local lovepanels = require("lovepanels")
local panelsmarkup = require("panelsmarkup")

local panels

function love.load()
    panels = lovepanels.parse(panelsmarkup)
end

function love.draw()
    lovepanels.draw_debug(panels)
end

function love.resize()
    lovepanels.process(panels)
end
