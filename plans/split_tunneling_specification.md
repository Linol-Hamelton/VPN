# VPN Split Tunneling Configuration Interface Specification

## Overview
This document specifies the design and implementation requirements for the VPN routing configuration interface that allows users to select which applications will route through the VPN versus connecting directly. This split tunneling functionality should be intuitive and accessible for non-technical users, implemented in the settings section of the simplified UI, and compatible with all target platforms (Windows, Linux, macOS, Android, iOS).

## 1. Platform-Specific Split Tunneling Implementation Methods

### 1.1 Windows Implementation
- **TUN/TAP Interface**: Utilize TUN interface with application-specific routing capabilities
- **WinTun Driver**: Leverage Microsoft's lightweight TUN driver for efficient packet forwarding
- **Application Binding**: Use Windows Filtering Platform (WFP) for app-specific traffic control
- **Policy Enforcement**: Route traffic based on executable paths with wildcards support
- **Example Command**: `wireguard.exe /add route=0.0.0.0/0 table=off` for specific app routing

### 1.2 macOS Implementation
- **Network Extension Framework**: Utilize NEPacketTunnelProvider for VPN routing
- **App-Specific Rules**: Support routing based on bundle identifiers (com.application.id)
- **System Integration**: Leverage NetworkExtension framework for privileged network operations
- **Policy Configuration**: Use NEOnDemandRuleApplication for app-based triggers

### 1.3 Linux Implementation
- **IPTables Integration**: Use iptables with owner matching for UID-based routing
- **Network Namespaces**: Isolate application traffic through network namespaces
- **Policy Routing**: Utilize ip rule/route for custom routing tables per application
- **Sudo Privileges**: Require admin privileges for configuring routing rules

### 1.4 Android Implementation
- **VpnService API**: Leverage Android's VpnService with protect() method
- **Application Filtering**: Use package name filtering (com.application.id)
- **Network Security**: Implement with android.permission.INTERNET and BIND_VPN_SERVICE
- **Per-App VPN**: Support for per-application VPN using allowBypass()

### 1.5 iOS Implementation
- **Network Extensions**: Use NEVPNManager for VPN configuration
- **Packet Tunnel Provider**: Implement NETunnelProvider for custom routing
- **Bundle Identifier Filtering**: Route traffic based on application bundle IDs
- **App-to-App Communication**: Support for routing specific applications

## 2. Common API/Interface for Managing App Routing

### 2.1 Core Data Structures
```javascript
interface ApplicationInfo {
  id: string;          // Unique identifier (bundle ID on mobile, exe path on desktop)
  name: string;        // Display name
  icon?: string;       // Base64 encoded icon or path
  category?: string;   // Category for grouping (Browser, Media, Social, etc.)
  version?: string;    // Application version
  lastUsed?: Date;     // Last launch timestamp
}

interface RoutingRule {
  appId: string;       // Application identifier
  mode: 'include' | 'exclude';  // Include in VPN or exclude from VPN
  createdAt: Date;
  updatedAt?: Date;
}
```

### 2.2 API Endpoints
```javascript
interface AppRoutingAPI {
  // Get list of installed applications
  getInstalledApplications(): Promise<ApplicationInfo[]>;
  
  // Get current routing configuration
  getRoutingRules(): Promise<RoutingRule[]>;
  
  // Set routing rules for applications
  setRoutingRules(rules: RoutingRule[]): Promise<void>;
  
  // Add a single routing rule
  addRoutingRule(rule: RoutingRule): Promise<void>;
  
  // Remove a routing rule
  removeRoutingRule(appId: string): Promise<void>;
  
  // Get current routing status for an app
  getAppRoutingStatus(appId: string): Promise<'vpn' | 'direct'>;
  
  // Get apps currently using VPN
  getVPNRoutedApps(): Promise<ApplicationInfo[]>;
  
  // Get apps bypassing VPN
  getDirectRoutedApps(): Promise<ApplicationInfo[]>;
  
  // Refresh application list
  refreshApplications(): Promise<ApplicationInfo[]>;
  
  // Set default routing behavior
  setDefaultRoute(defaultMode: 'vpn' | 'direct'): Promise<void>;
  
  // Get default routing behavior
  getDefaultRoute(): Promise<'vpn' | 'direct'>;
}
```

### 2.3 Platform Abstraction Layer
The API implements a platform abstraction layer that translates common operations to platform-specific implementations. Each platform implementation handles the low-level system operations while presenting a unified interface to the UI layer.

## 3. UI/UX Design for App Selection and Toggle Functionality

### 3.1 Desktop Implementation
```
┌─────────────────────────────────────────────────────────────┐
│ Settings > App Routing                    [Min] [_] [×]     │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│                    APP ROUTING                              │
│                                                             │
│  [●] Include Mode Only    [○] Exclude Mode (Recommended)    ││
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

### 3.2 Mobile Implementation
```
┌─────────────────────────────────────────┐
│              App Routing                │
├─────────────────────────────────────────┤
│                                         │
│ [●] Include Mode    [○] Exclude Mode    │
│                                         │
│ Selected Apps (2):                      │
│ [✓] Chrome     [Trash Icon]            │
│ [✓] Spotify    [Trash Icon]            │
│                                         │
│ Available Apps:                         │
│ [ ] Facebook                            │
│ [ ] Instagram                           │
│ [ ] WhatsApp                            │
│ [ ] Gmail                               │
│ [ ] YouTube                             │
│                                         │
│ [Search Icon] [+] Select More Apps      │
│                                         │
│           [Save] [Cancel]               │
└─────────────────────────────────────────┘
```

### 3.3 Visual Design Elements

#### 3.3.1 Toggle Switches
- Custom styled toggle switches with platform-appropriate appearance
- Clear visual distinction between enabled/disabled states
- Smooth animations for state transitions
- Consistent sizing across platforms (minimum 44x44px touch target)

#### 3.3.2 App Cards/List Items
- Application icon displayed left (48x48px on desktop, 32x32px on mobile)
- Application name with secondary details (category/version) below
- Status indicator showing current routing state
- Grouping by category when relevant

#### 3.3.3 Search and Filter Controls
- Prominent search field with magnifying glass icon
- Category filters (Browsers, Social, Media, Productivity)
- Recently used apps section
- Favorites/quick access section

### 3.4 Interaction Patterns

#### 3.4.1 Bulk Operations
- Select multiple apps using checkboxes
- Batch apply routing rules
- Select all/deselect all functionality
- Invert selection option

#### 3.4.2 Individual Operations
- Single tap to toggle routing status
- Long press for additional options (remove, details, etc.)
- Drag and drop for reordering prioritized apps

## 4. Technical Specification for Cross-Platform Implementation

### 4.1 Architecture Pattern
```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   UI Layer      │◄──►│ Platform Bridge  │◄──►│ Native Modules  │
│ (React/Flutter) │    │ (Common API)     │    │ (Platform Impl) │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

