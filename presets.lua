CinematicCam.presetPending = false
CinematicCam.vanillaPending = false
function CinematicCam:ApplyPresetSettings()
    -- Apply letterbox changes
    if self.savedVars.letterbox.letterboxVisible then
        self:ShowLetterbox()
    else
        self:HideLetterbox()
    end

    -- Apply font changes
    self:OnFontChanged()

    -- Apply layout changes
    local interactionType = GetInteractionType()
    if interactionType ~= INTERACTION_NONE then
        zo_callLater(function()
            self:ApplyDialogueRepositioning()
        end, 50)
    end

    -- Apply UI panel settings
    if self.savedVars.interaction.ui.hidePanelsESO then
        self:HideDialoguePanels()
    else
        self:ShowDialoguePanels()
    end

    -- Apply background settings
    self:SetActiveBackgroundControl()

    -- Update text colors for active dialogue if present
    if CinematicCam.chunkedDialogueData.isActive then
        self:ApplySubtitleTextColor()
    end

    -- Apply NPC name preset
    if interactionType ~= INTERACTION_NONE then
        self:ApplyNPCNamePreset()
    end

    -- Update visibility settings
    self:UpdateChunkedTextVisibility()
end

function CinematicCam:ApplyTarantinoriPreset()
    -- Signature Tarantino yellow/gold color
    self.vanillaPending = false
    local tarantinoGold = { r = 1.0, g = 0.75, b = 0.0, a = 1.0 } -- #FFD700 gold
    self.savedVars.interface.currentPreset = "tarantinoril"
    self:ApplyNPCNamePreset("prepended")
    self.savedVars.interaction.forceThirdPersonDialogue = true
    -- Apply all Tarantinoril settings
    self.savedVars.letterbox.letterboxVisible = true
    CinematicCam:ShowLetterbox()
    self.savedVars.letterbox.size = 100
    self.savedVars.letterbox.opacity = 1.0
    self.savedVars.interface.hideCompass = true
    CinematicCam:ToggleCompass(true)
    self.pendingUIRefresh = true
    -- Font settings
    self.savedVars.interface.selectedFont = "ESO_Bold"
    self.savedVars.interface.customFontSize = 52

    -- Layout and background
    self.savedVars.interaction.layoutPreset = "cinematic"
    self.savedVars.interface.cinematicBackgroundMode = "none"

    -- Text color - signature gold
    self.savedVars.interaction.subtitles.textColor = tarantinoGold

    -- NPC name settings
    self.savedVars.npcNamePreset = "prepended"
    self.savedVars.npcNameColor = tarantinoGold


    -- Enable subtitle features
    self.savedVars.interaction.auto.autoLetterboxDialogue = false
    self.savedVars.interaction.subtitles.isHidden = false
    self.savedVars.interaction.subtitles.useChunkedDialogue = true
    self.savedVars.interaction.subtitles.hidePlayerOptionsUntilLastChunk = true

    -- Hide UI panels for clean cinematic look
    self.savedVars.interaction.ui.hidePanelsESO = true
    zo_callLater(function()
        self:ApplyDialogueRepositioning()
    end, 50)
    -- Apply settings immediately
    self:InitializeInteractionSettings()
    CinematicCam.presetPending = true
end

function CinematicCam:ApplyRedemptionPreset()
    -- Clean white styling
    self.vanillaPending = false
    local cleanWhite = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 }
    local gray = { r = 0.5, g = 0.5, b = 0.5, a = 0.5 }
    self.savedVars.interaction.forceThirdPersonDialogue = true
    self.savedVars.interface.currentPreset = "redemption"
    self:ApplyNPCNamePreset("prepended")
    -- No letterbox by default, but auto-enable for dialogue
    self.savedVars.letterbox.letterboxVisible = false
    self.savedVars.interaction.auto.autoLetterboxDialogue = true

    -- Auto letterbox on mount after 20 seconds
    self.savedVars.letterbox.autoLetterboxMount = true
    self.savedVars.letterbox.mountLetterboxDelay = 20

    -- Font settings - clean and readable
    self.savedVars.interface.selectedFont = "ESO_Standard"
    self.savedVars.interface.customFontSize = 58

    -- Cinematic layout with no subtitle background
    self.savedVars.interaction.layoutPreset = "cinematic"
    self.savedVars.interface.cinematicBackgroundMode = "redemption_banner"

    -- Pure white text color
    self.savedVars.interaction.subtitles.textColor = cleanWhite

    -- Prepended NPC names with white color
    self.savedVars.npcNamePreset = "prepended"
    self.savedVars.npcNameColor = gray

    -- Enable subtitle features
    self.savedVars.interaction.subtitles.isHidden = false
    self.savedVars.interaction.subtitles.useChunkedDialogue = true
    self.savedVars.interaction.subtitles.hidePlayerOptionsUntilLastChunk = true
    zo_callLater(function()
        self:ApplyDialogueRepositioning()
    end, 50)
    -- Hide UI panels for cinematic look
    self.savedVars.interaction.ui.hidePanelsESO = true
    self:InitializeInteractionSettings()
    CinematicCam.presetPending = true
