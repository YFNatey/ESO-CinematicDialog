--TODO make a function to parse the npc dialogue AND the player options interation before processing to modify the should show 3rd perosn and if you want to hide the playher options
-- Example NPC dialogue starting with "<" forceThirdPersonDialogue = False
-- Example Player option starting with "Store" playeroptions hidden = false
-- Issues Multiple data structures for hiding and tracking player options state
-- Likely race conditions when determining whether to hide player options

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
CinematicCam.globalCount = 0
local interactionTypeMap = {}

-- State tracking
CinematicCam.isInteractionModified = false -- overriden default cam
local dialogLetterbox = false

-- Handles the logic when the default interaction camera is deactivated.
-- Applies UI changes, letterbox, and font updates based on user settings and interaction type.
-- Modified OnGameCameraDeactivated - just show/hide the background based on setting
function CinematicCam:OnGameCameraDeactivated()
    d(GetUnitName("interact")) -- Target unit name

    d(GetUnitType("interact")) -- Unit type classification

    -- Interaction context
    d(GetInteractionType()) -- Already using this

    local interactionType = GetInteractionType()
    if self:ShouldBlockInteraction(interactionType) then
        SetInteractionUsingInteractCamera(false)
        CinematicCam.isInteractionModified = true


        self:ForceApplyFontsToDialogue()

        -- Reposition UI elemnents
        if self.savedVars.interaction.layoutPreset == "default" then
            self:ApplyDefaultPosition()
        elseif self.savedVars.interaction.layoutPreset == "cinematic" then
            self:ApplyCinematicPreset()

            --Intercept dialogue and monitor it
            d(CinematicCam.globalCount .. ". intercepting here")

            zo_callLater(function()
                self:InterceptDialogueForChunking()
            end)
        end

        -- Hide UI Panels according to user preferences
        if self.savedVars.interaction.ui.hidePanelsESO then
            self:HideDialoguePanels()
        end

        -- Hide Dialogue Text according to user preferences
        if ZO_InteractWindowTargetAreaBodyText then
            ZO_InteractWindowTargetAreaBodyText:SetHidden(self.savedVars.interaction.subtitles.isHidden)
        end
        if ZO_InteractWindow_GamepadContainerText then
            ZO_InteractWindow_GamepadContainerText:SetHidden(self.savedVars.interaction.subtitles.isHidden)
        end

        -- Player options background
        if self.savedVars.interface.usePlayerOptionsBackground then
            self:ShowPlayerOptionsBackground()
        end
        -- Letterbox handling
        if self:AutoShowLetterbox(interactionType) then
            if not self.savedVars.letterbox.letterboxVisible then
                dialogLetterbox = true
                self:ShowLetterbox()
            else
                dialogLetterbox = false
            end
        end


        zo_callLater(function()
            CinematicCam:CheckInteractionStatus()
        end, 1000)
    end
end

function CinematicCam:OnGameCameraActivated()
    if CinematicCam.isInteractionModified then
        local currentInteraction = GetInteractionType()
        if currentInteraction == INTERACTION_NONE then
            CinematicCam:OnInteractionEnd()
        end
    end
end

function CinematicCam:OnInteractionEnd()
    if CinematicCam.isInteractionModified then
        CinematicCam.isInteractionModified = false

        -- Hide player options background when dialogue ends
        self:HidePlayerOptionsBackground()

        if self.savedVars.interaction.subtitles.useChunkedDialogue then
            self:CleanupChunkedDialogue()
        end

        -- Hide letterbox if was visible
        if dialogLetterbox and self.savedVars.letterbox.letterboxVisible then
            self:HideLetterbox()
        end

        -- Reset tracking flags
        dialogLetterbox = false
    end
end

---=============================================================================
-- Initialize
--=============================================================================
local function Initialize()
    CinematicCam:InitSavedVars()
    CinematicCam:ApplyFontsToUI()

    CinematicCam:InitializeChunkedTextControl()
    CinematicCam:RegisterFontEvents()
    CinematicCam:InitializeLetterbox()
    CinematicCam:InitializeUI()
    CinematicCam:ConfigurePlayerOptionsBackground()
    CinematicCam:InitializePreviewSystem()
    CinematicCam:InitializeInteractionSettings()

    zo_callLater(function()
        CinematicCam:CreateSettingsMenu()
        CinematicCam:RegisterSceneCallbacks()
    end, 100)
    -- Register slash commands
    SLASH_COMMANDS["/ccui"] = function()
        CinematicCam:ToggleUI()
    end

    SLASH_COMMANDS["/ccbars"] = function()
        CinematicCam:ToggleLetterbox()
    end
    CinematicCam:checkhid()
end
function CinematicCam:InitSavedVars()
    CinematicCam.savedVars = ZO_SavedVars:NewAccountWide("CinematicCam2SavedVars", 2, nil, CinematicCam.defaults)
end

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

function CinematicCam:InitializePlayerOptionsBackground()
    -- Configure background if not already done
    if not CinematicCam.chunkedDialogueData.playerOptionsBackgroundControl then
        self:ConfigurePlayerOptionsBackground()
    end

    -- Position it initially
    self:PositionPlayerOptionsBackground()

    -- Start monitoring for player options changes
    self:StartPlayerOptionsMonitoring()
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
    zo_callLater(function()
        if CinematicCam.chunkedDialogueData.playerOptionsBackgroundControl then
            CinematicCam.chunkedDialogueData.playerOptionsBackgroundControl:SetHidden(true)
        end
    end, 100)
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

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_CHATTER_END, function()
    d("CHATTER_END triggered cleanup")
    CinematicCam:OnInteractionEnd()
end)

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_QUEST_COMPLETE_DIALOG_END, function()
    d("QUEST COMPLETE Dialog END triggered cleanup")
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

-- Font events
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

---=============================================================================
-- Debug
--=============================================================================
function CinematicCam:DebugPrint()
    if self.savedVars and self.savedVars.showNotifications then
        d(message)
    end
end

---=============================================================================
-- Utility Functions
--=============================================================================
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

function CinematicCam:CheckInteractionStatus()
    if CinematicCam.isInteractionModified then
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
-- Checks if the current interaction should be forced to 3rd person.
-- @param interactionType number: The current interaction type constant
-- @return boolean: True if the interaction should be blocked, false otherwise
function CinematicCam:ShouldBlockInteraction(interactionType)
    local unitName = GetUnitName("interact")
    if unitName == "Equipment Crafting Writs" or unitName == " Consumables Crafting Writs" then
        -- If user disabled third person for notes, allow ESO default
        if not self.savedVars.interaction.forceThirdPersonInteractiveNotes then
            self.savedVars.interaction.subtitles.isHidden = false
            CinematicCam:checkhid()
            return false -- Don't block - use ESO default camera
        end
        -- Otherwise continue with third person override
    end
    return interactionTypeMap[interactionType] == true
end

function CinematicCam:checkhid()
    if self.savedVars.interaction.subtitles.isHidden then
        if ZO_InteractWindowTargetAreaBodyText then
            ZO_InteractWindowTargetAreaBodyText:SetHidden(true)
        end
        if ZO_InteractWindow_GamepadContainerText then
            ZO_InteractWindow_GamepadContainerText:SetHidden(true)
        end
    end
    if self.savedVars.interaction.subtitles.isHidden == false then
        if ZO_InteractWindowTargetAreaBodyText then
            ZO_InteractWindowTargetAreaBodyText:SetHidden(false)
        end
    end
end

--
