---=============================================================================
-- STATE AND DATA STRUCTURES
--=============================================================================
local dialogueChangeCheckTimer = nil

CinematicCam.chunkedDialogueData = {
    originalText = "",
    chunks = {},
    displayChunks = {},
    currentChunkIndex = 0,
    isActive = false,
    customControl = nil,
    displayTimer = nil,
    backgroundControl = nil,
    playerOptionsBackgroundControl = nil,
    sourceElement = nil,
    rawDialogueText = "",
    playerOptionsHidden = false,
    originalPlayerOptionsVisibility = {}
}
function CinematicCam:GetDialogueText()
    local sources = {
        ZO_InteractWindow_GamepadContainerText,
        ZO_InteractWindowTargetAreaBodyText
    }

    for _, element in ipairs(sources) do
        if element then
            local text = element.text or element:GetText() or ""
            if string.len(text) > 0 then
                return text, element
            end
        end
    end

    return nil, nil
end

--TODO, make a function that returns true if the word store is found in the player options
--Iterate all player options,
-- Only check forstr word

function CinematicCam:FindPlayerOptionTextElement(option)
    -- Try direct properties first
    if option.text and option.text.GetText then
        return option.text
    elseif option.label and option.label.GetText then
        return option.label
    elseif option.optionText and option.optionText.GetText then
        return option.optionText
    elseif option.GetText then
        return option
    else
        -- Search through children for text elements
        for j = 1, option:GetNumChildren() do
            local child = option:GetChild(j)
            if child and child.GetText then
                local childText = child:GetText()
                if childText and childText ~= "" then
                    return child
                end
            end
        end
    end
    return nil
end

function CinematicCam:CheckPlayerOptionsForVendorText()
    local vendorPatterns = { "^[Ss]tore", "^[Bb]uy", "^[Ss]ell", "^[Tt]rade", "Bank", "<", "Complete Quest", "Skills:",
        "Morphs:", "Skill Lines" }
    -- Check individual option elements (matching KhajiitVoice pattern exactly)
    for i = 1, 10 do
        local longOptionName = "ZO_InteractWindow_GamepadContainerInteractListScrollZO_ChatterOption_Gamepad" .. i
        local option = _G[longOptionName]
        if option then
            local textElement = self:FindPlayerOptionTextElement(option)
            if textElement then
                local optionText = textElement:GetText() or ""
                if optionText ~= "" then
                    -- Check if first option is "Goodbye."
                    if i == 1 and optionText == "Goodbye." then
                        return true
                    end
                    for _, pattern in ipairs(vendorPatterns) do
                        if optionText and pattern and string.find(optionText, pattern) then
                            return true
                        end
                    end
                end
            end
        end
        local shortOptionName = "ZO_ChatterOption_Gamepad" .. i
        local option2 = _G[shortOptionName]
        if option2 then
            local textElement = self:FindPlayerOptionTextElement(option2)
            if textElement then
                local optionText = textElement:GetText() or ""
                if optionText ~= "" then
                    -- Check if first option is "Goodbye."
                    if i == 1 and optionText == "Goodbye." then
                        return true
                    end
                    for _, pattern in ipairs(vendorPatterns) do
                        if string.find(optionText, pattern) then
                            return true
                        end
                    end
                end
            end
        end
    end
    return false
end

---=============================================================================
-- MAIN DIALOGUE INTERCEPTION AND PROCESSING
--=============================================================================

function CinematicCam:InterceptDialogueForChunking()
    local originalText, sourceElement = self:GetDialogueText()

    -- if the word "Store", show player options
    if self:CheckPlayerOptionsForVendorText() then
        CinematicCam.PlayerOptionsAlways = true
        CinematicCam:OnPlayerOptionsSettingChanged(false, true)
    else
        CinematicCam.PlayerOptionsAlways = false
        CinematicCam:OnPlayerOptionsSettingChanged(true, false)
    end
    if not originalText or string.len(originalText) == 0 then
        return false
    end

    -- Apply NPC name preset
    self:ApplyNPCNamePreset()

    -- Prepare text versions
    local textForTiming = originalText
    local processedTextForDisplay = self:HandleNPCName(
        originalText,
        CinematicCam.npcNameData.originalName,
        self.savedVars.npcNamePreset
    )

    -- Store dialogue data
    CinematicCam.chunkedDialogueData.originalText = processedTextForDisplay
    CinematicCam.chunkedDialogueData.sourceElement = sourceElement
    CinematicCam.chunkedDialogueData.rawDialogueText = originalText

    -- Process and display if chunked dialogue is enabled
    if self.savedVars.interaction.subtitles.useChunkedDialogue or
        self.savedVars.interaction.subtitles.hidePlayerOptionsUntilLastChunk then
        return self:ProcessAndDisplayChunkedDialogue(textForTiming, processedTextForDisplay)
    end
    return false