end

function CinematicCam:ApplyKingdomPreset()
    self.vanillaPending = false
    -- Medieval/fantasy styling with elegant colors
    local elegantWhite = { r = 0.2, g = 0.2, b = 0.2, a = 1.0 }
    self.savedVars.interface.currentPreset = "kingdom"
    self:ApplyNPCNamePreset("prepended")
    -- No letterbox for open view
    self.savedVars.letterbox.letterboxVisible = false
    self.savedVars.interaction.forceThirdPersonDialogue = true
    self.savedVars.letterbox.autoLetterboxMount = false
    self.savedVars.interaction.auto.autoLetterboxDialogue = false

    -- Handwritten font for medieval feel
    self.savedVars.interface.selectedFont = "Handwritten" -- Handwritten style
    self.savedVars.interface.customFontSize = 48

    -- Cinematic layout with kingdom banner background
    self.savedVars.interaction.layoutPreset = "cinematic"
    self.savedVars.interface.cinematicBackgroundMode = "kingdom"

    -- Elegant warm white text
    self.savedVars.interaction.subtitles.textColor = elegantWhite

    -- Prepended NPC names with matching elegant styling
    self.savedVars.npcNamePreset = "prepended"
    self.savedVars.npcNameColor = elegantWhite

    -- Enable subtitle features for immersive dialogue
    self.savedVars.interaction.subtitles.isHidden = false
    self.savedVars.interaction.subtitles.useChunkedDialogue = true
    self.savedVars.interaction.subtitles.hidePlayerOptionsUntilLastChunk = true

    -- Hide UI panels for clean medieval presentation
    self.savedVars.interaction.ui.hidePanelsESO = true
    zo_callLater(function()
        self:ApplyDialogueRepositioning()
    end, 50)
    self:InitializeInteractionSettings()
    CinematicCam.presetPending = true
end

function CinematicCam:ApplyVanillaPreset()
    self.savedVars.interface.currentPreset = "vanilla"
    self:ApplyNPCNamePreset("default")
    -- Disable all third-person forcing
    self.savedVars.interaction.forceThirdPersonDialogue = false
    self.savedVars.interaction.forceThirdPersonVendor = false
    self.savedVars.interaction.forceThirdPersonBank = false
    self.savedVars.interaction.forceThirdPersonCrafting = false
    self.savedVars.interaction.forceThirdPersonDye = false

    -- Use default layout with ESO panels
    self.savedVars.interaction.layoutPreset = "default"
    self.savedVars.interface.defaultBackgroundMode = "esoDefault"
    self.savedVars.interaction.ui.hidePanelsESO = false

    -- Disable letterbox features
    self.savedVars.letterbox.letterboxVisible = false
    self.savedVars.letterbox.autoLetterboxMount = false
    self.savedVars.interaction.auto.autoLetterboxDialogue = false

    -- Disable cinematic features
    self.savedVars.interaction.subtitles.useChunkedDialogue = false
    self.savedVars.interaction.subtitles.hidePlayerOptionsUntilLastChunk = false

    -- Use default NPC name handling
    self.savedVars.npcNamePreset = "default"

    -- Show subtitles but use default styling
    self.savedVars.interaction.subtitles.isHidden = false
    self:UpdateChunkedTextVisibility()
    -- Reset UI hiding features
    self.savedVars.interface.hideCompass = false
    self.savedVars.interface.hideActionBar = false
    self.savedVars.interface.hideReticle = false

    -- Apply default font and colors
    self.savedVars.interface.selectedFont = "ESO_Standard"
    self.savedVars.interface.customFontSize = 40 -- ESO default size
    self.savedVars.interaction.subtitles.textColor = { r = 0.9, g = 0.9, b = 0.8, a = 1.0 }

    -- Hide letterbox if currently visible
    if self.savedVars.letterbox.letterboxVisible then
        self:HideLetterbox()
    end

    -- Show ESO panels
    self:ShowDialoguePanels()

    -- Restore UI elements
    CinematicCam:ToggleCompass(false)
    CinematicCam:ToggleActionBar(false)
    CinematicCam:ToggleReticle(false)

    if CinematicCam.chunkedDialogueData.customControl then
        local control = CinematicCam.chunkedDialogueData.customControl
        -- Apply the new font and color settings to the control
        local fontString = self:BuildUserFontString()
        control:SetFont(fontString)
        local color = self.savedVars.interaction.subtitles.textColor
        control:SetColor(color.r, color.g, color.b, color.a)
    end

    -- Force font refresh for ESO elements
    self:OnFontChanged()

    -- Show original ESO text elements
    if ZO_InteractWindowTargetAreaBodyText then
        ZO_InteractWindowTargetAreaBodyText:SetHidden(false)
    end
    if ZO_InteractWindow_GamepadContainerText then
        ZO_InteractWindow_GamepadContainerText:SetHidden(false)
    end

    zo_callLater(function()
        self:RefreshDialogueBackgrounds()
        self:ApplyDialogueRepositioning()
        -- Force apply fonts to all dialogue elements
        self:ApplyFontsToUI()
    end, 50)

    -- Update interaction settings
    self:InitializeInteractionSettings()
    CinematicCam.vanillaPending = true
    CinematicCam.presetPending = true
