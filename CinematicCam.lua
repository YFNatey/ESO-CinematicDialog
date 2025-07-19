-- Cinematic Camera with UI Hiding and Letterbox
local ADDON_NAME = "CinematicCam"
CinematicCam = {}
CinematicCam.savedVars = nil

local hiddenElements = {}
local interactionSettings = {}
local savedCameraState = {}
local isInBlockedInteraction = false
local wasMountLetterboxAutoShown = false
local wasLetterboxAutoShown = false
local wasUIAutoHidden = false
local currentRepositionPreset = "full_center"
local lastDialogueText = ""
local dialogueChangeCheckTimer = nil

-- Default settings
local defaults = {
    camEnabled = false,
    letterboxSize = 100,
    letterboxOpacity = 1.0,
    autoSizeLetterbox = true,
    customUiElements = {},
    hideUiElements = {},
    letterboxVisible = false,
    uiVisible = true,
    autoLetterboxMount = false,
    dialogueLayoutPreset = "full_center",
    coordinateWithLetterbox = true,

    -- 3rd Person Dialogue Settings
    forceThirdPersonDialogue = true,
    forceThirdPersonVendor = false,
    forceThirdPersonBank = false,
    forceThirdPersonQuest = true,
    forceThirdPersonCrafting = false,
    autoLetterboxDialogue = false,
    autoHideUIDialogue = false,
    hideDialoguePanels = false,
    hideNPCText = false,
    autoLetterboxConversation = true, -- Enable for regular dialogue
    autoLetterboxQuest = true,        -- Enable for quest interactions
    autoLetterboxVendor = false,      -- Disable for vendors
    autoLetterboxBank = false,        -- Disable for banks
    autoLetterboxCrafting = false,    -- Disable for crafting stations

    selectedFont = "ESO_Standard",
    customFontSize = 36,
    fontScale = 1.0,


    useChunkedDialogue = false,
    chunkDisplayInterval = 3.0,
    chunkDelimiters = { ".", "!", "?" },
    chunkMinLength = 10,         -- Prevent very short chunk
    chunkMaxLength = 200,        -- Prevent very long chunks
    baseDisplayTime = 1.0,       -- Base time in seconds for any chunk
    timePerCharacter = 0.03,     -- Additional time per character (50ms per char)
    minDisplayTime = 1.5,        -- Minimum display time in seconds
    maxDisplayTime = 8.0,        -- Maximum display time in seconds
    timingMode = "dynamic",      -- "fixed" or "dynamic"
    usePunctuationTiming = true, -- Enable special punctuation timing
    hyphenPauseTime = 0.3,       -- Extra time for hyphens (300ms)
    commaPauseTime = 0.2,        -- Extra time for commas (200ms)
    semicolonPauseTime = 0.25,   -- Extra time for semicolons (250ms)
    colonPauseTime = 0.3,        -- Extra time for colons (300ms)
    dashPauseTime = 0.4,         -- Extra time for em-dashes (400ms)
    ellipsisPauseTime = 0.5,
    -- Alternative timing modes
    wordsPerMinute = 150, -- Reading speed for word-based timing
    useWordBasedTiming = false,


    mountLetterboxDelay = 0,

    interactions = {
        conversation = {
            enabled = true,
            forceThirdPerson = true,
            autoLetterbox = false,
            autoHideUI = false,
            hideDialoguePanels = false,
            hideNPCText = false,
            layoutPreset = "full_center"
        },
        quest = {
            enabled = true,
            forceThirdPerson = true,
            autoLetterbox = true,
            autoHideUI = false,
            hideDialoguePanels = false,
            hideNPCText = false,
            layoutPreset = "full_center"
        },
        vendor = {
            enabled = false,
            forceThirdPerson = false,
            autoLetterbox = false,
            autoHideUI = false,
            hideDialoguePanels = false,
            hideNPCText = false,
            layoutPreset = "default"
        },
        store = {
            enabled = false,
            forceThirdPerson = false,
            autoLetterbox = false,
            autoHideUI = false,
            hideDialoguePanels = false,
            hideNPCText = false,
            layoutPreset = "default"
        },
        bank = {
            enabled = false,
            forceThirdPerson = false,
            autoLetterbox = false,
            autoHideUI = false,
            hideDialoguePanels = false,
            hideNPCText = false,
            layoutPreset = "default"
        },
        guildbank = {
            enabled = false,
            forceThirdPerson = false,
            autoLetterbox = false,
            autoHideUI = false,
            hideDialoguePanels = false,
            hideNPCText = false,
            layoutPreset = "default"
        },
        tradinghouse = {
            enabled = false,
            forceThirdPerson = false,
            autoLetterbox = false,
            autoHideUI = false,
            hideDialoguePanels = false,
            hideNPCText = false,
            layoutPreset = "default"
        },
        stable = {
            enabled = false,
            forceThirdPerson = false,
            autoLetterbox = false,
            autoHideUI = false,
            hideDialoguePanels = false,
            hideNPCText = false,
            layoutPreset = "default"
        },
        craft = {
            enabled = false,
            forceThirdPerson = false,
            autoLetterbox = false,
            autoHideUI = false,
            hideDialoguePanels = false,
            hideNPCText = false,
            layoutPreset = "default"
        },
        dyestation = {
            enabled = false,
            forceThirdPerson = false,
            autoLetterbox = false,
            autoHideUI = false,
            hideDialoguePanels = false,
            hideNPCText = false,
            layoutPreset = "default"
        }
    },

    -- Global control settings
    usePerInteractionSettings = false, -- Toggle between simple/advanced mode

}
local chunkedDialogueData = {
    originalText = "",
    chunks = {},
    currentChunkIndex = 0,
    isActive = false,
    customControl = nil,
    displayTimer = nil
}

local letterboxSettings = {}
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
    -- NEW: Per-interaction settings

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
                    end, 100)
                end
            end)
        end
    end
end

-- Add this new function to reapply your UI state:
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

function CinematicCam:ShowNPCText()
    if ZO_InteractWindowTargetAreaBodyText then
        ZO_InteractWindowTargetAreaBodyText:SetHidden(true)
    end
end

