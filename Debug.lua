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

function CinematicCam:InvestigateNPCTextPositioning()
    local npcTextContainer = ZO_InteractWindow_GamepadContainerText
    if not npcTextContainer then
        d("ERROR: NPC text container not found")
        return
    end

    local screenWidth, screenHeight = GuiRoot:GetDimensions()
    d("=== NPC Text Positioning Investigation ===")
    d(string.format("Screen dimensions: %dx%d", screenWidth, screenHeight))

    -- Get current state
    local currentWidth, currentHeight = npcTextContainer:GetDimensions()
    local currentX, currentY = npcTextContainer:GetCenter()
    local left, top, right, bottom = npcTextContainer:GetRect()

    d(string.format("Current dimensions: %dx%d", currentWidth, currentHeight))
    d(string.format("Current center: (%d, %d)", currentX, currentY))
    d(string.format("Current rect: L=%d, T=%d, R=%d, B=%d", left, top, right, bottom))

    -- Test different anchor combinations to understand the system
    d("--- Testing Anchor Behaviors ---")

    -- Save original state first
    npcTextContainer:ClearAnchors()

    -- Test 1: BOTTOM anchor with different offsets
    d("Testing BOTTOM anchor...")
    npcTextContainer:SetAnchor(BOTTOM, GuiRoot, BOTTOM, 0, -100)
    zo_callLater(function()
        local testX, testY = npcTextContainer:GetCenter()
        d(string.format("BOTTOM anchor (0, -100): Center at (%d, %d)", testX, testY))

        -- Test 2: Different Y offset
        npcTextContainer:ClearAnchors()
        npcTextContainer:SetAnchor(BOTTOM, GuiRoot, BOTTOM, 0, 100)
        zo_callLater(function()
            local testX2, testY2 = npcTextContainer:GetCenter()
            d(string.format("BOTTOM anchor (0, 100): Center at (%d, %d)", testX2, testY2))

            -- Test 3: CENTER anchor for comparison
            npcTextContainer:ClearAnchors()
            npcTextContainer:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
            zo_callLater(function()
                local testX3, testY3 = npcTextContainer:GetCenter()
                d(string.format("CENTER anchor (0, 0): Center at (%d, %d)", testX3, testY3))

                -- Test 4: Try BOTTOMLEFT to understand horizontal behavior
                npcTextContainer:ClearAnchors()
                npcTextContainer:SetAnchor(BOTTOMLEFT, GuiRoot, BOTTOMLEFT, 100, -100)
                zo_callLater(function()
                    local testX4, testY4 = npcTextContainer:GetCenter()
                    d(string.format("BOTTOMLEFT anchor (100, -100): Center at (%d, %d)", testX4, testY4))
                    d("=== Investigation Complete ===")
                    d("Use this data to understand ESO's coordinate system!")
                end, 100)
            end, 100)
        end, 100)
    end, 100)
end

-- Comprehensive investigation to understand ESO's positioning behavior
function CinematicCam:ComprehensivePositioningInvestigation()
    local npcTextContainer = ZO_InteractWindow_GamepadContainerText
    if not npcTextContainer then
        d("ERROR: NPC text container not found - start a dialogue first")
        return
    end

    local screenWidth, screenHeight = GuiRoot:GetDimensions()
    local theoreticalCenterX = screenWidth / 2
    local theoreticalCenterY = screenHeight / 2

    d("=== COMPREHENSIVE ESO UI POSITIONING INVESTIGATION ===")
    d(string.format("Screen: %dx%d", screenWidth, screenHeight))
    d(string.format("Theoretical center: (%.1f, %.1f)", theoreticalCenterX, theoreticalCenterY))

    -- Phase 1: Understand current element state
    d("\n--- PHASE 1: Current Element Analysis ---")
    local currentWidth, currentHeight = npcTextContainer:GetDimensions()
    local currentCenterX, currentCenterY = npcTextContainer:GetCenter()


    d(string.format("Current dimensions: %dx%d", currentWidth, currentHeight))
    d(string.format("Current center: (%.1f, %.1f)", currentCenterX, currentCenterY))

    d(string.format("Distance from theoretical center: X offset = %.1f", currentCenterX - theoreticalCenterX))

    -- Phase 2: Test different anchor combinations systematically
    d("\n--- PHASE 2: Anchor Behavior Testing ---")

    local testSequence = {
        { name = "BOTTOM + (0,0)",            anchor = BOTTOM,     parentAnchor = BOTTOM,     x = 0,                  y = 0 },
        { name = "BOTTOM + (0,-96)",          anchor = BOTTOM,     parentAnchor = BOTTOM,     x = 0,                  y = -96 },
        { name = "CENTER + (0,0)",            anchor = CENTER,     parentAnchor = CENTER,     x = 0,                  y = 0 },
        { name = "CENTER + (0,200)",          anchor = CENTER,     parentAnchor = CENTER,     x = 0,                  y = 200 },
        { name = "BOTTOMLEFT + (center,0)",   anchor = BOTTOMLEFT, parentAnchor = BOTTOMLEFT, x = theoreticalCenterX, y = 0 },
        { name = "TOPLEFT + (center,bottom)", anchor = TOPLEFT,    parentAnchor = TOPLEFT,    x = theoreticalCenterX, y = screenHeight - 96 }
    }

    local function runNextTest(index)
        if index > #testSequence then
            d("\n--- PHASE 3: Parent Container Analysis ---")
            CinematicCam:AnalyzeParentContainers()
            return
        end

        local test = testSequence[index]
        npcTextContainer:ClearAnchors()
        npcTextContainer:SetAnchor(test.anchor, GuiRoot, test.parentAnchor, test.x, test.y)

        zo_callLater(function()
            local testCenterX, testCenterY = npcTextContainer:GetCenter()


            d(string.format("%s: Center=(%.1f, %.1f), Rect=(%.1f,%.1f,%.1f,%.1f)",
                test.name, testCenterX, testCenterY, testLeft, testTop, testRight, testBottom))
            d(string.format("  -> X offset from theoretical center: %.1f", testCenterX - theoreticalCenterX))

            -- Continue to next test
            runNextTest(index + 1)
        end, 200) -- Longer delay to ensure positioning settles
    end

    -- Start the test sequence
    runNextTest(1)
