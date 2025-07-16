-- Cinematic Camera with UI Hiding and Letterbox
local ADDON_NAME = "CinematicCam"
CinematicCam = {}
CinematicCam.savedVars = nil

local hiddenElements = {}
local camTargetX = 0.79
local camTargetY = 0.99
-- Default settings
local defaults = {
    camEnabled = false,
    letterboxSize = 100,
    letterboxOpacity = 1.0,
    autoSizeLetterbox = true,
    customUiElements = {},
    hideUiElements = {},
    letterboxVisible = false,
    uiVisible = true
}
-- UI elements to hide
local uiElements = {
    "ZO_CompassFrame",
    "ZO_PlayerAttributeHealth",
    "ZO_PlayerAttributeMagicka",
    "ZO_PlayerAttributeStamina",
    "ZO_ActionBar1",
    "ZO_ActionBar2",
    "ZO_TargetUnitFrame",
    "ZO_UnitFrames",
    "ZO_ChatWindowTemplate1",
    "ZO_MinimapContainer",
    "ZO_PowerBlock",
    "ZO_BuffTracker",

    -- Quest-related UI
    "ZO_QuestJournal",
    "ZO_QuestJournalKeyboard",
    "ZO_QuestTimerFrame",
    "ZO_FocusedQuestTrackerPanel",
    "ZO_QuestTrackerPanelContainer",
    "ZO_QuestLog",
    -- Interaction/Dialog UI
    "ZO_InteractWindow",
    "ZO_InteractWindowDivider",
    "ZO_InteractWindowTopBG",
    "ZO_InteractWindowBottomBG",
    "ZO_ConversationWindow",
    -- Inventory & Menus
    "ZO_PlayerInventory",
    "ZO_GameMenu_InGame",
    "ZO_MainMenuCategoryBarContainer",
    -- Social UI
    "ZO_KeyboardGuildWindow",
    "ZO_FriendsListKeyboard",
    "ZO_IgnoreListKeyboard",
    "ZO_GroupWindow",
    -- Other UI
    "ZO_CraftingTopLevel",
    "ZO_SmithingTopLevel",
    "ZO_EnchantingTopLevel",
    "ZO_AlchemyTopLevel",
    "ZO_ProvisionerTopLevel",
    "ZO_NotificationContainer",
    "ZO_TutorialOverlay",
    "ZO_DeathRecapWindow",
    -- Gamepad elements (just in case)
    "ZO_GamepadChatSystem",
    "ZO_InteractWindow_Gamepad",
}

-- Only working on initialize, mnay need to revise logic
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
            d("Registering callback for scene: " .. sceneName)
            scene:RegisterCallback("StateChange", function(_, newState)
                if newState == SCENE_HIDING then
                    ReapplyCameraOnMenuClose()
                end
            end)
        end
    end
end

function CinematicCam:CameraZoom()
    -- Zoom in the camera
    local currentZoom = GetCameraZoom()
    SetCameraZoom(currentZoom - 0.5) -- Adjust zoom speed as needed
end

---=============================================================================
-- Manage Letterbox Bars
--=============================================================================
function CinematicCam.ToggleLetterboxOnly()
    CinematicCam:ToggleLetterbox()
end

function CinematicCam:ShowLetterbox()
    if self.savedVars.letterboxVisible then
        return
    end
    -- Make sure our container is visible
    CinematicCam_Container:SetHidden(false)

    -- Set initial positions (bars start off-screen)
    local screenHeight = GuiRoot:GetHeight()
    local barHeight = self.savedVars.letterboxSize

    CinematicCam_LetterboxTop:ClearAnchors()
    CinematicCam_LetterboxTop:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 0, -barHeight)
    CinematicCam_LetterboxTop:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, 0, -barHeight)
    CinematicCam_LetterboxTop:SetHeight(barHeight)

    CinematicCam_LetterboxBottom:ClearAnchors()
    CinematicCam_LetterboxBottom:SetAnchor(BOTTOMLEFT, GuiRoot, BOTTOMLEFT, 0, barHeight)
    CinematicCam_LetterboxBottom:SetAnchor(BOTTOMRIGHT, GuiRoot, BOTTOMRIGHT, 0, barHeight)
    CinematicCam_LetterboxBottom:SetHeight(barHeight)

    -- Set color and draw properties
    CinematicCam_LetterboxTop:SetColor(0, 0, 0, self.savedVars.letterboxOpacity)
    CinematicCam_LetterboxBottom:SetColor(0, 0, 0, self.savedVars.letterboxOpacity)
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
    topAnimation:SetTranslateOffsets(0, -barHeight, 0, 0) -- Move from off-screen to final position
    topAnimation:SetDuration(2600)


    -- Animate bottom bar sliding up
    local bottomAnimation = timeline:InsertAnimation(ANIMATION_TRANSLATE, CinematicCam_LetterboxBottom)
    bottomAnimation:SetTranslateOffsets(0, barHeight, 0, 0) -- Move from off-screen to final position
    bottomAnimation:SetDuration(2600)

    timeline:SetHandler('OnStop', function()
        self.savedVars.letterboxVisible = true
    end)
    -- Start the animation
    timeline:PlayFromStart()
