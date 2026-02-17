# Detailed UI Mockups for Simplified Cross-Platform VPN Client

## Overview
This document contains detailed UI mockups for the simplified VPN client with only three core functions: "Add Profile", "Start VPN", and "Settings". The mockups follow the design strategy outlined in the UI/UX design document, ensuring consistency across all platforms while respecting platform-specific UI guidelines.

## 1. Main Screen Layout

### Desktop Main Screen
```
┌─────────────────────────────────────────────────────────────┐
│  [Shield Icon] VPN Client                    [Min] [_] [X] │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│                        [VPN STATUS CARD]                    │
│  ┌─────────────────────────────────────────────────────────┐│
│  │                    [VPN SHIELD ICON]                    ││
│  │                   CONNECTION STATUS                     ││
│  │                 (Location: Tokyo, Japan)                ││
│  │                                                         ││
│  │                   ↓ Download: 18.2 MB/s                 ││
│  │                   ↑ Upload: 12.4 MB/s                   ││
│  │                   ⚡ Ping: 24 ms                         ││
│  └─────────────────────────────────────────────────────────┘│
│                                                             │
│                   [MAIN ACTION BUTTON]                      │
│                     [ START VPN ]                           │
│                                                             │
│            [ADD PROFILE] [SETTINGS] [MORE...]              │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Mobile Main Screen
```
┌─────────────────────────┐
│ [Shield] VPN Client     │
├─────────────────────────┤
│                         │
│      [VPN STATUS]       │
│   [SHIELD ICON]         │
│   CONNECTED             │
│   Tokyo, Japan          │
│                         │
│   ↓ 18.2 MB/s           │
│   ↑ 12.4 MB/s           │
│   Ping: 24 ms           │
│                         │
│    [START VPN BTN]      │
│    [ 96px Diameter ]    │
│                         │
│  [ADD] [SET] [...]      │
└─────────────────────────┘
```

## 2. Connection Status and Performance Display

### Status Card Elements
The central status card displays:
- Status icon that changes based on connection state
- Connection status text (Disconnected, Connecting, Connected, Error)
- Server location (City, Country)
- Performance metrics (Download/Upload speeds, Ping)
- Additional connection information if relevant

### Connection State Visuals

#### Disconnected State
```
┌─────────────────────────────────────────────────────────────┐
│                        [VPN STATUS CARD]                    │
│  ┌─────────────────────────────────────────────────────────┐│
│  │                    [GRAY CIRCLE ICON]                   ││
│  │                    DISCONNECTED                         ││
│  │                     No VPN Active                       ││
│  │                                                         ││
│  │                   ↓ Download: --                        ││
│  │                   ↑ Upload: --                          ││
│  │                   ⚡ Ping: --                           ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
```

#### Connecting State
```
┌─────────────────────────────────────────────────────────────┐
│                        [VPN STATUS CARD]                    │
│  ┌─────────────────────────────────────────────────────────┐│
│  │                    [SPINNER ANIMATION]                  ││
│  │                    CONNECTING...                        ││
│  │                  Establishing secure                    ││
│  │                    connection                           ││
│  │                                                         ││
│  │                   ↓ Download: --                        ││
│  │                   ↑ Upload: --                          ││
│  │                   ⚡ Ping: --                           ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
```

#### Connected State
```
┌─────────────────────────────────────────────────────────────┐
│                        [VPN STATUS CARD]                    │
│  ┌─────────────────────────────────────────────────────────┐│
│  │                    [GREEN SHIELD ICON]                  ││
│  │                     CONNECTED                           ││
│  │                    Tokyo, Japan                         ││
│  │                                                         ││
│  │                   ↓ Download: 18.2 MB/s  [●●●●○]       ││
│  │                   ↑ Upload: 12.4 MB/s    [●●●●○]       ││
│  │                   ⚡ Ping: 24 ms           [●●●●●]       ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
```

#### Error State
```
┌─────────────────────────────────────────────────────────────┐
│                        [VPN STATUS CARD]                    │
│  ┌─────────────────────────────────────────────────────────┐│
│  │                    [RED EXCLAMATION]                    ││
│  │                  CONNECTION FAILED                      ││
│  │                 Check your settings                     ││
│  │                                                         ││
│  │                   ↓ Download: --                        ││
│  │                   ↑ Upload: --                          ││
│  │                   ⚡ Ping: --                           ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
```

### Performance Metrics Visual Feedback
- Download/Upload speeds: Colored based on performance (Green: Excellent, Yellow: Good, Red: Poor)
- Ping time: Colored based on latency (Green: <50ms, Yellow: 50-100ms, Red: >100ms)
- Signal strength indicators shown as bars or dots

## 3. Add Profile Flow

### Add Profile Main Screen
```
┌─────────────────────────────────────────────────────────────┐
│  [Shield Icon] VPN Client                    [Min] [_] [X] │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│                        ADD PROFILE                          │
│                                                             │
│   [QR Code Scanner]     [Manual Entry]      [Import File]   │
│      [Camera Icon]       [Pencil Icon]       [Folder Icon]  │
│                                                             │
│        Scan a QR code to add a new VPN profile             │
│                                                             │
│                    [SCAN QR CODE]                           │
│                                                             │
│                 Or enter connection details:                │
│   ┌─────────────────────────────────────────────────────────┐│
│   │     Server Address: _____________________________      ││
│   │        Port: ______________ Password: ________________ ││
│   │   Public Key: _______________________________________   ││
│   │     User ID: _____________________________             ││
│   └─────────────────────────────────────────────────────────┘│
│                                                             │
│                [ADD PROFILE]    [CANCEL]                    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### QR Code Scanner Screen
```
┌─────────────────────────┐
│        ADD PROFILE      │
├─────────────────────────┤
│    [CAMERA PREVIEW]     │
│                         │
│    [┌─────────────┐]    │  ← Overlay frame for QR code
│    [│ QR SCANNER  │]    │
│    [│    AREA     │]    │
│    [└─────────────┘]    │
│                         │
│   Align QR code within  │
│     the frame to scan   │
│                         │
│    [CANCEL] [FLASH ON]  │
└─────────────────────────┘
```

