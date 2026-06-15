local lovepanels = {}
local html2table = require("HTML2Table")

lovepanels.parse = function(panels_string)
    local panels_table = {}
    panels_table.tree = html2table.toTable(panels_string)
    panels_table.flat = lovepanels.process(panels_table)
    return panels_table
end

lovepanels.process = function(panels)
    local flat_panels = {}
    local root = panels.tree[1]

    local dup_count = {}

    -- Breadth-first search
    local q = {}
    table.insert(q, root)

    while q[1] do
        local node = table.remove(q)

        if not node.parent then
            node.x = 0
            node.y = 0
            node.w = love.graphics.getWidth()
            node.h = love.graphics.getHeight()
        else
            if node.parent.attributes.direction == "horizontal" then
                if not node.prev_sibling then
                    node.x = node.parent.x +
                        (math.min(root.w, root.h) * node.parent.attributes.padding * 0.01)
                    if not node.next_sibling then
                        node.w = (
                            node.parent.w
                            * (tonumber(node.attributes.ratio) / node.parent.total_children_ratio)
                            - (math.min(root.w, root.h) * node.parent.attributes.padding * 0.01) * 2
                        )
                    else
                        node.w = (
                            node.parent.w
                            * (tonumber(node.attributes.ratio) / node.parent.total_children_ratio)
                            - (math.min(root.w, root.h) * node.parent.attributes.padding * 0.01)
                        )
                    end
                else
                    node.x = node.prev_sibling.x + node.prev_sibling.w
                    node.w = (
                        node.parent.w
                        * (tonumber(node.attributes.ratio) / node.parent.total_children_ratio)
                        - (math.min(root.w, root.h) * node.parent.attributes.padding * 0.01)
                    )
                end
                node.y = node.parent.y + (math.min(root.w, root.h) * node.parent.attributes.padding * 0.01)
                node.h = (
                    node.parent.h
                    - (math.min(root.w, root.h) * node.parent.attributes.padding * 0.01) * 2
                )
            elseif node.parent.attributes.direction == "vertical" then
                if not node.prev_sibling then
                    node.y = node.parent.y +
                        (math.min(root.w, root.h) * node.parent.attributes.padding * 0.01)
                    if not node.next_sibling then
                        node.h = (
                            node.parent.h
                            * (tonumber(node.attributes.ratio) / node.parent.total_children_ratio)
                            - (math.min(root.w, root.h) * node.parent.attributes.padding * 0.01) * 2
                        )
                    else
                        node.h = (
                            node.parent.h
                            * (tonumber(node.attributes.ratio) / node.parent.total_children_ratio)
                            - (math.min(root.w, root.h) * node.parent.attributes.padding * 0.01)
                        )
                    end
                else
                    node.y = node.prev_sibling.y + node.prev_sibling.h
                    node.h = (
                        node.parent.h
                        * (tonumber(node.attributes.ratio) / node.parent.total_children_ratio)
                        - (math.min(root.w, root.h) * node.parent.attributes.padding * 0.01)
                    )
                end
                node.x = node.parent.x + (math.min(root.w, root.h) * node.parent.attributes.padding * 0.01)
                node.w = (
                    node.parent.w
                    - (math.min(root.w, root.h) * node.parent.attributes.padding * 0.01) * 2
                )
            end
        end

        if node.content then
            node.total_children_ratio = 0
            for i, child in ipairs(node.content) do
                if child.tag then
                    if dup_count[child.tag] ~= nil then
                        dup_count[child.tag] = dup_count[child.tag] + 1
                        child.tag = child.tag .. dup_count[child.tag]
                    else
                        dup_count[child.tag] = 0
                    end
                    -- Defaults
                    if child.attributes == nil then
                        child.attributes = {}
                    end
                    if child.attributes.ratio == nil then
                        child.attributes.ratio = 1
                    end
                    if child.attributes.direction == nil then
                        child.attributes.direction = "horizontal"
                    end
                    if not node.attributes.padding then
                        node.attributes.padding = 0
                    end
                    ---
                    node.total_children_ratio =
                        (
                            node.total_children_ratio +
                            child.attributes.ratio
                        )
                    child.parent = node
                    if node.content[i - 1] then
                        if node.content[i - 1].tag then
                            child.prev_sibling = node.content[i - 1]
                        end
                    end
                    if node.content[i + 1] then
                        if node.content[i + 1].tag then
                            child.next_sibling = node.content[i + 1]
                        end
                    end
                    table.insert(q, 1, child)
                end
            end
        end
        flat_panels[node.tag] = node
    end
    return flat_panels
end

lovepanels.draw_debug = function(panels)
    love.graphics.push("all")
    for _, p in pairs(panels.flat) do
        love.graphics.setColor(0, 0, 1)
        love.graphics.rectangle(
            "line",
            p.x,
            p.y,
            p.w,
            p.h
        )
    end
    love.graphics.pop()
end

return lovepanels