end

function CinematicCam:ProcessAndDisplayChunkedDialogue(textForTiming, processedTextForDisplay)
    -- Process text into chunks
    CinematicCam.chunkedDialogueData.chunks = self:ProcessTextIntoChunks(textForTiming)
    CinematicCam.chunkedDialogueData.displayChunks = self:ProcessTextIntoDisplayChunks(processedTextForDisplay)

    if #CinematicCam.chunkedDialogueData.chunks >= 1 then
        self:StartDialogueChangeMonitoring()
        if self.savedVars.interaction.layoutPreset == "default" then
            return self:InitializeHiddenChunkedDisplay()
        else
            return self:InitializeChunkedDisplay()
        end
    else
        -- Fallback to single chunk
        CinematicCam.chunkedDialogueData.chunks = { textForTiming }
        CinematicCam.chunkedDialogueData.displayChunks = { processedTextForDisplay }
        self:StartDialogueChangeMonitoring()
        if self.savedVars.interaction.layoutPreset == "default" then
            return self:InitializeHiddenCompleteTextDisplay()
        else
            return self:InitializeCompleteTextDisplay()
        end
    end
end

function CinematicCam:InitializeHiddenChunkedDisplay()
    if #CinematicCam.chunkedDialogueData.chunks == 0 then
        return false
    end

    -- DON'T hide source element for default preset
    -- Keep original dialogue visible

    -- Hide player options ONLY for dialogue interactions and if we have multiple chunks
    if self:ShouldHidePlayerOptionsForInteraction() and #CinematicCam.chunkedDialogueData.chunks > 1 and CinematicCam.PlayerOptionsAlways == false then
        self:HidePlayerOptionsUntilLastChunk()
    end

    -- Don't create or show custom control for default preset
    -- Just setup timing logic
    CinematicCam.chunkedDialogueData.currentChunkIndex = 1
    CinematicCam.chunkedDialogueData.isActive = true

    -- Schedule next chunk if multiple chunks exist (for timing only)
    if #CinematicCam.chunkedDialogueData.chunks > 1 then
        self:ScheduleNextChunk()
    else
        -- For single chunk, immediately show player options if they were hidden
        if CinematicCam.chunkedDialogueData.playerOptionsHidden then
            self:ShowPlayerOptionsOnLastChunk()
        end
    end

    return true
end

-- New function for hidden complete text display (default preset, single chunk)
function CinematicCam:InitializeHiddenCompleteTextDisplay()
    -- DON'T hide source element for default preset
    -- Keep original dialogue visible

    -- For single chunk, immediately show player options if they were hidden
    if CinematicCam.chunkedDialogueData.playerOptionsHidden then
        self:ShowPlayerOptionsOnLastChunk()
    end

    CinematicCam.chunkedDialogueData.currentChunkIndex = 1
    CinematicCam.chunkedDialogueData.isActive = true

    return true
end

---=============================================================================
-- TEXT PROCESSING AND CHUNKING
--=============================================================================
function CinematicCam:ProcessTextIntoChunks(fullText)
    if not fullText or fullText == "" then
        return {}
    end

    local chunks = {}
    local delimiters = self.savedVars.chunkedDialog.chunkDelimiters
    local minLength = self.savedVars.chunkedDialog.chunkMinLength
    local maxLength = self.savedVars.chunkedDialog.chunkMaxLength

    local processedText = self:PreprocessTextForChunking(fullText)

    chunks = self:SplitTextIntoChunks(processedText, delimiters, minLength, maxLength)

    -- Preview timing for debugging
    if #chunks > 1 then
        self:PreviewChunkTiming(chunks)
    end

    return chunks
end

function CinematicCam:ProcessTextIntoDisplayChunks(fullText)
    if not fullText or fullText == "" then
        return {}
    end

    local delimiters = self.savedVars.chunkedDialog.chunkDelimiters
    local minLength = self.savedVars.chunkedDialog.chunkMinLength
    local maxLength = self.savedVars.chunkedDialog.chunkMaxLength

    local processedText = self:PreprocessTextForChunking(fullText)

    return self:SplitTextIntoChunks(processedText, delimiters, minLength, maxLength)
