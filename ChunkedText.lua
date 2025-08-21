local dialogueChangeCheckTimer = nil
CinematicCam.chunkedDialogueData = {
    originalText = "",
    chunks = {},
    currentChunkIndex = 0,
    isActive = false,
    customControl = nil,
    displayTimer = nil,
    backgroundControl = nil,
    playerOptionsBackgroundControl = nil
}

--TODO cant find ResizeBackgroundToText() -- the subtitle background is too talland needs to be positioned slightly lower
-- Playher options needs to stay persisnt until dialog end

---=============================================================================
-- Chunked Text
--=============================================================================
-- Create XML elements
function CinematicCam:CreateChunkedTextControl()
    if CinematicCam.chunkedDialogueData.customControl then
        return CinematicCam.chunkedDialogueData.customControl
    end
    local control = CreateControl("CinematicCam_ChunkedDialogue", GuiRoot, CT_LABEL)

    self:ApplyFontToElement(control, self.savedVars.interface.customFontSize)

    -- Text Properties
    control:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    control:SetVerticalAlignment(TEXT_ALIGN_TOP)
    control:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    control:SetColor(0.9, 0.9, 0.8, 1.0)

    -- Set Position
    self:PositionChunkedTextControl(control)
    control:SetHidden(true)

    CinematicCam.chunkedDialogueData.customControl = control

    -- Load background
    self:ConfigureChunkedTextBackground()

    return control
end

function CinematicCam:ConfigurePlayerOptionsBackground()
    local background = _G["CinematicCam_PlayerOptionsBackground"]
    if background then
        -- Background Properties
        background:SetColor(0.2, 0.2, 0.2, 0.7)
        background:SetDrawLayer(DL_CONTROLS)
        background:SetDrawLevel(8) -- slightly lower than subtitle background (9)
        background:SetHidden(true)

        -- Store reference for later use
        CinematicCam.chunkedDialogueData.playerOptionsBackgroundControl = background

        -- Initialize position
        background:ClearAnchors()
        background:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
        background:SetDimensions(1, 1)
    end
end

function CinematicCam:ConfigureChunkedTextBackground()
    local background = _G["CinematicCam_ChunkedTextBackground"]
    if background then
        -- Background Properties
        background:SetColor(0.2, 0.2, 0.2, 0.7)
        background:SetDrawLayer(DL_CONTROLS)
        background:SetDrawLevel(9)
        background:SetHidden(true)

        -- Store reference for later use
        CinematicCam.chunkedDialogueData.backgroundControl = background

        -- Initialize position
        background:ClearAnchors()
        background:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
        background:SetDimensions(1, 1)
    end
end

function CinematicCam:PositionChunkedTextControl(control)
    local preset = self.savedVars.interaction.layoutPreset
    local background = CinematicCam.chunkedDialogueData.backgroundControl

    if preset == "default" then
        if CinematicCam.chunkedDialogueData.sourceElement then
            control:ClearAnchors()
            control:SetAnchor(CENTER, CinematicCam.chunkedDialogueData.sourceElement, CENTER, 0, -100)
            control:SetDimensions(CinematicCam.chunkedDialogueData.sourceElement:GetDimensions())

            -- Position background slightly below text center
            if background then
                background:ClearAnchors()
                background:SetAnchor(CENTER, CinematicCam.chunkedDialogueData.sourceElement, CENTER, 0, -99) -- 1px lower
                self:ResizeBackgroundToText()
            end
        end
    elseif preset == "cinematic" then
        -- Get target position
        local targetX, targetY = self:ConvertToScreenCoordinates(
            self.savedVars.interaction.subtitles.posX or 0.5,
            self.savedVars.interaction.subtitles.posY or 0.7
        )

        -- Position text control
        control:ClearAnchors()
        control:SetAnchor(CENTER, GuiRoot, CENTER, targetX, targetY)
        control:SetDimensions(2700, 200)

        -- Position background slightly below text center
        if background then
            background:ClearAnchors()
            background:SetAnchor(CENTER, GuiRoot, CENTER, targetX, targetY - 5) -- 5px lower
            self:ResizeBackgroundToText()
        end
    end
end

