-- Cinematic Camera with UI Hiding and Letterbox
local ADDON_NAME = "CinematicCam"
CinematicCam = {}
CinematicCam.savedVars = nil


local uiElementsMap = {}      -- table for hiding ui elements, used in HideUI()
local interactionTypeMap = {} -- table for interaction type settings

-- State tracking
local isInteractionModified = false -- overriden default cam
local mountLetterbox = false
local dialogLetterbox = false
local wasUIAutoHidden = false

local lastDialogueText = ""
local dialogueChangeCheckTimer = nil


-- Default settings
local defaults = {
    camEnabled = false,
    npcNamePreset = "default",
    npcNameColor = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 },
    npcNameFontSize = 42,
    -- Slightly larger than dialogue text
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
            useChunkedDialogue = false,
            posY = .8,
            posX = .5

        },
    },
    interface = {
        UiElementsVisible = true,
        hideDialoguePanels = false,
        selectedFont = "ESO_Standard",
        customFontSize = 42,
        fontScale = 1.0,
        dialogueHorizontalOffset = 0.34,
        dialogueVerticallOffset = 0.34,

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
    usePerInteractionSettings = false, -- Global setting
}

-- NPC Name tables
local npcNameData = {
    originalName = "",
    customNameControl = nil,
    currentPreset = "default"
}
local namePresetDefaults = {

    npcNameColor = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 },
    npcNameFontSize = 42,
}

-- Chunked Dialog Table
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
    -- Compass
    "ZO_CompassFrame",
    "ZO_CompassFrameCenter",
    "ZO_CompassFrameLeft",
    "ZO_CompassFrameRight",
    "ZO_CompassContainer",

    -- Action  Bar
    "ZO_PlayerAttributeHealth",
    "ZO_PlayerAttributeMagicka",
    "ZO_PlayerAttributeStamina",
    "ZO_ActionBar1",
    "ZO_ActionBar2",
    "ZO_TargetUnitFrame",
    "ZO_UnitFrames",

    "ZO_MinimapContainer",

    -- Buff bar
    "ZO_PowerBlock",
    "ZO_BuffTracker",

    -- Reticle
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
    "ZO_ConversationWindow",

    -- Inventory & Menus
    "ZO_PlayerInventory",
    "ZO_GameMenu_InGame",
    "ZO_MainMenuCategoryBarContainer",

    -- Social UI
    "ZO_GroupWindow",
    "ZO_ChatMenu_Gamepad_TopLevel",
    "ZO_GamepadTextChat",
    "ZO_GamepadTextChatBg",
    "ZO_GamepadTextChatScrollBar",
    "ZO_GamepadTextChatWindowContainer",
    "ZO_ChatWindowTab_Gamepad1",
    "ZO_ChatMenu_Gamepad_TopLevelMask",
    "ZO_ChatWindowTemplate1",
    "ZO_GamepadChatSystem",

    -- Other UI
    "ZO_NotificationContainer",
    "ZO_TutorialOverlay",

}
local playerOptionsData = {
    isDetached = false,
    detectedElement = nil,
    elementName = "",
    originalParent = nil,
    originalAnchors = {},
    originalDrawLayer = nil,
    originalDrawLevel = nil,
    originalInheritAlpha = nil,
    originalInheritScale = nil,
    isActive = false
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
                    self:ReapplyUIState()
                end
            end)
        end
    end
end

function CinematicCam:ReapplyUIState()
    -- Reapply UI visibility based on saved setting
    if not self.savedVars.interface.UiElementsVisible then
        self:HideUI()
    end

    -- Reapply letterbox if it should be visible
    if self.savedVars.letterbox.letterboxVisible then
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

-- Show regular npc text using eso's ui and not using the cinematic mode
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
    return interactionTypeMap and self.savedVars.interaction.auto.autoLetterboxDialogue
end

function CinematicCam:ShowLetterbox()
    if self.savedVars.letterbox.letterboxVisible then
        return
    end
    self.savedVars.letterbox.letterboxVisible = true

    CinematicCam_Container:SetHidden(false)

    local barHeight = self.savedVars.letterbox.size

    CinematicCam_LetterboxTop:ClearAnchors()
    CinematicCam_LetterboxTop:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 0, -barHeight)
    CinematicCam_LetterboxTop:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, 0, -barHeight)
    CinematicCam_LetterboxTop:SetHeight(barHeight)

    CinematicCam_LetterboxBottom:ClearAnchors()
    CinematicCam_LetterboxBottom:SetAnchor(BOTTOMLEFT, GuiRoot, BOTTOMLEFT, 0, barHeight)
    CinematicCam_LetterboxBottom:SetAnchor(BOTTOMRIGHT, GuiRoot, BOTTOMRIGHT, 0, barHeight)
    CinematicCam_LetterboxBottom:SetHeight(barHeight)

    -- Set color and draw properties
    CinematicCam_LetterboxTop:SetColor(0, 0, 0, self.savedVars.letterbox.opacity)
    CinematicCam_LetterboxBottom:SetColor(0, 0, 0, self.savedVars.letterbox.opacity)
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

    timeline:PlayFromStart()