### 4.2 Platform Bridge Specification
The platform bridge translates common API calls to platform-specific implementations:

#### 4.2.1 Application Discovery
- **Windows**: Enumerate programs in Program Files, AppData, and registry entries
- **macOS**: Query Launch Services database and /Applications directory
- **Linux**: Parse desktop entries in /usr/share/applications/ and ~/.local/share/applications/
- **Android**: Query PackageManager for installed applications
- **iOS**: Query system for applications with associated protocols

#### 4.2.2 Routing Configuration Storage
- Store routing rules in encrypted local storage
- Use platform-specific secure storage (Keychain on macOS/iOS, Credential Manager on Windows, Keystore on Android)
- Backup configuration to cloud if user opts in
- Export/import functionality for backup purposes

#### 4.2.3 Real-Time Status Updates
- Monitor network interfaces for traffic routing changes
- Update UI with current routing status (VPN vs direct)
- Display active/inactive states for each application
- Log routing events for troubleshooting

### 4.3 Implementation Requirements
- **Performance**: Application enumeration should complete within 3 seconds
- **Memory**: Cache application list to reduce repeated system calls
- **Privacy**: Do not transmit application lists to external services
- **Security**: Encrypt routing configuration data on disk
- **Compatibility**: Support older versions of each operating system

## 5. Performance Considerations for App Detection and Routing

### 5.1 Application Discovery Performance
- **Caching Strategy**: Cache application lists with 5-minute TTL
- **Background Discovery**: Perform app discovery during idle periods
- **Incremental Updates**: Detect newly installed/uninstalled apps without full enumeration
- **Resource Limits**: Limit discovery threads to prevent system slowdown

### 5.2 Routing Rule Application
- **Efficiency**: Apply routing rules in batch to minimize system calls
- **Optimization**: Maintain routing rule index for fast lookups
- **Cleanup**: Remove dangling rules for uninstalled applications
- **Validation**: Verify routing rules before applying to prevent conflicts

### 5.3 Memory and CPU Optimization
- **Lazy Loading**: Load application data only when viewed
- **Pagination**: Display applications in paginated lists (50 items/page)
- **Debouncing**: Debounce search input to prevent excessive filtering
- **Threading**: Perform heavy operations on background threads

### 5.4 Resource Monitoring
- Monitor system resources during routing operations
- Temporarily pause operations if system load is too high
- Provide feedback for long-running operations
- Optimize routing rules to minimize processing overhead

## 6. Visual Feedback System for Current App Routing Status

### 6.1 Status Indicator Types
- **VPN Active**: Green dot with VPN icon overlay
- **Direct Connection**: Blue dot with globe icon overlay
- **Mixed Routing**: Yellow split circle (half green, half blue)
- **Inactive**: Gray dot with line-through icon

### 6.2 Real-Time Status Updates
- Update status indicators every 2 seconds when VPN is active
- Show last known status when VPN is inactive
- Highlight recently changed routing status briefly (3 second pulse)
- Display tooltip with detailed routing status on hover/tap

### 6.3 Dashboard View
```
┌─────────────────────────────────────────────────────────────┐
│                CURRENT ROUTING STATUS                       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  VPN Connected: ✓ (US Server, 24ms ping)                  ││
│                                                             │
│  Apps via VPN (3):                                          ││
│  [VPN] Chrome      [VPN] Firefox    [VPN] Spotify         ││
│                                                             │
│  Apps Direct (5):                                           ││
│  [DIR] Outlook     [DIR] Skype      [DIR] Calculator      ││
│  [DIR] Photos      [DIR] Mail                              ││
│                                                             │
│  [View Details] [Configure Routing] [Switch Mode]          ││
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 6.4 Notification System
- Alert users when applications switch routing modes unexpectedly
- Notify about performance impact of routing configuration
- Provide warnings when many apps are routed through VPN
- Show quick access to routing settings from notifications

## 7. Automatic vs Manual App Configuration Options

### 7.1 Automatic Detection and Configuration
- **Smart Defaults**: Pre-configure common applications based on category
- **Usage Tracking**: Learn from user behavior to suggest routing rules
- **Category-Based**: Group applications by function (browsers, banking, media)
- **Intelligent Suggestions**: Recommend routing based on privacy/security needs

### 7.2 Manual Configuration Options
- **Individual Selection**: Allow users to select each application individually
- **Bulk Operations**: Select multiple applications at once
- **Import/Export**: Share routing configurations between devices
- **Presets**: Save and restore routing configuration presets

### 7.3 Hybrid Approach
- **Recommended Settings**: Present smart defaults with option to customize
- **Learning Algorithm**: Adapt recommendations based on user choices
- **Quick Actions**: One-click to route all apps in a category
- **Override Protection**: Allow temporary overrides of automatic settings

### 7.4 Configuration Profiles
- **Work Profile**: Route work-related apps through VPN
- **Privacy Profile**: Route browsers and messaging apps through VPN
- **Performance Profile**: Route only essential apps through VPN
- **Custom Profile**: User-defined routing configuration

## 8. Platform-Specific Implementation Guides

### 8.1 Windows Implementation Guide

#### 8.1.1 Prerequisites
- Windows 10 version 1809 or later (for WFP support)
- Administrative privileges for network configuration
- .NET Framework 4.8 or .NET Core 3.1+

#### 8.1.2 Technical Implementation
- Use Windows Filtering Platform (WFP) for application-specific routing
- Implement using Microsoft's Windows SDK
- Require administrator privileges for TUN interface creation
- Handle UAC prompts gracefully

#### 8.1.3 Application Discovery
```cpp
// Example for enumerating applications
#include <shlobj.h>
#include <appmgmt.h>

