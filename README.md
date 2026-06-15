# 💕🪟 LovePanels

A minimalistic UI module for [love2d](https://github.com/love2d/love).  
Arrange your interface into padded panels (with a simple HTML-like markup
definition) that keep their ratios when resizing the window.


<img src="./output.gif"/>

<br/>

```lua
-- panelsmarkup.lua

return [[
<root direction="horizontal" padding="4">
    <leftcontainer>
        <foo padding="8" direction="vertical">
            <bar></bar>
            <bar></bar>
        </foo>
    </leftcontainer>
    <rightcontainer direction="horizontal" padding="4">
        <foo ratio="2"></foo>
        <foo ratio="3"></foo>
    </rightcontainer>
</root>
]]
```

```lua
--- main.lua

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
```

#### Ratio

The `ratio` attribute works like flex in CSS. Every panel has default
`ratio="1"`. Panels occupy `(parent - padding) * ratio / sum(children_ratios)`

#### Tags

Since all panels have the same role and properties (unlike HTML elements) the
tag is used as an ID for the panel (`<someid/>`) To avoid ID collisions, an
increasing numerical index is appended to duplicate IDs.

## Credits

Parsing is handled by
[HTML2Table -by RicardoTM](https://forum.rainmeter.net/viewtopic.php?t=44955#p231448).