end

-- Hide letterbox bars
function CinematicCam:HideLetterbox()
    if not self.savedVars.letterbox.letterboxVisible then
        return
    end
    if CinematicCam_LetterboxTop:IsHidden() then
        return
    end

    local barHeight = self.savedVars.letterbox.size

    local timeline = ANIMATION_MANAGER:CreateTimeline()

    -- Top bar
    local topAnimation = timeline:InsertAnimation(ANIMATION_TRANSLATE, CinematicCam_LetterboxTop)
    topAnimation:SetTranslateOffsets(0, 0, 0, -barHeight)
    topAnimation:SetDuration(3300)
    topAnimation:SetEasingFunction(ZO_EaseOutCubic)
    -- Bottom bar
    local bottomAnimation = timeline:InsertAnimation(ANIMATION_TRANSLATE, CinematicCam_LetterboxBottom)
    bottomAnimation:SetTranslateOffsets(0, 0, 0, barHeight)
    bottomAnimation:SetDuration(3300)
    bottomAnimation:SetEasingFunction(ZO_EaseOutCubic)

    timeline:SetHandler('OnStop', function()
        CinematicCam_LetterboxTop:SetHidden(true)
        CinematicCam_LetterboxBottom:SetHidden(true)
        CinematicCam_LetterboxTop:ClearAnchors()
        CinematicCam_LetterboxTop:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT)
        CinematicCam_LetterboxTop:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT)
        CinematicCam_LetterboxBottom:ClearAnchors()
        CinematicCam_LetterboxBottom:SetAnchor(BOTTOMLEFT, GuiRoot, BOTTOMLEFT)
        CinematicCam_LetterboxBottom:SetAnchor(BOTTOMRIGHT, GuiRoot, BOTTOMRIGHT)
        self.savedVars.letterbox.letterboxVisible = false
    end)
    timeline:PlayFromStart()
end

function CinematicCam:ToggleLetterbox()
    if self.savedVars.letterbox.letterboxVisible then
        self:HideLetterbox()
    else
        self:ShowLetterbox()
    end
end

---=============================================================================
-- Cinematic Mounting
--=============================================================================
function CinematicCam:OnMountUp()
    if not self.savedVars or not self.savedVars.letterbox then
        return
    end

    if self.savedVars.letterbox.autoLetterboxMount then
        if not self.savedVars.letterbox.letterboxVisible then
            mountLetterbox = true
            -- Apply delay
            local delayMs = self.savedVars.letterbox.mountLetterboxDelay * 1000
            if delayMs > 0 then
                mountLetterboxTimer = zo_callLater(function()
                    if IsMounted() and mountLetterbox then
                        self:ShowLetterbox()
                    else
                        mountLetterbox = false
                    end
                    mountLetterboxTimer = nil
                end, delayMs)
            else
                self:ShowLetterbox()
            end
        else
            mountLetterbox = false
        end
    end
end

function CinematicCam:OnMountDown()
    if not self.savedVars or not self.savedVars.letterbox then
        return
    end

    if self.savedVars.letterbox.autoLetterboxMount then
        if mountLetterbox and self.savedVars.letterbox.letterboxVisible then
            self:HideLetterbox()
        end
        mountLetterbox = false
    end
end

---=============================================================================
-- Manage ESO UI Elements
--=============================================================================
function CinematicCam:HideUI()
    if not self.savedVars.interface.UiElementsVisible then
        return
    end
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
    self.savedVars.interface.UiElementsVisible = false
end

-- Show UI elements
function CinematicCam:ShowUI()
    if self.savedVars.interface.UiElementsVisible then
        return
    end
    for elementName, _ in pairs(uiElementsMap) do
        local element = _G[elementName]
        if element then
            element:SetHidden(false)
        end
    end
    uiElementsMap = {}
    self.savedVars.interface.UiElementsVisible = true
end

-- Toggle UI
function CinematicCam:ToggleUI()
    if self.savedVars.interface.UiElementsVisible then
        self:HideUI()
    else
        self:ShowUI()
    end
end

-- THE INTERACT LIST CONTAINER FOR GAMEPAD IS
-- ZO_InteractWindow_GamepadContainerInteract(List)
-- ZO_InteractWindow_Gamepad
-- ZO_InteractWindow_GamepadTitle

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

-- Preview system for subtitle positioning
local previewTimer = nil
local isPreviewActive = false


function CinematicCam:ConvertToScreenCoordinates(normalizedX, normalizedY)
    local screenWidth = GuiRoot:GetWidth()
    local screenHeight = GuiRoot:GetHeight()

    local targetX = 0 -- Default to center for X
    local targetY = 0 -- Default to center for Y

    if normalizedX then
        -- Convert 0-1 range to actual screen position
        -- 0.5 (50%) should be center (0 offset)
        -- 0.0 (0%) should be left, 1.0 (100%) should be right
        targetX = (normalizedX - 0.5) * screenWidth * 0.8 -- 0.8 to keep within reasonable bounds
    end

    if normalizedY then
        -- For cinematic preset, you use a fixed offset from center
        if self.savedVars.interaction.layoutPreset == "cinematic" then
            -- Convert 0-1 range to actual screen position
            -- 0.5 (50%) should be center (0 offset)
            -- 0.0 (0%) should be top, 1.0 (100%) should be bottom
            targetY = (normalizedY - 0.5) * screenHeight * 0.8 -- 0.8 to keep within reasonable bounds
        else
            -- For default preset, match your existing logic
            targetY = (normalizedY * screenHeight) - (screenHeight / 2)
        end
    end

    return targetX, targetY