// Use SHChangeNotify to monitor application changes
// Query registry for installed programs
// Use Package Manager API for UWP apps
```

#### 8.1.4 Routing Configuration
- Modify WireGuard configuration dynamically
- Use WinDivert for packet interception if needed
- Handle firewall rule creation/deletion
- Implement proper cleanup on service stop

### 8.2 macOS Implementation Guide

#### 8.2.1 Prerequisites
- macOS 10.15 (Catalina) or later
- Network Extension entitlements
- Administrator privileges for network configuration

#### 8.2.2 Technical Implementation
```swift
// Example Swift code structure
import NetworkExtension
import Network

class AppRoutingManager: NSObject {
    private var tunnelManager: NETunnelProviderManager?
    
    func configureAppRouting(for bundleIDs: [String]) -> Bool {
        // Configure per-app VPN routing
        return true
    }
    
    func updateRoutingRules(_ rules: [RoutingRule]) {
        // Update routing configuration
    }
}
```

#### 8.2.3 Application Discovery
- Use Launch Services to enumerate installed applications
- Monitor ~/Applications and /Applications directories
- Track Bundle IDs for proper identification
- Handle sandboxed applications correctly

### 8.3 Linux Implementation Guide

#### 8.3.1 Prerequisites
- Kernel 3.17+ for TUN/TAP interfaces
- iptables with owner matching support
- Administrative privileges (sudo)

#### 8.3.2 Technical Implementation
```bash
# Example routing configuration
# Create routing table for specific user
ip route add default dev tun0 table $TABLE_ID
ip rule add fwmark $MARK lookup $TABLE_ID

# Use owner matching in iptables
iptables -t mangle -A OUTPUT -m owner --uid-owner $UID -j MARK --set-mark $MARK
```

#### 8.3.3 Application Discovery
- Parse .desktop files in standard locations
- Use systemd to discover user services
- Monitor /usr/bin and /usr/local/bin
- Handle Flatpak and Snap packages separately

### 8.4 Android Implementation Guide

#### 8.4.1 Prerequisites
- Android API Level 21+ (Lollipop)
- VPN permissions granted by user
- Proper network security configuration

#### 8.4.2 Technical Implementation
```kotlin
// Example Kotlin code
class SplitTunnelVpnService : VpnService() {
    override fun onCreate() {
        super.onCreate()
        // Initialize routing manager
    }
    
    private fun buildVpnInterface(): Builder {
        val builder = Builder()
        
        // Add allowed applications
        for (packageName in allowedPackages) {
            try {
                builder.addAllowedApplication(packageName)
            } catch (e: PackageManager.NameNotFoundException) {
                // Handle missing packages
            }
        }
        
        // Add disallowed applications (if in include mode)
        for (packageName in disallowedPackages) {
            try {
                builder.addDisallowedApplication(packageName)
            } catch (e: PackageManager.NameNotFoundException) {
                // Handle missing packages
            }
        }
        
        return builder
    }
}
```

#### 8.4.3 Application Discovery
- Query PackageManager for installed packages
- Filter system vs user applications
- Handle application updates and removals
- Respect application opt-out policies

### 8.5 iOS Implementation Guide

#### 8.5.1 Prerequisites
- iOS 9.0+ for Network Extensions
- App Transport Security configuration
- Required entitlements for VPN extensions

#### 8.5.2 Technical Implementation
```swift
import NetworkExtension

class PacketTunnelProvider: NEPacketTunnelProvider {
    
    override func startTunnel(options: [String : NSObject]?, 
                            completionHandler: @escaping (Error?) -> Void) {
        // Configure routing based on stored rules
        setupAppSpecificRouting()
        completionHandler(nil)
    }
    
    private func setupAppSpecificRouting() {
        guard let routingRules = loadRoutingRules() else { return }
        
        // Configure routes based on bundle IDs
        for rule in routingRules {
            configureRoute(for: rule.appId, mode: rule.mode)
        }
    }
}
```

#### 8.5.3 Application Discovery
- Query for applications that have associated URL schemes
- Use LSApplicationQueriesSchemes in Info.plist
- Handle app updates that may change bundle IDs
- Respect app privacy settings

## Conclusion
This comprehensive specification provides the foundation for implementing a cross-platform VPN split tunneling interface that meets all specified requirements. The design emphasizes user-friendliness for non-technical users while providing the sophisticated functionality needed for effective VPN management.

The solution balances performance considerations with usability, ensuring that the application can efficiently manage routing rules without impacting system resources. The platform-specific implementations account for differences in how each operating system handles network routing while maintaining a consistent user experience.

## Overview
This document specifies the design and implementation requirements for the VPN routing configuration interface that allows users to select which applications will route through the VPN versus connecting directly. This split tunneling functionality should be intuitive and accessible for non-technical users, implemented in the settings section of the simplified UI, and compatible with all target platforms (Windows, Linux, macOS, Android, iOS).

## 1. Platform-Specific Split Tunneling Implementation Methods

### 1.1 Windows Implementation
- **TUN/TAP Interface**: Utilize TUN interface with application-specific routing capabilities
- **WinTun Driver**: Leverage Microsoft's lightweight TUN driver for efficient packet forwarding
- **Application Binding**: Use Windows Filtering Platform (WFP) for app-specific traffic control
- **Policy Enforcement**: Route traffic based on executable paths with wildcards support
- **Example Command**: `wireguard.exe /add route=0.0.0.0/0 table=off` for specific app routing

### 1.2 macOS Implementation
- **Network Extension Framework**: Utilize NEPacketTunnelProvider for VPN routing
- **App-Specific Rules**: Support routing based on bundle identifiers (com.application.id)
- **System Integration**: Leverage NetworkExtension framework for privileged network operations
- **Policy Configuration**: Use NEOnDemandRuleApplication for app-based triggers

### 1.3 Linux Implementation
- **IPTables Integration**: Use iptables with owner matching for UID-based routing
- **Network Namespaces**: Isolate application traffic through network namespaces
- **Policy Routing**: Utilize ip rule/route for custom routing tables per application
- **Sudo Privileges**: Require admin privileges for configuring routing rules

### 1.4 Android Implementation
- **VpnService API**: Leverage Android's VpnService with protect() method
- **Application Filtering**: Use package name filtering (com.application.id)
- **Network Security**: Implement with android.permission.INTERNET and BIND_VPN_SERVICE
- **Per-App VPN**: Support for per-application VPN using allowBypass()

### 1.5 iOS Implementation
- **Network Extensions**: Use NEVPNManager for VPN configuration
- **Packet Tunnel Provider**: Implement NETunnelProvider for custom routing
- **Bundle Identifier Filtering**: Route traffic based on application bundle IDs
- **App-to-App Communication**: Support for routing specific applications

## 2. Common API/Interface for Managing App Routing

### 2.1 Core Data Structures
```javascript
interface ApplicationInfo {
  id: string;          // Unique identifier (bundle ID on mobile, exe path on desktop)
  name: string;        // Display name
  icon?: string;       // Base64 encoded icon or path
  category?: string;   // Category for grouping (Browser, Media, Social, etc.)
  version?: string;    // Application version
  lastUsed?: Date;     // Last launch timestamp
}

