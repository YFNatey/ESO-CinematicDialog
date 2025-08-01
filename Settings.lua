--[[ TODO
Dye Stations toggle
Allow npc text repositioning
Allow options for npc name: appended or above text
Allow reposition dialoge options
Fix "images, coin, u46 descision images shopwing up as squares"
--]]
---=============================================================================
-- Settings Menu
--=============================================================================
-- Create LibAddonMenu-2.0 settings panel
function CinematicCam:CreateSettingsMenu()
    local LAM = LibAddonMenu2

    if not LAM then
        return
    end
    local choices, choicesValues = self:GetFontChoices()

    local panelName = "CinematicCamOptions"

    local panelData = {
        type = "panel",
        name = "Cinematic Dialog",
        displayName = "Cinemtaic Dialog",
        author = "YFNatey",
        version = "1.0",
        slashCommand = "/cinematicsettings",
        registerForRefresh = true,
        registerForDefaults = true,
    }

    local optionsData = {
        {
            type = "header",
            name = "3rd Person Dialog Toggles",
        },

        {
            type = "checkbox",
            name = "Citizens",
            tooltip = "Keep camera in 3rd person when talking to regular NPCs",
            getFunc = function() return self.savedVars.interaction.forceThirdPersonDialogue end,
            setFunc = function(value)
                self.savedVars.interaction.forceThirdPersonDialogue = value
                self:InitializeInteractionSettings()
            end,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Merchants",
            tooltip = "Keep camera in 3rd person when using vendors, stores, trading house, and stables",
            getFunc = function() return self.savedVars.interaction.forceThirdPersonVendor end,
            setFunc = function(value)
                self.savedVars.forceThirdPersonVendor = value
                self:InitializeInteractionSettings()
            end,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Bankers",
            tooltip = "Keep camera in 3rd person when using banks and guild banks",
            getFunc = function() return self.savedVars.interaction.forceThirdPersonBank end,
            setFunc = function(value)
                self.savedVars.interaction.forceThirdPersonBank = value
                self:InitializeInteractionSettings()
            end,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Crafting Stations",
            tooltip = "Keep camera in 3rd person when using crafting stations",
            getFunc = function() return self.savedVars.interaction.forceThirdPersonCrafting end,
            setFunc = function(value)
                self.savedVars.interaction.forceThirdPersonCrafting = value
                self:InitializeInteractionSettings()
            end,
            width = "full",
        },
        --TODO: Dye Stations
        {
            type = "header",
            name = "Subtitle Settings",
        },
        --[[TODO hide player options
        {
            type = "checkbox",
            name = "Hide Player Options Until NPC Finishes",
            tooltip = "Hide player dialogue options until the NPC finishes speaking for a more cinematic experience",
            getFunc = function() return CinematicCam.savedVars.hidePlayerOptionsUntilComplete end,
            setFunc = function(value) CinematicCam.savedVars.hidePlayerOptionsUntilComplete = value end,

        },
        {
            type = "checkbox",
            name = "Show Options on Last Sentence",
            tooltip = "Show player options when the last sentence starts (vs when it finishes)",
            getFunc = function() return CinematicCam.savedVars.showOptionsOnLastChunk end,
            setFunc = function(value) CinematicCam.savedVars.showOptionsOnLastChunk = value end,

            disabled = function() return not CinematicCam.savedVars.hidePlayerOptionsUntilComplete end,
        },
        --]]
        {
            type = "checkbox",
            name = "Subtitles",
            getFunc = function() return not self.savedVars.interaction.subtitles.isHidden end,
            setFunc = function(value)
                self.savedVars.interaction.subtitles.isHidden = not value
                self:UpdateChunkedTextVisibility()
            end,
            width = "full",
        },
        {
            type = "dropdown",
            name = "Subtitle Style",
            tooltip =
            "Choose how dialogue elements are positioned:\n• Default: Original positioning\n• Cinematic: Bottom centered\n",
            choices = { "Default", "Cinematic" },
            choicesValues = { "defeault", "cinematic" },
            getFunc = function() return self.savedVars.interaction.layoutPreset end,
            setFunc = function(value)
                self.savedVars.interaction.layoutPreset = value
                currentRepositionPreset = value

                -- Force hide dialogue panels for center layouts
                if value == "cinematic" then
                    self.savedVars.interaction.ui.hidePanelsESO = true
                    self.savedVars.interaction.subtitles.useChunkedDialogue = true
                elseif value == "default" then
                    self.savedVars.interaction.ui.hidePanelsESO = false
                end

                -- Apply immediately if in dialogue
                local interactionType = GetInteractionType()
                if interactionType ~= INTERACTION_NONE then
                    zo_callLater(function()
                        self:ApplyDialogueRepositioning()
                    end, 50)
                end
            end,
            width = "full",
        },
        {
            type = "slider",
            name = "Cinematic Subtitle Position",
            tooltip =
            "Adjust vertical position of dialogue text (0% = top, 100% = bottom). Move the slider to see a preview.",
            min = 0,
            max = 100,
            step = 1,
            getFunc = function()
                local normalizedPos = self.savedVars.interaction.subtitles.posY or 0.7
                return math.floor(normalizedPos * 100)
            end,
            setFunc = function(value)
                local normalizedY = value / 100
                self.savedVars.interaction.subtitles.posY = normalizedY
                self:OnSubtitlePositionChanged(normalizedY)

                -- Show preview when slider changes
                self:ShowSubtitlePreview(value)
            end,
            -- Real-time preview while dragging (if supported by your settings library)
            onValueChanged = function(value)
                if isPreviewActive then
                    self:UpdatePreviewPosition(value)
                end
            end,
            width = "full",
        },
        {
            type = "slider",
            name = "Move Default Panel Position",
            tooltip =
            "Adjust the horizontal position of the dialogue window.",
            min = 10,
            max = 34,
            step = 2,
            getFunc = function()
                return math.floor(self.savedVars.interface.dialogueHorizontalOffset * 100)
            end,
            setFunc = function(value)
                self.savedVars.interface.dialogueHorizontalOffset = value / 100

                -- Apply immediately if in dialogue
                local interactionType = GetInteractionType()
                if interactionType ~= INTERACTION_NONE then
                    zo_callLater(function()
                        self:ApplyDialogueRepositioning()
                    end, 50)
                end
            end,
            width = "full",
        },

        --- FONT SETTINGS
        {
            type = "header",
            name = "Font Settings",
        },
        {
            type = "dropdown",
            name = "Font",
            tooltip = "Choose the font for the NPC dialogue text",
            choices = choices,
            choicesValues = choicesValues,
            getFunc = function() return self.savedVars.interface.selectedFont end,
            setFunc = function(value)
                self.savedVars.interface.selectedFont = value
                self:OnFontChanged()
            end,
            width = "full",
        },
        {
            type = "slider",
            name = "Font Size",
            min = 10,
            max = 64,
            step = 1,
            getFunc = function() return self.savedVars.interface.customFontSize end,
            setFunc = function(value)
                self.savedVars.interface.customFontSize = value
                self:OnFontChanged()
            end,
            width = "full",
        },
        {
            type = "header",
            name = "Cinematic Settings",
        },

        {
            type = "checkbox",
            name = "UI Panels",
            tooltip = "Hide the default ESO UI panels",
            getFunc = function() return not self.savedVars.interaction.ui.hidePanelsESO end,
            setFunc = function(value)
                self.savedVars.interaction.ui.hidePanelsESO = not value
                if self.savedVars.interaction.ui.hidePanelsESO then
                    CinematicCam:HideDialoguePanels()
                else
                    CinematicCam:ShowDialoguePanels()
                end
            end,
            width = "full",
        },

        {
            type = "checkbox",
            name = "Auto Black Bars During Dialog",
            tooltip = "Automatically show black bars during dialogue interactions (conversations and quests)",
            getFunc = function() return self.savedVars.interaction.auto.autoLetterboxDialogue end,
            setFunc = function(value)
                self.savedVars.interaction.auto.autoLetterboxDialogue = value
            end,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Auto Black Bars on Mount",
            tooltip = "Automatically show black bars when riding",
            getFunc = function() return CinematicCam.savedVars.letterbox.autoLetterboxMount end,
            setFunc = function(value) CinematicCam.savedVars.letterbox.autoLetterboxMount = value end,
            width = "full",
        },
        {
            type = "slider",
            name = "Mount Black Bars Delay",
            tooltip = "Delay before showing black bars when mounting (0 = instant, 60 = 1 minute)",
            min = 0,
            max = 60,
            step = 20,
            getFunc = function() return CinematicCam.savedVars.letterbox.mountLetterboxDelay end,
            setFunc = function(value)
                CinematicCam.savedVars.letterbox.mountLetterboxDelay = value
            end,
            disabled = function() return not CinematicCam.savedVars.letterbox.autoLetterboxMount end,
            width = "full",
        },
        {
            type = "button",
            name = "Toggle Black Bars",
            func = function()
                self:ToggleLetterbox()
            end,
            width = "half",
        },
        {
            type = "slider",
            name = "Black Bar Size",
            tooltip = "Adjust the height of the bars (default is 100)",
            min = 10,
            max = 300,
            step = 5,
            getFunc = function() return self.savedVars.letterbox.size end,
            setFunc = function(value)
                self.savedVars.letterbox.size = value
                if not CinematicCam_LetterboxTop:IsHidden() then
                    CinematicCam_LetterboxTop:SetHeight(value)
                    CinematicCam_LetterboxBottom:SetHeight(value)
                end
            end,
            width = "full",
        },
        {
            type = "slider",
            name = "Black Bar Opacity",
            tooltip = "Adjust the opacity of the bars (1.0 = solid black)",
            min = 0.5,
            max = 1.0,
            step = 0.05,
            getFunc = function() return self.savedVars.letterbox.opacity end,
            setFunc = function(value)
                self.savedVars.letterbox.opacity = value
                if not CinematicCam_LetterboxTop:IsHidden() then
                    CinematicCam_LetterboxTop:SetColor(0, 0, 0, value)
                    CinematicCam_LetterboxBottom:SetColor(0, 0, 0, value)
                end
            end,
            width = "full",
        },
        {
            type = "description",
            text = [[/ccui - Photo Mdde
/ccbars - Black Bars]],
            width = "full"
        },
        {
            type = "divider",
            width = "full"
        },
        {
            type = "header",
            name = "Support"
        },
        {
            type = "description",
            text = "Author: YFNatey, Xbox NA",
            width = "full"
        },
        {
            type = "description",
            text = "If you find this addon useful, consider supporting its development!",
            width = "full"
        },
        {
            type = "button",
            name = "Paypal",
            tooltip = "paypal.me/yfnatey",
            func = function() RequestOpenUnsafeURL("https://paypal.me/yfnatey") end,
            width = "half"
        },
        {
            type = "button",
            name = "Ko-fi",
            tooltip = "Ko-fi.me/yfnatey",
            func = function() RequestOpenUnsafeURL("https://Ko-fi.com/yfnatey") end,
            width = "half"
        },
    }

    LAM:RegisterAddonPanel(panelName, panelData)
    LAM:RegisterOptionControls(panelName, optionsData)
