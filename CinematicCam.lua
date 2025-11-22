--[[
===============================================================================
Cinematic Dialog - Elder Scrolls Online Addon
Author: YFNatey
===============================================================================
]]
local ADDON_NAME = "CinematicCam"

CinematicCam = {}
CinematicCam.savedVars = nil
CinematicCam.globalCount = 0
local interactionTypeMap = {}
local CURRENT_VERSION = "3.37"

-- State tracking
CinematicCam.isInteractionModified = false
CinematicCam.settingsUpdatedThisSession = false
CinematicCam.lastWeaponsState = nil
CinematicCam.currentZoneType = nil


-- Handles the logic when the default interaction camera is deactivated.
-- Applies UI changes, letterbox, and font updates based on user settings and interaction type.
function CinematicCam:OnGameCameraDeactivated()
    if not CinematicCam.isInteractionModified then
        self:ResetChunkedDialogueState()
    end

    -- Hide the NPC subtitles immediately
    CinematicCam:HideNPCText()

    local interactionType = GetInteractionType()
    if self:ShouldBlockInteraction(interactionType) then
        SetInteractionUsingInteractCamera(false)

        -- Handle Camera movement during dialogue
        if CinematicCam.savedVars.interaction.allowCameraMovementDuringDialogue then
            if not self.gamepadStickPoll then
                self.gamepadStickPoll = {
                    isActive = true,
                    deadzone = 0.2,
                    moveThreshold = 0.5,
                    lastMove = GetGameTimeMilliseconds(),
                }
            end
            self.gamepadStickPoll.isActive = true
            EVENT_MANAGER:RegisterForUpdate("CinematicCam_GamepadStickPoll", 50, function()
                self:GamepadStickPoll()
            end)
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
                    CinematicCam:HideNPCText()
                    self:InterceptDialogueForChunking()
                end
            end
        )

        -- Player Advances in dialogue (chooses a response option)
        EVENT_MANAGER:RegisterForEvent(
            ADDON_NAME .. "_ConversationUpdate",
            EVENT_CONVERSATION_UPDATED,
            function()
                if self.savedVars.interaction.subtitles.hidePlayerOptionsUntilLastChunk == false then
                    CinematicCam:ForceShowAllPlayerOptions()
                end

                if self.savedVars.interaction.layoutPreset == "cinematic" then
                    CinematicCam:HideNPCText()
                    self:InterceptDialogueForChunking()
                    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME .. "_ChatterBegin", EVENT_CHATTER_BEGIN)
                end
            end
        )

        -- The players response option will start a quest
        EVENT_MANAGER:RegisterForEvent(
            ADDON_NAME .. "_QuestOffered",
            EVENT_QUEST_OFFERED,
            function()
                if self.savedVars.interaction.subtitles.hidePlayerOptionsUntilLastChunk == false then
                    CinematicCam:ForceShowAllPlayerOptions()
                end

                if self.savedVars.interaction.layoutPreset == "cinematic" then
                    CinematicCam:HideNPCText()

                    self:InterceptDialogueForChunking()
                    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME .. "_ChatterBegin", EVENT_CHATTER_BEGIN)
                    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME .. "_ConversationUpdate", EVENT_CONVERSATION_UPDATED)
                end
            end
        )

        -- Complete quest and accept rewards
        EVENT_MANAGER:RegisterForEvent(
            ADDON_NAME .. "_QuestCompleteDialog",
            EVENT_QUEST_COMPLETE_DIALOG,
            function()
                if self.savedVars.interaction.subtitles.hidePlayerOptionsUntilLastChunk == false then
                    CinematicCam:ForceShowAllPlayerOptions()
                end

                if self.savedVars.interaction.layoutPreset == "cinematic" then
                    CinematicCam:HideNPCText()
                    self:InterceptDialogueForChunking()
                    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME .. "_ChatterBegin", EVENT_CHATTER_BEGIN)
                    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME .. "_ConversationUpdate", EVENT_CONVERSATION_UPDATED)
                    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME .. "_QuestOffered", EVENT_QUEST_OFFERED)
                end
            end
        )

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
                    self:ShowLetterbox()
                end
            end
        end, 200)
    end
end

-- Called when Leaving an interaction (conversation, quest, vendor, etc)
function CinematicCam:OnInteractionEnd()
    CinematicCam.lastWeaponsState = nil
    CinematicCam.exitedDialogue = true
    -- Stop watching gamepad sticks
    self:StopGamepadStickPoll()
    CinematicCam:UpdateUIVisibility()
    -- Stop watching for conversation events
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
    end
    zo_callLater(function()
        CinematicCam.exitedDialogue = false
    end, 2000)
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

---=============================================================================
-- Initialize
--=============================================================================
function CinematicCam:InitDefaults()
    CinematicCam.savedVars = ZO_SavedVars:NewAccountWide("CinematicCam2SavedVars", 2, nil, CinematicCam.defaults)
end

