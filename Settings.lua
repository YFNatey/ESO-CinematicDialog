--[[ TODO
Allow reposition dialoge options
Fix "images, coin, u46 descision images shopwing up as squares"
--]]
---=============================================================================
-- Settings Menu
--=============================================================================
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
                self.savedVars.interaction.forceThirdPersonVendor = value
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

        {
            type = "header",
            name = "Subtitle Settings",
        },
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
            choicesValues = { "default", "cinematic" },
            getFunc = function() return self.savedVars.interaction.layoutPreset end,
            setFunc = function(value)
                self.savedVars.interaction.layoutPreset = value
                currentRepositionPreset = value

                -- Force hide dialogue panels for center layouts
                if value == "cinematic" then
                    self.savedVars.interaction.ui.hidePanelsESO = true
                    if self.savedVars.interaction.ui.hidePanelsESO then
                        CinematicCam:HideDialoguePanels()
                    end
                    self.savedVars.interaction.subtitles.useChunkedDialogue = true
                elseif value == "default" then
                    self.savedVars.interaction.ui.hidePanelsESO = false
                    CinematicCam:ShowDialoguePanels()
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
            name = "Cinematic Subtitle Y Position",
            tooltip = "Adjust vertical position of dialogue text.",
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
                self:OnSubtitlePositionChanged(nil, normalizedY)
                -- Show preview when slider changes
                self:ShowSubtitlePreview(nil, value)
            end,
            width = "full",
        },
        {
            type = "slider",
            name = "Cinematic Subtitle X Position",
            tooltip = "Adjust horizontal position of dialogue text.",
            min = 0,
            max = 100,
            step = 1,
            getFunc = function()
                local normalizedPos = self.savedVars.interaction.subtitles.posX or 0.5
                return math.floor(normalizedPos * 100)
            end,
            setFunc = function(value)
                local normalizedX = value / 100
                self.savedVars.interaction.subtitles.posX = normalizedX
                self:OnSubtitlePositionChanged(normalizedX, nil)
                -- Show preview when slider changes
                self:ShowSubtitlePreview(value, nil)
            end,
            width = "full",
        },

        {
            type = "slider",
            name = "Player Dialog X Position",
            tooltip = "Adjust the horizontal position of the dialogue window. Move the slider to see a preview.",
            min = 10,
            max = 34,
            step = 2,
            getFunc = function()
                return math.floor(self.savedVars.interface.dialogueHorizontalOffset * 100)
            end,
            setFunc = function(value)
                self.savedVars.interface.dialogueHorizontalOffset = value / 100
                self:ApplyDefaultPosition()
                -- Show preview when slider changes
                self:ShowPlayerOptionsPreview(value)
            end,
            -- Real-time preview while dragging (if supported by your settings library)
            onValueChanged = function(value)
                if isPlayerOptionsPreviewActive then
                    self:UpdatePlayerOptionsPreviewPosition(value)
                end
            end,
            width = "full",
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
            type = "dropdown",
            name = "NPC Name Location",

            choices = { "Default", "Attached" },
            choicesValues = { "default", "prepended" },
            getFunc = function()
                return self.savedVars.npcNamePreset or "default"
            end,
            setFunc = function(value)
                self.savedVars.npcNamePreset = value
                -- Apply immediately if in dialogue
                local interactionType = GetInteractionType()
                if interactionType ~= INTERACTION_NONE then
                    self:ApplyNPCNamePreset(value)
                end
            end,
            width = "full",
        },
        {
        },
        {
            type = "colorpicker",
            name = "NPC Name Color",
            tooltip = "Color for NPC names when using 'Attached' location",
            getFunc = function()
                local color = self.savedVars.npcNameColor or namePresetDefaults.npcNameColor
                return color.r, color.g, color.b, color.a
            end,
            setFunc = function(r, g, b, a)
                self.savedVars.npcNameColor = { r = r, g = g, b = b, a = a }
                self:UpdateNPCNameColor()

                -- If we're in prepended mode and dialogue is active, refresh the text
                if self.savedVars.npcNamePreset == "prepended" then
                    local interactionType = GetInteractionType()
                    if interactionType ~= INTERACTION_NONE and chunkedDialogueData.isActive then
                        -- Re-process the dialogue with the new color
                        self:InterceptDialogueForChunking()
                    end
                end
            end,
            disabled = function()
                return self.savedVars.npcNamePreset == "default"
            end,
            width = "full",
        },

        --- FONT SETTINGS
        {
            type = "dropdown",
            name = "Font",
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

local playerOptionsPreviewTimer = nil
local isPlayerOptionsPreviewActive = false

function CinematicCam:ConvertFromScreenCoordinates(pixelY)
    -- Convert absolute pixels back to normalized range
    local screenHeight = GuiRoot:GetHeight()
    return pixelY / screenHeight
end

function CinematicCam:ShowPlayerOptionsPreview(xPosition)
    if not CinematicCam_PlayerOptionsPreviewContainer or not CinematicCam_PlayerOptionsPreviewText or not CinematicCam_PlayerOptionsPreviewBackground then
        return
    end

    isPlayerOptionsPreviewActive = true

    -- Convert percentage to screen coordinates
    local screenWidth = GuiRoot:GetWidth()
    local targetX = screenWidth * (xPosition / 100)

    -- Position the background box
    CinematicCam_PlayerOptionsPreviewBackground:ClearAnchors()
    CinematicCam_PlayerOptionsPreviewBackground:SetAnchor(CENTER, GuiRoot, CENTER, targetX, 0)

    -- Set background properties (slightly opaque dark background)
    CinematicCam_PlayerOptionsPreviewBackground:SetColor(0, 0, 0, 0.7) -- (r,g,b,opacity)
    CinematicCam_PlayerOptionsPreviewBackground:SetDrawLayer(DL_CONTROLS)
    CinematicCam_PlayerOptionsPreviewBackground:SetDrawLevel(5)

    -- Position the preview text
    CinematicCam_PlayerOptionsPreviewText:ClearAnchors()
    CinematicCam_PlayerOptionsPreviewText:SetAnchor(CENTER, GuiRoot, CENTER, targetX, 0)

    -- Set preview text properties
    CinematicCam_PlayerOptionsPreviewText:SetText("")
    CinematicCam_PlayerOptionsPreviewText:SetColor(1, 1, 1, 1)
    CinematicCam_PlayerOptionsPreviewText:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    CinematicCam_PlayerOptionsPreviewText:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    CinematicCam_PlayerOptionsPreviewText:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    -- Apply current font settings to preview
    local fontString = self:BuildUserFontString()
    CinematicCam_PlayerOptionsPreviewText:SetFont(fontString)

    -- Show the preview container
    CinematicCam_PlayerOptionsPreviewContainer:SetHidden(false)
    CinematicCam_PlayerOptionsPreviewBackground:SetHidden(false)
    CinematicCam_PlayerOptionsPreviewText:SetHidden(false)

    -- Clear any existing timer
    if playerOptionsPreviewTimer then
        zo_removeCallLater(playerOptionsPreviewTimer)
    end

    -- Hide preview after 3 seconds
    playerOptionsPreviewTimer = zo_callLater(function()
        self:HidePlayerOptionsPreview()
    end, 3000)
end

function CinematicCam:HidePlayerOptionsPreview()
    if not isPlayerOptionsPreviewActive then
        return
    end

    isPlayerOptionsPreviewActive = false

    -- Clear timer
    if playerOptionsPreviewTimer then
        zo_removeCallLater(playerOptionsPreviewTimer)
        playerOptionsPreviewTimer = nil
    end

    -- Hide preview elements
    if CinematicCam_PlayerOptionsPreviewContainer then
        CinematicCam_PlayerOptionsPreviewContainer:SetHidden(true)
    end
    if CinematicCam_PlayerOptionsPreviewBackground then
        CinematicCam_PlayerOptionsPreviewBackground:SetHidden(true)
    end
    if CinematicCam_PlayerOptionsPreviewText then
        CinematicCam_PlayerOptionsPreviewText:SetHidden(true)
    end
end

function CinematicCam:UpdatePlayerOptionsPreviewPosition(xPosition)
    if isPlayerOptionsPreviewActive then
        -- Update position while slider is being moved
        local screenWidth = GuiRoot:GetWidth()
        local targetX = (xPosition / 100) * screenWidth - (screenWidth / 2)

        if CinematicCam_PlayerOptionsPreviewBackground then
            CinematicCam_PlayerOptionsPreviewBackground:ClearAnchors()
            CinematicCam_PlayerOptionsPreviewBackground:SetAnchor(CENTER, GuiRoot, CENTER, targetX, 0)
        end

        if CinematicCam_PlayerOptionsPreviewText then
            CinematicCam_PlayerOptionsPreviewText:ClearAnchors()
            CinematicCam_PlayerOptionsPreviewText:SetAnchor(CENTER, GuiRoot, CENTER, targetX, 0)
        end

        -- Reset the auto-hide timer
        if playerOptionsPreviewTimer then
            zo_removeCallLater(playerOptionsPreviewTimer)
        end
        playerOptionsPreviewTimer = zo_callLater(function()
            self:HidePlayerOptionsPreview()
        end, 3000)
    end
end
