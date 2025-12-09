--[[
===============================================================================
Cinematic Dialog - Elder Scrolls Online Addon
Author: YFNatey

===============================================================================
]]
local ADDON_NAME = "CinematicCam"

CinematicCam = {}
CinematicCam.savedVars = nil
local interactionTypeMap = {}
local CURRENT_VERSION = "3.54"
CinematicCam.lastWeaponsState = nil
CinematicCam.isMounted = false
CinematicCam.currentZoneType = nil
-- State tracking
CinematicCam.isInteractionModified = false -- override default cam
CinematicCam.settingsUpdatedThisSession = false
CinematicCam.isMenuActive = false
CinematicCam.blockGamepad = false

-- Camera Renaming
local CAMERA_MODE = {
    -- SetGameCameraUIMode()
    FREE     = false,
    STATIC   = true,

    --SetInteractionUsingInteractCamera()
    INTERACT = true,
    GAMEPLAY = false,
}

function CinematicCam:ApplyDialogueRepositioning()
    local preset = self.savedVars.interaction.layoutPreset
    if preset and preset.applyFunction then
        preset.applyFunction(self)
    end
end

function CinematicCam:GamepadStickPoll()
    if not self.gamepadStickPoll or not self.gamepadStickPoll.isActive then
        self:StopGamepadStickPoll()
        return
    end

    local interactionType = GetInteractionType()
    if interactionType == INTERACTION_NONE then
        -- Interaction ended but event hasn't fired yet
        self:StopGamepadStickPoll()
        if self.isInteractionModified then
            self:OnInteractionEnd()
        end
        return
    end

    -- Only run polling during actual interactions
    if not CinematicCam.isInteractionModified then
        return
    end

    local leftTrigger = GetGamepadLeftTriggerMagnitude()
    local rightTrigger = GetGamepadRightTriggerMagnitude()
    local rightX = ZO_Gamepad_GetRightStickEasedX()
    local rightY = ZO_Gamepad_GetRightStickEasedY()
    local leftX = ZO_Gamepad_GetLeftStickEasedX()
    local leftY = ZO_Gamepad_GetLeftStickEasedY()

    local rightMagnitude = zo_sqrt(rightX * rightX + rightY * rightY)
    local leftMagnitude = zo_sqrt(leftX * leftX + leftY * leftY)
    local currentTime = GetGameTimeMilliseconds()


    --  disable camera UI mode (free camera)
    if rightMagnitude > 0 and rightTrigger == 0 then
        SetGameCameraUIMode(CAMERA_MODE.FREE)
    end
    if leftMagnitude > 0 and rightTrigger == 0 then
        SetGameCameraUIMode(CAMERA_MODE.FREE)
    end
    -- Left trigger to activate emote pad
    if leftTrigger > 0.3 and CinematicCam.savedVars.interaction.allowImmersionControls then
        SetGameCameraUIMode(CAMERA_MODE.FREE)

        -- Show emote pad if not visible
        if not self.emotePadVisible then
            self:ShowEmotePad()
        end

        -- Hide camera pad if visible
        if self.cameraPadVisible then
            self:HideCameraPad()
            self:ResetCameraHighlights()
        end

        if rightMagnitude > self.gamepadStickPoll.deadzone then
            -- Check emote cooldown
            local timeSinceLastEmote = currentTime - self.gamepadStickPoll.lastEmoteTime

            if timeSinceLastEmote >= self.gamepadStickPoll.emoteCooldown then
                if math.abs(rightX) > math.abs(rightY) then
                    if rightX > 0 then
                        -- Slot 2 (Right)
                        self:HighlightEmoteDirection("Right")
                        local emote = self:GetEmoteForSlot(2)
                        CinematicCam.savedVars.emoteWheel.lastUsedSlot = 2

                        if emote then
                            DoCommand(emote)
                            self.gamepadStickPoll.lastEmoteTime = currentTime
                        end
                    elseif rightX < 0 then
                        -- Slot 4 (Left)
                        self:HighlightEmoteDirection("Left")
                        local emote = self:GetEmoteForSlot(4)
                        CinematicCam.savedVars.emoteWheel.lastUsedSlot = 4

                        if emote then
                            DoCommand(emote)
                            self.gamepadStickPoll.lastEmoteTime = currentTime
                        end
                    end
                else
                    if rightY > 0 then
                        -- Slot 1 (Top)
                        self:HighlightEmoteDirection("Top")
                        local emote = self:GetEmoteForSlot(1)
                        CinematicCam.savedVars.emoteWheel.lastUsedSlot = 1
                        if emote then
                            DoCommand(emote)
                            self.gamepadStickPoll.lastEmoteTime = currentTime
                        end
                    elseif rightY < 0 then
                        -- Slot 3 (Bottom)
                        self:HighlightEmoteDirection("Bottom")
                        local emote = self:GetEmoteForSlot(3)
                        CinematicCam.savedVars.emoteWheel.lastUsedSlot = 3

                        if emote then
                            DoCommand(emote)
                            self.gamepadStickPoll.lastEmoteTime = currentTime
                        end
                    end
                end
            end
        else
            self:ResetEmoteHighlights()
        end
        -- Right trigger to activate camera pad
    elseif rightTrigger > 0.3 and CinematicCam.savedVars.interaction.allowCameraMovementDuringDialogue then
        -- Show camera pad if not visible
        if not self.cameraPadVisible then
            self:ShowCameraPad()
        end

        -- Hide emote pad if visible
        if self.emotePadVisible then
            self:HideEmotePad()
            self:ResetEmoteHighlights()
        end


        if rightMagnitude > 0 then
            -- Check cooldown before allowing camera switch
            local timeSinceLastSwitch = currentTime - self.gamepadStickPoll.lastCameraSwitch

            if math.abs(rightX) > math.abs(rightY) then
                -- Left/Right for camera UI mode toggle (with cooldown)
                if timeSinceLastSwitch >= self.gamepadStickPoll.cameraSwitchCooldown then
                    if rightX > 0 then
                        -- Right - Enable camera UI mode (lock camera)
                        self:HighlightCameraDirection("Right")
                        self.savedVars.useCinematicCamera = true
                        SetInteractionUsingInteractCamera(self.savedVars.useCinematicCamera)

                        self.gamepadStickPoll.lastCameraSwitch = currentTime
                    elseif rightX < 0 then
                        -- Left - Disable camera UI mode (free camera)
                        self:HighlightCameraDirection("Left")

                        self.savedVars.useCinematicCamera = false
                        SetInteractionUsingInteractCamera(self.savedVars.useCinematicCamera)
                        self.gamepadStickPoll.lastCameraSwitch = currentTime
                    end
                end
            else
                -- Up/Down for zoom
                if rightY > 0 then
                    self:HighlightCameraDirection("Top")
                    CameraZoomIn()
                    SetGameCameraUIMode(CAMERA_MODE.STATIC)
                elseif rightY < 0 then
                    self:HighlightCameraDirection("Bottom")
                    CameraZoomOut()
                    SetGameCameraUIMode(CAMERA_MODE.STATIC)
                end
            end
        else
            self:ResetCameraHighlights()
        end
    else
        -- Hide both pads when no trigger is pressed
        if self.emotePadVisible then
            self:HideEmotePad()
            self:ResetEmoteHighlights()
        end

        if self.cameraPadVisible then
            self:HideCameraPad()
            self:ResetCameraHighlights()
        end

        -- Right stick camera controls when no trigger pressed
        -- Only apply free camera if we're in free mode
        if rightMagnitude >= self.gamepadStickPoll.deadzone then
            if self.gamepadStickPoll.currentCameraMode == "free" then
                SetGameCameraUIMode(CAMERA_MODE.FREE)
            end
        end
    end