end

function CinematicCam:ShowSubtitlePreview(xPosition, yPosition)
    if not CinematicCam_PreviewContainer or not CinematicCam_PreviewText or not CinematicCam_PreviewBackground then
        return
    end

    isPreviewActive = true

    -- Convert percentage to screen coordinates
    local normalizedX = xPosition and (xPosition / 100) or (self.savedVars.interaction.subtitles.posX or 0.5)
    local normalizedY = yPosition and (yPosition / 100) or (self.savedVars.interaction.subtitles.posY or 0.7)

    local targetX, targetY = self:ConvertToScreenCoordinates(normalizedX, normalizedY)

    -- Position the background box
    CinematicCam_PreviewBackground:ClearAnchors()
    CinematicCam_PreviewBackground:SetAnchor(CENTER, GuiRoot, CENTER, targetX, targetY)

    -- Set background properties (slightly opaque dark background)
    CinematicCam_PreviewBackground:SetColor(0, 0, 0, 0.7) -- Dark background with 70% opacity
    CinematicCam_PreviewBackground:SetDrawLayer(DL_CONTROLS)
    CinematicCam_PreviewBackground:SetDrawLevel(5)

    -- Position the preview text
    CinematicCam_PreviewText:ClearAnchors()
    CinematicCam_PreviewText:SetAnchor(CENTER, GuiRoot, CENTER, targetX, targetY)

    -- Set preview text properties
    CinematicCam_PreviewText:SetText("Sample Dialogue Text Preview")
    CinematicCam_PreviewText:SetColor(1, 1, 1, 1) -- White text
    CinematicCam_PreviewText:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    CinematicCam_PreviewText:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    CinematicCam_PreviewText:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    -- Apply current font settings to preview
    local fontString = self:BuildUserFontString()
    CinematicCam_PreviewText:SetFont(fontString)

    -- Show the preview container
    CinematicCam_PreviewContainer:SetHidden(false)
    CinematicCam_PreviewBackground:SetHidden(false)
    CinematicCam_PreviewText:SetHidden(false)

    -- Clear any existing timer
    if previewTimer then
        zo_removeCallLater(previewTimer)
    end

    -- Auto-hide preview after 3 seconds
    previewTimer = zo_callLater(function()
        self:HideSubtitlePreview()
    end, 3000)
end

function CinematicCam:HideSubtitlePreview()
    if not isPreviewActive then
        return
    end

    isPreviewActive = false

    -- Clear timer
    if previewTimer then
        zo_removeCallLater(previewTimer)
        previewTimer = nil
    end

    -- Hide preview elements
    if CinematicCam_PreviewContainer then
        CinematicCam_PreviewContainer:SetHidden(true)
    end
    if CinematicCam_PreviewBackground then
        CinematicCam_PreviewBackground:SetHidden(true)
    end
    if CinematicCam_PreviewText then
        CinematicCam_PreviewText:SetHidden(true)
    end
end

function CinematicCam:UpdatePreviewPosition(xPosition, yPosition)
    if isPreviewActive then
        -- Update position in real-time while slider is being moved
        local normalizedX = xPosition and (xPosition / 100) or (self.savedVars.interaction.subtitles.posX or 0.5)
        local normalizedY = yPosition and (yPosition / 100) or (self.savedVars.interaction.subtitles.posY or 0.7)

        local targetX, targetY = self:ConvertToScreenCoordinates(normalizedX, normalizedY)

        if CinematicCam_PreviewBackground then
            CinematicCam_PreviewBackground:ClearAnchors()
            CinematicCam_PreviewBackground:SetAnchor(CENTER, GuiRoot, CENTER, targetX, targetY)
        end

        if CinematicCam_PreviewText then
            CinematicCam_PreviewText:ClearAnchors()
            CinematicCam_PreviewText:SetAnchor(CENTER, GuiRoot, CENTER, targetX, targetY)
        end

        -- Reset the auto-hide timer
        if previewTimer then
            zo_removeCallLater(previewTimer)
        end
        previewTimer = zo_callLater(function()
            self:HideSubtitlePreview()
        end, 3000)
    end
end

-- Initialize preview system
function CinematicCam:InitializePreviewSystem()
    -- Ensure preview containers start hidden
    if CinematicCam_PreviewContainer then
        CinematicCam_PreviewContainer:SetHidden(true)
    end

    if CinematicCam_PlayerOptionsPreviewContainer then
        CinematicCam_PlayerOptionsPreviewContainer:SetHidden(true)
    end

    -- Register for scene changes to hide preview when settings close
    local function hidePreviewOnSceneChange()
        self:HideSubtitlePreview()
        self:HidePlayerOptionsPreview()
    end

    -- Hook into various scene changes that might close settings
    SCENE_MANAGER:RegisterCallback("SceneStateChanged", function(scene, oldState, newState)
        if newState == SCENE_HIDING or newState == SCENE_HIDDEN then
            hidePreviewOnSceneChange()
        end
    end)