---=============================================================================
-- Manage Letterbox Bars
--=============================================================================
function CinematicCam:InitializeLetterboxSettings()
    letterboxSettings = {
        [INTERACTION_CONVERSATION] = self.savedVars.autoLetterboxConversation,
        [INTERACTION_QUEST] = self.savedVars.autoLetterboxQuest,
        [INTERACTION_VENDOR] = self.savedVars.autoLetterboxVendor,
        [INTERACTION_STORE] = self.savedVars.autoLetterboxVendor,
        [INTERACTION_BANK] = self.savedVars.autoLetterboxBank,
        [INTERACTION_GUILDBANK] = self.savedVars.autoLetterboxBank,
        [INTERACTION_TRADINGHOUSE] = self.savedVars.autoLetterboxVendor,
        [INTERACTION_STABLE] = self.savedVars.autoLetterboxVendor,
        [INTERACTION_CRAFT] = self.savedVars.autoLetterboxCrafting,
        [INTERACTION_DYE_STATION] = self.savedVars.autoLetterboxCrafting,
    }
end

function CinematicCam:ShouldApplyLetterbox(interactionType)
    -- Simple master toggle for all dialogue types
    local isDialogueInteraction = (
        interactionType == INTERACTION_CONVERSATION or
        interactionType == INTERACTION_QUEST
    )

    return isDialogueInteraction and self.savedVars.autoLetterboxDialogue
end

function CinematicCam.ToggleLetterboxOnly()
    CinematicCam:ToggleLetterbox()
end

function CinematicCam:ShowLetterbox()
    if self.savedVars.letterboxVisible then
        return
    end

    -- SET THE FLAG IMMEDIATELY, before animation starts
    self.savedVars.letterboxVisible = true

    -- Make sure our container is visible
    CinematicCam_Container:SetHidden(false)

    -- Set initial positions (bars start off-screen)
    local screenHeight = GuiRoot:GetHeight()
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

    -- Remove the timeline handler since flag is already set
    -- timeline:SetHandler('OnStop', function()
    --     self.savedVars.letterboxVisible = true
    -- end)

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
            wasMountLetterboxAutoShown = true


            -- Apply delay
            local delayMs = self.savedVars.mountLetterboxDelay * 1000 -- Convert to milliseconds

            if delayMs > 0 then
                mountLetterboxTimer = zo_callLater(function()
                    -- Check if still mounted before showing
                    if IsMounted() and wasMountLetterboxAutoShown then
                        self:ShowLetterbox()
                    else
                        wasMountLetterboxAutoShown = false
                    end
                    mountLetterboxTimer = nil
                end, delayMs)
            else
                -- Instant (no delay)
                self:ShowLetterbox()
            end
        else
            wasMountLetterboxAutoShown = false
        end
    end
end

function CinematicCam:OnMountDown()
    if self.savedVars.autoLetterboxMount then
        -- Cancel any pending timer

        -- Only hide letterbox if we auto-showed it
        if wasMountLetterboxAutoShown and self.savedVars.letterboxVisible then
            self:HideLetterbox()
        end

        -- Reset tracking flag
        wasMountLetterboxAutoShown = false
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
            hiddenElements[elementName] = true
            element:SetHidden(true)
        end
    end

    for elementName, shouldHide in pairs(self.savedVars.hideUiElements) do
        if shouldHide then
            local element = _G[elementName]
            if element and not element:IsHidden() then
                hiddenElements[elementName] = true
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
    for elementName, _ in pairs(hiddenElements) do
        local element = _G[elementName]
        if element then
            element:SetHidden(false)
        end
    end
    hiddenElements = {}
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
            d("Dialogue change detected during chunking!")
            d("Old: " .. (lastDialogueText or "nil"):sub(1, 50))
            d("New: " .. currentText:sub(1, 50))

            -- Cleanup current chunked dialogue
            self:CleanupChunkedDialogue()

            -- Try to start new chunked dialogue for the new text

            self:InterceptDialogueForChunking()


            return -- Stop this monitoring cycle
        end

        -- Check if interaction has ended
        local interactionType = GetInteractionType()
        if interactionType == INTERACTION_NONE then
            d("Interaction ended, stopping dialogue monitoring")
            self:CleanupChunkedDialogue()
            return
        end

        -- Schedule next check
        dialogueChangeCheckTimer = zo_callLater(checkForDialogueChange, 200) -- Check every 200ms
    end

    -- Start the monitoring
    dialogueChangeCheckTimer = zo_callLater(checkForDialogueChange, 200)
    d("Started dialogue change monitoring")
end

-- SOLUTION: Modify InterceptDialogueForChunking to ALWAYS use XML control



-- NEW: Function to display complete text in XML control (no chunking)
function CinematicCam:InitializeCompleteTextDisplay()
    d("Initializing complete text display in XML control")

    if #chunkedDialogueData.chunks == 0 then
        d("No text to display")
        return false
    end

    -- Ensure control is ready
    if not chunkedDialogueData.customControl then
        self:InitializeChunkedTextControl()
    end

    local control = chunkedDialogueData.customControl
    if not control then
        d("ERROR: Failed to get XML text control")
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

    d("Displaying complete text in XML control (no chunking)")

    return true
end

