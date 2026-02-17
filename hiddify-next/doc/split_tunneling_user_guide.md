# Split Tunneling (App Routing) User Guide

## What is Split Tunneling?

Split tunneling (also known as app routing or per-app proxy) is a feature that allows you to selectively route specific applications through the VPN while letting others connect directly to the internet. This gives you granular control over which apps use the VPN and which don't.

### Benefits of Split Tunneling:
- **Selective Privacy**: Protect sensitive apps while allowing local services to operate normally
- **Better Performance**: Non-sensitive apps can use faster local connections
- **Regional Services**: Access region-specific content without affecting other apps
- **Battery Life**: Reduce VPN overhead for apps that don't need it

## How to Use Split Tunneling

### 1. Accessing the Feature

You can access the split tunneling settings in two ways:

**Method 1: From Settings**
1. Open the Hiddify app
2. Navigate to Settings → Network → Per-App Proxy

**Method 2: From Main Screen**
1. On the simplified home page, look for the "App Routing" option in the action buttons
2. Tap to open the configuration screen

### 2. Understanding the Interface

When you open the split tunneling screen, you'll see:

- **Mode Selector**: Toggle between Include and Exclude modes
- **Application List**: All installed applications with checkboxes
- **Search Bar**: Find specific applications
- **Category Filters**: Group apps by function (Browsers, Social, Media, etc.)
- **Status Summary**: Shows how many apps are currently routed through VPN

### 3. Configuring App Routes

#### Include Mode vs Exclude Mode

**Include Mode (Recommended for Privacy)**:
- Only the selected applications will be routed through the VPN
- All other applications will connect directly to the internet
- Example: If you only select your browser and messaging apps, only those will use the VPN

**Exclude Mode (Recommended for Convenience)**:
- All applications will be routed through the VPN except for those explicitly selected
- Selected applications will connect directly to the internet
- Example: If you exclude your banking app and local news app, everything else will use the VPN

#### Adding Apps to Route

1. Select your preferred mode (Include or Exclude)
2. Browse the application list or use the search bar to find specific apps
3. Tap the checkbox next to each app you want to include/exclude
4. Use the "Select All" or "Invert Selection" options for bulk operations
5. Tap "Save" to apply your changes

#### Removing Apps from Route

1. Uncheck the box next to the app you want to remove from the routing list
2. Tap "Save" to apply changes

### 4. Visual Indicators

The app includes several visual elements to help understand routing status:

- **Green checkmark**: App is routed through VPN
- **Blue globe icon**: App connects directly to the internet
- **Progress bar**: Shows percentage of apps in each routing mode
- **Status summary**: Displays total counts of routed vs direct apps

## Best Practices

### For Privacy-Conscious Users
- Use **Include Mode** to route only essential apps through VPN
- Select browsers, email clients, and messaging apps
- Exclude system apps and local services

### For Performance-Conscious Users
- Use **Exclude Mode** to bypass VPN for bandwidth-intensive apps
- Exclude video streaming, gaming, or local services
- Keep essential privacy apps on VPN

### For Country-Specific Services
- Exclude local banking, shopping, or government apps from VPN
- Include apps for accessing global content
- Remember to switch settings when traveling internationally

## Troubleshooting

### Common Issues and Solutions

**Issue: Apps don't appear in the list**
- Solution: Ensure the app has the necessary permissions to scan installed applications
- Try restarting the Hiddify app

**Issue: Routing doesn't seem to be working**
- Solution: Restart the VPN connection after applying new rules
- Check that you're in the correct mode (Include vs Exclude)

**Issue: Performance is slower than expected**
- Solution: Reduce the number of apps in your routing rules
- Try excluding resource-heavy apps from VPN routing

**Issue: Gaming or streaming apps still seem slow**
- Solution: Add these apps to the exclusion list if you don't need them on VPN

### Resetting Configuration

To reset all routing rules to default:
1. Go to the split tunneling screen
2. Use the "Clear Selection" option in the menu
3. Or toggle the split tunneling switch OFF and then ON again

## FAQ

### Q: Can I use split tunneling with all VPN configurations?
A: Yes, split tunneling works with all supported VPN protocols in Hiddify-Next.

### Q: Will apps not routed through VPN be able to detect my real IP?
A: Yes, apps configured to bypass the VPN will use your actual IP address and location.

### Q: Why are system apps listed?
A: System apps are shown to give you complete control over all applications. Only include system apps if you specifically need them routed through VPN.

### Q: Do app updates affect routing rules?
A: Generally, app updates do not affect routing rules. However, if an app changes its package name or identifier, routing rules may need to be reapplied.

### Q: Can I schedule routing rules?
A: Currently, routing rules are static. Scheduled rules may be implemented in future versions.

## Tips & Tricks

1. **Start simple**: Begin with a few apps and gradually expand your routing rules
2. **Group by purpose**: Organize apps by what you want to achieve (privacy, performance, etc.)
3. **Use search**: The search function helps quickly find specific applications
4. **Monitor performance**: Watch for any changes in speed or connectivity after applying rules
5. **Use categories**: Filter by categories to quickly find apps that serve similar functions

## Platform Notes

### Android
- May require additional permissions for app detection on newer Android versions
- System apps are marked for easy identification
- Works with all Android VPN-capable apps

### iOS
- Requires VPN configuration profile with full access
- App routing works with all sandboxed applications
- Background app refresh follows the same routing rules

### Windows, macOS, Linux
- May require administrative privileges for routing configuration
- Supports both traditional applications and UWP/Flatpak/Snap packages
- System integration may vary based on firewall configuration

---

**Note**: This feature requires the VPN service to be active to take effect. Split tunneling rules are applied only when the VPN is connected.