end

function CinematicCam:GetNPCName()
    local sources = {
        ZO_InteractWindow_GamepadTitle,
        ZO_InteractWindowTargetAreaTitle
    }

    for _, element in ipairs(sources) do
        if element then
            local name = element.text or element:GetText() or ""
            if string.len(name) > 0 then
                return name, element
            end
        end
    end

    return nil, nil
end

function CinematicCam:CreateNPCNameControl()
    if npcNameData.customNameControl then
        return npcNameData.customNameControl
    end

    -- Create custom label control for NPC name
    local control = CreateControl("CinematicCam_NPCName", GuiRoot, CT_LABEL)

    -- Set text properties
    control:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    control:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    control:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    -- Apply NPC name color
    local color = self.savedVars.npcNameColor or namePresetDefaults.npcNameColor
    control:SetColor(color.r, color.g, color.b, color.a)

    -- Apply font (slightly larger than dialogue text)
    local fontSize = self.savedVars.npcNameFontSize or namePresetDefaults.npcNameFontSize
    self:ApplyFontToElement(control, fontSize)

    -- Set draw properties
    control:SetDrawLayer(DL_OVERLAY)
    control:SetDrawLevel(7) -- Above chunked text (level 6) but below UI

    -- Start hidden
    control:SetHidden(true)
    control:SetText("")

    npcNameData.customNameControl = control
    return control
end

function CinematicCam:RGBToHexString(r, g, b)
    -- Convert 0-1 float values to 0-255 integer values
    local red = math.floor(r * 255)
    local green = math.floor(g * 255)
    local blue = math.floor(b * 255)

    -- Convert to hex and ensure 2-digit format
    return string.format("%02X%02X%02X", red, green, blue)
end

function CinematicCam:ProcessNPCNameForPreset(dialogueText, npcName, preset)
    if not npcName or npcName == "" then
        return dialogueText
    end

    preset = preset or self.savedVars.npcNamePreset or "default"

    if preset == "prepended" then
        -- Add colored name to beginning of dialogue: "|cFFFFFFJohn|r: Hello there!"
        local color = self.savedVars.npcNameColor or namePresetDefaults.npcNameColor
        local hexColor = self:RGBToHexString(color.r, color.g, color.b)
        local coloredName = "|c" .. hexColor .. npcName .. ": |r"
        return coloredName .. dialogueText
    elseif preset == "above" then
        -- Name will be displayed separately above, return original text
        return dialogueText
    else
        -- Default: return original text unchanged
        return dialogueText
    end
end

function CinematicCam:PositionNPCNameControl(preset)
    local control = npcNameData.customNameControl
    if not control then return end

    preset = preset or self.savedVars.npcNamePreset or "default"

    if preset == "above" then
        -- Position above the dialogue text
        local dialogueControl = chunkedDialogueData.customControl
        if dialogueControl and self.savedVars.interaction.layoutPreset == "cinematic" then
            -- Get dialogue position and place name above it
            local targetX, targetY = self:ConvertToScreenCoordinates(
                self.savedVars.interaction.subtitles.posX or 0.5,
                self.savedVars.interaction.subtitles.posY or 0.7
            )
            control:ClearAnchors()
            control:SetAnchor(CENTER, GuiRoot, CENTER, targetX, targetY - 80) -- 80 pixels above dialogue
            control:SetDimensions(800, 60)
        else
            -- Fallback positioning for non-cinematic mode
            control:ClearAnchors()
            control:SetAnchor(CENTER, GuiRoot, CENTER, 0, -200)
            control:SetDimensions(600, 60)
        end
    end
end

function CinematicCam:ApplyNPCNamePreset(preset)
    preset = preset or self.savedVars.npcNamePreset or "default"
    npcNameData.currentPreset = preset

    local npcName, originalElement = self:GetNPCName()

    if preset == "default" then
        -- Show original ESO name element
        if originalElement then
            originalElement:SetHidden(false)
            --originalElement:SetText(GetUnitName("player"))
        end
        -- Hide custom name control
        if npcNameData.customNameControl then
            npcNameData.customNameControl:SetHidden(true)
        end
    elseif preset == "prepended" then
        -- Hide original name element
        if originalElement then
            originalElement:SetHidden(true)
        end
        -- Hide custom name control (name will be in dialogue text)
        if npcNameData.customNameControl then
            npcNameData.customNameControl:SetHidden(true)
        end
    elseif preset == "above" then
        -- Hide original name element
        if originalElement then
            originalElement:SetHidden(true)
        end

        -- Show custom name control
        if not npcNameData.customNameControl then
            self:CreateNPCNameControl()
        end

        local control = npcNameData.customNameControl
        if control and npcName then
            control:SetText(npcName)
            self:PositionNPCNameControl(preset)
            control:SetHidden(false)
        end
    end
    -- Store the NPC name for use in dialogue processing
    npcNameData.originalName = npcName or ""
