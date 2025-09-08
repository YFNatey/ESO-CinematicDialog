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
local CURRENT_VERSION = "3.16"

-- State tracking
CinematicCam.isInteractionModified = false -- overriden default cam
local dialogLetterbox = false
function CinematicCam:ApplyDialogueRepositioning()
    local preset = self.savedVars.interaction.layoutPreset
    if preset and preset.applyFunction then
        preset.applyFunction(self)
    end
end

CinematicCam.debugEventLog = {}
CinematicCam.debugSessionId = 0

function CinematicCam:LogDebugEvent(eventName, details)
    --[[local timestamp = GetTimeStamp()
    local logEntry = {
        session = self.debugSessionId,
        time = timestamp,
        event = eventName,
        details = details or {},
        playerOptionsState = self:GetCurrentPlayerOptionsState(),
        settingValue = self.savedVars.interaction.subtitles.hidePlayerOptionsUntilLastChunk,
        chunkData = {
            isActive = CinematicCam.chunkedDialogueData.isActive,
            currentChunk = CinematicCam.chunkedDialogueData.currentChunkIndex,
            totalChunks = CinematicCam.chunkedDialogueData.chunks and #CinematicCam.chunkedDialogueData.chunks or 0,
            playerOptionsHidden = CinematicCam.chunkedDialogueData.playerOptionsHidden
        }
    }

    table.insert(self.debugEventLog, logEntry)

    -- Print immediate debug info
    d(string.format("[DEBUG %d] %s | Setting=%s | State=%s | Chunk=%d/%d",
        self.debugSessionId,
        eventName,
        tostring(logEntry.settingValue),
        logEntry.playerOptionsState,
        logEntry.chunkData.currentChunk,
        logEntry.chunkData.totalChunks
    ))
    --]]
end

function CinematicCam:GetCurrentPlayerOptionsState()
    local elements = {
        "ZO_InteractWindowPlayerAreaOptions",
        "ZO_InteractWindow_GamepadContainerInteractList",
        "ZO_InteractWindow_GamepadContainerInteract",
        "ZO_InteractWindowPlayerAreaHighlight"
    }

    local visibilityStates = {}
    for _, elementName in ipairs(elements) do
        local element = _G[elementName]
        if element then
            visibilityStates[elementName] = not element:IsHidden()
        end
    end

    -- Return summary state
    local anyVisible = false
    for _, visible in pairs(visibilityStates) do
        if visible then
            anyVisible = true
            break
        end
    end

    return anyVisible and "VISIBLE" or "HIDDEN"
end

