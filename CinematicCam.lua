-- Cinematic Camera with UI Hiding and Letterbox
local ADDON_NAME = "CinematicCam"
CinematicCam = {}
CinematicCam.savedVars = nil

local hiddenElements = {}
local interactionSettings = {}
local savedCameraState = {}
local isInBlockedInteraction = false
local wasMountLetterboxAutoShown = false
local wasLetterboxAutoShown = false
local wasUIAutoHidden = false

-- Default settings
local defaults = {
    camEnabled = false,
    letterboxSize = 100,
    letterboxOpacity = 1.0,
    autoSizeLetterbox = true,
    customUiElements = {},
    hideUiElements = {},
    letterboxVisible = false,
    uiVisible = true,
    autoLetterboxMount = false,

    -- 3rd Person Dialogue Settings
    forceThirdPersonDialogue = true,
    forceThirdPersonVendor = true,
    forceThirdPersonBank = true,
    forceThirdPersonQuest = true,
    forceThirdPersonCrafting = false,
    autoLetterboxDialogue = false,
    autoHideUIDialogue = false,
    hideDialoguePanels = false,
    hideNPCText = false,
    autoLetterboxConversation = true, -- Enable for regular dialogue
    autoLetterboxQuest = true,        -- Enable for quest interactions
    autoLetterboxVendor = false,      -- Disable for vendors
    autoLetterboxBank = false,        -- Disable for banks
    autoLetterboxCrafting = false,    -- Disable for crafting stations
    selectedFont = "ESO_Standard",
    customFontSize = 18,
    fontScale = 1.0,
}

local letterboxSettings = {}
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
    "ZO_ReticleContainer",

    -- Quest-related UI
    "ZO_QuestJournal",
    "ZO_QuestJournalKeyboard",
    "ZO_QuestTimerFrame",
    "ZO_FocusedQuestTrackerPanel",
    "ZO_QuestTrackerPanelContainer",
    "ZO_QuestLog",

    -- General Interaction UI (but NOT specific dialogue elements)
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

    -- Crafting UI
    "ZO_CraftingTopLevel",
    "ZO_SmithingTopLevel",
    "ZO_EnchantingTopLevel",
    "ZO_AlchemyTopLevel",
    "ZO_ProvisionerTopLevel",


    -- Other UI
    "ZO_NotificationContainer",
    "ZO_TutorialOverlay",
    "ZO_DeathRecapWindow",

    -- Gamepad elements
    "ZO_GamepadChatSystem",
}

local fontBook = {
    ["ESO_Standard"] = {
        name = "ESO Standard",
        path = nil,
        description = "Default ESO font"
    },
    ["ESO_Bold"] = {
        name = "ESO Bold",
        path = "EsoUI/Common/Fonts/FTN57.slug|30|thick-outline",
        description = "Bold ESO font"
    },
    ["Handwritten"] = {
        name = "Handwritten Style",
        path = "EsoUI/Common/Fonts/ProseAntiquePSMT.slug|20|soft-shadow-thick",
        description = "Handwritten-style font"
    },

}


-- Only working on initialize, mnay need to revise logic
-- Replace your RegisterSceneCallbacks function with this:
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
                    -- Reapply UI state after menu closes
                    zo_callLater(function()
                        self:ReapplyUIState()
                    end, 100)
                end
            end)
        end
    end
end

-- Add this new function to reapply your UI state:
function CinematicCam:ReapplyUIState()
    -- Reapply UI visibility based on saved setting
    if not self.savedVars.uiVisible then
        self:HideUI()
    end

    -- Reapply letterbox if it should be visible
    if self.savedVars.letterboxVisible then
        -- Don't animate, just show immediately
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

function CinematicCam:ShowNPCText()
    if ZO_InteractWindowTargetAreaBodyText then
        ZO_InteractWindowTargetAreaBodyText:SetHidden(false)
    end
end