end

function CinematicCam:ConvertToScreenCoordinates(normalizedY)
    -- Normalize input range [0.0, 1.0] to screen coordinates
    local screenHeight = GuiRoot:GetHeight()
    return math.floor(normalizedY * screenHeight)
end

function CinematicCam:ConvertFromScreenCoordinates(pixelY)
    -- Convert absolute pixels back to normalized range
    local screenHeight = GuiRoot:GetHeight()
    return pixelY / screenHeight
end

-- Preview system for subtitle positioning
local previewTimer = nil
local isPreviewActive = false

-- Helper function to convert normalized position to screen coordinates
function CinematicCam:ConvertToScreenCoordinates(normalizedY)
    -- This should match the positioning logic used in your actual chunked dialogue
    -- Based on your ApplyChunkedTextPositioning function
    local screenHeight = GuiRoot:GetHeight()

    -- For cinematic preset, you use a fixed offset from center
    if self.savedVars.interaction.layoutPreset == "cinematic" then
        -- Convert 0-1 range to actual screen position
        -- 0.5 (50%) should be center (0 offset)
        -- 0.0 (0%) should be top
        -- 1.0 (100%) should be bottom
        local centerOffset = (normalizedY - 0.5) * screenHeight * 0.8 -- 0.8 to keep within reasonable bounds
        return centerOffset
    else
        -- For default preset, match your existing logic
        return (normalizedY * screenHeight) - (screenHeight / 2)
    end
