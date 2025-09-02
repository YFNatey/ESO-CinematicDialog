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

-- Handles the logic when the default interaction camera is deactivated.
-- Applies UI changes, letterbox, and font updates based on user settings and interaction type.
-- Modified OnGameCameraDeactivated - just show/hide the background based on setting
function CinematicCam:OnGameCameraDeactivated()
    -- Hide Dialogue Text according to user preferences
    if ZO_InteractWindowTargetAreaBodyText then
        ZO_InteractWindowTargetAreaBodyText:SetHidden(self.savedVars.interaction.subtitles.isHidden)
    end
    if ZO_InteractWindow_GamepadContainerText then
        ZO_InteractWindow_GamepadContainerText:SetHidden(self.savedVars.interaction.subtitles.isHidden)
    end
    local interactionType = GetInteractionType()
    if self:ShouldBlockInteraction(interactionType) then
        SetInteractionUsingInteractCamera(false)
        CinematicCam.isInteractionModified = true


        self:ForceApplyFontsToDialogue()

        self:ApplyDialogueRepositioning()
        --Intercept dialogue and monitor it





        zo_callLater(function()
            self:InterceptDialogueForChunking()
        end)

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

CinematicCam.questEventTests = {
    -- Most promising events for preventing flash

    {
        event = EVENT_CONVERSATION_UPDATED,
        description = "Conversation updated - fires when dialogue changes",
        priority = 1,
        handler = function(eventCode, conversationBodyText, conversationOptionCount)
            d("CONVERSATION_UPDATED fired with text length: " .. string.len(conversationBodyText or ""))
            CinematicCam:PreemptivelyHidePlayerOptions("CONVERSATION_UPDATED", conversationBodyText)
        end
    },
    {
        event = EVENT_CHATTER_BEGIN,
        description = "Chatter begin - fires at start of any dialogue",
        priority = 2,
        handler = function(eventCode, optionCount)
            d("CHATTER_BEGIN fired with " .. (optionCount or 0) .. " options")
            CinematicCam:PreemptivelyHidePlayerOptions("CHATTER_BEGIN")
        end
    },
    {
        event = EVENT_CONFIRM_INTERACT,
        description = "Confirm interact - fires for quest acceptance dialogs",
        priority = 3,
        handler = function(eventCode, dialogTitle, dialogBody, acceptText, cancelText)
            d("CONFIRM_INTERACT fired: " .. (dialogTitle or "unknown"))
            CinematicCam:PreemptivelyHidePlayerOptions("CONFIRM_INTERACT", dialogBody)
        end
    }


}

-- Function to preemptively hide player options before flash occurs
function CinematicCam:PreemptivelyHidePlayerOptions(eventSource)
    if not self.savedVars.interaction.subtitles.hidePlayerOptionsUntilLastChunk then
        return
    end

    d("CinematicCam: Preemptively hiding dialogue for " .. eventSource)

    -- IMMEDIATELY hide original dialogue text to prevent flash
    if ZO_InteractWindowTargetAreaBodyText then
        ZO_InteractWindowTargetAreaBodyText:SetHidden(true)
    end
    if ZO_InteractWindow_GamepadContainerText then
        ZO_InteractWindow_GamepadContainerText:SetHidden(true)
    end

    -- Hide player options too if needed
    self:ForceHideAllPlayerOptions()


    self:InterceptDialogueForChunking()
end

-- Enable quest event testing
function CinematicCam:EnableQuestEventTesting()
    d("CinematicCam: Enabling quest event testing")

    for _, testEvent in ipairs(self.questEventTests) do
        EVENT_MANAGER:RegisterForEvent(
            ADDON_NAME .. "_QuestTest_" .. testEvent.event,
            testEvent.event,
            testEvent.handler
        )
        d("Registered: " .. testEvent.description)
    end

    self.questEventTestingEnabled = true
end

-- Disable quest event testing
function CinematicCam:DisableQuestEventTesting()
    d("CinematicCam: Disabling quest event testing")

    for _, testEvent in ipairs(self.questEventTests) do
        EVENT_MANAGER:UnregisterForEvent(
            ADDON_NAME .. "_QuestTest_" .. testEvent.event,
            testEvent.event
        )
    end

    self.questEventTestingEnabled = false
end

-- Test individual events
function CinematicCam:TestSpecificQuestEvent(eventName)
    for _, testEvent in ipairs(self.questEventTests) do
        if testEvent.event == eventName then
            d("Testing only: " .. testEvent.description)
            EVENT_MANAGER:RegisterForEvent(
                ADDON_NAME .. "_SingleTest",
                testEvent.event,
                testEvent.handler
            )
            return true
        end
    end

    d("Event not found: " .. tostring(eventName))
    return false
end

-- Enhanced dialogue change monitoring with quest event awareness
function CinematicCam:StartDialogueChangeMonitoringWithQuests()
    -- Start regular monitoring
    self:StartDialogueChangeMonitoring()

    -- Enable quest event testing if setting is enabled
    if self.savedVars.interaction.subtitles.hidePlayerOptionsUntilLastChunk then
        self:EnableQuestEventTesting()
    end
end

-- Cleanup quest event monitoring
function CinematicCam:CleanupQuestEventMonitoring()
    if self.questEventTestingEnabled then
        self:DisableQuestEventTesting()
    end
end

-- Add to your OnInteractionEnd function
function CinematicCam:OnInteractionEndWithQuests()
    -- Cleanup quest event monitoring
    self:CleanupQuestEventMonitoring()

    -- Rest of your existing cleanup
    self:OnInteractionEnd()
end

-- Debug commands for testing
SLASH_COMMANDS["/ccquesttest"] = function(args)
    if args == "on" then
        CinematicCam:EnableQuestEventTesting()
    elseif args == "off" then
        CinematicCam:DisableQuestEventTesting()
    elseif args == "status" then
        d("Quest event testing enabled: " .. tostring(CinematicCam.questEventTestingEnabled or false))
    else
        d("Usage: /ccquesttest [on|off|status]")
    end
end

-- Test specific events
SLASH_COMMANDS["/ccquestsingle"] = function(args)
    local eventName = "EVENT_" .. string.upper(args)
    CinematicCam:TestSpecificQuestEvent(_G[eventName])
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
    -- Initialize update system AFTER savedVars are loaded

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