function CinematicCam:InterceptDialogueForChunking()
    d("InterceptDialogueForChunking called")

    -- CHANGE: Remove the early return when chunked dialogue is disabled
    -- We still want to use XML control for font stability

    local originalText, sourceElement = self:GetDialogueText()
    d("Found original text: " .. tostring(originalText ~= nil))
    d("Found source element: " .. tostring(sourceElement ~= nil))

    if not originalText or string.len(originalText) == 0 then
        d("No text found for chunking")
        return false
    end

    -- CHECK IF THIS IS A NEW DIALOGUE TEXT
    if originalText == lastDialogueText then
        d("Same dialogue text detected, skipping")
        return false
    end

    -- ALWAYS hide ESO dialogue to use XML control instead
    if sourceElement then
        sourceElement:SetHidden(true)
        d("Hidden ESO dialogue element")
    end

    -- CLEANUP ANY EXISTING DISPLAY
    if chunkedDialogueData.isActive then
        d("New dialogue detected, cleaning up previous display")
        self:CleanupChunkedDialogue()
    end

    -- Store the new dialogue text
    lastDialogueText = originalText

    d("Original text length: " .. string.len(originalText))
    d("First 100 chars: " .. originalText:sub(1, 100))

    -- Store original data
    chunkedDialogueData.originalText = originalText
    chunkedDialogueData.sourceElement = sourceElement

    -- Check if chunking is enabled
    if self.savedVars.useChunkedDialogue then
        d("Chunked dialogue ENABLED - processing into chunks")

        -- Process into chunks
        chunkedDialogueData.chunks = self:ProcessTextIntoChunks(originalText)
        d("Created " .. #chunkedDialogueData.chunks .. " chunks")

        if #chunkedDialogueData.chunks > 1 then
            d("Multiple chunks - using chunking animation")
            self:StartDialogueChangeMonitoring()
            return self:InitializeChunkedDisplay()
        else
            d("Single chunk - showing complete text")
            chunkedDialogueData.chunks = { originalText } -- Use full text as single chunk
            self:StartDialogueChangeMonitoring()
            return self:InitializeCompleteTextDisplay()
        end
    else
        d("Chunked dialogue DISABLED - showing complete text in XML control")

        -- Don't chunk, just show complete text in XML control
        chunkedDialogueData.chunks = { originalText }
        self:StartDialogueChangeMonitoring()
        return self:InitializeCompleteTextDisplay()
    end
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
    local delimiters = self.savedVars.chunkDelimiters
    local minLength = self.savedVars.chunkMinLength
    local maxLength = self.savedVars.chunkMaxLength

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
        d("=== CHUNK TIMING PREVIEW ===")
        local totalTime = 0
        for i, chunk in ipairs(chunks) do
            local chunkTime = self:CalculateChunkDisplayTime(chunk)
            totalTime = totalTime + chunkTime
            d("Chunk " .. i .. " (" .. string.len(chunk) .. " chars): " .. string.format("%.1f", chunkTime) .. "s")
        end
        d("Total dialogue time: " .. string.format("%.1f", totalTime) .. " seconds")
    end

    return chunks
end

function CinematicCam:InitializeChunkedTextControl()
    -- Try to get the XML-defined control first
    local control = _G["CinematicCam_ChunkedText"]

    if not control then
        -- Create control programmatically as fallback
        control = CreateControl("CinematicCam_ChunkedDialogue", GuiRoot, CT_LABEL)

        if not control then
            d("ERROR: Failed to create chunked text control")
            return nil
        end
    end

    -- FORCE SIMPLE CENTER POSITIONING
    control:ClearAnchors()
    control:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    control:SetDimensions(800, 200)

    -- Basic visibility settings
    control:SetColor(1, 1, 1, 1) -- White text
    control:SetAlpha(1.0)
    control:SetDrawLayer(DL_TEXT)
    control:SetDrawLevel(2)

    -- Text properties
    control:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    control:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    control:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    -- APPLY USER'S SELECTED FONT
    self:ApplyFontToElement(control, self.savedVars.customFontSize)



    -- Start hidden
    control:SetHidden(true)
    control:SetText("")

    -- Store reference
    chunkedDialogueData.customControl = control

    d("Chunked text control initialized with font: " .. tostring(control:GetFont()))

    return control
end

function CinematicCam:ApplyChunkedTextPositioning()
    local control = chunkedDialogueData.customControl
    if not control then return end

    local preset = currentRepositionPreset or "default"
    d("Applying chunked text positioning with preset: " .. preset)

    control:ClearAnchors()

    local screenWidth, screenHeight = GuiRoot:GetDimensions()

    if preset == "full_center" then
        -- True center screen
        control:SetAnchor(CENTER, GuiRoot, CENTER, 0, -100) -- Changed: center X, higher up
        control:SetDimensions(800, 300)
    elseif preset == "subtle_center" then
        -- Lower center area
        control:SetAnchor(CENTER, GuiRoot, CENTER, 0, 150)       -- Changed: much lower
        control:SetDimensions(700, 250)
    else                                                         -- default
        -- Right side (mimicking original ESO position)
        control:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, -80, 300) -- Changed: much lower Y
        control:SetDimensions(650, 200)
    end

    d("XML control positioned with preset: " .. preset)
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

    if preset == "full_center" then
        -- Center screen positioning
        control:ClearAnchors()
        control:SetAnchor(CENTER, GuiRoot, CENTER, 0, -100)
        control:SetDimensions(800, 300)
    elseif preset == "subtle_center" then
        -- Subtle center positioning
        control:ClearAnchors()
        control:SetAnchor(CENTER, GuiRoot, CENTER, 0, 100)
        control:SetDimensions(700, 250)
    else
        -- Default: mimic original element position
        if chunkedDialogueData.sourceElement then
            control:ClearAnchors()
            control:SetAnchor(CENTER, chunkedDialogueData.sourceElement, CENTER, 0, -100)
            control:SetDimensions(chunkedDialogueData.sourceElement:GetDimensions())
        end
    end
end

function CinematicCam:InitializeChunkedDisplay()
    d("Starting InitializeChunkedDisplay")

    if #chunkedDialogueData.chunks == 0 then
        d("No chunks to display")
        return false
    end

    -- Hide original text element
    if chunkedDialogueData.sourceElement then
        chunkedDialogueData.sourceElement:SetHidden(true)
        d("Hidden source element: " .. chunkedDialogueData.sourceElement:GetName())
    end

    -- Ensure control is ready
    if not chunkedDialogueData.customControl then
        self:InitializeChunkedTextControl()
    end

    local control = chunkedDialogueData.customControl
    if not control then
        d("ERROR: Failed to get chunked text control")
        return false
    end

    self:ApplyChunkedTextPositioning()

    -- Initialize display state
    chunkedDialogueData.currentChunkIndex = 1
    chunkedDialogueData.isActive = true

    d("About to display first chunk")

    -- Show first chunk immediately
    self:DisplayCurrentChunk()

    -- Schedule next chunk if there are more
    if #chunkedDialogueData.chunks > 1 then
        self:ScheduleNextChunk()
    end

    return true
end

function CinematicCam:UpdateChunkedTextFont()
    local control = chunkedDialogueData.customControl
    if control then
        self:ApplyFontToElement(control, self.savedVars.customFontSize)
        d("Updated chunked text font to: " .. tostring(control:GetFont()))
    end
end