interface RoutingRule {
  appId: string;       // Application identifier
  mode: 'include' | 'exclude';  // Include in VPN or exclude from VPN
  createdAt: Date;
  updatedAt?: Date;
}
```

### 2.2 API Endpoints
```javascript
interface AppRoutingAPI {
  // Get list of installed applications
  getInstalledApplications(): Promise<ApplicationInfo[]>;
  
  // Get current routing configuration
  getRoutingRules(): Promise<RoutingRule[]>;
  
  // Set routing rules for applications
  setRoutingRules(rules: RoutingRule[]): Promise<void>;
  
  // Add a single routing rule
  addRoutingRule(rule: RoutingRule): Promise<void>;
  
  // Remove a routing rule
  removeRoutingRule(appId: string): Promise<void>;
  
  // Get current routing status for an app
  getAppRoutingStatus(appId: string): Promise<'vpn' | 'direct'>;
  
  // Get apps currently using VPN
  getVPNRoutedApps(): Promise<ApplicationInfo[]>;
  
  // Get apps bypassing VPN
  getDirectRoutedApps(): Promise<ApplicationInfo[]>;
  
  // Refresh application list
  refreshApplications(): Promise<ApplicationInfo[]>;
  
  // Set default routing behavior
  setDefaultRoute(defaultMode: 'vpn' | 'direct'): Promise<void>;
  
  // Get default routing behavior
  getDefaultRoute(): Promise<'vpn' | 'direct'>;
}
```

### 2.3 Platform Abstraction Layer
The API implements a platform abstraction layer that translates common operations to platform-specific implementations. Each platform implementation handles the low-level system operations while presenting a unified interface to the UI layer.

## 3. UI/UX Design for App Selection and Toggle Functionality

### 3.1 Desktop Implementation
```
┌─────────────────────────────────────────────────────────────┐
│ Settings > App Routing                    [Min] [_] [×]     │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│                    APP ROUTING                              │
│                                                             │
│  [●] Include Mode Only    [○] Exclude Mode (Recommended)    ││
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

### 3.2 Mobile Implementation
```
┌─────────────────────────────────────────┐
│              App Routing                │
├─────────────────────────────────────────┤
│                                         │
│ [●] Include Mode    [○] Exclude Mode    │
│                                         │
│ Selected Apps (2):                      │
│ [✓] Chrome     [Trash Icon]            │
│ [✓] Spotify    [Trash Icon]            │
│                                         │
│ Available Apps:                         │
│ [ ] Facebook                            │
│ [ ] Instagram                           │
│ [ ] WhatsApp                            │
│ [ ] Gmail                               │
│ [ ] YouTube                             │
│                                         │
│ [Search Icon] [+] Select More Apps      │
│                                         │
│           [Save] [Cancel]               │
└─────────────────────────────────────────┘
```

### 3.3 Visual Design Elements

#### 3.3.1 Toggle Switches
- Custom styled toggle switches with platform-appropriate appearance
- Clear visual distinction between enabled/disabled states
- Smooth animations for state transitions
- Consistent sizing across platforms (minimum 44x44px touch target)

#### 3.3.2 App Cards/List Items
- Application icon displayed left (48x48px on desktop, 32x32px on mobile)
- Application name with secondary details (category/version) below
- Status indicator showing current routing state
- Grouping by category when relevant

#### 3.3.3 Search and Filter Controls
- Prominent search field with magnifying glass icon
- Category filters (Browsers, Social, Media, Productivity)
- Recently used apps section
- Favorites/quick access section

### 3.4 Interaction Patterns

#### 3.4.1 Bulk Operations
- Select multiple apps using checkboxes
- Batch apply routing rules
- Select all/deselect all functionality
- Invert selection option

#### 3.4.2 Individual Operations
- Single tap to toggle routing status
- Long press for additional options (remove, details, etc.)
- Drag and drop for reordering prioritized apps

## 4. Technical Specification for Cross-Platform Implementation

