--[[ TODO
Zarith-Var - Slow talker
Dye Station - separate tgoggle
Clean up dialogue when using crtafting stations stations
Force remvoe black bars more accresively
Ignore font images: use default
Add another font
Reposition:
 - Player choices - adjust x-y
  - Npc Name (appened or above text or original)
  - Show dialogue after npc is done talking.
  0 fade in dialogue choices
--]]

-- Cinematic Camera with UI Hiding and Letterbox
local ADDON_NAME = "CinematicCam"
CinematicCam = {}
CinematicCam.savedVars = nil

local uiElementsMap = {}      -- table for hiding ui elements, used in HideUI()
local interactionTypeMap = {} -- table for interaction type settings

-- State tracking
local isInteractionModified = false -- is default camera overridden?
local mountLetterbox = false
local dialogLetterbox = false
local wasUIAutoHidden = false
CinematicCam.currentRepositionPreset = "default"
local lastDialogueText = ""
local dialogueChangeCheckTimer = nil

-- Default settings
local defaults = {
    camEnabled = false,
    letterbox = {
        size = 100,
        opacity = 1.0,
        letterboxVisible = false,
        autoLetterboxMount = false,
        coordinateWithLetterbox = true,
        mountLetterboxDelay = 0,

    },
    interaction = {
        forceThirdPersonDialogue = true,
        forceThirdPersonVendor = false,
        forceThirdPersonBank = false,
        forceThirdPersonQuest = true,
        forceThirdPersonCrafting = false,
        hidePlayerOptions = false,
        layoutPreset = "default",
        ui = {
            hidePanelsESO = false,
        },
        auto = {
            autoLetterboxDialogue = false,
            autoHideUIDialogue = false,
            autoLetterboxConversation = true,
            autoLetterboxQuest = true,
            autoLetterboxVendor = false,
            autoLetterboxBank = false,
            autoLetterboxCrafting = false,
        },

        subtitles = {
            isHidden = false,
            useChunkedDialogue = false
        },

    },
    interface = {
        UiElementsVisible = true,
        hideDialoguePanels = false,
        selectedFont = "ESO_Standard",
        customFontSize = 36,
        fontScale = 1.0,
        dialogueHorizontalOffset = 0.34,

    },
    hideUiElements = {},


    chunkedDialog = {
        chunkDisplayInterval = 3.0,
        chunkDelimiters = { ".", "!", "?" },
        chunkMinLength = 10,
        chunkMaxLength = 200,
        baseDisplayTime = 1.0,
        timePerCharacter = 0.03,
        minDisplayTime = 1.5,
        maxDisplayTime = 8.0,
        timingMode = "dynamic",
        usePunctuationTiming = true,
        hyphenPauseTime = 0.3,
        commaPauseTime = 0.2,
        semicolonPauseTime = 0.25,
        colonPauseTime = 0.3,
        dashPauseTime = 0.4,
        ellipsisPauseTime = 0.5,
    },
    -- Global control settings
    usePerInteractionSettings = false,


}

local chunkedDialogueData = {
    originalText = "",
    chunks = {},
    currentChunkIndex = 0,
    isActive = false,
    customControl = nil,
    displayTimer = nil
}

-- UI elements to hide
local uiElements = {
    "ZO_CompassFrame",
    "ZO_CompassFrameCenter",
    "ZO_CompassFrameLeft",
    "ZO_CompassFrameRight",
    "ZO_CompassContainer",
    "ZO_PlayerAttributeHealth",
    "ZO_PlayerAttributeMagicka",
    "ZO_PlayerAttributeStamina",
    "ZO_ActionBar1",
    "ZO_ActionBar2",
    "ZO_TargetUnitFrame",
    "ZO_UnitFrames",
    "ZO_ChatWindowTemplate1",
    "ZO_MinimapContainer",
    "ZO_PowerBlock",
    "ZO_BuffTracker",
    "ZO_ReticleContainerReticle",
    "ZO_ReticleContainer",
    "ZO_ReticleContainerStealthIcon",
    "ZO_ReticleContainerNoneInteract",

    -- Quest-related UI
    "ZO_QuestJournal",
    "ZO_QuestJournalKeyboard",
    "ZO_QuestTimerFrame",
    "ZO_FocusedQuestTrackerPanel",
    "ZO_QuestTrackerPanelContainer",
    "ZO_QuestLog",

    -- General Interaction UI (but NOT specific dialogue elements)
    "ZO_ConversationWindow",

    -- Inventory & Menus
    "ZO_PlayerInventory",
    "ZO_GameMenu_InGame",
    "ZO_MainMenuCategoryBarContainer",

    -- Social UI
    "ZO_KeyboardGuildWindow",
    "ZO_FriendsListKeyboard",
    "ZO_IgnoreListKeyboard",
    "ZO_GroupWindow",
    "ZO_ChatMenu_Gamepad_TopLevel",
    "ZO_GamepadTextChat",
    "ZO_GamepadTextChatBg",
    "ZO_GamepadTextChatScrollBar",
    "ZO_GamepadTextChatWindowContainer",
    "ZO_ChatWindowTab_Gamepad1",
    "ZO_ChatMenu_Gamepad_TopLevelMask",

    -- Crafting UI
    "ZO_CraftingTopLevel",
    "ZO_SmithingTopLevel",
    "ZO_EnchantingTopLevel",
    "ZO_AlchemyTopLevel",
    "ZO_ProvisionerTopLevel",


    -- Other UI
    "ZO_NotificationContainer",
    "ZO_TutorialOverlay",
    "ZO_DeathRecapWindow",

    -- Gamepad elements
    "ZO_GamepadChatSystem",
}

local fontBook = {
    ["ESO_Standard"] = {
        name = "ESO Standard",
        path = nil,
        description = "Default ESO font"
    },
    ["ESO_Bold"] = {
        name = "ESO Bold",
        path = "EsoUI/Common/Fonts/FTN57.slug|30|thick-outline",
        description = "Bold ESO font"
    },
    ["Handwritten"] = {
        name = "Handwritten",
        path = "EsoUI/Common/Fonts/ProseAntiquePSMT.slug|30|soft-shadow-thick",
        description = "Handwritten-style font"
    },
}

function CinematicCam:RegisterSceneCallbacks()
    local scenesToWatch = {
        "gameMenuInGame",       -- keyboard main menu
        "gamepadOptionsRoot",   -- gamepad options root
        "gamepadOptionsPanel",  -- gamepad options panel
        "gamepadInventoryRoot", -- gamepad inventory
        "gamepadDialog",        -- gamepad dialogs
        "gamepadCrownStore",    -- gamepad crown store
    }

    for _, sceneName in ipairs(scenesToWatch) do
        local scene = SCENE_MANAGER:GetScene(sceneName)
        if scene then
            scene:RegisterCallback("StateChange", function(_, newState)
                if newState == SCENE_HIDING then
                    -- Reapply UI state after menu closes
                    zo_callLater(function()
                        self:ReapplyUIState()
                    end)
                end
            end)
        end
    end
end

function CinematicCam:ReapplyUIState()
    -- Reapply UI visibility based on saved setting
    if not self.savedVars.uiVisible then
        self:HideUI()
    end

    -- Reapply letterbox if it should be visible
    if self.savedVars.letterboxVisible then
        -- Don't animate, just show immediately
        CinematicCam_Container:SetHidden(false)
        CinematicCam_LetterboxTop:SetHidden(false)
        CinematicCam_LetterboxBottom:SetHidden(false)
    end
end

function CinematicCam:HideNPCText()
    if ZO_InteractWindowTargetAreaBodyText then
        ZO_InteractWindowTargetAreaBodyText:SetHidden(true)
    end
end

-- Show regular npc text using eso's ui and not usingthe cinematic mode
function CinematicCam:ShowNPCText()
    if ZO_InteractWindowTargetAreaBodyText and self.savedVars.interaction.layoutPreset ~= "cinematic" then
        ZO_InteractWindowTargetAreaBodyText:SetHidden(false)
    end