function CinematicCam:DisplayCurrentChunk()
    local control = chunkedDialogueData.customControl
    local chunkIndex = chunkedDialogueData.currentChunkIndex

    if not control then
        d("ERROR: No control in DisplayCurrentChunk")
        return
    end

    if chunkIndex > #chunkedDialogueData.chunks then
        d("ERROR: Chunk index out of range")
        return
    end

    local chunkText = chunkedDialogueData.chunks[chunkIndex]

    -- Restore abbreviation periods
    chunkText = string.gsub(chunkText, "§ABBREV§", ".")



    -- REAPPLY FONT DIRECTLY
    local fontString = self:BuildUserFontString()
    control:SetFont(fontString)
    d("Applied font: " .. fontString)

    -- Set text and show
    control:SetText(chunkText)
    control:SetHidden(false)

    d("Displaying chunk " .. chunkIndex)
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
        d("Using FIXED timing: " .. displayTime .. "s")
    elseif self.savedVars.useWordBasedTiming then
        -- Calculate based on reading speed (words per minute)
        local wordCount = self:CountWords(cleanText)
        local wordsPerSecond = (self.savedVars.wordsPerMinute or 150) / 60
        displayTime = wordCount / wordsPerSecond
        d("Using WORD-BASED timing: " .. wordCount .. " words")
    else
        -- Character-based dynamic timing (default)
        local baseTime = 0.4
        local timePerChar = 0.06
        displayTime = baseTime + (textLength * timePerChar)
        d("Using CHARACTER-BASED timing: " .. baseTime .. "s + (" .. textLength .. " × " .. timePerChar .. "s)")
    end

    -- ADD PUNCTUATION TIMING (only for dynamic modes)
    if self.savedVars.timingMode ~= "fixed" and self.savedVars.usePunctuationTiming then
        local punctuationTime = self:CalculatePunctuationTime(cleanText)
        displayTime = displayTime + punctuationTime

        if punctuationTime > 0 then
            d("Added punctuation time: +" .. string.format("%.1f", punctuationTime) .. "s")
        end
    end

    -- Apply min/max bounds (only for dynamic modes)
    if self.savedVars.timingMode ~= "fixed" then
        local minTime = self.savedVars.minDisplayTime or 1.5
        local maxTime = self.savedVars.maxDisplayTime or 8.0
        displayTime = math.max(minTime, displayTime)
        displayTime = math.min(maxTime, displayTime)
    end

    d("Final timing for '" ..
        cleanText:sub(1, 30) .. "...' (" .. textLength .. " chars) = " .. string.format("%.1f", displayTime) .. "s")

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
    totalPunctuationTime = totalPunctuationTime + (punctuationCounts["-"] * (self.savedVars.hyphenPauseTime or 0.3))
    totalPunctuationTime = totalPunctuationTime + (punctuationCounts["—"] * (self.savedVars.dashPauseTime or 0.4))
    totalPunctuationTime = totalPunctuationTime + (punctuationCounts["–"] * (self.savedVars.dashPauseTime or 0.4))
    totalPunctuationTime = totalPunctuationTime + (punctuationCounts[","] * (self.savedVars.commaPauseTime or 0.2))
    totalPunctuationTime = totalPunctuationTime + (punctuationCounts[";"] * (self.savedVars.semicolonPauseTime or 0.25))
    totalPunctuationTime = totalPunctuationTime + (punctuationCounts[":"] * (self.savedVars.colonPauseTime or 0.3))
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

        d("Punctuation found: " .. table.concat(details, ", "))
    end

    return totalPunctuationTime
end

function CinematicCam:SetOptimalTimingDefaults()
    -- Force dynamic timing mode
    self.savedVars.timingMode = "dynamic"
    self.savedVars.useWordBasedTiming = false

    -- Set good dynamic timing defaults if they don't exist
    if self.savedVars.baseDisplayTime == nil then
        self.savedVars.baseDisplayTime = 1.0
    end
    if self.savedVars.timePerCharacter == nil then
        self.savedVars.timePerCharacter = 0.03
    end
    if self.savedVars.minDisplayTime == nil then
        self.savedVars.minDisplayTime = 1.5
    end
    if self.savedVars.maxDisplayTime == nil then
        self.savedVars.maxDisplayTime = 8.0
    end

    -- NEW: Set punctuation timing defaults
    if self.savedVars.usePunctuationTiming == nil then
        self.savedVars.usePunctuationTiming = true
    end
    if self.savedVars.hyphenPauseTime == nil then
        self.savedVars.hyphenPauseTime = 0.3
    end
    if self.savedVars.commaPauseTime == nil then
        self.savedVars.commaPauseTime = 0.2
    end
    if self.savedVars.semicolonPauseTime == nil then
        self.savedVars.semicolonPauseTime = 0.25
    end
    if self.savedVars.colonPauseTime == nil then
        self.savedVars.colonPauseTime = 0.3
    end
    if self.savedVars.dashPauseTime == nil then
        self.savedVars.dashPauseTime = 0.4
    end
    if self.savedVars.ellipsisPauseTime == nil then
        self.savedVars.ellipsisPauseTime = 0.5
    end

    d("=== TIMING SETTINGS CONFIGURED ===")
    d("Mode: " .. self.savedVars.timingMode)
    d("Base time: " .. self.savedVars.baseDisplayTime .. "s")
    d("Per character: " .. self.savedVars.timePerCharacter .. "s")
    d("Punctuation timing: " .. (self.savedVars.usePunctuationTiming and "ON" or "OFF"))
    d("Hyphen pause: " .. self.savedVars.hyphenPauseTime .. "s")
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

    d("Scheduled next chunk in " .. string.format("%.1f", displayTime) .. " seconds")
end

function CinematicCam:AdvanceToNextChunk()
    chunkedDialogueData.currentChunkIndex = chunkedDialogueData.currentChunkIndex + 1

    if chunkedDialogueData.currentChunkIndex <= #chunkedDialogueData.chunks then
        self:DisplayCurrentChunk()

        -- Only schedule next chunk if chunking is enabled and there are multiple chunks
        if self.savedVars.useChunkedDialogue and #chunkedDialogueData.chunks > 1 then
            self:ScheduleNextChunk()
        end
    else
        -- All chunks displayed (only relevant for chunked mode)
        self:OnChunkedDialogueComplete()
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
            chunkedDialogueData.sourceElement:SetHidden(self.savedVars.hideNPCText)
        end

        d("Chunked dialogue complete - text hidden after delay")
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
        d("Stopped dialogue change monitoring")
    end

    -- Hide custom control
    if chunkedDialogueData.customControl then
        chunkedDialogueData.customControl:SetHidden(true)
        chunkedDialogueData.customControl:SetText("")
    end

    -- Restore original element
    if chunkedDialogueData.sourceElement then
        chunkedDialogueData.sourceElement:SetHidden(self.savedVars.hideNPCText)
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

    -- Clear last dialogue text tracking
    lastDialogueText = ""

    d("Chunked dialogue cleaned up completely")