end

function CinematicCam:UpdateNPCNameFont()
    local control = npcNameData.customNameControl
    if control then
        local fontSize = self.savedVars.npcNameFontSize or namePresetDefaults.npcNameFontSize
        self:ApplyFontToElement(control, fontSize)
    end
end

-- Function to update NPC name color
function CinematicCam:UpdateNPCNameColor()
    local control = npcNameData.customNameControl
    if control then
        local color = self.savedVars.npcNameColor or namePresetDefaults.npcNameColor
        control:SetColor(color.r, color.g, color.b, color.a)
    end
end

---=============================================================================
-- Chunked Text
--=============================================================================
-- Create XML element
function CinematicCam:CreateChunkedTextControl()
    if chunkedDialogueData.customControl then
        return chunkedDialogueData.customControl
    end
    local control = CreateControl("CinematicCam_ChunkedDialogue", GuiRoot, CT_LABEL)

    self:ApplyFontToElement(control, self.savedVars.interface.customFontSize)

    -- Set text properties
    control:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    control:SetVerticalAlignment(TEXT_ALIGN_TOP)
    control:SetHorizontalAlignment(TEXT_ALIGN_LEFT)

    -- Color customization
    control:SetColor(0.9, 0.9, 0.8, 1.0)
    self:PositionChunkedTextControl(control)

    control:SetHidden(true)

    chunkedDialogueData.customControl = control
    return control
end

function CinematicCam:PositionChunkedTextControl(control)
    local preset = self.savedVars.interaction.layoutPreset

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
        control:SetDimensions(4000, 750)
    end
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

        local currentRawText, _ = self:GetDialogueText()

        -- Compare RAW text instead of processed text
        if currentRawText and currentRawText ~= chunkedDialogueData.rawDialogueText then
            -- Only cleanup if there's actually new dialogue content
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
        npcNameData.originalName,
        self.savedVars.npcNamePreset
    )

    if sourceElement and self.savedVars.interaction.layoutPreset == "default" then
        sourceElement:SetHidden(false)
    elseif sourceElement and self.savedVars.interaction.layoutPreset == "cinematic" then
        sourceElement:SetHidden(true)
    end

    -- CLEANUP ANY EXISTING DISPLAY
    if chunkedDialogueData.isActive then
        self:CleanupChunkedDialogue()
    end

    -- Store both versions
    chunkedDialogueData.originalText = processedTextForDisplay
    chunkedDialogueData.sourceElement = sourceElement
    chunkedDialogueData.rawDialogueText = originalText

    if self.savedVars.interaction.subtitles.useChunkedDialogue then
        chunkedDialogueData.chunks = self:ProcessTextIntoChunks(textForTiming)
        chunkedDialogueData.displayChunks = self:ProcessTextIntoDisplayChunks(processedTextForDisplay)

        function CinematicCam:InitializeChunkedDisplay()
            if #chunkedDialogueData.chunks == 0 then
                return false
            end
            if chunkedDialogueData.sourceElement then
                chunkedDialogueData.sourceElement:SetHidden(true)
            end
            if not chunkedDialogueData.customControl then
                self:InitializeChunkedTextControl()
            end
            local control = chunkedDialogueData.customControl
            if not control then
                return false
            end
            self:ApplyChunkedTextPositioning()
            chunkedDialogueData.currentChunkIndex = 1
            chunkedDialogueData.isActive = true
            self:DisplayCurrentChunk()
            if #chunkedDialogueData.chunks >= 1 then
                self:ScheduleNextChunk()
            end

            return true
        end

        if #chunkedDialogueData.chunks >= 1 then
            self:StartDialogueChangeMonitoring()
            return self:InitializeChunkedDisplay()
        else
            chunkedDialogueData.chunks = { textForTiming }
            chunkedDialogueData.displayChunks = { processedTextForDisplay }
            self:StartDialogueChangeMonitoring()
            return self:InitializeCompleteTextDisplay()
        end
    end
end

function CinematicCam:ProcessTextIntoDisplayChunks(fullText)
    -- This follows the same chunking logic as ProcessTextIntoChunks
    -- but uses the text that already has the name prepended
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

