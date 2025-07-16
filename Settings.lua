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

    local panelName = "CinematicCamOptions"

    local panelData = {
        type = "panel",
        name = "Cinematic Camera",
        displayName = "Cinematic Camera",
        author = "YFNatey",
        version = "1.0",
        slashCommand = "/cinematicsettings",
        registerForRefresh = true,
        registerForDefaults = true,
    }

    local optionsData = {
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
            type = "header",
            name = "3rd Person Dialogue Settings",
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
            name = "Auto black bars During Dialogue",
            tooltip = "Automatically show black bars during 3rd person dialogue",
            getFunc = function() return self.savedVars.autoLetterboxDialogue end,
            setFunc = function(value)
                self.savedVars.autoLetterboxDialogue = value
            end,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Auto Hide UI During Dialogue",
            tooltip = "Automatically hide UI elements during 3rd person dialogue",
            getFunc = function() return self.savedVars.autoHideUIDialogue end,
            setFunc = function(value)
                self.savedVars.autoHideUIDialogue = value
            end,
            width = "full",
        },
    }

    LAM:RegisterAddonPanel(panelName, panelData)
    LAM:RegisterOptionControls(panelName, optionsData)
end