---=============================================================================
-- Manage Letterbox Bars
--=============================================================================
function CinematicCam:InitializeLetterboxSettings()
    letterboxSettings = {
        [INTERACTION_CONVERSATION] = self.savedVars.autoLetterboxConversation,
        [INTERACTION_QUEST] = self.savedVars.autoLetterboxQuest,
        [INTERACTION_VENDOR] = self.savedVars.autoLetterboxVendor,
        [INTERACTION_STORE] = self.savedVars.autoLetterboxVendor,
        [INTERACTION_BANK] = self.savedVars.autoLetterboxBank,
        [INTERACTION_GUILDBANK] = self.savedVars.autoLetterboxBank,
        [INTERACTION_TRADINGHOUSE] = self.savedVars.autoLetterboxVendor,
        [INTERACTION_STABLE] = self.savedVars.autoLetterboxVendor,
        [INTERACTION_CRAFT] = self.savedVars.autoLetterboxCrafting,
        [INTERACTION_DYE_STATION] = self.savedVars.autoLetterboxCrafting,
    }
end

function CinematicCam:ShouldApplyLetterbox(interactionType)
    return letterboxSettings[interactionType] == true
end

function CinematicCam.ToggleLetterboxOnly()
    CinematicCam:ToggleLetterbox()
end

function CinematicCam:ShowLetterbox()
    if self.savedVars.letterboxVisible then
        return
    end

    -- SET THE FLAG IMMEDIATELY, before animation starts
    self.savedVars.letterboxVisible = true

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
    topAnimation:SetTranslateOffsets(0, -barHeight, 0, 0)
    topAnimation:SetDuration(2600)

    -- Animate bottom bar sliding up
    local bottomAnimation = timeline:InsertAnimation(ANIMATION_TRANSLATE, CinematicCam_LetterboxBottom)
    bottomAnimation:SetTranslateOffsets(0, barHeight, 0, 0)
    bottomAnimation:SetDuration(2600)

    -- Remove the timeline handler since flag is already set
    -- timeline:SetHandler('OnStop', function()
    --     self.savedVars.letterboxVisible = true
    -- end)

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
-- Cinematic Mounting
--=============================================================================
function CinematicCam:OnMountUp()
    if self.savedVars.autoLetterboxMount then
        if not self.savedVars.letterboxVisible then
            wasMountLetterboxAutoShown = true
            self:ShowLetterbox()
        else
            wasMountLetterboxAutoShown = false
        end
    end
end

function CinematicCam:OnMountDown()
    if self.savedVars.autoLetterboxMount then
        -- Only hide letterbox if we auto-showed it
        if wasMountLetterboxAutoShown and self.savedVars.letterboxVisible then
            self:HideLetterbox()
        end
        -- Reset tracking flag
        wasMountLetterboxAutoShown = false
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
-- 3rd Person Questing
--=============================================================================
-- User preference settings
function CinematicCam:InitializeInteractionSettings()
    interactionSettings = {
        [INTERACTION_CONVERSATION] = self.savedVars.forceThirdPersonDialogue,
        [INTERACTION_QUEST] = self.savedVars.forceThirdPersonQuest,
        [INTERACTION_VENDOR] = self.savedVars.forceThirdPersonVendor,
        [INTERACTION_STORE] = self.savedVars.forceThirdPersonVendor,
        [INTERACTION_BANK] = self.savedVars.forceThirdPersonBank,
        [INTERACTION_GUILDBANK] = self.savedVars.forceThirdPersonBank,
        [INTERACTION_TRADINGHOUSE] = self.savedVars.forceThirdPersonVendor,
        [INTERACTION_STABLE] = self.savedVars.forceThirdPersonVendor,
        [INTERACTION_CRAFT] = self.savedVars.forceThirdPersonCrafting,
        [INTERACTION_DYE_STATION] = self.savedVars.forceThirdPersonCrafting,
    }
end

function CinematicCam:CheckInteractionStatus()
    if isInBlockedInteraction then
        local currentInteraction = GetInteractionType()
        if currentInteraction == INTERACTION_NONE then
            CinematicCam:OnInteractionEnd()
        else
            -- If still in interaction, check again after a delay
            zo_callLater(function()
                CinematicCam:CheckInteractionStatus()
            end, 500)
        end
    end