-- Call this after text changes to update background size
function CinematicCam:UpdateBackgroundSize()
    zo_callLater(function()
        self:ResizeBackgroundToText()
    end, 10)
end

-- Monitoring
function CinematicCam:StartDialogueChangeMonitoring()
    -- Cancel any existing monitoring
    if dialogueChangeCheckTimer then
        zo_removeCallLater(dialogueChangeCheckTimer)
        dialogueChangeCheckTimer = nil
    end

    -- Start periodic checking for dialogue changes
    local function checkForDialogueChange()
        if not CinematicCam.chunkedDialogueData.isActive then
            -- Stop monitoring if chunked dialogue is not active
            dialogueChangeCheckTimer = nil
            return
        end

        local currentRawText, _ = self:GetDialogueText()

        -- Compare RAW text instead of processed text
        if currentRawText and currentRawText ~= CinematicCam.chunkedDialogueData.rawDialogueText then
            if string.len(currentRawText) > 10 then
                -- Cleanup current chunked dialogue
                self:CleanupChunkedDialogue()

                -- Try to start new chunked dialogue for the new text
                if self.savedVars.interaction.layoutPreset == "cinematic" then
                    self:InterceptDialogueForChunking()
                end
                return
            end
        end
        local interactionType = GetInteractionType()
        if interactionType == NTERACTION_ANTIQUITY_DIG_SPOT then
            self:CleanupChunkedDialogue()
            return
        end

        if interactionType == INTERACTION_NONE then
            self:CleanupChunkedDialogue()
            return
        end

        -- Schedule next check
        dialogueChangeCheckTimer = zo_callLater(checkForDialogueChange, 200)
    end

    -- Start the monitoring
    dialogueChangeCheckTimer = zo_callLater(checkForDialogueChange, 200)
end

function CinematicCam:InterceptDialogueForChunking()
    local originalText, sourceElement = self:GetDialogueText()

    if not originalText or string.len(originalText) == 0 then
        return false
    end

    self:ApplyNPCNamePreset()

    local textForTiming = originalText
    local processedTextForDisplay = self:ProcessNPCNameForPreset(
        originalText,
        CinematicCam.npcNameData.originalName,
        self.savedVars.npcNamePreset
    )

    if sourceElement and self.savedVars.interaction.layoutPreset == "default" then
        sourceElement:SetHidden(false)
    elseif sourceElement and self.savedVars.interaction.layoutPreset == "cinematic" then
        sourceElement:SetHidden(true)
    end

    -- CLEANUP ANY EXISTING DISPLAY
    if CinematicCam.chunkedDialogueData.isActive then
        self:CleanupChunkedDialogue()
    end

    -- Store both versions
    CinematicCam.chunkedDialogueData.originalText = processedTextForDisplay
    CinematicCam.chunkedDialogueData.sourceElement = sourceElement
    CinematicCam.chunkedDialogueData.rawDialogueText = originalText

    if self.savedVars.interaction.subtitles.useChunkedDialogue then
        CinematicCam.chunkedDialogueData.chunks = self:ProcessTextIntoChunks(textForTiming)
        CinematicCam.chunkedDialogueData.displayChunks = self:ProcessTextIntoDisplayChunks(processedTextForDisplay)

        function CinematicCam:InitializeChunkedDisplay()
            if #CinematicCam.chunkedDialogueData.chunks == 0 then
                return false
            end
            if CinematicCam.chunkedDialogueData.sourceElement then
                CinematicCam.chunkedDialogueData.sourceElement:SetHidden(true)
            end
            if not CinematicCam.chunkedDialogueData.customControl then
                self:InitializeChunkedTextControl()
            end
            local control = CinematicCam.chunkedDialogueData.customControl
            if not control then
                return false
            end
            self:ApplyChunkedTextPositioning()
            CinematicCam.chunkedDialogueData.currentChunkIndex = 1
            CinematicCam.chunkedDialogueData.isActive = true
            self:DisplayCurrentChunk()
            if #CinematicCam.chunkedDialogueData.chunks >= 1 then
                self:ScheduleNextChunk()
            end

            return true
        end

        if #CinematicCam.chunkedDialogueData.chunks >= 1 then
            self:StartDialogueChangeMonitoring()
            return self:InitializeChunkedDisplay()
        else
            CinematicCam.chunkedDialogueData.chunks = { textForTiming }
            CinematicCam.chunkedDialogueData.displayChunks = { processedTextForDisplay }
            self:StartDialogueChangeMonitoring()
            return self:InitializeCompleteTextDisplay()
        end
    end
