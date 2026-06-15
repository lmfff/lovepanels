--[[
	HTML2Table is a module that allows to convert HTML code to Lua tables and the other way around.
		-by RicardoTM.
	For encoding and decoding htmlEntities.lua by TiagoDanin module is required: https://github.com/TiagoDanin/htmlEntities-for-lua
	More info and questions: https://forum.rainmeter.net/viewtopic.php?t=44955#p231448

	v.1.1
]]

local HTML2Table = {}

--This option allows for empty strings, which return "".
local allowEmptyStrings = true

-- Extract HTML/XML into a structured table
function HTML2Table.toTable(html, decode)
  -- Converts an HTML string into a nested Lua table representation.
  -- Parameters:
  -- html: A string containing HTML content (tags, attributes, comments, and text).
  -- decode: (Optional) A boolean to indicate whether to decode HTML character references.
  -- Returns:
  -- A nested Lua table representing the structure of the HTML content. For example:
  -- {
  --   {tag="div", attributes={class="container"}, content={"Some text", {tag="span", content={"nested"}}}}
  -- }

  if not html then return error('No HTML code found') end
  local decode = decode or false
  local idx = 1    -- Initialize current index for parsing
  local tbl = {}   -- Initialize the table to hold the parsed HTML structure

  if decode and not htmlEntities then
    print('Warning: htmlEntities.lua is required to decode.')
  end

  -- Function to trim leading and trailing whitespace from a string
  local function trim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
  end

  html = trim(html)   -- Remove excess whitespace from the input HTML string

  -- Function to parse HTML comments
  local function parseComment(startIndex)
    -- Looks for comments in the format <!-- comment content -->
    local commentStart, commentEnd = html:find("<!%-%-(.-)%-%->", startIndex)
    if commentStart and commentEnd then
      local commentContent = html:sub(commentStart + 4, commentEnd - 3)       -- Extract comment content
      return { tag = "comment", content = { trim(commentContent) } }, commentEnd + 1
    end
    return nil, startIndex
  end

  -- Function to parse an HTML tag and its content
  local function parseTag(startIndex)
    -- Find the start of an opening tag
    local tagStart = html:find("<([^/][^>]*)", startIndex)
    if not tagStart then return nil, #html + 1 end     -- End parsing if no more tags are found

    -- Check if the tag is a comment
    if html:sub(tagStart, tagStart + 3) == "<!--" then
      return parseComment(startIndex)       -- Delegate to comment parser
    end

    -- Find the end of the opening tag
    local tagEnd = html:find(">", startIndex)
    if not tagEnd then return nil, #html + 1 end     -- End parsing if no tag closure is found

    -- Extract the tag name
    local tagName = html:sub(tagStart + 1, tagEnd - 1):match("([%w:_%-%.]+)")
    if not tagName then return nil, tagEnd + 1 end     -- Skip malformed tags

    -- Initialize a table to represent the tag
    local tagData = { tag = tagName, content = {} }

    -- Extract attributes from the tag
    local attributesStr = html:sub(tagStart + 1, tagEnd - 1):match("%s(.+)")
    if attributesStr then
      tagData.attributes = {}
      for attr, value in attributesStr:gmatch("([a-zA-Z0-9:_-.]+)%s*=%s*['\"]([^\"]+)['\"]") do
        tagData.attributes[attr] = value         -- Store attributes as key-value pairs
      end
    end

    -- Find the closing tag and handle nested content
    local nextPos = tagEnd + 1
    local closingTagPattern = "</" .. tagName .. ">"
    local closingTagStart = html:find(closingTagPattern, nextPos)

    if not closingTagStart then return tagData, nextPos end     -- If no closing tag, return tag as is

    -- Process the content inside the tag
    while closingTagStart do
      local nextTagStart = html:find("<([^/][^>]*)", nextPos)
      if nextTagStart and nextTagStart < closingTagStart then
        -- Add text content before the next nested tag
        local textBeforeTag = html:sub(nextPos, nextTagStart - 1)
        if textBeforeTag:match("%S") and not textBeforeTag:match("<.*>") then
          if decode and htmlEntities then
            textBeforeTag = htmlEntities.decode(textBeforeTag)             -- Optionally decode references
          end
          table.insert(tagData.content, trim(textBeforeTag))
        end

        -- Parse the nested tag
        local nestedTagData, newPos = parseTag(nextTagStart)
        if nestedTagData then
          table.insert(tagData.content, nestedTagData)
          nextPos = newPos
        else
          nextPos = newPos
        end
      else
        -- Add text content before the closing tag
        local textContent = html:sub(nextPos, closingTagStart - 1)
        if textContent:match("%S") and not textContent:match("<.*>") then
          if decode and htmlEntities then
            textContent = htmlEntities.decode(textContent)
          end
          table.insert(tagData.content, trim(textContent))
        elseif allowEmptyStrings then
          table.insert(tagData.content, "")
        end
        break
      end
    end

    return tagData, closingTagStart + #closingTagPattern     -- Return parsed tag and position
  end

  -- Main loop to process the entire HTML string
  while idx <= #html do
    local tagData, newPos = parseTag(idx)     -- Parse the next tag
    if tagData then
      table.insert(tbl, tagData)              -- Add parsed tag to the result table
    end
    if newPos > #html then break end          -- Exit loop if end of string is reached
    idx = newPos                              -- Move index to the next position
  end

  return tbl