end

function CinematicCam:StopGamepadStickPoll()
    if not self.gamepadStickPoll then return end
    self.gamepadStickPoll.isActive = false


    self:HideEmoteWheel()
    self:HideEmotePad()
    self:HideCameraWheel()
    self:HideCameraPad()
end

-- Handles the visibility of the games default subtitles.
-- @param visibility string: the user settings. If using "cinematic" layout, the default subtitles need to be hidden on each new dialogue event
function CinematicCam:HandleDefaultSubtitles(visibility)
    -- Hide Subtitles with user settings
    local npcSubtitles = ZO_InteractWindowTargetAreaBodyText
    local npcName = ZO_InteractWindow_GamepadContainerText
    if visibility == "savedSettings" then
        if npcSubtitles then
            npcSubtitles:SetHidden(self.savedVars.interaction.subtitles.isHidden)
        end
        if npcName then
            npcName:SetHidden(self.savedVars.interaction.subtitles.isHidden)
        end
    end
    -- Hide
    if visibility == "cinematic" then
        if npcSubtitles then
            npcSubtitles:SetHidden(true)
        end
        if npcName then
            npcName:SetHidden(true)
        end
    end
end

---

-- Handles the logic when the player enters an interaction with an interactive object (NPCs, notes, quest starters, etc)
-- This function tracks the state of the interaction using dialogue events to watch for subtitle changes, update the chunked text system and apply the appropriate visibility settings.
function CinematicCam:OnInteractionStart()
    local useGameplayCam = false
    local interactionType = GetInteractionType()

    if interactionTypeMap[interactionType] == true then
        useGameplayCam = true
    end

    -- Handle the default subtitle visibility immediately
    CinematicCam:HandleDefaultSubtitles("savedSettings")

    -- Check if the current interaction should block the normal camera behavior.
    if useGameplayCam then
        SetGameCameraUIMode(CAMERA_MODE.FREE) -- Enable free camera movement

        CinematicCam.isInteractionModified = true
        if CinematicCam.savedVars.interaction.allowCameraMovementDuringDialogue or CinematicCam.savedVars.interaction.allowImmersionControls then
            if not self.gamepadStickPoll then
                self.gamepadStickPoll = {
                    isActive = true,
                    deadzone = 0.2,
                    moveThreshold = 0.5,
                    lastMove = GetGameTimeMilliseconds(),
                    lastCameraSwitch = 0,
                    cameraSwitchCooldown = 500, -- 500ms cooldown
                    lastEmoteTime = 0,
                    emoteCooldown = 2000,       -- 2000ms cooldown for emotes
                }
            end

            self.gamepadStickPoll.isActive = true
            -- Initialize and show emote wheel
            if CinematicCam.savedVars.interaction.allowImmersionControls then
                if not self.emoteWheelInitialized then
                    self.emoteWheelInitialized = true
                end
                if not self.cameraWheelInitialized then
                    self.cameraWheelInitialized = true
                end
                if self.savedVars.interaction.ButtonsVisible then
                    self:ShowEmoteWheel()
                end
            end
            if CinematicCam.savedVars.interaction.allowCameraMovementDuringDialogue then
                if self.savedVars.interaction.ButtonsVisible then
                    self:ShowCameraWheel()
                end
            end
            zo_callLater(function()
                local isVendor = self:IsVendorInteraction()
                CinematicCam.blockGamepad = isVendor

                if isVendor then
                    -- Hide the wheels for vendor interactions

                    self:HideEmoteWheel()
                    self:HideCameraWheel()
                    self:HideEmotePad()
                    self:HideCameraPad()
                elseif CinematicCam.isInteractionModified then
                    EVENT_MANAGER:RegisterForUpdate("CinematicCam_GamepadStickPoll", 50, function()
                        self:GamepadStickPoll()
                    end)
                end
            end) -- 100ms delay for UI to populate
        end
        if interactionType == INTERACTION_FURNITURE or interactionType == INTERACTION_STORE then
            self:StopGamepadStickPoll()
        end


        self:ApplyDialogueRepositioning()
        EVENT_MANAGER:UnregisterForEvent(ADDON_NAME .. "_ChatterBegin", EVENT_CHATTER_BEGIN)
        EVENT_MANAGER:UnregisterForEvent(ADDON_NAME .. "_ConversationUpdate", EVENT_CONVERSATION_UPDATED)
        EVENT_MANAGER:RegisterForEvent(
            ADDON_NAME .. "_ChatterBegin",
            EVENT_CHATTER_BEGIN,
            function()
                SetInteractionUsingInteractCamera(self.savedVars.useCinematicCamera)
                SetGameCameraUIMode(CAMERA_MODE.FREE)
                if self.savedVars.interaction.subtitles.hidePlayerOptionsUntilLastChunk == false then
                    CinematicCam:ShowPlayerResponse()
                end

                if self.savedVars.interaction.layoutPreset == "cinematic" then
                    CinematicCam:HandleDefaultSubtitles("cinematic")

                    self:InterceptDialogueForChunking("ChatterBegin")

                    if not self.savedVars.interaction.autoEmotes then
                        return
                    end
                    if self.savedVars.interaction.GreetingType == "none" then
                        return
                    end
                end
            end
        )

        EVENT_MANAGER:RegisterForEvent(
            ADDON_NAME .. "_ConversationUpdate",
            EVENT_CONVERSATION_UPDATED,
            function()
                SetInteractionUsingInteractCamera(self.savedVars.useCinematicCamera)
                SetGameCameraUIMode(CAMERA_MODE.FREE)
                if self.savedVars.interaction.subtitles.hidePlayerOptionsUntilLastChunk == false then
                    CinematicCam:ShowPlayerResponse()
                end

                if self.savedVars.interaction.layoutPreset == "cinematic" then
                    CinematicCam:HandleDefaultSubtitles("cinematic")


                    self:InterceptDialogueForChunking("ConversationUpdate")

                    -- automatic greeting when entering dialogue
                    if not self.savedVars.interaction.autoEmotes then return end
                    if self.savedVars.interaction.ChatType == "none" then return end

                    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME .. "_ChatterBegin", EVENT_CHATTER_BEGIN)
                end
            end
        )
        EVENT_MANAGER:RegisterForEvent(
            ADDON_NAME .. "_QuestOffered",
            EVENT_QUEST_OFFERED,
            function()
                SetInteractionUsingInteractCamera(self.savedVars.useCinematicCamera)
                SetGameCameraUIMode(CAMERA_MODE.FREE)
                if self.savedVars.interaction.subtitles.hidePlayerOptionsUntilLastChunk == false then
                    CinematicCam:ShowPlayerResponse()
                end

                if self.savedVars.interaction.layoutPreset == "cinematic" then
                    CinematicCam:HandleDefaultSubtitles("cinematic")


                    self:InterceptDialogueForChunking("QuestOffered")
                    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME .. "_ChatterBegin", EVENT_CHATTER_BEGIN)
                    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME .. "_ConversationUpdate", EVENT_CONVERSATION_UPDATED)
                end
            end
        )
        EVENT_MANAGER:RegisterForEvent(
            ADDON_NAME .. "_QuestCompleteDialog",
            EVENT_QUEST_COMPLETE_DIALOG,
            function()
                SetInteractionUsingInteractCamera(self.savedVars.useCinematicCamera)
                SetGameCameraUIMode(CAMERA_MODE.FREE)
                if self.savedVars.interaction.subtitles.hidePlayerOptionsUntilLastChunk == false then
                    CinematicCam:ShowPlayerResponse()
                end

                if self.savedVars.interaction.layoutPreset == "cinematic" then
                    CinematicCam:HandleDefaultSubtitles("cinematic")


                    self:InterceptDialogueForChunking("QuestCompleteDialog")
                    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME .. "_ChatterBegin", EVENT_CHATTER_BEGIN)
                    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME .. "_ConversationUpdate", EVENT_CONVERSATION_UPDATED)
                    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME .. "_QuestOffered", EVENT_QUEST_OFFERED)
                end
            end
        )
        -- Move NPC dialogue text off-screen for cinematic mode (instead of hiding) to prevent flashing
        if self.savedVars.interaction.layoutPreset == "cinematic" then
            CinematicCam:HandleDefaultSubtitles("cinematic")
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
        zo_callLater(function()
            if self:AutoShowLetterbox(interactionType) and not CinematicCam:CheckPlayerOptionsForVendorText() then
                if not self.savedVars.letterbox.letterboxVisible then
                    dialogLetterbox = true
                    self:ShowLetterbox()
                else
                    dialogLetterbox = false
                end
            end
        end, 200)
    end
