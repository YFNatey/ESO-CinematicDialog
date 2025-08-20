local uiElementsMap = {} -- table for hiding ui elements, used in HideUI()
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

---=============================================================================
-- Manage ESO UI Elements
--=============================================================================

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