### 4.1 Architecture Pattern
```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   UI Layer      │◄──►│ Platform Bridge  │◄──►│ Native Modules  │
│ (React/Flutter) │    │ (Common API)     │    │ (Platform Impl) │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

### 4.2 Platform Bridge Specification
The platform bridge translates common API calls to platform-specific implementations:

#### 4.2.1 Application Discovery
- **Windows**: Enumerate programs in Program Files, AppData, and registry entries
- **macOS**: Query Launch Services database and /Applications directory
- **Linux**: Parse desktop entries in /usr/share/applications/ and ~/.local/share/applications/
- **Android**: Query PackageManager for installed applications
- **iOS**: Query system for applications with associated protocols

#### 4.2.2 Routing Configuration Storage
- Store routing rules in encrypted local storage
- Use platform-specific secure storage (Keychain on macOS/iOS, Credential Manager on Windows, Keystore on Android)
- Backup configuration to cloud if user opts in
- Export/import functionality for backup purposes

#### 4.2.3 Real-Time Status Updates
- Monitor network interfaces for traffic routing changes
- Update UI with current routing status (VPN vs direct)
- Display active/inactive states for each application
- Log routing events for troubleshooting

### 4.3 Implementation Requirements
- **Performance**: Application enumeration should complete within 3 seconds
- **Memory**: Cache application list to reduce repeated system calls
- **Privacy**: Do not transmit application lists to external services
- **Security**: Encrypt routing configuration data on disk
- **Compatibility**: Support older versions of each operating system

## 5. Performance Considerations for App Detection and Routing

### 5.1 Application Discovery Performance
- **Caching Strategy**: Cache application lists with 5-minute TTL
- **Background Discovery**: Perform app discovery during idle periods
- **Incremental Updates**: Detect newly installed/uninstalled apps without full enumeration
- **Resource Limits**: Limit discovery threads to prevent system slowdown

### 5.2 Routing Rule Application
- **Efficiency**: Apply routing rules in batch to minimize system calls
- **Optimization**: Maintain routing rule index for fast lookups
- **Cleanup**: Remove dangling rules for uninstalled applications
- **Validation**: Verify routing rules before applying to prevent conflicts

### 5.3 Memory and CPU Optimization
- **Lazy Loading**: Load application data only when viewed
- **Pagination**: Display applications in paginated lists (50 items/page)
- **Debouncing**: Debounce search input to prevent excessive filtering
- **Threading**: Perform heavy operations on background threads

### 5.4 Resource Monitoring
- Monitor system resources during routing operations
- Temporarily pause operations if system load is too high
- Provide feedback for long-running operations
- Optimize routing rules to minimize processing overhead

## 6. Visual Feedback System for Current App Routing Status

### 6.1 Status Indicator Types
- **VPN Active**: Green dot with VPN icon overlay
- **Direct Connection**: Blue dot with globe icon overlay
- **Mixed Routing**: Yellow split circle (half green, half blue)
- **Inactive**: Gray dot with line-through icon

### 6.2 Real-Time Status Updates
- Update status indicators every 2 seconds when VPN is active
- Show last known status when VPN is inactive
- Highlight recently changed routing status briefly (3 second pulse)
- Display tooltip with detailed routing status on hover/tap

### 6.3 Dashboard View
```
┌─────────────────────────────────────────────────────────────┐
│                CURRENT ROUTING STATUS                       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  VPN Connected: ✓ (US Server, 24ms ping)                  ││
│                                                             │
│  Apps via VPN (3):                                          ││
│  [VPN] Chrome      [VPN] Firefox    [VPN] Spotify         ││
│                                                             │
│  Apps Direct (5):                                           ││
│  [DIR] Outlook     [DIR] Skype      [DIR] Calculator      ││
│  [DIR] Photos      [DIR] Mail                              ││
│                                                             │
│  [View Details] [Configure Routing] [Switch Mode]          ││
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 6.4 Notification System
- Alert users when applications switch routing modes unexpectedly
- Notify about performance impact of routing configuration
- Provide warnings when many apps are routed through VPN
- Show quick access to routing settings from notifications

## 7. Automatic vs Manual App Configuration Options

### 7.1 Automatic Detection and Configuration
- **Smart Defaults**: Pre-configure common applications based on category
- **Usage Tracking**: Learn from user behavior to suggest routing rules
- **Category-Based**: Group applications by function (browsers, banking, media)
- **Intelligent Suggestions**: Recommend routing based on privacy/security needs

### 7.2 Manual Configuration Options
- **Individual Selection**: Allow users to select each application individually
- **Bulk Operations**: Select multiple applications at once
- **Import/Export**: Share routing configurations between devices
- **Presets**: Save and restore routing configuration presets

### 7.3 Hybrid Approach
- **Recommended Settings**: Present smart defaults with option to customize
- **Learning Algorithm**: Adapt recommendations based on user choices
- **Quick Actions**: One-click to route all apps in a category
- **Override Protection**: Allow temporary overrides of automatic settings

### 7.4 Configuration Profiles
- **Work Profile**: Route work-related apps through VPN
- **Privacy Profile**: Route browsers and messaging apps through VPN
- **Performance Profile**: Route only essential apps through VPN
- **Custom Profile**: User-defined routing configuration

## 8. Platform-Specific Implementation Guides

### 8.1 Windows Implementation Guide

#### 8.1.1 Prerequisites
- Windows 10 version 1809 or later (for WFP support)
- Administrative privileges for network configuration
- .NET Framework 4.8 or .NET Core 3.1+

#### 8.1.2 Technical Implementation
- Use Windows Filtering Platform (WFP) for application-specific routing
- Implement using Microsoft's Windows SDK
- Require administrator privileges for TUN interface creation
- Handle UAC prompts gracefully

#### 8.1.3 Application Discovery
```cpp
// Example for enumerating applications
#include <shlobj.h>
#include <appmgmt.h>

// Use SHChangeNotify to monitor application changes
// Query registry for installed programs
// Use Package Manager API for UWP apps
```

#### 8.1.4 Routing Configuration
- Modify WireGuard configuration dynamically
- Use WinDivert for packet interception if needed
- Handle firewall rule creation/deletion
- Implement proper cleanup on service stop

### 8.2 macOS Implementation Guide

#### 8.2.1 Prerequisites
- macOS 10.15 (Catalina) or later
- Network Extension entitlements
- Administrator privileges for network configuration

#### 8.2.2 Technical Implementation
```swift
// Example Swift code structure
import NetworkExtension
import Network

class AppRoutingManager: NSObject {
    private var tunnelManager: NETunnelProviderManager?
    
    func configureAppRouting(for bundleIDs: [String]) -> Bool {
        // Configure per-app VPN routing
        return true
    }
    
    func updateRoutingRules(_ rules: [RoutingRule]) {
        // Update routing configuration
    }
}
```

#### 8.2.3 Application Discovery
- Use Launch Services to enumerate installed applications
- Monitor ~/Applications and /Applications directories
- Track Bundle IDs for proper identification
- Handle sandboxed applications correctly

### 8.3 Linux Implementation Guide

#### 8.3.1 Prerequisites
- Kernel 3.17+ for TUN/TAP interfaces
- iptables with owner matching support
- Administrative privileges (sudo)

#### 8.3.2 Technical Implementation
```bash
# Example routing configuration
# Create routing table for specific user
ip route add default dev tun0 table $TABLE_ID
ip rule add fwmark $MARK lookup $TABLE_ID

# Use owner matching in iptables
iptables -t mangle -A OUTPUT -m owner --uid-owner $UID -j MARK --set-mark $MARK
```

#### 8.3.3 Application Discovery
- Parse .desktop files in standard locations
- Use systemd to discover user services
- Monitor /usr/bin and /usr/local/bin
- Handle Flatpak and Snap packages separately

### 8.4 Android Implementation Guide

#### 8.4.1 Prerequisites
- Android API Level 21+ (Lollipop)
- VPN permissions granted by user
- Proper network security configuration

