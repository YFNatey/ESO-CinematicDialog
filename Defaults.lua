CinematicCam.defaults = {
    camEnabled = false,
    npcNamePreset = "default",
    npcNameColor = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 },
    npcNameFontSize = 42,
    usePlayerName = false,
    playerNameColor = { r = 0.8, g = 0.8, b = 1.0, a = 1.0 },
    dialogueElementsHidden = false,
    homePresets = {},

    lastSeenUpdateVersion = "0.0.0",
    hasSeenWelcomeMessage = false,
    selectedCompanion = "ember",
    companionColors = {
        ["bastian hallix"] = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 },
        ["mirri elendis"] = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 },
        ember = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 },
        ["isobel veloise"] = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 },
        ["azandar al-cybiades"] = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 },
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

        layoutPreset = "default",
        ui = {
            hidePanelsESO = false,
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
            useChunkedDialogue = false,
            posY = 0.8,
            posX = 0.5,
            hidePlayerOptionsUntilLastChunk = false,
            textColor = { r = 0.9, g = 0.9, b = 0.8, a = 1.0 },

        },
    },
    interface = {
        currentPreset = "none",
        UiElementsVisible = true,
        hideDialoguePanels = false,
        hideCompass = false,
        hideReticle = "never",
        hideActionBar = false,

        selectedFont = "ESO_Standard",
        customFontSize = 42,
        fontScale = 1.0,
        dialogueHorizontalOffset = 0.34,
        dialogueVerticalOffset = 0.34,

        defaultBackgroundMode = "esoDefault", -- "esoDefault", "none"
        cinematicBackgroundMode = "none",     -- "all", "subtitles", "playerOptions", "none"

        useSubtitleBackground = false,
        usePlayerOptionsBackground = false,

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