end

function CinematicCam:ShowSubtitlePreview(yPosition)
    if not CinematicCam_PreviewContainer or not CinematicCam_PreviewText or not CinematicCam_PreviewBackground then
        return
    end

    isPreviewActive = true

    -- Convert percentage to screen coordinates to match actual chunked dialogue positioning
    local screenHeight = GuiRoot:GetHeight()
    local targetY = self:ConvertToScreenCoordinates(yPosition / 100)

    -- Position the background box
    CinematicCam_PreviewBackground:ClearAnchors()
    CinematicCam_PreviewBackground:SetAnchor(CENTER, GuiRoot, CENTER, 0, targetY)

    -- Set background properties (slightly opaque dark background)
    CinematicCam_PreviewBackground:SetColor(0, 0, 0, 0.7) -- Dark background with 70% opacity
    CinematicCam_PreviewBackground:SetDrawLayer(DL_CONTROLS)
    CinematicCam_PreviewBackground:SetDrawLevel(5)

    -- Position the preview text
    CinematicCam_PreviewText:ClearAnchors()
    CinematicCam_PreviewText:SetAnchor(CENTER, GuiRoot, CENTER, 0, targetY)

    -- Set preview text properties
    CinematicCam_PreviewText:SetText("Preview: Dialogue text will appear here during conversations")
    CinematicCam_PreviewText:SetColor(1, 1, 1, 1) -- White text
    CinematicCam_PreviewText:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    CinematicCam_PreviewText:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    CinematicCam_PreviewText:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    -- Apply current font settings to preview
    local fontString = self:BuildUserFontString()
    CinematicCam_PreviewText:SetFont(fontString)

    -- Show the preview container
    CinematicCam_PreviewContainer:SetHidden(false)
    CinematicCam_PreviewBackground:SetHidden(false)
    CinematicCam_PreviewText:SetHidden(false)

    -- Clear any existing timer
    if previewTimer then
        zo_removeCallLater(previewTimer)
    end

    -- Auto-hide preview after 3 seconds
    previewTimer = zo_callLater(function()
        self:HideSubtitlePreview()
    end, 3000)
