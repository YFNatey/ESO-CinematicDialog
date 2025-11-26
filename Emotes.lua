local AUTO_EMOTE_CHANCES = {
    frequent = 75,   -- 75% chance
    infrequent = 40, -- 40% chance
    minimal = 15     -- 15% chance
}
function CinematicCam:ShouldPlayAutoEmote()
    if not self.savedVars.interaction.autoEmotes then
        return false
    end

    local frequency = self.savedVars.interaction.autoEmoteFrequency or "infrequent"
    local chance = AUTO_EMOTE_CHANCES[frequency] or 40

    -- Generate random number between 1-100
    local roll = math.random(1, 100)

    return roll <= chance
end

-- Initialize the emote wheel system
function CinematicCam:InitializeEmoteWheel()
    self.emoteWheelVisible = false
    self.emotePadVisible = false

    -- Set platform-specific trigger icon
    self:SetPlatformTriggerIcon()

    -- Start hidden
    self:HideEmoteWheel()
    self:HideEmotePad()
end

-- Set the correct trigger icon based on platform
-- Set the correct trigger icon based on platform
function CinematicCam:SetPlatformTriggerIcon()
    local xboxLT = _G["CinematicCam_XboxLT"]
    local ps4LT = _G["CinematicCam_PS4LT"]
    local xboxLS_Slide = _G["CinematicCam_XboxLS_Slide"]
    local xboxLS_Scroll = _G["CinematicCam_XboxLS_Scroll"]
    local ps4LS = _G["CinematicCam_PS4LS"]

    if not xboxLT or not ps4LT then
        return
    end

    local worldName = GetWorldName()

    -- Default to Xbox, switch to PS if on PlayStation
    if worldName == "PS4live" or worldName == "PS4live-eu" or worldName == "NA Megaserver" then
        -- Show PlayStation icons
        xboxLT:SetTexture("/esoui/art/buttons/gamepad/ps5/nav_ps5_l2.dds")


        if xboxLS_Slide then xboxLS_Slide:SetTexture("/esoui/art/buttons/gamepad/ps5/nav_ps5_rs_scroll.dds") end
        if xboxLS_Scroll then xboxLS_Scroll:SetTexture("/esoui/art/buttons/gamepad/ps5/nav_ps5_rs_slide.dds") end
        if ps4LS then ps4LS:SetHidden(false) end
    else
        -- Show Xbox icons (includes PC, NA Megaserver, EU Megaserver, XB1live, XB1live-eu)
        xboxLT:SetHidden(false)
        ps4LT:SetHidden(true)

        if xboxLS_Slide then xboxLS_Slide:SetHidden(false) end
        if xboxLS_Scroll then xboxLS_Scroll:SetHidden(false) end
        if ps4LS then ps4LS:SetHidden(true) end
    end
end

-- Show the emote wheel indicator
function CinematicCam:ShowEmoteWheel()
    local control = _G["CinematicCam_EmoteWheel"]
    if not control then return end

    -- Set platform-specific icon BEFORE showing
    self:SetPlatformTriggerIcon()

    control:SetHidden(false)
    control:SetAlpha(0)

    -- Fade in animation
    local timeline = ANIMATION_MANAGER:CreateTimeline()
    local animation = timeline:InsertAnimation(ANIMATION_ALPHA, control)
    animation:SetAlphaValues(0, 1)
    animation:SetDuration(200)
    animation:SetEasingFunction(ZO_EaseOutQuadratic)
    timeline:PlayFromStart()

    self.emoteWheelVisible = true
end

-- Hide the emote wheel indicator
function CinematicCam:HideEmoteWheel()
    local control = _G["CinematicCam_EmoteWheel"]
    if not control then return end

    -- Fade out animation
    local timeline = ANIMATION_MANAGER:CreateTimeline()
    local animation = timeline:InsertAnimation(ANIMATION_ALPHA, control)
    animation:SetAlphaValues(control:GetAlpha(), 0)
    animation:SetDuration(200)
    animation:SetEasingFunction(ZO_EaseOutQuadratic)

    timeline:SetHandler("OnStop", function()
        control:SetHidden(true)
    end)

    timeline:PlayFromStart()

    self.emoteWheelVisible = false