end

function CinematicCam:InitializeChunkedDialogueSystem()
    -- Hook into your existing dialogue detection
    local originalOnGameCameraDeactivated = self.OnGameCameraDeactivated
    self.OnGameCameraDeactivated = function(self)
        originalOnGameCameraDeactivated(self)

        -- Add chunked dialogue initialization
        zo_callLater(function()
            self:InterceptDialogueForChunking()
        end, 100)
    end
end

---=============================================================================
-- 3rd Person Questing
--=============================================================================
-- User preference settings
function CinematicCam:InitializeInteractionSettings()
    if self.savedVars.usePerInteractionSettings then
        -- Use new per-interaction settings
        interactionSettings = {
            [INTERACTION_CONVERSATION] = self.savedVars.interactions.conversation.enabled and
                self.savedVars.interactions.conversation.forceThirdPerson,
            [INTERACTION_QUEST] = self.savedVars.interactions.quest.enabled and
                self.savedVars.interactions.quest.forceThirdPerson,
            [INTERACTION_VENDOR] = self.savedVars.interactions.vendor.enabled and
                self.savedVars.interactions.vendor.forceThirdPerson,
            [INTERACTION_STORE] = self.savedVars.interactions.store.enabled and
                self.savedVars.interactions.store.forceThirdPerson,
            [INTERACTION_BANK] = self.savedVars.interactions.bank.enabled and
                self.savedVars.interactions.bank.forceThirdPerson,
            [INTERACTION_GUILDBANK] = self.savedVars.interactions.guildbank.enabled and
                self.savedVars.interactions.guildbank.forceThirdPerson,
            [INTERACTION_TRADINGHOUSE] = self.savedVars.interactions.tradinghouse.enabled and
                self.savedVars.interactions.tradinghouse.forceThirdPerson,
            [INTERACTION_STABLE] = self.savedVars.interactions.stable.enabled and
                self.savedVars.interactions.stable.forceThirdPerson,
            [INTERACTION_CRAFT] = self.savedVars.interactions.craft.enabled and
                self.savedVars.interactions.craft.forceThirdPerson,
            [INTERACTION_DYE_STATION] = self.savedVars.interactions.dyestation.enabled and
                self.savedVars.interactions.dyestation.forceThirdPerson,
        }
    else
        -- Use legacy simple settings (your current implementation)
        interactionSettings = {
            [INTERACTION_CONVERSATION] = self.savedVars.forceThirdPersonDialogue,
            [INTERACTION_QUEST] = self.savedVars.forceThirdPersonQuest,
            [INTERACTION_VENDOR] = self.savedVars.forceThirdPersonVendor,
            [INTERACTION_STORE] = self.savedVars.forceThirdPersonVendor,
            [INTERACTION_BANK] = self.savedVars.forceThirdPersonBank,
            [INTERACTION_GUILDBANK] = self.savedVars.forceThirdPersonBank,
            [INTERACTION_TRADINGHOUSE] = self.savedVars.forceThirdPersonVendor,
            [INTERACTION_STABLE] = self.savedVars.forceThirdPersonVendor,
            [INTERACTION_CRAFT] = self.savedVars.forceThirdPersonCrafting,
            [INTERACTION_DYE_STATION] = self.savedVars.forceThirdPersonCrafting,

        }
    end
end

function CinematicCam:GetInteractionConfig(interactionType)
    if not self.savedVars.usePerInteractionSettings then
        return nil -- Use legacy behavior
    end

    local configMap = {
        [INTERACTION_CONVERSATION] = self.savedVars.interactions.conversation,
        [INTERACTION_QUEST] = self.savedVars.interactions.quest,
        [INTERACTION_VENDOR] = self.savedVars.interactions.vendor,
        [INTERACTION_STORE] = self.savedVars.interactions.store,
        [INTERACTION_BANK] = self.savedVars.interactions.bank,
        [INTERACTION_GUILDBANK] = self.savedVars.interactions.guildbank,
        [INTERACTION_TRADINGHOUSE] = self.savedVars.interactions.tradinghouse,
        [INTERACTION_STABLE] = self.savedVars.interactions.stable,
        [INTERACTION_CRAFT] = self.savedVars.interactions.craft,
        [INTERACTION_DYE_STATION] = self.savedVars.interactions.dyestation,
    }

    return configMap[interactionType]
end

function CinematicCam:CheckInteractionStatus()
    if isInBlockedInteraction then
        local currentInteraction = GetInteractionType()
        if currentInteraction == INTERACTION_NONE then
            CinematicCam:OnInteractionEnd()
        else
            -- If still in interaction, check again after a delay
            zo_callLater(function()
                CinematicCam:CheckInteractionStatus()
            end, 500)
        end
    end
end

function GetCameraDistance()
    return tonumber(GetSetting(SETTING_TYPE_CAMERA, CAMERA_SETTING_DISTANCE))
end

function CinematicCam:ShouldBlockInteraction(interactionType)
    return interactionSettings[interactionType] == true
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
    local config = self:GetInteractionConfig(interactionType)

    if self.savedVars.usePerInteractionSettings and config then
        -- Use per-interaction settings
        if not config.enabled or not config.forceThirdPerson then
            return
        end

        SetInteractionUsingInteractCamera(false)
        isInBlockedInteraction = true
        self:CaptureOriginalElementStates()

        -- Apply interaction-specific layout preset
        local oldPreset = currentRepositionPreset
        currentRepositionPreset = config.layoutPreset or "default"
        d("Switched to preset: " .. currentRepositionPreset .. " for interaction")

        self:ApplyDialogueRepositioning()

        -- Save current state
        self:SaveCameraState()

        -- Handle dialogue panels, NPC text, etc.
        if config.hideDialoguePanels then
            self:HideDialoguePanels()
        end

        if config.hideNPCText then
            if ZO_InteractWindowTargetAreaBodyText then
                ZO_InteractWindowTargetAreaBodyText:SetHidden(true)
            end
            if ZO_InteractWindow_GamepadContainerText then
                ZO_InteractWindow_GamepadContainerText:SetHidden(true)
            end
        end

        -- ALWAYS intercept dialogue (for both chunked and non-chunked)
        self:InterceptDialogueForChunking()

        -- Handle letterbox and UI
        if config.autoLetterbox then
            if not self.savedVars.letterboxVisible then
                wasLetterboxAutoShown = true
                self:ShowLetterbox()
            else
                wasLetterboxAutoShown = false
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
            isInBlockedInteraction = true
            self:CaptureOriginalElementStates()

            self:ApplyDialogueRepositioning()
            self:SaveCameraState()

            if self.savedVars.hideDialoguePanels then
                self:HideDialoguePanels()
            end

            if ZO_InteractWindowTargetAreaBodyText then
                ZO_InteractWindowTargetAreaBodyText:SetHidden(self.savedVars.hideNPCText)
            end
            if ZO_InteractWindow_GamepadContainerText then
                ZO_InteractWindow_GamepadContainerText:SetHidden(self.savedVars.hideNPCText)
            end

            -- ALWAYS intercept dialogue (for both chunked and non-chunked)
            self:InterceptDialogueForChunking()

            if self:ShouldApplyLetterbox(interactionType) then
                if not self.savedVars.letterboxVisible then
                    wasLetterboxAutoShown = true
                    self:ShowLetterbox()
                else
                    wasLetterboxAutoShown = false
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
    self:InitializeLetterboxSettings()
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
    self:InitializeLetterboxSettings()
