---=============================================================================
-- Settings Menu
--=============================================================================
-- Create LibAddonMenu-2.0 settings panel
function CinematicCam:CreateSettingsMenu()
    local LAM = LibAddonMenu2

    if not LAM then
        d("LibAddonMenu-2.0 is required for the settings menu. You can still use slash commands.")
        return
    end
    local choices, choicesValues = self:GetFontChoices()

    local panelName = "CinematicCamOptions"

    local panelData = {
        type = "panel",
        name = "Third Person Dialogue",
        displayName = "Third Person Dialogue",
        author = "YFNatey",
        version = "1.0",
        slashCommand = "/cinematicsettings",
        registerForRefresh = true,
        registerForDefaults = true,
    }

    local optionsData = {

        {
            type = "header",
            name = "3rd Person Dialogue Settings",
        },
        {
            type = "checkbox",
            name = "NPC Dialogue UI Panels",
            tooltip = "Hide the dialogue window, and choice panels during 3rd person dialogue",
            getFunc = function() return not self.savedVars.hideDialoguePanels end,
            setFunc = function(value)
                self.savedVars.hideDialoguePanels = not value
            end,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Subtitles",
            getFunc = function() return not self.savedVars.hideNPCText end,
            setFunc = function(value)
                self.savedVars.hideNPCText = not value
            end,
            width = "full",
        },
        {
            type = "checkbox",
            name = "3rd Person - NPC Dialogue",
            tooltip = "Keep camera in 3rd person when talking to NPCs",
            getFunc = function() return self.savedVars.forceThirdPersonDialogue end,
            setFunc = function(value)
                self.savedVars.forceThirdPersonDialogue = value
                self:InitializeInteractionSettings()
            end,
            width = "full",
        },
        {
            type = "checkbox",
            name = "3rd Person - Vendors/Stores",
            tooltip = "Keep camera in 3rd person when interacting with vendors and stores",
            getFunc = function() return self.savedVars.forceThirdPersonVendor end,
            setFunc = function(value)
                self.savedVars.forceThirdPersonVendor = value
                self:InitializeInteractionSettings()
            end,
            width = "full",
        },
        {
            type = "checkbox",
            name = "3rd Person - Banks",
            tooltip = "Keep camera in 3rd person when using banks",
            getFunc = function() return self.savedVars.forceThirdPersonBank end,
            setFunc = function(value)
                self.savedVars.forceThirdPersonBank = value
                self:InitializeInteractionSettings()
            end,
            width = "full",
        },
        {
            type = "checkbox",
            name = "3rd Person - Quest Interactions",
            tooltip = "Keep camera in 3rd person during quest interactions",
            getFunc = function() return self.savedVars.forceThirdPersonQuest end,
            setFunc = function(value)
                self.savedVars.forceThirdPersonQuest = value
                self:InitializeInteractionSettings()
            end,
            width = "full",
        },
        {
            type = "checkbox",
            name = "3rd Person - Crafting Stations",
            tooltip = "Keep camera in 3rd person when using crafting stations",
            getFunc = function() return self.savedVars.forceThirdPersonCrafting end,
            setFunc = function(value)
                self.savedVars.forceThirdPersonCrafting = value
                self:InitializeInteractionSettings()
            end,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Auto Black Bars During Dialogue",
            tooltip = "Automatically show black bars during dialogue interactions (conversations and quests)",
            getFunc = function() return self.savedVars.autoLetterboxDialogue end,
            setFunc = function(value)
                self.savedVars.autoLetterboxDialogue = value
            end,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Auto Black Bars on Mount",
            tooltip = "Automatically show black bars when mounting",
            getFunc = function() return CinematicCam.savedVars.autoLetterboxMount end,
            setFunc = function(value) CinematicCam.savedVars.autoLetterboxMount = value end,
            width = "full",
        },
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
            getFunc = function() return self.savedVars.selectedFont end,
            setFunc = function(value)
                self.savedVars.selectedFont = value
                self:OnFontChanged()
            end,
            width = "full",
        },
        {
            type = "slider",
            name = "Font Size",
            min = 10,
            max = 32,
            step = 1,
            getFunc = function() return self.savedVars.customFontSize end,
            setFunc = function(value)
                self.savedVars.customFontSize = value
                self:OnFontChanged()
            end,
            width = "full",
        },
        {
            type = "slider",
            name = "Font Scale Multiplier",
            min = 0.5,
            max = 2.0,
            step = 0.1,
            getFunc = function() return self.savedVars.fontScale end,
            setFunc = function(value)
                self.savedVars.fontScale = value
                self:OnFontChanged()
            end,
            width = "full",
        },
        {
            type = "button",
            name = "Reset Font Settings",
            tooltip = "Reset font settings to default ESO style",
            func = function()
                self.savedVars.selectedFont = "ESO_Standard"
                self.savedVars.customFontSize = 18
                self.savedVars.fontScale = 1.0
                self:OnFontChanged()
            end,
            width = "half",
        },
        {
            type = "header",
            name = "Dialogue Layout Settings",
        },
        {
            type = "description",
            text = "Choose how dialogue elements are positioned on screen during 3rd person interactions.",
            width = "full",
        },
        {
            type = "dropdown",
            name = "Layout Preset",
            tooltip =
            "Choose how dialogue elements are positioned:\n• Default: Original ESO positioning\n• Subtle Center: Slight adjustment toward screen center\n• Full Center: Complete center screen positioning",
            choices = { "Default ESO Layout", "Subtle Center", "Full Center Screen" },
            choicesValues = { "default", "subtle_center", "full_center" },
            getFunc = function() return self.savedVars.dialogueLayoutPreset end,
            setFunc = function(value)
                self.savedVars.dialogueLayoutPreset = value
                currentRepositionPreset = value
                d("Dialogue layout preset changed to: " .. value)

                -- Apply immediately if in dialogue
                local interactionType = GetInteractionType()
                if interactionType ~= INTERACTION_NONE then
                    zo_callLater(function()
                        self:ApplyDialogueRepositioning()
                    end, 100)
                end
            end,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Coordinate with Black Bars",
            tooltip = "Adjust dialogue positioning when black bars are active for optimal visual balance",
            getFunc = function() return self.savedVars.coordinateWithLetterbox end,
            setFunc = function(value)
                self.savedVars.coordinateWithLetterbox = value
            end,
            width = "full",
        },
        {
            type = "button",
            name = "Preview Current Layout",
            tooltip = "Test the current layout preset (requires being in dialogue with an NPC)",
            func = function()
                local interactionType = GetInteractionType()
                if interactionType ~= INTERACTION_NONE then
                    self:ApplyDialogueRepositioning()
                    d("Applied current layout preset")
                else
                    d("Start a dialogue with an NPC to preview layout changes")
                end
            end,
            width = "half",
        },
        {
            type = "button",
            name = "Reset to Default",
            tooltip = "Reset dialogue layout to original ESO positioning",
            func = function()
                self.savedVars.dialogueLayoutPreset = "default"
                currentRepositionPreset = "default"

                -- Apply immediately if in dialogue
                local interactionType = GetInteractionType()
                if interactionType ~= INTERACTION_NONE then
                    zo_callLater(function()
                        self:RestoreDefaultPositions()
                    end, 100)
                end

                d("Dialogue layout reset to default")
            end,
            width = "half",
        },
        {
            type = "divider",
            width = "full"
        },
        width = "full",
        {
            type = "header",
            name = "Black Bars Settings",
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
            type = "checkbox",
            name = "Auto-size Black Bars",
            tooltip = "When enabled, black bars will be sized automatically to create a cinematic aspect ratio",
            getFunc = function() return self.savedVars.autoSizeLetterbox end,
            setFunc = function(value)
                self.savedVars.autoSizeLetterbox = value
                if value then
                    -- Recalculate size now
                    self:CalculateLetterboxSize()
                    -- Apply if visible
                    if not CinematicCam_LetterboxTop:IsHidden() then
                        CinematicCam_LetterboxTop:SetHeight(self.savedVars.letterboxSize)
                        CinematicCam_LetterboxBottom:SetHeight(self.savedVars.letterboxSize)
                    end
                end
            end,
            width = "full",
        },
        {
            type = "slider",
            name = "Black Bar Size",
            tooltip = "Adjust the height of the bars",
            min = 10,
            max = 300,
            step = 5,
            getFunc = function() return self.savedVars.letterboxSize end,
            setFunc = function(value)
                self.savedVars.letterboxSize = value
                -- Apply new size if letterbox is visible
                if not CinematicCam_LetterboxTop:IsHidden() then
                    CinematicCam_LetterboxTop:SetHeight(value)
                    CinematicCam_LetterboxBottom:SetHeight(value)
                end
            end,
            disabled = function() return self.savedVars.autoSizeLetterbox end,
            width = "full",
        },
        {
            type = "slider",
            name = "Black Bar Opacity",
            tooltip = "Adjust the opacity of the bars (1.0 = solid black)",
            min = 0.5,
            max = 1.0,
            step = 0.05,
            getFunc = function() return self.savedVars.letterboxOpacity end,
            setFunc = function(value)
                self.savedVars.letterboxOpacity = value
                -- Apply new opacity if letterbox is visible
                if not CinematicCam_LetterboxTop:IsHidden() then
                    CinematicCam_LetterboxTop:SetColor(0, 0, 0, value)
                    CinematicCam_LetterboxBottom:SetColor(0, 0, 0, value)
                end
            end,
            width = "full",
        },
        {
            type = "button",
            name = "Reset to Default Size",
            func = function()
                self.savedVars.letterboxSize = defaults.letterboxSize
                if not CinematicCam_LetterboxTop:IsHidden() then
                    CinematicCam_LetterboxTop:SetHeight(defaults.letterboxSize)
                    CinematicCam_LetterboxBottom:SetHeight(defaults.letterboxSize)
                end
                d("Letterbox size reset to default: " .. defaults.letterboxSize)
            end,
            width = "half",
        },
        {
            type = "button",
            name = "Auto-calculate Size",
            tooltip = "Automatically calculate black bar size for your screen",
            func = function()
                self:CalculateLetterboxSize()
                if not CinematicCam_LetterboxTop:IsHidden() then
                    CinematicCam_LetterboxTop:SetHeight(self.savedVars.letterboxSize)
                    CinematicCam_LetterboxBottom:SetHeight(self.savedVars.letterboxSize)
                end
            end,
            width = "half",
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