end

function CinematicCam:SplitTextIntoChunks(processedText, delimiters, minLength, maxLength)
    local chunks = {}
    local currentChunk = ""
    local i = 1

    while i <= #processedText do
        local char = processedText:sub(i, i)
        currentChunk = currentChunk .. char

        local foundDelimiter = false
        for _, delimiter in ipairs(delimiters) do
            if char == delimiter then
                if self:IsValidChunkBoundary(processedText, i, currentChunk, minLength) then
                    local trimmedChunk = self:TrimString(currentChunk)
                    if string.len(trimmedChunk) >= minLength then
                        table.insert(chunks, trimmedChunk)
                        currentChunk = ""
                        foundDelimiter = true
                        break
                    end
                end
            end
        end

        if not foundDelimiter and string.len(currentChunk) >= maxLength then
            local breakPoint = self:FindWordBoundary(currentChunk, maxLength)
            if breakPoint > minLength then
                table.insert(chunks, self:TrimString(currentChunk:sub(1, breakPoint)))
                currentChunk = currentChunk:sub(breakPoint + 1)
            end
        end

        i = i + 1
    end

    -- Add final chunk if any text remains
    local finalChunk = self:TrimString(currentChunk)
    if string.len(finalChunk) > 0 then
        table.insert(chunks, finalChunk)
    end

    return chunks
end

function CinematicCam:PreprocessTextForChunking(text)
    local abbreviations = {
        "Mr%.", "Mrs%.", "Ms%.", "Dr%.", "Prof%.",
        "U%.S%.A%.", "etc%.", "vs%.", "e%.g%.", "i%.e%."
    }

    local processed = text
    for _, abbrev in ipairs(abbreviations) do
        processed = string.gsub(processed, abbrev, function(match)
            return string.gsub(match, "%.", "§ABBREV§")
        end)
    end

    return processed
end

---=============================================================================
-- DISPLAY AND RENDERING
--=============================================================================

function CinematicCam:DisplayCurrentChunk()
    local control = CinematicCam.chunkedDialogueData.customControl
    local background = CinematicCam.chunkedDialogueData.backgroundControl
    local chunkIndex = CinematicCam.chunkedDialogueData.currentChunkIndex
    if self.savedVars.interaction.layoutPreset == "default" then
        -- Just handle the timing logic, no visual display
        return
    end
    if not control or chunkIndex > #CinematicCam.chunkedDialogueData.chunks then
        return
    end

    -- Get chunk text
    local displayChunks = CinematicCam.chunkedDialogueData.displayChunks or CinematicCam.chunkedDialogueData.chunks
    local chunkText = displayChunks[chunkIndex]

    -- Process text and apply formatting
    chunkText = string.gsub(chunkText, "§ABBREV§", ".")
    local fontString = self:BuildUserFontString()
    control:SetFont(fontString)
    control:SetText(chunkText)

    -- Check if we should display based on interaction type
    if self:ShouldHideForInteractionType() then
        self:HideChunkDisplay(control, background)
        return
    end

    -- Show text control
    control:SetHidden(false)

    -- Handle background
    self:UpdateChunkBackground(control, background)

    -- Update overall visibility
    self:UpdateChunkedTextVisibility()
end

function CinematicCam:ShouldHidePlayerOptionsForInteraction()
    if not self.savedVars.interaction.subtitles.hidePlayerOptionsUntilLastChunk then
        return false
    end

    local interactionType = GetInteractionType()

    -- Only hide for dialogue/conversation interactions, NEVER for merchants/banks/etc
    return interactionType == INTERACTION_CONVERSATION or interactionType == INTERACTION_QUEST
end

function CinematicCam:ShouldHideForInteractionType()
    local interactionType = GetInteractionType()
    local hideTypes = {
        INTERACTION_DYE_STATION,
        INTERACTION_CRAFT,
        INTERACTION_NONE,
        INTERACTION_LOCKPICK,
        INTERACTION_BOOK
    }

    for _, hideType in ipairs(hideTypes) do
        if interactionType == hideType then
            return true
        end
    end

    return false
end

function CinematicCam:HideChunkDisplay(control, background)
    control:SetText("")
    control:SetHidden(true)
    if background then
        background:SetHidden(true)
    end