end

function CinematicCam:SetAllLayoutPreset(preset)
    for interactionName, settings in pairs(self.savedVars.interactions) do
        if type(settings) == "table" then
            settings.layoutPreset = preset
        end
    end
end

function CinematicCam:OnGameCameraActivated()
    if isInBlockedInteraction then
        -- Check if we're actually out of interaction
        zo_callLater(function()
            local currentInteraction = GetInteractionType()
            if currentInteraction == INTERACTION_NONE then
                CinematicCam:OnInteractionEnd()
            end
        end) -- just to let the interaction state update
    end
end

function CinematicCam:OnInteractionEnd()
    if isInBlockedInteraction then
        isInBlockedInteraction = false

        -- Always cleanup chunked dialogue when interaction ends
        if self.savedVars.useChunkedDialogue then
            self:CleanupChunkedDialogue()
        end

        -- RESTORE DIALOGUE PANELS ONLY IF THEY WERE HIDDEN
        if self.savedVars.hideDialoguePanels then
            self:ShowDialoguePanels()
        end

        -- Restore camera state
        self:RestoreCameraState()

        -- Only hide letterbox if we auto-showed it
        if wasLetterboxAutoShown and self.savedVars.letterboxVisible then
            self:HideLetterbox()
        end

        -- Only show UI if we auto-hid it
        if wasUIAutoHidden and not self.savedVars.uiVisible then
            self:ShowUI()
        end

        -- Reset tracking flags
        wasLetterboxAutoShown = false
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
    if ZO_InteractWindow_GamepadContainerText then
        ZO_InteractWindow_GamepadContainerText:SetHidden(true)
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
    if ZO_InteractWindow_GamepadContainerText then
        ZO_InteractWindow_GamepadContainerText:SetHidden(true)
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
        d("ApplyFontToElement: No element provided")
        return
    end

    local fontPath = self:GetCurrentFont()
    d("Applying font: " .. tostring(fontPath) .. " size: " .. tostring(fontSize))

    -- ESO default font (nil path means use default)
    if not fontPath then
        d("Using ESO default font")
        return
    end

    local actualSize = fontSize or self.savedVars.customFontSize
    actualSize = math.floor(actualSize * self.savedVars.fontScale)

    -- Parse the font path and replace size
    local finalFontString = self:ParseFontPath(fontPath, actualSize)

    if finalFontString then
        d("Setting font string: " .. finalFontString)
        element:SetFont(finalFontString)

        -- Verify font was applied
        local appliedFont = element:GetFont()
        d("Font applied successfully: " .. tostring(appliedFont))
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

function CinematicCam:SetupDialogueFontHooks()
    -- Interaction window hook
    local originalSetupInteraction = ZO_InteractWindow_OnInteractionUpdated
    if originalSetupInteraction then
        ZO_InteractWindow_OnInteractionUpdated = function(...)
            originalSetupInteraction(...)
            -- Apply fonts after dialogue is set up

            CinematicCam:ApplyFontsToUI()
        end
    end

    -- Add these new hooks for dialogue advancement:
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_Font", EVENT_CHATTER_BEGIN, function()
        zo_callLater(function()
            CinematicCam:ApplyFontsToUI()
        end)
    end)

    -- Hook for when dialogue text updates/advances
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_Font", EVENT_CONVERSATION_UPDATED, function()
        zo_callLater(function()
            CinematicCam:ApplyFontsToUI()
        end)
    end)

    -- Hook for quest dialogue updates
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_Font", EVENT_QUEST_COMPLETE_DIALOG, function()
        zo_callLater(function()
            CinematicCam:ApplyFontsToUI()
        end)
    end)

    -- Hook for any interaction changes
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_Font", EVENT_INTERACTION_UPDATED, function()
        zo_callLater(function()
            CinematicCam:ApplyFontsToUI()
        end)
    end)
end

function CinematicCam:OnFontChanged()
    -- Apply fonts immediately if dialogue is currently open
    local interactionType = GetInteractionType()
    if interactionType ~= INTERACTION_NONE then
        self:ApplyFontsToUI()
    end
    self:UpdateChunkedTextFont()
    -- Also apply to any existing dialogue elements
    zo_callLater(function()
        self:ApplyFontsToUI()
    end)
end

