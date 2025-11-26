---=============================================================================
-- Settings Menu
--=============================================================================
-- Helper function to create option names with update indicators
function CinematicCam:GetOptionName(baseName, isNewFeature)
    if isNewFeature and not self.savedVars.hasReloadedSinceUpdate then
        return "|c00FF00●|r" .. baseName
    end
    return baseName
end

function CinematicCam:CreateSettingsMenu()
    local LAM = LibAddonMenu2

    if not LAM then
        return
    end
    local choices, choicesValues = self:GetFontChoices()

    local panelName = "CinematicCamOptions"

    local panelData = {
        type = "panel",
        name = "Cinematic Dialogue",
        displayName = "Cinemtaic Dialogue",
        author = "YFNatey",
        version = "1.0",
        slashCommand = "/cinematicsettings",
        registerForRefresh = true,
        registerForDefaults = true,
    }

    local optionsData = {

        {
            type = "dropdown",
            name = "Custom Presets",
            tooltip = function()
                local slot = self.selectedPresetSlot or 1
                return self:GetPresetTooltip(slot)
            end,
            choices = {
                self:GetSlotDisplayName(1),
                self:GetSlotDisplayName(2),
                self:GetSlotDisplayName(3)
            },
            choicesValues = { 1, 2, 3 },
            choicesTooltips = {
                function() return self:GetPresetTooltip(1) end,
                function() return self:GetPresetTooltip(2) end,
                function() return self:GetPresetTooltip(3) end
            },
            getFunc = function()
                return self.selectedPresetSlot
            end,
            setFunc = function(value)
                self.selectedPresetSlot = value

                zo_callLater(function()
                    local tooltip = LibAddonMenu2 and LibAddonMenu2.tooltip
                    if tooltip and not tooltip:IsHidden() then
                        tooltip:ClearLines()

                        tooltip:AddLine(self:GetPresetTooltip(value), "", ZO_TOOLTIP_DEFAULT_COLOR:UnpackRGB())
                    end
                end, 10)
            end,
            width = "full",
        },
        {

        },
        {
            type = "button",
            name = function()
                local slot = self.selectedPresetSlot or 1
                local slotName = self:GetSlotDisplayName(slot)


                return "[Apply " .. slotName .. " Preset]"
            end,
            tooltip = "Button to apply the selected preset settings",
            func = function()
                local slot = self.selectedPresetSlot or 1
                local slotName = self:GetSlotDisplayName(slot)
                self:LoadFromPresetSlot(slot)
                CinematicCam:ShowPresetNotificationUI(slotName)
            end,
            width = "half",
            disabled = function()
                local slot = self.selectedPresetSlot or 1
                local slotKey = "slot" .. slot
                local presetSlot = self.savedVars.customPresets and self.savedVars.customPresets[slotKey]
                return not (presetSlot and presetSlot.settings)
            end,
        },
        {
            type = "button",
            name = function()
                local slot = self.selectedPresetSlot or 1
                local slotName = self:GetSlotDisplayName(slot)


                return "[Save Settings to " .. slotName .. "]"
            end,
            tooltip = "Button to save all settings to the current preset",
            func = function()
                local slot = self.selectedPresetSlot or 1
                self:SaveToPresetSlot(slot)
            end,
            width = "half",
        },
        {
            type = "button",
            name = function()
                local slot = self.selectedPresetSlot or 1
                local slotName = self:GetSlotDisplayName(slot)


                return "[Delete Saved Settings for " .. slotName .. "]"
            end,
            tooltip = "Button to clear all settings from the selected preset",
            func = function()
                local slot = self.selectedPresetSlot or 1
                self:ClearPresetSlot(slot)
                local slotName = self:GetSlotDisplayName(slot)

                local notification = _G["CinematicCam_UpdateNotification"]
                local notificationText = _G["CinematicCam_UpdateNotificationText"]
                if not notification then
                    return
                end

                notification:SetHidden(false)
                notification:SetAlpha(0)
                notificationText:SetText("Cinematic Dialogue: Deleted " .. slotName)

                -- Start fade in animation
                self:AnimateUpdateNotification(notification, true)

                -- Auto-hide wafter 5 seconds
                zo_callLater(function()
                    self:HideUpdateNotification()
                end, 4000)
            end,
            width = "half",
            disabled = function()
                local slot = self.selectedPresetSlot or 1
                local slotKey = "slot" .. slot
                local presetSlot = self.savedVars.customPresets and self.savedVars.customPresets[slotKey]
                return not (presetSlot and presetSlot.settings)
            end,
        },
        {
            type = "checkbox",
            name = "Auto Presets",
            tooltip = "Automatically apply the correct preset in homes, overland, or dungeon zones",
            getFunc = function() return self.savedVars.autoSwapPresets end,
            setFunc = function(value)
                self.savedVars.autoSwapPresets = value
            end,
            width = "full",
        },

        {
            type = "header",
            name = "General Settings",
        },
        {
            type = "checkbox",
            name = "Subtitles",
            tooltip = "Show NPC subtitles during dialogue",
            getFunc = function() return not self.savedVars.interaction.subtitles.isHidden end,
            setFunc = function(value)
                self.savedVars.interaction.subtitles.isHidden = not value
                self:UpdateChunkedTextVisibility()
                self.presetPending = true
            end,
            width = "full",
        },
        {
            type = "dropdown",
            name = "Subtitle Style",
            tooltip =
            "Default: Original style\n Cinematic: Centered captions with additional customization\n",
            choices = { "Default", "Cinematic" },
            choicesValues = { "default", "cinematic" },
            getFunc = function() return self.savedVars.interaction.layoutPreset end,
            setFunc = function(value)
                self.savedVars.interaction.layoutPreset = value
                currentRepositionPreset = value

                -- Set NPC name location based on style
                if value == "cinematic" then
                    self.savedVars.npcNamePreset = "prepended"
                    self.savedVars.interaction.ui.hidePanelsESO = true
                    if self.savedVars.interaction.ui.hidePanelsESO then
                        CinematicCam:HideDialoguePanels()
                    end
                    self.savedVars.interaction.subtitles.useChunkedDialogue = true
                    self.presetPending = false
                    self.vanillaPending = false
                elseif value == "default" then
                    self.savedVars.npcNamePreset = "default"
                    self.savedVars.interaction.ui.hidePanelsESO = false
                    CinematicCam:ShowDialoguePanels()
                    self.presetPending = true
                    self.vanillaPending = true
                end

                -- Apply immediately if in dialogue
                local interactionType = GetInteractionType()
                if interactionType ~= INTERACTION_NONE then
                    -- Apply NPC name preset first
                    self:ApplyNPCNamePreset(self.savedVars.npcNamePreset)

                    zo_callLater(function()
                        self:ApplyDialogueRepositioning()
                    end, 50)
                end
            end,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Hide Choices until Dialogue finishes",
            tooltip = "Hides your response options until the NPC has finished speaking",
            getFunc = function() return self.savedVars.interaction.subtitles.hidePlayerOptionsUntilLastChunk end,
            setFunc = function(value)
                self.savedVars.interaction.subtitles.hidePlayerOptionsUntilLastChunk = value
            end,
            width = "full",
            disabled = function()
                return self.savedVars.interaction.layoutPreset ~= "cinematic"
            end,
        },


        {
            type = "checkbox",
            name = "Show Interaction Buttons",
            getFunc = function()
                return CinematicCam.savedVars.interaction.ButtonsVisible
            end,
            setFunc = function(value)
                CinematicCam.savedVars.interaction.ButtonsVisible = value
            end,


        },

        {
        },
        {
            type = "header",
            name = "Subtitle Appearance",
            width = "full",
        },
        {
            type = "dropdown",
            name = "Font",
            tooltip = "Change the font for subtitle text, and your responses",
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
            name = " Text Size",
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
            type = "colorpicker",
            name = "Text Color",
            tooltip = "Change the color of subtitle text",
            getFunc = function()
                local color = self.savedVars.interaction.subtitles.textColor or { r = 0.9, g = 0.9, b = 0.8, a = 1.0 }
                return color.r, color.g, color.b, color.a
            end,
            setFunc = function(r, g, b, a)
                self.savedVars.interaction.subtitles.textColor = { r = r, g = g, b = b, a = a }

                -- Apply immediately if in dialogue
                local control = CinematicCam.chunkedDialogueData.customControl
                if control then
                    control:SetColor(r, g, b, a)
                end
            end,
            disabled = function()
                return self.savedVars.interaction.layoutPreset ~= "cinematic"
            end,
            width = "full",
        },
        {
            type = "dropdown",
            name = "Text Background",
            tooltip =
            "Backgrounds for easier viewing of subtitles. Light background is only available in Cinematic layout",
            choices = { "Default", "Light", "None" },
            choicesValues = { "default", "light", "none" },
            getFunc = function()
                local currentLayout = self.savedVars.interaction.layoutPreset
                if currentLayout == "default" then
                    local bgMode = self.savedVars.interface.defaultBackgroundMode or "esoDefault"
                    if bgMode == "esoDefault" then
                        return "default"
                    elseif bgMode == "none" then
                        return "none"
                    else
                        return "light"
                    end
                else -- cinematic layout
                    local bgMode = self.savedVars.interface.cinematicBackgroundMode or "redemption_banner"
                    if bgMode == "redemption_banner" then
                        return "default"
                    elseif bgMode == "kingdom" then
                        return "light"
                    else
                        return "none"
                    end
                end
            end,
            setFunc = function(value)
                local currentLayout = self.savedVars.interaction.layoutPreset
                if currentLayout == "default" then
                    -- Map unified values to default layout values
                    local defaultValue
                    if value == "default" then
                        defaultValue = "esoDefault"
                    elseif value == "light" then
                        defaultValue = "esoDefault" -- Default layout doesn't support light mode, default to esoDefault
                    else
                        defaultValue = "none"
                    end
                    self.savedVars.interface.defaultBackgroundMode = defaultValue
                    self:ApplyDefaultBackgroundSettings(defaultValue)
                    local interactionType = GetInteractionType()
                    if interactionType ~= INTERACTION_NONE then
                        zo_callLater(function()
                            self:ApplyDialogueRepositioning()
                        end, 50)
                    end
                else -- cinematic
                    -- Map unified values to cinematic layout values
                    local cinematicValue
                    if value == "default" then
                        cinematicValue = "redemption_banner"
                    elseif value == "light" then
                        cinematicValue = "kingdom"
                    else -- "none"
                        cinematicValue = "none"
                    end
                    self.savedVars.interface.cinematicBackgroundMode = cinematicValue
                    self:ApplyCinematicBackgroundSettings(cinematicValue)
                    local interactionType = GetInteractionType()
                    if interactionType ~= INTERACTION_NONE then
                        zo_callLater(function()
                            self:RefreshDialogueBackgrounds()
                        end, 50)
                    end
                end
            end,
            width = "full",
        },


        {
            type = "slider",
            name = "Position",
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
            disabled = function()
                return self.savedVars.interaction.layoutPreset ~= "cinematic"
            end,
            width = "full",
        },

        {
            type = "header",
            name = "Name Appearance",
            width = "full",
        },

        {
            type = "dropdown",
            name = "Select Companion",
            choices = {
                "Bastian Hallix",
                "Mirri Elendis",
                "Ember",
                "Isobel Veloise",
                "Azandar al-Cybiades",
                "Sharp-as-Night",
                "Tanlorin",
                "Zerith-var"
            },
            choicesValues = {
                "bastian hallix",
                "mirri elendis",
                "ember",
                "isobel veloise",
                "azandar",
                "sharp-as-night",
                "tanlorin",
                "zerith-var"
            },
            getFunc = function()
                return self.savedVars.selectedCompanion or "ember"
            end,
            setFunc = function(value)
                self.savedVars.selectedCompanion = value
                CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel", controlPanel)
            end,
            disabled = function()
                return self.savedVars.interaction.layoutPreset ~= "cinematic"
            end,
            width = "half",
        },
        {
            type = "colorpicker",
            name = function()
                local companionName = self.savedVars.selectedCompanion or "ember"
                -- Capitalize first letter of each word
                local displayName = companionName:gsub("(%a)([%w_']*)", function(first, rest)
                    return first:upper() .. rest
                end)
                return displayName .. " Color"
            end,
            getFunc = function()
                local companionName = self.savedVars.selectedCompanion or "ember"
                if not self.savedVars.companionColors then
                    self.savedVars.companionColors = {}
                end
                if not self.savedVars.companionColors[companionName] then
                    -- Default to white for all companions
                    self.savedVars.companionColors[companionName] = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 }
                end
                local color = self.savedVars.companionColors[companionName]
                return color.r, color.g, color.b, color.a
            end,
            setFunc = function(r, g, b, a)
                local companionName = self.savedVars.selectedCompanion or "ember"
                if not self.savedVars.companionColors then
                    self.savedVars.companionColors = {}
                end
                self.savedVars.companionColors[companionName] = { r = r, g = g, b = b, a = a }

                -- Apply immediately if in dialogue with this companion
                if self.savedVars.npcNamePreset == "prepended" then
                    local interactionType = GetInteractionType()
                    if interactionType ~= INTERACTION_NONE then
                        self:UpdateNPCNameColor()
                    end
                end
            end,
            disabled = function()
                return self.savedVars.interaction.layoutPreset ~= "cinematic"
            end,
            width = "half",
        },
        {
            type = "colorpicker",
            name = "Default NPC Color",
            getFunc = function()
                local color = self.savedVars.npcNameColor
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
            type = "header",
            name = "Cinematic Settings",
        },
        {
            type = "checkbox",
            name = "Enable UI settings",
            tooltip =
            "Turn ON to use this addons custom hiding behavior.\n - Hide compass, group tracker and more.\nTurn OFF to use default hiding behavior.",
            getFunc = function()
                return CinematicCam.savedVars.interface.usingModTweaks
            end,
            setFunc = function(value) CinematicCam.savedVars.interface.usingModTweaks = value end,
            width = "full",
        },
        {
            type = "dropdown",
            name = "Show Compass",
            tooltip =
            "Choose when to hide the compass\nAlways: Always Show\nNever: Never show\nCombat Only: Show only in combat\nWeapons Drawn: Show only when weapons are drawn",
            choices = { "Always", "Never", "Combat Only", "Weapons Drawn" },
            choicesValues = { "always", "never", "combat", "weapons" },
            getFunc = function() return self.savedVars.interface.hideCompass end,
            setFunc = function(value)
                self.savedVars.interface.hideCompass = value
                CinematicCam:UpdateCompassVisibility()
                self.pendingUIRefresh = true
            end,
            disabled = function() return not CinematicCam.savedVars.interface.usingModTweaks end,
        },
        {
            type = "dropdown",
            name = "Show Skill Bar",
            tooltip =
            "Choose when to hide the skill and resource bars\nAlways: Always Show\nNever: Never show\nCombat Only: Show only in combat\nWeapons Drawn: Show only when weapons are drawn",

            choices = { "Always", "Never", "Combat Only", "Weapons Drawn" },
            choicesValues = { "always", "never", "combat", "weapons" },
            getFunc = function() return self.savedVars.interface.hideActionBar end,
            setFunc = function(value)
                self.savedVars.interface.hideActionBar = value
                CinematicCam:UpdateActionBarVisibility()
                self.pendingUIRefresh = true
            end,
            disabled = function() return not CinematicCam.savedVars.interface.usingModTweaks end,
        },
        {
            type = "dropdown",
            name = "Show Reticle",
            tooltip =
            "Choose when to hide the center reticle and resource bars\nAlways: Always Show\nNever: Never show\nCombat Only: Show only in combat\nWeapons Drawn: Show only when weapons are drawn",

            choices = { "Always", "Never", "Combat Only", "Weapons Drawn" },
            choicesValues = { "always", "never", "combat", "weapons" },
            getFunc = function() return self.savedVars.interface.hideReticle end,
            setFunc = function(value)
                self.savedVars.interface.hideReticle = value
                CinematicCam:UpdateReticleVisibility()
                self.pendingUIRefresh = true
            end,
            disabled = function() return not CinematicCam.savedVars.interface.usingModTweaks end,
        },
        {

            type = "header",
            name = "Black Bar Settings",
        },

        {
            type = "button",
            name = "Toggle Black Bars",
            tooltip = "Add movie-like black bars",
            func = function()
                self:ToggleLetterbox()
            end,
            width = "half",
        },
        {
            type = "checkbox",
            name = "Auto Black Bars During Dialogue",
            getFunc = function() return self.savedVars.interaction.auto.autoLetterboxDialogue end,
            setFunc = function(value)
                self.savedVars.interaction.auto.autoLetterboxDialogue = value
            end,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Auto Black Bars on Mount",

            getFunc = function() return CinematicCam.savedVars.letterbox.autoLetterboxMount end,
            setFunc = function(value) CinematicCam.savedVars.letterbox.autoLetterboxMount = value end,
            width = "full",
        },
        {
            type = "slider",
            name = "Mount Black Bars Delay",
            tooltip = "Delay showing black bars when mounting (in seconds)",
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
            type = "slider",
            name = "Black Bar Size",
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
            type = "checkbox",
            name = "Vignette",

            getFunc = function() return self.savedVars.interface.sepiaFilter.enabled end,
            setFunc = function(value)
                self.savedVars.interface.sepiaFilter.enabled = value
                self.savedVars.interface.sepiaFilter.useTextured = value
                self:UpdateSepiaFilter()
            end,
            width = "full",
        },
        {

            type = "dropdown",
            name = "Quick Presets",
            choices = { "None", "Pulp", "Redemption", "Kingdom", "Vanilla" },
            choicesValues = { "none", "tarantinoril", "redemption", "kingdom", "vanilla" },
            getFunc = function() return self.savedVars.interface.currentPreset end,
            setFunc = function(value)
                if value == "tarantinoril" then
                    self:ShowLetterbox()
                    self:ApplyTarantinoriPreset()
                elseif value == "redemption" then
                    if self.savedVars.letterbox.letterboxVisible then
                        self:HideLetterbox()
                    end
                    self:ApplyRedemptionPreset()
                elseif value == "kingdom" then
                    if self.savedVars.letterbox.letterboxVisible then
                        self:HideLetterbox()
                    end
                    self:ApplyKingdomPreset()
                elseif value == "vanilla" then
                    self:ApplyVanillaPreset()
                end
            end,
            width = "full",
        },
        {
            type = "header",
            name = "Apply Addon to",
        },
        {
            type = "description",
            text =
            "Seamless transitions from gameplay to NPC interactions. Turning OFF uses the default NPC camera angle.",
        },
        {
            type = "checkbox",
            name = "Citizens",
            tooltip = [[Keep game camera when talking to regular characters]],
            getFunc = function() return self.savedVars.interaction.forceThirdPersonDialogue end,
            setFunc = function(value)
                self.savedVars.interaction.forceThirdPersonDialogue = value
                self:InitializeInteractionSettings()

                self.presetPending = true
            end,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Merchants & Bankers",
            tooltip =
            [[Keep game camera when using stores, stables, and banks]],
            getFunc = function()
                return self.savedVars.interaction.forceThirdPersonVendor and
                    self.savedVars.interaction.forceThirdPersonBank
            end,
            setFunc = function(value)
                self.savedVars.interaction.forceThirdPersonVendor = value
                self.savedVars.interaction.forceThirdPersonBank = value
                self:InitializeInteractionSettings()

                self.presetPending = true
            end,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Crafting Stations",
            tooltip = "Keep game camera when using crafting stations",
            getFunc = function() return self.savedVars.interaction.forceThirdPersonCrafting end,
            setFunc = function(value)
                self.savedVars.interaction.forceThirdPersonCrafting = value
                self.savedVars.interaction.forceThirdPersonDye = false
                self:InitializeInteractionSettings()
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
            type = "description",
            text = "Update Notes",
            tooltip =
            [[
Version 6d - Added camera movement during dialogue interactions
---
Version 6c - Bug Fixes
• Made using presets easier by adding buttons to apply/save/delete
• Added a "weapons drawn" options for hiding compass, reticle, and skill bar
• Fixed UI error when loading in while mounted
]],

            width = "full",
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
    CinematicCam_PlayerOptionsPreviewText:SetText("Preview")
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
    CinematicCam_PreviewText:SetText("Preview")

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
    self.savedVars.interface.useSubtitleBackground = (backgroundMode == "subtitles" or backgroundMode == "kingdom")
    self.savedVars.interface.usePlayerOptionsBackground = false -- Removed player options background for simplicity

    -- Update the active background control
    self:SetActiveBackgroundControl()
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

    local backgroundMode = self.savedVars.interface.cinematicBackgroundMode or "subtitles"
    return backgroundMode == "subtitles" or backgroundMode == "kingdom" or backgroundMode == "redemption_banner"
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

function CinematicCam:SetActiveBackgroundControl()
    local backgroundMode = self.savedVars.interface.cinematicBackgroundMode or "subtitles"
    local backgroundNormal = _G["CinematicCam_ChunkedTextBackground"]
    local backgroundKingdom = _G["CinematicCam_ChunkedTextBackground_Kingdom"]

    -- Hide both backgrounds first
    if backgroundNormal then backgroundNormal:SetHidden(true) end
    if backgroundKingdom then backgroundKingdom:SetHidden(true) end

    -- Set the active background control
    if backgroundMode == "kingdom" or backgroundMode == "redemption_banner" or backgroundMode == "dark" then
        CinematicCam.chunkedDialogueData.backgroundControl = backgroundKingdom
    else
        CinematicCam.chunkedDialogueData.backgroundControl = backgroundNormal
    end
end

function CinematicCam:MigrateSettings()
    if self.savedVars.interaction.subtitles.posX ~= 0.5 then
        self.savedVars.interaction.subtitles.posX = 0.5
    end
    -- Migrate hideCompass from boolean to string
    if type(self.savedVars.interface.hideCompass) == "boolean" then
        self.savedVars.interface.hideCompass = self.savedVars.interface.hideCompass and "never" or "always"
    end

    -- Migrate hideReticle from boolean to string
    if type(self.savedVars.interface.hideReticle) == "boolean" then
        self.savedVars.interface.hideReticle = self.savedVars.interface.hideReticle and "never" or "always"
    end

    -- Migrate hideActionBar from boolean to string
    if type(self.savedVars.interface.hideActionBar) == "boolean" then
        self.savedVars.interface.hideActionBar = self.savedVars.interface.hideActionBar and "never" or "always"
    end
end