end

---=============================================================================
-- Manage Letterbox Bars
--=============================================================================


function CinematicCam:AutoShowLetterbox(interactionType)
    local interactionTypeMap = (
        interactionType == INTERACTION_CONVERSATION or
        interactionType == INTERACTION_QUEST
    )
    return interactionTypeMap and self.savedVars.autoLetterboxDialogue
end

function CinematicCam:ShowLetterbox()
    if self.savedVars.letterboxVisible then
        return
    end
    self.savedVars.letterboxVisible = true

    -- Show XML Container
    CinematicCam_Container:SetHidden(false)

    -- Set initial positions (bars start off-screen)
    local barHeight = self.savedVars.letterboxSize

    CinematicCam_LetterboxTop:ClearAnchors()
    CinematicCam_LetterboxTop:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 0, -barHeight)
    CinematicCam_LetterboxTop:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, 0, -barHeight)
    CinematicCam_LetterboxTop:SetHeight(barHeight)

    CinematicCam_LetterboxBottom:ClearAnchors()
    CinematicCam_LetterboxBottom:SetAnchor(BOTTOMLEFT, GuiRoot, BOTTOMLEFT, 0, barHeight)
    CinematicCam_LetterboxBottom:SetAnchor(BOTTOMRIGHT, GuiRoot, BOTTOMRIGHT, 0, barHeight)
    CinematicCam_LetterboxBottom:SetHeight(barHeight)

    -- Set color and draw properties
    CinematicCam_LetterboxTop:SetColor(0, 0, 0, self.savedVars.letterboxOpacity)
    CinematicCam_LetterboxBottom:SetColor(0, 0, 0, self.savedVars.letterboxOpacity)
    CinematicCam_LetterboxTop:SetDrawLayer(DL_OVERLAY)
    CinematicCam_LetterboxBottom:SetDrawLayer(DL_OVERLAY)
    CinematicCam_LetterboxTop:SetDrawLevel(5)
    CinematicCam_LetterboxBottom:SetDrawLevel(5)

    -- Show bars
    CinematicCam_LetterboxTop:SetHidden(false)
    CinematicCam_LetterboxBottom:SetHidden(false)

    -- Create timeline for animation
    local timeline = ANIMATION_MANAGER:CreateTimeline()

    -- Animate top bar sliding down
    local topAnimation = timeline:InsertAnimation(ANIMATION_TRANSLATE, CinematicCam_LetterboxTop)
    topAnimation:SetTranslateOffsets(0, -barHeight, 0, 0)
    topAnimation:SetDuration(2600)

    -- Animate bottom bar sliding up
    local bottomAnimation = timeline:InsertAnimation(ANIMATION_TRANSLATE, CinematicCam_LetterboxBottom)
    bottomAnimation:SetTranslateOffsets(0, barHeight, 0, 0)
    bottomAnimation:SetDuration(2600)

    -- Start the animation
    timeline:PlayFromStart()
end

-- Hide letterbox bars
function CinematicCam:HideLetterbox()
    if not self.savedVars.letterboxVisible then
        return
    end
    if CinematicCam_LetterboxTop:IsHidden() then
        return
    end

    local barHeight = self.savedVars.letterboxSize

    -- Create timeline for hide animation
    local timeline = ANIMATION_MANAGER:CreateTimeline()

    -- Animate top bar sliding up (off-screen)
    local topAnimation = timeline:InsertAnimation(ANIMATION_TRANSLATE, CinematicCam_LetterboxTop)
    topAnimation:SetTranslateOffsets(0, 0, 0, -barHeight) -- Move from current position to off-screen
    topAnimation:SetDuration(3300)                        -- Slightly faster exit
    topAnimation:SetEasingFunction(ZO_EaseOutCubic)
    -- Animate bottom bar sliding down (off-screen)
    local bottomAnimation = timeline:InsertAnimation(ANIMATION_TRANSLATE, CinematicCam_LetterboxBottom)
    bottomAnimation:SetTranslateOffsets(0, 0, 0, barHeight) -- Move from current position to off-screen
    bottomAnimation:SetDuration(3300)                       -- Slightly faster exit
    bottomAnimation:SetEasingFunction(ZO_EaseOutCubic)

    -- Hide bars after animation completes
    timeline:SetHandler('OnStop', function()
        CinematicCam_LetterboxTop:SetHidden(true)
        CinematicCam_LetterboxBottom:SetHidden(true)
        -- Reset positions for next time
        CinematicCam_LetterboxTop:ClearAnchors()
        CinematicCam_LetterboxTop:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT)
        CinematicCam_LetterboxTop:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT)
        CinematicCam_LetterboxBottom:ClearAnchors()
        CinematicCam_LetterboxBottom:SetAnchor(BOTTOMLEFT, GuiRoot, BOTTOMLEFT)
        CinematicCam_LetterboxBottom:SetAnchor(BOTTOMRIGHT, GuiRoot, BOTTOMRIGHT)
        self.savedVars.letterboxVisible = false
    end)

    -- Start the animation
    timeline:PlayFromStart()
end

-- Toggle letterbox visibility
function CinematicCam:ToggleLetterbox()
    if self.savedVars.letterboxVisible then
        self:HideLetterbox()
    else
        self:ShowLetterbox()
    end
end

-- Calculate letterbox size for screen
function CinematicCam:CalculateLetterboxSize()
    -- Only auto-calculate if enabled in settings
    if not self.savedVars.autoSizeLetterbox then
        return
    end

    -- Get screen dimensions
    local screenWidth = GuiRoot:GetWidth()
    local screenHeight = GuiRoot:GetHeight()

    -- Calculate letterbox size for a 2.35:1 aspect ratio
    local targetAspectRatio = 2.35
    local currentAspectRatio = screenWidth / screenHeight

    if currentAspectRatio < targetAspectRatio then
        -- Screen is too tall, calculate letterbox size
        local idealHeight = screenWidth / targetAspectRatio
        local letterboxSize = math.floor((screenHeight - idealHeight) / 2)

        -- Update size
        self.savedVars.letterboxSize = letterboxSize
    else
        -- Screen is already wider than cinematic ratio, use minimal letterbox
        self.savedVars.letterboxSize = math.floor(screenHeight * 0.1) -- 10% of screen height
    end

    -- Apply the new size if letterbox is visible
    if not CinematicCam_LetterboxTop:IsHidden() then
        CinematicCam_LetterboxTop:SetHeight(self.savedVars.letterboxSize)
        CinematicCam_LetterboxBottom:SetHeight(self.savedVars.letterboxSize)
    end
end

---=============================================================================
-- Cinematic Mounting
--=============================================================================
function CinematicCam:OnMountUp()
    if self.savedVars.autoLetterboxMount then
        if not self.savedVars.letterboxVisible then
            mountLetterbox = true


            -- Apply delay
            local delayMs = self.savedVars.mountLetterboxDelay * 1000 -- Convert to milliseconds

            if delayMs > 0 then
                mountLetterboxTimer = zo_callLater(function()
                    -- Check if still mounted before showing
                    if IsMounted() and mountLetterbox then
                        self:ShowLetterbox()
                    else
                        mountLetterbox = false
                    end
                    mountLetterboxTimer = nil
                end, delayMs)
            else
                -- Instant (no delay)
                self:ShowLetterbox()
            end
        else
            mountLetterbox = false
        end
    end
end

function CinematicCam:OnMountDown()
    if self.savedVars.autoLetterboxMount then
        -- Cancel any pending timer

        -- Only hide letterbox if we auto-showed it
        if mountLetterbox and self.savedVars.letterboxVisible then
            self:HideLetterbox()
        end

        -- Reset tracking flag
        mountLetterbox = false
    end
end