end

-- Convert a structured Lua table into an HTML/XML string
function HTML2Table.toHTML(tbl, encode)
  -- Converts a nested Lua table representation of HTML into an HTML-formatted string.
  -- Parameters:
  -- tbl: A table with a structure like:
  --   {
  --     {tag="th", attributes={colspan=2}, content={"text", {tag="span", content={"nested text"}}}}
  --   }
  -- encode: (Optional) A boolean to indicate whether to encode special HTML characters in text content.
  -- Returns:
  -- A string containing HTML with properly formatted tags, attributes, and content.

  if not tbl then return error('HTML2Table.toHTML(): No table found') end   -- Ensure a valid table is provided
  local encode = encode or false
  local indentLevel = 0                                                     -- Tracks the current level of indentation for better formatting
  local indent = string.rep("    ", indentLevel)                            -- Base indentation string

  if encode and not htmlEntities then
    print('Warning: htmlEntities.lua is required to encode.')
  end

  -- Function to convert a table of attributes into a string
  local function processAttributes(attributes)
    -- Parameters:
    -- attributes: A table of key-value pairs representing HTML attributes (e.g., {class="btn", id="submit"}).
    -- Returns:
    -- A string formatted as key-value pairs for use in an HTML tag (e.g., ' class="btn" id="submit"').
    local attrStr = ""
    if attributes then
      for key, value in pairs(attributes) do
        attrStr = attrStr .. string.format(' %s="%s"', key, value)         -- Concatenate attributes
      end
    end
    return attrStr
  end

  -- Function to process the content of a tag
  local function processContent(content, level)
    -- Parameters:
    -- content: The content of the tag, which can be text, nested tables, or a mix.
    -- level: The current indentation level for formatting.
    -- Returns:
    -- A string representing the processed HTML content.
    local html = ""
    if type(content) == "table" then
      -- Iterate over the content table, which may contain strings or nested tags
      for _, item in ipairs(content) do
        if type(item) == "table" and item.tag then
          -- Handle table entries with a "tag" field (i.e., HTML elements)
          if item.tag == "comment" then
            -- Special handling for comments (e.g., <!--comment content-->)
            local commentContent = table.concat(item.content or {}, "")
            html = html .. string.format(
              '\n%s<!--%s-->\n',
              string.rep("    ", level),               -- Indent the comment based on its nesting level
              commentContent
            )
          else
            -- Handle regular HTML tags (e.g., <div>, <span>)
            local attributes = processAttributes(item.attributes)                    -- Process attributes
            local innerContent = processContent(item.content, level + 1)             -- Process nested content
            html = html .. string.format(
              '\n%s<%s%s>%s</%s>\n',
              string.rep("    ", level),               -- Indent the tag based on its nesting level
              item.tag,                                -- Tag name (e.g., "div")
              attributes,                              -- Attributes string (e.g., ' class="example"')
              innerContent,                            -- Inner content (e.g., text or more tags)
              item.tag                                 -- Closing tag (e.g., </div>)
            )
          end
        elseif type(item) == "string" then
          -- Handle plain text content
          if encode and htmlEntities then
            item = htmlEntities.encode(item)             -- Optionally encode special HTML characters
          end
          html = html .. item                            -- Append the text content
        end
      end
    end
    return html
  end

  -- Start processing the input table from the top level
  local html = processContent(tbl, indentLevel)
  return html   -- Return the final HTML string
