CinematicCam.defaults = {
    camEnabled = false,
    npcNamePreset = "prepended",
    npcNameColor = { r = 0.9, g = 0.9, b = 0.8, a = 1.0 },
    npcNameFontSize = 48,
    usePlayerName = false,

    playerNameColor = { r = 0.8, g = 0.8, b = 1.0, a = 1.0 },
    dialogueElementsHidden = false,
    homePresets = {},
    isHome = false,
    lastSeenUpdateVersion = "0.0.0",
    hasSeenWelcomeMessage = false,
    selectedCompanion = "ember",
    autoSwapPresets = false,
    companionColors = {
        ["bastian hallix"] = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 },
        ["mirri elendis"] = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 },
        ember = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 },
        ["isobel veloise"] = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 },
        ["azandar"] = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 },
        ["sharp-as-night"] = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 },
        tanlorin = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 },
        ["zerith-var"] = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 },
    },
    letterbox = {
        size = 100,
        opacity = 1.0,
        letterboxVisible = false,
        autoLetterboxMount = false,
        coordinateWithLetterbox = true,
        mountLetterboxDelay = 0,
        perma = false

    },
    interaction = {
        forceThirdPersonDialogue = true,
        forceThirdPersonVendor = false,
        forceThirdPersonBank = false,
        forceThirdPersonQuest = true,
        forceThirdPersonCrafting = false,
        forceThirdPersonDye = false,
        hidePlayerOptions = false,
        forceThirdPersonInteractiveNotes = false,
        allowCameraMovementDuringDialogue = true,
        allowImmersionControls = true,
        layoutPreset = "cinematic",
        autoEmoteFrequency = "infrequent",
        ui = {
            hidePanelsESO = true,
        },
        auto = {
            autoLetterboxDialogue = false,
            autoHideUIDialogue = false,
            autoLetterboxConversation = true,
            autoLetterboxQuest = true,
            autoLetterboxVendor = false,
            autoLetterboxBank = false,
            autoLetterboxCrafting = false,
        },
        subtitles = {
            isHidden = false,
            useChunkedDialogue = true,
            posY = 0.8,
            posX = 0.5,
            hidePlayerOptionsUntilLastChunk = false,
            textColor = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 },

        },
    },
    interface = {
        currentPreset = "none",
        UiElementsVisible = true,
        hideDialoguePanels = true,
        hideCompass = "always",
        hideReticle = "always",
        hideActionBar = "always",
        usingModTweaks = true,


        selectedFont = "ESO_Standard",
        customFontSize = 48,
        fontScale = 1.0,
        dialogueHorizontalOffset = 0.34,
        dialogueVerticalOffset = 0.34,

        defaultBackgroundMode = "none",   -- "esoDefault", "none"
        cinematicBackgroundMode = "none", -- "kingdom", "redemption_banner", "none"

        useSubtitleBackground = false,
        usePlayerOptionsBackground = false,
        sepiaFilter = {
            enabled = false,
            intensity = 0.3,
            useTextured = false,
        },
    },
    emoteWheel = {
        slot1 = "idle",     -- Top
        slot2 = "friendly", -- Right
        slot3 = "greeting", -- Bottom
        slot4 = "hostile",  -- Left
        lastUsedSlot = 1    -- 1,2,3,4
    },
    hideUiElements = {},
    chunkedDialog = {
        chunkDisplayInterval = 3.0,
        chunkDelimiters = { ".", "!", "?" },
        chunkMinLength = 10,
        chunkMaxLength = 200,
        baseDisplayTime = 0.8,
        timePerCharacter = 0.08,
        minDisplayTime = 0.6,
        maxDisplayTime = 8.0,
        timingMode = "dynamic",
        usePunctuationTiming = true,
        hyphenPauseTime = 0.3,
        commaPauseTime = 0.2,
        semicolonPauseTime = 0.25,
        colonPauseTime = 0.3,
        dashPauseTime = 0.4,
        ellipsisPauseTime = 0.5,
    },

}
