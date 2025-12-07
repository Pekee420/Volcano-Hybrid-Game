# VolcanoGame Handoff

## Directory
`/Users/petermaksimenko/TradeRunner/VolcanoGame`

## Project Structure
```
VolcanoGame/
├── Sources/VolcanoGame/       # macOS app source
│   ├── main.swift             # macOS entry point
│   ├── ContentView.swift      # macOS main view (uses AppKit/NSEvent)
│   ├── Views.swift            # macOS game views
│   ├── SettingsView.swift     # macOS settings (brightness slider)
│   ├── Models.swift           # Shared game logic + Snoop AI
│   ├── BluetoothManager.swift # Volcano BLE control
│   ├── SoundManager.swift     # Audio
│   └── Extensions.swift       # Shared utilities
├── iOS/                       # iOS app source
│   ├── VolcanoGameiOSApp.swift
│   ├── iOSContentView.swift   # All iOS views (850+ lines)
│   ├── Info.plist
│   └── Assets.xcassets/
├── VolcanoGameiOS.xcodeproj/  # iOS Xcode project
├── mp3/                       # Sound files
├── icons/                     # App icons
├── Info.plist                 # macOS Info.plist
└── Package.swift              # Swift Package (macOS)
```

## Current State
- **macOS**: Builds and runs via `swift build` → installed to `/Applications/VolcanoGame.app`
- **iOS**: ✅ BUILD FIXED - Builds successfully via Xcode

## Recent Changes
1. Fixed Volcano BLE UUIDs (heater toggle bug)
   - 10110011/10110012 = Boost (NOT fan) - removed from gameplay
   - 10110005 = LED Brightness
2. Added brightness control to BluetoothManager
3. Nerfed Snoop AI (35% fail, 35% match, 30% win)
4. Removed Views.swift & SettingsView.swift from iOS build (macOS-only)
5. iOS build issue resolved (2025-12-07)
6. Removed personal information from codebase (2025-12-07)
   - Removed hardcoded dev path from SoundManager.swift
   - All source files use generic "AI Assistant" author
   - Git config uses GitHub username (Pekee420)

## Build Status
- iOS Xcode build: ✅ WORKING (cleaned up warnings)
- Fixed:
  - ✅ Added AccentColor to Assets.xcassets (blaze green)
  - ✅ Removed unused heaterRetryCount variable
- Remaining warnings (non-critical):
  - Missing iPad icon sizes (76x76@2x, 83.5x83.5@2x)
  - Models.swift:12 - immutable property with initial value (minor Codable warning)

## Build Commands
```bash
# macOS
cd /Users/petermaksimenko/TradeRunner/VolcanoGame
swift build --configuration release
# Then copy to /Applications/VolcanoGame.app

# iOS
open VolcanoGameiOS.xcodeproj
# Build in Xcode (Cmd+R)
```

## Volcano BLE UUIDs (from APK decompile)
- 10110001: Temperature Read
- 10110003: Temperature Write
- 10110005: LED Brightness (0-100, UInt16 LE)
- 1011000F: Heater On
- 10110010: Heater Off
- 10110013: Air Pump On
- 10110014: Air Pump Off
