local namePresetDefaults = {
    npcNameColor = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 },
    npcNameFontSize = 42,
}
-- NPC Name tables
CinematicCam.npcNameData = {
    originalName = "",
    customNameControl = nil,
    currentPreset = "default"
}
function CinematicCam:GetNPCName()
    local sources = {
        ZO_InteractWindow_GamepadTitle,
        ZO_InteractWindowTargetAreaTitle
    }

    for _, element in ipairs(sources) do
        if element then
            local name = element.text or element:GetText() or ""
            if string.len(name) > 0 then
                return name, element
            end
        end
    end
    return nil, nil
end

function CinematicCam:CreateNPCNameControl()
    if CinematicCam.npcNameData.customNameControl then
        return CinematicCam.npcNameData.customNameControl
    end

    -- Create custom label control for NPC name
    local control = CreateControl("CinematicCam_NPCName", GuiRoot, CT_LABEL)

    -- Set text properties
    control:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    control:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    control:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    -- Apply NPC name color
    local color = self.savedVars.npcNameColor or namePresetDefaults.npcNameColor
    control:SetColor(color.r, color.g, color.b, color.a)

    -- Apply font
    local fontSize = self.savedVars.npcNameFontSize or namePresetDefaults.npcNameFontSize
    self:ApplyFontToElement(control, fontSize)

    -- Set draw properties
    control:SetDrawLayer(DL_OVERLAY)
    control:SetDrawLevel(7)

    -- Initially hidden
    control:SetHidden(true)
    control:SetText("")

    CinematicCam.npcNameData.customNameControl = control
    return control
end

function CinematicCam:RGBToHexString(r, g, b)
    -- Convert 0-1 float values to 0-255 integer values
    local red = math.floor(r * 255)
    local green = math.floor(g * 255)
    local blue = math.floor(b * 255)

    -- Convert to hex
    return string.format("%02X%02X%02X", red, green, blue)
end

function CinematicCam:ProcessNPCNameForPreset(dialogueText, npcName, preset)
    if not npcName or npcName == "" then
        return dialogueText
    end

    preset = preset or self.savedVars.npcNamePreset or "default"

    if preset == "prepended" then
        local color = self.savedVars.npcNameColor or namePresetDefaults.npcNameColor
        local hexColor = self:RGBToHexString(color.r, color.g, color.b)
        local coloredName = "|c" .. hexColor .. npcName .. ": |r"
        return coloredName .. dialogueText
    elseif preset == "above" then
        return dialogueText
    else
        -- Default
        return dialogueText
    end
end

function CinematicCam:PositionNPCNameControl(preset)
    local control = CinematicCam.npcNameData.customNameControl
    if not control then return end

    preset = preset or self.savedVars.npcNamePreset or "default"

    if preset == "above" then
        -- Position above the dialogue text
        local dialogueControl = CinematicCam.chunkedDialogueData.customControl
        if dialogueControl and self.savedVars.interaction.layoutPreset == "cinematic" then
            -- Get dialogue position and place name above it
            local targetX, targetY = self:ConvertToScreenCoordinates(
                self.savedVars.interaction.subtitles.posX or 0.5,
                self.savedVars.interaction.subtitles.posY or 0.7
            )
            control:ClearAnchors()
            control:SetAnchor(CENTER, GuiRoot, CENTER, targetX, targetY - 80) -- 80 pixels above dialogue
            control:SetDimensions(800, 60)
        else
            -- Fallback positioning for non-cinematic mode
            control:ClearAnchors()
            control:SetAnchor(CENTER, GuiRoot, CENTER, 0, -200)
            control:SetDimensions(600, 60)
        end
    end
end

function CinematicCam:ApplyNPCNamePreset(preset)
    preset = preset or self.savedVars.npcNamePreset or "default"
    CinematicCam.npcNameData.currentPreset = preset

    local npcName, originalElement = self:GetNPCName()

    if preset == "default" then
        -- Show original ESO name element
        if originalElement then
            originalElement:SetHidden(false)
            --originalElement:SetText(GetUnitName("player"))
        end
        -- Hide custom name control
        if CinematicCam.npcNameData.customNameControl then
            CinematicCam.npcNameData.customNameControl:SetHidden(true)
        end
    elseif preset == "prepended" then
        -- Hide original name element
        if originalElement then
            originalElement:SetHidden(true)
        end
        -- Hide custom name control (name will be in dialogue text)
        if CinematicCam.npcNameData.customNameControl then
            CinematicCam.npcNameData.customNameControl:SetHidden(true)
        end
    elseif preset == "above" then
        -- Hide original name element
        if originalElement then
            originalElement:SetHidden(true)
        end

        -- Show custom name control
        if not CinematicCam.npcNameData.customNameControl then
            self:CreateNPCNameControl()
        end

        local control = CinematicCam.npcNameData.customNameControl
        if control and npcName then
            control:SetText(npcName)
            self:PositionNPCNameControl(preset)
            control:SetHidden(false)
        end
    end
    -- Store the NPC name for use in dialogue processing
    CinematicCam.npcNameData.originalName = npcName or ""
end

function CinematicCam:UpdateNPCNameFont()
    local control = CinematicCam.npcNameData.customNameControl
    if control then
        local fontSize = self.savedVars.npcNameFontSize or namePresetDefaults.npcNameFontSize
        self:ApplyFontToElement(control, fontSize)
    end
end

-- Function to update NPC name color
function CinematicCam:UpdateNPCNameColor()
    local control = CinematicCam.npcNameData.customNameControl
    if control then
        local color = self.savedVars.npcNameColor or namePresetDefaults.npcNameColor
        control:SetColor(color.r, color.g, color.b, color.a)
    end
end