end

-- processing
function CinematicCam:ProcessTextIntoDisplayChunks(fullText)
    if not fullText or fullText == "" then
        return {}
    end

    local chunks = {}
    local delimiters = self.savedVars.chunkedDialog.chunkDelimiters
    local minLength = self.savedVars.chunkedDialog.chunkMinLength
    local maxLength = self.savedVars.chunkedDialog.chunkMaxLength

    local processedText = self:PreprocessTextForChunking(fullText)

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

    local finalChunk = self:TrimString(currentChunk)
    if string.len(finalChunk) > 0 then
        table.insert(chunks, finalChunk)
    end

    return chunks
end

function CinematicCam:TrimString(str)
    if not str or type(str) ~= "string" then
        return ""
    end
    local trimmed = string.gsub(str, "^%s*", "")
    trimmed = string.gsub(trimmed, "%s*$", "")
    return trimmed
end

function CinematicCam:ProcessTextIntoChunks(fullText)
    if not fullText or fullText == "" then
        return {}
    end

    local chunks = {}
    local delimiters = self.savedVars.chunkedDialog.chunkDelimiters
    local minLength = self.savedVars.chunkedDialog.chunkMinLength
    local maxLength = self.savedVars.chunkedDialog.chunkMaxLength

    local processedText = self:PreprocessTextForChunking(fullText)

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

    local finalChunk = self:TrimString(currentChunk)
    if string.len(finalChunk) > 0 then
        table.insert(chunks, finalChunk)
    end

    -- Preview timing for all chunks
    if #chunks > 1 then
        local totalTime = 0
        for i, chunk in ipairs(chunks) do
            local chunkTime = self:CalculateChunkDisplayTime(chunk)
            totalTime = totalTime + chunkTime
        end
    end

    return chunks
end

-- display processed chunks
function CinematicCam:UpdateChunkedTextFont()
    local control = CinematicCam.chunkedDialogueData.customControl
    if control then
        self:ApplyFontToElement(control, self.savedVars.interface.customFontSize)
    end
end

function CinematicCam:DisplayCurrentChunk()
    local control = CinematicCam.chunkedDialogueData.customControl
    local background = CinematicCam.chunkedDialogueData.backgroundControl
    local chunkIndex = CinematicCam.chunkedDialogueData.currentChunkIndex

    if not control then
        return
    end

    if chunkIndex > #CinematicCam.chunkedDialogueData.chunks then
        return
    end

    local displayChunks = CinematicCam.chunkedDialogueData.displayChunks or CinematicCam.chunkedDialogueData.chunks
    local chunkText = displayChunks[chunkIndex]

    chunkText = string.gsub(chunkText, "§ABBREV§", ".")
    local fontString = self:BuildUserFontString()
    control:SetFont(fontString)

    -- Set text first
    control:SetText(chunkText)

    local interactionType = GetInteractionType()
    if interactionType == INTERACTION_DYE_STATION or interactionType == INTERACTION_CRAFT or
        interactionType == INTERACTION_NONE or interactionType == INTERACTION_LOCKPICK or
        interactionType == INTERACTION_BOOK then
        control:SetText("")
        control:SetHidden(true)
        if background then
            background:SetHidden(true)
        end
        return
    end

    -- Show text control
    control:SetHidden(false)

    -- Enhanced background handling with new system
    if background and self:ShouldShowSubtitleBackground() then
        -- Get text dimensions
        local textWidth = control:GetTextWidth()
        local textHeight = control:GetTextHeight()

        -- Add padding around the text
        local padding = 40
        local backgroundWidth = textWidth + (padding * 2)
        local backgroundHeight = textHeight + (padding * 2)

        -- Set minimum and maximum sizes
        local minWidth = 200
        local maxWidth = 1200
        local minHeight = 60
        local maxHeight = 300

        -- Clamp to min/max values
        backgroundWidth = math.max(minWidth, math.min(maxWidth, backgroundWidth))
        backgroundHeight = math.max(minHeight, math.min(maxHeight, backgroundHeight))

        -- Apply the new dimensions
        background:SetDimensions(backgroundWidth, backgroundHeight)
        background:SetHidden(false)
    elseif background then
        background:SetHidden(true)
    end

    -- Update visibility for both text and background
    self:UpdateChunkedTextVisibility()