function CinematicCam:UpdateChunkedTextFont()
    local control = chunkedDialogueData.customControl
    if control then
        self:ApplyFontToElement(control, self.savedVars.interface.customFontSize)
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

    local displayChunks = chunkedDialogueData.displayChunks or chunkedDialogueData.chunks
    local chunkText = displayChunks[chunkIndex]

    chunkText = string.gsub(chunkText, "§ABBREV§", ".")
    local fontString = self:BuildUserFontString()
    control:SetFont(fontString)

    self:UpdateChunkedTextVisibility()

    -- Set text and show
    control:SetText(chunkText)
    local interactionType = GetInteractionType()
    if interactionType == INTERACTION_DYE_STATION or interactionType == INTERACTION_CRAFT or interactionType == INTERACTION_NONE or interactionType == INTERACTION_LOCKPICK or interactionType == INTERATCTION_BOOK then
        control:SetText("")
    end
    control:SetHidden(false)
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

    -- Hide custom controls
    if chunkedDialogueData.customControl then
        chunkedDialogueData.customControl:SetHidden(true)
        chunkedDialogueData.customControl:SetText("")
    end

    -- Hide custom NPC name control
    if npcNameData.customNameControl then
        npcNameData.customNameControl:SetHidden(true)
        npcNameData.customNameControl:SetText("")
    end

    -- Restore original elements based on current settings
    if chunkedDialogueData.sourceElement then
        chunkedDialogueData.sourceElement:SetHidden(self.savedVars.interaction.subtitles.isHidden)
    end

    -- Restore NPC name element for default preset
    if npcNameData.currentPreset == "default" then
        local _, originalNameElement = self:GetNPCName()
        if originalNameElement then
            originalNameElement:SetHidden(false)
        end
    end

    -- Reset state
    chunkedDialogueData = {
        originalText = "",
        chunks = {},
        currentChunkIndex = 0,
        isActive = false,
        customControl = chunkedDialogueData.customControl, -- Preserve control
        displayTimer = nil,
        sourceElement = nil,
        rawDialogueText = ""
    }
    npcNameData.originalName = ""
    npcNameData.currentPreset = "default"
end

-- CHUNKED Timing
function CinematicCam:CalculateChunkDisplayTime(chunkText)
    local timingChunks = chunkedDialogueData.chunks
    local chunkIndex = chunkedDialogueData.currentChunkIndex

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
end

function CinematicCam:AdvanceToNextChunk()
    chunkedDialogueData.currentChunkIndex = chunkedDialogueData.currentChunkIndex + 1

    if chunkedDialogueData.currentChunkIndex <= #chunkedDialogueData.chunks then
        self:DisplayCurrentChunk()
        if self.savedVars.interaction.subtitles.useChunkedDialogue and #chunkedDialogueData.chunks > 1 then
            self:ScheduleNextChunk()
        end
    end
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

function CinematicCam:ShouldBlockInteraction(interactionType)
    return interactionTypeMap[interactionType] == true
end

function CinematicCam:checkhid()
    if self.savedVars.interaction.subtitles.isHidden or self.savedVars.interaction.layoutPreset == "cinematic" then
        if ZO_InteractWindowTargetAreaBodyText then
            ZO_InteractWindowTargetAreaBodyText:SetHidden(true)
        end
        if ZO_InteractWindow_GamepadContainerText then
            ZO_InteractWindow_GamepadContainerText:SetHidden(true)
        end
    end
end

function CinematicCam:OnGameCameraDeactivated()
    local interactionType = GetInteractionType()


    if self:ShouldBlockInteraction(interactionType) then
        SetInteractionUsingInteractCamera(false)
        isInteractionModified = true

        self:ApplyDialogueRepositioning()


        if self.savedVars.interaction.ui.hidePanelsESO then
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
            if not self.savedVars.letterbox.letterboxVisible then
                dialogLetterbox = true
                self:ShowLetterbox()
            else
                dialogLetterbox = false
            end
        end

        if self.savedVars.interaction.auto.autoHideUIDialogue then
            if self.savedVars.interface.UiElementsVisible then
                self:HideUI()
            end
        end
        self:ForceApplyFontsToDialogue()
        zo_callLater(function()
            CinematicCam:CheckInteractionStatus()
        end, 1000)
    end
end

function CinematicCam:OnGameCameraActivated()
    if isInteractionModified then
        local currentInteraction = GetInteractionType()
        if currentInteraction == INTERACTION_NONE then
            CinematicCam:OnInteractionEnd()
        end
    end
end

function CinematicCam:OnInteractionEnd()
    if isInteractionModified then
        isInteractionModified = false
        if self.savedVars.interaction.subtitles.useChunkedDialogue then
            self:CleanupChunkedDialogue()
        end

        -- Only hide letterbox if we auto-showed it
        if dialogLetterbox and self.savedVars.letterbox.letterboxVisible then
            self:HideLetterbox()
        end

        -- Reset tracking flags
        dialogLetterbox = false
    end
end

---=============================================================================
-- Hide Questing Dialoge Panels
--=============================================================================
-- Need to hide this: "ZO_KeybindStripButtonTemplate1-6"
--ZO_KeybindStripControl
--ZO_KeybindStripControlCenterParent
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
    local fontData = fontBook[self.savedVars.interface.selectedFont]
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
    local finalFontString = self:ParseFontPath(fontPath, actualSize)
    if finalFontString then
        element:SetFont(finalFontString)
    end
end

function CinematicCam:ApplyFontsToUI()
    local fontSize = self.savedVars.interface.customFontSize
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
    local finalSize = math.floor(fontSize * fontScale)

    if selectedFont == "ESO_Standard" then
        return "EsoUI/Common/Fonts/FTN57.slug|" .. finalSize .. "|soft-shadow-thick"
    elseif selectedFont == "ESO_Bold" then
        return "EsoUI/Common/Fonts/FTN57.slug|" .. finalSize .. "|thick-outline"
    elseif selectedFont == "Handwritten" then
        return "EsoUI/Common/Fonts/ProseAntiquePSMT.slug|" .. finalSize .. "|soft-shadow-thick"
    end