---=============================================================================
-- Manage ESO UI Elements
--=============================================================================
function CinematicCam:HideUI()
    if not self.savedVars.uiVisible then
        return
    end
    ZO_ReticleContainerReticle:SetHidden(true)
    ZO_ReticleContainerReticle.SetHidden = function() end
    for _, elementName in ipairs(uiElements) do
        local element = _G[elementName]
        if element and not element:IsHidden() then
            uiElementsMap[elementName] = true
            element:SetHidden(true)
        end
    end

    for elementName, shouldHide in pairs(self.savedVars.hideUiElements) do
        if shouldHide then
            local element = _G[elementName]
            if element and not element:IsHidden() then
                uiElementsMap[elementName] = true
                element:SetHidden(true)
            end
        end
    end
    self.savedVars.uiVisible = false
end

-- Show UI elements
function CinematicCam:ShowUI()
    if self.savedVars.uiVisible then
        return
    end
    ZO_ReticleContainerReticle:SetHidden(false)
    ZO_ReticleContainerReticle.SetHidden = function() end
    for elementName, _ in pairs(uiElementsMap) do
        local element = _G[elementName]
        if element then
            element:SetHidden(false)
        end
    end
    uiElementsMap = {}
    self.savedVars.uiVisible = true
end

-- Toggle UI
function CinematicCam:ToggleUI()
    if self.savedVars.uiVisible then
        self:HideUI()
    else
        self:ShowUI()
    end
end

-- THE INTERACT LIST CONTAINER FOR GAMEPAD IS
-- ZO_InteractWindow_GamepadContainerInteract(List)
-- ZO_InteractWindow_Gamepad

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

function CinematicCam:StartDialogueChangeMonitoring()
    -- Cancel any existing monitoring
    if dialogueChangeCheckTimer then
        zo_removeCallLater(dialogueChangeCheckTimer)
        dialogueChangeCheckTimer = nil
    end

    -- Start periodic checking for dialogue changes
    local function checkForDialogueChange()
        if not chunkedDialogueData.isActive then
            -- Stop monitoring if chunked dialogue is not active
            dialogueChangeCheckTimer = nil
            return
        end

        local currentText, _ = self:GetDialogueText()

        -- Check if dialogue text has changed
        if currentText and currentText ~= lastDialogueText then
            -- Cleanup current chunked dialogue
            self:CleanupChunkedDialogue()

            -- Try to start new chunked dialogue for the new text
            if self.savedVars.interaction.layoutPreset == "cinematic" then
                self:InterceptDialogueForChunking()
            end
            return
        end

        -- Check if interaction has ended
        local interactionType = GetInteractionType()
        if interactionType == INTERACTION_NONE then
            self:CleanupChunkedDialogue()
            return
        end
    end

    -- Start the monitoring
    dialogueChangeCheckTimer = zo_callLater(checkForDialogueChange, 20)
end

function CinematicCam:InitializeCompleteTextDisplay()
    if #chunkedDialogueData.chunks == 0 then
        return false
    end

    -- Ensure control is ready
    if not chunkedDialogueData.customControl then
        self:InitializeChunkedTextControl()
    end

    local control = chunkedDialogueData.customControl
    if not control then
        return false
    end

    -- Apply positioning based on current preset (same as ESO positioning)
    self:ApplyChunkedTextPositioning()

    -- Initialize display state
    chunkedDialogueData.currentChunkIndex = 1
    chunkedDialogueData.isActive = true

    -- Show the complete text immediately (no chunking animation)
    local completeText = chunkedDialogueData.chunks[1]

    -- Restore abbreviation periods
    completeText = string.gsub(completeText, "§ABBREV§", ".")

    -- Apply font
    local fontString = self:BuildUserFontString()
    control:SetFont(fontString)

    -- Set text and show
    control:SetText(completeText)
    control:SetHidden(false)

    return true
end

function CinematicCam:InterceptDialogueForChunking()
    local originalText, sourceElement = self:GetDialogueText()

    if not originalText or string.len(originalText) == 0 then
        return false
    end

    if sourceElement and self.savedVars.interaction.layoutPreset then
        sourceElement:SetHidden(false)
    end

    -- CLEANUP ANY EXISTING DISPLAY
    if chunkedDialogueData.isActive then
        self:CleanupChunkedDialogue()
    end

    -- Store the new dialogue text
    lastDialogueText = originalText

    -- Store original data
    chunkedDialogueData.originalText = originalText
    chunkedDialogueData.sourceElement = sourceElement


    if self.savedVars.interaction.subtitles.useChunkedDialogue then
        -- Process into chunks
        chunkedDialogueData.chunks = self:ProcessTextIntoChunks(originalText)
        if #chunkedDialogueData.chunks >= 1 then
            self:StartDialogueChangeMonitoring()
            return self:InitializeChunkedDisplay()
        else
            chunkedDialogueData.chunks = { originalText }
            self:StartDialogueChangeMonitoring()
            return self:InitializeCompleteTextDisplay()
        end
    end
    -- TODO: handle when use chunking is disabled
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

function CinematicCam:UpdateChunkedTextVisibility()
    local control = chunkedDialogueData.customControl
    if control then
        if self.savedVars.interaction.subtitles.isHidden then
            control:SetAlpha(0)
        else
            control:SetAlpha(1.0)
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

function CinematicCam:CreateChunkedTextControl()
    if chunkedDialogueData.customControl then
        return chunkedDialogueData.customControl
    end

    -- Create custom label control
    local control = CreateControl("CinematicCam_ChunkedDialogue", GuiRoot, CT_LABEL)

    -- Apply your existing font system
    self:ApplyFontToElement(control, self.savedVars.customFontSize)

    -- Set text properties
    control:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    control:SetVerticalAlignment(TEXT_ALIGN_TOP)
    control:SetHorizontalAlignment(TEXT_ALIGN_LEFT)

    -- Color customization (addressing your earlier note)
    control:SetColor(0.9, 0.9, 0.8, 1.0) -- Slightly warmer than ESO default

    -- Position according to current layout preset
    self:PositionChunkedTextControl(control)

    control:SetHidden(true)

    chunkedDialogueData.customControl = control
    return control
end

function CinematicCam:PositionChunkedTextControl(control)
    local preset = currentRepositionPreset or "default"

    if preset == "default" then
        if chunkedDialogueData.sourceElement then
            control:ClearAnchors()
            control:SetAnchor(CENTER, chunkedDialogueData.sourceElement, CENTER, 0, -100)
            control:SetDimensions(chunkedDialogueData.sourceElement:GetDimensions())
        end
    elseif preset == "cinematic" then
        -- Subtle center positioning
        control:ClearAnchors()
        control:SetAnchor(CENTER, GuiRoot, CENTER, 0, 100)
        control:SetDimensions(700, 250)
    end
end

function CinematicCam:InitializeChunkedDisplay()
    if #chunkedDialogueData.chunks == 0 then
        return false
    end

    -- Hide original text element
    if chunkedDialogueData.sourceElement then
        chunkedDialogueData.sourceElement:SetHidden(true)
    end

    -- Ensure control is ready
    if not chunkedDialogueData.customControl then
        self:InitializeChunkedTextControl()
    end

    local control = chunkedDialogueData.customControl
    if not control then
        return false
    end

    self:ApplyChunkedTextPositioning()

    -- Initialize display state
    chunkedDialogueData.currentChunkIndex = 1
    chunkedDialogueData.isActive = true



    -- Show first chunk immediately
    self:DisplayCurrentChunk()

    -- Schedule next chunk if there are more
    if #chunkedDialogueData.chunks >= 1 then
        self:ScheduleNextChunk()
    end

    return true
end

function CinematicCam:UpdateChunkedTextFont()
    local control = chunkedDialogueData.customControl
    if control then
        self:ApplyFontToElement(control, self.savedVars.customFontSize)
    end
end