-- Handles the logic when the default interaction camera is deactivated.
-- Applies UI changes, letterbox, and font updates based on user settings and interaction type.
-- Modified OnGameCameraDeactivated - just show/hide the background based on setting
function CinematicCam:OnGameCameraDeactivated()
    -- Start new debug session
    self.debugSessionId = self.debugSessionId + 1
    self:LogDebugEvent("CAMERA_DEACTIVATED_START")

    -- COMPLETE state reset at the beginning - this is crucial
    if not CinematicCam.isInteractionModified then
        self:ResetChunkedDialogueState()
    end

    if ZO_InteractWindowTargetAreaBodyText then
        ZO_InteractWindowTargetAreaBodyText:SetHidden(self.savedVars.interaction.subtitles.isHidden)
    end
    if ZO_InteractWindow_GamepadContainerText then
        ZO_InteractWindow_GamepadContainerText:SetHidden(self.savedVars.interaction.subtitles.isHidden)
    end

    local interactionType = GetInteractionType()
    if self:ShouldBlockInteraction(interactionType) then
        self:LogDebugEvent("INTERACTION_BLOCKED", { interactionType = interactionType })

        CinematicCam:RegisterFontEvents()
        SetInteractionUsingInteractCamera(false)
        CinematicCam.isInteractionModified = true

        self:ApplyDialogueRepositioning()
        EVENT_MANAGER:UnregisterForEvent(ADDON_NAME .. "_ChatterBegin", EVENT_CHATTER_BEGIN)
        EVENT_MANAGER:UnregisterForEvent(ADDON_NAME .. "_ConversationUpdate", EVENT_CONVERSATION_UPDATED)
        EVENT_MANAGER:RegisterForEvent(
            ADDON_NAME .. "_ChatterBegin",
            EVENT_CHATTER_BEGIN,
            function(eventCode, conversationBodyText, conversationOptionCount)
                self:LogDebugEvent("CHATTER_BEGIN_FIRED", {
                    textLength = string.len(conversationBodyText or ""),
                    optionCount = conversationOptionCount
                })

                if self.savedVars.interaction.subtitles.hidePlayerOptionsUntilLastChunk == false then
                    self:LogDebugEvent("CHATTER_BEGIN_FORCE_SHOW")
                    CinematicCam:ForceShowAllPlayerOptions()
                else
                    self:LogDebugEvent("CHATTER_BEGIN_NO_ACTION")
                end

                if self.savedVars.interaction.layoutPreset == "cinematic" then
                    self:LogDebugEvent("CINEMATIC_MODE_HIDING_ORIGINAL")
                    if ZO_InteractWindowTargetAreaBodyText then
                        ZO_InteractWindowTargetAreaBodyText:SetHidden(true)
                    end
                    if ZO_InteractWindow_GamepadContainerText then
                        ZO_InteractWindow_GamepadContainerText:SetHidden(true)
                    end
                    self:LogDebugEvent("BEFORE_INTERCEPT", {
                        isActive = CinematicCam.chunkedDialogueData.isActive,
                        playerOptionsHidden = CinematicCam.chunkedDialogueData.playerOptionsHidden
                    })
                    self:InterceptDialogueForChunking()
                end
            end
        )

        EVENT_MANAGER:RegisterForEvent(
            ADDON_NAME .. "_ConversationUpdate",
            EVENT_CONVERSATION_UPDATED,
            function(eventCode, conversationBodyText, conversationOptionCount)
                self:LogDebugEvent("CONVERSATION_UPDATED_FIRED", {
                    textLength = string.len(conversationBodyText or ""),
                    optionCount = conversationOptionCount
                })

                if self.savedVars.interaction.subtitles.hidePlayerOptionsUntilLastChunk == false then
                    self:LogDebugEvent("CONVERSATION_UPDATE_FORCE_SHOW")
                    CinematicCam:ForceShowAllPlayerOptions()
                else
                    self:LogDebugEvent("CONVERSATION_UPDATE_NO_ACTION")
                end

                if self.savedVars.interaction.layoutPreset == "cinematic" then
                    self:LogDebugEvent("CONVERSATION_UPDATE_CINEMATIC")
                    if ZO_InteractWindowTargetAreaBodyText then
                        ZO_InteractWindowTargetAreaBodyText:SetHidden(true)
                    end
                    if ZO_InteractWindow_GamepadContainerText then
                        ZO_InteractWindow_GamepadContainerText:SetHidden(true)
                    end
                    self:LogDebugEvent("BEFORE_INTERCEPT", {
                        isActive = CinematicCam.chunkedDialogueData.isActive,
                        playerOptionsHidden = CinematicCam.chunkedDialogueData.playerOptionsHidden
                    })
                    self:InterceptDialogueForChunking()
                    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME .. "_ChatterBegin", EVENT_CHATTER_BEGIN)
                end
            end
        )

        -- Move NPC dialogue text off-screen for cinematic mode (instead of hiding)
        if self.savedVars.interaction.layoutPreset == "cinematic" then
            if ZO_InteractWindowTargetAreaBodyText then
                ZO_InteractWindowTargetAreaBodyText:ClearAnchors()
                ZO_InteractWindowTargetAreaBodyText:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, -5000, -5000)
            end
            if ZO_InteractWindow_GamepadContainerText then
                ZO_InteractWindow_GamepadContainerText:ClearAnchors()
                ZO_InteractWindow_GamepadContainerText:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, -5000, -5000)
            end
        end

        -- Hide UI Panels according to user preferences
        if self.savedVars.interaction.ui.hidePanelsESO then
            self:HideDialoguePanels()
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
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME .. "_ConversationUpdate", EVENT_CONVERSATION_UPDATED)
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME .. "_ChatterBegin", EVENT_CHATTER_BEGIN)

    if CinematicCam.isInteractionModified then
        CinematicCam.isInteractionModified = false

        -- Use the complete reset instead of partial cleanup
        self:ResetChunkedDialogueState()

        -- Hide player options background when dialogue ends
        self:HidePlayerOptionsBackground()

        -- Hide letterbox if was visible
        if self.savedVars.interaction.auto.autoLetterboxDialogue and self.savedVars.letterbox.letterboxVisible then
            self:HideLetterbox()
        end

        -- Reset tracking flags
        dialogLetterbox = false
    end