### Manual Entry Form
```
┌─────────────────────────────────────────────────────────────┐
│  [Shield Icon] VPN Client                    [Min] [_] [X] │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│                        ADD PROFILE                          │
│                     Manual Entry                            │
│                                                             │
│   ┌─────────────────────────────────────────────────────────┐│
│   │ Profile Name: [_________________________]               ││
│   │ Protocol: [▼ WireGuard                ▼]               ││
│   └─────────────────────────────────────────────────────────┘│
│                                                             │
│   ┌─────────────────────────────────────────────────────────┐│
│   │ Server Address: [_________________________]             ││
│   │ Server Port:    [____]                                 ││
│   │ Server Public Key:                                      ││
│   │ [_________________________________________________]     ││
│   │ User ID: [_______________________________________]      ││
│   │ Password: [_______________________________________]     ││
│   │ Pre-shared Key: [________________________________]      ││
│   └─────────────────────────────────────────────────────────┘│
│                                                             │
│   [TEST CONNECTION] [ADD PROFILE] [CANCEL]                 ││
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## 4. Settings Interface

### Main Settings Screen
```
┌─────────────────────────────────────────────────────────────┐
│  [Shield Icon] VPN Client                    [Min] [_] [X] │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│                           SETTINGS                          │
│                                                             │
│   ┌─────────────────────────────────────────────────────────┐│
│   │ Connection Settings                                     ││
│   │ • Auto-connect on startup: [✓] [toggle]               ││
│   │ • DNS Settings: [Custom DNS...]                        ││
│   │ • Protocol Selection: [▼ WireGuard ▼]                 ││
│   └─────────────────────────────────────────────────────────┘│
│                                                             │
│   ┌─────────────────────────────────────────────────────────┐│
│   │ Split Tunneling (App Routing)                          ││
│   │ • [Apps via VPN] [Apps Direct] [toggle]               ││
│   │ • Configure apps: [Configure...]                       ││
│   └─────────────────────────────────────────────────────────┘│
│                                                             │
│   ┌─────────────────────────────────────────────────────────┐│
│   │ Privacy Settings                                        ││
│   │ • Kill Switch: [✓] [toggle]                           ││
│   │ • IPv6 Leak Protection: [✓] [toggle]                  ││
│   │ • Ad Tracker Blocking: [ ] [toggle]                   ││
│   └─────────────────────────────────────────────────────────┘│
│                                                             │
│   ┌─────────────────────────────────────────────────────────┐│
│   │ About                                                 ││
│   │ • Version: 1.0.0                                      ││
│   │ • Check for Updates                                    ││
│   │ • Support                                             ││
│   └─────────────────────────────────────────────────────────┘│
│                                                             │
│                        [DONE]                               │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### App Routing (Split Tunneling) Screen
Desktop Version:
```
┌─────────────────────────────────────────────────────────────┐
│ Settings > App Routing                    [Min] [_] [X]     │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│                    APP ROUTING                              │
│                                                             │
│  [□] Include Mode Only    [■] Exclude Mode (Recommended)    ││
│                                                             │
│  Currently routed apps:                                     ││
│  [✓] Chrome                [Remove]                        ││
│  [✓] Spotify               [Remove]                        ││
│                                                             │
│  Available apps:                                            ││
│  [ ] Facebook      [ ] Instagram     [ ] WhatsApp          ││
│  [ ] Gmail         [ ] YouTube       [ ] Discord           ││
│  [ ] Telegram      [ ] Slack         [ ] Zoom              ││
│                                                             │
│  [Select All] [Select Apps...] [Search] [Reset]            ││
│                                                             │
│                    [SAVE] [CANCEL]                          ││
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

Mobile Version:
```
┌─────────────────────────┐
│      App Routing        │
├─────────────────────────┤
│                         │
│ [Toggle] Include Mode   │
│ [ ] Exclude Mode        │
│                         │
│ Selected Apps:          │
│ [✓] Chrome    [REMOVE]  │
│ [✓] Spotify   [REMOVE]  │
│ [ ] Facebook           │
│ [ ] Instagram          │
│ [ ] WhatsApp           │
│ [ ] Gmail              │
│ [ ] YouTube            │
│                         │
│ [Select Apps] [Search]  │
│                         │
│      [SAVE] [BACK]      │
└─────────────────────────┘
```

## 5. Cross-Platform Consistency

### Visual Design Consistency
All platforms maintain:
- Same color palette (Deep Blue #1E3A8A as primary)
- Same typography hierarchy
- Same iconography for functions
- Same status indicators and meanings
- Same spacing and layout principles

### Platform-Specific Adaptations

#### Android
- Material Design 3 (Material You) with dynamic color
- Floating Action Button for primary action
- Status bar integration with connection color
- Navigation bar with secondary actions

#### iOS
- Human Interface Guidelines compliant
- Native navigation patterns
- Control Center style for quick access
- Haptic feedback for interactions

#### Windows
- Fluent Design elements integrated appropriately
- Title bar with standard controls
- System tray integration for quick status
- Native context menus

#### macOS
- Native macOS appearance
- Menu bar status item
- Sheet presentation for secondary views
- Natural macOS control styles

#### Linux
- GTK/Qt native appearance when possible
- System tray indicator
- Native dialog appearances
- Desktop environment integration

## 6. Visual Feedback States

### Button States
- **Normal**: Primary blue (#1E3A8A) background
- **Hover**: Darker shade of primary color
- **Pressed**: Even darker shade with subtle inset shadow
- **Disabled**: Grayed out with reduced opacity

### Input Field States
- **Normal**: Light gray border
- **Focused**: Primary blue border with subtle glow
- **Error**: Red border with error icon
- **Validated**: Green checkmark indicator

### Connection Status Colors
- **Disconnected**: Gray (#6B7280)
- **Connecting**: Amber (#F59E0B) with animation
- **Connected**: Forest Green (#10B981)
- **Error**: Crimson (#EF4444)
- **Reconnecting**: Orange (#F97316)

## 7. Accessibility Features

### Visual Accessibility
- High contrast ratio maintained (4.5:1 minimum)
- Large touch targets (48px minimum on mobile, 44px recommended)
- Focus states clearly visible for keyboard navigation
- Text size scalability up to 200%

### Motor Accessibility
- Touch targets optimized for finger interaction
- Voice control compatibility for primary actions
- Keyboard navigation for all interactive elements

### Cognitive Accessibility
- Clear, non-technical language
- Consistent layout and element positioning
- Progressive disclosure of advanced features
- Contextual help available for complex settings

## 8. Animation Guidelines

### Micro-interactions
- Button presses: 150ms animation with subtle scale
- State changes: 300ms ease-in-out transition
- Loading animations: Smooth continuous movement
- Page transitions: Slide in/out with 200ms duration

### Reduced Motion Support
- All animations respect system reduce-motion preference
- Static alternatives provided when motion is disabled
- Essential animations remain functional but subtle

This comprehensive mockup specification ensures a consistent, accessible, and user-friendly VPN client experience across all supported platforms while maintaining the simplicity that makes the product approachable to non-technical users.
## Overview
This document contains detailed UI mockups for the simplified VPN client with only three core functions: "Add Profile", "Start VPN", and "Settings". The mockups follow the design strategy outlined in the UI/UX design document, ensuring consistency across all platforms while respecting platform-specific UI guidelines.

## 1. Main Screen Layout

### Desktop Main Screen
```
┌─────────────────────────────────────────────────────────────┐
│  [Shield Icon] VPN Client                    [Min] [_] [X] │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│                        [VPN STATUS CARD]                    │
│  ┌─────────────────────────────────────────────────────────┐│
│  │                    [VPN SHIELD ICON]                    ││
│  │                   CONNECTION STATUS                     ││
│  │                 (Location: Tokyo, Japan)                ││
│  │                                                         ││
│  │                   ↓ Download: 18.2 MB/s                 ││
│  │                   ↑ Upload: 12.4 MB/s                   ││
│  │                   ⚡ Ping: 24 ms                         ││
│  └─────────────────────────────────────────────────────────┘│
│                                                             │
│                   [MAIN ACTION BUTTON]                      │
│                     [ START VPN ]                           │
│                                                             │
│            [ADD PROFILE] [SETTINGS] [MORE...]              │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Mobile Main Screen
```
┌─────────────────────────┐
│ [Shield] VPN Client     │
├─────────────────────────┤
│                         │
│      [VPN STATUS]       │
│   [SHIELD ICON]         │
│   CONNECTED             │
│   Tokyo, Japan          │
│                         │
│   ↓ 18.2 MB/s           │
│   ↑ 12.4 MB/s           │
│   Ping: 24 ms           │
│                         │
│    [START VPN BTN]      │
│    [ 96px Diameter ]    │
│                         │
│  [ADD] [SET] [...]      │
└─────────────────────────┘
```