end

function CinematicCam:UpdateChunkBackground(control, background)
    if background and self:ShouldShowSubtitleBackground() then
        -- Calculate dynamic dimensions
        local textWidth = control:GetTextWidth()
        local textHeight = control:GetTextHeight()

        local padding = 16
        local backgroundWidth = textWidth + (padding * 2)
        local backgroundHeight = textHeight + (padding * 2)

        -- Apply size constraints
        local minWidth, maxWidth = 200, 2800
        local minHeight, maxHeight = 40, 200

        backgroundWidth = math.max(minWidth, math.min(maxWidth, backgroundWidth))
        backgroundHeight = math.max(minHeight, math.min(maxHeight, backgroundHeight))

        -- Position and show background
        background:SetDimensions(backgroundWidth, backgroundHeight)

        local targetX, targetY = self:ConvertToScreenCoordinates(
            self.savedVars.interaction.subtitles.posX or 0.5,
            self.savedVars.interaction.subtitles.posY or 0.7
        )

        background:ClearAnchors()
        background:SetAnchor(CENTER, GuiRoot, CENTER, targetX, targetY)
        background:SetHidden(false)
    elseif background then
        background:SetHidden(true)
    end
end

---=============================================================================
-- HIDE PLAYER OPTIONS
--=============================================================================
function CinematicCam:OnPlayerOptionsSettingChanged(newValue, isVendor)
    -- If we're currently in dialogue and chunked dialogue is active
    if isVendor then
        return
    end
    if CinematicCam.chunkedDialogueData.isActive then
        if newValue then
            -- Setting was turned ON - hide player options if we have multiple chunks
            -- and we're not on the last chunk
            local currentChunk = CinematicCam.chunkedDialogueData.currentChunkIndex
            local totalChunks = #CinematicCam.chunkedDialogueData.chunks

            if totalChunks > 1 and currentChunk < totalChunks then
                self:HidePlayerOptionsUntilLastChunk()
            end
        else
            -- Setting was turned OFF - show player options immediately
            if CinematicCam.chunkedDialogueData.playerOptionsHidden then
                self:ShowPlayerOptionsOnLastChunk()
            end
        end
    end
end

function CinematicCam:HidePlayerOptionsUntilLastChunk()
    if CinematicCam.chunkedDialogueData.playerOptionsHidden then
        return -- Already hidden
    end

    local playerOptionElements = {
        "ZO_InteractWindowPlayerAreaOptions",
        "ZO_InteractWindow_GamepadContainerInteractList",
        "ZO_InteractWindow_GamepadContainerInteract",
        "ZO_InteractWindowPlayerAreaHighlight"
    }

    -- Store original visibility and hide elements
    for _, elementName in ipairs(playerOptionElements) do
        local element = _G[elementName]
        if element then
            -- Store original visibility state in chunkedDialogueData, NOT savedVars
            CinematicCam.chunkedDialogueData.originalPlayerOptionsVisibility[elementName] = not element:IsHidden()
            element:SetHidden(true)
        end
    end

    CinematicCam.chunkedDialogueData.playerOptionsHidden = true -- Use chunkedDialogueData
end

function CinematicCam:ShowPlayerOptionsOnLastChunk()
    if not CinematicCam.chunkedDialogueData.playerOptionsHidden then
        return -- Not hidden, nothing to show
    end

    -- Restore original visibility for all stored elements
    for elementName, wasVisible in pairs(CinematicCam.chunkedDialogueData.originalPlayerOptionsVisibility) do
        local element = _G[elementName]
        if element and wasVisible then
            element:SetHidden(false)
        end
    end

    CinematicCam.chunkedDialogueData.playerOptionsHidden = false
    CinematicCam.chunkedDialogueData.originalPlayerOptionsVisibility = {}
end

---=============================================================================
-- POSITIONING AND LAYOUT
--=============================================================================

function CinematicCam:PositionChunkedTextControl(control)
    local preset = self.savedVars.interaction.layoutPreset

    if preset == "default" then
        self:PositionForDefaultPreset(control)
    elseif preset == "cinematic" then
        self:PositionForCinematicPreset(control)
    end
end

function CinematicCam:PositionForDefaultPreset(control)
    if CinematicCam.chunkedDialogueData.sourceElement then
        control:ClearAnchors()
        control:SetAnchor(CENTER, CinematicCam.chunkedDialogueData.sourceElement, CENTER, 0, -100)
        control:SetDimensions(CinematicCam.chunkedDialogueData.sourceElement:GetDimensions())
    end