end

---=============================================================================
-- Custom Preset Slots - Simple 3-slot system
---=============================================================================

function CinematicCam:InitializeCustomPresets()
    if not self.savedVars.customPresets then
        self.savedVars.customPresets = {
            slot1 = { name = "Home", settings = nil },
            slot2 = { name = "Overland", settings = nil },
            slot3 = { name = "Dungeons/Trials", settings = nil }
        }
    end

    -- Ensure structure exists for old saves
    for i = 1, 3 do
        local slotKey = "slot" .. i
        if not self.savedVars.customPresets[slotKey] then
            self.savedVars.customPresets[slotKey] = {
                name = "Custom " .. i,
                settings = nil
            }
        end
    end
end

function CinematicCam:SaveToPresetSlot(slotNumber)
    d("CinematicDialog: Saved")
    local slotKey = "slot" .. slotNumber
    local slot = self.savedVars.customPresets[slotKey]

    if not slot then
        return false
    end

    -- Save all current settings
    slot.settings = {
        forceThirdPersonDialogue = self.savedVars.interaction.forceThirdPersonDialogue,
        forceThirdPersonVendor = self.savedVars.interaction.forceThirdPersonVendor,
        forceThirdPersonBank = self.savedVars.interaction.forceThirdPersonBank,
        forceThirdPersonCrafting = self.savedVars.interaction.forceThirdPersonCrafting,
        layoutPreset = self.savedVars.interaction.layoutPreset,
        defaultBackgroundMode = self.savedVars.interface.defaultBackgroundMode,
        cinematicBackgroundMode = self.savedVars.interface.cinematicBackgroundMode,
        letterboxVisible = self.savedVars.letterbox.letterboxVisible,
        letterboxSize = self.savedVars.letterbox.size,
        letterboxOpacity = self.savedVars.letterbox.opacity,
        autoLetterboxDialogue = self.savedVars.interaction.auto.autoLetterboxDialogue,
        autoLetterboxMount = self.savedVars.letterbox.autoLetterboxMount,
        mountLetterboxDelay = self.savedVars.letterbox.mountLetterboxDelay,
        selectedFont = self.savedVars.interface.selectedFont,
        customFontSize = self.savedVars.interface.customFontSize,
        subtitlesHidden = self.savedVars.interaction.subtitles.isHidden,
        useChunkedDialogue = self.savedVars.interaction.subtitles.useChunkedDialogue,
        hidePlayerOptionsUntilLastChunk = self.savedVars.interaction.subtitles.hidePlayerOptionsUntilLastChunk,
        textColor = self.savedVars.interaction.subtitles.textColor,
        posX = self.savedVars.interaction.subtitles.posX,
        posY = self.savedVars.interaction.subtitles.posY,
        npcNamePreset = self.savedVars.npcNamePreset,
        npcNameColor = self.savedVars.npcNameColor,
        hidePanelsESO = self.savedVars.interaction.ui.hidePanelsESO,
        hideCompass = self.savedVars.interface.hideCompass,
        hideActionBar = self.savedVars.interface.hideActionBar,
        hideReticle = self.savedVars.interface.hideReticle,
    }


    return true
