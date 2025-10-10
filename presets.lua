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
    local elegantWhite = { r = 0.2, g = 0.2, b = 0.2, a = 1.0 } -- Slightly warm white
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

    -- IMPORTANT: Force refresh the text control properties
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

-- Add to your Presets.lua file (document 4)

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
    self.savedVars.letterbox.letterboxVisible = preset.letterboxVisible
    self.savedVars.letterbox.size = preset.letterboxSize
    self.savedVars.letterbox.opacity = preset.letterboxOpacity
    self.savedVars.interaction.auto.autoLetterboxDialogue = preset.autoLetterboxDialogue
    self.savedVars.letterbox.autoLetterboxMount = preset.autoLetterboxMount
    self.savedVars.letterbox.mountLetterboxDelay = preset.mountLetterboxDelay
    self.savedVars.interface.selectedFont = preset.selectedFont
    self.savedVars.interface.customFontSize = preset.customFontSize
    self.savedVars.interaction.subtitles.isHidden = preset.subtitlesHidden
    self.savedVars.interaction.subtitles.useChunkedDialogue = preset.useChunkedDialogue
    self.savedVars.interaction.subtitles.hidePlayerOptionsUntilLastChunk = preset.hidePlayerOptionsUntilLastChunk
    self.savedVars.interaction.subtitles.textColor = preset.textColor
    self.savedVars.interaction.subtitles.posX = preset.posX
    self.savedVars.interaction.subtitles.posY = preset.posY
    self.savedVars.npcNamePreset = preset.npcNamePreset
    self.savedVars.npcNameColor = preset.npcNameColor
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

    CinematicCam:ToggleCompass(preset.hideCompass)
    CinematicCam:ToggleActionBar(preset.hideActionBar)
    CinematicCam:ToggleReticle(preset.hideReticle)

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
    local statusIcon = hasData and "✓ " or "○ "
    return statusIcon .. (slot.name or ("Custom " .. slotNumber))
end
