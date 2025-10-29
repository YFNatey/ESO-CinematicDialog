CinematicCam.uiElementsMap = {} -- table for hiding ui elements, used in HideUI()
-- UI elements to hide
CinematicCam.uiElements = {
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

function CinematicCam:HideUI()
    if not self.savedVars.interface.UiElementsVisible then
        return
    end
    for _, elementName in ipairs(CinematicCam.uiElements) do
        local element = _G[elementName]
        if element and not element:IsHidden() then
            CinematicCam.uiElementsMap[elementName] = true
            element:SetHidden(true)
        end
    end

    for elementName, shouldHide in pairs(self.savedVars.hideUiElements) do
        if shouldHide then
            local element = _G[elementName]
            if element and not element:IsHidden() then
                CinematicCam.uiElementsMap[elementName] = true
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
    for elementName, _ in pairs(CinematicCam.uiElementsMap) do
        local element = _G[elementName]
        if element then
            element:SetHidden(false)
        end
    end
    CinematicCam.uiElementsMap = {}
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

function CinematicCam:StartUIMonitoring()
    -- Stop monitoring
    self:StopUIMonitoring()

    -- Start monitoring
    local function monitorUIElements()
        if self.savedVars.interface.UiElementsVisible then
            self:StopUIMonitoring()
            return
        end

        -- Hide elements from the predefined list if visible
        for _, elementName in ipairs(CinematicCam.uiElements) do
            local element = _G[elementName]
            if element and not element:IsHidden() then
                element:SetHidden(true)
            end
        end

        -- Hide custom UI elements if visible
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
    uiMonitoringTimer = zo_callLater(monitorUIElements, MONITORING_INTERVAL)
end

-- Stop monitoring
function CinematicCam:StopUIMonitoring()
    if uiMonitoringTimer then
        zo_removeCallLater(uiMonitoringTimer)
        uiMonitoringTimer = nil
    end
end

-- UI element groups
CinematicCam.compassElements = {
    "ZO_CompassFrame",
    "ZO_CompassFrameCenter",
    "ZO_CompassFrameLeft",
    "ZO_CompassFrameRight",
    "ZO_CompassContainer",
}

CinematicCam.actionbar = {
    "ZO_PlayerAttributeHealth",
    "ZO_PlayerAttributeMagicka",
    "ZO_PlayerAttributeStamina",
    "ZO_PlayerAttributeMountStamina",
    "ZO_ActionBar1",
    "ZO_ActionBar2",
    "ZO_TargetUnitFrame",
    "ZO_UnitFrames",
    "ZO_MinimapContainer",
    "ZO_PowerBlock",
    "ZO_BuffTracker",
}

CinematicCam.reticle = {
    "ZO_ReticleContainerReticle",
    "ZO_ReticleContainerStealthIcon",
}


---=============================================================================
-- UI Element Show/Hide Functions
--=============================================================================
function CinematicCam:ShowCompass()
    for _, elementName in ipairs(CinematicCam.compassElements) do
        local element = _G[elementName]
        if element then
            self:FadeInElement(element, 200)
        end
    end
end

function CinematicCam:HideCompass()
    for _, elementName in ipairs(CinematicCam.compassElements) do
        local element = _G[elementName]
        if element then
            self:FadeOutElement(element, 200)
        end
    end
end

function CinematicCam:ShowActionBar()
    for _, elementName in ipairs(CinematicCam.actionbar) do
        local element = _G[elementName]
        if element then
            self:FadeInElement(element, 200)
        end
    end
end

function CinematicCam:HideActionBar()
    for _, elementName in ipairs(CinematicCam.actionbar) do
        local element = _G[elementName]
        if element then
            self:FadeOutElement(element, 200)
        end
    end
end

function CinematicCam:ShowReticle()
    for _, elementName in ipairs(CinematicCam.reticle) do
        local element = _G[elementName]
        if element then
            self:FadeInElement(element, 200)
        end
    end
end

function CinematicCam:HideReticle()
    for _, elementName in ipairs(CinematicCam.reticle) do
        local element = _G[elementName]
        if element then
            self:FadeOutElement(element, 200)
        end
    end
end

-- Update Compass Visibility
function CinematicCam:UpdateCompassVisibility()
    local setting = self.savedVars.interface.hideCompass
    local inCombat = IsUnitInCombat("player")

    if setting == "never" then
        self:HideCompass()
    elseif setting == "always" then
        self:ShowCompass()
    elseif setting == "combat" then
        if inCombat then
            self:ShowCompass()
        else
            self:HideCompass()
        end
    end
end

-- Update action bar visibility
function CinematicCam:UpdateActionBarVisibility()
    local setting = self.savedVars.interface.hideActionBar
    local inCombat = IsUnitInCombat("player")

    if setting == "never" then
        self:HideActionBar()
    elseif setting == "always" then
        self:ShowActionBar()
    elseif setting == "combat" then
        if inCombat then
            self:ShowActionBar()
        else
            self:HideActionBar()
        end
    end
end

-- Update reticle visibility
function CinematicCam:UpdateReticleVisibility()
    local setting = self.savedVars.interface.hideReticle
    local inCombat = IsUnitInCombat("player")

    if setting == "never" then
        self:HideReticle()
    elseif setting == "always" then
        self:ShowReticle()
    elseif setting == "combat" then
        if inCombat then
            self:ShowReticle()
        else
            self:HideReticle()
        end
    end
end

---=============================================================================
-- Hide Questing Dialoge Panels
--=============================================================================
-- Hides each element of the default UI panels during dialogue interactions
function CinematicCam:HideDialoguePanels()
    -- Main dialogue window elements
    if ZO_InteractWindow_GamepadContainerDivider then ZO_InteractWindow_GamepadContainerDivider:SetHidden(true) end

    -- Gold divider line between subtitles and player options
    if ZO_InteractWindowVerticalSeparator then ZO_InteractWindowVerticalSeparator:SetHidden(true) end

    -- Top and bottom background
    if ZO_InteractWindowTopBG then ZO_InteractWindowTopBG:SetHidden(false) end
    if ZO_InteractWindowBottomBG then ZO_InteractWindowBottomBG:SetHidden(true) end

    -- NPC Name
    if ZO_InteractWindowTargetAreaTitle then ZO_InteractWindowTargetAreaTitle:SetHidden(true) end

    -- Options
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

    -- Gold divider line between subtitles and player options
    if ZO_InteractWindowVerticalSeparator then ZO_InteractWindowVerticalSeparator:SetHidden(false) end

    -- Top and bottom background
    if ZO_InteractWindowTopBG then ZO_InteractWindowTopBG:SetHidden(false) end
    if ZO_InteractWindowBottomBG then ZO_InteractWindowBottomBG:SetHidden(false) end

    -- NPC Name
    if ZO_InteractWindowTargetAreaTitle then ZO_InteractWindowTargetAreaTitle:SetHidden(false) end

    -- Only show NPC text if the hideNPCText setting is enabled
    if ZO_InteractWindowTargetAreaBodyText then ZO_InteractWindowTargetAreaBodyText:SetHidden(true) end

    -- Options
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
local npcTextContainer = ZO_InteractWindow_GamepadContainerText
if npcTextContainer then
    local originalWidth, originalHeight = npcTextContainer:GetDimensions()
    local addedWidth = originalWidth + 10
    local addedHeight = originalHeight + 100
end

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
    local safeWidth, safeHeight, screenWidth, screenHeight = self:GetSafeScreenDimensions()

    if preset == "cinematic" then
        local targetX, targetY = self:ConvertToScreenCoordinates(
            self.savedVars.interaction.subtitles.posX or 0.5,
            self.savedVars.interaction.subtitles.posY or 0.7
        )

        control:ClearAnchors()
        control:SetAnchor(CENTER, GuiRoot, CENTER, targetX, targetY)
        control:SetDimensions(safeWidth, math.min(safeHeight * 0.3, 200))

        -- Position background to match with dynamic sizing
        if background then
            background:ClearAnchors()
            background:SetAnchor(CENTER, GuiRoot, CENTER, targetX, targetY)
            background:SetDimensions(math.min(safeWidth * 1.1, 900), 150)
        end
    else
        -- Default positioning for non-cinematic presets
        -- The width of efault eso subtitles is 683
        local defaultWidth = math.min(screenWidth * 0.35, 683)
        local defaultHeight = math.min(safeHeight * 0.7, 550)

        control:ClearAnchors()
        control:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, -50, 100)
        control:SetDimensions(defaultWidth, defaultHeight)

        -- Position background to match
        if background then
            background:ClearAnchors()
            background:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, -50, 100)
            background:SetDimensions(defaultWidth + 37, defaultHeight + 30)
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