end

function CinematicCam:LoadFromPresetSlot(slotNumber)
    local slotKey = "slot" .. slotNumber
    local slot = self.savedVars.customPresets[slotKey]

    if not slot or not slot.settings then
        return false
    end

    local preset = slot.settings

    -- Apply all saved settings
    self.savedVars.interaction.forceThirdPersonDialogue = preset.forceThirdPersonDialogue
    self.savedVars.letterbox.letterboxVisible = preset.letterboxVisible
    self.savedVars.letterbox.size = preset.letterboxSize
    self.savedVars.letterbox.opacity = preset.letterboxOpacity
    self.savedVars.interaction.forceThirdPersonVendor = preset.forceThirdPersonVendor
    self.savedVars.interaction.forceThirdPersonBank = preset.forceThirdPersonBank
    self.savedVars.interaction.forceThirdPersonCrafting = preset.forceThirdPersonCrafting
    self.savedVars.interaction.layoutPreset = preset.layoutPreset
    self.savedVars.interface.defaultBackgroundMode = preset.defaultBackgroundMode
    self.savedVars.interface.cinematicBackgroundMode = preset.cinematicBackgroundMode
    self.savedVars.interaction.auto.autoLetterboxDialogue = preset.autoLetterboxDialogue
    self.savedVars.letterbox.autoLetterboxMount = preset.autoLetterboxMount
    self.savedVars.letterbox.mountLetterboxDelay = preset.mountLetterboxDelay

    self.savedVars.interaction.subtitles.isHidden = preset.subtitlesHidden
    self.savedVars.interaction.subtitles.useChunkedDialogue = preset.useChunkedDialogue
    self.savedVars.interaction.subtitles.hidePlayerOptionsUntilLastChunk = preset.hidePlayerOptionsUntilLastChunk

    self.savedVars.interaction.subtitles.posX = preset.posX
    self.savedVars.interaction.subtitles.posY = preset.posY
    self.savedVars.npcNamePreset = preset.npcNamePreset

    self.savedVars.interaction.ui.hidePanelsESO = preset.hidePanelsESO
    self.savedVars.interface.hideCompass = preset.hideCompass
    self.savedVars.interface.hideActionBar = preset.hideActionBar
    self.savedVars.interface.hideReticle = preset.hideReticle

    -- Apply the preset
    self.savedVars.interface.currentPreset = "custom:slot" .. slotNumber
    self:ApplyNPCNamePreset(preset.npcNamePreset)

    if preset.letterboxVisible then
        self:ShowLetterbox()
    else
        self:HideLetterbox()
    end

    -- Use the new update functions instead of direct toggle
    CinematicCam:UpdateCompassVisibility()
    CinematicCam:UpdateActionBarVisibility()
    CinematicCam:UpdateReticleVisibility()

    if preset.hidePanelsESO then
        self:HideDialoguePanels()
    else
        self:ShowDialoguePanels()
    end

    zo_callLater(function()
        self:ApplyDialogueRepositioning()
        self:InitializeInteractionSettings()
        self:OnFontChanged()
    end, 50)

    CinematicCam.presetPending = true

    return true
end

function CinematicCam:ClearPresetSlot(slotNumber)
    local slotKey = "slot" .. slotNumber
    local slot = self.savedVars.customPresets[slotKey]

    if slot then
        slot.settings = nil

        return true
    end
    return false
end

function CinematicCam:RenamePresetSlot(slotNumber, newName)
    local slotKey = "slot" .. slotNumber
    local slot = self.savedVars.customPresets[slotKey]

    if not slot then
        return false
    end

    if not newName or newName == "" then
        newName = "Custom " .. slotNumber
    end

    slot.name = newName
    return true
end

function CinematicCam:GetSlotDisplayName(slotNumber)
    -- Safety check
    if not self.savedVars or not self.savedVars.customPresets then
        return "○ Custom " .. slotNumber
    end

    local slotKey = "slot" .. slotNumber
    local slot = self.savedVars.customPresets[slotKey]

    -- Another safety check
    if not slot then
        return "○ Custom " .. slotNumber
    end

    local hasData = slot.settings ~= nil

    return slot.name
end