## 2. Connection Status and Performance Display

### Status Card Elements
The central status card displays:
- Status icon that changes based on connection state
- Connection status text (Disconnected, Connecting, Connected, Error)
- Server location (City, Country)
- Performance metrics (Download/Upload speeds, Ping)
- Additional connection information if relevant

### Connection State Visuals

#### Disconnected State
```
┌─────────────────────────────────────────────────────────────┐
│                        [VPN STATUS CARD]                    │
│  ┌─────────────────────────────────────────────────────────┐│
│  │                    [GRAY CIRCLE ICON]                   ││
│  │                    DISCONNECTED                         ││
│  │                     No VPN Active                       ││
│  │                                                         ││
│  │                   ↓ Download: --                        ││
│  │                   ↑ Upload: --                          ││
│  │                   ⚡ Ping: --                           ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
```

#### Connecting State
```
┌─────────────────────────────────────────────────────────────┐
│                        [VPN STATUS CARD]                    │
│  ┌─────────────────────────────────────────────────────────┐│
│  │                    [SPINNER ANIMATION]                  ││
│  │                    CONNECTING...                        ││
│  │                  Establishing secure                    ││
│  │                    connection                           ││
│  │                                                         ││
│  │                   ↓ Download: --                        ││
│  │                   ↑ Upload: --                          ││
│  │                   ⚡ Ping: --                           ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
```

