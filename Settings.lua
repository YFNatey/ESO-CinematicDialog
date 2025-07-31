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
            name = "Subtitle Location",
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
        }, {
        type = "description",
        text = "/reloadui for location presets to take effect",
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
            getFunc = function() return CinematicCam.savedVars.interaction.auto.autoLetterboxMount end,
            setFunc = function(value) CinematicCam.savedVars.interaction.auto.autoLetterboxMount = value end,
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
                CinematicCam.savedVars.mountLetterboxDelay = value
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