end

function CinematicCam:OnInteractionEnd()
    EVENT_MANAGER:UnregisterForUpdate("CinematicCam_GamepadStickPoll")
    SetInteractionUsingInteractCamera(CAMERA_MODE.GAMEPLAY)

    CinematicCam.lastWeaponsState = nil

    self:InitializeUITweaks()
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME .. "_ConversationUpdate", EVENT_CONVERSATION_UPDATED)
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME .. "_ChatterBegin", EVENT_CHATTER_BEGIN)
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME .. "_QuestOffered", EVENT_QUEST_OFFERED)
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME .. "_QuestCompleteDialog", EVENT_QUEST_COMPLETE_DIALOG)
    if CinematicCam.isInteractionModified then
        CinematicCam.isInteractionModified = false

        -- Use the complete reset instead of partial cleanup
        self:ResetChunkedDialogueState()

        -- Hide player options background when dialogue ends
        self:HidePlayerOptionsBackground()

        -- Hide letterbox if was visible
        if self.savedVars.interaction.auto.autoLetterboxDialogue and not self.savedVars.letterbox.perma then
            self:HideLetterbox()
        end

        -- Reset tracking flags
        dialogLetterbox = false
    end
end

function CinematicCam:ShowPlayerResponse()
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

function CinematicCam:InitDefaults()
    CinematicCam.savedVars = ZO_SavedVars:NewAccountWide("CinematicCam2SavedVars", 2, nil, CinematicCam.defaults)