end

function CinematicCam:PositionForCinematicPreset(control)
    local safeWidth, safeHeight, screenWidth, screenHeight = self:GetSafeScreenDimensions()

    local targetX, targetY = self:ConvertToScreenCoordinates(
        self.savedVars.interaction.subtitles.posX or 0.5,
        self.savedVars.interaction.subtitles.posY or 0.7
    )

    control:ClearAnchors()
    control:SetAnchor(CENTER, GuiRoot, CENTER, targetX, targetY)

    -- Use safe screen width instead of fixed 2700
    -- Limit height to prevent vertical overflow
    control:SetDimensions(safeWidth, math.min(safeHeight * 0.3, 200))
end

---=============================================================================
-- TIMING AND SCHEDULING
--=============================================================================

function CinematicCam:ScheduleNextChunk()
    if CinematicCam.chunkedDialogueData.displayTimer then
        zo_removeCallLater(CinematicCam.chunkedDialogueData.displayTimer)
    end

    -- Calculate timing for current chunk
    local currentChunkIndex = CinematicCam.chunkedDialogueData.currentChunkIndex
    local currentChunk = CinematicCam.chunkedDialogueData.chunks[currentChunkIndex]
    local displayTime = self:CalculateChunkDisplayTime(currentChunk)

    -- Convert to milliseconds and schedule
    local displayTimeMs = displayTime * 1000

    CinematicCam.chunkedDialogueData.displayTimer = zo_callLater(function()
        self:AdvanceToNextChunk()
    end, displayTimeMs)
end

function CinematicCam:AdvanceToNextChunk()
    CinematicCam.chunkedDialogueData.currentChunkIndex = CinematicCam.chunkedDialogueData.currentChunkIndex + 1

    if CinematicCam.chunkedDialogueData.currentChunkIndex <= #CinematicCam.chunkedDialogueData.chunks then
        -- Check if this is the last chunk
        local isLastChunk = CinematicCam.chunkedDialogueData.currentChunkIndex ==
            #CinematicCam.chunkedDialogueData.chunks

        -- Show player options if this is the last chunk
        if isLastChunk then
            self:ShowPlayerOptionsOnLastChunk()
        end

        self:DisplayCurrentChunk()

        if self.savedVars.interaction.subtitles.useChunkedDialogue and #CinematicCam.chunkedDialogueData.chunks > 1 and not isLastChunk then
            self:ScheduleNextChunk()
        end
    end
end

function CinematicCam:CalculateChunkDisplayTime(chunkText)
    local timingChunks = CinematicCam.chunkedDialogueData.chunks
    local chunkIndex = CinematicCam.chunkedDialogueData.currentChunkIndex

    local timingText = timingChunks[chunkIndex]

    if not timingText or timingText == "" then
        return self.savedVars.chunkedDialog.baseDisplayTime or 1.0
    end

    local cleanText = self:CleanTextForTiming(timingText)
    local textLength = string.len(cleanText)

    -- Base calculation
    local baseTime = 0.4
    local timePerChar = 0.06
    local displayTime = baseTime + (textLength * timePerChar)

    -- Add punctuation timing if enabled
    if self.savedVars.chunkedDialog.timingMode ~= "fixed" and self.savedVars.chunkedDialog.usePunctuationTiming then
        local punctuationTime = self:CalculatePunctuationTime(cleanText)
        displayTime = displayTime + punctuationTime
    end

    -- Apply min/max constraints
    if self.savedVars.chunkedDialog.timingMode ~= "fixed" then
        local minTime = self.savedVars.chunkedDialog.minDisplayTime or 1.5
        local maxTime = self.savedVars.chunkedDialog.maxDisplayTime or 8.0
        displayTime = math.max(minTime, displayTime)
        displayTime = math.min(maxTime, displayTime)
    end

    return displayTime
end