end

function CinematicCam:OnFontChanged()
    self:UpdateChunkedTextFont()
    self:ApplyFontsToUI()

    local interactionType = GetInteractionType()
    if interactionType ~= INTERACTION_NONE then
        self:ApplyFontsToUI()
    end
end

-- Repositioning preset system
local repositionPresets = {
    ["default"] = {
        name = "Default ESO Layout",
        applyFunction = function(self)
            self:ApplyDefaultPosition()
        end
    },
    ["cinematic"] = {
        name = "Cinematic",
        applyFunction = function(self)
            self:ApplyCinematicPreset()
        end
    },
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
function CinematicCam:ApplyCinematicPreset()
    ZO_InteractWindow_GamepadContainerText:SetHidden(true)
    if npcTextContainer then
        local originalWidth, originalHeight = npcTextContainer:GetDimensions()
        npcTextContainer:SetWidth(originalWidth)
        npcTextContainer:SetHeight(originalHeight + 100)
    end
    self:ApplySubtitlePosition()
end

function CinematicCam:ApplySubtitlePosition()
    local targetX, targetY = self:ConvertToScreenCoordinates(
        self.savedVars.interaction.subtitles.posX or 0.5,
        self.savedVars.interaction.subtitles.posY or 0.7
    )

    if npcTextContainer then
        npcTextContainer:ClearAnchors()
        npcTextContainer:SetAnchor(CENTER, GuiRoot, CENTER, targetX, targetY)
    end

    -- Apply to custom chunked dialogue control
    if chunkedDialogueData.customControl then
        chunkedDialogueData.customControl:ClearAnchors()
        chunkedDialogueData.customControl:SetAnchor(CENTER, GuiRoot, CENTER, targetX, targetY)
    end
end

function CinematicCam:ApplyChunkedTextPositioning()
    local control = chunkedDialogueData.customControl
    if not control then return end

    local preset = self.savedVars.interaction.layoutPreset

    if preset == "cinematic" then
        -- Use the same positioning logic as native subtitles
        local targetX, targetY = self:ConvertToScreenCoordinates(
            self.savedVars.interaction.subtitles.posX or 0.5,
            self.savedVars.interaction.subtitles.posY or 0.7
        )

        control:ClearAnchors()
        control:SetAnchor(CENTER, GuiRoot, CENTER, targetX, targetY)
        control:SetDimensions(2700, 200)
    else
        -- Default positioning for non-cinematic presets
        control:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, -50, 100)
        control:SetDimensions(683, 550)
    end
end

function CinematicCam:OnSubtitlePositionChanged(newX, newY)
    -- Update saved variables
    if newX then
        self.savedVars.interaction.subtitles.posX = newX
    end
    if newY then
        self.savedVars.interaction.subtitles.posY = newY
    end

    -- Immediate application if dialogue is active
    local interactionType = GetInteractionType()
    if interactionType ~= INTERACTION_NONE then
        self:ApplySubtitlePosition()
        -- Also update chunked dialogue positioning if active
        if chunkedDialogueData.isActive then
            self:ApplyChunkedTextPositioning()
        end
    end
end

function CinematicCam:ApplyDefaultPosition()
    ZO_InteractWindow_GamepadContainerText:SetHidden(false)
    zo_callLater(function()
        local rootWindow = _G["ZO_InteractWindow_Gamepad"]
        if rootWindow then
            local screenWidth, screenHeight = GuiRoot:GetDimensions()

            -- Calculate positions
            local centerX = screenWidth * self.savedVars.interface.dialogueHorizontalOffset
            local centerY = 0
            if self.savedVars.interface.dialogueVerticalOffset then
                centerY = (self.savedVars.interface.dialogueVerticalOffset - 0.5) * screenHeight * 0.8
            end

            -- Coordinate with letterbox if active
            if self.savedVars.letterbox.letterboxVisible then
                centerY = centerY + (self.savedVars.letterbox.size * 0.3)
            end

            -- Move root window
            rootWindow:ClearAnchors()
            rootWindow:SetAnchor(CENTER, GuiRoot, CENTER, centerX, 0)
            rootWindow:SetWidth(683)
            rootWindow:SetHeight(2000)

            -- Move the player options elements with same offset
            local playerOptionsElements = {
                "ZO_InteractWindow_GamepadContainerInteract",
                "ZO_InteractWindow_GamepadContainerInteractList",
                "ZO_InteractWindow_GamepadContainerInteractListScroll",
                "ZO_InteractWindow_GamepadContainer",
                "ZO_InteractWindow_GamepadTitle"
            }

            for _, elementName in ipairs(playerOptionsElements) do
                local element = _G[elementName]
                if element then
                    element:ClearAnchors()
                    element:SetAnchor(CENTER, GuiRoot, CENTER, centerX, centerY)
                end
            end
        end
    end)