#### 8.4.2 Technical Implementation
```kotlin
// Example Kotlin code
class SplitTunnelVpnService : VpnService() {
    override fun onCreate() {
        super.onCreate()
        // Initialize routing manager
    }
    
    private fun buildVpnInterface(): Builder {
        val builder = Builder()
        
        // Add allowed applications
        for (packageName in allowedPackages) {
            try {
                builder.addAllowedApplication(packageName)
            } catch (e: PackageManager.NameNotFoundException) {
                // Handle missing packages
            }
        }
        
        // Add disallowed applications (if in include mode)
        for (packageName in disallowedPackages) {
            try {
                builder.addDisallowedApplication(packageName)
            } catch (e: PackageManager.NameNotFoundException) {
                // Handle missing packages
            }
        }
        
        return builder
    }
}
```

#### 8.4.3 Application Discovery
- Query PackageManager for installed packages
- Filter system vs user applications
- Handle application updates and removals
- Respect application opt-out policies

### 8.5 iOS Implementation Guide

#### 8.5.1 Prerequisites
- iOS 9.0+ for Network Extensions
- App Transport Security configuration
- Required entitlements for VPN extensions

#### 8.5.2 Technical Implementation
```swift
import NetworkExtension

class PacketTunnelProvider: NEPacketTunnelProvider {
    
    override func startTunnel(options: [String : NSObject]?, 
                            completionHandler: @escaping (Error?) -> Void) {
        // Configure routing based on stored rules
        setupAppSpecificRouting()
        completionHandler(nil)
    }
    
    private func setupAppSpecificRouting() {
        guard let routingRules = loadRoutingRules() else { return }
        
        // Configure routes based on bundle IDs
        for rule in routingRules {
            configureRoute(for: rule.appId, mode: rule.mode)
        }
    }
}
```

#### 8.5.3 Application Discovery
- Query for applications that have associated URL schemes
- Use LSApplicationQueriesSchemes in Info.plist
- Handle app updates that may change bundle IDs
- Respect app privacy settings

## Conclusion
This comprehensive specification provides the foundation for implementing a cross-platform VPN split tunneling interface that meets all specified requirements. The design emphasizes user-friendliness for non-technical users while providing the sophisticated functionality needed for effective VPN management.

The solution balances performance considerations with usability, ensuring that the application can efficiently manage routing rules without impacting system resources. The platform-specific implementations account for differences in how each operating system handles network routing while maintaining a consistent user experience.
## Overview
This document specifies the design and implementation requirements for the VPN routing configuration interface that allows users to select which applications will route through the VPN versus connecting directly. This split tunneling functionality should be intuitive and accessible for non-technical users, implemented in the settings section of the simplified UI, and compatible with all target platforms (Windows, Linux, macOS, Android, iOS).

## 1. Platform-Specific Split Tunneling Implementation Methods

### 1.1 Windows Implementation
- **TUN/TAP Interface**: Utilize TUN interface with application-specific routing capabilities
- **WinTun Driver**: Leverage Microsoft's lightweight TUN driver for efficient packet forwarding
- **Application Binding**: Use Windows Filtering Platform (WFP) for app-specific traffic control
- **Policy Enforcement**: Route traffic based on executable paths with wildcards support
- **Example Command**: `wireguard.exe /add route=0.0.0.0/0 table=off` for specific app routing

### 1.2 macOS Implementation
- **Network Extension Framework**: Utilize NEPacketTunnelProvider for VPN routing
- **App-Specific Rules**: Support routing based on bundle identifiers (com.application.id)
- **System Integration**: Leverage NetworkExtension framework for privileged network operations
- **Policy Configuration**: Use NEOnDemandRuleApplication for app-based triggers

### 1.3 Linux Implementation
- **IPTables Integration**: Use iptables with owner matching for UID-based routing
- **Network Namespaces**: Isolate application traffic through network namespaces
- **Policy Routing**: Utilize ip rule/route for custom routing tables per application
- **Sudo Privileges**: Require admin privileges for configuring routing rules

### 1.4 Android Implementation
- **VpnService API**: Leverage Android's VpnService with protect() method
- **Application Filtering**: Use package name filtering (com.application.id)
- **Network Security**: Implement with android.permission.INTERNET and BIND_VPN_SERVICE
- **Per-App VPN**: Support for per-application VPN using allowBypass()

### 1.5 iOS Implementation
- **Network Extensions**: Use NEVPNManager for VPN configuration
- **Packet Tunnel Provider**: Implement NETunnelProvider for custom routing
- **Bundle Identifier Filtering**: Route traffic based on application bundle IDs
- **App-to-App Communication**: Support for routing specific applications

## 2. Common API/Interface for Managing App Routing

### 2.1 Core Data Structures
```javascript
interface ApplicationInfo {
  id: string;          // Unique identifier (bundle ID on mobile, exe path on desktop)
  name: string;        // Display name
  icon?: string;       // Base64 encoded icon or path
  category?: string;   // Category for grouping (Browser, Media, Social, etc.)
  version?: string;    // Application version
  lastUsed?: Date;     // Last launch timestamp
}

interface RoutingRule {
  appId: string;       // Application identifier
  mode: 'include' | 'exclude';  // Include in VPN or exclude from VPN
  createdAt: Date;
  updatedAt?: Date;
}
```

### 2.2 API Endpoints
```javascript
interface AppRoutingAPI {
  // Get list of installed applications
  getInstalledApplications(): Promise<ApplicationInfo[]>;
  
  // Get current routing configuration
  getRoutingRules(): Promise<RoutingRule[]>;
  
  // Set routing rules for applications
  setRoutingRules(rules: RoutingRule[]): Promise<void>;
  
  // Add a single routing rule
  addRoutingRule(rule: RoutingRule): Promise<void>;
  
  // Remove a routing rule
  removeRoutingRule(appId: string): Promise<void>;
  
  // Get current routing status for an app
  getAppRoutingStatus(appId: string): Promise<'vpn' | 'direct'>;
  
  // Get apps currently using VPN
  getVPNRoutedApps(): Promise<ApplicationInfo[]>;
  
  // Get apps bypassing VPN
  getDirectRoutedApps(): Promise<ApplicationInfo[]>;
  
  // Refresh application list
  refreshApplications(): Promise<ApplicationInfo[]>;
  
  // Set default routing behavior
  setDefaultRoute(defaultMode: 'vpn' | 'direct'): Promise<void>;
  
  // Get default routing behavior
  getDefaultRoute(): Promise<'vpn' | 'direct'>;
}
```

### 2.3 Platform Abstraction Layer
The API implements a platform abstraction layer that translates common operations to platform-specific implementations. Each platform implementation handles the low-level system operations while presenting a unified interface to the UI layer.

