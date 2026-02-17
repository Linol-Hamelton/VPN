# Split Tunneling (App Routing) Implementation Documentation

## Overview

This document details the implementation of the split tunneling feature (also known as app routing or per-app proxy) in the Hiddify-Next application. This feature allows users to selectively route specific applications through the VPN while allowing others to connect directly to the internet.

## Architecture

### Cross-Platform Repository Pattern

The implementation follows a unified repository pattern that abstracts platform-specific functionality:

```
┌─────────────────────────────────────┐
│     UnifiedPerAppProxyRepository    │
├─────────────────────────────────────┤
│  • getAllInstalledApplications()    │
│  • getApplicationIcon()             │
│  • applyRoutingRules()              │
│  • isAppRoutedThroughVPN()          │
│  • resetRoutingRules()              │
└─────────────────────────────────────┘
                    │
        ┌───────────┼───────────┐
        ▼           ▼           ▼
┌─────────────┐ ┌─────────────┐ ┌─────────────┐
│ Android     │ │ Desktop     │ │ iOS         │
│ Repository  │ │ Repository  │ │ Repository  │
└─────────────┘ └─────────────┘ └─────────────┘
```

### Key Components

1. **Unified Repository Interface** - Abstract interface defining common functionality
2. **Platform-Specific Repositories** - Implementations tailored for each platform
3. **Routing Controller** - Manages actual routing configuration
4. **UI Components** - Visual feedback and configuration screens
5. **Performance Optimizer** - Caching and resource management

## Platform-Specific Implementations

### Android

Uses Android's VPNService with `VpnService.Builder` and the `addAllowedApplication()` and `addDisallowedApplication()` methods:

- **Include Mode**: Only specified apps route through VPN (`builder.addAllowedApplication()`)
- **Exclude Mode**: All apps except specified ones route through VPN (`builder.addDisallowedApplication()`)

### iOS

Implements using Network Extensions with packet tunnel providers:

- Uses `NETunnelProviderProtocol` with application bundle ID filtering
- Leverages `includedAppBoundIdentifiers` and `excludedAppBoundIdentifiers`
- Supports iOS 15+ for full functionality

### Windows

Utilizes Windows Filtering Platform (WFP) for application-specific traffic control:

- Integrates with WinTun driver for TUN interface
- Uses application path-based filtering
- Supports wildcard paths for application families

### macOS

Implements using Network Extension Framework:

- Uses `NEPacketTunnelProvider` with bundle identifier filtering
- Leverages system integration for privileged network operations
- Supports policy routing based on bundle identifiers

### Linux

Implements using iptables with owner matching:

- Uses `iptables` with `-m owner --uid-owner` for UID-based routing
- Leverages network namespaces for isolation
- Uses policy routing with custom routing tables

## Features Implemented

### 1. Enhanced UI for App Selection
- Intuitive interface for selecting applications to route through VPN
- Search and filter capabilities
- Category-based grouping (browsers, social media, etc.)
- System vs user application differentiation

### 2. Cross-Platform Compatibility
- Seamless functionality across Android, iOS, Windows, macOS, and Linux
- Consistent user experience with platform-appropriate UI patterns
- Unified API across all platforms

### 3. Performance Optimizations
- Smart caching of installed applications (5-minute TTL)
- Efficient application enumeration algorithms
- Debounced routing updates to prevent excessive system calls
- Resource monitoring to prevent system slowdown

### 4. Visual Feedback System
- Real-time status indicators for routing configuration
- Progress bars showing percentage of apps in each routing mode
- Clear visual distinction between include/exclude modes
- Status dashboard showing current routing state

### 5. Routing Controls
- Include Mode: Only specified applications route through VPN
- Exclude Mode: All applications except specified ones route through VPN
- Bulk operations for selecting multiple applications
- Ability to reset to default routing behavior

## API Interface

```dart
abstract interface class UnifiedPerAppProxyRepository {
  /// Get all installed applications/packages regardless of platform
  TaskEither<String, List<InstalledPackageInfo>> getAllInstalledApplications();

  /// Get application icon by package/app ID
  TaskEither<String, Uint8List> getApplicationIcon(String appId);

  /// Apply routing rules to the system
  TaskEither<String, Unit> applyRoutingRules(List<String> appIds, bool includeMode);

  /// Get the current routing status of an app
  TaskEither<String, bool> isAppRoutedThroughVPN(String appId);

  /// Reset all routing rules to default
  TaskEither<String, Unit> resetRoutingRules();
}
```

