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
            type = "description",
            text = "Update Notes",
            tooltip =
            [[3.19 Fix text flashing when advancing through dialogue
3.18 Added Feature to hide player options until the character is finished speaking
• This excludes bankers, merchants, writ boards, or other non-story interactions]],
            width = "full",
        },
        {
            type = "header",
            name = "3rd Person Dialog Toggles",
        },

        {
            type = "checkbox",
            name = "Citizens",
            tooltip = "Keep camera in 3rd person when talking to regular characters",
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
            type = "checkbox",
            name = "Dye Stations",
            tooltip = "Keep camera in 3rd person when using dye stations",
            getFunc = function() return self.savedVars.interaction.forceThirdPersonDye end,
            setFunc = function(value)
                self.savedVars.interaction.forceThirdPersonDye = value
                self:InitializeInteractionSettings()
            end,
            width = "full",
        },
        --[[{
            type = "checkbox",
            name = "Notes & Boards",
            tooltip =
            "Keep camera in 3rd person when reading interactive notes and books (quest starting notes, items, writ boards, etc.)",
            getFunc = function() return self.savedVars.interaction.forceThirdPersonInteractiveNotes end,
            setFunc = function(value)
                self.savedVars.interaction.forceThirdPersonInteractiveNotes = value
                self:InitializeInteractionSettings()
            end,
            width = "full",
        },
`      --}]]

        {
            type = "header",
            name = "General Settings",
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
            type = "checkbox",
            name = "Hide Choices until Dialogue finishes",
            tooltip =
            "Cinematic layout only: Hide player response options until the character finishes speaking. ",
            getFunc = function() return self.savedVars.interaction.subtitles.hidePlayerOptionsUntilLastChunk end,
            setFunc = function(value)
                self.savedVars.interaction.subtitles.hidePlayerOptionsUntilLastChunk = value
            end,
            width = "full",
        },
        {
            type = "dropdown",
            name = "Style",
            tooltip =
            "Choose how dialogue elements are positioned:\n• Default: Original ESO positioning\n• Cinematic: Bottom centered with visual chunking\n*Reloadui if default subtitles are not showing",
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
                    -- For default preset, only enable visual chunking if explicitly set
                    -- But always allow timing processing for "Hide Choices Until Last Line"
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
            type = "dropdown",
            name = "Default Layout Backgrounds",
            tooltip = "Background options when using Default layout style",
            choices = { "ESO Default", "None" },
            choicesValues = { "esoDefault", "none" },
            getFunc = function()
                return self.savedVars.interface.defaultBackgroundMode or "esoDefault"
            end,
            setFunc = function(value)
                self.savedVars.interface.defaultBackgroundMode = value
                self:ApplyDefaultBackgroundSettings(value)
                if self.savedVars.interaction.layoutPreset == "default" then
                    local interactionType = GetInteractionType()
                    if interactionType ~= INTERACTION_NONE then
                        zo_callLater(function()
                            self:RefreshDialogueBackgrounds()
                        end, 50)
                    end
                end
            end,
            disabled = function()
                return self.savedVars.interaction.layoutPreset ~= "default"
            end,
            width = "full",
        },
        {
            type = "dropdown",
            name = "Cinematic Layout Backgrounds",
            tooltip = "Custom background options when using Cinematic layout style",
            --choices = { "All", "Only Subtitles", "Only Player Choices", "None" },
            --choicesValues = { "all", "subtitles", "playerOptions", "none" },
            choices = { "Subtitles", "None" },
            choicesValues = { "subtitles", "none" },
            getFunc = function()
                return self.savedVars.interface.cinematicBackgroundMode or "all"
            end,
            setFunc = function(value)
                self.savedVars.interface.cinematicBackgroundMode = value
                self:ApplyCinematicBackgroundSettings(value)

                if self.savedVars.interaction.layoutPreset == "cinematic" then
                    local interactionType = GetInteractionType()
                    if interactionType ~= INTERACTION_NONE then
                        zo_callLater(function()
                            self:RefreshDialogueBackgrounds()
                        end, 50)
                    end
                end
            end,
            disabled = function()
                return self.savedVars.interaction.layoutPreset ~= "cinematic"
            end,
            width = "full",
        },
        {
            type = "divider"
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
            name = "Default NPC Name Color",
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
        {
            type = "divider"
        },
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
            name = "Position Settings",
        },
        {
            type = "slider",
            name = "Cinematic Subtitle X Position",
            tooltip = "Adjust horizontal position of dialogue text. Limited range prevents text cutoff.",
            min = 30, -- Prevents positioning too far left
            max = 70, -- Prevents positioning too far right
            step = 1,
            getFunc = function()
                local normalizedPos = self.savedVars.interaction.subtitles.posX or 0.5
                return math.floor(normalizedPos * 100)
            end,
            setFunc = function(value)
                local normalizedX = value / 100
                self.savedVars.interaction.subtitles.posX = normalizedX
                self:OnSubtitlePositionChanged(normalizedX, nil)
                CinematicCam:ShowSubtitlePreview(value, nil)
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
                CinematicCam:OnSubtitlePositionChanged(nil, normalizedY)
                -- Show preview when slider changes
                CinematicCam:ShowSubtitlePreview(nil, value)
            end,
            width = "full",
        },

        --[[ {
            type = "slider",
            name = "Player Choices X Position",
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
            type = "slider",
            name = "Player Choices Y Position",
            tooltip = "Adjust the vertical position of the dialogue window.",
            min = 0,
            max = 2000,
            step = 30,
            getFunc = function()
                return math.floor(self.savedVars.interface.dialogueVerticalOffset)
            end,
            setFunc = function(value)
                self.savedVars.interface.dialogueVerticalOffset = value

                self:ApplyDefaultPosition()
            end,
            width = "full",
        },
        {
            type = "header",
            name = "Name Settings",
        --},]]

        --[[{
            type = "checkbox",
            name = "Show Your Name",
            tooltip = "Show your character's name instead of NPC name in dialogue",
            getFunc = function() return self.savedVars.usePlayerName end,
            setFunc = function(value)
                self.savedVars.usePlayerName = value

                -- Apply immediately if in dialogue
                local interactionType = GetInteractionType()
                if interactionType ~= INTERACTION_NONE then
                    self:ApplyNPCNamePreset(self.savedVars.npcNamePreset)
                end
            end,
            disabled = function()
                return self.savedVars.npcNamePreset == "default"
            end,
            width = "full",
        },
        {
            type = "colorpicker",
            name = "Player Name Color",
            tooltip = "Color for your character's name when displayed",
            getFunc = function()
                local color = self.savedVars.playerNameColor
                return color.r, color.g, color.b, color.a
            end,
            setFunc = function(r, g, b, a)
                self.savedVars.playerNameColor = { r = r, g = g, b = b, a = a }
                -- Apply immediately if in dialogue
                local interactionType = GetInteractionType()
                if interactionType ~= INTERACTION_NONE then
                    self:ApplyNPCNamePreset(self.savedVars.npcNamePreset)
                end
            end,
            disabled = function()
                return not self.savedVars.usePlayerName or self.savedVars.npcNamePreset == "default"
            end,
            width = "full",
        --},]]
        --[[{
            type = "editbox",
            name = "NPC Name Filter", -- Give it a proper name
            tooltip = "Enter partial NPC name to save custom color for",
            getFunc = function()
                return self.savedVars.npcNameFilter or ""
            end,
            setFunc = function(value)
                self.savedVars.npcNameFilter = value or ""
            end,
            width = "full",
        },
        --TODO color the player inputted name  npc spoken to, generate a hash and save to variables. "does not need the entire name (Lyris) = Lyris Titanborn"
        {
            type = "colorpicker",
            name = "Save Color for(Inputted npc Name)",
            tooltip = "Give unique color to the last NPC spoken to.",
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
        {
            type = "divider"
        },

        ]]

        --- FONT SETTINGS

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
            type = "header",
            name = "Support"
        },
        {
            {
                type = "button",
                name = "Changelog",
                tooltip = [[Version 3.14
• Added option to show player options when NPC is finished speaking. Shows immediately for vendors, bankers, writs]],
                func = function() end,
                width = "full"
            },
        },
        {
            type = "divider",
            width = "full"
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

---=============================================================================
function CinematicCam:ConvertFromScreenCoordinates(pixelY)
    -- Convert absolute pixels back to normalized range
    local screenHeight = GuiRoot:GetHeight()
    return pixelY / screenHeight
end

---
-- Converts normalized (0-1) X and Y coordinates to actual screen coordinates.
-- Used for positioning UI elements relative to the screen size and user settings.
-- @param normalizedX number: X position as a value between 0 and 1
-- @param normalizedY number: Y position as a value between 0 and 1
-- @return number, number: The calculated screen X and Y positions
function CinematicCam:ConvertToScreenCoordinates(normalizedX, normalizedY)
    local screenWidth = GuiRoot:GetWidth()
    local screenHeight = GuiRoot:GetHeight()

    local targetX = 0 -- Default to center for X
    local targetY = 0 -- Default to center for Y

    if normalizedX then
        -- Convert 0-1 range to actual screen position
        -- 0.5 (50%) should be center (0 offset)
        -- 0.0 (0%) should be left, 1.0 (100%) should be right
        targetX = (normalizedX - 0.5) * screenWidth * 0.8 -- 0.8 to keep within reasonable bounds
    end

    if normalizedY then
        -- Cinematic uses a fixed offset from center
        if self.savedVars.interaction.layoutPreset == "cinematic" then
            targetY = (normalizedY - 0.5) * screenHeight * 0.8
        else
            -- For default preset, match your existing logic
            targetY = (normalizedY * screenHeight) - (screenHeight / 2)
        end
    end

    return targetX, targetY
end

function CinematicCam:OnSubtitlePositionChanged(newX, newY)
    -- Update saved variables
    if newX then
        self.savedVars.interaction.subtitles.posX = newX
    end
    if newY then
        self.savedVars.interaction.subtitles.posY = newY
    end


    local interactionType = GetInteractionType()
    if interactionType ~= INTERACTION_NONE then
        self:ApplySubtitlePosition()
        if CinematicCam.chunkedDialogueData.isActive then
            self:ApplyChunkedTextPositioning()
        end
    end
end

local playerOptionsPreviewTimer = nil
local isPlayerOptionsPreviewActive = false
local previewTimer = nil
local isPreviewActive = false
---=============================================================================
-- Player Options preview
--=============================================================================
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

---=============================================================================
-- Subtitle Preview
--=============================================================================
function CinematicCam:ShowSubtitlePreview(xPosition, yPosition)
    if not CinematicCam_PreviewContainer or not CinematicCam_PreviewText or not CinematicCam_PreviewBackground then
        return
    end

    isPreviewActive = true

    -- Convert percentage to screen coordinates
    local normalizedX = xPosition and (xPosition / 100) or (self.savedVars.interaction.subtitles.posX or 0.5)
    local normalizedY = yPosition and (yPosition / 100) or (self.savedVars.interaction.subtitles.posY or 0.7)

    local targetX, targetY = self:ConvertToScreenCoordinates(normalizedX, normalizedY)

    -- Position the background box
    CinematicCam_PreviewBackground:ClearAnchors()
    CinematicCam_PreviewBackground:SetAnchor(CENTER, GuiRoot, CENTER, targetX, targetY)

    -- Set background properties with the texture
    CinematicCam_PreviewBackground:SetColor(1, 1, 1, 0.8)
    CinematicCam_PreviewBackground:SetDrawLayer(DL_CONTROLS)
    CinematicCam_PreviewBackground:SetDrawLevel(5)

    -- Position the preview text
    CinematicCam_PreviewText:ClearAnchors()
    CinematicCam_PreviewText:SetAnchor(CENTER, GuiRoot, CENTER, targetX, targetY)

    -- Set preview text properties
    CinematicCam_PreviewText:SetColor(1, 1, 1, 1) -- White text
    CinematicCam_PreviewText:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    CinematicCam_PreviewText:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    CinematicCam_PreviewText:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    CinematicCam_PreviewText:SetText("This is a preview of subtitle positioning")

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

function CinematicCam:UpdatePreviewPosition(xPosition, yPosition)
    if isPreviewActive then
        -- Update position in real-time while slider is being moved
        local normalizedX = xPosition and (xPosition / 100) or (self.savedVars.interaction.subtitles.posX or 0.5)
        local normalizedY = yPosition and (yPosition / 100) or (self.savedVars.interaction.subtitles.posY or 0.7)

        local targetX, targetY = self:ConvertToScreenCoordinates(normalizedX, normalizedY)

        if CinematicCam_PreviewBackground then
            CinematicCam_PreviewBackground:ClearAnchors()
            CinematicCam_PreviewBackground:SetAnchor(CENTER, GuiRoot, CENTER, targetX, targetY)
        end

        if CinematicCam_PreviewText then
            CinematicCam_PreviewText:ClearAnchors()
            CinematicCam_PreviewText:SetAnchor(CENTER, GuiRoot, CENTER, targetX, targetY)
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
    -- Ensure preview containers start hidden
    if CinematicCam_PreviewContainer then
        CinematicCam_PreviewContainer:SetHidden(true)
    end

    if CinematicCam_PlayerOptionsPreviewContainer then
        CinematicCam_PlayerOptionsPreviewContainer:SetHidden(true)
    end

    -- Register for scene changes to hide preview when settings close
    local function hidePreviewOnSceneChange()
        self:HideSubtitlePreview()
        self:HidePlayerOptionsPreview()
    end

    -- Hook into various scene changes that might close settings
    SCENE_MANAGER:RegisterCallback("SceneStateChanged", function(scene, oldState, newState)
        if newState == SCENE_HIDING or newState == SCENE_HIDDEN then
            hidePreviewOnSceneChange()
        end
    end)
end

---=============================================================================
-- Backgrounds
--=============================================================================
function CinematicCam:ApplyDefaultBackgroundSettings(backgroundMode)
    if backgroundMode == "esoDefault" then
        self.savedVars.interaction.ui.hidePanelsESO = false
        self:ShowDialoguePanels()
    elseif backgroundMode == "none" then
        self.savedVars.interaction.ui.hidePanelsESO = true
        self:HideDialoguePanels()
    end
end

function CinematicCam:ApplyCinematicBackgroundSettings(backgroundMode)
    self.savedVars.interface.useSubtitleBackground = (backgroundMode == "all" or backgroundMode == "subtitles")
    self.savedVars.interface.usePlayerOptionsBackground = (backgroundMode == "all" or backgroundMode == "playerOptions")
end

function CinematicCam:GetCurrentBackgroundMode()
    local layoutPreset = self.savedVars.interaction.layoutPreset

    if layoutPreset == "default" then
        return self.savedVars.interface.defaultBackgroundMode or "esoDefault"
    else
        return self.savedVars.interface.cinematicBackgroundMode or "all"
    end
end

function CinematicCam:ShouldShowSubtitleBackground()
    local layoutPreset = self.savedVars.interaction.layoutPreset

    -- Only show alternate backgrounds in cinematic mode
    if layoutPreset ~= "cinematic" then
        return false
    end

    local backgroundMode = self.savedVars.interface.cinematicBackgroundMode or "all"
    return backgroundMode == "all" or backgroundMode == "subtitles"
end

function CinematicCam:ShouldShowPlayerOptionsBackground()
    local layoutPreset = self.savedVars.interaction.layoutPreset

    -- Only show alternate backgrounds in cinematic mode
    if layoutPreset ~= "cinematic" then
        return false
    end

    local backgroundMode = self.savedVars.interface.cinematicBackgroundMode or "all"
    return backgroundMode == "all" or backgroundMode == "playerOptions"
end

function CinematicCam:RefreshDialogueBackgrounds()
    -- Update subtitle background
    local subtitleBackground = CinematicCam.chunkedDialogueData.backgroundControl
    if subtitleBackground then
        if self:ShouldShowSubtitleBackground() and CinematicCam.chunkedDialogueData.isActive then
            subtitleBackground:SetHidden(false)
            self:ResizeBackgroundToText()
        else
            subtitleBackground:SetHidden(true)
        end
    end

    -- Update player options background
    local playerOptionsBackground = CinematicCam.chunkedDialogueData.playerOptionsBackgroundControl
    if playerOptionsBackground then
        if self:ShouldShowPlayerOptionsBackground() then
            self:ShowPlayerOptionsBackground()
            self:UpdatePlayerOptionsBackgroundSize()
        else
            self:HidePlayerOptionsBackground()
        end
    end
end

function CinematicCam:ShowPlayerOptionsBackground()
    local background = CinematicCam.chunkedDialogueData.playerOptionsBackgroundControl
    if background and self:ShouldShowPlayerOptionsBackground() then
        background:SetHidden(false)
        self:UpdatePlayerOptionsBackgroundSize()
    end
end

function CinematicCam:HidePlayerOptionsBackground()
    local background = CinematicCam.chunkedDialogueData.playerOptionsBackgroundControl
    if background then
        background:SetHidden(true)
    end
end

function CinematicCam:UpdatePlayerOptionsBackgroundSize()
    local background = CinematicCam.chunkedDialogueData.playerOptionsBackgroundControl
    if not background or not self:ShouldShowPlayerOptionsBackground() then
        return
    end

    -- Find player options container to size background appropriately
    local playerOptionsContainer = _G["ZO_InteractWindow_GamepadContainerInteract"]
    if playerOptionsContainer and not playerOptionsContainer:IsHidden() then
        local width, height = playerOptionsContainer:GetDimensions()
        local padding = 30

        background:ClearAnchors()
        background:SetAnchor(CENTER, playerOptionsContainer, CENTER, 0, 0)
        background:SetDimensions(width + padding, height + padding)
        background:SetHidden(false)
    end
end

function CinematicCam:OnLayoutPresetChanged(newPreset)
    local currentBackgroundMode = self.savedVars.interface.backgroundMode

    if newPreset == "default" then
        if currentBackgroundMode ~= "esoDefault" and currentBackgroundMode ~= "none" then
            self.savedVars.interface.backgroundMode = "esoDefault"
        end
    elseif newPreset == "cinematic" then
        if currentBackgroundMode == "esoDefault" then
            self.savedVars.interface.backgroundMode = "all"
        end
    end

    self:ApplyBackgroundSettings()
    local interactionType = GetInteractionType()
    if interactionType ~= INTERACTION_NONE then
        zo_callLater(function()
            self:RefreshDialogueBackgrounds()
        end, 50)
    end
end
