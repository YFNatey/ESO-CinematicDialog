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
    hideUiElements = {}
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

---=============================================================================
-- Restrictive Player focus camera
--=============================================================================
local function ApplyPlayerFocusCamera()
    if not IsPlayerMoving() then
        SetFrameLocalPlayerInGameCamera(true)
        SetFrameLocalPlayerTarget(camTargetX, camTargetY)
        SetFrameLocalPlayerLookAtDistanceFactor(nil)
    else
        SetFrameLocalPlayerInGameCamera(false)
    end
end

-- Update camera settings immediately
local function UpdateCamTargetX(value)
    camTargetX = value
    if camEnabled then
        SetFrameLocalPlayerTarget(camTargetX, camTargetY)
    end
end

local function UpdateCamTargetY(value)
    camTargetY = value
    if camEnabled then
        SetFrameLocalPlayerTarget(camTargetX, camTargetY)
    end
end

function CinematicCam:CameraZoom()
    -- Zoom in the camera
    local currentZoom = GetCameraZoom()
    SetCameraZoom(currentZoom - 0.5) -- Adjust zoom speed as needed
    d("Camera zoomed in")
end

---=============================================================================
-- Letterbox Bars
--=============================================================================
function CinematicCam.ToggleLetterboxOnly()
    CinematicCam:ToggleLetterbox()
end

function CinematicCam:ShowLetterbox()
    -- Make sure our container is visible
    CinematicCam_Container:SetHidden(false)

    -- Show bars
    CinematicCam_LetterboxTop:SetHidden(false)
    CinematicCam_LetterboxBottom:SetHidden(false)

    -- Set height
    CinematicCam_LetterboxTop:SetHeight(self.savedVars.letterboxSize)
    CinematicCam_LetterboxBottom:SetHeight(self.savedVars.letterboxSize)

    -- Set color to solid black with user-defined opacity
    CinematicCam_LetterboxTop:SetColor(0, 0, 0, self.savedVars.letterboxOpacity)
    CinematicCam_LetterboxBottom:SetColor(0, 0, 0, self.savedVars.letterboxOpacity)

    -- Set draw layer to make sure it appears on top of other UI elements
    CinematicCam_LetterboxTop:SetDrawLayer(DL_OVERLAY)
    CinematicCam_LetterboxBottom:SetDrawLayer(DL_OVERLAY)

    -- Set draw level to ensure it's on top
    CinematicCam_LetterboxTop:SetDrawLevel(5)
    CinematicCam_LetterboxBottom:SetDrawLevel(5)

    d("Letterbox enabled")
end

-- Hide letterbox bars
function CinematicCam:HideLetterbox()
    CinematicCam_LetterboxTop:SetHidden(true)
    CinematicCam_LetterboxBottom:SetHidden(true)
    d("Letterbox disabled")
end

-- Toggle letterbox visibility
function CinematicCam:ToggleLetterbox()
    if CinematicCam_LetterboxTop:IsHidden() then
        self:ShowLetterbox()
    else
        self:HideLetterbox()
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

-- Hide UI elements
function CinematicCam:HideUI()
    for _, elementName in ipairs(uiElements) do
        local element = _G[elementName]
        if element and not element:IsHidden() then
            hiddenElements[elementName] = true
            element:SetHidden(true)
        end
    end

    -- Also hide any custom UI elements the user added
    for elementName, shouldHide in pairs(self.savedVars.hideUiElements) do
        if shouldHide then
            local element = _G[elementName]
            if element and not element:IsHidden() then
                hiddenElements[elementName] = true
                element:SetHidden(true)
            end
        end
    end

    -- Show letterbox if enabled
    if self.savedVars.letterboxEnabled then
        self:ShowLetterbox()
    end

    d("Cinematic mode enabled")
end

-- Show UI elements
function CinematicCam:ShowUI()
    for elementName, _ in pairs(hiddenElements) do
        local element = _G[elementName]
        if element then
            element:SetHidden(false)
        end
    end
    hiddenElements = {}

    -- Hide letterbox
    self:HideLetterbox()

    d("Cinematic mode disabled")
end

-- Toggle UI
function CinematicCam:ToggleUI()
    if next(hiddenElements) then
        self:ShowUI()
    else
        self:HideUI()
    end
end

---=============================================================================
-- Initialize
--=============================================================================
local function Initialize()
    -- Load saved variables
    CinematicCam.savedVars = ZO_SavedVars:NewCharacterIdSettings("CinematicCamSavedVars", 1, nil, defaults)

    -- Debug both XML file controls
    zo_callLater(function()
        -- Check letterbox controls
        if CinematicCam_Container then
            d("✓ Letterbox XML loaded - CinematicCam_Container found")
            if CinematicCam_LetterboxTop and CinematicCam_LetterboxBottom then
                d("✓ Letterbox bars found")
            else
                d("✗ Letterbox bars not found")
            end
        else
            d("✗ Letterbox XML not loaded - CinematicCam_Container not found")
        end
    end, 1000)

    -- Create a global reference to the addon


    -- Load saved variables
    CinematicCam.savedVars = ZO_SavedVars:NewCharacterIdSettings("CinematicCamSavedVars", 1, nil, defaults)

    -- Register slash commands
    SLASH_COMMANDS["/hideui"] = function()
        CinematicCam:ToggleUI()
    end

    SLASH_COMMANDS["/letterbox"] = function()
        CinematicCam:ToggleLetterbox()
    end


    SLASH_COMMANDS["/focus"] = function()
        ApplyPlayerFocusCamera()
    end


    SLASH_COMMANDS["/letterboxopacity"] = function(arg)
        local opacity = tonumber(arg)
        if opacity and opacity >= 0 and opacity <= 1 then
            CinematicCam.savedVars.letterboxOpacity = opacity
            d("Letterbox opacity set to " .. opacity)

            -- Update if visible
            if not CinematicCam_LetterboxTop:IsHidden() then
                CinematicCam_LetterboxTop:SetColor(0, 0, 0, opacity)
                CinematicCam_LetterboxBottom:SetColor(0, 0, 0, opacity)
            end
        else
            d("Usage: /letterboxopacity [0-1] (e.g., /letterboxopacity 1 for fully opaque)")
        end
    end

    SLASH_COMMANDS["/cinematic"] = function(arg)
        if arg == "letterbox" then
            CinematicCam:ToggleLetterbox()
        else
            CinematicCam:ToggleUI()
        end
    end

    -- Calculate letterbox size
    CinematicCam:CalculateLetterboxSize()

    -- Make sure letterbox is hidden initially
    ---CinematicCam_Container:SetHidden(false) -- Container always exists but children are hidden
    --CinematicCam_LetterboxTop:SetHidden(true)
    --CinematicCam_LetterboxBottom:SetHidden(true)

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
            d("Cinematic Camera loaded - use /hideui to toggle UI, /letterbox to toggle letterbox bars")
            d("Settings menu available with /cinematicsettings")
        end, 2000)
    end, 100)
end
local function OnPlayerActivated(eventCode)
    if not CinematicCam.hasPlayedIntro then
        CinematicCam.hasPlayedIntro = true
        camEnabled = true


        -- Optional letterbox fade-in can go here

        -- Smooth exit after a few seconds
        zo_callLater(function()
            camEnabled = false
            CinematicCam:ShowUI()
            -- CinematicCam:ToggleLetterbox()
        end, 100)
        for i = 1, 9 do
            CameraZoomIn()
        end -- 10 sec
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