## Usage Examples

### Applying Routing Rules
```dart
final repo = ref.read(unifiedPerAppProxyRepositoryProvider);

// Route only Chrome and Firefox through VPN (Include mode)
await repo.applyRoutingRules(['com.android.chrome', 'org.mozilla.firefox'], true);

// Route all apps except Chrome and Firefox through VPN (Exclude mode)  
await repo.applyRoutingRules(['com.android.chrome', 'org.mozilla.firefox'], false);
```

### Getting Application List
```dart
final apps = await repo.getAllInstalledApplications().getOrElse(() => []);
for (final app in apps) {
  print('App: ${app.name}, Package: ${app.packageName}');
}
```

## Configuration

The split tunneling feature can be accessed through:
1. Settings > Network > Per-App Proxy
2. Direct access from the main app routing screen
3. Programmatically via the repository API

## Testing

The feature has been tested across:
- Android 7.0+ with various OEM customizations
- iOS 15.0+ with different device models
- Windows 10/11 with different network configurations
- macOS 12.0+ (Monterey) and newer
- Major Linux distributions (Ubuntu, Fedora, Arch, etc.)

## Known Limitations

1. **System Applications**: Some system applications cannot be routed differently on certain platforms due to security restrictions
2. **Game Launchers**: Game launchers and certain anti-cheat systems may conflict with routing rules
3. **Performance Impact**: Enabling split tunneling for many apps may cause slight performance overhead
4. **App Updates**: App updates may require reconfiguration of routing rules

## Troubleshooting

### Common Issues
- **No Applications Listed**: Ensure proper permissions are granted
- **Routing Not Working**: Restart VPN connection after applying new rules
- **Performance Issues**: Reduce the number of applications in routing rules

### Solutions
- Clear app cache and restart the application
- Remove and re-add the VPN profile
- Check system firewall settings that might interfere with routing
- Ensure latest version of Hiddify-Next is installed

## Future Enhancements

1. Machine learning-based app categorization
2. Profile-based routing configurations 
3. Scheduled routing rules
4. Enhanced visual feedback for network traffic
5. Integration with firewall applications
## Overview

This document details the implementation of the split tunneling feature (also known as app routing or per-app proxy) in the Hiddify-Next application. This feature allows users to selectively route specific applications through the VPN while allowing others to connect directly to the internet.

## Architecture

### Cross-Platform Repository Pattern

The implementation follows a unified repository pattern that abstracts platform-specific functionality:

```
┌─────────────────────────────────────┐
│     UnifiedPerAppProxyRepository    │
├─────────────────────────────────────┤
│  • getAllInstalledApplications()    │
│  • getApplicationIcon()             │
│  • applyRoutingRules()              │
│  • isAppRoutedThroughVPN()          │
│  • resetRoutingRules()              │
└─────────────────────────────────────┘
                    │
        ┌───────────┼───────────┐
        ▼           ▼           ▼
┌─────────────┐ ┌─────────────┐ ┌─────────────┐
│ Android     │ │ Desktop     │ │ iOS         │
│ Repository  │ │ Repository  │ │ Repository  │
└─────────────┘ └─────────────┘ └─────────────┘
```

### Key Components

1. **Unified Repository Interface** - Abstract interface defining common functionality
2. **Platform-Specific Repositories** - Implementations tailored for each platform
3. **Routing Controller** - Manages actual routing configuration
4. **UI Components** - Visual feedback and configuration screens
5. **Performance Optimizer** - Caching and resource management

## Platform-Specific Implementations

### Android

Uses Android's VPNService with `VpnService.Builder` and the `addAllowedApplication()` and `addDisallowedApplication()` methods:

- **Include Mode**: Only specified apps route through VPN (`builder.addAllowedApplication()`)
- **Exclude Mode**: All apps except specified ones route through VPN (`builder.addDisallowedApplication()`)

### iOS

Implements using Network Extensions with packet tunnel providers:

- Uses `NETunnelProviderProtocol` with application bundle ID filtering
- Leverages `includedAppBoundIdentifiers` and `excludedAppBoundIdentifiers`
- Supports iOS 15+ for full functionality

### Windows

Utilizes Windows Filtering Platform (WFP) for application-specific traffic control:

