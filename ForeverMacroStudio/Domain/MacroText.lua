local _, studio = ...
local MacroText = {}
studio.MacroText = MacroText

function MacroText.Trim(text)
    local first = text:find("[^ \t]")
    if not first then return "" end
    local last = #text
    while text:byte(last) == 32 or text:byte(last) == 9 do last = last - 1 end
    return text:sub(first, last)
end

function MacroText.Normalize(text)
    return (text:gsub("\r\n", "\n"):gsub("\r", "\n"))
end

-- Count UTF-8 code points and reject malformed, overlong and surrogate sequences.
function MacroText.CountCharacters(text)
    local index, count = 1, 0
    while index <= #text do
        local first = text:byte(index)
        local width, low, high = 1, 128, 191
        if first >= 194 and first <= 223 then
            width = 2
        elseif first >= 224 and first <= 239 then
            width = 3
            if first == 224 then low = 160 end
            if first == 237 then high = 159 end
        elseif first >= 240 and first <= 244 then
            width = 4
            if first == 240 then low = 144 end
            if first == 244 then high = 143 end
        elseif first > 127 then
            return nil, index
        end
        for offset = 1, width - 1 do
            local nextByte = text:byte(index + offset)
            if not nextByte or nextByte < low or nextByte > high then return nil, index end
            low, high = 128, 191
        end
        index, count = index + width, count + 1
    end
    return count
end

function MacroText.HasControls(text)
    return text:find("[%z\1-\8\11-\31\127]") or text:find("\194[\128-\159]")
        or text:find("\226\128[\168\169]")
end