#### Connected State
```
┌─────────────────────────────────────────────────────────────┐
│                        [VPN STATUS CARD]                    │
│  ┌─────────────────────────────────────────────────────────┐│
│  │                    [GREEN SHIELD ICON]                  ││
│  │                     CONNECTED                           ││
│  │                    Tokyo, Japan                         ││
│  │                                                         ││
│  │                   ↓ Download: 18.2 MB/s  [●●●●○]       ││
│  │                   ↑ Upload: 12.4 MB/s    [●●●●○]       ││
│  │                   ⚡ Ping: 24 ms           [●●●●●]       ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
```

#### Error State
```
┌─────────────────────────────────────────────────────────────┐
│                        [VPN STATUS CARD]                    │
│  ┌─────────────────────────────────────────────────────────┐│
│  │                    [RED EXCLAMATION]                    ││
│  │                  CONNECTION FAILED                      ││
│  │                 Check your settings                     ││
│  │                                                         ││
│  │                   ↓ Download: --                        ││
│  │                   ↑ Upload: --                          ││
│  │                   ⚡ Ping: --                           ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
```

### Performance Metrics Visual Feedback
- Download/Upload speeds: Colored based on performance (Green: Excellent, Yellow: Good, Red: Poor)
- Ping time: Colored based on latency (Green: <50ms, Yellow: 50-100ms, Red: >100ms)
- Signal strength indicators shown as bars or dots