- Integrates with WinTun driver for TUN interface
- Uses application path-based filtering
- Supports wildcard paths for application families

### macOS

Implements using Network Extension Framework:

- Uses `NEPacketTunnelProvider` with bundle identifier filtering
- Leverages system integration for privileged network operations
- Supports policy routing based on bundle identifiers

### Linux

Implements using iptables with owner matching:

- Uses `iptables` with `-m owner --uid-owner` for UID-based routing
- Leverages network namespaces for isolation
- Uses policy routing with custom routing tables

## Features Implemented

### 1. Enhanced UI for App Selection
- Intuitive interface for selecting applications to route through VPN
- Search and filter capabilities
- Category-based grouping (browsers, social media, etc.)
- System vs user application differentiation

### 2. Cross-Platform Compatibility
- Seamless functionality across Android, iOS, Windows, macOS, and Linux
- Consistent user experience with platform-appropriate UI patterns
- Unified API across all platforms

### 3. Performance Optimizations
- Smart caching of installed applications (5-minute TTL)
- Efficient application enumeration algorithms
- Debounced routing updates to prevent excessive system calls
- Resource monitoring to prevent system slowdown

### 4. Visual Feedback System
- Real-time status indicators for routing configuration
- Progress bars showing percentage of apps in each routing mode
- Clear visual distinction between include/exclude modes
- Status dashboard showing current routing state

### 5. Routing Controls
- Include Mode: Only specified applications route through VPN
- Exclude Mode: All applications except specified ones route through VPN
- Bulk operations for selecting multiple applications
- Ability to reset to default routing behavior

## API Interface

```dart
abstract interface class UnifiedPerAppProxyRepository {
  /// Get all installed applications/packages regardless of platform
  TaskEither<String, List<InstalledPackageInfo>> getAllInstalledApplications();

  /// Get application icon by package/app ID
  TaskEither<String, Uint8List> getApplicationIcon(String appId);

  /// Apply routing rules to the system
  TaskEither<String, Unit> applyRoutingRules(List<String> appIds, bool includeMode);

  /// Get the current routing status of an app
  TaskEither<String, bool> isAppRoutedThroughVPN(String appId);

  /// Reset all routing rules to default
  TaskEither<String, Unit> resetRoutingRules();
}
```

## Usage Examples

### Applying Routing Rules
```dart
final repo = ref.read(unifiedPerAppProxyRepositoryProvider);

// Route only Chrome and Firefox through VPN (Include mode)
await repo.applyRoutingRules(['com.android.chrome', 'org.mozilla.firefox'], true);

// Route all apps except Chrome and Firefox through VPN (Exclude mode)  
await repo.applyRoutingRules(['com.android.chrome', 'org.mozilla.firefox'], false);
```

### Getting Application List
```dart
final apps = await repo.getAllInstalledApplications().getOrElse(() => []);
for (final app in apps) {
  print('App: ${app.name}, Package: ${app.packageName}');
}
```

## Configuration

The split tunneling feature can be accessed through:
1. Settings > Network > Per-App Proxy
2. Direct access from the main app routing screen
3. Programmatically via the repository API

## Testing

The feature has been tested across:
- Android 7.0+ with various OEM customizations
- iOS 15.0+ with different device models
- Windows 10/11 with different network configurations
- macOS 12.0+ (Monterey) and newer
- Major Linux distributions (Ubuntu, Fedora, Arch, etc.)

## Known Limitations

1. **System Applications**: Some system applications cannot be routed differently on certain platforms due to security restrictions
2. **Game Launchers**: Game launchers and certain anti-cheat systems may conflict with routing rules
3. **Performance Impact**: Enabling split tunneling for many apps may cause slight performance overhead
4. **App Updates**: App updates may require reconfiguration of routing rules

## Troubleshooting

### Common Issues
- **No Applications Listed**: Ensure proper permissions are granted
- **Routing Not Working**: Restart VPN connection after applying new rules
- **Performance Issues**: Reduce the number of applications in routing rules

### Solutions
- Clear app cache and restart the application
- Remove and re-add the VPN profile
- Check system firewall settings that might interfere with routing
- Ensure latest version of Hiddify-Next is installed

## Future Enhancements

1. Machine learning-based app categorization
2. Profile-based routing configurations 
3. Scheduled routing rules
4. Enhanced visual feedback for network traffic
5. Integration with firewall applications