end

function CinematicCam:ForceShowAllPlayerOptions()
    local playerOptionElements = {
        "ZO_InteractWindowPlayerAreaOptions",
        "ZO_InteractWindow_GamepadContainerInteractList",
        "ZO_InteractWindow_GamepadContainerInteract",
        "ZO_InteractWindowPlayerAreaHighlight"
    }

    for _, elementName in ipairs(playerOptionElements) do
        local element = _G[elementName]
        if element then
            element:SetHidden(false)
        end
    end
end

function CinematicCam:ForceHideAllPlayerOptions()
    local playerOptionElements = {
        "ZO_InteractWindowPlayerAreaOptions",
        "ZO_InteractWindow_GamepadContainerInteractList",
        "ZO_InteractWindow_GamepadContainerInteract",
        "ZO_InteractWindowPlayerAreaHighlight"
    }

    for _, elementName in ipairs(playerOptionElements) do
        local element = _G[elementName]
        if element then
            element:SetHidden(true)
        end
    end
end

---=============================================================================
-- Initialize
--=============================================================================
local function Initialize()
    CinematicCam.savedVars = ZO_SavedVars:NewAccountWide("CinematicCam2SavedVars", 2, nil, CinematicCam.defaults)
    CinematicCam:InitializeChunkedTextControl()


    CinematicCam:InitializeLetterbox()
    CinematicCam:InitializeUI()
    CinematicCam:ConfigurePlayerOptionsBackground()
    CinematicCam:InitializePreviewSystem()
    CinematicCam:InitializeInteractionSettings()

    zo_callLater(function()
        CinematicCam:CreateSettingsMenu()
        CinematicCam:RegisterSceneCallbacks()
    end, 100)
    zo_callLater(function()
        CinematicCam:RegisterUIRefreshEvent()
    end, 1000)

    -- Initialize update system
    CinematicCam:InitializeUpdateSystem()

    -- Register slash commands
    SLASH_COMMANDS["/ccui"] = function()
        CinematicCam:ToggleUI()
    end

    SLASH_COMMANDS["/ccbars"] = function()
        CinematicCam:ToggleLetterbox()
    end
    CinematicCam:checkhid()
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
            for _, elementName in ipairs(CinematicCam.uiElements) do
                local element = _G[elementName]
                if element and not element:IsHidden() then
                    CinematicCam.uiElementsMap[elementName] = true
                    element:SetHidden(true)
                end
            end
            for elementName, shouldHide in pairs(CinematicCam.savedVars.hideUiElements) do
                if shouldHide then
                    local element = _G[elementName]
                    if element and not element:IsHidden() then
                        CinematicCam.uiElementsMap[elementName] = true
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
    CinematicCam:OnInteractionEnd()
end)

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_QUEST_COMPLETE_DIALOG, function()
    CinematicCam:ShowPlayerOptionsOnLastChunk()
end)
EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_QUEST_COMPLETE, function()
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

function CinematicCam:RegisterUIRefreshEvent()
    EVENT_MANAGER:RegisterForEvent("CinematicCam", EVENT_RETICLE_HIDDEN_UPDATE, function(eventCode, hidden)
        if not hidden then
            -- Reticle is now visible - player has exited menus/settings
            zo_callLater(function()
                -- Check each setting independently
                if self.savedVars.interface.hideCompass then
                    CinematicCam:ToggleCompass(true)
                end

                if self.savedVars.interface.hideActionBar then
                    CinematicCam:ToggleActionBar(true)
                end

                if self.savedVars.interface.hideReticle then
                    CinematicCam:ToggleReticle(true)
                end
            end, 200)
        end
    end)
end

-- Font events
function CinematicCam:RegisterFontEvents()
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_Font", EVENT_CHATTER_BEGIN, function()
        self:ApplyFontsToUI()
    end)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_Font", EVENT_CONVERSATION_UPDATED, function()
        self:ApplyFontsToUI()
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

