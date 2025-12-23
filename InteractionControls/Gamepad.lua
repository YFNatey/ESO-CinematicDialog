function CinematicCam:GamepadStickPoll()
    if not self.gamepadStickPoll or not self.gamepadStickPoll.isActive then
        self:StopGamepadStickPoll()
        return
    end

    local interactionType = GetInteractionType()
    if interactionType == INTERACTION_NONE then
        -- Interaction ended but event hasn't fired yet
        self:StopGamepadStickPoll()
        if self.isInteractionModified then
            self:OnInteractionEnd()
        end
        return
    end

    -- Only run polling during actual interactions
    if not CinematicCam.isInteractionModified then
        return
    end

    local leftTrigger = GetGamepadLeftTriggerMagnitude()
    local rightTrigger = GetGamepadRightTriggerMagnitude()
    local rightX = ZO_Gamepad_GetRightStickEasedX()
    local rightY = ZO_Gamepad_GetRightStickEasedY()
    local leftX = ZO_Gamepad_GetLeftStickEasedX()
    local leftY = ZO_Gamepad_GetLeftStickEasedY()

    local rightMagnitude = zo_sqrt(rightX * rightX + rightY * rightY)
    local leftMagnitude = zo_sqrt(leftX * leftX + leftY * leftY)
    local currentTime = GetGameTimeMilliseconds()


    --  disable camera UI mode (free camera)
    if rightMagnitude > 0 and rightTrigger == 0 then
        SetGameCameraUIMode(CinematicCam.CAMERA_MODE.FREE)
    end
    if leftMagnitude > 0 and rightTrigger == 0 then
        SetGameCameraUIMode(CinematicCam.CAMERA_MODE.FREE)
    end
    -- Left trigger to activate emote pad
    if leftTrigger > 0.3 and CinematicCam.savedVars.interaction.allowImmersionControls then
        SetGameCameraUIMode(CinematicCam.CAMERA_MODE.FREE)

        -- Show emote pad if not visible
        if not self.emotePadVisible then
            self:ShowEmotePad()
        end

        -- Hide camera pad if visible
        if self.cameraPadVisible then
            self:HideCameraPad()
            self:ResetCameraHighlights()
        end

        if rightMagnitude > self.gamepadStickPoll.deadzone then
            -- Check emote cooldown
            local timeSinceLastEmote = currentTime - self.gamepadStickPoll.lastEmoteTime

            if timeSinceLastEmote >= self.gamepadStickPoll.emoteCooldown then
                if math.abs(rightX) > math.abs(rightY) then
                    if rightX > 0 then
                        -- Slot 2 (Right)
                        self:HighlightEmoteDirection("Right")
                        local emote = self:GetEmoteForSlot(2)
                        CinematicCam.savedVars.emoteWheel.lastUsedSlot = 2

                        if emote then
                            DoCommand(emote)
                            self.gamepadStickPoll.lastEmoteTime = currentTime
                        end
                    elseif rightX < 0 then
                        -- Slot 4 (Left)
                        self:HighlightEmoteDirection("Left")
                        local emote = self:GetEmoteForSlot(4)
                        CinematicCam.savedVars.emoteWheel.lastUsedSlot = 4

                        if emote then
                            DoCommand(emote)
                            self.gamepadStickPoll.lastEmoteTime = currentTime
                        end
                    end
                else
                    if rightY > 0 then
                        -- Slot 1 (Top)
                        self:HighlightEmoteDirection("Top")
                        local emote = self:GetEmoteForSlot(1)
                        CinematicCam.savedVars.emoteWheel.lastUsedSlot = 1
                        if emote then
                            DoCommand(emote)
                            self.gamepadStickPoll.lastEmoteTime = currentTime
                        end
                    elseif rightY < 0 then
                        -- Slot 3 (Bottom)
                        self:HighlightEmoteDirection("Bottom")
                        local emote = self:GetEmoteForSlot(3)
                        CinematicCam.savedVars.emoteWheel.lastUsedSlot = 3

                        if emote then
                            DoCommand(emote)
                            self.gamepadStickPoll.lastEmoteTime = currentTime
                        end
                    end
                end
            end
        else
            self:ResetEmoteHighlights()
        end
        -- Right trigger to activate camera pad
    elseif rightTrigger > 0.3 and CinematicCam.savedVars.interaction.allowCameraMovementDuringDialogue then
        -- Show camera pad if not visible
        if not self.cameraPadVisible then
            self:ShowCameraPad()
        end

        -- Hide emote pad if visible
        if self.emotePadVisible then
            self:HideEmotePad()
            self:ResetEmoteHighlights()
        end


        if rightMagnitude > 0 then
            -- Check cooldown before allowing camera switch
            local timeSinceLastSwitch = currentTime - self.gamepadStickPoll.lastCameraSwitch

            if math.abs(rightX) > math.abs(rightY) then
                -- Left/Right for camera UI mode toggle (with cooldown)
                if timeSinceLastSwitch >= self.gamepadStickPoll.cameraSwitchCooldown then
                    if rightX > 0 then
                        -- Right - Enable camera UI mode (lock camera)
                        self:HighlightCameraDirection("Right")
                        self.savedVars.useCinematicCamera = true
                        SetInteractionUsingInteractCamera(self.savedVars.useCinematicCamera)

                        self.gamepadStickPoll.lastCameraSwitch = currentTime
                    elseif rightX < 0 then
                        -- Left - Disable camera UI mode (free camera)
                        self:HighlightCameraDirection("Left")

                        self.savedVars.useCinematicCamera = false
                        SetInteractionUsingInteractCamera(self.savedVars.useCinematicCamera)
                        self.gamepadStickPoll.lastCameraSwitch = currentTime
                    end
                end
            else
                -- Up/Down for zoom
                if rightY > 0 then
                    self:HighlightCameraDirection("Top")
                    CameraZoomIn()
                    SetGameCameraUIMode(CinematicCam.CAMERA_MODE.STATIC)
                elseif rightY < 0 then
                    self:HighlightCameraDirection("Bottom")
                    CameraZoomOut()
                    SetGameCameraUIMode(CinematicCam.CAMERA_MODE.STATIC)
                end
            end
        else
            self:ResetCameraHighlights()
        end
    else
        -- Hide both pads when no trigger is pressed
        if self.emotePadVisible then
            self:HideEmotePad()
            self:ResetEmoteHighlights()
        end

        if self.cameraPadVisible then
            self:HideCameraPad()
            self:ResetCameraHighlights()
        end

        -- Right stick camera controls when no trigger pressed
        -- Only apply free camera if we're in free mode
        if rightMagnitude >= self.gamepadStickPoll.deadzone then
            if self.gamepadStickPoll.currentCameraMode == "free" then
                SetGameCameraUIMode(CinematicCam.CAMERA_MODE.FREE)
            end
        end
    end
end

function CinematicCam:StopGamepadStickPoll()
    if not self.gamepadStickPoll then return end
    self.gamepadStickPoll.isActive = false


    self:HideEmoteWheel()
    self:HideEmotePad()
    self:HideCameraWheel()
    self:HideCameraPad()
end
