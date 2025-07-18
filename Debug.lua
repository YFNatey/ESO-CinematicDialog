function CinematicCam:AnalyzeDialogueStructure()
    local textElement = _G["ZO_InteractWindow_GamepadContainerText"]
    if not textElement then
        d("GamepadContainerText not found")
        return
    end

    local width, height = textElement:GetDimensions()
    local content = textElement:GetText() or ""

    -- Detailed content analysis
    local lines = {}
    local lineCount = 0
    local blankLineCount = 0

    -- Split content into lines (handle both \n and natural wrapping)
    for line in string.gmatch(content .. "\n", "(.-)\n") do
        lineCount = lineCount + 1
        lines[lineCount] = line

        -- Check for blank lines
        if string.match(line, "^%s*$") then
            blankLineCount = blankLineCount + 1
        end
    end

    -- Calculate expected dimensions based on our pattern
    local expectedHeight = (lineCount * 48) + ((lineCount - 1) * 3)
    local heightPerLine = height / lineCount

    d("=== COMPREHENSIVE LINE ANALYSIS ===")
    d(string.format("Measured Dimensions: %dx%d", width, height))
    d(string.format("Total Lines: %d", lineCount))
    d(string.format("Blank Lines: %d", blankLineCount))
    d(string.format("Text Lines: %d", lineCount - blankLineCount))
    d(string.format("Expected Height: %d px", expectedHeight))
    d(string.format("Height Variance: %+d px", height - expectedHeight))
    d(string.format("Actual Height per Line: %.2f px", heightPerLine))
    d("---")

    -- Display each line for verification
    for i, line in ipairs(lines) do
        local lineType = string.match(line, "^%s*$") and "BLANK" or "TEXT"
        d(string.format("Line %d (%s): '%s'", i, lineType, string.sub(line, 1, 50)))
    end
    d("=== END ANALYSIS ===")
end

-- Add this comprehensive debugging function
function CinematicCam:DebugDialogueElements()
    d("=== DIALOGUE ELEMENT DEBUG ===")

    local elementsToCheck = {
        "ZO_InteractWindowDivider",
        "ZO_InteractWindow_GamepadContainer",
        "ZO_InteractWindow_GamepadContainerText",
        "ZO_InteractWindowPlayerAreaOptions",
        "ZO_InteractWindowPlayerAreaHighlight",
        "ZO_InteractWindowTargetAreaTitle",
        "ZO_InteractWindowTargetAreaBodyText"
    }

    for _, elementName in ipairs(elementsToCheck) do
        local element = _G[elementName]
        if element then
            local width, height = element:GetDimensions()
            local isHidden = element:IsHidden()
            local alpha = element:GetAlpha()
            local parent = element:GetParent()

            d(string.format("%s: EXISTS", elementName))
            d(string.format("  Size: %dx%d", width, height))
            d(string.format("  Hidden: %s, Alpha: %.2f", tostring(isHidden), alpha))
            d(string.format("  Parent: %s", parent and parent:GetName() or "nil"))
            d("---")
        else
            d(string.format("%s: NOT FOUND", elementName))
        end
    end

    d("Current interaction type: " .. tostring(GetInteractionType()))
    d("Current preset: " .. tostring(currentRepositionPreset))
    d("=== END DEBUG ===")
end

function CinematicCam:DebugGamepadDialogueHierarchy()
    d("=== GAMEPAD DIALOGUE HIERARCHY DEBUG ===")

    -- Root window
    local rootWindow = _G["ZO_InteractWindow_Gamepad"]
    if rootWindow then
        local width, height = rootWindow:GetDimensions()
        d(string.format("Root Window: %dx%d, Hidden: %s", width, height, tostring(rootWindow:IsHidden())))
    end

    -- Main text container (we know this exists)
    local textContainer = _G["ZO_InteractWindow_GamepadContainer"]
    if textContainer then
        local width, height = textContainer:GetDimensions()
        d(string.format("Text Container: %dx%d, Hidden: %s", width, height, tostring(textContainer:IsHidden())))
    end

    -- Options container (your discovery)
    local optionsContainer = _G["ZO_InteractWindow_GamepadContainerInteractListScroll"]
    if optionsContainer then
        local width, height = optionsContainer:GetDimensions()
        local numChildren = optionsContainer:GetNumChildren()
        d(string.format("Options Container: %dx%d, Hidden: %s, Children: %d",
            width, height, tostring(optionsContainer:IsHidden()), numChildren))

        -- List all children in the options container
        for i = 1, numChildren do
            local child = optionsContainer:GetChild(i)
            if child and child.GetName then
                local childName = child:GetName() or "unnamed"
                local childWidth, childHeight = child:GetDimensions()
                d(string.format("  Child %d: %s (%dx%d, Hidden: %s)",
                    i, childName, childWidth, childHeight, tostring(child:IsHidden())))
            end
        end
    end

    -- Individual dialogue options (your naming pattern discovery)
    local activeOptions = 0
    for i = 1, 10 do
        local optionElement = _G["ZO_ChatterOption_GamePad" .. i]
        if optionElement and not optionElement:IsHidden() then
            local width, height = optionElement:GetDimensions()
            local text = ""
            if optionElement.GetText then
                text = optionElement:GetText() or ""
                if string.len(text) > 30 then
                    text = string.sub(text, 1, 30) .. "..."
                end
            end
            activeOptions = activeOptions + 1
            d(string.format("Option %d: %dx%d, Text: '%s'", i, width, height, text))
        end
    end

    d(string.format("Total active options: %d", activeOptions))
    d("=== END HIERARCHY DEBUG ===")
end