function CinematicCam:DisplayCurrentChunk()
    local control = chunkedDialogueData.customControl
    local chunkIndex = chunkedDialogueData.currentChunkIndex

    if not control then
        return
    end

    if chunkIndex > #chunkedDialogueData.chunks then
        return
    end

    local chunkText = chunkedDialogueData.chunks[chunkIndex]

    -- Restore abbreviation periods
    chunkText = string.gsub(chunkText, "§ABBREV§", ".")

    -- REAPPLY FONT DIRECTLY
    local fontString = self:BuildUserFontString()
    control:SetFont(fontString)

    -- NEW: Update visibility based on current setting
    self:UpdateChunkedTextVisibility()

    -- Set text and show
    control:SetText(chunkText)
    control:SetHidden(false)
end

function CinematicCam:CountWords(text)
    if not text or text == "" then return 0 end

    local wordCount = 0
    for word in string.gmatch(text, "%S+") do
        wordCount = wordCount + 1
    end

    return math.max(1, wordCount) -- At least 1 word to avoid division by zero
end

function CinematicCam:CalculateChunkDisplayTime(chunkText)
    if not chunkText or chunkText == "" then
        return self.savedVars.baseDisplayTime or 1.0
    end

    -- Remove markup and clean the text for accurate length calculation
    local cleanText = self:CleanTextForTiming(chunkText)
    local textLength = string.len(cleanText)

    local displayTime

    -- Check timing mode
    if self.savedVars.timingMode == "fixed" then
        -- Use the original fixed interval
        displayTime = self.savedVars.chunkDisplayInterval or 3.0
    elseif self.savedVars.useWordBasedTiming then
        -- Calculate based on reading speed (words per minute)
        local wordCount = self:CountWords(cleanText)
        local wordsPerSecond = (self.savedVars.wordsPerMinute or 150) / 60
        displayTime = wordCount / wordsPerSecond
    else
        -- Character-based dynamic timing (default)
        local baseTime = 0.4
        local timePerChar = 0.06
        displayTime = baseTime + (textLength * timePerChar)
    end

    -- ADD PUNCTUATION TIMING (only for dynamic modes)
    if self.savedVars.timingMode ~= "fixed" and self.savedVars.usePunctuationTiming then
        local punctuationTime = self:CalculatePunctuationTime(cleanText)
        displayTime = displayTime + punctuationTime
    end

    -- Apply min/max bounds (only for dynamic modes)
    if self.savedVars.timingMode ~= "fixed" then
        local minTime = self.savedVars.minDisplayTime or 1.5
        local maxTime = self.savedVars.maxDisplayTime or 8.0
        displayTime = math.max(minTime, displayTime)
        displayTime = math.min(maxTime, displayTime)
    end
    return displayTime
end

function CinematicCam:CalculatePunctuationTime(text)
    if not text or not self.savedVars.usePunctuationTiming then
        return 0
    end

    local totalPunctuationTime = 0

    -- Count different punctuation marks and add time for each
    local punctuationCounts = {
        ["-"] = 0, -- Hyphens
        ["—"] = 0, -- Em-dashes
        ["–"] = 0, -- En-dashes
        [","] = 0, -- Commas
        [";"] = 0, -- Semicolons
        [":"] = 0, -- Colons
        ["."] = 0
    }

    -- Count ellipsis separately (3 dots together)
    local ellipsisCount = 0

    -- Count each character
    for i = 1, #text do
        local char = text:sub(i, i)
        if punctuationCounts[char] ~= nil then
            punctuationCounts[char] = punctuationCounts[char] + 1
        end
    end

    -- Count ellipsis (handle both ... and …)
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
    totalPunctuationTime = totalPunctuationTime + (ellipsisCount * (self.savedVars.ellipsisPauseTime or 0.5))

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

    -- Remove common markup if present
    cleaned = string.gsub(cleaned, "|[cC]%x%x%x%x%x%x", "") -- Color codes
    cleaned = string.gsub(cleaned, "|[rR]", "")             -- Reset codes

    return cleaned
end

function CinematicCam:ScheduleNextChunk()
    if chunkedDialogueData.displayTimer then
        zo_removeCallLater(chunkedDialogueData.displayTimer)
    end

    -- Calculate timing for the CURRENT chunk (the one being displayed)
    local currentChunkIndex = chunkedDialogueData.currentChunkIndex
    local currentChunk = chunkedDialogueData.chunks[currentChunkIndex]
    local displayTime = self:CalculateChunkDisplayTime(currentChunk)

    -- Convert to milliseconds for zo_callLater
    local displayTimeMs = displayTime * 1000

    chunkedDialogueData.displayTimer = zo_callLater(function()
        self:AdvanceToNextChunk()
    end, displayTimeMs)

    CinematicCam:DebugPrint("Scheduled next chunk in " .. string.format("%.1f", displayTime) .. " seconds")
end

function CinematicCam:AdvanceToNextChunk()
    chunkedDialogueData.currentChunkIndex = chunkedDialogueData.currentChunkIndex + 1

    if chunkedDialogueData.currentChunkIndex <= #chunkedDialogueData.chunks then
        self:DisplayCurrentChunk()

        -- Only schedule next chunk if chunking is enabled and there are multiple chunks
        if self.savedVars.interaction.subtitles.useChunkedDialogue and #chunkedDialogueData.chunks > 1 then
            self:ScheduleNextChunk()
        end
    end
end

function CinematicCam:OnChunkedDialogueComplete()
    -- Keep the last chunk visible for a short time, then hide
    zo_callLater(function()
        if chunkedDialogueData.customControl then
            chunkedDialogueData.customControl:SetHidden(true)
            chunkedDialogueData.customControl:SetText("")
        end

        -- Optionally restore original text
        if chunkedDialogueData.sourceElement then
            chunkedDialogueData.sourceElement:SetHidden(self.savedVars.interaction.subtitles.isHidden)
        end
    end, 2000) -- Hide after 2 seconds
end

function CinematicCam:CleanupChunkedDialogue()
    -- Stop any active timers
    if chunkedDialogueData.displayTimer then
        zo_removeCallLater(chunkedDialogueData.displayTimer)
        chunkedDialogueData.displayTimer = nil
    end

    -- Stop dialogue change monitoring
    if dialogueChangeCheckTimer then
        zo_removeCallLater(dialogueChangeCheckTimer)
        dialogueChangeCheckTimer = nil
    end

    -- Hide custom control
    if chunkedDialogueData.customControl then
        chunkedDialogueData.customControl:SetHidden(true)
        chunkedDialogueData.customControl:SetText("")
    end

    -- Restore original element
    if chunkedDialogueData.sourceElement then
        chunkedDialogueData.sourceElement:SetHidden(self.savedVars.interaction.subtitles.isHidden)
    end

    -- Reset state
    chunkedDialogueData = {
        originalText = "",
        chunks = {},
        currentChunkIndex = 0,
        isActive = false,
        customControl = chunkedDialogueData.customControl, -- Preserve control
        displayTimer = nil,
        sourceElement = nil
    }
    lastDialogueText = ""
end

function CinematicCam:InitializeChunkedDialogueSystem()
    -- Hook into your existing dialogue detection
    local originalOnGameCameraDeactivated = self.OnGameCameraDeactivated
    self.OnGameCameraDeactivated = function(self)
        originalOnGameCameraDeactivated(self)

        if self.savedVars.interaction.layoutPreset == "cinematic" then
            -- Add chunked dialogue initialization
            zo_callLater(function()
                self:InterceptDialogueForChunking()
            end, 200)
        end
    end
end