-- Repositioning preset system
local repositionPresets = {
    ["default"] = {
        name = "Default ESO Layout",
        applyFunction = function(self)
            self:RestoreDefaultPositions()
        end
    },
    ["subtle_center"] = {
        name = "Subtle Center",
        applyFunction = function(self)
            self:ApplySubtleCenterRepositioning()
        end
    },
    ["full_center"] = {
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
    zo_callLater(function()
        local rootWindow = _G["ZO_InteractWindow_Gamepad"]

        if rootWindow then
            local screenWidth, screenHeight = GuiRoot:GetDimensions()
            local originalWidth, originalHeight = rootWindow:GetDimensions()

            local centerX = screenWidth * 0.27
            local centerY = 40

            -- Coordinate with letterbox if active
            if self.savedVars.letterboxVisible then
                centerY = self.savedVars.letterboxSize * 0.3 -- Position optimally within letterbox area
            end

            -- Apply full center positioning
            rootWindow:ClearAnchors()
            rootWindow:SetAnchor(CENTER, GuiRoot, CENTER, centerX, centerY)

            -- Set appropriate dimensions for center positioning
            local maxWidth = math.min(originalWidth, screenWidth * 0.8)
            rootWindow:SetWidth(683)
            rootWindow:SetHeight(2000)
        else
            d("ERROR: Root window not found for repositioning")
        end
    end)
end

function CinematicCam:RestoreDefaultPositions()
    local rootWindow = _G["ZO_InteractWindow_Gamepad"]
    ZO_InteractWindow_GamepadContainerText:SetHidden(false)
    if rootWindow then
        -- Clear custom anchors
        rootWindow:ClearAnchors()

        -- Restore ESO's default gamepad dialogue positioning
        -- Based on our dimensional analysis: positioned on right side of screen
        rootWindow:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, -50, 100)

        -- Restore original dimensions
        rootWindow:SetWidth(683) -- From our measurements
        rootWindow:SetHeight(1083)
    else
        d("ERROR: Root window not found for restoration")
    end
end

function CinematicCam:ApplyDialogueRepositioning()
    local preset = repositionPresets[currentRepositionPreset]
    if preset and preset.applyFunction then
        preset.applyFunction(self)
    end
end

function CinematicCam:TestChunkingSystem()
    local testText =
    "Hello there, traveler! I see you've been exploring our beautiful lands. Did you know that the ancient ruins nearby contain treasures from a forgotten age? Many adventurers have tried to unlock their secrets, but few have succeeded. Would you be interested in taking on this challenging quest?"

    d("=== CHUNKING TEST ===")
    d("Original text (" .. string.len(testText) .. " chars):")
    d(testText)
    d("")

    local chunks = self:ProcessTextIntoChunks(testText)
    d("Generated " .. #chunks .. " chunks:")

    for i, chunk in ipairs(chunks) do
        d(string.format("Chunk %d (%d chars): %s", i, string.len(chunk), chunk))
    end
end

function CinematicCam:InvestigateESOTextControlSyntax()
    d("=== ESO TEXT CONTROL XML SYNTAX INVESTIGATION ===")

    -- Check existing ESO dialogue text controls to understand their structure
    local dialogueElements = {
        "ZO_InteractWindowTargetAreaBodyText",
        "ZO_InteractWindow_GamepadContainerText"
    }

    for _, elementName in ipairs(dialogueElements) do
        local element = _G[elementName]
        if element then
            d(elementName .. ":")
            d("  Type: " .. tostring(element:GetType()))
            d("  Parent: " .. tostring(element:GetParent():GetName()))
            d("  DrawLayer: " .. tostring(element:GetDrawLayer()))
            d("  DrawLevel: " .. tostring(element:GetDrawLevel()))

            -- Check if it was created from XML template
            if element.xmlNode then
                d("  Created from XML template")
            else
                d("  Created programmatically")
            end
        end
    end
end

function CinematicCam:BuildUserFontString()
    local selectedFont = self.savedVars.selectedFont
    local fontSize = self.savedVars.customFontSize
    local fontScale = self.savedVars.fontScale

    -- Calculate final size
    local finalSize = math.floor(fontSize * fontScale)

    d("Building font string: " .. selectedFont .. " size: " .. finalSize)

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

function CinematicCam:InitializeChunkedTextControl()
    -- Try to get the XML-defined control first
    local control = _G["CinematicCam_ChunkedText"]

    if not control then
        -- Create control programmatically as fallback
        control = CreateControl("CinematicCam_ChunkedDialogue", GuiRoot, CT_LABEL)

        if not control then
            d("ERROR: Failed to create chunked text control")
            return nil
        end
    end

    -- DON'T set position here - let ApplyChunkedTextPositioning handle it
    -- Just set basic properties

    -- Basic visibility settings
    control:SetColor(1, 1, 1, 1) -- White text
    control:SetAlpha(1.0)
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

    d("Chunked text control initialized (positioning will be applied separately)")
    return control
end

function CinematicCam:OnDialogueLayoutPresetChanged(newPreset)
    -- Update the current preset
    currentRepositionPreset = newPreset

    -- If chunked dialogue is active, reapply positioning
    if chunkedDialogueData.isActive and chunkedDialogueData.customControl then
        self:ApplyChunkedTextPositioning()
        d("Reapplied chunked text positioning for new preset: " .. newPreset)
    end
end

function CinematicCam:ApplyChunkedTextPositioning()
    local control = chunkedDialogueData.customControl
    if not control then return end

    local preset = currentRepositionPreset or "default"
    d("Applying chunked text positioning with preset: " .. preset)

    control:ClearAnchors()

    -- Copy positioning logic from your ESO repositioning functions
    if preset == "full_center" then
        -- From ApplyFullCenterRepositioning
        local screenWidth, screenHeight = GuiRoot:GetDimensions()
        local centerX = screenWidth * 0.27
        local centerY = 10

        if self.savedVars.letterboxVisible then
            centerY = self.savedVars.letterboxSize * 0.3
        end

        control:SetAnchor(CENTER, GuiRoot, CENTER, centerX, centerY)
        control:SetDimensions(683, 250) -- Appropriate for text
    elseif preset == "subtle_center" then
        -- From ApplySubtleCenterRepositioning
        local screenWidth, screenHeight = GuiRoot:GetDimensions()
        local npcYOffset = screenHeight * 0.20 + (100 * 0.5)

        control:SetAnchor(CENTER, GuiRoot, CENTER, 0, npcYOffset)
        control:SetDimensions(700, 200)
    else -- default
        -- From RestoreDefaultPositions
        control:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, -50, 70)
        control:SetDimensions(683, 550)
    end

    d("XML control positioned to match " .. preset .. " ESO dialogue positioning")
end

function CinematicCam:VerifyChunkedTextXMLControl()
    d("=== CHUNKED TEXT XML CONTROL VERIFICATION ===")

    local control = CinematicCam_ChunkedText

    if control then
        d("✅ XML control found")
        d("  Type: " .. tostring(control:GetType()))
        d("  Parent: " .. tostring(control:GetParent():GetName()))
        d("  Initial dimensions: " .. control:GetWidth() .. "x" .. control:GetHeight())
        d("  Initial draw layer: " .. tostring(control:GetDrawLayer()))
        d("  Initial draw level: " .. tostring(control:GetDrawLevel()))

        -- Test programmatic modification
        control:SetText("XML Control Test")
        control:SetHidden(false)

        zo_callLater(function()
            control:SetHidden(true)
            control:SetText("")
            d("✅ Programmatic control successful")
        end, 2000)
    else
        d("❌ XML control not found - check XML syntax")
    end
end

---=============================================================================
-- Initialize
--=============================================================================
local function Initialize()
    -- Load saved variables
    CinematicCam.savedVars = ZO_SavedVars:NewAccountWide("CinematicCamSavedVars", 2, nil, defaults)

    CinematicCam:SetupDialogueFontHooks()
    CinematicCam:SetOptimalTimingDefaults()


    -- Apply fonts after UI elements are loaded

    CinematicCam:ApplyFontsToUI()

    CinematicCam:InitializeChunkedDialogueSystem()

    CinematicCam:InitializeChunkedTextControl()


    -- NEW: Add chunked dialogue slash commands for testing
    SLASH_COMMANDS["/ccchunk"] = function(args)
        if args == "on" then
            CinematicCam.savedVars.useChunkedDialogue = true
            d("Chunked dialogue enabled")
        elseif args == "off" then
            CinematicCam.savedVars.useChunkedDialogue = false
            d("Chunked dialogue disabled")
        elseif args == "test" then
            CinematicCam:TestChunkingSystem()
        else
            d("Usage: /ccchunk [on|off|test]")
        end
    end

    -- Init letterbox bars savedVars
    if CinematicCam.savedVars.letterboxVisible then
        zo_callLater(function()
            CinematicCam_Container:SetHidden(false)
            CinematicCam_LetterboxTop:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT)
            CinematicCam_LetterboxTop:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT)
            CinematicCam_LetterboxTop:SetHeight(CinematicCam.savedVars.letterboxSize)
            CinematicCam_LetterboxTop:SetColor(0, 0, 0, CinematicCam.savedVars.letterboxOpacity)
            CinematicCam_LetterboxTop:SetDrawLayer(DL_OVERLAY)
            CinematicCam_LetterboxTop:SetDrawLevel(5)
            CinematicCam_LetterboxTop:SetHidden(false)

            CinematicCam_LetterboxBottom:SetAnchor(BOTTOMLEFT, GuiRoot, BOTTOMLEFT)
            CinematicCam_LetterboxBottom:SetAnchor(BOTTOMRIGHT, GuiRoot, BOTTOMRIGHT)
            CinematicCam_LetterboxBottom:SetHeight(CinematicCam.savedVars.letterboxSize)
            CinematicCam_LetterboxBottom:SetColor(0, 0, 0, CinematicCam.savedVars.letterboxOpacity)
            CinematicCam_LetterboxBottom:SetDrawLayer(DL_OVERLAY)
            CinematicCam_LetterboxBottom:SetDrawLevel(5)
            CinematicCam_LetterboxBottom:SetHidden(false)
        end, 1500) -- Wait for UI to be ready
    else
        zo_callLater(function()
            CinematicCam_Container:SetHidden(false) -- Container can stay visible
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
                    hiddenElements[elementName] = true
                    element:SetHidden(true)
                end
            end
            for elementName, shouldHide in pairs(CinematicCam.savedVars.hideUiElements) do
                if shouldHide then
                    local element = _G[elementName]
                    if element and not element:IsHidden() then
                        hiddenElements[elementName] = true
                        element:SetHidden(true)
                    end
                end
            end
        end, 1600)
    end
    -- Add a slash command to trigger debugging
    SLASH_COMMANDS["/ccdebug"] = function()
        CinematicCam:DebugDialogueElements()
    end
    SLASH_COMMANDS["/cchierarchy"] = function()
        CinematicCam:DebugGamepadDialogueHierarchy()
    end
    -- Register slash commands
    SLASH_COMMANDS["/ccui"] = function()
        CinematicCam:ToggleUI()
    end
    SLASH_COMMANDS["/cctest"] = function(preset)
        if not preset or preset == "" then
            d("Usage: /cctest [default|subtle_center|full_center]")
            return
        end

        if repositionPresets[preset] then
            currentRepositionPreset = preset
            CinematicCam.savedVars.dialogueLayoutPreset = preset


            local interactionType = GetInteractionType()
            if interactionType ~= INTERACTION_NONE then
                CinematicCam:ApplyDialogueRepositioning()
            end
        else
            d("Invalid preset: " .. preset)
        end
    end
    -- NEW: Add chunked dialogue slash commands
    SLASH_COMMANDS["/ccchunk"] = function(args)
        if args == "on" then
            CinematicCam.savedVars.useChunkedDialogue = true
            d("Chunked dialogue enabled")
        elseif args == "off" then
            CinematicCam.savedVars.useChunkedDialogue = false
            d("Chunked dialogue disabled")
        elseif args == "test" then
            CinematicCam:TestChunkingSystem()
        else
            d("Usage: /ccchunk [on|off|test]")
        end
    end

    SLASH_COMMANDS["/ccbars"] = function()
        CinematicCam:ToggleLetterbox()
    end
    currentRepositionPreset = CinematicCam.savedVars.dialogueLayoutPreset or "default"
    CinematicCam:InitializeLetterboxSettings()
    -- Initialize 3rd person dialogue settings
    CinematicCam:InitializeInteractionSettings()

    -- Calculate letterbox size
    CinematicCam:CalculateLetterboxSize()


    -- Register for camera events (for 3rd person dialogue)
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
    end)
    zo_callLater(function()
        -- Create settings menu with LibAddonMenu-2.0
        CinematicCam:CreateSettingsMenu()
        CinematicCam:RegisterSceneCallbacks() -- Not doing anything
    end, 100)
end



local function OnPlayerActivated(eventCode)
    if not CinematicCam.hasPlayedIntro then
        CinematicCam.hasPlayedIntro = true
        camEnabled = true

        -- Smooth exit after a few seconds
        zo_callLater(function()
            camEnabled = false
            CinematicCam:ShowUI()
        end, 100)
    end
end

-- Keybind functions
function CinematicCam.ToggleCinematicMode()
    CinematicCam:ToggleUI()
    CinematicCam:ToggleLetterbox()
end

-- OnAddOnLoaded event
local function OnAddOnLoaded(event, addonName)
    if addonName == ADDON_NAME then
        EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
        Initialize()
    end
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
