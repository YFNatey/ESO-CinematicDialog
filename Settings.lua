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
            type = "checkbox",
            name = "Enable Black Bars with Cinematic Mode",
            tooltip = "When enabled, black bars will appear when toggling cinematic mode",
            getFunc = function() return self.savedVars.letterboxEnabled end,
            setFunc = function(value)
                self.savedVars.letterboxEnabled = value
                -- If cinematic mode is active, update letterbox visibility
                if next(hiddenElements) then
                    if value then
                        self:ShowLetterbox()
                    else
                        self:HideLetterbox()
                    end
                end
            end,
            width = "full",
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
            tooltip = "Automatically calculate letterbox size for your screen",
            func = function()
                self:CalculateLetterboxSize()
                if not CinematicCam_LetterboxTop:IsHidden() then
                    CinematicCam_LetterboxTop:SetHeight(self.savedVars.letterboxSize)
                    CinematicCam_LetterboxBottom:SetHeight(self.savedVars.letterboxSize)
                end
                d("Letterbox size auto-calculated: " .. self.savedVars.letterboxSize)
            end,
            width = "half",
        },
        {
            type = "header",
            name = "UI Controls",
        },
        {
            type = "description",
            text =
            "Cinematic Camera hides standard UI elements like health bars, action bars, and compass when in cinematic mode. Use the commands below to toggle cinematic mode.",
            width = "full",
        },
        {
            type = "description",
            text =
            "Commands:\n/hideui - Toggle cinematic mode (hide UI elements)\n/letterbox - Toggle letterbox bars only\n/cinematic - Same as /hideui",
            width = "full",
        },
        {
            type = "button",
            name = "Toggle Cinematic Mode",
            tooltip = "Toggle UI hiding and letterbox bars",
            func = function()
                self:ToggleUI()
            end,
            width = "half",
        },
        {
            type = "button",
            name = "Toggle Letterbox Only",
            tooltip = "Toggle just the letterbox bars",
            func = function()
                self:ToggleLetterbox()
            end,
            width = "half",
        },

        {
            type = "header",
            name = "Custom UI Elements",
        },
        {
            type = "description",
            text =
            "Add custom UI elements to hide in cinematic mode. Enter the name of a UI element to add it to the list.",
            width = "full",
        },
        {
            type = "editbox",
            name = "Add UI Element",
            tooltip = "Enter the name of a UI element to hide in cinematic mode",
            getFunc = function() return "" end,
            setFunc = function(text)
                if text and text ~= "" then
                    -- Check if element exists
                    local element = _G[text]
                    if element then
                        -- Add to saved variables
                        self.savedVars.hideUiElements[text] = true
                        d("Added UI element to hide: " .. text)
                    else
                        d("UI element not found: " .. text)
                    end
                end
            end,
            width = "full",
        },
        {
            type = "button",
            name = "Clear Custom UI Elements",
            tooltip = "Clear all custom UI elements",
            func = function()
                self.savedVars.hideUiElements = {}
                d("Cleared custom UI elements")
            end,
            width = "full",
        },
    }

    LAM:RegisterAddonPanel(panelName, panelData)
    LAM:RegisterOptionControls(panelName, optionsData)
end
