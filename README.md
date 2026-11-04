# Morse Radio

A macOS menu bar Morse keyer written in Swift. Click the menu bar icon to open the key panel. Click the panel and hold **Space** to transmit a tone; a short press is a dot and a longer press is a dash. Right-click the menu bar icon to change the virtual frequency.

## Build

Requirements: macOS 13 or later and Xcode Command Line Tools.

```sh
./Scripts/build-app.sh
open MorseRadio.app
```

The app advertises and discovers peers with Apple's MultipeerConnectivity framework. Devices need to be on the same local Wi-Fi/nearby network and use the exact same virtual frequency. The receiver plays the keyed 650 Hz tone locally. The app does not provide an Internet relay, decode Morse into text, or use licensed radio equipment/frequencies.

macOS may ask for Local Network access the first time the app searches for peers; allow it to discover other devices.
