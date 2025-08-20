--[[
===============================================================================
Cinematic Dialog - Elder Scrolls Online Addon
Author: YFNatey

DESCRIPTION:
    CinematicCam enhances the dialogue and interaction experience in ESO by
    providing cinematic camera controls, letterbox bars, subtitle customization,
    and advanced UI hiding features. It supports chunked dialogue display,
    font customization, and dynamic repositioning of UI elements for a more
    immersive experience.

NAVIGATING THE CODE:
    - Main logic and initialization: This file (CinematicCam.lua)
    - Saved variable defaults: See the 'defaults' table near the top
    - UI management: Functions prefixed with HideUI, ShowUI, ToggleUI
    - Letterbox controls: Functions prefixed with ShowLetterbox, HideLetterbox
    - Subtitle and dialogue positioning: See ApplySubtitlePosition, ApplyChunkedTextPositioning
    - Font customization: See ApplyFontsToUI, BuildUserFontString, RegisterFontEvents
    - Interaction and camera logic: See OnGameCameraDeactivated, OnGameCameraActivated
    - Event registration: At the bottom of this file
    - Settings menu and slash commands: See Initialize and CreateSettingsMenu

NOTES:
    - All saved variables are accessed via the nested 'self.savedVars' table.
    - For adding new UI elements to hide, update the 'uiElements' table.
    - For chunked dialogue logic, see the chunkedDialogueData and related functions.

===============================================================================
]]
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



-- NPC Name tables
CinematicCam.npcNameData = {
    originalName = "",
    customNameControl = nil,
    currentPreset = "default"
}
local namePresetDefaults = {

    npcNameColor = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 },
    npcNameFontSize = 42,
}