end

function CinematicCam:ResetEmoteWheel()
    if CinematicCam.savedVars.resetEmoteWheelNeeded then

    end
end

---=============================================================================
-- Initialize
--=============================================================================
local function Initialize()
    CinematicCam:InitDefaults()
    CinematicCam:InitializeLetterbox()
    CinematicCam:ConfigurePlayerOptionsBackground()
    CinematicCam:InitializeChunkedTextControl()
    CinematicCam:InitializePreviewSystem()
    CinematicCam:InitializeEmoteWheel()
    CinematicCam:RegisterFontEvents()
    CinematicCam:InitializeCameraWheel()
    CinematicCam:InitializeFilters()
    zo_callLater(function()
        CinematicCam:InitializeUI()
        CinematicCam:MigrateSettings()
        CinematicCam:InitializeInteractionSettings()
        CinematicCam:RegisterUIRefreshEvent()
        CinematicCam:CreateEmoteSettingsMenu()
        CinematicCam:InitializeUITweaks()
        CinematicCam:BuildHomeIdsLookup()
        CinematicCam:InitializeUpdateSystem()
    end, 1000)
    zo_callLater(function()
        CinematicCam:InitializeCustomPresets()
    end, 2000)

    -- Register slash commands
    SLASH_COMMANDS["/ccui"] = function()
        CinematicCam:ToggleUI()
    end

    SLASH_COMMANDS["/ccbars"] = function()
        CinematicCam:ToggleLetterbox()
    end
    SLASH_COMMANDS["/p1"] = function()
        CinematicCam:LoadFromPresetSlot(1)
        CinematicCam:ShowPresetNotificationUI("Home")
    end
    SLASH_COMMANDS["/p2"] = function()
        CinematicCam:LoadFromPresetSlot(2)
        CinematicCam:ShowPresetNotificationUI("Overland")
    end
    SLASH_COMMANDS["/p3"] = function()
        CinematicCam:LoadFromPresetSlot(3)
        CinematicCam:ShowPresetNotificationUI("Dungeon/Trials")
    end