end

-- Analyze parent container hierarchy
function CinematicCam:AnalyzeParentContainers()
    local npcTextContainer = ZO_InteractWindow_GamepadContainerText
    if not npcTextContainer then return end

    d("\n--- Parent Container Analysis ---")

    -- Walk up the parent hierarchy
    local current = npcTextContainer
    local level = 0

    while current and level < 5 do -- Limit to 5 levels to avoid infinite loops
        local parent = current:GetParent()
        if parent then
            local parentName = parent:GetName() or "Unnamed"
            local parentWidth, parentHeight = parent:GetDimensions()
            local parentCenterX, parentCenterY = parent:GetCenter()


            d(string.format("Level %d Parent: %s", level, parentName))
            d(string.format("  Dimensions: %dx%d", parentWidth, parentHeight))
            d(string.format("  Center: (%.1f, %.1f)", parentCenterX, parentCenterY))
            e

            current = parent
            level = level + 1
        else
            d(string.format("Level %d: No parent (reached root)", level))
            break
        end
    end

    d("\n--- Text Alignment Analysis ---")
    CinematicCam:AnalyzeTextAlignment()
end

-- Analyze text alignment within the container
function CinematicCam:AnalyzeTextAlignment()
    local npcTextContainer = ZO_InteractWindow_GamepadContainerText
    if not npcTextContainer then return end

    -- Check text alignment properties
    local horizontalAlignment = npcTextContainer:GetHorizontalAlignment()
    local verticalAlignment = npcTextContainer:GetVerticalAlignment()

    d("Text Alignment Properties:")
    d(string.format("  Horizontal: %s", tostring(horizontalAlignment)))
    d(string.format("  Vertical: %s", tostring(verticalAlignment)))

    -- Check if we can get text-specific properties
    local text = npcTextContainer:GetText()
    if text then
        d(string.format("  Current text length: %d characters", string.len(text)))
        d(string.format("  Text preview: '%s'", string.sub(text, 1, 50) .. (string.len(text) > 50 and "..." or "")))
    end

    d("\n=== INVESTIGATION COMPLETE ===")
    d("Use this data to understand the positioning behavior!")
end

-- Simplified test function to try a specific positioning approach
function CinematicCam:TestSpecificPositioning(anchorType, xOffset, yOffset)
    local npcTextContainer = ZO_InteractWindow_GamepadContainerText
    if not npcTextContainer then
        d("Start a dialogue first")
        return
    end

    local screenWidth, screenHeight = GuiRoot:GetDimensions()

    d(string.format("Testing: %s anchor with offset (%d, %d)", tostring(anchorType), xOffset, yOffset))

    npcTextContainer:ClearAnchors()
    npcTextContainer:SetAnchor(anchorType, GuiRoot, anchorType, xOffset, yOffset)

    zo_callLater(function()
        local resultX, resultY = npcTextContainer:GetCenter()
        local theoreticalCenterX = screenWidth / 2
        d(string.format("Result: Center at (%.1f, %.1f)", resultX, resultY))
        d(string.format("X offset from screen center: %.1f", resultX - theoreticalCenterX))
    end, 100)
end