## 3. UI/UX Design for App Selection and Toggle Functionality

### 3.1 Desktop Implementation
```
┌─────────────────────────────────────────────────────────────┐
│ Settings > App Routing                    [Min] [_] [×]     │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│                    APP ROUTING                              │
│                                                             │
│  [●] Include Mode Only    [○] Exclude Mode (Recommended)    ││
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

### 3.2 Mobile Implementation
```
┌─────────────────────────────────────────┐
│              App Routing                │
├─────────────────────────────────────────┤
│                                         │
│ [●] Include Mode    [○] Exclude Mode    │
│                                         │
│ Selected Apps (2):                      │
│ [✓] Chrome     [Trash Icon]            │
│ [✓] Spotify    [Trash Icon]            │
│                                         │
│ Available Apps:                         │
│ [ ] Facebook                            │
│ [ ] Instagram                           │
│ [ ] WhatsApp                            │
│ [ ] Gmail                               │
│ [ ] YouTube                             │
│                                         │
│ [Search Icon] [+] Select More Apps      │
│                                         │
│           [Save] [Cancel]               │
└─────────────────────────────────────────┘
```

### 3.3 Visual Design Elements

#### 3.3.1 Toggle Switches
- Custom styled toggle switches with platform-appropriate appearance
- Clear visual distinction between enabled/disabled states
- Smooth animations for state transitions
- Consistent sizing across platforms (minimum 44x44px touch target)

#### 3.3.2 App Cards/List Items
- Application icon displayed left (48x48px on desktop, 32x32px on mobile)
- Application name with secondary details (category/version) below
- Status indicator showing current routing state
- Grouping by category when relevant

#### 3.3.3 Search and Filter Controls
- Prominent search field with magnifying glass icon
- Category filters (Browsers, Social, Media, Productivity)
- Recently used apps section
- Favorites/quick access section

### 3.4 Interaction Patterns

#### 3.4.1 Bulk Operations
- Select multiple apps using checkboxes
- Batch apply routing rules
- Select all/deselect all functionality
- Invert selection option

#### 3.4.2 Individual Operations
- Single tap to toggle routing status
- Long press for additional options (remove, details, etc.)
- Drag and drop for reordering prioritized apps

## 4. Technical Specification for Cross-Platform Implementation

### 4.1 Architecture Pattern
```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   UI Layer      │◄──►│ Platform Bridge  │◄──►│ Native Modules  │
│ (React/Flutter) │    │ (Common API)     │    │ (Platform Impl) │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

### 4.2 Platform Bridge Specification
The platform bridge translates common API calls to platform-specific implementations:

#### 4.2.1 Application Discovery
- **Windows**: Enumerate programs in Program Files, AppData, and registry entries
- **macOS**: Query Launch Services database and /Applications directory
- **Linux**: Parse desktop entries in /usr/share/applications/ and ~/.local/share/applications/
- **Android**: Query PackageManager for installed applications
- **iOS**: Query system for applications with associated protocols

#### 4.2.2 Routing Configuration Storage
- Store routing rules in encrypted local storage
- Use platform-specific secure storage (Keychain on macOS/iOS, Credential Manager on Windows, Keystore on Android)
- Backup configuration to cloud if user opts in
- Export/import functionality for backup purposes

#### 4.2.3 Real-Time Status Updates
- Monitor network interfaces for traffic routing changes
- Update UI with current routing status (VPN vs direct)
- Display active/inactive states for each application
- Log routing events for troubleshooting

### 4.3 Implementation Requirements
- **Performance**: Application enumeration should complete within 3 seconds
- **Memory**: Cache application list to reduce repeated system calls
- **Privacy**: Do not transmit application lists to external services
- **Security**: Encrypt routing configuration data on disk
- **Compatibility**: Support older versions of each operating system

## 5. Performance Considerations for App Detection and Routing

### 5.1 Application Discovery Performance
- **Caching Strategy**: Cache application lists with 5-minute TTL
- **Background Discovery**: Perform app discovery during idle periods
- **Incremental Updates**: Detect newly installed/uninstalled apps without full enumeration
- **Resource Limits**: Limit discovery threads to prevent system slowdown

### 5.2 Routing Rule Application
- **Efficiency**: Apply routing rules in batch to minimize system calls
- **Optimization**: Maintain routing rule index for fast lookups
- **Cleanup**: Remove dangling rules for uninstalled applications
- **Validation**: Verify routing rules before applying to prevent conflicts

### 5.3 Memory and CPU Optimization
- **Lazy Loading**: Load application data only when viewed
- **Pagination**: Display applications in paginated lists (50 items/page)
- **Debouncing**: Debounce search input to prevent excessive filtering
- **Threading**: Perform heavy operations on background threads

### 5.4 Resource Monitoring
- Monitor system resources during routing operations
- Temporarily pause operations if system load is too high
- Provide feedback for long-running operations
- Optimize routing rules to minimize processing overhead

## 6. Visual Feedback System for Current App Routing Status

### 6.1 Status Indicator Types
- **VPN Active**: Green dot with VPN icon overlay
- **Direct Connection**: Blue dot with globe icon overlay
- **Mixed Routing**: Yellow split circle (half green, half blue)
- **Inactive**: Gray dot with line-through icon

### 6.2 Real-Time Status Updates
- Update status indicators every 2 seconds when VPN is active
- Show last known status when VPN is inactive
- Highlight recently changed routing status briefly (3 second pulse)
- Display tooltip with detailed routing status on hover/tap