end

function CinematicCam:HideSubtitlePreview()
    if not isPreviewActive then
        return
    end

    isPreviewActive = false

    -- Clear timer
    if previewTimer then
        zo_removeCallLater(previewTimer)
        previewTimer = nil
    end

    -- Hide preview elements
    if CinematicCam_PreviewContainer then
        CinematicCam_PreviewContainer:SetHidden(true)
    end
    if CinematicCam_PreviewBackground then
        CinematicCam_PreviewBackground:SetHidden(true)
    end
    if CinematicCam_PreviewText then
        CinematicCam_PreviewText:SetHidden(true)
    end
end

function CinematicCam:UpdatePreviewPosition(yPosition)
    if isPreviewActive then
        -- Update position in real-time while slider is being moved
        local targetY = self:ConvertToScreenCoordinates(yPosition / 100)

        if CinematicCam_PreviewBackground then
            CinematicCam_PreviewBackground:ClearAnchors()
            CinematicCam_PreviewBackground:SetAnchor(CENTER, GuiRoot, CENTER, 0, targetY)
        end

        if CinematicCam_PreviewText then
            CinematicCam_PreviewText:ClearAnchors()
            CinematicCam_PreviewText:SetAnchor(CENTER, GuiRoot, CENTER, 0, targetY)
        end

        -- Reset the auto-hide timer
        if previewTimer then
            zo_removeCallLater(previewTimer)
        end
        previewTimer = zo_callLater(function()
            self:HideSubtitlePreview()
        end, 3000)
    end
end

-- Initialize preview system
function CinematicCam:InitializePreviewSystem()
    -- Ensure preview container starts hidden
    if CinematicCam_PreviewContainer then
        CinematicCam_PreviewContainer:SetHidden(true)
    end

    -- Register for scene changes to hide preview when settings close
    local function hidePreviewOnSceneChange()
        self:HideSubtitlePreview()
    end

    -- Hook into various scene changes that might close settings
    SCENE_MANAGER:RegisterCallback("SceneStateChanged", function(scene, oldState, newState)
        if newState == SCENE_HIDING or newState == SCENE_HIDDEN then
            hidePreviewOnSceneChange()
        end
    end)
end
