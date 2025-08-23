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
    rawDialogueText = ""
}

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

function CinematicCam:ConfigureChunkedTextBackground()
    local background = _G["CinematicCam_ChunkedTextBackground"]
    if background then
        -- Background properties
        background:SetAlpha(0.6)
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
-- MAIN DIALOGUE INTERCEPTION AND PROCESSING
--=============================================================================

function CinematicCam:InterceptDialogueForChunking()
    local originalText, sourceElement = self:GetDialogueText()

    if not originalText or string.len(originalText) == 0 then
        return false
    end

    -- Apply NPC name preset
    self:ApplyNPCNamePreset()

    -- Prepare text versions
    local textForTiming = originalText
    local processedTextForDisplay = self:ProcessNPCNameForPreset(
        originalText,
        CinematicCam.npcNameData.originalName,
        self.savedVars.npcNamePreset
    )

    -- Handle source element visibility
    self:HandleSourceElementVisibility(sourceElement)

    -- Clean up any existing display
    if CinematicCam.chunkedDialogueData.isActive then
        self:CleanupChunkedDialogue()
    end

    -- Store dialogue data
    self:StoreDialogueData(processedTextForDisplay, sourceElement, originalText)

    -- Process and display if chunked dialogue is enabled
    if self.savedVars.interaction.subtitles.useChunkedDialogue then
        return self:ProcessAndDisplayChunkedDialogue(textForTiming, processedTextForDisplay)
    end

    return false
end

function CinematicCam:HandleSourceElementVisibility(sourceElement)
    if not sourceElement then return end

    if self.savedVars.interaction.layoutPreset == "default" then
        sourceElement:SetHidden(false)
    elseif self.savedVars.interaction.layoutPreset == "cinematic" then
        sourceElement:SetHidden(true)
    end
end

function CinematicCam:StoreDialogueData(processedText, sourceElement, originalText)
    CinematicCam.chunkedDialogueData.originalText = processedText
    CinematicCam.chunkedDialogueData.sourceElement = sourceElement
    CinematicCam.chunkedDialogueData.rawDialogueText = originalText
end

function CinematicCam:ProcessAndDisplayChunkedDialogue(textForTiming, processedTextForDisplay)
    -- Process text into chunks
    CinematicCam.chunkedDialogueData.chunks = self:ProcessTextIntoChunks(textForTiming)
    CinematicCam.chunkedDialogueData.displayChunks = self:ProcessTextIntoDisplayChunks(processedTextForDisplay)

    if #CinematicCam.chunkedDialogueData.chunks >= 1 then
        self:StartDialogueChangeMonitoring()
        return self:InitializeChunkedDisplay()
    else
        -- Fallback to single chunk
        CinematicCam.chunkedDialogueData.chunks = { textForTiming }
        CinematicCam.chunkedDialogueData.displayChunks = { processedTextForDisplay }
        self:StartDialogueChangeMonitoring()
        return self:InitializeCompleteTextDisplay()
    end
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

function CinematicCam:InitializeChunkedDisplay()
    if #CinematicCam.chunkedDialogueData.chunks == 0 then
        return false
    end

    -- Hide source element
    if CinematicCam.chunkedDialogueData.sourceElement then
        CinematicCam.chunkedDialogueData.sourceElement:SetHidden(true)
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

function CinematicCam:DisplayCurrentChunk()
    local control = CinematicCam.chunkedDialogueData.customControl
    local background = CinematicCam.chunkedDialogueData.backgroundControl
    local chunkIndex = CinematicCam.chunkedDialogueData.currentChunkIndex

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
        local minWidth, maxWidth = 200, 2200
        local minHeight, maxHeight = 40, 230

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
    local targetX, targetY = self:ConvertToScreenCoordinates(
        self.savedVars.interaction.subtitles.posX or 0.5,
        self.savedVars.interaction.subtitles.posY or 0.7
    )

    control:ClearAnchors()
    control:SetAnchor(CENTER, GuiRoot, CENTER, targetX, targetY)
    control:SetDimensions(2700, 200)
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
        self:DisplayCurrentChunk()

        if self.savedVars.interaction.subtitles.useChunkedDialogue and #CinematicCam.chunkedDialogueData.chunks > 1 then
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

        -- Check for dialogue text changes
        if currentRawText and currentRawText ~= CinematicCam.chunkedDialogueData.rawDialogueText then
            if string.len(currentRawText) > 10 then
                self:CleanupChunkedDialogue()

                if self.savedVars.interaction.layoutPreset == "cinematic" then
                    self:InterceptDialogueForChunking()
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

        -- Schedule next check
        dialogueChangeCheckTimer = zo_callLater(checkForDialogueChange, 200)
    end

    -- Start monitoring
    dialogueChangeCheckTimer = zo_callLater(checkForDialogueChange, 200)
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
        rawDialogueText = ""
    }

    CinematicCam.npcNameData.originalName = ""
    CinematicCam.npcNameData.currentPreset = "default"
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