function CinematicCam:CalculatePunctuationTime(text)
    if not text or not self.savedVars.chunkedDialog.usePunctuationTiming then
        return 0
    end

    local totalPunctuationTime = 0
    local punctuationCounts = {
        ["-"] = 0,
        ["—"] = 0,
        ["–"] = 0,
        [","] = 0,
        [";"] = 0,
        [":"] = 0,
        ["."] = 0
    }

    -- Count punctuation marks
    for i = 1, #text do
        local char = text:sub(i, i)
        if punctuationCounts[char] ~= nil then
            punctuationCounts[char] = punctuationCounts[char] + 1
        end
    end

    -- Count ellipsis
    local ellipsisCount = 0
    ellipsisCount = ellipsisCount + select(2, string.gsub(text, "%.%.%.", "")) -- Three dots
    ellipsisCount = ellipsisCount + select(2, string.gsub(text, "…", "")) -- Unicode ellipsis

    -- Calculate timing
    totalPunctuationTime = totalPunctuationTime + (punctuationCounts["-"] * 0.3)
    totalPunctuationTime = totalPunctuationTime + (punctuationCounts["—"] * 0.4)
    totalPunctuationTime = totalPunctuationTime + (punctuationCounts["–"] * 0.4)
    totalPunctuationTime = totalPunctuationTime + (punctuationCounts[","] * 0.7)
    totalPunctuationTime = totalPunctuationTime + (punctuationCounts[";"] * 0.25)
    totalPunctuationTime = totalPunctuationTime + (punctuationCounts[":"] * 0.3)
    totalPunctuationTime = totalPunctuationTime + (punctuationCounts["."] * 0.3)
    totalPunctuationTime = totalPunctuationTime +
        (ellipsisCount * (self.savedVars.chunkedDialog.ellipsisPauseTime or 0.5))

    return totalPunctuationTime
end

function CinematicCam:PreviewChunkTiming(chunks)
    local totalTime = 0
    for i, chunk in ipairs(chunks) do
        local chunkTime = self:CalculateChunkDisplayTime(chunk)
        totalTime = totalTime + chunkTime
    end
    -- Could add debug output here if needed
end

---=============================================================================
-- MONITORING AND CLEANUP
--=============================================================================

function CinematicCam:StartDialogueChangeMonitoring()
    -- Cancel any existing monitoring
    if dialogueChangeCheckTimer then
        zo_removeCallLater(dialogueChangeCheckTimer)
        dialogueChangeCheckTimer = nil
    end

    local function checkForDialogueChange()
        if not CinematicCam.chunkedDialogueData.isActive then
            dialogueChangeCheckTimer = nil
            return
        end

        local currentRawText, _ = self:GetDialogueText()


        if currentRawText and currentRawText ~= CinematicCam.chunkedDialogueData.rawDialogueText then
            if string.len(currentRawText) > 10 then
                -- Hide player options before any processing
                if self.savedVars.interaction.subtitles.hidePlayerOptionsUntilLastChunk then
                    self:HidePlayerOptionsUntilLastChunk()
                end

                if self.savedVars.interaction.layoutPreset == "cinematic" then
                    -- Small delay to ensure ESO's UI has updated
                    zo_callLater(function()
                        self:InterceptDialogueForChunking()
                    end)
                end
                return
            end
        end

        -- Check for interaction end conditions
        local interactionType = GetInteractionType()
        if interactionType == INTERACTION_ANTIQUITY_DIG_SPOT or interactionType == INTERACTION_NONE then
            self:CleanupChunkedDialogue()
            return
        end


        dialogueChangeCheckTimer = zo_callLater(function()
            checkForDialogueChange()
        end, 1)
    end

    checkForDialogueChange()
end

function CinematicCam:CleanupChunkedDialogue()
    -- Cancel timers
    if CinematicCam.chunkedDialogueData.displayTimer then
        zo_removeCallLater(CinematicCam.chunkedDialogueData.displayTimer)
        CinematicCam.chunkedDialogueData.displayTimer = nil
    end

    if dialogueChangeCheckTimer then
        zo_removeCallLater(dialogueChangeCheckTimer)
        dialogueChangeCheckTimer = nil
    end

    -- Restore player options if they were hidden
    if CinematicCam.chunkedDialogueData.playerOptionsHidden then
        self:ShowPlayerOptionsOnLastChunk()
    end

    -- Hide all controls
    self:HideAllChunkedControls()

    -- Restore original elements
    self:RestoreOriginalElements()

    -- Reset state
    self:ResetChunkedDialogueState()
end