end

function GetCameraDistance()
    return tonumber(GetSetting(SETTING_TYPE_CAMERA, CAMERA_SETTING_DISTANCE))
end

function CinematicCam:ShouldBlockInteraction(interactionType)
    return interactionSettings[interactionType] == true
end

-- Save current camera state before interaction
function CinematicCam:SaveCameraState()
    savedCameraState = {
        distance = GetCameraDistance(),
    }
end

function CinematicCam:RestoreCameraState()
    savedCameraState = {}
end

function CinematicCam:OnGameCameraDeactivated()
    local interactionType = GetInteractionType()

    if self:ShouldBlockInteraction(interactionType) then
        -- Prevent the camera switch to close-up interaction view
        SetInteractionUsingInteractCamera(false)
        isInBlockedInteraction = true

        -- Save current state
        self:SaveCameraState()



        -- HIDE DIALOGUE PANELS ONLY IF SETTING IS ENABLED
        if self.savedVars.hideDialoguePanels then
            self:HideDialoguePanels()
        end

        -- Track and show letterbox IF this interaction type should have letterbox
        if self:ShouldApplyLetterbox(interactionType) then
            if not self.savedVars.letterboxVisible then
                wasLetterboxAutoShown = true
                self:ShowLetterbox()
            else
                wasLetterboxAutoShown = false
            end
        end

        -- Track and hide UI during dialogue if needed
        if self.savedVars.autoHideUIDialogue then
            if self.savedVars.uiVisible then
                wasUIAutoHidden = true
                self:HideUI()
            else
                wasUIAutoHidden = false
            end
        end

        -- Start periodic check for interaction end
        zo_callLater(function()
            CinematicCam:CheckInteractionStatus()
        end, 1000)
    end
end

function CinematicCam:OnGameCameraActivated()
    if isInBlockedInteraction then
        -- Check if we're actually out of interaction
        zo_callLater(function()
            local currentInteraction = GetInteractionType()
            if currentInteraction == INTERACTION_NONE then
                CinematicCam:OnInteractionEnd()
            end
        end, 100) -- just to let the interaction state update
    end
end

function CinematicCam:OnInteractionEnd()
    if isInBlockedInteraction then
        isInBlockedInteraction = false



        -- RESTORE DIALOGUE PANELS ONLY IF THEY WERE HIDDEN
        if self.savedVars.hideDialoguePanels then
            self:ShowDialoguePanels()
        end
        -- Restore camera state
        self:RestoreCameraState()

        -- Only hide letterbox if we auto-showed it
        if wasLetterboxAutoShown and self.savedVars.letterboxVisible then
            self:HideLetterbox()
        end

        -- Only show UI if we auto-hid it
        if wasUIAutoHidden and not self.savedVars.uiVisible then
            self:ShowUI()
        end

        -- Reset tracking flags
        wasLetterboxAutoShown = false
        wasUIAutoHidden = false
    end
end

---=============================================================================
-- Hide Questing Dialoge Panels
--=============================================================================
-- Need to hide this: "ZO_KeybindStripButtonTemplate2"
function CinematicCam:HideDialoguePanels()
    -- Main dialogue window elements
    if ZO_InteractWindowDivider then ZO_InteractWindowDivider:SetHidden(true) end
    if ZO_InteractWindowVerticalSeparator then ZO_InteractWindowVerticalSeparator:SetHidden(true) end
    if ZO_InteractWindowTopBG then ZO_InteractWindowTopBG:SetHidden(true) end
    if ZO_InteractWindowBottomBG then ZO_InteractWindowBottomBG:SetHidden(true) end

    -- Text elements - handle title and body text separately
    if ZO_InteractWindowTargetAreaTitle then ZO_InteractWindowTargetAreaTitle:SetHidden(true) end
    -- Only hide NPC text if the hideNPCText setting is enabled
    if ZO_InteractWindowTargetAreaBodyText then
        ZO_InteractWindowTargetAreaBodyText:SetHidden(true)
    end

    -- Options and highlights
    if ZO_InteractWindowPlayerAreaOptions then ZO_InteractWindowPlayerAreaOptions:SetHidden(true) end
    if ZO_InteractWindowPlayerAreaHighlight then ZO_InteractWindowPlayerAreaHighlight:SetHidden(true) end
    if ZO_InteractWindowCollapseContainerRewardArea then ZO_InteractWindowCollapseContainerRewardArea:SetHidden(true) end

    -- Gamepad elements
    if ZO_InteractWindow_GamepadBG then ZO_InteractWindow_GamepadBG:SetHidden(true) end
    if ZO_InteractWindow_GamepadContainerText then
        ZO_InteractWindow_GamepadContainerText:SetHidden(self.savedVars
            .hideNPCText)
    end