function CinematicCam:GetPresetTooltip(slotNumber)
    local slotKey = "slot" .. slotNumber
    local slot = self.savedVars.customPresets[slotKey]

    if not slot or not slot.settings then
        return "No settings saved for this preset"
    end

    local settings = slot.settings
    local tooltip = {}

    -- Header
    table.insert(tooltip, "|cFFD700" .. slot.name .. " Settings|r")
    table.insert(tooltip, "")

    -- Apply To settings
    table.insert(tooltip, "|cFFFFFF• Apply To:|r")
    if settings.forceThirdPersonDialogue then
        table.insert(tooltip, "  - Citizens: |c00FF00Enabled|r")
    else
        table.insert(tooltip, "  - Citizens: |cFF0000Disabled|r")
    end

    if settings.forceThirdPersonVendor and settings.forceThirdPersonBank then
        table.insert(tooltip, "  - Merchants & Bankers: |c00FF00Enabled|r")
    else
        table.insert(tooltip, "  - Merchants & Bankers: |cFF0000Disabled|r")
    end

    if settings.forceThirdPersonCrafting then
        table.insert(tooltip, "  - Crafting Stations: |c00FF00Enabled|r")
    else
        table.insert(tooltip, "  - Crafting Stations: |cFF0000Disabled|r")
    end

    table.insert(tooltip, "")

    -- Style settings
    table.insert(tooltip, "|cFFFFFF• Style:|r")
    local styleName = settings.layoutPreset == "cinematic" and "Cinematic" or "Default"
    table.insert(tooltip, "  - " .. styleName)

    table.insert(tooltip, "")

    -- Subtitle settings
    table.insert(tooltip, "|cFFFFFF• Subtitles:|r")
    if settings.subtitlesHidden then
        table.insert(tooltip, "  - |cFF0000Hidden|r")
    else
        table.insert(tooltip, "  - |c00FF00Visible|r")
        if settings.hidePlayerOptionsUntilLastChunk then
            table.insert(tooltip, "  - Hide choices until finished")
        end
    end

    table.insert(tooltip, "")

    -- Font settings
    table.insert(tooltip, "|cFFFFFF• Font:|r")
    table.insert(tooltip, "  - " .. settings.selectedFont .. " (" .. settings.customFontSize .. ")")

    table.insert(tooltip, "")

    -- Letterbox settings
    table.insert(tooltip, "|cFFFFFF• Black Bars:|r")
    if settings.letterboxVisible then
        table.insert(tooltip, "  - |c00FF00ON|r (Size: " .. settings.letterboxSize .. ")")
    else
        table.insert(tooltip, "  - |cFF0000OFF|r")
    end

    if settings.autoLetterboxDialogue then
        table.insert(tooltip, "  - Auto during dialogue")
    end

    if settings.autoLetterboxMount then
        table.insert(tooltip, "  - Auto on mount (" .. settings.mountLetterboxDelay .. "s delay)")
    end

    table.insert(tooltip, "")

    -- Cinematic UI settings
    table.insert(tooltip, "|cFFFFFF• UI Visibility:|r")

    local compassText = settings.hideCompass
    if compassText == "never" then
        table.insert(tooltip, "  - Compass: |cFF0000Never|r")
    elseif compassText == "combat" then
        table.insert(tooltip, "  - Compass: Combat Only")
    else
        table.insert(tooltip, "  - Compass: |c00FF00Always|r")
    end

    local actionBarText = settings.hideActionBar
    if actionBarText == "never" then
        table.insert(tooltip, "  - Skill Bar: |cFF0000Never|r")
    elseif actionBarText == "combat" then
        table.insert(tooltip, "  - Skill Bar: Combat Only")
    else
        table.insert(tooltip, "  - Skill Bar: |c00FF00Always|r")
    end

    local reticleText = settings.hideReticle
    if reticleText == "never" then
        table.insert(tooltip, "  - Reticle: |cFF0000Never|r")
    elseif reticleText == "combat" then
        table.insert(tooltip, "  - Reticle: Combat Only")
    else
        table.insert(tooltip, "  - Reticle: |c00FF00Always|r")
    end

    if settings.hidePanelsESO then
        table.insert(tooltip, "  - ESO Panels: |cFF0000Hidden|r")
    else
        table.insert(tooltip, "  - ESO Panels: |c00FF00Visible|r")
    end

    return table.concat(tooltip, "\n")
end

-- Updated dropdown definition