end

function CinematicCam:InitializeUITweaks()
    if self.savedVars.interface.usingModTweaks then
        CinematicCam:UpdateCompassVisibility()
        CinematicCam:UpdateActionBarVisibility()
        CinematicCam:UpdateReticleVisibility()
    end
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
        [INTERACTION_DYE_STATION] = self.savedVars.interaction.forceThirdPersonDye,

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
    local color = self.savedVars.interaction.subtitles.textColor or { r = 0.9, g = 0.9, b = 0.8, a = 1.0 }
    control:SetColor(color.r, color.g, color.b, color.a)
    if self.savedVars.interaction.subtitles.isHidden == true then
        control:SetAlpha(0)
    elseif self.savedVars.interaction.subtitles.isHidden == false then
        control:SetAlpha(1.0)
    end


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
    self:ConfigureChunkedTextBackground()

    -- Set the correct active background
    self:SetActiveBackgroundControl()
    return control
end

function CinematicCam:InitializePlayerOptionsBackground()
    -- Configure background if not already done
    if not CinematicCam.chunkedDialogueData.playerOptionsBackgroundControl then
        self:ConfigurePlayerOptionsBackground()
    end

    -- Position it initially
    self:PositionPlayerOptionsBackground()

    -- Start monitor
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

        CinematicCam_LetterboxTop:SetHidden(false)

        CinematicCam_LetterboxBottom:SetAnchor(BOTTOMLEFT, GuiRoot, BOTTOMLEFT)
        CinematicCam_LetterboxBottom:SetAnchor(BOTTOMRIGHT, GuiRoot, BOTTOMRIGHT)
        CinematicCam_LetterboxBottom:SetHeight(CinematicCam.savedVars.letterbox.size)
        CinematicCam_LetterboxBottom:SetColor(0, 0, 0, CinematicCam.savedVars.letterboxOpacity)

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

local function OnAddOnLoaded(event, addonName)
    if addonName == ADDON_NAME then
        EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
        Initialize()
    end
end
EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)


---=============================================================================
-- Events
--=============================================================================
EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_GAME_CAMERA_DEACTIVATED, function()
    CinematicCam:OnInteractionStart()
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
        CinematicCam.isMounted = true
    else
        CinematicCam:OnMountDown()
        CinematicCam.isMounted = false
    end
end)

