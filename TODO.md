# PawSanctuary — TODO

## Pending

- [ ] Drag `SoundManager.swift` from Finder into the Xcode project navigator and add it to the PawSanctuary target. Xcode won't pick it up automatically since it was created outside the IDE.
- [ ] Drag `HapticManager.swift` from Finder into the Xcode project navigator and add it to the PawSanctuary target.
- [ ] Enable **Push Notifications** capability in Xcode: target → Signing & Capabilities → + Push Notifications. Required for `UNUserNotificationCenter` permission prompt to work on device.
- [ ] When ready for final audio assets, replace `AudioServicesPlaySystemSound(XXXX)` calls in `SoundManager.swift` with `AVAudioPlayer` instances pointed at the real asset files.