end

-- Show the emote directional pad
function CinematicCam:ShowEmotePad()
    local control = _G["CinematicCam_EmotePad"]
    if not control then return end

    -- Update labels before showing
    self:UpdateEmotePadLabels()

    control:SetHidden(false)
    control:SetAlpha(0)

    -- Fade in animation
    local timeline = ANIMATION_MANAGER:CreateTimeline()
    local animation = timeline:InsertAnimation(ANIMATION_ALPHA, control)
    animation:SetAlphaValues(0, 1)
    animation:SetDuration(150)
    animation:SetEasingFunction(ZO_EaseOutQuadratic)
    timeline:PlayFromStart()

    self.emotePadVisible = true
end

-- Hide the emote directional pad
function CinematicCam:HideEmotePad()
    local control = _G["CinematicCam_EmotePad"]
    if not control then return end

    -- Fade out animation
    local timeline = ANIMATION_MANAGER:CreateTimeline()
    local animation = timeline:InsertAnimation(ANIMATION_ALPHA, control)
    animation:SetAlphaValues(control:GetAlpha(), 0)
    animation:SetDuration(150)
    animation:SetEasingFunction(ZO_EaseOutQuadratic)

    timeline:SetHandler("OnStop", function()
        control:SetHidden(true)
    end)

    timeline:PlayFromStart()

    self.emotePadVisible = false
end

-- Highlight active direction
function CinematicCam:HighlightEmoteDirection(direction)
    local directions = { "Top", "Right", "Bottom", "Left" }

    for _, dir in ipairs(directions) do
        local texture = _G["CinematicCam_EmotePad_" .. dir]
        if texture then
            if dir == direction then
                texture:SetColor(0.3, 0.3, 0.3, 0.95) -- Lighter gray for selected
            else
                texture:SetColor(0, 0, 0, 0.85)       -- Dark for unselected
            end
        end
    end
end

-- Reset all direction highlights
function CinematicCam:ResetEmoteHighlights()
    local directions = { "Top", "Right", "Bottom", "Left" }

    for _, dir in ipairs(directions) do
        local texture = _G["CinematicCam_EmotePad_" .. dir]
        if texture then
            texture:SetColor(0, 0, 0, 0.85)
        end
    end
end