function CinematicCam:CheckForUpdates()
    -- Don't show during initial loading screen
    if not GetWorldName() or GetWorldName() == "" then
        -- Wait for world to load, then check
        EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_UpdateCheck", EVENT_PLAYER_ACTIVATED, function()
            EVENT_MANAGER:UnregisterForEvent(ADDON_NAME .. "_UpdateCheck", EVENT_PLAYER_ACTIVATED)
            zo_callLater(function()
                self:ShowUpdateNotificationIfNeeded()
            end, 2000)
        end)
        return
    end

    self:ShowUpdateNotificationIfNeeded()
end

function CinematicCam:IsNewerVersion(current, last)
    if last == "0.0.0" then return true end

    local currentParts = {}
    local lastParts = {}

    for num in current:gmatch("(%d+)") do
        table.insert(currentParts, tonumber(num))
    end

    for num in last:gmatch("(%d+)") do
        table.insert(lastParts, tonumber(num))
    end

    -- Compare major, minor, patch
    for i = 1, math.max(#currentParts, #lastParts) do
        local currentNum = currentParts[i] or 0
        local lastNum = lastParts[i] or 0

        if currentNum > lastNum then
            return true
        elseif currentNum < lastNum then
            return false
        end
    end

    return false
end

function CinematicCam:ShowWelcomeMessage()
    -- Text is set in XML, just show the notification
    self:ShowUpdateNotificationUI()
end

function CinematicCam:ShowUpdateMessage()
    -- Text is set in XML, just show the notification
    self:ShowUpdateNotificationUI()
end

-- Fixed ShowUpdateNotificationUI with better debugging:
function CinematicCam:ShowUpdateNotificationUI()
    local notification = _G["CinematicCam_UpdateNotification"]

    if not notification then
        return
    end


    -- Make sure it's visible and starts at alpha 0 for fade in
    notification:SetHidden(false)
    notification:SetAlpha(0)

    -- Start fade in animation
    self:AnimateUpdateNotification(notification, true)

    -- Auto-hide after 5 seconds
    zo_callLater(function()
        self:HideUpdateNotification()
    end, 5000)
end

-- Fixed HideUpdateNotification:
function CinematicCam:HideUpdateNotification()
    local notification = _G["CinematicCam_UpdateNotification"]

    if not notification then
        return
    end



    -- Start fade out animation
    self:AnimateUpdateNotification(notification, false)

    -- Actually hide after fade completes
    zo_callLater(function()
        if notification then
            notification:SetHidden(true)
        end
    end, 350)
end

-- Fixed animation function:
function CinematicCam:AnimateUpdateNotification(control, fadeIn)
    if not control then
        return
    end



    local timeline = ANIMATION_MANAGER:CreateTimeline()
    local animation = timeline:InsertAnimation(ANIMATION_ALPHA, control)

    if fadeIn then
        animation:SetAlphaValues(0, 1)
        control:SetAlpha(0)
    else
        animation:SetAlphaValues(control:GetAlpha(), 0)
    end

    animation:SetDuration(300)
    animation:SetEasingFunction(ZO_EaseOutQuadratic)

    timeline:SetPlaybackType(ANIMATION_PLAYBACK_ONE_SHOT)
    timeline:PlayFromStart()
end

----
function CinematicCam:ShowUpdateNotificationIfNeeded()
    local lastSeenVersion = self.savedVars.lastSeenUpdateVersion or "0.0.0"
    local hasSeenWelcome = self.savedVars.hasSeenWelcomeMessage or false


    -- Compare versions
    if self:IsNewerVersion(CURRENT_VERSION, lastSeenVersion) then
        -- Determine if this is a first install or update
        local isFirstInstall = (lastSeenVersion == "0.0.0" and not hasSeenWelcome)

        if isFirstInstall then
            self:ShowWelcomeMessage()
        else
            self:ShowUpdateMessage()
        end

        -- Mark this version as seen
        self.savedVars.lastSeenUpdateVersion = CURRENT_VERSION
        self.savedVars.hasSeenWelcomeMessage = true
    else
        local notification = _G["CinematicCam_UpdateNotification"]


        notification:SetHidden(true)
    end
end

function CinematicCam:InitializeUpdateSystem()
    -- Extra safety check
    if not self.savedVars then
        zo_callLater(function()
            self:InitializeUpdateSystem()
        end, 1000)
        return
    end
    -- Check for updates after everything is loaded
    self:CheckForUpdates()
end
