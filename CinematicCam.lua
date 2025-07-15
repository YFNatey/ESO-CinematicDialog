-- Cinematic Camera with UI Hiding and Letterbox
local ADDON_NAME = "CinematicCam"
local hiddenElements = {}

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

-- Saved variables
local CinematicCam = {
    savedVars = {
        letterboxSize = 100,    -- Default height in pixels
        letterboxOpacity = 0.9, -- Default opacity
    }
}

-- Show letterbox bars
function CinematicCam:ShowLetterbox()
    -- Make sure our container is visible
    CinematicCam_Container:SetHidden(false)

    -- Show bars
    CinematicCam_LetterboxTop:SetHidden(false)
    CinematicCam_LetterboxBottom:SetHidden(false)

    -- Set height
    CinematicCam_LetterboxTop:SetHeight(self.savedVars.letterboxSize)
    CinematicCam_LetterboxBottom:SetHeight(self.savedVars.letterboxSize)

    -- IMPORTANT: Set color to solid black with 100% opacity
    -- Format is: R, G, B, Alpha (all values 0-1)
    CinematicCam_LetterboxTop:SetColor(0, 0, 0, 1)
    CinematicCam_LetterboxBottom:SetColor(0, 0, 0, 1)

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

    -- Show letterbox
    self:ShowLetterbox()

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

-- Initialize addon
function CinematicCam:Initialize()
    -- Create a global reference to the addon
    _G["CinematicCam"] = self

    -- Register slash commands
    SLASH_COMMANDS["/hideui"] = function()
        self:ToggleUI()
    end

    SLASH_COMMANDS["/letterbox"] = function()
        self:ToggleLetterbox()
    end

    SLASH_COMMANDS["/cinematic"] = function(arg)
        if arg == "letterbox" then
            self:ToggleLetterbox()
        else
            self:ToggleUI()
        end
    end

    -- Calculate letterbox size
    self:CalculateLetterboxSize()

    -- Make sure letterbox is hidden initially
    CinematicCam_Container:SetHidden(false) -- Container always exists but children are hidden
    CinematicCam_LetterboxTop:SetHidden(true)
    CinematicCam_LetterboxBottom:SetHidden(true)

    -- Register for screen resize
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_SCREEN_RESIZED, function()
        zo_callLater(function()
            self:CalculateLetterboxSize()
        end, 500)
    end)

    d("Cinematic Camera loaded - use /hideui to toggle UI, /letterbox to toggle letterbox bars, or /cinematic for both")
end

-- Keybind function
function CinematicCam.ToggleCinematicMode()
    CinematicCam:ToggleUI()
end

function CinematicCam.ToggleLetterboxOnly()
    CinematicCam:ToggleLetterbox()
end

-- OnAddOnLoaded event
local function OnAddOnLoaded(eventCode, addonName)
    if addonName ~= ADDON_NAME then return end

    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    CinematicCam:Initialize()
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