function CinematicCam:RegisterUIRefreshEvent()
    EVENT_MANAGER:RegisterForEvent("CinematicCam", EVENT_RETICLE_HIDDEN_UPDATE, function(eventCode, hidden)
        if not hidden then
            -- Reticle now visible, player has exited menus/settings
            zo_callLater(function()
                -- Check each setting independently
                SetInteractionUsingInteractCamera(CAMERA_MODE.GAMEPLAY)
                CinematicCam:InitializeUITweaks()

                if self.presetPending then
                    CinematicCam:InitializeChunkedTextControl()
                    CinematicCam:InitializeLetterbox()
                    CinematicCam:InitializeUI()
                    CinematicCam:ConfigurePlayerOptionsBackground()
                    CinematicCam:InitializePreviewSystem()
                    CinematicCam:InitializeInteractionSettings()
                    CinematicCam:ApplyPresetSettings()
                    CinematicCam:OnFontChanged()
                    self.presetPending = false
                end
                if self.pendingUIRefresh then
                    CinematicCam:UpdateUIVisibility()
                    self.pendingUIRefresh = false
                end
            end, 200)
        end
    end)
end

-- Combat state change for compass, reticle, and action bar
EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_Combat", EVENT_PLAYER_COMBAT_STATE, function(eventCode, inCombat)
    CinematicCam:InitializeUITweaks()
end)

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

EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_ChatterEnd_StopPoll", EVENT_CHATTER_END, function()
    if CinematicCam.gamepadStickPoll and CinematicCam.gamepadStickPoll.isActive then
        CinematicCam:StopGamepadStickPoll()
    end
end)
EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_HousingState", EVENT_HOUSING_EDITOR_MODE_CHANGED,
    function(eventCode, oldMode, newMode)
        -- newMode values:
        -- HOUSING_EDITOR_MODE_DISABLED = 0 (not in housing editor)
        -- HOUSING_EDITOR_MODE_BROWSE = 1 (browsing/placing items)
        -- HOUSING_EDITOR_MODE_PLACEMENT = 2 (actively placing an item)
        -- HOUSING_EDITOR_MODE_NODE_SELECTION = 3 (path nodes)

        if newMode ~= HOUSING_EDITOR_MODE_DISABLED then
            -- Entering housing editor - force show reticle
            --CinematicCam:ToggleReticle(false)
            CinematicCam.inHousingEditor = true
        else
            -- Exiting housing editor - restore reticle setting
            CinematicCam.inHousingEditor = false
            --CinematicCam:UpdateReticleVisibility()
        end
    end)


EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_ZoneChange", EVENT_PLAYER_ACTIVATED, function()
    zo_callLater(function()
        -- Show normal settings menu when the player travels to a new zone

        -- Only proceed if auto-swap is enabled
        if not CinematicCam.savedVars.autoSwapPresets then
            return
        end

        local newZoneType = nil
        local presetToLoad = nil

        -- Home
        local zoneId = GetZoneId(GetCurrentMapZoneIndex())
        local homeId = CinematicCam:CheckAndApplyHomePreset(zoneId)

        if homeId then
            newZoneType = "home"
            if CinematicCam.savedVars.homePresets and CinematicCam.savedVars.homePresets[homeId] then
                presetToLoad = CinematicCam.savedVars.homePresets[homeId]
            end
            -- Dungeon
        elseif IsUnitInDungeon("player") then
            newZoneType = "dungeon"
            presetToLoad = 3

            CinematicCam:LoadFromPresetSlot(3)
            -- Overland
        elseif not IsUnitInDungeon("player") and not CinematicCam.savedVars.isHome then
            newZoneType = "overland"
            presetToLoad = 2
        end

        -- Only apply preset if zone type changed
        if newZoneType and newZoneType ~= CinematicCam.currentZoneType then
            CinematicCam.currentZoneType = newZoneType

            if presetToLoad then
                CinematicCam:LoadFromPresetSlot(presetToLoad)
            end
        end
    end, 1000)
end)