end

function CinematicCam:ShowDialoguePanels()
    -- Main dialogue window elements
    if ZO_InteractWindowDivider then ZO_InteractWindowDivider:SetHidden(false) end
    if ZO_InteractWindowVerticalSeparator then ZO_InteractWindowVerticalSeparator:SetHidden(false) end
    if ZO_InteractWindowTopBG then ZO_InteractWindowTopBG:SetHidden(false) end
    if ZO_InteractWindowBottomBG then ZO_InteractWindowBottomBG:SetHidden(false) end

    -- Text elements
    if ZO_InteractWindowTargetAreaTitle then ZO_InteractWindowTargetAreaTitle:SetHidden(false) end

    -- Only show NPC text if the hideNPCText setting is enabled
    if ZO_InteractWindowTargetAreaBodyText then ZO_InteractWindowTargetAreaBodyText:SetHidden(true) end

    -- Options and highlights
    if ZO_InteractWindowPlayerAreaOptions then ZO_InteractWindowPlayerAreaOptions:SetHidden(false) end
    if ZO_InteractWindowPlayerAreaHighlight then ZO_InteractWindowPlayerAreaHighlight:SetHidden(false) end
    if ZO_InteractWindowCollapseContainerRewardArea then ZO_InteractWindowCollapseContainerRewardArea:SetHidden(false) end

    -- Gamepad elements
    if ZO_InteractWindow_GamepadBG then ZO_InteractWindow_GamepadBG:SetHidden(false) end
    if ZO_InteractWindow_GamepadContainerText then
        ZO_InteractWindow_GamepadContainerText:SetHidden(self.savedVars
            .hideNPCText)
    end
end

---=============================================================================
-- Font Book
--=============================================================================
function CinematicCam:GetFontChoices()
    local choices = {}
    local choicesValues = {}

    for fontId, fontData in pairs(fontBook) do
        table.insert(choices, fontData.name)
        table.insert(choicesValues, fontId)
    end

    return choices, choicesValues
end

function CinematicCam:GetCurrentFont()
    local fontData = fontBook[self.savedVars.selectedFont]
    if fontData then
        return fontData.path
    end
    return fontBook["ESO_Standard"].path -- fallback
end

function CinematicCam:ApplyFontToElement(element, fontSize)
    if not element then return end

    local fontPath = self:GetCurrentFont()

    -- Let ESO use its default font
    if not fontPath then
        return
    end

    local actualSize = fontSize or self.savedVars.customFontSize
    actualSize = math.floor(actualSize * self.savedVars.fontScale)

    -- Parse the font path and replace size
    local finalFontString = self:ParseFontPath(fontPath, actualSize)

    element:SetFont(finalFontString)
end

function CinematicCam:ParseFontPath(fontPath, newSize)
    -- Safety check for nil fontPath
    if not fontPath or fontPath == "" then
        return nil
    end

    -- Check if the path contains a size (pattern: |number|)
    local hasSize = string.find(fontPath, "|%d+|")

    if hasSize then
        -- Replace existing size with new size
        local newPath = string.gsub(fontPath, "|%d+|", "|" .. newSize .. "|")
        return newPath
    else
        -- No size found, check if it has effects after the font file
        local hasEffects = string.find(fontPath, "|")

        if hasEffects then
            -- Has effects but no size, insert size before effects
            local newPath = string.gsub(fontPath, "|", "|" .. newSize .. "|", 1)
            return newPath
        else
            -- No size, no effects, just add size
            return fontPath .. "|" .. newSize
        end
    end
