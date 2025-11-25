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
local CURRENT_VERSION = "3.34"
CinematicCam.lastWeaponsState = nil

CinematicCam.currentZoneType = nil

-- State tracking
CinematicCam.isInteractionModified = false -- override default cam
CinematicCam.settingsUpdatedThisSession = false


function CinematicCam:ApplyDialogueRepositioning()
    local preset = self.savedVars.interaction.layoutPreset
    if preset and preset.applyFunction then
        preset.applyFunction(self)
    end
end

function CinematicCam:GamepadStickPoll()
    if not self.gamepadStickPoll or not self.gamepadStickPoll.isActive then
        return
    end

    local leftTrigger = GetGamepadLeftTriggerMagnitude()
    local rightTrigger = GetGamepadRightTriggerMagnitude()
    local rightX = ZO_Gamepad_GetRightStickEasedX()
    local rightY = ZO_Gamepad_GetRightStickEasedY()

    local rightMagnitude = zo_sqrt(rightX * rightX + rightY * rightY)
    local currentTime = GetGameTimeMilliseconds()

    -- Left trigger to activate emote pad
    if leftTrigger > 0.3 then
        SetGameCameraUIMode(true)

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
                        if emote then
                            DoCommand(emote)
                            self.gamepadStickPoll.lastEmoteTime = currentTime
                        end
                    elseif rightX < 0 then
                        -- Slot 4 (Left)
                        self:HighlightEmoteDirection("Left")
                        local emote = self:GetEmoteForSlot(4)
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
                        if emote then
                            DoCommand(emote)
                            self.gamepadStickPoll.lastEmoteTime = currentTime
                        end
                    elseif rightY < 0 then
                        -- Slot 3 (Bottom)
                        self:HighlightEmoteDirection("Bottom")
                        local emote = self:GetEmoteForSlot(3)
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
    elseif rightTrigger > 0.3 then
        -- Show camera pad if not visible
        if not self.cameraPadVisible then
            self:ShowCameraPad()
        end

        -- Hide emote pad if visible
        if self.emotePadVisible then
            self:HideEmotePad()
            self:ResetEmoteHighlights()
        end

        if rightMagnitude > self.gamepadStickPoll.deadzone then
            -- Check cooldown before allowing camera switch
            local timeSinceLastSwitch = currentTime - self.gamepadStickPoll.lastCameraSwitch

            if math.abs(rightX) > math.abs(rightY) then
                -- Left/Right for camera mode switching (TOGGLE with cooldown)
                if timeSinceLastSwitch >= self.gamepadStickPoll.cameraSwitchCooldown then
                    if rightX > 0 and self.gamepadStickPoll.currentCameraMode ~= "free" then
                        -- Right: Switch to free game camera (Cinematic Cam)
                        self:HighlightCameraDirection("Right")
                        SetGameCameraUIMode(false)
                        SetInteractionUsingInteractCamera(false)
                        self.gamepadStickPoll.currentCameraMode = "free"
                        self.gamepadStickPoll.lastCameraSwitch = currentTime
                    elseif rightX < 0 and self.gamepadStickPoll.currentCameraMode ~= "eso" then
                        -- Left: Switch to ESO interact camera
                        self:HighlightCameraDirection("Left")
                        SetGameCameraUIMode(true)
                        SetInteractionUsingInteractCamera(true)
                        self.gamepadStickPoll.currentCameraMode = "eso"
                        self.gamepadStickPoll.lastCameraSwitch = currentTime
                    end
                end
            else
                -- Up/Down for zoom (no cooldown needed)
                if rightY > 0 then
                    self:HighlightCameraDirection("Top")
                    CameraZoomIn()
                elseif rightY < 0 then
                    self:HighlightCameraDirection("Bottom")
                    CameraZoomOut()
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
                SetGameCameraUIMode(false)
            end
        end
    end
end

function CinematicCam:StopGamepadStickPoll()
    if not self.gamepadStickPoll then return end
    self.gamepadStickPoll.isActive = false


    EVENT_MANAGER:UnregisterForUpdate("CinematicCam_GamepadStickPoll")
    self:HideEmoteWheel()
    self:HideEmotePad()
    self:HideCameraWheel()
    self:HideCameraPad()