---=============================================================================
-- Utility Functions
--=============================================================================
function CinematicCam:MigrateSettings()
    if self.savedVars.interaction.subtitles.posX ~= 0.5 then
        self.savedVars.interaction.subtitles.posX = 0.5
    end
    -- Migrate hideCompass from boolean to string
    if type(self.savedVars.interface.hideCompass) == "boolean" then
        self.savedVars.interface.hideCompass = self.savedVars.interface.hideCompass and "never" or "always"
    end

    -- Migrate hideReticle from boolean to string
    if type(self.savedVars.interface.hideReticle) == "boolean" then
        self.savedVars.interface.hideReticle = self.savedVars.interface.hideReticle and "never" or "always"
    end

    -- Migrate hideActionBar from boolean to string
    if type(self.savedVars.interface.hideActionBar) == "boolean" then
        self.savedVars.interface.hideActionBar = self.savedVars.interface.hideActionBar and "never" or "always"
    end

    -- Prevent settings errors from removed emote packs
    if not self.savedVars.emoteWheelVersion or self.savedVars.emoteWheelVersion < 1 then
        self.savedVars.emoteWheel = {
            slot1 = "friendly",
            slot2 = "confused",
            slot3 = "greeting",
            slot4 = "idle"
        }
        self.savedVars.emoteWheelVersion = 2
    end


    if self.savedVars.interaction.forceThirdPersonVendor == true then
        self.savedVars.interaction.forceThirdPersonVendor = false
    end

    if self.savedVars.interaction.forceThirdPersonBank == true then
        self.savedVars.interaction.forceThirdPersonBank = false
    end
    self:InitializeInteractionSettings()
end

function CinematicCam:CheckForUpdates()
    -- Don't show during initial loading screen
    if not GetWorldName() or GetWorldName() == "" then
        -- Wait for world to load, then check
        EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_UpdateCheck", EVENT_PLAYER_ACTIVATED, function()
            EVENT_MANAGER:UnregisterForEvent(ADDON_NAME .. "_UpdateCheck", EVENT_PLAYER_ACTIVATED)
            zo_callLater(function()
                self:DetermineNotificationType()
            end, 2000)
        end)
        return
    end

    self:DetermineNotificationType()
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

function CinematicCam:ShowUpdateNotificationUI()
    local notification = _G["CinematicCam_UpdateNotification"]
    if not notification then
        return
    end

    notification:SetHidden(false)
    notification:SetAlpha(0)

    -- Start fade in animation
    self:AnimateUpdateNotification(notification, true)

    -- Auto-hide after 5 seconds
    zo_callLater(function()
        self:HideUpdateNotification()
    end, 5000)
end

function CinematicCam:ShowWelcomeNotificationUI()
    if self.savedVars.hasSeenWelcomeMessage then
        return
    end
    local notification = _G["CinematicCam_UpdateNotification"]
    local notificationText = _G["CinematicCam_UpdateNotificationText"]
    if not notification then
        return
    end

    notification:SetHidden(false)
    notification:SetAlpha(0)
    notificationText:SetText(
        "|cFFD700Cinematic Dialog|r \n|cFFFFFFTry it out by talking to an NPC|r\n|cE0E0E0Check the settings menu for more customization options|r")

    -- Start fade in animation
    self:AnimateUpdateNotification(notification, true)

    -- Auto-hide after 5 seconds
    zo_callLater(function()
        self:HideUpdateNotification()
    end, 10000)
    self.savedVars.hasSeenWelcomeMessage = true
end

function CinematicCam:ShowPresetNotificationUI(slotName)
    local notification = _G["CinematicCam_UpdateNotification"]
    local notificationText = _G["CinematicCam_UpdateNotificationText"]
    if not notification then
        return
    end

    notification:SetHidden(false)
    notification:SetAlpha(0)
    notificationText:SetText("Cinematic Dialogue: " .. slotName)

    -- Start fade in animation
    self:AnimateUpdateNotification(notification, true)

    -- Auto-hide after 5 seconds
    zo_callLater(function()
        self:HideUpdateNotification()
    end, 6000)
end

function CinematicCam:HideUpdateNotification()
    local notification = _G["CinematicCam_UpdateNotification"]
    local notificationText = _G["CinematicCam_UpdateNotificationText"]
    if not notification then
        return
    end

    -- Start fade out animation
    self:AnimateUpdateNotification(notification, false)

    zo_callLater(function()
        if notification then
            notification:SetHidden(true)
        end
    end, 350)
    zo_callLater(function()
        notificationText:SetText("Cinematic Dialog Updated. Check settings to see whats new!")
    end, 400)
end

-- Animate notification
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

