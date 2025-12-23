CinematicCam.uiElementsMap = {} -- table for hiding ui elements, used in HideUI()
-- UI elements to hide
CinematicCam.interactionTypes = {
    INTERACTION_CONVERSATION,
    INTERACTION_QUEST,
    INTERACTION_VENDOR,
    INTERACTION_STORE,
    INTERACTION_BANK,
    INTERACTION_GUILDBANK,
    INTERACTION_TRADINGHOUSE,
    INTERACTION_STABLE,
    INTERACTION_CRAFT,
    INTERACTION_DYE_STATION,
}
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

function CinematicCam:InitializeUITweaks()
    if self.savedVars.interface.usingModTweaks then
        CinematicCam:UpdateCompassVisibility()
        CinematicCam:UpdateActionBarVisibility()
        CinematicCam:UpdateReticleVisibility()
    end
end

function CinematicCam:IsInAnyInteraction()
    local currentInteractionType = GetInteractionType()

    if currentInteractionType == INTERACTION_NONE then
        return false
    end

    for _, interactionType in ipairs(self.interactionTypes) do
        if currentInteractionType == interactionType then
            return true
        end
    end

    return false
end

---=============================================================================
-- Manage ESO UI Elements
--=============================================================================
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
end

-- Show UI elements
function CinematicCam:ShowUI()
    if self.savedVars.interface.UiElementsVisible then
        return
    end
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
CinematicCam.InteractionReticle = {
    "ZO_ReticleContainerReticle",
    "ZO_ReticleContainer",
    "ZO_ReticleContainerStealthIcon",
    "ZO_ReticleContainerNoneInteract",

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

    --  mount stamina handled separately
    local mountStamina = _G["ZO_PlayerAttributeMountStamina"]
    if mountStamina and IsMounted() then
        self:FadeInElement(mountStamina, 200)
    end
end

function CinematicCam:HideActionBar()
    for _, elementName in ipairs(CinematicCam.actionbar) do
        local element = _G[elementName]
        if element then
            self:FadeOutElement(element, 200)
        end
    end

    -- mount stamina
    local mountStamina = _G["ZO_PlayerAttributeMountStamina"]
    if mountStamina then
        self:FadeOutElement(mountStamina, 200)
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

function CinematicCam:HideInteractionReticle()
    for _, elementName in ipairs(CinematicCam.InteractionReticle) do
        local element = _G[elementName]
        if element then
            element:SetHidden(true)
        end
    end
end

function CinematicCam:UpdateCompassVisibility()
    local setting = self.savedVars.interface.hideCompass
    local interactionType = GetInteractionType()
    local inCombat = IsUnitInCombat("player")
    local weaponsSheathed = ArePlayerWeaponsSheathed()
    local showWhenWeaponsUnsheathed = self.savedVars.interface.hideCompassWhenWeaponsSheathed

    -- Check for weapon-unsheathed override
    if showWhenWeaponsUnsheathed and not weaponsSheathed then
        self:ShowCompass()
        return
    end

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
    elseif setting == "weapons" then
        self:PollWeapons()
        return
    end
    self:StopPollingWeapons()
end

-- Update action bar visibility
function CinematicCam:UpdateActionBarVisibility()
    local setting = self.savedVars.interface.hideActionBar
    local inCombat = IsUnitInCombat("player")
    local weaponsSheathed = ArePlayerWeaponsSheathed()
    local showWhenWeaponsUnsheathed = self.savedVars.interface.hideActionBarWhenWeaponsSheathed

    -- Check for weapon-unsheathed override
    if showWhenWeaponsUnsheathed and not weaponsSheathed then
        self:ShowActionBar()
        return
    end

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
    elseif setting == "weapons" then
        self:PollWeapons()
        return
    end
    self:StopPollingWeapons()
end

function CinematicCam:UpdateUIVisibility()
    CinematicCam:UpdateActionBarVisibility()
    CinematicCam:UpdateCompassVisibility()
    CinematicCam:UpdateReticleVisibility()
end

function CinematicCam:PollWeapons()
    local ReticleSetting = self.savedVars.interface.hideReticle
    local CompassSetting = self.savedVars.interface.hideCompass
    local ActionbarSetting = self.savedVars.interface.hideActionBar

    local weaponsSheathed = ArePlayerWeaponsSheathed()

    if CinematicCam.lastWeaponsState == weaponsSheathed then
        self.weaponsPollTimer = zo_callLater(function()
            self:PollWeapons()
        end, 1000)
        return
    end

    CinematicCam.lastWeaponsState = weaponsSheathed

    if not weaponsSheathed then
        if ReticleSetting == "weapons" then
            self:ShowReticle()
        end
        if CompassSetting == "weapons" then
            self:ShowCompass()
        end
        if ActionbarSetting == "weapons" then
            self:ShowActionBar()
        end
    else
        if ReticleSetting == "weapons" then
            self:HideReticle()
        end
        if CompassSetting == "weapons" then
            self:HideCompass()
        end
        if ActionbarSetting == "weapons" then
            self:HideActionBar()
        end
    end

    self.weaponsPollTimer = zo_callLater(function()
        self:PollWeapons()
    end, 1000)
end

function CinematicCam:StopPollingWeapons()
    if self.weaponsPollTimer then
        zo_removeCallLater(self.weaponsPollTimer)
        self.weaponsPollTimer = nil
    end
end

-- Update reticle visibility
function CinematicCam:UpdateReticleVisibility()
    local setting = self.savedVars.interface.hideReticle
    local inCombat = IsUnitInCombat("player")
    local weaponsSheathed = ArePlayerWeaponsSheathed()



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
    elseif setting == "weapons" then
        self:PollWeapons()
        return
    end
    self:StopPollingWeapons()
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
-- fade-in for any UI element
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
