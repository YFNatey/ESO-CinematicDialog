CinematicCam.defaults = {
    camEnabled = false,
    npcNamePreset = "default",
    npcNameColor = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 },
    npcNameFontSize = 42,

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
            posX = 0.5

        },
    },
    interface = {
        UiElementsVisible = true,
        hideDialoguePanels = false,
        selectedFont = "ESO_Standard",
        customFontSize = 42,
        fontScale = 1.0,
        dialogueHorizontalOffset = 0.34,
        dialogueVerticalOffset = 0.34,

        defaultBackgroundMode = "esoDefault", -- "esoDefault", "none"
        cinematicBackgroundMode = "all",      -- "all", "subtitles", "playerOptions", "none"

        useSubtitleBackground = true,
        usePlayerOptionsBackground = true,

    },
    hideUiElements = {},
    chunkedDialog = {
        chunkDisplayInterval = 3.0,
        chunkDelimiters = { ".", "!", "?" },
        chunkMinLength = 10,
        chunkMaxLength = 200,
        baseDisplayTime = 1.0,
        timePerCharacter = 0.03,
        minDisplayTime = 1.5,
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
    usePerInteractionSettings = false, -- Global setting
}