function CinematicCam:HideAllChunkedControls()
    if CinematicCam.chunkedDialogueData.customControl then
        CinematicCam.chunkedDialogueData.customControl:SetHidden(true)
        CinematicCam.chunkedDialogueData.customControl:SetText("")
    end

    if CinematicCam.chunkedDialogueData.backgroundControl then
        CinematicCam.chunkedDialogueData.backgroundControl:SetHidden(true)
    end

    if CinematicCam.chunkedDialogueData.playerOptionsBackgroundControl then
        CinematicCam.chunkedDialogueData.playerOptionsBackgroundControl:SetHidden(true)
    end

    if CinematicCam.npcNameData.customNameControl then
        CinematicCam.npcNameData.customNameControl:SetHidden(true)
        CinematicCam.npcNameData.customNameControl:SetText("")
    end
end

function CinematicCam:RestoreOriginalElements()
    if CinematicCam.chunkedDialogueData.sourceElement then
        CinematicCam.chunkedDialogueData.sourceElement:SetHidden(self.savedVars.interaction.subtitles.isHidden)
    end

    if CinematicCam.npcNameData.currentPreset == "default" then
        local _, originalNameElement = self:GetNPCName()
        if originalNameElement then
            originalNameElement:SetHidden(false)
        end
    end
end

function CinematicCam:ResetChunkedDialogueState()
    -- Preserve control references
    local backgroundControl = CinematicCam.chunkedDialogueData.backgroundControl
    local playerOptionsBackgroundControl = CinematicCam.chunkedDialogueData.playerOptionsBackgroundControl
    local customControl = CinematicCam.chunkedDialogueData.customControl

    CinematicCam.chunkedDialogueData = {
        originalText = "",
        chunks = {},
        displayChunks = {},
        currentChunkIndex = 0,
        isActive = false,
        customControl = customControl,
        backgroundControl = backgroundControl,
        playerOptionsBackgroundControl = playerOptionsBackgroundControl,
        displayTimer = nil,
        sourceElement = nil,
        rawDialogueText = "",
        playerOptionsHidden = false,
        originalPlayerOptionsVisibility = {}
    }

    CinematicCam.npcNameData.originalName = ""
    CinematicCam.npcNameData.currentPreset = "default"
end

---=============================================================================
-- INITIALIZATION AND SETUP
--=============================================================================

function CinematicCam:CreateChunkedTextControl()
    if CinematicCam.chunkedDialogueData.customControl then
        return CinematicCam.chunkedDialogueData.customControl
    end

    local control = CreateControl("CinematicCam_ChunkedDialogue", GuiRoot, CT_LABEL)

    -- Apply font styling
    self:ApplyFontToElement(control, self.savedVars.interface.customFontSize)

    -- Text properties
    control:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    control:SetVerticalAlignment(TEXT_ALIGN_TOP)
    control:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    control:SetColor(0.9, 0.9, 0.8, 1.0)

    -- Initial state
    control:SetHidden(true)

    -- Position the control
    self:PositionChunkedTextControl(control)

    -- Store reference
    CinematicCam.chunkedDialogueData.customControl = control

    -- Initialize background
    self:ConfigureChunkedTextBackground()

    return control
end

function CinematicCam:InitializeChunkedDisplay()
    if #CinematicCam.chunkedDialogueData.chunks == 0 then
        return false
    end

    -- Hide source element
    if CinematicCam.chunkedDialogueData.sourceElement then
        CinematicCam.chunkedDialogueData.sourceElement:SetHidden(true)
    end

    -- Hide player options ONLY for dialogue interactions and if we have multiple chunks
    if self:ShouldHidePlayerOptionsForInteraction() and #CinematicCam.chunkedDialogueData.chunks > 1 and CinematicCam.PlayerOptionsAlways == false then
        self:HidePlayerOptionsUntilLastChunk()
    end

    -- Ensure control exists
    if not CinematicCam.chunkedDialogueData.customControl then
        self:InitializeChunkedTextControl()
    end

    local control = CinematicCam.chunkedDialogueData.customControl
    if not control then
        return false
    end

    -- Setup display
    self:ApplyChunkedTextPositioning()
    CinematicCam.chunkedDialogueData.currentChunkIndex = 1
    CinematicCam.chunkedDialogueData.isActive = true

    -- Display first chunk
    self:DisplayCurrentChunk()

    -- Schedule next chunk if multiple chunks exist
    if #CinematicCam.chunkedDialogueData.chunks > 1 then
        self:ScheduleNextChunk()
    end

    return true
end