### 6.3 Dashboard View
```
┌─────────────────────────────────────────────────────────────┐
│                CURRENT ROUTING STATUS                       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  VPN Connected: ✓ (US Server, 24ms ping)                  ││
│                                                             │
│  Apps via VPN (3):                                          ││
│  [VPN] Chrome      [VPN] Firefox    [VPN] Spotify         ││
│                                                             │
│  Apps Direct (5):                                           ││
│  [DIR] Outlook     [DIR] Skype      [DIR] Calculator      ││
│  [DIR] Photos      [DIR] Mail                              ││
│                                                             │
│  [View Details] [Configure Routing] [Switch Mode]          ││
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 6.4 Notification System
- Alert users when applications switch routing modes unexpectedly
- Notify about performance impact of routing configuration
- Provide warnings when many apps are routed through VPN
- Show quick access to routing settings from notifications

## 7. Automatic vs Manual App Configuration Options

### 7.1 Automatic Detection and Configuration
- **Smart Defaults**: Pre-configure common applications based on category
- **Usage Tracking**: Learn from user behavior to suggest routing rules
- **Category-Based**: Group applications by function (browsers, banking, media)
- **Intelligent Suggestions**: Recommend routing based on privacy/security needs

### 7.2 Manual Configuration Options
- **Individual Selection**: Allow users to select each application individually
- **Bulk Operations**: Select multiple applications at once
- **Import/Export**: Share routing configurations between devices
- **Presets**: Save and restore routing configuration presets

### 7.3 Hybrid Approach
- **Recommended Settings**: Present smart defaults with option to customize
- **Learning Algorithm**: Adapt recommendations based on user choices
- **Quick Actions**: One-click to route all apps in a category
- **Override Protection**: Allow temporary overrides of automatic settings

### 7.4 Configuration Profiles
- **Work Profile**: Route work-related apps through VPN
- **Privacy Profile**: Route browsers and messaging apps through VPN
- **Performance Profile**: Route only essential apps through VPN
- **Custom Profile**: User-defined routing configuration

## 8. Platform-Specific Implementation Guides

### 8.1 Windows Implementation Guide

#### 8.1.1 Prerequisites
- Windows 10 version 1809 or later (for WFP support)
- Administrative privileges for network configuration
- .NET Framework 4.8 or .NET Core 3.1+

#### 8.1.2 Technical Implementation
- Use Windows Filtering Platform (WFP) for application-specific routing
- Implement using Microsoft's Windows SDK
- Require administrator privileges for TUN interface creation
- Handle UAC prompts gracefully

#### 8.1.3 Application Discovery
```cpp
// Example for enumerating applications
#include <shlobj.h>
#include <appmgmt.h>

// Use SHChangeNotify to monitor application changes
// Query registry for installed programs
// Use Package Manager API for UWP apps
```

#### 8.1.4 Routing Configuration
- Modify WireGuard configuration dynamically
- Use WinDivert for packet interception if needed
- Handle firewall rule creation/deletion
- Implement proper cleanup on service stop

### 8.2 macOS Implementation Guide

#### 8.2.1 Prerequisites
- macOS 10.15 (Catalina) or later
- Network Extension entitlements
- Administrator privileges for network configuration

#### 8.2.2 Technical Implementation
```swift
// Example Swift code structure
import NetworkExtension
import Network

class AppRoutingManager: NSObject {
    private var tunnelManager: NETunnelProviderManager?
    
    func configureAppRouting(for bundleIDs: [String]) -> Bool {
        // Configure per-app VPN routing
        return true
    }
    
    func updateRoutingRules(_ rules: [RoutingRule]) {
        // Update routing configuration
    }
}
```

#### 8.2.3 Application Discovery
- Use Launch Services to enumerate installed applications
- Monitor ~/Applications and /Applications directories
- Track Bundle IDs for proper identification
- Handle sandboxed applications correctly

### 8.3 Linux Implementation Guide

#### 8.3.1 Prerequisites
- Kernel 3.17+ for TUN/TAP interfaces
- iptables with owner matching support
- Administrative privileges (sudo)

#### 8.3.2 Technical Implementation
```bash
# Example routing configuration
# Create routing table for specific user
ip route add default dev tun0 table $TABLE_ID
ip rule add fwmark $MARK lookup $TABLE_ID

# Use owner matching in iptables
iptables -t mangle -A OUTPUT -m owner --uid-owner $UID -j MARK --set-mark $MARK
```

#### 8.3.3 Application Discovery
- Parse .desktop files in standard locations
- Use systemd to discover user services
- Monitor /usr/bin and /usr/local/bin
- Handle Flatpak and Snap packages separately

### 8.4 Android Implementation Guide

#### 8.4.1 Prerequisites
- Android API Level 21+ (Lollipop)
- VPN permissions granted by user
- Proper network security configuration

#### 8.4.2 Technical Implementation
```kotlin
// Example Kotlin code
class SplitTunnelVpnService : VpnService() {
    override fun onCreate() {
        super.onCreate()
        // Initialize routing manager
    }
    
    private fun buildVpnInterface(): Builder {
        val builder = Builder()
        
        // Add allowed applications
        for (packageName in allowedPackages) {
            try {
                builder.addAllowedApplication(packageName)
            } catch (e: PackageManager.NameNotFoundException) {
                // Handle missing packages
            }
        }
        
        // Add disallowed applications (if in include mode)
        for (packageName in disallowedPackages) {
            try {
                builder.addDisallowedApplication(packageName)
            } catch (e: PackageManager.NameNotFoundException) {
                // Handle missing packages
            }
        }
        
        return builder
    }
}
```

#### 8.4.3 Application Discovery
- Query PackageManager for installed packages
- Filter system vs user applications
- Handle application updates and removals
- Respect application opt-out policies

### 8.5 iOS Implementation Guide

#### 8.5.1 Prerequisites
- iOS 9.0+ for Network Extensions
- App Transport Security configuration
- Required entitlements for VPN extensions

#### 8.5.2 Technical Implementation
```swift
import NetworkExtension

class PacketTunnelProvider: NEPacketTunnelProvider {
    
    override func startTunnel(options: [String : NSObject]?, 
                            completionHandler: @escaping (Error?) -> Void) {
        // Configure routing based on stored rules
        setupAppSpecificRouting()
        completionHandler(nil)
    }
    
    private func setupAppSpecificRouting() {
        guard let routingRules = loadRoutingRules() else { return }
        
        // Configure routes based on bundle IDs
        for rule in routingRules {
            configureRoute(for: rule.appId, mode: rule.mode)
        }
    }
}
```

#### 8.5.3 Application Discovery
- Query for applications that have associated URL schemes
- Use LSApplicationQueriesSchemes in Info.plist
- Handle app updates that may change bundle IDs
- Respect app privacy settings

## Conclusion
This comprehensive specification provides the foundation for implementing a cross-platform VPN split tunneling interface that meets all specified requirements. The design emphasizes user-friendliness for non-technical users while providing the sophisticated functionality needed for effective VPN management.

The solution balances performance considerations with usability, ensuring that the application can efficiently manage routing rules without impacting system resources. The platform-specific implementations account for differences in how each operating system handles network routing while maintaining a consistent user experience.