For additional support, please check the Hiddify community forums or contact our support team.
## What is Split Tunneling?

Split tunneling (also known as app routing or per-app proxy) is a feature that allows you to selectively route specific applications through the VPN while letting others connect directly to the internet. This gives you granular control over which apps use the VPN and which don't.

### Benefits of Split Tunneling:
- **Selective Privacy**: Protect sensitive apps while allowing local services to operate normally
- **Better Performance**: Non-sensitive apps can use faster local connections
- **Regional Services**: Access region-specific content without affecting other apps
- **Battery Life**: Reduce VPN overhead for apps that don't need it

## How to Use Split Tunneling

### 1. Accessing the Feature

You can access the split tunneling settings in two ways:

**Method 1: From Settings**
1. Open the Hiddify app
2. Navigate to Settings → Network → Per-App Proxy

**Method 2: From Main Screen**
1. On the simplified home page, look for the "App Routing" option in the action buttons
2. Tap to open the configuration screen

### 2. Understanding the Interface

When you open the split tunneling screen, you'll see:

- **Mode Selector**: Toggle between Include and Exclude modes
- **Application List**: All installed applications with checkboxes
- **Search Bar**: Find specific applications
- **Category Filters**: Group apps by function (Browsers, Social, Media, etc.)
- **Status Summary**: Shows how many apps are currently routed through VPN

### 3. Configuring App Routes

#### Include Mode vs Exclude Mode

**Include Mode (Recommended for Privacy)**:
- Only the selected applications will be routed through the VPN
- All other applications will connect directly to the internet
- Example: If you only select your browser and messaging apps, only those will use the VPN

**Exclude Mode (Recommended for Convenience)**:
- All applications will be routed through the VPN except for those explicitly selected
- Selected applications will connect directly to the internet
- Example: If you exclude your banking app and local news app, everything else will use the VPN

#### Adding Apps to Route

1. Select your preferred mode (Include or Exclude)
2. Browse the application list or use the search bar to find specific apps
3. Tap the checkbox next to each app you want to include/exclude
4. Use the "Select All" or "Invert Selection" options for bulk operations
5. Tap "Save" to apply your changes

#### Removing Apps from Route

1. Uncheck the box next to the app you want to remove from the routing list
2. Tap "Save" to apply changes

### 4. Visual Indicators

The app includes several visual elements to help understand routing status:

- **Green checkmark**: App is routed through VPN
- **Blue globe icon**: App connects directly to the internet
- **Progress bar**: Shows percentage of apps in each routing mode
- **Status summary**: Displays total counts of routed vs direct apps

## Best Practices

### For Privacy-Conscious Users
- Use **Include Mode** to route only essential apps through VPN
- Select browsers, email clients, and messaging apps
- Exclude system apps and local services

### For Performance-Conscious Users
- Use **Exclude Mode** to bypass VPN for bandwidth-intensive apps
- Exclude video streaming, gaming, or local services
- Keep essential privacy apps on VPN

### For Country-Specific Services
- Exclude local banking, shopping, or government apps from VPN
- Include apps for accessing global content
- Remember to switch settings when traveling internationally

## Troubleshooting

### Common Issues and Solutions

**Issue: Apps don't appear in the list**
- Solution: Ensure the app has the necessary permissions to scan installed applications
- Try restarting the Hiddify app

**Issue: Routing doesn't seem to be working**
- Solution: Restart the VPN connection after applying new rules
- Check that you're in the correct mode (Include vs Exclude)

**Issue: Performance is slower than expected**
- Solution: Reduce the number of apps in your routing rules
- Try excluding resource-heavy apps from VPN routing

**Issue: Gaming or streaming apps still seem slow**
- Solution: Add these apps to the exclusion list if you don't need them on VPN

### Resetting Configuration

To reset all routing rules to default:
1. Go to the split tunneling screen
2. Use the "Clear Selection" option in the menu
3. Or toggle the split tunneling switch OFF and then ON again

## FAQ

### Q: Can I use split tunneling with all VPN configurations?
A: Yes, split tunneling works with all supported VPN protocols in Hiddify-Next.

### Q: Will apps not routed through VPN be able to detect my real IP?
A: Yes, apps configured to bypass the VPN will use your actual IP address and location.

### Q: Why are system apps listed?
A: System apps are shown to give you complete control over all applications. Only include system apps if you specifically need them routed through VPN.

### Q: Do app updates affect routing rules?
A: Generally, app updates do not affect routing rules. However, if an app changes its package name or identifier, routing rules may need to be reapplied.

### Q: Can I schedule routing rules?
A: Currently, routing rules are static. Scheduled rules may be implemented in future versions.

## Tips & Tricks

1. **Start simple**: Begin with a few apps and gradually expand your routing rules
2. **Group by purpose**: Organize apps by what you want to achieve (privacy, performance, etc.)
3. **Use search**: The search function helps quickly find specific applications
4. **Monitor performance**: Watch for any changes in speed or connectivity after applying rules
5. **Use categories**: Filter by categories to quickly find apps that serve similar functions

## Platform Notes

### Android
- May require additional permissions for app detection on newer Android versions
- System apps are marked for easy identification
- Works with all Android VPN-capable apps

### iOS
- Requires VPN configuration profile with full access
- App routing works with all sandboxed applications
- Background app refresh follows the same routing rules

### Windows, macOS, Linux
- May require administrative privileges for routing configuration
- Supports both traditional applications and UWP/Flatpak/Snap packages
- System integration may vary based on firewall configuration

---

**Note**: This feature requires the VPN service to be active to take effect. Split tunneling rules are applied only when the VPN is connected.

For additional support, please check the Hiddify community forums or contact our support team.