## 3. Add Profile Flow

### Add Profile Main Screen
```
┌─────────────────────────────────────────────────────────────┐
│  [Shield Icon] VPN Client                    [Min] [_] [X] │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│                        ADD PROFILE                          │
│                                                             │
│   [QR Code Scanner]     [Manual Entry]      [Import File]   │
│      [Camera Icon]       [Pencil Icon]       [Folder Icon]  │
│                                                             │
│        Scan a QR code to add a new VPN profile             │
│                                                             │
│                    [SCAN QR CODE]                           │
│                                                             │
│                 Or enter connection details:                │
│   ┌─────────────────────────────────────────────────────────┐│
│   │     Server Address: _____________________________      ││
│   │        Port: ______________ Password: ________________ ││
│   │   Public Key: _______________________________________   ││
│   │     User ID: _____________________________             ││
│   └─────────────────────────────────────────────────────────┘│
│                                                             │
│                [ADD PROFILE]    [CANCEL]                    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### QR Code Scanner Screen
```
┌─────────────────────────┐
│        ADD PROFILE      │
├─────────────────────────┤
│    [CAMERA PREVIEW]     │
│                         │
│    [┌─────────────┐]    │  ← Overlay frame for QR code
│    [│ QR SCANNER  │]    │
│    [│    AREA     │]    │
│    [└─────────────┘]    │
│                         │
│   Align QR code within  │
│     the frame to scan   │
│                         │
│    [CANCEL] [FLASH ON]  │
└─────────────────────────┘
```

### Manual Entry Form
```
┌─────────────────────────────────────────────────────────────┐
│  [Shield Icon] VPN Client                    [Min] [_] [X] │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│                        ADD PROFILE                          │
│                     Manual Entry                            │
│                                                             │
│   ┌─────────────────────────────────────────────────────────┐│
│   │ Profile Name: [_________________________]               ││
│   │ Protocol: [▼ WireGuard                ▼]               ││
│   └─────────────────────────────────────────────────────────┘│
│                                                             │
│   ┌─────────────────────────────────────────────────────────┐│
│   │ Server Address: [_________________________]             ││
│   │ Server Port:    [____]                                 ││
│   │ Server Public Key:                                      ││
│   │ [_________________________________________________]     ││
│   │ User ID: [_______________________________________]      ││
│   │ Password: [_______________________________________]     ││
│   │ Pre-shared Key: [________________________________]      ││
│   └─────────────────────────────────────────────────────────┘│
│                                                             │
│   [TEST CONNECTION] [ADD PROFILE] [CANCEL]                 ││
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## 4. Settings Interface

### Main Settings Screen
```
┌─────────────────────────────────────────────────────────────┐
│  [Shield Icon] VPN Client                    [Min] [_] [X] │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│                           SETTINGS                          │
│                                                             │
│   ┌─────────────────────────────────────────────────────────┐│
│   │ Connection Settings                                     ││
│   │ • Auto-connect on startup: [✓] [toggle]               ││
│   │ • DNS Settings: [Custom DNS...]                        ││
│   │ • Protocol Selection: [▼ WireGuard ▼]                 ││
│   └─────────────────────────────────────────────────────────┘│
│                                                             │
│   ┌─────────────────────────────────────────────────────────┐│
│   │ Split Tunneling (App Routing)                          ││
│   │ • [Apps via VPN] [Apps Direct] [toggle]               ││
│   │ • Configure apps: [Configure...]                       ││
│   └─────────────────────────────────────────────────────────┘│
│                                                             │
│   ┌─────────────────────────────────────────────────────────┐│
│   │ Privacy Settings                                        ││
│   │ • Kill Switch: [✓] [toggle]                           ││
│   │ • IPv6 Leak Protection: [✓] [toggle]                  ││
│   │ • Ad Tracker Blocking: [ ] [toggle]                   ││
│   └─────────────────────────────────────────────────────────┘│
│                                                             │
│   ┌─────────────────────────────────────────────────────────┐│
│   │ About                                                 ││
│   │ • Version: 1.0.0                                      ││
│   │ • Check for Updates                                    ││
│   │ • Support                                             ││
│   └─────────────────────────────────────────────────────────┘│
│                                                             │
│                        [DONE]                               │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### App Routing (Split Tunneling) Screen
Desktop Version:
```
┌─────────────────────────────────────────────────────────────┐
│ Settings > App Routing                    [Min] [_] [X]     │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│                    APP ROUTING                              │
│                                                             │
│  [□] Include Mode Only    [■] Exclude Mode (Recommended)    ││
│                                                             │
│  Currently routed apps:                                     ││
│  [✓] Chrome                [Remove]                        ││
│  [✓] Spotify               [Remove]                        ││
│                                                             │
│  Available apps:                                            ││
│  [ ] Facebook      [ ] Instagram     [ ] WhatsApp          ││
│  [ ] Gmail         [ ] YouTube       [ ] Discord           ││
│  [ ] Telegram      [ ] Slack         [ ] Zoom              ││
│                                                             │
│  [Select All] [Select Apps...] [Search] [Reset]            ││
│                                                             │
│                    [SAVE] [CANCEL]                          ││
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