---=============================================================================
-- 3rd Person Questing
--=============================================================================
-- User preference settings
function CinematicCam:InitializeInteractionSettings()
    interactionTypeMap = {
        [INTERACTION_CONVERSATION] = self.savedVars.interaction.forceThirdPersonDialogue,
        [INTERACTION_QUEST] = self.savedVars.interaction.forceThirdPersonQuest,
        [INTERACTION_VENDOR] = self.savedVars.interaction.forceThirdPersonVendor,
        [INTERACTION_STORE] = self.savedVars.interaction.forceThirdPersonVendor,
        [INTERACTION_BANK] = self.savedVars.interaction.forceThirdPersonBank,
        [INTERACTION_GUILDBANK] = self.savedVars.interaction.forceThirdPersonBank,
        [INTERACTION_TRADINGHOUSE] = self.savedVars.interaction.forceThirdPersonVendor,
        [INTERACTION_STABLE] = self.savedVars.interaction.forceThirdPersonVendor,
        [INTERACTION_CRAFT] = self.savedVars.interaction.forceThirdPersonCrafting,
        [INTERACTION_DYE_STATION] = self.savedVars.interaction.forceThirdPersonCrafting,

    }
end

function CinematicCam:CheckInteractionStatus()
    if isInteractionModified then
        local currentInteraction = GetInteractionType()
        if currentInteraction == INTERACTION_NONE then
            CinematicCam:OnInteractionEnd()
        elseif not interactionTypeMap[currentInteraction] then
            CinematicCam:OnInteractionEnd()
        end
        zo_callLater(function()
            CinematicCam:CheckInteractionStatus()
        end, 500)
    end
end

function GetCameraDistance()
    return tonumber(GetSetting(SETTING_TYPE_CAMERA, CAMERA_SETTING_DISTANCE))
end

function CinematicCam:ShouldBlockInteraction(interactionType)
    return interactionTypeMap[interactionType] == true
end

-- Save current camera state before interaction
function CinematicCam:SaveCameraState()
    savedCameraState = {
        distance = GetCameraDistance(),
    }
end

function CinematicCam:RestoreCameraState()
    savedCameraState = {}
end

function CinematicCam:OnGameCameraDeactivated()
    local interactionType = GetInteractionType()

    if not self.savedVars.usePerInteractionSettings and config then
        -- Use per-interaction settings
        if not config.enabled or not config.forceThirdPerson then
            return
        end

        SetInteractionUsingInteractCamera(false)
        isInteractionModified = true
        self:CaptureOriginalElementStates()

        -- Apply interaction-specific layout preset
        local oldPreset = currentRepositionPreset
        currentRepositionPreset = config.layoutPreset or "default"


        self:ApplyDialogueRepositioning()

        -- Save current state
        self:SaveCameraState()

        -- Handle dialogue panels, NPC text, etc.
        if config.hideDialoguePanels then
            self:HideDialoguePanels()
        end

        if self.savedVars.interaction.subtitles.isHidden then
            if ZO_InteractWindowTargetAreaBodyText then
                ZO_InteractWindowTargetAreaBodyText:SetHidden(true)
            end
            if ZO_InteractWindow_GamepadContainerText then
                ZO_InteractWindow_GamepadContainerText:SetHidden(true)
            end
        end

        -- ALWAYS intercept dialogue (for both chunked and non-chunked)
        if self.savedVars.interaction.layoutPreset == "cinematic" then
            self:InterceptDialogueForChunking()
        end
        -- Handle letterbox and UI
        if config.autoLetterbox then
            if not self.savedVars.letterboxVisible then
                dialogLetterbox = true
                self:ShowLetterbox()
            else
                dialogLetterbox = false
            end
        end

        if config.autoHideUI then
            if self.savedVars.uiVisible then
                wasUIAutoHidden = true
                self:HideUI()
            else
                wasUIAutoHidden = false
            end
        end

        zo_callLater(function()
            CinematicCam:CheckInteractionStatus()
        end, 1000)
    else
        -- Legacy behavior
        if self:ShouldBlockInteraction(interactionType) then
            SetInteractionUsingInteractCamera(false)
            isInteractionModified = true
            self:CaptureOriginalElementStates()

            self:ApplyDialogueRepositioning()
            self:SaveCameraState()

            if self.savedVars.hideDialoguePanels then
                self:HideDialoguePanels()
            end

            if ZO_InteractWindowTargetAreaBodyText then
                ZO_InteractWindowTargetAreaBodyText:SetHidden(self.savedVars.interaction.subtitles.isHidden)
            end
            if ZO_InteractWindow_GamepadContainerText then
                ZO_InteractWindow_GamepadContainerText:SetHidden(self.savedVars.interaction.subtitles.isHidden)
            end


            if self.savedVars.interaction.layoutPreset == "cinematic" then
                self:InterceptDialogueForChunking()
            end
            if self:AutoShowLetterbox(interactionType) then
                if not self.savedVars.letterboxVisible then
                    dialogLetterbox = true
                    self:ShowLetterbox()
                else
                    dialogLetterbox = false
                end
            end

            if self.savedVars.autoHideUIDialogue then
                if self.savedVars.uiVisible then
                    wasUIAutoHidden = true
                    self:HideUI()
                else
                    wasUIAutoHidden = false
                end
            end

            zo_callLater(function()
                CinematicCam:CheckInteractionStatus()
            end, 1000)
        end
    end
end

function CinematicCam:EnableAllInteractions(enable)
    for interactionName, settings in pairs(self.savedVars.interactions) do
        if type(settings) == "table" then
            settings.enabled = enable
        end
    end
    self:InitializeInteractionSettings()
end

function CinematicCam:SetAllThirdPersonMode(enable)
    for interactionName, settings in pairs(self.savedVars.interactions) do
        if type(settings) == "table" then
            settings.forceThirdPerson = enable
        end
    end
    self:InitializeInteractionSettings()
end

function CinematicCam:SetAllLetterboxMode(enable)
    for interactionName, settings in pairs(self.savedVars.interactions) do
        if type(settings) == "table" then
            settings.autoLetterbox = enable
        end
    end
end

function CinematicCam:OnGameCameraActivated()
    if isInteractionModified then
        -- Check if we're actually out of interaction
        local currentInteraction = GetInteractionType()
        if currentInteraction == INTERACTION_NONE then
            CinematicCam:OnInteractionEnd()
        end
    end
end

function CinematicCam:OnInteractionEnd()
    if isInteractionModified then
        isInteractionModified = false

        -- Always cleanup chunked dialogue when interaction ends
        if self.savedVars.interaction.subtitles.useChunkedDialogue then
            self:CleanupChunkedDialogue()
        end

        if self.savedVars.hideDialoguePanels then
            self:ShowDialoguePanels()
        end

        -- Restore camera state
        self:RestoreCameraState()

        -- Only hide letterbox if we auto-showed it
        if dialogLetterbox and self.savedVars.letterboxVisible then
            self:HideLetterbox()
        end

        -- Only show UI if we auto-hid it
        if wasUIAutoHidden and not self.savedVars.uiVisible then
            self:ShowUI()
        end

        -- Reset tracking flags
        dialogLetterbox = false
        wasUIAutoHidden = false

        -- Clear dialogue tracking
        lastDialogueText = ""
    end
end

---=============================================================================
-- Hide Questing Dialoge Panels
--=============================================================================
-- Need to hide this: "ZO_KeybindStripButtonTemplate2"
function CinematicCam:HideDialoguePanels()
    -- Main dialogue window elements
    if ZO_InteractWindow_GamepadContainerDivider then ZO_InteractWindow_GamepadContainerDivider:SetHidden(true) end

    if ZO_InteractWindowVerticalSeparator then ZO_InteractWindowVerticalSeparator:SetHidden(true) end
    if ZO_InteractWindowTopBG then ZO_InteractWindowTopBG:SetHidden(true) end
    if ZO_InteractWindowBottomBG then ZO_InteractWindowBottomBG:SetHidden(true) end

    -- Text elements - handle title and body text separately
    if ZO_InteractWindowTargetAreaTitle then ZO_InteractWindowTargetAreaTitle:SetHidden(true) end


    -- Options and highlights
    if ZO_InteractWindowPlayerAreaOptions then ZO_InteractWindowPlayerAreaOptions:SetHidden(true) end
    if ZO_InteractWindowPlayerAreaHighlight then ZO_InteractWindowPlayerAreaHighlight:SetHidden(true) end
    if ZO_InteractWindowCollapseContainerRewardArea then ZO_InteractWindowCollapseContainerRewardArea:SetHidden(true) end

    -- Gamepad elements
    if ZO_InteractWindow_GamepadBG then ZO_InteractWindow_GamepadBG:SetHidden(true) end
    if ZO_InteractWindow_GamepadContainerText and self.savedVars.interaction.layoutPreset ~= "cinematic" then
        ZO_InteractWindow_GamepadContainerText:SetHidden(self.savedVars.interaction.subtitles.isHidden)
    end