end

-- Hide letterbox bars
function CinematicCam:HideLetterbox()
    if not self.savedVars.letterboxVisible then
        return
    end
    if CinematicCam_LetterboxTop:IsHidden() then
        return
    end
    local barHeight = self.savedVars.letterboxSize

    -- Create timeline for hide animation
    local timeline = ANIMATION_MANAGER:CreateTimeline()

    -- Animate top bar sliding up (off-screen)
    local topAnimation = timeline:InsertAnimation(ANIMATION_TRANSLATE, CinematicCam_LetterboxTop)
    topAnimation:SetTranslateOffsets(0, 0, 0, -barHeight) -- Move from current position to off-screen
    topAnimation:SetDuration(3300)                        -- Slightly faster exit
    topAnimation:SetEasingFunction(ZO_EaseOutCubic)
    -- Animate bottom bar sliding down (off-screen)
    local bottomAnimation = timeline:InsertAnimation(ANIMATION_TRANSLATE, CinematicCam_LetterboxBottom)
    bottomAnimation:SetTranslateOffsets(0, 0, 0, barHeight) -- Move from current position to off-screen
    bottomAnimation:SetDuration(3300)                       -- Slightly faster exit
    bottomAnimation:SetEasingFunction(ZO_EaseOutCubic)

    -- Hide bars after animation completes
    timeline:SetHandler('OnStop', function()
        CinematicCam_LetterboxTop:SetHidden(true)
        CinematicCam_LetterboxBottom:SetHidden(true)
        -- Reset positions for next time
        CinematicCam_LetterboxTop:ClearAnchors()
        CinematicCam_LetterboxTop:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT)
        CinematicCam_LetterboxTop:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT)
        CinematicCam_LetterboxBottom:ClearAnchors()
        CinematicCam_LetterboxBottom:SetAnchor(BOTTOMLEFT, GuiRoot, BOTTOMLEFT)
        CinematicCam_LetterboxBottom:SetAnchor(BOTTOMRIGHT, GuiRoot, BOTTOMRIGHT)
        self.savedVars.letterboxVisible = false
    end)
    -- Start the animation
    timeline:PlayFromStart()
end

-- Toggle letterbox visibility
function CinematicCam:ToggleLetterbox()
    if self.savedVars.letterboxVisible then
        self:HideLetterbox()
    else
        self:ShowLetterbox()
    end
end

-- Calculate letterbox size for screen
function CinematicCam:CalculateLetterboxSize()
    -- Only auto-calculate if enabled in settings
    if not self.savedVars.autoSizeLetterbox then
        return
    end

    -- Get screen dimensions
    local screenWidth = GuiRoot:GetWidth()
    local screenHeight = GuiRoot:GetHeight()

    -- Calculate letterbox size for a 2.35:1 aspect ratio
    local targetAspectRatio = 2.35
    local currentAspectRatio = screenWidth / screenHeight

    if currentAspectRatio < targetAspectRatio then
        -- Screen is too tall, calculate letterbox size
        local idealHeight = screenWidth / targetAspectRatio
        local letterboxSize = math.floor((screenHeight - idealHeight) / 2)

        -- Update size
        self.savedVars.letterboxSize = letterboxSize
    else
        -- Screen is already wider than cinematic ratio, use minimal letterbox
        self.savedVars.letterboxSize = math.floor(screenHeight * 0.1) -- 10% of screen height
    end

    -- Apply the new size if letterbox is visible
    if not CinematicCam_LetterboxTop:IsHidden() then
        CinematicCam_LetterboxTop:SetHeight(self.savedVars.letterboxSize)
        CinematicCam_LetterboxBottom:SetHeight(self.savedVars.letterboxSize)
    end
end

---=============================================================================
-- Manage ESO UI Elements
--=============================================================================
function CinematicCam:HideUI()
    if not self.savedVars.uiVisible then
        return
    end

    for _, elementName in ipairs(uiElements) do
        local element = _G[elementName]
        if element and not element:IsHidden() then
            hiddenElements[elementName] = true
            element:SetHidden(true)
        end
    end

    for elementName, shouldHide in pairs(self.savedVars.hideUiElements) do
        if shouldHide then
            local element = _G[elementName]
            if element and not element:IsHidden() then
                hiddenElements[elementName] = true
                element:SetHidden(true)
            end
        end
    end
    self.savedVars.uiVisible = false