Mobile Version:
```
┌─────────────────────────┐
│      App Routing        │
├─────────────────────────┤
│                         │
│ [Toggle] Include Mode   │
│ [ ] Exclude Mode        │
│                         │
│ Selected Apps:          │
│ [✓] Chrome    [REMOVE]  │
│ [✓] Spotify   [REMOVE]  │
│ [ ] Facebook           │
│ [ ] Instagram          │
│ [ ] WhatsApp           │
│ [ ] Gmail              │
│ [ ] YouTube            │
│                         │
│ [Select Apps] [Search]  │
│                         │
│      [SAVE] [BACK]      │
└─────────────────────────┘
```

## 5. Cross-Platform Consistency

### Visual Design Consistency
All platforms maintain:
- Same color palette (Deep Blue #1E3A8A as primary)
- Same typography hierarchy
- Same iconography for functions
- Same status indicators and meanings
- Same spacing and layout principles

### Platform-Specific Adaptations

#### Android
- Material Design 3 (Material You) with dynamic color
- Floating Action Button for primary action
- Status bar integration with connection color
- Navigation bar with secondary actions

#### iOS
- Human Interface Guidelines compliant
- Native navigation patterns
- Control Center style for quick access
- Haptic feedback for interactions

#### Windows
- Fluent Design elements integrated appropriately
- Title bar with standard controls
- System tray integration for quick status
- Native context menus

#### macOS
- Native macOS appearance
- Menu bar status item
- Sheet presentation for secondary views
- Natural macOS control styles

#### Linux
- GTK/Qt native appearance when possible
- System tray indicator
- Native dialog appearances
- Desktop environment integration

## 6. Visual Feedback States

### Button States
- **Normal**: Primary blue (#1E3A8A) background
- **Hover**: Darker shade of primary color
- **Pressed**: Even darker shade with subtle inset shadow
- **Disabled**: Grayed out with reduced opacity

### Input Field States
- **Normal**: Light gray border
- **Focused**: Primary blue border with subtle glow
- **Error**: Red border with error icon
- **Validated**: Green checkmark indicator

### Connection Status Colors
- **Disconnected**: Gray (#6B7280)
- **Connecting**: Amber (#F59E0B) with animation
- **Connected**: Forest Green (#10B981)
- **Error**: Crimson (#EF4444)
- **Reconnecting**: Orange (#F97316)

## 7. Accessibility Features

### Visual Accessibility
- High contrast ratio maintained (4.5:1 minimum)
- Large touch targets (48px minimum on mobile, 44px recommended)
- Focus states clearly visible for keyboard navigation
- Text size scalability up to 200%

### Motor Accessibility
- Touch targets optimized for finger interaction
- Voice control compatibility for primary actions
- Keyboard navigation for all interactive elements

### Cognitive Accessibility
- Clear, non-technical language
- Consistent layout and element positioning
- Progressive disclosure of advanced features
- Contextual help available for complex settings

## 8. Animation Guidelines

### Micro-interactions
- Button presses: 150ms animation with subtle scale
- State changes: 300ms ease-in-out transition
- Loading animations: Smooth continuous movement
- Page transitions: Slide in/out with 200ms duration

### Reduced Motion Support
- All animations respect system reduce-motion preference
- Static alternatives provided when motion is disabled
- Essential animations remain functional but subtle

This comprehensive mockup specification ensures a consistent, accessible, and user-friendly VPN client experience across all supported platforms while maintaining the simplicity that makes the product approachable to non-technical users.