function CinematicCam:OnDialoguelayoutPresetChanged(newPreset)
    if CinematicCam.chunkedDialogueData.isActive and CinematicCam.chunkedDialogueData.customControl then
        self:ApplyChunkedTextPositioning()
    end
end

---=============================================================================
-- Animations
--=============================================================================
--  fade-in for any UI element
function CinematicCam:FadeInElement(element, duration)
    if not element then return end

    if not element:IsHidden() and element:GetAlpha() >= 0.99 then
        return
    end

    element:SetAlpha(0)
    element:SetHidden(false)

    -- Fade-in animation
    local timeline = ANIMATION_MANAGER:CreateTimelineFromVirtual("ShowOnMouseOverLabelAnimation", element)
    local animation = timeline:GetFirstAnimation()

    if animation then
        animation:SetAlphaValues(0, 1)
        animation:SetDuration(duration or 300)
        animation:SetEasingFunction(ZO_EaseInQuadratic)
    end

    timeline:PlayFromStart()
end

-- fade-out for any UI element
function CinematicCam:FadeOutElement(element, duration)
    if not element then return end

    if element:IsHidden() then
        return
    end

    local timeline = ANIMATION_MANAGER:CreateTimelineFromVirtual("ShowOnMouseOverLabelAnimation", element)
    local animation = timeline:GetFirstAnimation()

    if animation then
        animation:SetAlphaValues(element:GetAlpha(), 0)
        animation:SetDuration(duration or 300)
        animation:SetEasingFunction(ZO_EaseOutQuadratic)
    end

    timeline:SetHandler("OnStop", function()
        element:SetHidden(true)
        element:SetAlpha(1)
    end)

    timeline:PlayFromStart()
end