function CinematicCam:ConfigureChunkedTextBackground()
    local background = _G["CinematicCam_ChunkedTextBackground"]
    if background then
        -- Background properties
        background:SetAlpha(0.4)
        background:SetDrawLayer(DL_CONTROLS)
        background:SetDrawLevel(9)
        background:SetHidden(true)

        -- Store reference
        CinematicCam.chunkedDialogueData.backgroundControl = background

        -- Initialize position
        background:ClearAnchors()
        background:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
        background:SetDimensions(1, 1)
    end
end

function CinematicCam:ConfigurePlayerOptionsBackground()
    local background = _G["CinematicCam_PlayerOptionsBackground"]
    if background then
        -- Background properties
        background:SetColor(0.2, 0.2, 0.2, 0.7)
        background:SetDrawLayer(DL_CONTROLS)
        background:SetDrawLevel(8) -- slightly lower than subtitle background (9)
        background:SetHidden(true)

        -- Store reference
        CinematicCam.chunkedDialogueData.playerOptionsBackgroundControl = background

        -- Initialize position
        background:ClearAnchors()
        background:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
        background:SetDimensions(1, 1)
    end
end

---=============================================================================
-- UTILITY FUNCTIONS
--=============================================================================

function CinematicCam:UpdateChunkedTextFont()
    local control = CinematicCam.chunkedDialogueData.customControl
    if control then
        self:ApplyFontToElement(control, self.savedVars.interface.customFontSize)
    end
end

function CinematicCam:UpdateChunkedTextVisibility()
    local control = CinematicCam.chunkedDialogueData.customControl
    local background = CinematicCam.chunkedDialogueData.backgroundControl

    if control then
        if self.savedVars.interaction.subtitles.isHidden then
            control:SetAlpha(0)
            if background then background:SetHidden(true) end
        else
            control:SetAlpha(1.0)
            --TODO Fix the background apeparenign when the option was selected, but disabled when the user change preset from cinematic to defalt
            if background and self.savedVars.interface and self.savedVars.interface.useSubtitleBackground then
                background:SetHidden(false)
            end
        end
    end
end

function CinematicCam:HideChunkedTextBackground()
    if CinematicCam.chunkedDialogueData.backgroundControl then
        CinematicCam.chunkedDialogueData.backgroundControl:SetHidden(true)
    end
end

function CinematicCam:OnChunkedDialogueComplete()
    zo_callLater(function()
        if CinematicCam.chunkedDialogueData.customControl then
            CinematicCam.chunkedDialogueData.customControl:SetHidden(true)
            CinematicCam.chunkedDialogueData.customControl:SetText("")
        end

        if CinematicCam.chunkedDialogueData.sourceElement then
            CinematicCam.chunkedDialogueData.sourceElement:SetHidden(self.savedVars.interaction.subtitles.isHidden)
        end
    end, 2000)
end

function CinematicCam:CleanTextForTiming(text)
    if not text then return "" end

    -- Remove abbreviation markers
    local cleaned = string.gsub(text, "§ABBREV§", ".")

    -- Remove extra whitespace
    cleaned = string.gsub(cleaned, "%s+", " ")
    cleaned = self:TrimString(cleaned)

    return cleaned
end

function CinematicCam:TrimString(str)
    if not str or type(str) ~= "string" then
        return ""
    end
    local trimmed = string.gsub(str, "^%s*", "")
    trimmed = string.gsub(trimmed, "%s*$", "")
    return trimmed
end

function CinematicCam:IsValidChunkBoundary(text, position, currentChunk, minLength)
    if string.len(currentChunk) < minLength then
        return false
    end

    local nextChar = text:sub(position + 1, position + 1)
    if nextChar == " " or nextChar == "\n" or nextChar == "\t" or nextChar == "" then
        return true
    end

    if string.match(nextChar, "%w") then
        return false
    end

    return true
end

function CinematicCam:FindWordBoundary(text, maxPosition)
    for i = maxPosition, 1, -1 do
        if text:sub(i, i) == " " then
            return i - 1
        end
    end
    return maxPosition
end

function CinematicCam:GetSafeScreenDimensions()
    local screenWidth, screenHeight = GuiRoot:GetDimensions()

    -- Account for letterbox if active
    local availableHeight = screenHeight
    if self.savedVars.letterbox.letterboxVisible then
        availableHeight = screenHeight - (self.savedVars.letterbox.size * 2)
    end

    -- Leave margins for safety (10% on each side)
    local safeWidth = screenWidth * 0.8
    local safeHeight = availableHeight * 0.8

    return safeWidth, safeHeight, screenWidth, screenHeight
end