end

function CinematicCam:ApplyFontsToUI()
    -- Use the same size for all dialogue elements
    local fontSize = self.savedVars.customFontSize

    if ZO_InteractWindowTargetAreaTitle then
        self:ApplyFontToElement(ZO_InteractWindowTargetAreaTitle, fontSize)
    end

    if ZO_InteractWindowTargetAreaBodyText then
        self:ApplyFontToElement(ZO_InteractWindowTargetAreaBodyText, fontSize)
    end

    if ZO_InteractWindow_GamepadContainerText then
        self:ApplyFontToElement(ZO_InteractWindow_GamepadContainerText, fontSize)
    end
    if ZO_InteractWindowPlayerAreaOptions then
        self:ApplyFontToElement(ZO_InteractWindowPlayerAreaOptions, fontSize)
    end
    if ZO_InteractWindowPlayerAreaHighlight then
        self:ApplyFontToElement(ZO_InteractWindowPlayerAreaHighlight, fontSize)
    end
end

function CinematicCam:SetupDialogueFontHooks()
    -- Hook into the interaction window showing
    local originalSetupInteraction = ZO_InteractWindow_OnInteractionUpdated
    if originalSetupInteraction then
        ZO_InteractWindow_OnInteractionUpdated = function(...)
            originalSetupInteraction(...)
            -- Apply fonts after dialogue is set up
            zo_callLater(function()
                CinematicCam:ApplyFontsToUI()
            end, 50)
        end
    end

    -- Also hook into chatter events for simple NPC dialogue
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_Font", EVENT_CHATTER_BEGIN, function()
        zo_callLater(function()
            CinematicCam:ApplyFontsToUI()
        end, 100)
    end)
end

function CinematicCam:OnFontChanged()
    -- Apply fonts immediately if dialogue is currently open
    local interactionType = GetInteractionType()
    if interactionType ~= INTERACTION_NONE then
        self:ApplyFontsToUI()
    end

    -- Also apply to any existing dialogue elements
    zo_callLater(function()
        self:ApplyFontsToUI()
    end, 100)
end

---=============================================================================
-- Initialize
--=============================================================================
local function Initialize()
    -- Load saved variables
    CinematicCam.savedVars = ZO_SavedVars:NewAccountWide("CinematicCamSavedVars", 2, nil, defaults)
    zo_callLater(function()
        CinematicCam:SetupDialogueFontHooks()
    end, 1000)

    -- Apply fonts after UI elements are loaded
    zo_callLater(function()
        CinematicCam:ApplyFontsToUI()
    end, 2000)
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
    else
        zo_callLater(function()
            CinematicCam_Container:SetHidden(false) -- Container can stay visible
            CinematicCam_LetterboxTop:SetHidden(true)
            CinematicCam_LetterboxBottom:SetHidden(true)
        end, 1500)
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

    CinematicCam:InitializeLetterboxSettings()
    -- Initialize 3rd person dialogue settings
    CinematicCam:InitializeInteractionSettings()

    -- Calculate letterbox size
    CinematicCam:CalculateLetterboxSize()

    -- Register for camera events (for 3rd person dialogue)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_GAME_CAMERA_DEACTIVATED, function()
        CinematicCam:OnGameCameraDeactivated()
    end)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_GAME_CAMERA_ACTIVATED, function()
        CinematicCam:OnGameCameraActivated()
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
    -- Register for screen resize
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_SCREEN_RESIZED, function()
        zo_callLater(function()
            CinematicCam:CalculateLetterboxSize()
        end, 500)
    end)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_MOUNTED_STATE_CHANGED, function(eventCode, mounted)
        if mounted then
            CinematicCam:OnMountUp()
        else
            CinematicCam:OnMountDown()
        end
    end)
    zo_callLater(function()
        -- Create settings menu with LibAddonMenu-2.0
        CinematicCam:CreateSettingsMenu()
        CinematicCam:RegisterSceneCallbacks() -- Not doing anything
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