end

function CinematicCam:ShowDialoguePanels()
    -- Main dialogue window elements
    if ZO_InteractWindow_GamepadContainerDivider then ZO_InteractWindow_GamepadContainerDivider:SetHidden(false) end

    if ZO_InteractWindowDivider then ZO_InteractWindowDivider:SetHidden(false) end
    if ZO_InteractWindowVerticalSeparator then ZO_InteractWindowVerticalSeparator:SetHidden(false) end
    if ZO_InteractWindowTopBG then ZO_InteractWindowTopBG:SetHidden(false) end
    if ZO_InteractWindowBottomBG then ZO_InteractWindowBottomBG:SetHidden(false) end

    -- Text elements
    if ZO_InteractWindowTargetAreaTitle then ZO_InteractWindowTargetAreaTitle:SetHidden(false) end

    -- Only show NPC text if the hideNPCText setting is enabled
    if ZO_InteractWindowTargetAreaBodyText then ZO_InteractWindowTargetAreaBodyText:SetHidden(true) end

    -- Options and highlights
    if ZO_InteractWindowPlayerAreaOptions then ZO_InteractWindowPlayerAreaOptions:SetHidden(false) end
    if ZO_InteractWindowPlayerAreaHighlight then ZO_InteractWindowPlayerAreaHighlight:SetHidden(false) end
    if ZO_InteractWindowCollapseContainerRewardArea then ZO_InteractWindowCollapseContainerRewardArea:SetHidden(false) end

    -- Gamepad elements
    if ZO_InteractWindow_GamepadBG then ZO_InteractWindow_GamepadBG:SetHidden(false) end
    if ZO_InteractWindow_GamepadContainerText and self.savedVars.interaction.layoutPreset ~= "cinematic" then
        ZO_InteractWindow_GamepadContainerText:SetHidden(self.savedVars.interaction.subtitles.isHidden)
    end
end

---=============================================================================
-- Font Book
--=============================================================================
function CinematicCam:GetFontChoices()
    local choices = {}
    local choicesValues = {}

    for fontId, fontData in pairs(fontBook) do
        table.insert(choices, fontData.name)
        table.insert(choicesValues, fontId)
    end

    return choices, choicesValues
end

function CinematicCam:GetCurrentFont()
    local fontData = fontBook[self.savedVars.selectedFont]
    if fontData then
        return fontData.path
    end
    return fontBook["ESO_Standard"].path -- fallback
end

function CinematicCam:ApplyFontToElement(element, fontSize)
    if not element then
        return
    end

    local fontPath = self:GetCurrentFont()
    local actualSize = fontSize or self.savedVars.interface.customFontSize
    actualSize = math.floor(actualSize * self.savedVars.interface.fontScale)

    if not fontPath then
        local defaultFontString = "EsoUI/Common/Fonts/FTN57.slug|" .. actualSize .. "|soft-shadow-thick"
        element:SetFont(defaultFontString)
        return
    end

    -- Parse the font path and replace size for custom fonts
    local finalFontString = self:ParseFontPath(fontPath, actualSize)

    if finalFontString then
        element:SetFont(finalFontString)
    end
end

function CinematicCam:ApplyFontsToUI()
    -- Use the same size for all dialogue elements
    local fontSize = self.savedVars.customFontSize

    if ZO_InteractWindowTargetAreaTitle then
        self:ApplyFontToElement(ZO_InteractWindowTargetAreaTitle, fontSize)
    end
    if ZO_InteractWindow_GamepadTitle then
        self:ApplyFontToElement(ZO_InteractWindow_GamepadTitle, fontSize)
    end
    if ZO_InteractWindowTargetAreaBodyText then
        self:ApplyFontToElement(ZO_InteractWindowTargetAreaBodyText, fontSize)
    end

    if ZO_InteractWindow_GamepadContainerText then
        self:ApplyFontToElement(ZO_InteractWindow_GamepadContainerText, fontSize)
    end
    if ZO_InteractWindowPlayerAreaOptions then
        self:ApplyFontToElement(ZO_InteractWindowPlayerAreaOptions, fontSize)
    end
    if ZO_InteractWindowPlayerAreaHighlight then
        self:ApplyFontToElement(ZO_InteractWindowPlayerAreaHighlight, fontSize)
    end
    for i = 1, 10 do
        local longOptionName = "ZO_InteractWindow_GamepadContainerInteractListScrollZO_ChatterOption_Gamepad" ..
            i .. "Text"
        local option = _G[longOptionName]
        if option then
            self:ApplyFontToElement(option, fontSize)
        end
    end
end

function CinematicCam:ParseFontPath(fontPath, newSize)
    -- Safety check for nil fontPath
    if not fontPath or fontPath == "" then
        return nil
    end

    -- Check if the path contains a size (pattern: |number|)
    local hasSize = string.find(fontPath, "|%d+|")

    if hasSize then
        -- Replace existing size with new size
        local newPath = string.gsub(fontPath, "|%d+|", "|" .. newSize .. "|")
        return newPath
    else
        -- No size found, check if it has effects after the font file
        local hasEffects = string.find(fontPath, "|")

        if hasEffects then
            -- Has effects but no size, insert size before effects
            local newPath = string.gsub(fontPath, "|", "|" .. newSize .. "|", 1)
            return newPath
        else
            -- No size, no effects, just add size
            return fontPath .. "|" .. newSize
        end
    end
end

function CinematicCam:BuildUserFontString()
    local selectedFont = self.savedVars.interface.selectedFont
    local fontSize = self.savedVars.interface.customFontSize
    local fontScale = self.savedVars.interface.fontScale

    -- Calculate final size
    local finalSize = math.floor(fontSize * fontScale)

    -- Handle each font type directly
    if selectedFont == "ESO_Standard" then
        -- ESO Standard uses the default font with size
        return "EsoUI/Common/Fonts/FTN57.slug|" .. finalSize .. "|soft-shadow-thick"
    elseif selectedFont == "ESO_Bold" then
        -- ESO Bold with the path from your fontBook
        return "EsoUI/Common/Fonts/FTN57.slug|" .. finalSize .. "|thick-outline"
    elseif selectedFont == "Handwritten" then
        -- Handwritten with the path from your fontBook
        return "EsoUI/Common/Fonts/ProseAntiquePSMT.slug|" .. finalSize .. "|soft-shadow-thick"
    end
end

function CinematicCam:OnFontChanged()
    -- Apply fonts immediately if dialogue is currently open
    local interactionType = GetInteractionType()
    if interactionType ~= INTERACTION_NONE then
        self:ApplyFontsToUI()
    end
    self:UpdateChunkedTextFont()
    -- Also apply to any existing dialogue elements
    self:ApplyFontsToUI()
end