end

-- Handles the logic when the default interaction camera is deactivated.
-- Applies UI changes, letterbox, and font updates based on user settings and interaction type.
function CinematicCam:OnGameCameraDeactivated()
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
        SetInteractionUsingInteractCamera(false)

        if CinematicCam.savedVars.interaction.allowCameraMovementDuringDialogue then
            if not self.gamepadStickPoll then
                self.gamepadStickPoll = {
                    isActive = true,
                    deadzone = 0.2,
                    moveThreshold = 0.5,
                    lastMove = GetGameTimeMilliseconds(),
                    lastCameraSwitch = 0,       -- Add this
                    cameraSwitchCooldown = 500, -- 500ms cooldown
                    lastEmoteTime = 0,          -- Add this
                    emoteCooldown = 2000,       -- 2000ms cooldown for emotes
                }
            end

            self.gamepadStickPoll.isActive = true
            -- Initialize and show emote wheel
            if not self.emoteWheelInitialized then
                self.emoteWheelInitialized = true
            end
            if not self.cameraWheelInitialized then
                self.cameraWheelInitialized = true
            end
            self:ShowEmoteWheel()
            self:ShowCameraWheel()

            EVENT_MANAGER:RegisterForUpdate("CinematicCam_GamepadStickPoll", 50, function()
                self:GamepadStickPoll()
            end)
        end
        if interactionType == INTERACTION_FURNITURE or interactionType == INTERACTION_STORE then
            self:StopGamepadStickPoll()
        end
        CinematicCam.isInteractionModified = true

        self:ApplyDialogueRepositioning()
        EVENT_MANAGER:UnregisterForEvent(ADDON_NAME .. "_ChatterBegin", EVENT_CHATTER_BEGIN)
        EVENT_MANAGER:UnregisterForEvent(ADDON_NAME .. "_ConversationUpdate", EVENT_CONVERSATION_UPDATED)
        EVENT_MANAGER:RegisterForEvent(
            ADDON_NAME .. "_ChatterBegin",
            EVENT_CHATTER_BEGIN,
            function()
                if self.savedVars.interaction.subtitles.hidePlayerOptionsUntilLastChunk == false then
                    CinematicCam:ForceShowAllPlayerOptions()
                end

                if self.savedVars.interaction.layoutPreset == "cinematic" then
                    if ZO_InteractWindowTargetAreaBodyText then
                        ZO_InteractWindowTargetAreaBodyText:SetHidden(true)
                    end
                    if ZO_InteractWindow_GamepadContainerText then
                        ZO_InteractWindow_GamepadContainerText:SetHidden(true)
                    end

                    self:InterceptDialogueForChunking()
                end
            end
        )

        EVENT_MANAGER:RegisterForEvent(
            ADDON_NAME .. "_ConversationUpdate",
            EVENT_CONVERSATION_UPDATED,
            function()
                if self.savedVars.interaction.subtitles.hidePlayerOptionsUntilLastChunk == false then
                    CinematicCam:ForceShowAllPlayerOptions()
                end

                if self.savedVars.interaction.layoutPreset == "cinematic" then
                    if ZO_InteractWindowTargetAreaBodyText then
                        ZO_InteractWindowTargetAreaBodyText:SetHidden(true)
                    end
                    if ZO_InteractWindow_GamepadContainerText then
                        ZO_InteractWindow_GamepadContainerText:SetHidden(true)
                    end

                    self:InterceptDialogueForChunking()
                    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME .. "_ChatterBegin", EVENT_CHATTER_BEGIN)
                end
            end
        )
        EVENT_MANAGER:RegisterForEvent(
            ADDON_NAME .. "_QuestOffered",
            EVENT_QUEST_OFFERED,
            function()
                if self.savedVars.interaction.subtitles.hidePlayerOptionsUntilLastChunk == false then
                    CinematicCam:ForceShowAllPlayerOptions()
                end

                if self.savedVars.interaction.layoutPreset == "cinematic" then
                    if ZO_InteractWindowTargetAreaBodyText then
                        ZO_InteractWindowTargetAreaBodyText:SetHidden(true)
                    end
                    if ZO_InteractWindow_GamepadContainerText then
                        ZO_InteractWindow_GamepadContainerText:SetHidden(true)
                    end

                    self:InterceptDialogueForChunking()
                    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME .. "_ChatterBegin", EVENT_CHATTER_BEGIN)
                    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME .. "_ConversationUpdate", EVENT_CONVERSATION_UPDATED)
                end
            end
        )
        EVENT_MANAGER:RegisterForEvent(
            ADDON_NAME .. "_QuestCompleteDialog",
            EVENT_QUEST_COMPLETE_DIALOG,
            function()
                if self.savedVars.interaction.subtitles.hidePlayerOptionsUntilLastChunk == false then
                    CinematicCam:ForceShowAllPlayerOptions()
                end

                if self.savedVars.interaction.layoutPreset == "cinematic" then
                    if ZO_InteractWindowTargetAreaBodyText then
                        ZO_InteractWindowTargetAreaBodyText:SetHidden(true)
                    end
                    if ZO_InteractWindow_GamepadContainerText then
                        ZO_InteractWindow_GamepadContainerText:SetHidden(true)
                    end

                    self:InterceptDialogueForChunking()
                    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME .. "_ChatterBegin", EVENT_CHATTER_BEGIN)
                    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME .. "_ConversationUpdate", EVENT_CONVERSATION_UPDATED)
                    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME .. "_QuestOffered", EVENT_QUEST_OFFERED)
                end
            end
        )
        -- Move NPC dialogue text off-screen for cinematic mode (instead of hiding) to prevent flashing
        if self.savedVars.interaction.layoutPreset == "cinematic" then
            if ZO_InteractWindowTargetAreaBodyText then
                ZO_InteractWindowTargetAreaBodyText:SetHidden(true)
            end
            if ZO_InteractWindow_GamepadContainerText then
                ZO_InteractWindow_GamepadContainerText:SetHidden(true)
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