end

-- Convert a structured table to a list of strings.
function HTML2Table.getStrings(tbl, tags, mode, returnTags, wContentOnly)
  --[[ Parameters:
        tbl: A table containing nested tag data with the structure:
        { {tag="tagName", attributes={atribute=value}, content={"text", {tag="nestedTag", content={"nested text"}}}}, ... }
        tags: (Optional) A list of tags to include or exclude, e.g., {"p", "span"}.
        mode: (Optional) Specifies whether tags are included ("include") or excluded ("exclude"). Default is "exclude".
        returnTags: (Optional) Boolean indicating whether to return the tags themselves (true) or their content (false).
        wContentOnly: (Optional) Boolean indicating whether to return only tags that have non-empty string content (default is false).
        Return: Table containing extracted strings or tags based on the specified mode and options.
    ]]
  local result = {}
  tags = tags or {}
  mode = mode or "exclude"
  returnTags = returnTags or false
  wContentOnly = wContentOnly or false

  -- Utility function to split a comma-separated string into a table
  local function splitToTable(str)
    if type(str) ~= 'string' then
      error("splitToTable(): Input must be a string. Not a " .. type(str))
    end
    local fields = {}
    for field in str:gmatch('([^,%s*]+)') do
      table.insert(fields, field)
    end
    return fields
  end

  -- Converts strings 'true' or 'false' to boolean
  local function trueOrFalse(str)
    if str == 'true' then return true end
    if str == 'false' then return false end
    error("trueOrFalse(): Input must be 'true' or 'false', got '" .. tostring(str) .. "'.")
  end

  if type(tags) ~= 'table' then
    tags = splitToTable(tags)
  end

  if type(returnTags) ~= 'boolean' then
    returnTags = trueOrFalse(returnTags)
  end

  if type(wContentOnly) ~= 'boolean' then
    wContentOnly = trueOrFalse(wContentOnly)
  end

  -- Create a set of tags for fast lookup
  local tagsSet = {}
  for _, tag in ipairs(tags) do
    tagsSet[tag] = true
  end

  -- Recursive function to process tag content
  local function processContent(tagData)
    if tagData.content then
      local tagMatches = (mode == "include" and tagsSet[tagData.tag]) or
          (mode == "exclude" and not tagsSet[tagData.tag])
      local hasStringContent = false

      for _, contentItem in ipairs(tagData.content) do
        if type(contentItem) == "string" then
          -- Handle empty strings based on `wContentOnly`
          if contentItem == "" then
            if not wContentOnly and tagMatches and not returnTags then
              table.insert(result, contentItem)               -- Include empty strings if `wContentOnly` is false
            end
          else
            hasStringContent = true
            if tagMatches and not returnTags then
              table.insert(result, contentItem)
            end
          end
        elseif type(contentItem) == "table" then
          processContent(contentItem)
        end
      end

      if tagMatches and returnTags then
        if not wContentOnly or (wContentOnly and hasStringContent) then
          result[tagData.tag] = true
        end
      end
    end
  end

  -- Process each tag in the input table
  for _, tagData in ipairs(tbl) do
    processContent(tagData)
  end

  -- Convert tag set to a list if returning tags
  if returnTags then
    local tagsList = {}
    for tag in pairs(result) do
      table.insert(tagsList, tag)
    end
    return tagsList
  end

  return result
end

return HTML2Table