-- Repositioning preset system
local repositionPresets = {
    ["default"] = {
        name = "Default ESO Layout",
        applyFunction = function(self)
            self:RestoreDefaultPositions()
        end
    },
    ["cinematic"] = {
        name = "Subtle Center",
        applyFunction = function(self)
            self:ApplySubtleCenterRepositioning()
        end
    },
    ["default"] = {
        name = "Full Center Screen",
        applyFunction = function(self)
            self:ApplyFullCenterRepositioning()
        end
    }
}
local npcTextContainer = ZO_InteractWindow_GamepadContainerText
if npcTextContainer then
    local originalWidth, originalHeight = npcTextContainer:GetDimensions()
    local addedWidth = originalWidth + 10
    local addedHeight = originalHeight + 100
end

---=============================================================================
-- Reposition UI
--=============================================================================
function CinematicCam:ApplySubtleCenterRepositioning()
    ZO_InteractWindow_GamepadContainerText:SetHidden(true)
    local screenWidth, screenHeight = GuiRoot:GetDimensions()
    local effectiveWidth = screenWidth
    if self.savedVars.letterboxVisible and self.savedVars.coordinateWithLetterbox then
        -- Account for letterbox visual boundaries
        effectiveWidth = screenWidth * 0.95 -- Leave small margins
    end

    -- NPC text positioning (accounting for bottom alignment)

    if npcTextContainer then
        local originalWidth, originalHeight = npcTextContainer:GetDimensions()

        -- Calculate offset accounting for bottom-aligned text
        local npcYOffset = screenHeight * 0.20 + (originalHeight * 0.5) -- Adjust for bottom alignment

        npcTextContainer:ClearAnchors()
        npcTextContainer:SetAnchor(CENTER, GuiRoot, CENTER, 0, 1000)
        npcTextContainer:SetWidth(originalWidth)
        npcTextContainer:SetHeight(addedHeight)
    end

    -- Dialogue options positioning with alignment consideration
    local optionsXOffset = screenWidth * 0.15
    local optionsYStart = screenHeight * 0.4
    local optionSpacing = 60
    local repositionedCount = 0
    --[[
    local playerInteractContainer = _G["ZO_InteractWindow_Gamepad"] -- Verify exact name
    if playerInteractContainer then
        local originalWidth, originalHeight = playerInteractContainer:GetDimensions()

        -- Calculate subtle center positioning for player interactions
        local interactXOffset = screenWidth * -0.14 -- Slight movement toward center
        local interactYOffset = screenHeight * .09  -- Vertical positioning adjustment

        playerInteractContainer:ClearAnchors()
        playerInteractContainer:SetAnchor(CENTER, GuiRoot, CENTER, -interactXOffset, interactYOffset)

        -- Preserve or adjust dimensions as needed
        playerInteractContainer:SetWidth(originalWidth)
        playerInteractContainer:SetHeight(originalHeight)

        d("Repositioned player interact container independently")
    else
        d("ERROR: Player interact container not found")
    end
    local playerInteractContainer = _G["ZO_InteractWindow_GamepadContainerInteractList"]
    if playerInteractContainer then
        local originalWidth, originalHeight = playerInteractContainer:GetDimensions()

        -- Calculate subtle center positioning for player interactions
        local interactXOffset = screenWidth * -0.28 -- Slight movement toward center
        local interactYOffset = screenHeight * .03  -- Vertical positioning adjustment

        playerInteractContainer:ClearAnchors()
        playerInteractContainer:SetAnchor(CENTER, GuiRoot, CENTER, -interactXOffset, interactYOffset)

        -- Preserve or adjust dimensions as needed
        playerInteractContainer:SetWidth(originalWidth)
        playerInteractContainer:SetHeight(originalHeight)

        d("Repositioned player interact container independently")
    else
        d("ERROR: Player interact container not found")
    end
    --]]
end

-- Element state management
local originalElementStates = {}


function CinematicCam:CaptureOriginalElementStates()
    local elementsToCapture = {
        "ZO_InteractWindowDivider",
        "ZO_InteractWindow_GamepadContainer",
        "ZO_InteractWindow_GamepadContainerText",
        "ZO_InteractWindowPlayerAreaOptions",
        "ZO_InteractWindowPlayerAreaHighlight"
    }

    for _, elementName in ipairs(elementsToCapture) do
        local element = _G[elementName]
        if element then
            originalElementStates[elementName] = {
                isHidden = element:IsHidden(),
                alpha = element:GetAlpha(),

                captured = true
            }
        end
    end
end

function CinematicCam:GetStableDimensions(elementName, maxAttempts)
    local element = _G[elementName]
    if not element then return nil, nil end

    maxAttempts = maxAttempts or 10
    local attempts = 0
    local lastWidth, lastHeight = 0, 0
    local stableCount = 0

    local function checkDimensions()
        attempts = attempts + 1
        local width, height = element:GetDimensions()

        -- Check if dimensions are stable
        if width == lastWidth and height == lastHeight and width > 0 and height > 0 then
            stableCount = stableCount + 1
            if stableCount >= 3 then -- 3 consecutive stable measurements
                return width, height
            end
        else
            stableCount = 0
        end

        lastWidth, lastHeight = width, height

        -- Continue checking if not stable and under max attempts
        if attempts < maxAttempts then
            zo_callLater(checkDimensions, 50)
        else
            -- Return last known dimensions even if not perfectly stable
            return width, height
        end
    end

    return checkDimensions()
end

function CinematicCam:ApplyFullCenterRepositioning()
    ZO_InteractWindow_GamepadContainerText:SetHidden(false)
    zo_callLater(function()
        local rootWindow = _G["ZO_InteractWindow_Gamepad"]
        if rootWindow then
            local screenWidth, screenHeight = GuiRoot:GetDimensions()
            local originalWidth, originalHeight = rootWindow:GetDimensions()

            -- Use the slider value for horizontal positioning
            local centerX = screenWidth * self.savedVars.interface.dialogueHorizontalOffset
            local centerY = 0

            -- Coordinate with letterbox if active
            if self.savedVars.letterboxVisible then
                centerY = self.savedVars.letterboxSize * 0.3
            end

            -- Apply positioning
            rootWindow:ClearAnchors()
            rootWindow:SetAnchor(CENTER, GuiRoot, CENTER, centerX, centerY)

            -- Set dimensions
            rootWindow:SetWidth(683)
            rootWindow:SetHeight(2000)
        end
    end)
end

function CinematicCam:RestoreDefaultPositions()
    ZO_InteractWindow_GamepadContainerText:SetHidden(false)
    zo_callLater(function()
        local rootWindow = _G["ZO_InteractWindow_Gamepad"]
        if rootWindow then
            local screenWidth, screenHeight = GuiRoot:GetDimensions()
            local originalWidth, originalHeight = rootWindow:GetDimensions()

            -- Use the slider value for horizontal positioning (same as full center now)
            local centerX = screenWidth * self.savedVars.interface.dialogueHorizontalOffset
            local centerY = 0

            -- Coordinate with letterbox if active
            if self.savedVars.letterboxVisible then
                centerY = self.savedVars.letterboxSize * 0.3
            end

            -- Apply positioning
            rootWindow:ClearAnchors()
            rootWindow:SetAnchor(CENTER, GuiRoot, CENTER, centerX, centerY)

            -- Set dimensions
            rootWindow:SetWidth(683)
            rootWindow:SetHeight(2000)
        end
    end)
end

function CinematicCam:ApplyDialogueRepositioning()
    local preset = repositionPresets[currentRepositionPreset]
    if preset and preset.applyFunction then
        preset.applyFunction(self)
    end
end

function CinematicCam:InitializeChunkedTextControl()
    -- Try to get the XML-defined control first
    local control = _G["CinematicCam_ChunkedText"]

    if not control then
        -- Create control programmatically as fallback
        control = CreateControl("CinematicCam_ChunkedDialogue", GuiRoot, CT_LABEL)

        if not control then
            return nil
        end
    end
    -- Basic visibility settings
    control:SetColor(1, 1, 1, 1) -- White text
    if self.savedVars.interaction.subtitles.isHidden == true then
        control:SetAlpha(0)
    elseif self.savedVars.interaction.subtitles.isHidden == false then
        control:SetAlpha(1.0)
    end
    control:SetDrawLayer(DL_TEXT)
    control:SetDrawLevel(2)

    -- Text properties
    control:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    control:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    control:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    -- DIRECT FONT SETTING
    local fontString = self:BuildUserFontString()
    control:SetFont(fontString)

    -- Start hidden
    control:SetHidden(true)
    control:SetText("")

    -- Store reference
    chunkedDialogueData.customControl = control

    return control