function CinematicCam:GetEmoteForSlot(slotNumber)
    local slotKey = "slot" .. slotNumber
    local packName = self.savedVars.emoteWheel[slotKey]

    if not packName or not CinematicCam.categorizedEmotes[packName] then
        return nil
    end

    local emotePack = CinematicCam.categorizedEmotes[packName]
    local randomIndex = math.random(1, #emotePack)
    return emotePack[randomIndex]
end

function CinematicCam:GetEmotePack(packName)
    if not packName or not CinematicCam.categorizedEmotes[packName] then
        return nil
    end
    local emotePack = CinematicCam.categorizedEmotes[packName]
    local randomIndex = math.random(1, #emotePack)
    return emotePack[randomIndex]
end

function CinematicCam:GetEmotePackDisplayName(packKey)
    local displayNames = {
        respectful = "Respectful",
        friendly = "Friendly",
        greeting = "Greeting",
        flirty = "Flirty",
        hostile = "Hostile",
        frustrated = "Frustrated",
        sad = "Sad",
        scared = "Scared",
        confused = "Confused",
        celebratory = "Celebratory",
        disgusted = "Disgusted",
        eating = "Eating/Drinking",
        entertainment = "Entertainment/Dance",
        idle = "Idle Poses",
        sitting = "Sitting/Resting",
        pointing = "Pointing/Directing",
        physical = "Physical Actions",
        exercise = "Exercise",
        working = "Working/Tools",
        tired = "Tired/Sick",
        agreement = "Agreement",
        disagreement = "Disagreement",
        playful = "Playful",
        attention = "Get Attention",
        misc = "Miscellaneous"
    }
    return displayNames[packKey] or packKey
end

-- Function to update emote pad labels when pack changes
function CinematicCam:UpdateEmotePadLabels()
    local slotMap = {
        [1] = "Top",
        [2] = "Right",
        [3] = "Bottom",
        [4] = "Left"
    }

    for slotNum, direction in pairs(slotMap) do
        local slotKey = "slot" .. slotNum
        local packName = self.savedVars.emoteWheel[slotKey]
        local label = _G["CinematicCam_EmotePad_" .. direction .. "Text"]

        if label and packName then
            label:SetText(self:GetEmotePackDisplayName(packName))
        end
    end
end

function CinematicCam:CreateEmoteSettingsMenu()
    local LAM = LibAddonMenu2

    if not LAM then
        return
    end

    local panelName = "CinematicCamEmoteOptions"

    local panelData = {
        type = "panel",
        name = "Cinematic Emotes",
        displayName = "Cinematic Emotes",
        author = "YFNatey",
        version = "1.0",
        registerForRefresh = true,
        registerForDefaults = true,
    }

    -- Available emote packs for display
    local emotePackChoices = {
        "Respectful", "Friendly", "Greeting", "Flirty", "Hostile", "Frustrated",
        "Sad", "Scared", "Confused", "Celebratory", "Disgusted", "Eating/Drinking",
        "Entertainment/Dance", "Idle Poses", "Sitting/Resting", "Pointing/Directing",
        "Physical Actions", "Exercise", "Working/Tools", "Tired/Sick", "Agreement",
        "Disagreement", "Playful", "Get Attention", "Miscellaneous"
    }

    local emotePackValues = {
        "respectful", "friendly", "greeting", "flirty", "hostile", "frustrated",
        "sad", "scared", "confused", "celebratory", "disgusted", "eating",
        "entertainment", "idle", "sitting", "pointing", "physical",
        "exercise", "working", "tired", "agreement", "disagreement",
        "playful", "attention", "misc"
    }

    local optionsData = {
        {
            type = "checkbox",
            name = "Enable Emotes",
            tooltip =
            "Adds on screen controls emotes. Move the camera with the Right Stick, Move your character with the Left Stick",
            getFunc = function()
                return CinematicCam.savedVars.interaction.allowImmersionControls
            end,
            setFunc = function(value)
                CinematicCam.savedVars.interaction.allowImmersionControls = value
            end,


        },
        {
            type = "header",
            name = "Auto Emotes",
        },

        {
            type = "checkbox",
            name = "Enable Auto Emotes",
            tooltip = "Automatically play emotes from your last-used emote wheel slot during dialogue progression",
            getFunc = function()
                return CinematicCam.savedVars.interaction.autoEmotes
            end,
            setFunc = function(value)
                CinematicCam.savedVars.interaction.autoEmotes = value
            end,

        },
        {
            type = "dropdown",
            name = "Auto Emotes Frequency",
            tooltip =
            "How often auto-emotes play during dialogue:\nFrequent: 75% chance\nInfrequent: 40% chance\nMinimal: 15% chance",
            choices = { "Frequent", "Infrequent", "Minimal" },
            choicesValues = { "frequent", "infrequent", "minimal" },
            getFunc = function()
                return self.savedVars.interaction.autoEmoteFrequency or "infrequent"
            end,
            setFunc = function(value)
                self.savedVars.interaction.autoEmoteFrequency = value
            end,
            width = "full",
            disabled = function()
                return not self.savedVars.interaction.allowImmersionControls
            end,
        },

        -- Greeting Handler


        {
            type = "dropdown",
            name = "Greetings",
            tooltip = "Emote pack to use when greeting friendly NPCs",
            choices = { "Friendly", "Hostile", "Casual", "No Greeting" },
            choicesValues = { "friendly", "hostile", "idle", "none" },
            getFunc = function()
                return self.savedVars.interaction.GreetingType
            end,
            setFunc = function(value)
                self.savedVars.interaction.GreetingType = value
            end,
            width = "full",
            disabled = function()
                return not self.savedVars.interaction.allowImmersionControls
            end,
        },

        -- Player Response Handler

        {
            type = "dropdown",
            name = "Responses",
            tooltip = "Emote pack to use for friendly/positive dialogue choices",
            choices = { "Friendly", "Hostile", "No Reaction" },
            choicesValues = { "friendly", "frustrated", "none" },
            getFunc = function()
                return self.savedVars.interaction.ChatType
            end,
            setFunc = function(value)
                self.savedVars.interaction.ChatType = value
            end,
            width = "full",
            disabled = function()
                return not self.savedVars.interaction.allowImmersionControls
            end,
        },
        {
            type = "header",
            name = "Emote Pad",
        },
        {
            type = "description",
            text = "Assign emote packs to the emote pad. The Emote Pad is used in interactions with NPCs.",
        },
        {
            type = "dropdown",
            name = "Slot 1 (Up)",
            tooltip = "Emote pack for Up direction on the emote wheel",
            choices = emotePackChoices,
            choicesValues = emotePackValues,
            getFunc = function()
                return self.savedVars.emoteWheel.slot1 or "entertainment"
            end,
            setFunc = function(value)
                self.savedVars.emoteWheel.slot1 = value
                self:UpdateEmotePadLabels()
            end,
            default = "entertainment",
            width = "full",
        },
        {
            type = "dropdown",
            name = "Slot 2 (Right)",
            tooltip = "Emote pack for Right direction on the emote wheel",
            choices = emotePackChoices,
            choicesValues = emotePackValues,
            getFunc = function()
                return self.savedVars.emoteWheel.slot2 or "friendly"
            end,
            setFunc = function(value)
                self.savedVars.emoteWheel.slot2 = value
                self:UpdateEmotePadLabels()
            end,
            default = "friendly",
            width = "full",
        },
        {
            type = "dropdown",
            name = "Slot 3 (Down)",
            tooltip = "Emote pack for Down direction on the emote wheel",
            choices = emotePackChoices,
            choicesValues = emotePackValues,
            getFunc = function()
                return self.savedVars.emoteWheel.slot3 or "greeting"
            end,
            setFunc = function(value)
                self.savedVars.emoteWheel.slot3 = value
                self:UpdateEmotePadLabels()
            end,
            default = "greeting",
            width = "full",
        },
        {
            type = "dropdown",
            name = "Slot 4 (Left)",
            tooltip = "Emote pack for Left direction on the emote wheel",
            choices = emotePackChoices,
            choicesValues = emotePackValues,
            getFunc = function()
                return self.savedVars.emoteWheel.slot4 or "respectful"
            end,
            setFunc = function(value)
                self.savedVars.emoteWheel.slot4 = value
                self:UpdateEmotePadLabels()
            end,
            default = "respectful",
            width = "full",
        },

        --[[{
            type = "header",
            name = "Emote Manager",
        },
        {
            type = "description",
            text =
            "Manage custom emote packs. Select a pack, then add or remove emotes using the slash command format (e.g., /wave, /dance).",
        },

        -- Select Pack to Edit
        {
            type = "dropdown",
            name = "Select Pack to Edit",
            tooltip = "Choose an emote pack to modify",
            choices = emotePackChoices,
            choicesValues = emotePackValues,
            getFunc = function()
                return self.savedVars.emoteManager.selectedPack or "friendly"
            end,
            setFunc = function(value)
                self.savedVars.emoteManager.selectedPack = value
            end,
            width = "full",
        },

        -- Add New Emote
        {
            type = "editbox",
            name = "Add Emote Command",
            tooltip = "Enter an emote command (e.g., /wave, /dance, /bow) and press Enter to add it to the selected pack",
            getFunc = function()
                return ""
            end,
            setFunc = function(value)
                local pack = self.savedVars.emoteManager.selectedPack

                if pack and value and value ~= "" then
                    if not CinematicCam.categorizedEmotes[pack] then
                        CinematicCam.categorizedEmotes[pack] = {}
                    end

                    -- Add slash if not present
                    local command = value
                    if not string.match(command, "^/") then
                        command = "/" .. command
                    end

                    -- Check if already exists
                    local exists = false
                    for _, emote in ipairs(CinematicCam.categorizedEmotes[pack]) do
                        if emote == command then
                            exists = true
                            break
                        end
                    end

                    if not exists then
                        table.insert(CinematicCam.categorizedEmotes[pack], command)
                        d("Added " .. command .. " to " .. pack .. " pack")
                    else
                        d(command .. " already exists in " .. pack .. " pack")
                    end
                end
            end,
            width = "full",
            disabled = function()
                return not self.savedVars.emoteManager.selectedPack
            end,
        },

        -- View Emotes in Pack
        {
            type = "description",
            text = function()
                local pack = self.savedVars.emoteManager.selectedPack
                if not pack or not CinematicCam.categorizedEmotes[pack] then
                    return "No pack selected or pack is empty"
                end

                local emotes = CinematicCam.categorizedEmotes[pack]
                if #emotes == 0 then
                    return "Pack is empty. Add emotes using the field above."
                end

                local text = "Emotes in " .. pack .. " pack:\n"
                for i, emote in ipairs(emotes) do
                    text = text .. emote
                    if i < #emotes then
                        text = text .. ", "
                    end
                end
                return text
            end,
        },

        -- Remove Emote (via editbox)
        {
            type = "editbox",
            name = "Remove Emote Command",
            tooltip = "Enter an emote command to remove it from the selected pack (e.g., /wave)",
            getFunc = function()
                return ""
            end,
            setFunc = function(value)
                local pack = self.savedVars.emoteManager.selectedPack

                if pack and value and value ~= "" and CinematicCam.categorizedEmotes[pack] then
                    -- Add slash if not present
                    local command = value
                    if not string.match(command, "^/") then
                        command = "/" .. command
                    end

                    for i, emote in ipairs(CinematicCam.categorizedEmotes[pack]) do
                        if emote == command then
                            table.remove(CinematicCam.categorizedEmotes[pack], i)
                            d("Removed " .. command .. " from " .. pack .. " pack")
                            return
                        end
                    end

                    d(command .. " not found in " .. pack .. " pack")
                end
            end,
            width = "full",
            disabled = function()
                return not self.savedVars.emoteManager.selectedPack
            end,
        },

        -- Create New Pack
        {
            type = "editbox",
            name = "Create New Pack",
            tooltip = "Enter a name for a new emote pack and press Enter to create it",
            getFunc = function()
                return ""
            end,
            setFunc = function(value)
                if value and value ~= "" then
                    -- Convert to lowercase key
                    local packKey = string.lower(string.gsub(value, " ", "_"))

                    if not CinematicCam.categorizedEmotes[packKey] then
                        CinematicCam.categorizedEmotes[packKey] = {}
                        d("Created new pack: " .. value .. " (key: " .. packKey .. ")")
                        self.savedVars.emoteManager.selectedPack = packKey
                    else
                        d("Pack already exists: " .. value)
                    end
                end
            end,
            width = "full",
       -- },]]
    }

    LAM:RegisterAddonPanel(panelName, panelData)
    LAM:RegisterOptionControls(panelName, optionsData)
end