end

-- Show UI elements
function CinematicCam:ShowUI()
    if self.savedVars.uiVisible then
        return
    end
    for elementName, _ in pairs(hiddenElements) do
        local element = _G[elementName]
        if element then
            element:SetHidden(false)
        end
    end
    hiddenElements = {}
    self.savedVars.uiVisible = true
end

-- Toggle UI
function CinematicCam:ToggleUI()
    if self.savedVars.uiVisible then
        self:HideUI()
    else
        self:ShowUI()
    end
end

---=============================================================================
-- Initialize
--=============================================================================
local function Initialize()
    -- Load saved variables
    CinematicCam.savedVars = ZO_SavedVars:NewCharacterIdSettings("CinematicCamSavedVars", 1, nil, defaults)

    -- Init letterbox bars savedVars
    if CinematicCam.savedVars.letterboxVisible then
        zo_callLater(function()
            CinematicCam_Container:SetHidden(false)
            CinematicCam_LetterboxTop:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT)
            CinematicCam_LetterboxTop:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT)
            CinematicCam_LetterboxTop:SetHeight(CinematicCam.savedVars.letterboxSize)
            CinematicCam_LetterboxTop:SetColor(0, 0, 0, CinematicCam.savedVars.letterboxOpacity)
            CinematicCam_LetterboxTop:SetDrawLayer(DL_OVERLAY)
            CinematicCam_LetterboxTop:SetDrawLevel(5)
            CinematicCam_LetterboxTop:SetHidden(false)

            CinematicCam_LetterboxBottom:SetAnchor(BOTTOMLEFT, GuiRoot, BOTTOMLEFT)
            CinematicCam_LetterboxBottom:SetAnchor(BOTTOMRIGHT, GuiRoot, BOTTOMRIGHT)
            CinematicCam_LetterboxBottom:SetHeight(CinematicCam.savedVars.letterboxSize)
            CinematicCam_LetterboxBottom:SetColor(0, 0, 0, CinematicCam.savedVars.letterboxOpacity)
            CinematicCam_LetterboxBottom:SetDrawLayer(DL_OVERLAY)
            CinematicCam_LetterboxBottom:SetDrawLevel(5)
            CinematicCam_LetterboxBottom:SetHidden(false)
        end, 1500) -- Wait for UI to be ready
    end

    -- Init UI saved Vars
    if not CinematicCam.savedVars.uiVisible then
        zo_callLater(function()
            for _, elementName in ipairs(uiElements) do
                local element = _G[elementName]
                if element and not element:IsHidden() then
                    hiddenElements[elementName] = true
                    element:SetHidden(true)
                end
            end
            for elementName, shouldHide in pairs(CinematicCam.savedVars.hideUiElements) do
                if shouldHide then
                    local element = _G[elementName]
                    if element and not element:IsHidden() then
                        hiddenElements[elementName] = true
                        element:SetHidden(true)
                    end
                end
            end
        end, 1600)
    end

    -- Register slash commands
    SLASH_COMMANDS["/ccui"] = function()
        CinematicCam:ToggleUI()
    end

    SLASH_COMMANDS["/ccbars"] = function()
        CinematicCam:ToggleLetterbox()
    end

    -- Calculate letterbox size
    CinematicCam:CalculateLetterboxSize()


    -- Register for screen resize
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_SCREEN_RESIZED, function()
        zo_callLater(function()
            CinematicCam:CalculateLetterboxSize()
        end, 500)
    end)
    zo_callLater(function()
        -- Create settings menu with LibAddonMenu-2.0
        CinematicCam:CreateSettingsMenu()
        CinematicCam:RegisterSceneCallbacks() -- Not doing anything
        zo_callLater(function()
            d("Cinematic Camera loaded - use /ccui to toggle UI, /ccbars to toggle letterbox bars")
        end, 2000)
    end, 100)
end
local function OnPlayerActivated(eventCode)
    if not CinematicCam.hasPlayedIntro then
        CinematicCam.hasPlayedIntro = true
        camEnabled = true

        -- Smooth exit after a few seconds
        zo_callLater(function()
            camEnabled = false
            CinematicCam:ShowUI()
        end, 100)
        for i = 1, 9 do
            CameraZoomIn()
        end
    end
end

-- Keybind functions
function CinematicCam.ToggleCinematicMode()
    CinematicCam:ToggleUI()
    CinematicCam:ToggleLetterbox()
end

-- OnAddOnLoaded event
local function OnAddOnLoaded(event, addonName)
    if addonName == ADDON_NAME then
        EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
        Initialize()
    end
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