end

function CinematicCam:OnDialoguelayoutPresetChanged(newPreset)
    -- Update the current preset
    currentRepositionPreset = newPreset

    -- If chunked dialogue is active, reapply positioning
    if chunkedDialogueData.isActive and chunkedDialogueData.customControl then
        self:ApplyChunkedTextPositioning()
    end
end

function CinematicCam:ApplyChunkedTextPositioning()
    local control = chunkedDialogueData.customControl
    if not control then return end

    local preset = currentRepositionPreset or "default"


    if preset == "cinematic" then
        control:ClearAnchors()
    end


    if preset == "default" then
        local screenWidth, screenHeight = GuiRoot:GetDimensions()
        local centerX = screenWidth * 0.27
        local centerY = 10

        if self.savedVars.letterboxVisible then
            centerY = self.savedVars.letterboxSize * 0.3
        end

        control:SetAnchor(CENTER, GuiRoot, CENTER, centerX, centerY)
        control:SetDimensions(683, 250) -- Appropriate for text
    elseif preset == "cinematic" then
        -- From ApplySubtleCenterRepositioning
        local screenWidth, screenHeight = GuiRoot:GetDimensions()
        local npcYOffset = screenHeight * 0.20 + (100 * 0.5)

        control:SetAnchor(CENTER, GuiRoot, CENTER, 0, npcYOffset)
        control:SetDimensions(700, 200)
    else -- default
        -- From RestoreDefaultPositions
        control:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, -50, 7000)
        control:SetDimensions(683, 550)
    end
end

---=============================================================================
-- Initialize
--=============================================================================
local function Initialize()
    -- Load saved variables
    CinematicCam.savedVars = ZO_SavedVars:NewAccountWide("CinematicCam2SavedVars", 2, nil, defaults)

    -- Apply fonts after UI elements are loaded
    CinematicCam:ApplyFontsToUI()
    CinematicCam:InitializeChunkedDialogueSystem()
    CinematicCam:InitializeChunkedTextControl()

    --Letterbox
    if CinematicCam.savedVars.letterboxVisible then
        zo_callLater(function()
            CinematicCam_Container:SetHidden(false)
            CinematicCam_LetterboxTop:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT)
            CinematicCam_LetterboxTop:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT)
            CinematicCam_LetterboxTop:SetHeight(CinematicCam.savedVars.letterbox.size)
            CinematicCam_LetterboxTop:SetColor(0, 0, 0, CinematicCam.savedVars.letterboxOpacity)
            CinematicCam_LetterboxTop:SetDrawLayer(DL_OVERLAY)
            CinematicCam_LetterboxTop:SetDrawLevel(5)
            CinematicCam_LetterboxTop:SetHidden(false)

            CinematicCam_LetterboxBottom:SetAnchor(BOTTOMLEFT, GuiRoot, BOTTOMLEFT)
            CinematicCam_LetterboxBottom:SetAnchor(BOTTOMRIGHT, GuiRoot, BOTTOMRIGHT)
            CinematicCam_LetterboxBottom:SetHeight(CinematicCam.savedVars.letterbox.size)
            CinematicCam_LetterboxBottom:SetColor(0, 0, 0, CinematicCam.savedVars.letterboxOpacity)
            CinematicCam_LetterboxBottom:SetDrawLayer(DL_OVERLAY)
            CinematicCam_LetterboxBottom:SetDrawLevel(5)
            CinematicCam_LetterboxBottom:SetHidden(false)
        end, 1500) -- Wait for UI to be ready
    else
        zo_callLater(function()
            CinematicCam_Container:SetHidden(false)
            CinematicCam_LetterboxTop:SetHidden(true)
            CinematicCam_LetterboxBottom:SetHidden(true)
        end, 1500)
    end

    -- Init UI saved Vars
    if not CinematicCam.savedVars.uiVisible then
        zo_callLater(function()
            for _, elementName in ipairs(uiElements) do
                local element = _G[elementName]
                if element and not element:IsHidden() then
                    uiElementsMap[elementName] = true
                    element:SetHidden(true)
                end
            end
            for elementName, shouldHide in pairs(CinematicCam.savedVars.hideUiElements) do
                if shouldHide then
                    local element = _G[elementName]
                    if element and not element:IsHidden() then
                        uiElementsMap[elementName] = true
                        element:SetHidden(true)
                    end
                end
            end
        end, 1600)
    end

    -- Register slash commands
    SLASH_COMMANDS["/ccui"] = function()
        CinematicCam:ToggleUI()
    end

    SLASH_COMMANDS["/ccbars"] = function()
        CinematicCam:ToggleLetterbox()
    end
    currentRepositionPreset = CinematicCam.savedVars.interaction.layoutPreset or "default"

    -- Initialize 3rd person dialogue settings
    CinematicCam:InitializeInteractionSettings()

    -- Calculate letterbox size
    CinematicCam:CalculateLetterboxSize()
    zo_callLater(function()
        CinematicCam:CreateSettingsMenu()
        CinematicCam:RegisterSceneCallbacks()
    end, 100)
end

local function OnPlayerActivated(eventCode)
    if not CinematicCam.hasPlayedIntro then
        CinematicCam.hasPlayedIntro = true
        CinematicCam.savedVars.camEnabled = true

        zo_callLater(function()
            CinematicCam.savedVars.camEnabled = false
            CinematicCam:ShowUI()
        end, 100)
    end
end

local function OnAddOnLoaded(event, addonName)
    if addonName == ADDON_NAME then
        EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
        Initialize()
    end
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)


---=============================================================================
-- Events
--=============================================================================
EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_GAME_CAMERA_DEACTIVATED, function()
    CinematicCam:OnGameCameraDeactivated()
end)

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_GAME_CAMERA_ACTIVATED, function()
    CinematicCam:OnGameCameraActivated()
end)
EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_CHATTER_END, function()
    CinematicCam:OnInteractionEnd()
end)

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_QUEST_COMPLETE_DIALOG_END, function()
    CinematicCam:OnInteractionEnd()
end)

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_CLOSE_STORE, function()
    CinematicCam:OnInteractionEnd()
end)

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_CLOSE_BANK, function()
    CinematicCam:OnInteractionEnd()
end)
-- Register for screen resize
EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_SCREEN_RESIZED, function()
    zo_callLater(function()
        CinematicCam:CalculateLetterboxSize()
    end, 500)
end)
EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_MOUNTED_STATE_CHANGED, function(eventCode, mounted)
    if mounted then
        CinematicCam:OnMountUp()
    else
        CinematicCam:OnMountDown()
    end
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_Font", EVENT_CHATTER_BEGIN, function()
        zo_callLater(function()
            CinematicCam:ApplyFontsToUI()
        end)
    end)


    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_Font", EVENT_CONVERSATION_UPDATED, function()
        zo_callLater(function()
            CinematicCam:ApplyFontsToUI()
        end)
    end)


    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_Font", EVENT_QUEST_COMPLETE_DIALOG, function()
        zo_callLater(function()
            CinematicCam:ApplyFontsToUI()
        end)
    end)


    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_Font", EVENT_INTERACTION_UPDATED, function()
        zo_callLater(function()
            CinematicCam:ApplyFontsToUI()
        end)
    end)
end)
---=============================================================================
-- Debug
--=============================================================================
function CinematicCam:DebugPrint()
    if self.savedVars and self.savedVars.showNotifications then
        d(message)
    end
end