end

function CinematicCam:ApplyDialogueRepositioning()
    local preset = self.savedVars.interaction.layoutPreset
    if preset and preset.applyFunction then
        preset.applyFunction(self)
    end
end

function CinematicCam:OnDialoguelayoutPresetChanged(newPreset)
    if chunkedDialogueData.isActive and chunkedDialogueData.customControl then
        self:ApplyChunkedTextPositioning()
    end
end

function CinematicCam:RegisterFontEvents()
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_Font", EVENT_CHATTER_BEGIN, function()
        self:ApplyFontsToUI()
    end)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_Font", EVENT_CONVERSATION_UPDATED, function()
        zo_callLater(function()
            self:ApplyFontsToUI()
        end, 20)
    end)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_Font", EVENT_QUEST_COMPLETE_DIALOG, function()
        self:ApplyFontsToUI()
    end)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_Font", EVENT_INTERACTION_UPDATED, function()
        self:ApplyFontsToUI()
    end)

    -- Add more specific events
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_Font", EVENT_SHOW_BOOK, function()
        self:ApplyFontsToUI()
    end)
end

function CinematicCam:ForceApplyFontsToDialogue()
    local dialogueElements = {
        "ZO_InteractWindowTargetAreaBodyText",
        "ZO_InteractWindow_GamepadContainerText",
        "ZO_InteractWindowTargetAreaTitle",
        "ZO_InteractWindow_GamepadTitle",
        "ZO_InteractWindowPlayerAreaOptions",
        "ZO_InteractWindowPlayerAreaHighlight"
    }

    for _, elementName in ipairs(dialogueElements) do
        local element = _G[elementName]
        if element then
            self:ApplyFontToElement(element, self.savedVars.interface.customFontSize)
        end
    end
end

---=============================================================================
-- Initialize
--=============================================================================
local function Initialize()
    CinematicCam:InitSavedVars()
    CinematicCam:ApplyFontsToUI()

    CinematicCam:InitializeChunkedDialogueSystem()
    CinematicCam:InitializeChunkedTextControl()

    CinematicCam:RegisterFontEvents()

    CinematicCam:InitializeLetterbox()
    CinematicCam:InitializeUI()

    zo_callLater(function()
        CinematicCam:InitializePreviewSystem()
    end, 200)

    -- Register slash commands
    SLASH_COMMANDS["/ccui"] = function()
        CinematicCam:ToggleUI()
    end

    SLASH_COMMANDS["/ccbars"] = function()
        CinematicCam:ToggleLetterbox()
    end

    CinematicCam:InitializeInteractionSettings()

    zo_callLater(function()
        CinematicCam:CreateSettingsMenu()
        CinematicCam:RegisterSceneCallbacks()
    end, 100)

    CinematicCam:checkhid()
end
function CinematicCam:InitSavedVars()
    CinematicCam.savedVars = ZO_SavedVars:NewAccountWide("CinematicCam2SavedVars", 2, nil, defaults)
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
            end, 2)
        end
    end
end

function CinematicCam:InitializeChunkedTextControl()
    local control = _G["CinematicCam_ChunkedText"] -- XML element

    if not control then
        control = CreateControl("CinematicCam_ChunkedDialogue", GuiRoot, CT_LABEL)

        if not control then
            return nil
        end
    end

    -- visibility settings
    control:SetColor(1, 1, 1, 1)
    if self.savedVars.interaction.subtitles.isHidden == true then
        control:SetAlpha(0)
    elseif self.savedVars.interaction.subtitles.isHidden == false then
        control:SetAlpha(1.0)
    end
    control:SetDrawLayer(DL_OVERLAY)
    control:SetDrawLevel(6)

    -- Text properties
    control:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    control:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    control:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    -- DIRECT FONT SETTING
    local fontString = self:BuildUserFontString()
    control:SetFont(fontString)

    -- Start hidden
    control:SetHidden(false)
    control:SetText("")

    -- Store reference
    chunkedDialogueData.customControl = control
    return control
end

function CinematicCam:InitializeLetterbox()
    if CinematicCam.savedVars.letterbox.letterboxVisible then
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
    else
        CinematicCam_Container:SetHidden(false)
        CinematicCam_LetterboxTop:SetHidden(true)
        CinematicCam_LetterboxBottom:SetHidden(true)
    end
end

function CinematicCam:InitializeUI()
    if not CinematicCam.savedVars.interface.UiElementsVisible then
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
end

local function OnPlayerActivated(eventCode)
    CinematicCam.savedVars.camEnabled = true
    zo_callLater(function()
        CinematicCam.savedVars.camEnabled = false
        CinematicCam:ShowUI()
    end, 100)
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

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_MOUNTED_STATE_CHANGED, function(eventCode, mounted)
    if mounted then
        CinematicCam:OnMountUp()
    else
        CinematicCam:OnMountDown()
    end
end)


---=============================================================================
-- Debug
--=============================================================================
function CinematicCam:DebugPrint()
    if self.savedVars and self.savedVars.showNotifications then
        d(message)
    end
end