end

function CinematicCam:HideChunkedTextBackground()
    if CinematicCam.chunkedDialogueData.backgroundControl then
        CinematicCam.chunkedDialogueData.backgroundControl:SetHidden(true)
    end
end

function CinematicCam:OnChunkedDialogueComplete()
    -- Keep the last chunk visible for a short time, then hide
    zo_callLater(function()
        if CinematicCam.chunkedDialogueData.customControl then
            CinematicCam.chunkedDialogueData.customControl:SetHidden(true)
            CinematicCam.chunkedDialogueData.customControl:SetText("")
        end

        -- Optionally restore original text
        if CinematicCam.chunkedDialogueData.sourceElement then
            CinematicCam.chunkedDialogueData.sourceElement:SetHidden(self.savedVars.interaction.subtitles.isHidden)
        end
    end, 2000) -- Hide after 2 seconds
end

function CinematicCam:CleanupChunkedDialogue()
    if CinematicCam.chunkedDialogueData.displayTimer then
        zo_removeCallLater(CinematicCam.chunkedDialogueData.displayTimer)
        CinematicCam.chunkedDialogueData.displayTimer = nil
    end

    -- Stop dialogue change monitoring
    if dialogueChangeCheckTimer then
        zo_removeCallLater(dialogueChangeCheckTimer)
        dialogueChangeCheckTimer = nil
    end

    -- Hide custom controls
    if CinematicCam.chunkedDialogueData.customControl then
        CinematicCam.chunkedDialogueData.customControl:SetHidden(true)
        CinematicCam.chunkedDialogueData.customControl:SetText("")
    end

    -- Hide subtitle background
    if CinematicCam.chunkedDialogueData.backgroundControl then
        CinematicCam.chunkedDialogueData.backgroundControl:SetHidden(true)
    end

    -- NEW: Hide player options background
    if CinematicCam.chunkedDialogueData.playerOptionsBackgroundControl then
        CinematicCam.chunkedDialogueData.playerOptionsBackgroundControl:SetHidden(true)
    end

    -- Hide custom NPC name control
    if CinematicCam.npcNameData.customNameControl then
        CinematicCam.npcNameData.customNameControl:SetHidden(true)
        CinematicCam.npcNameData.customNameControl:SetText("")
    end

    -- Restore original elements based on current settings
    if CinematicCam.chunkedDialogueData.sourceElement then
        CinematicCam.chunkedDialogueData.sourceElement:SetHidden(self.savedVars.interaction.subtitles.isHidden)
    end

    -- Restore NPC name element for default preset
    if CinematicCam.npcNameData.currentPreset == "default" then
        local _, originalNameElement = self:GetNPCName()
        if originalNameElement then
            originalNameElement:SetHidden(false)
        end
    end

    -- Reset state (preserve background control references)
    local backgroundControl = CinematicCam.chunkedDialogueData.backgroundControl
    local playerOptionsBackgroundControl = CinematicCam.chunkedDialogueData.playerOptionsBackgroundControl
    CinematicCam.chunkedDialogueData = {
        originalText = "",
        chunks = {},
        currentChunkIndex = 0,
        isActive = false,
        customControl = CinematicCam.chunkedDialogueData.customControl,
        backgroundControl = backgroundControl,
        playerOptionsBackgroundControl = playerOptionsBackgroundControl, -- NEW: preserve player options background
        displayTimer = nil,
        sourceElement = nil,
        rawDialogueText = ""
    }
    CinematicCam.npcNameData.originalName = ""
    CinematicCam.npcNameData.currentPreset = "default"
end