function CinematicCam:DetermineNotificationType()
    local lastSeenVersion = self.savedVars.lastSeenUpdateVersion or "0.0.0"
    local hasSeenWelcome = self.savedVars.hasSeenWelcomeMessage or false

    -- Compare versions
    if self:IsNewerVersion(CURRENT_VERSION, lastSeenVersion) then
        -- Determine if this is a first install or update
        local isFirstInstall = (lastSeenVersion == "0.0.0" and not hasSeenWelcome)

        if isFirstInstall then
            self:ShowWelcomeNotificationUI()
        else
            self:ShowUpdateNotificationUI()
            -- Set flag that user needs to reload to clear update indicators
            self.savedVars.hasReloadedSinceUpdate = false
        end

        -- Mark this version as seen
        self.savedVars.lastSeenUpdateVersion = CURRENT_VERSION
        self.savedVars.hasSeenWelcomeMessage = true
    else
        local notification = _G["CinematicCam_UpdateNotification"]
        if notification then
            notification:SetHidden(true)
        end
    end

    -- Always create the single settings menu
    CinematicCam:CreateSettingsMenu()
end

-- Add event handler to detect UI reload and clear update indicators
EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_UIReload", EVENT_PLAYER_ACTIVATED, function()
    -- Check if this is the first activation after an update
    if CinematicCam.savedVars and not CinematicCam.savedVars.hasReloadedSinceUpdate then
        -- User has reloaded UI, clear the update indicators
        zo_callLater(function()
            CinematicCam.savedVars.hasReloadedSinceUpdate = true
            -- Refresh the settings menu to remove green dots
            if LibAddonMenu2 then
                CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel", "CinematicCamOptions")
            end
        end, 1000)
    end
end)


function CinematicCam:InitializeUpdateSystem()
    if not self.savedVars then
        zo_callLater(function()
            self:InitializeUpdateSystem()
        end, 1000)
        return
    end
    -- Check for updates
    self:CheckForUpdates()
end

function CinematicCam:RegisterSceneHiddenCallbacks()
    local scenesToWatch = {
        "gamepad_store",
        "gamepad_housing_furniture_scene",
        "housingEditorHud",
        "hudui",
        "gamepadMainMenu",
    }

    for _, sceneName in ipairs(scenesToWatch) do
        local scene = SCENE_MANAGER:GetScene(sceneName)
        if scene then
            scene:RegisterCallback("StateChange", function(oldState, newState)
                if newState == SCENE_SHOWN then
                    self:OnTargetSceneShown(sceneName)
                elseif newState == SCENE_HIDDEN then
                    self:OnTargetSceneHidden(sceneName)
                end
            end)
        end
    end
end

function CinematicCam:OnTargetSceneShown(sceneName)
    if sceneName == "gamepad_store" then
        self:StopGamepadStickPoll()
    elseif sceneName == "gamepad_housing_furniture_scene" then
        self:StopGamepadStickPoll()
    elseif sceneName == "housingEditorHud" then
        self:StopGamepadStickPoll()
    elseif sceneName == "hudui" then
        if CinematicCam.isInteractionModified then
            SetGameCameraUIMode(CAMERA_MODE.FREE)
        end
    elseif sceneName == "gamepadMainMenu" then
        -- mark when menu is opened so StopGamepadStickPoll doesn't override
        CinematicCam.isMenuActive = true
        self:StopGamepadStickPoll()
    end
end

function CinematicCam:OnTargetSceneHidden(sceneName)
    if sceneName == "gamepad_store" then
        SetGameCameraUIMode(CAMERA_MODE.FREE)
    elseif sceneName == "gamepad_housing_furniture_scene" then
        SetGameCameraUIMode(CAMERA_MODE.FREE)
    elseif sceneName == "housingEditorHud" then
        SetGameCameraUIMode(CAMERA_MODE.FREE)
    elseif sceneName == "hudui" then
        if not CinematicCam.isInteractionModified then
            SetGameCameraUIMode(CAMERA_MODE.FREE)
        end
    elseif sceneName == "gamepadMainMenu" then
        -- Menu is closing - safe to reset
        CinematicCam.isMenuActive = false
        CinematicCam.isInteractionModified = false
        SetGameCameraUIMode(CAMERA_MODE.FREE)
    end
end

-- Individual scene handlers
function CinematicCam:OnStoreSceneShown()
    -- Stop freecam when store opens
    self:StopGamepadStickPoll()
end

function CinematicCam:OnHudUISceneShown()
    -- Only lock camera if we're in an interaction
    if CinematicCam.isInteractionModified then
        SetGameCameraUIMode(CAMERA_MODE.STATIC)
    end
end

function CinematicCam:OnHousingFurnitureSceneShown()
    -- Stop freecam when housing furniture browser opens
    self:StopGamepadStickPoll()
end

function CinematicCam:OnHousingEditorHudShown()
    -- Stop freecam when housing editor opens
    self:StopGamepadStickPoll()
end