function CinematicCam:OnGameCameraActivated()
    if CinematicCam.isInteractionModified then
        local currentInteraction = GetInteractionType()
        if currentInteraction == INTERACTION_NONE then
            CinematicCam:OnInteractionEnd()
        end
    end
    self:StopGamepadStickPoll()
end

function CinematicCam:OnInteractionEnd()
    CinematicCam.lastWeaponsState = nil
    self:StopGamepadStickPoll()

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

function CinematicCam:UpdateHorizontal()
    if self.savedVars.interaction.subtitles.posX ~= 0.5 then
        self.savedVars.interaction.subtitles.posX = 0.5
    end
end

function CinematicCam:MigrateSettings()
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
end

function CinematicCam:InitDefaults()
    CinematicCam.savedVars = ZO_SavedVars:NewAccountWide("CinematicCam2SavedVars", 2, nil, CinematicCam.defaults)
end

---=============================================================================
-- Initialize
--=============================================================================
local function Initialize()
    CinematicCam:InitDefaults()
    CinematicCam:InitializeLetterbox()
    CinematicCam:InitializeSepiaFilter()
    CinematicCam:ConfigurePlayerOptionsBackground()
    CinematicCam:InitializeChunkedTextControl()
    CinematicCam:InitializePreviewSystem()
    CinematicCam:InitializeEmoteWheel()
    CinematicCam:RegisterFontEvents()
    CinematicCam:InitializeCameraWheel()
    zo_callLater(function()
        CinematicCam:InitializeUI()
        CinematicCam:RegisterSceneCallbacks()
        CinematicCam:RegisterSceneHiddenCallbacks()
        CinematicCam:MigrateSettings()
        CinematicCam:InitializeInteractionSettings()
        CinematicCam:UpdateHorizontal()
        CinematicCam:RegisterUIRefreshEvent()

        --CinematicCam:UpdateActionBarVisibility()
        --CinematicCam:UpdateCompassVisibility()
        --CinematicCam:UpdateReticleVisibility()
        CinematicCam:InitializeUITweaks()

        CinematicCam:BuildHomeIdsLookup()
        CinematicCam:checkhid()
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
            -- Reticle now visible, player has exited menus/settings
            zo_callLater(function()
                -- Check each setting independently

                if self.presetPending then
                    CinematicCam:InitializeChunkedTextControl()

                    CinematicCam:RegisterSceneCallbacks()
                    CinematicCam:InitializeLetterbox()
                    CinematicCam:InitializeUI()
                    CinematicCam:ConfigurePlayerOptionsBackground()
                    CinematicCam:InitializePreviewSystem()
                    CinematicCam:InitializeInteractionSettings()
                    self:ApplyPresetSettings()
                    self:OnFontChanged()
                    CinematicCam:checkhid()
                    self.presetPending = false
                end
                if self.vanillaPending then
                    self.vanillaPending = false
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

----
function CinematicCam:ShowUpdateNotificationIfNeeded()
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
            CinematicCam:ShowUpdatedSettingsMenu()
            CinematicCam.settingsUpdatedThisSession = true
        end

        -- Mark this version as seen
        self.savedVars.lastSeenUpdateVersion = CURRENT_VERSION
        self.savedVars.hasSeenWelcomeMessage = true
    else
        local notification = _G["CinematicCam_UpdateNotification"]


        notification:SetHidden(true)
        CinematicCam:CreateSettingsMenu()
    end
end

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

-- Initialize the emote wheel system
function CinematicCam:InitializeEmoteWheel()
    self.emoteWheelVisible = false
    self.emotePadVisible = false

    -- Set platform-specific trigger icon
    self:SetPlatformTriggerIcon()

    -- Start hidden
    self:HideEmoteWheel()
    self:HideEmotePad()
end

-- Set the correct trigger icon based on platform
-- Set the correct trigger icon based on platform
function CinematicCam:SetPlatformTriggerIcon()
    local xboxLT = _G["CinematicCam_XboxLT"]
    local ps4LT = _G["CinematicCam_PS4LT"]
    local xboxLS_Slide = _G["CinematicCam_XboxLS_Slide"]
    local xboxLS_Scroll = _G["CinematicCam_XboxLS_Scroll"]
    local ps4LS = _G["CinematicCam_PS4LS"]

    if not xboxLT or not ps4LT then
        return
    end

    local worldName = GetWorldName()

    -- Default to Xbox, switch to PS if on PlayStation
    if worldName == "PS4live" or worldName == "PS4live-eu" or worldName == "NA Megaserver" then
        -- Show PlayStation icons
        xboxLT:SetTexture("/esoui/art/buttons/gamepad/ps5/nav_ps5_l2.dds")


        if xboxLS_Slide then xboxLS_Slide:SetTexture("/esoui/art/buttons/gamepad/ps5/nav_ps5_ls_scroll.dds") end
        if xboxLS_Scroll then xboxLS_Scroll:SetTexture("/esoui/art/buttons/gamepad/ps5/nav_ps5_ls_slide.dds") end
        if ps4LS then ps4LS:SetHidden(false) end
    else
        -- Show Xbox icons (includes PC, NA Megaserver, EU Megaserver, XB1live, XB1live-eu)
        xboxLT:SetHidden(false)
        ps4LT:SetHidden(true)

        if xboxLS_Slide then xboxLS_Slide:SetHidden(false) end
        if xboxLS_Scroll then xboxLS_Scroll:SetHidden(false) end
        if ps4LS then ps4LS:SetHidden(true) end
    end
end

-- Show the emote wheel indicator
function CinematicCam:ShowEmoteWheel()
    local control = _G["CinematicCam_EmoteWheel"]
    if not control then return end

    -- Set platform-specific icon BEFORE showing
    self:SetPlatformTriggerIcon()

    control:SetHidden(false)
    control:SetAlpha(0)

    -- Fade in animation
    local timeline = ANIMATION_MANAGER:CreateTimeline()
    local animation = timeline:InsertAnimation(ANIMATION_ALPHA, control)
    animation:SetAlphaValues(0, 1)
    animation:SetDuration(200)
    animation:SetEasingFunction(ZO_EaseOutQuadratic)
    timeline:PlayFromStart()

    self.emoteWheelVisible = true
end

-- Hide the emote wheel indicator
function CinematicCam:HideEmoteWheel()
    local control = _G["CinematicCam_EmoteWheel"]
    if not control then return end

    -- Fade out animation
    local timeline = ANIMATION_MANAGER:CreateTimeline()
    local animation = timeline:InsertAnimation(ANIMATION_ALPHA, control)
    animation:SetAlphaValues(control:GetAlpha(), 0)
    animation:SetDuration(200)
    animation:SetEasingFunction(ZO_EaseOutQuadratic)

    timeline:SetHandler("OnStop", function()
        control:SetHidden(true)
    end)

    timeline:PlayFromStart()

    self.emoteWheelVisible = false
end

-- Show the emote directional pad
function CinematicCam:ShowEmotePad()
    local control = _G["CinematicCam_EmotePad"]
    if not control then return end

    -- Update labels before showing
    self:UpdateEmotePadLabels()

    control:SetHidden(false)
    control:SetAlpha(0)

    -- Fade in animation
    local timeline = ANIMATION_MANAGER:CreateTimeline()
    local animation = timeline:InsertAnimation(ANIMATION_ALPHA, control)
    animation:SetAlphaValues(0, 1)
    animation:SetDuration(150)
    animation:SetEasingFunction(ZO_EaseOutQuadratic)
    timeline:PlayFromStart()

    self.emotePadVisible = true
end

-- Hide the emote directional pad
function CinematicCam:HideEmotePad()
    local control = _G["CinematicCam_EmotePad"]
    if not control then return end

    -- Fade out animation
    local timeline = ANIMATION_MANAGER:CreateTimeline()
    local animation = timeline:InsertAnimation(ANIMATION_ALPHA, control)
    animation:SetAlphaValues(control:GetAlpha(), 0)
    animation:SetDuration(150)
    animation:SetEasingFunction(ZO_EaseOutQuadratic)

    timeline:SetHandler("OnStop", function()
        control:SetHidden(true)
    end)

    timeline:PlayFromStart()

    self.emotePadVisible = false
end

-- Highlight active direction
function CinematicCam:HighlightEmoteDirection(direction)
    local directions = { "Top", "Right", "Bottom", "Left" }

    for _, dir in ipairs(directions) do
        local texture = _G["CinematicCam_EmotePad_" .. dir]
        if texture then
            if dir == direction then
                texture:SetColor(0.3, 0.3, 0.3, 0.95) -- Lighter gray for selected
            else
                texture:SetColor(0, 0, 0, 0.85)       -- Dark for unselected
            end
        end
    end
end

-- Reset all direction highlights
function CinematicCam:ResetEmoteHighlights()
    local directions = { "Top", "Right", "Bottom", "Left" }

    for _, dir in ipairs(directions) do
        local texture = _G["CinematicCam_EmotePad_" .. dir]
        if texture then
            texture:SetColor(0, 0, 0, 0.85)
        end
    end
end

function CinematicCam:InitializeCameraWheel()
    self.cameraWheelVisible = false
    self.cameraPadVisible = false

    -- Set platform-specific trigger icon
    self:SetPlatformCameraTriggerIcon()

    -- Start hidden
    self:HideCameraWheel()
    self:HideCameraPad()
end

-- Set the correct trigger icon based on platform for camera wheel
function CinematicCam:SetPlatformCameraTriggerIcon()
    local xboxRT = _G["CinematicCam_XboxRT"]
    local ps4RT = _G["CinematicCam_PS4RT"]
    local xboxRS_Slide = _G["CinematicCam_XboxRS_Slide"]
    local xboxRS_Scroll = _G["CinematicCam_XboxRS_Scroll"]
    local ps4RS = _G["CinematicCam_PS4RS"]

    if not xboxRT or not ps4RT then
        return
    end

    local worldName = GetWorldName()

    -- Default to Xbox, switch to PS if on PlayStation
    if worldName == "PS4live" or worldName == "PS4live-eu" or worldName == "NA Megaserver" then
        -- Show PlayStation icons
        xboxRT:SetTexture("/esoui/art/buttons/gamepad/ps5/nav_ps5_r2.dds")

        if xboxRS_Slide then xboxRS_Slide:SetTexture("/esoui/art/buttons/gamepad/ps5/nav_ps5_rs_slide.dds") end
        if xboxRS_Scroll then xboxRS_Scroll:SetTexture("/esoui/art/buttons/gamepad/ps5/nav_ps5_rs_scroll.dds") end
        if ps4RS then ps4RS:SetHidden(false) end
    else
        -- Show Xbox icons (includes PC, NA Megaserver, EU Megaserver, XB1live, XB1live-eu)
        xboxRT:SetHidden(false)
        ps4RT:SetHidden(true)

        if xboxRS_Slide then xboxRS_Slide:SetHidden(false) end
        if xboxRS_Scroll then xboxRS_Scroll:SetHidden(false) end
        if ps4RS then ps4RS:SetHidden(true) end
    end
end

-- Show the camera wheel indicator
function CinematicCam:ShowCameraWheel()
    local control = _G["CinematicCam_CameraWheel"]
    if not control then return end

    -- Set platform-specific icon BEFORE showing
    self:SetPlatformCameraTriggerIcon()

    control:SetHidden(false)
    control:SetAlpha(0)

    -- Fade in animation
    local timeline = ANIMATION_MANAGER:CreateTimeline()
    local animation = timeline:InsertAnimation(ANIMATION_ALPHA, control)
    animation:SetAlphaValues(0, 1)
    animation:SetDuration(200)
    animation:SetEasingFunction(ZO_EaseOutQuadratic)
    timeline:PlayFromStart()

    self.cameraWheelVisible = true
end

-- Hide the camera wheel indicator
function CinematicCam:HideCameraWheel()
    local control = _G["CinematicCam_CameraWheel"]
    if not control then return end

    -- Fade out animation
    local timeline = ANIMATION_MANAGER:CreateTimeline()
    local animation = timeline:InsertAnimation(ANIMATION_ALPHA, control)
    animation:SetAlphaValues(control:GetAlpha(), 0)
    animation:SetDuration(200)
    animation:SetEasingFunction(ZO_EaseOutQuadratic)

    timeline:SetHandler("OnStop", function()
        control:SetHidden(true)
    end)

    timeline:PlayFromStart()

    self.cameraWheelVisible = false
end

-- Show the camera directional pad
function CinematicCam:ShowCameraPad()
    local control = _G["CinematicCam_CameraPad"]
    if not control then return end

    control:SetHidden(false)
    control:SetAlpha(0)

    -- Fade in animation
    local timeline = ANIMATION_MANAGER:CreateTimeline()
    local animation = timeline:InsertAnimation(ANIMATION_ALPHA, control)
    animation:SetAlphaValues(0, 1)
    animation:SetDuration(150)
    animation:SetEasingFunction(ZO_EaseOutQuadratic)
    timeline:PlayFromStart()

    self.cameraPadVisible = true
end

-- Hide the camera directional pad
function CinematicCam:HideCameraPad()
    local control = _G["CinematicCam_CameraPad"]
    if not control then return end

    -- Fade out animation
    local timeline = ANIMATION_MANAGER:CreateTimeline()
    local animation = timeline:InsertAnimation(ANIMATION_ALPHA, control)
    animation:SetAlphaValues(control:GetAlpha(), 0)
    animation:SetDuration(150)
    animation:SetEasingFunction(ZO_EaseOutQuadratic)

    timeline:SetHandler("OnStop", function()
        control:SetHidden(true)
    end)

    timeline:PlayFromStart()

    self.cameraPadVisible = false
end

-- Highlight active camera direction
function CinematicCam:HighlightCameraDirection(direction)
    local directions = { "Top", "Right", "Bottom", "Left" }

    for _, dir in ipairs(directions) do
        local texture = _G["CinematicCam_CameraPad_" .. dir]
        if texture then
            if dir == direction then
                -- Only highlight Top and Bottom (zoom controls are active)
                if dir == "Top" or dir == "Bottom" then
                    texture:SetColor(0.3, 0.3, 0.3, 0.95) -- Lighter gray for selected
                else
                    texture:SetColor(0, 0, 0, 0.4)        -- Keep disabled look
                end
            else
                -- Reset to default state
                if dir == "Top" or dir == "Bottom" then
                    texture:SetColor(0, 0, 0, 0.85) -- Dark for unselected active buttons
                else
                    texture:SetColor(0, 0, 0, 0.4)  -- Keep disabled look
                end
            end
        end
    end
end

-- Reset all camera direction highlights
function CinematicCam:ResetCameraHighlights()
    local texture = _G["CinematicCam_CameraPad_Top"]
    if texture then texture:SetColor(0, 0, 0, 0.85) end

    texture = _G["CinematicCam_CameraPad_Bottom"]
    if texture then texture:SetColor(0, 0, 0, 0.85) end

    -- Left and Right stay disabled
    texture = _G["CinematicCam_CameraPad_Left"]
    if texture then texture:SetColor(0, 0, 0, 0.4) end

    texture = _G["CinematicCam_CameraPad_Right"]
    if texture then texture:SetColor(0, 0, 0, 0.4) end
end

function CinematicCam:RegisterSceneHiddenCallbacks()
    local scenesToWatch = {
        "gamepad_store",
        "gamepad_housing_furniture_scene",
        "housingEditorHud"
    }

    for _, sceneName in ipairs(scenesToWatch) do
        local scene = SCENE_MANAGER:GetScene(sceneName)
        if scene then
            scene:RegisterCallback("StateChange", function(oldState, newState)
                if newState == SCENE_SHOWN then
                    self:OnTargetSceneShown(sceneName)
                end
            end)
        end
    end
end

-- Called when one of the target scenes is hidden
function CinematicCam:OnTargetSceneShown(sceneName)
    -- Execute different functions based on which scene was hidden
    if sceneName == "gamepad_store" then
        self:OnStoreSceneShown()
    elseif sceneName == "gamepad_housing_furniture_scene" then
        self:OnHousingFurnitureSceneShown()
    elseif sceneName == "housingEditorHud" then
        self:OnHousingEditorHudShown()
    end

    -- Or call a common function for all scenes
    self:OnAnyTargetSceneHidden(sceneName)
end

-- Individual scene handlers
function CinematicCam:OnStoreSceneShown()
    -- stop freecam
    self:StopGamepadStickPoll()
end

function CinematicCam:OnHousingFurnitureSceneShown()
    self:StopGamepadStickPoll()
end

function CinematicCam:OnHousingEditorHudShown()
    self:StopGamepadStickPoll()
end

-- Common handler for all scenes
function CinematicCam:OnAnyTargetSceneHidden(sceneName)

end

function CinematicCam:GetEmoteForSlot(slotNumber)
    local slotKey = "slot" .. slotNumber
    local packName = self.savedVars.emoteWheel[slotKey]

    if not packName or not CinematicCam.categorizedEmotes[packName] then
        d("CinematicCam: Invalid emote pack for slot " .. slotNumber)
        return nil
    end

    local emotePack = CinematicCam.categorizedEmotes[packName]
    local randomIndex = math.random(1, #emotePack)
    return emotePack[randomIndex]
end

function CinematicCam:GetEmotePackDisplayName(packKey)
    local displayNames = {
        respectful = "Respectful",
        friendly = "Friendly",
        greeting = "Greeting",
        flirty = "Flirty",
        hostile = "Hostile",
        frustrated = "Frustrated",
        sad = "Sad",
        scared = "Scared",
        confused = "Confused",
        celebratory = "Celebratory",
        disgusted = "Disgusted",
        eating = "Eating/Drinking",
        entertainment = "Entertainment/Dance",
        idle = "Idle Poses",
        sitting = "Sitting/Resting",
        pointing = "Pointing/Directing",
        physical = "Physical Actions",
        exercise = "Exercise",
        working = "Working/Tools",
        tired = "Tired/Sick",
        agreement = "Agreement",
        disagreement = "Disagreement",
        playful = "Playful",
        attention = "Get Attention",
        misc = "Miscellaneous"
    }
    return displayNames[packKey] or packKey
end

-- Function to update emote pad labels when pack changes
function CinematicCam:UpdateEmotePadLabels()
    local slotMap = {
        [1] = "Top",
        [2] = "Right",
        [3] = "Bottom",
        [4] = "Left"
    }

    for slotNum, direction in pairs(slotMap) do
        local slotKey = "slot" .. slotNum
        local packName = self.savedVars.emoteWheel[slotKey]
        local label = _G["CinematicCam_EmotePad_" .. direction .. "Text"]

        if label and packName then
            label:SetText(self:GetEmotePackDisplayName(packName))
        end
    end
end