local function Initialize()
    CinematicCam:InitDefaults()
    CinematicCam:InitializeLetterbox()
    CinematicCam:InitializeSepiaFilter()
    CinematicCam:ConfigurePlayerOptionsBackground()
    CinematicCam:InitializeChunkedTextControl()
    CinematicCam:InitializePreviewSystem()


    zo_callLater(function()
        CinematicCam:InitializeUI()
        CinematicCam:RegisterFontEvents()
        CinematicCam:RegisterSceneCallbacks()
        CinematicCam:MigrateSettings()
        CinematicCam:InitializeInteractionSettings()
        CinematicCam:UpdateHorizontal()
        CinematicCam:RegisterUIRefreshEvent()
        CinematicCam:UpdateUIVisibility()
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
                CinematicCam:UpdateUIVisibility()
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
    CinematicCam:UpdateUIVisibility()
end)

-- Font events
function CinematicCam:RegisterFontEvents()
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_Font", EVENT_CHATTER_BEGIN, function()
        self:ApplyFontsToUI()
        CinematicCam:UpdateUIVisibility()
    end)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_Font", EVENT_CONVERSATION_UPDATED, function()
        self:ApplyFontsToUI()
        CinematicCam:UpdateUIVisibility()
    end)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_Font", EVENT_QUEST_COMPLETE_DIALOG, function()
        self:ApplyFontsToUI()
        CinematicCam:UpdateUIVisibility()
    end)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_Font", EVENT_INTERACTION_UPDATED, function()
        self:ApplyFontsToUI()
        CinematicCam:UpdateUIVisibility()
    end)

    -- Add more specific events
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_Font", EVENT_SHOW_BOOK, function()
        self:ApplyFontsToUI()
        CinematicCam:UpdateUIVisibility()
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
            CinematicCam.inHousingEditor = true
        else
            -- Exiting housing editor - restore reticle setting
            CinematicCam.inHousingEditor = false
            CinematicCam:UpdateUIVisibility()
        end
    end)


EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_ZoneChange", EVENT_PLAYER_ACTIVATED, function()
    zo_callLater(function()
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

-- Checks if the current interaction should be forced to 3rd person.
-- @param interactionType number: The current interaction type constant
-- @return boolean: True if the interaction should be blocked, false otherwise
function CinematicCam:ShouldBlockInteraction(interactionType)
    local unitName = GetUnitName("interact")
    if unitName == "Equipment Crafting Writs" or unitName == " Consumables Crafting Writs" then
        -- If user disabled third person for notes, allow ESO default
        if not self.savedVars.interaction.forceThirdPersonInteractiveNotes then
            self.savedVars.interaction.subtitles.isHidden = false
            return false -- Don't block - use ESO default camera
        end
    end
    return interactionTypeMap[interactionType] == true
end

function CinematicCam:GamepadStickPoll()
    if not self.gamepadStickPoll or not self.gamepadStickPoll.isActive then
        return
    end

    -- Read left stick input for interaction camera toggle
    local leftX = ZO_Gamepad_GetLeftStickEasedX()
    local leftY = ZO_Gamepad_GetLeftStickEasedY()

    -- Read right stick input for frame local player
    local rightX = ZO_Gamepad_GetRightStickEasedX()
    local rightY = ZO_Gamepad_GetRightStickEasedY()

    -- Calculate stick magnitudes
    local leftMagnitude = zo_sqrt(leftX * leftX + leftY * leftY)
    local rightMagnitude = zo_sqrt(rightX * rightX + rightY * rightY)

    -- Right stick: Frame local player in game camera
    if rightMagnitude >= self.gamepadStickPoll.deadzone then
        if math.abs(rightX) > math.abs(rightY) then
            if rightX > 0 then     -- Right
                SetGameCameraUIMode(false)
            elseif rightY > 0 then -- Left
                SetGameCameraUIMode(false)
            elseif rightY < 0 then -- Down
                SetGameCameraUIMode(false)
            elseif rightX < 0 then -- Up
                SetGameCameraUIMode(false)
            end
        end
    end
end

function CinematicCam:StopGamepadStickPoll()
    if not self.gamepadStickPoll then return end
    self.gamepadStickPoll.isActive = false
    EVENT_MANAGER:UnregisterForUpdate("CinematicCam_GamepadStickPoll")
end

---=============================================================================
-- Check for Updates
--=============================================================================
function CinematicCam:CheckForUpdates()
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
    self:FadeInElement(notification, 300)

    -- Auto-hide after 5 seconds
    zo_callLater(function()
        self:FadeOutElement(notification, 300)
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
        "|cFFD700Cinematic Dialogue|r \n|cFFFFFFTry it out by talking to an NPC|r\n|cE0E0E0Check the settings menu for more customization options|r")

    -- Start fade in animation
    self:FadeInElement(notification, 300)

    -- Auto-hide after 5 seconds
    zo_callLater(function()
        self:FadeOutElement(notification, 300)
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
    self:FadeInElement(notification, 300)

    -- Auto-hide after 5 seconds
    zo_callLater(function()
        self:FadeOutElement(notification, 300)
    end, 6000)
end

---=============================================================================
-- Migrate Settings
--=============================================================================
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
