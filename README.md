# VolcanoGame

macOS app for Volcano Hybrid vaporizer game.

## Build & Install
```bash
cd VolcanoGame && ./build.sh
```
This builds the app and installs it to `/Applications/VolcanoGame.app`

## Project Structure
```
Sources/VolcanoGame/
├── main.swift              # App entry point
├── VolcanoGameApp.swift    # SwiftUI App
├── Models.swift            # Player, GameSettings, GameState, HighScore
├── ContentView.swift       # Main view + spacebar handling
├── Views.swift             # SidebarView, PlayerSetupView, GameSetupView, GameView, GameFinishedView
├── BluetoothManager.swift  # BLE connection to Volcano Hybrid
├── SettingsView.swift      # Settings UI
├── SoundManager.swift      # Audio feedback
```

## Game Flow
1. **Setup**: Add player names
2. **Game Setup**: Set starting duration, seconds added per round, prep time
3. **Preparation**: Player holds SPACEBAR to indicate ready
4. **Active**: Timer counts down, air pump runs while spacebar held
5. **Result**: Show points (2/sec + bonus for completion)
6. **Next round**: Cycle duration increases

## Scoring
- 2 points per second held
- +5 bonus for completing cycle
- +5 additional if cycle >15 seconds
- -10 penalty for not pressing spacebar

## Bluetooth (Volcano Hybrid)
- Auto-connects on launch
- Air pump: `10110013-...` (on), `10110014-...` (off)
- Service UUIDs from S&B VOLCANO H device

## Current Features ✅
- Player rotation with SPACEBAR hold/release mechanic
- Air pump control via BLE to Volcano Hybrid
- Temperature control (+/- 5°C buttons)
- Game requires Volcano connection to start
- Scoring: 2 points/second + 5 bonus for completion
- Sidebar with player rankings
- Sound effects for success/failure

## Known Issues to Test
- Temperature BLE commands may need correct characteristic UUIDs
- Air pump activation timing (should trigger when SPACEBAR held in active phase)
- UI layout should keep controls visible at bottom

## Key Files for Context
- `BluetoothManager.swift` - BLE connection & controls
- `Views.swift` - UI with temperature controls overlay
- `Models.swift` - GameState class with temperature property
- `ContentView.swift` - Spacebar global monitoring