-- Chunked Dialog Table
CinematicCam.chunkedDialogueData = {
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
    -- Reapply current UI state
    if not self.savedVars.interface.UiElementsVisible then
        self:HideUI() -- This will restart monitoring
    end

    -- Reapply letterbox if user sets visible
    if self.savedVars.letterbox.letterboxVisible then
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

-- Show regular npc text using eso's ui
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
    self:StartUIMonitoring()
end

-- Show UI elements
function CinematicCam:ShowUI()
    if self.savedVars.interface.UiElementsVisible then
        return
    end
    self:StopUIMonitoring()
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
function CinematicCam:StartUIMonitoring()
    -- Stop any existing monitoring
    self:StopUIMonitoring()

    -- Start the monitoring loop
    local function monitorUIElements()
        -- Only continue monitoring if UI should be hidden
        if self.savedVars.interface.UiElementsVisible then
            self:StopUIMonitoring()
            return
        end

        -- Hide elements from the predefined list if they've become visible
        for _, elementName in ipairs(uiElements) do
            local element = _G[elementName]
            if element and not element:IsHidden() then
                element:SetHidden(true)
            end
        end

        -- Hide custom UI elements if they've become visible
        for elementName, shouldHide in pairs(self.savedVars.hideUiElements) do
            if shouldHide then
                local element = _G[elementName]
                if element and not element:IsHidden() then
                    element:SetHidden(true)
                end
            end
        end

        -- Schedule next check
        uiMonitoringTimer = zo_callLater(monitorUIElements, MONITORING_INTERVAL)
    end

    -- Start the first check
    uiMonitoringTimer = zo_callLater(monitorUIElements, MONITORING_INTERVAL)
end

-- Stop the periodic monitoring
function CinematicCam:StopUIMonitoring()
    if uiMonitoringTimer then
        zo_removeCallLater(uiMonitoringTimer)
        uiMonitoringTimer = nil
    end
end

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

---
-- Converts normalized (0-1) X and Y coordinates to actual screen coordinates.
-- Used for positioning UI elements relative to the screen size and user settings.
-- @param normalizedX number: X position as a value between 0 and 1
-- @param normalizedY number: Y position as a value between 0 and 1
-- @return number, number: The calculated screen X and Y positions
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
        -- Cinematic uses a fixed offset from center
        if self.savedVars.interaction.layoutPreset == "cinematic" then
            targetY = (normalizedY - 0.5) * screenHeight * 0.8
        else
            -- For default preset, match your existing logic
            targetY = (normalizedY * screenHeight) - (screenHeight / 2)
        end
    end

    return targetX, targetY
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
    if CinematicCam.npcNameData.customNameControl then
        return CinematicCam.npcNameData.customNameControl
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

    -- Apply font
    local fontSize = self.savedVars.npcNameFontSize or namePresetDefaults.npcNameFontSize
    self:ApplyFontToElement(control, fontSize)

    -- Set draw properties
    control:SetDrawLayer(DL_OVERLAY)
    control:SetDrawLevel(7)

    -- Start hidden
    control:SetHidden(true)
    control:SetText("")

    CinematicCam.npcNameData.customNameControl = control
    return control
end

function CinematicCam:RGBToHexString(r, g, b)
    -- Convert 0-1 float values to 0-255 integer values
    local red = math.floor(r * 255)
    local green = math.floor(g * 255)
    local blue = math.floor(b * 255)

    -- Convert to hex
    return string.format("%02X%02X%02X", red, green, blue)
end

function CinematicCam:ProcessNPCNameForPreset(dialogueText, npcName, preset)
    if not npcName or npcName == "" then
        return dialogueText
    end

    preset = preset or self.savedVars.npcNamePreset or "default"

    if preset == "prepended" then
        local color = self.savedVars.npcNameColor or namePresetDefaults.npcNameColor
        local hexColor = self:RGBToHexString(color.r, color.g, color.b)
        local coloredName = "|c" .. hexColor .. npcName .. ": |r"
        return coloredName .. dialogueText
    elseif preset == "above" then
        return dialogueText
    else
        -- Default
        return dialogueText
    end
end

function CinematicCam:PositionNPCNameControl(preset)
    local control = CinematicCam.npcNameData.customNameControl
    if not control then return end

    preset = preset or self.savedVars.npcNamePreset or "default"

    if preset == "above" then
        -- Position above the dialogue text
        local dialogueControl = CinematicCam.chunkedDialogueData.customControl
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
    CinematicCam.npcNameData.currentPreset = preset

    local npcName, originalElement = self:GetNPCName()

    if preset == "default" then
        -- Show original ESO name element
        if originalElement then
            originalElement:SetHidden(false)
            --originalElement:SetText(GetUnitName("player"))
        end
        -- Hide custom name control
        if CinematicCam.npcNameData.customNameControl then
            CinematicCam.npcNameData.customNameControl:SetHidden(true)
        end
    elseif preset == "prepended" then
        -- Hide original name element
        if originalElement then
            originalElement:SetHidden(true)
        end
        -- Hide custom name control (name will be in dialogue text)
        if CinematicCam.npcNameData.customNameControl then
            CinematicCam.npcNameData.customNameControl:SetHidden(true)
        end
    elseif preset == "above" then
        -- Hide original name element
        if originalElement then
            originalElement:SetHidden(true)
        end

        -- Show custom name control
        if not CinematicCam.npcNameData.customNameControl then
            self:CreateNPCNameControl()
        end

        local control = CinematicCam.npcNameData.customNameControl
        if control and npcName then
            control:SetText(npcName)
            self:PositionNPCNameControl(preset)
            control:SetHidden(false)
        end
    end
    -- Store the NPC name for use in dialogue processing
    CinematicCam.npcNameData.originalName = npcName or ""
end

function CinematicCam:UpdateNPCNameFont()
    local control = CinematicCam.npcNameData.customNameControl
    if control then
        local fontSize = self.savedVars.npcNameFontSize or namePresetDefaults.npcNameFontSize
        self:ApplyFontToElement(control, fontSize)
    end
end

-- Function to update NPC name color
function CinematicCam:UpdateNPCNameColor()
    local control = CinematicCam.npcNameData.customNameControl
    if control then
        local color = self.savedVars.npcNameColor or namePresetDefaults.npcNameColor
        control:SetColor(color.r, color.g, color.b, color.a)
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

---
-- Checks if the current interaction type should be blocked (forced to 3rd person).
-- @param interactionType number: The current interaction type constant
-- @return boolean: True if the interaction should be blocked, false otherwise
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

--
-- Handles the logic when the game camera is deactivated (e.g., entering dialogue).
-- Applies UI changes, letterbox, and font updates based on user settings and interaction type.
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
    if CinematicCam.chunkedDialogueData.customControl then
        CinematicCam.chunkedDialogueData.customControl:ClearAnchors()
        CinematicCam.chunkedDialogueData.customControl:SetAnchor(CENTER, GuiRoot, CENTER, targetX, targetY)
    end
end

function CinematicCam:ApplyChunkedTextPositioning()
    local control = CinematicCam.chunkedDialogueData.customControl
    local background = CinematicCam.chunkedDialogueData.backgroundControl

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

        -- Position background to match
        if background then
            background:ClearAnchors()
            background:SetAnchor(CENTER, GuiRoot, CENTER, targetX, targetY)
            background:SetDimensions(900, 150)
        end
    else
        -- Default positioning for non-cinematic presets
        control:ClearAnchors()
        control:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, -50, 100)
        control:SetDimensions(683, 550)

        -- Position background to match
        if background then
            background:ClearAnchors()
            background:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, -50, 100)
            background:SetDimensions(720, 580)
        end
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


    local interactionType = GetInteractionType()
    if interactionType ~= INTERACTION_NONE then
        self:ApplySubtitlePosition()
        if CinematicCam.chunkedDialogueData.isActive then
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
    if CinematicCam.chunkedDialogueData.isActive and CinematicCam.chunkedDialogueData.customControl then
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
    CinematicCam.savedVars = ZO_SavedVars:NewAccountWide("CinematicCam2SavedVars", 2, nil, CinematicCam.defaults)
end

function CinematicCam:InitializeChunkedDialogueSystem()
    local originalOnGameCameraDeactivated = self.OnGameCameraDeactivated
    self.OnGameCameraDeactivated = function(self)
        originalOnGameCameraDeactivated(self)

        if self.savedVars.interaction.layoutPreset == "cinematic" then
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

    self:ConfigureChunkedTextBackground()

    -- visibility settings
    control:SetColor(1, 1, 1, 1)
    if self.savedVars.interaction.subtitles.isHidden == true then
        control:SetAlpha(0)
    elseif self.savedVars.interaction.subtitles.isHidden == false then
        control:SetAlpha(1.0)
    end
    control:SetDrawLayer(DL_OVERLAY)
    control:SetDrawLevel(10)

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
    CinematicCam.chunkedDialogueData.customControl = control
    return control
end

function CinematicCam:InitializeLetterbox()
    -- Hide background on startup to prevent permanent display
    zo_callLater(function()
        self:HideChunkedTextBackground()
    end, 100)

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