-- Timing
function CinematicCam:CalculateChunkDisplayTime(chunkText)
    local timingChunks = CinematicCam.chunkedDialogueData.chunks
    local chunkIndex = CinematicCam.chunkedDialogueData.currentChunkIndex

    local timingText = timingChunks[chunkIndex]

    if not timingText or timingText == "" then
        return self.savedVars.chunkedDialog.baseDisplayTime or 1.0
    end

    local cleanText = self:CleanTextForTiming(timingText)
    local textLength = string.len(cleanText)
    local displayTime

    local baseTime = 0.4
    local timePerChar = 0.06
    displayTime = baseTime + (textLength * timePerChar)

    if self.savedVars.chunkedDialog.timingMode ~= "fixed" and self.savedVars.chunkedDialog.usePunctuationTiming then
        local punctuationTime = self:CalculatePunctuationTime(cleanText)
        displayTime = displayTime + punctuationTime
    end

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

    local ellipsisCount = 0

    -- Count each character
    for i = 1, #text do
        local char = text:sub(i, i)
        if punctuationCounts[char] ~= nil then
            punctuationCounts[char] = punctuationCounts[char] + 1
        end
    end

    -- Count ellipsis
    ellipsisCount = ellipsisCount + select(2, string.gsub(text, "%.%.%.", "")) -- Three dots
    ellipsisCount = ellipsisCount + select(2, string.gsub(text, "…", "")) -- Unicode ellipsis

    -- Calculate total punctuation time
    totalPunctuationTime = totalPunctuationTime + (punctuationCounts["-"] * (0.3))
    totalPunctuationTime = totalPunctuationTime + (punctuationCounts["—"] * (0.4))
    totalPunctuationTime = totalPunctuationTime + (punctuationCounts["–"] * (0.4))
    totalPunctuationTime = totalPunctuationTime + (punctuationCounts[","] * (0.7))
    totalPunctuationTime = totalPunctuationTime + (punctuationCounts[";"] * (0.25))
    totalPunctuationTime = totalPunctuationTime + (punctuationCounts[":"] * (0.3))
    totalPunctuationTime = totalPunctuationTime + (punctuationCounts["."] * (0.3))
    totalPunctuationTime = totalPunctuationTime +
        (ellipsisCount * (self.savedVars.chunkedDialog.ellipsisPauseTime or 0.5))

    -- Debug output
    if totalPunctuationTime > 0 then
        local details = {}
        if punctuationCounts["-"] > 0 then table.insert(details, punctuationCounts["-"] .. " hyphens") end
        if punctuationCounts["—"] > 0 then table.insert(details, punctuationCounts["—"] .. " em-dashes") end
        if punctuationCounts[","] > 0 then table.insert(details, punctuationCounts[","] .. " commas") end
        if punctuationCounts[";"] > 0 then table.insert(details, punctuationCounts[";"] .. " semicolons") end
        if punctuationCounts[":"] > 0 then table.insert(details, punctuationCounts[":"] .. " colons") end
        if ellipsisCount > 0 then table.insert(details, ellipsisCount .. " ellipsis") end
    end
    return totalPunctuationTime
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

function CinematicCam:ScheduleNextChunk()
    if CinematicCam.chunkedDialogueData.displayTimer then
        zo_removeCallLater(CinematicCam.chunkedDialogueData.displayTimer)
    end

    -- Calculate timing for the CURRENT chunk (the one being displayed)
    local currentChunkIndex = CinematicCam.chunkedDialogueData.currentChunkIndex
    local currentChunk = CinematicCam.chunkedDialogueData.chunks[currentChunkIndex]
    local displayTime = self:CalculateChunkDisplayTime(currentChunk)

    -- Convert to milliseconds for zo_callLater
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

function CinematicCam:UpdateChunkedTextVisibility()
    local control = CinematicCam.chunkedDialogueData.customControl
    local background = CinematicCam.chunkedDialogueData.backgroundControl

    if control then
        if self.savedVars.interaction.subtitles.isHidden then
            control:SetAlpha(0)
            if background then background:SetHidden(true) end
        else
            control:SetAlpha(1.0)
            -- Show background if setting exists and is enabled
            if background and self.savedVars.interface and self.savedVars.interface.useSubtitleBackground then
                background:SetHidden(false)
            end
        end
    end
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
