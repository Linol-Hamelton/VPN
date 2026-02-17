//
// ExtensionProvider+Splits.swift
// HiddifyPacketTunnel
//
// Implements split tunneling functionality for iOS using Network Extensions
//

import Foundation
import NetworkExtension
import Libcore

// MARK: - Split Tunneling Methods
extension ExtensionProvider {
    
    /**
     Sets up app-based routing rules for split tunneling
     - Parameters:
        - appList: Array of bundle identifiers to include or exclude
        - includeMode: True if apps should be included in VPN, false if excluded
     */
    func setupAppBasedRouting(appList: [String], includeMode: Bool) throws {
        writeMessage("Setting up app-based routing for \(appList.count) apps in \(includeMode ? "include" : "exclude") mode")
        
        // Note: Due to iOS limitations, we use the NEVPNProtocol configuration
        // to set up app-based exclusions/inclusions
        
        if let tunnelProvider = self.protocolConfiguration as? NETunnelProviderProtocol {
            if includeMode {
                // In include mode, we only allow specified apps through VPN
                // (This requires a different approach since iOS doesn't easily allow restricting to only specific apps)
                tunnelProvider.includeAllNetworks = false
                writeMessage("Include mode: Currently using system default routing - iOS limitations apply")
                
                // Set included apps if possible
                if #available(iOS 15.0, *) {
                    do {
                        let includedAppIDs = try appList.map { try NSBundleID(string: $0) }
                        tunnelProvider.includedAppBoundIdentifiers = includedAppIDs
                        writeMessage("Successfully set \(includedAppIDs.count) included app IDs")
                    } catch {
                        writeMessage("Failed to set included app IDs: \(error)")
                    }
                } else {
                    writeMessage("iOS version too old for includedAppBoundIdentifiers")
                }
            } else {
                // In exclude mode, we exclude specific apps from VPN
                if #available(iOS 15.0, *) {
                    do {
                        let excludedAppIDs = try appList.map { try NSBundleID(string: $0) }
                        tunnelProvider.excludedAppBoundIdentifiers = excludedAppIDs
                        writeMessage("Successfully set \(excludedAppIDs.count) excluded app IDs")
                    } catch {
                        writeMessage("Failed to set excluded app IDs: \(error)")
                    }
                } else {
                    writeMessage("iOS version too old for excludedAppBoundIdentifiers")
                }
            }
        } else {
            writeMessage("Protocol configuration is not NETunnelProviderProtocol")
        }
    }
    
    /**
     Resets app-based routing to default behavior
     */
    func resetAppBasedRouting() throws {
        writeMessage("Resetting app-based routing to default")
        
        if let tunnelProvider = self.protocolConfiguration as? NETunnelProviderProtocol {
            // Clear app-specific routing rules
            if #available(iOS 15.0, *) {
                tunnelProvider.includedAppBoundIdentifiers = []
                tunnelProvider.excludedAppBoundIdentifiers = []
            } else {
                writeMessage("Cannot reset app routing - iOS version too old")
            }
        }
    }
    
    /**
     Checks if an app is currently routed through the VPN
     - Parameter bundleID: The bundle identifier of the app to check
     - Returns: Boolean indicating if the app is routed through VPN
     */
    func isAppRoutedThroughVPN(bundleID: String) -> Bool {
        writeMessage("Checking if app \(bundleID) is routed through VPN")
        
        // For iOS, we determine this based on the exclusion/inclusion lists
        if let tunnelProvider = self.protocolConfiguration as? NETunnelProviderProtocol {
            if #available(iOS 15.0, *) {
                // If we have inclusion list, only apps in the list are routed through VPN
                if let includedAppIDs = tunnelProvider.includedAppBoundIdentifiers,
                   !includedAppIDs.isEmpty {
                    return includedAppIDs.contains { $0.stringValue == bundleID }
                }
                
                // If we have exclusion list, apps not in the list are routed through VPN
                if let excludedAppIDs = tunnelProvider.excludedAppBoundIdentifiers,
                   !excludedAppIDs.isEmpty {
                    return !excludedAppIDs.contains { $0.stringValue == bundleID }
                }
            }
        }
        
        // By default, all traffic goes through VPN
        return true
    }
    
    /**
     Gets a list of installed applications that can be used for split tunneling
     */
    func getInstalledApplications() -> [String: String] {
        writeMessage("Getting list of installed applications for split tunneling")
        
        // iOS restricts the ability to list all installed apps
        // Instead, we'll return an empty list with a note that apps need to be added manually
        // or retrieved via other means in the app extension
        
        writeMessage("iOS restrictions prevent automatic app listing - apps must be added manually")
        return [:]
    }
    
    /**
     Updates VPN configuration with split tunneling rules
     */
    func updateSplitTunnelingConfiguration(includeMode: Bool, appList: [String]) async {
        writeMessage("Updating split tunneling configuration: mode=\(includeMode), apps=\(appList.count)")
        
        await self.reloadService()
        
        // Reconfigure the protocol with new app rules
        do {
            try setupAppBasedRouting(appList: appList, includeMode: includeMode)
            writeMessage("Successfully updated split tunneling configuration")
        } catch {
            writeMessage("Failed to update split tunneling configuration: \(error)")
        }
    }
}// ExtensionProvider+Splits.swift
// HiddifyPacketTunnel
//
// Implements split tunneling functionality for iOS using Network Extensions
//

import Foundation
import NetworkExtension
import Libcore

// MARK: - Split Tunneling Methods
extension ExtensionProvider {
    
    /**
     Sets up app-based routing rules for split tunneling
     - Parameters:
        - appList: Array of bundle identifiers to include or exclude
        - includeMode: True if apps should be included in VPN, false if excluded
     */
    func setupAppBasedRouting(appList: [String], includeMode: Bool) throws {
        writeMessage("Setting up app-based routing for \(appList.count) apps in \(includeMode ? "include" : "exclude") mode")
        
        // Note: Due to iOS limitations, we use the NEVPNProtocol configuration
        // to set up app-based exclusions/inclusions
        
        if let tunnelProvider = self.protocolConfiguration as? NETunnelProviderProtocol {
            if includeMode {
                // In include mode, we only allow specified apps through VPN
                // (This requires a different approach since iOS doesn't easily allow restricting to only specific apps)
                tunnelProvider.includeAllNetworks = false
                writeMessage("Include mode: Currently using system default routing - iOS limitations apply")
                
                // Set included apps if possible
                if #available(iOS 15.0, *) {
                    do {
                        let includedAppIDs = try appList.map { try NSBundleID(string: $0) }
                        tunnelProvider.includedAppBoundIdentifiers = includedAppIDs
                        writeMessage("Successfully set \(includedAppIDs.count) included app IDs")
                    } catch {
                        writeMessage("Failed to set included app IDs: \(error)")
                    }
                } else {
                    writeMessage("iOS version too old for includedAppBoundIdentifiers")
                }
            } else {
                // In exclude mode, we exclude specific apps from VPN
                if #available(iOS 15.0, *) {
                    do {
                        let excludedAppIDs = try appList.map { try NSBundleID(string: $0) }
                        tunnelProvider.excludedAppBoundIdentifiers = excludedAppIDs
                        writeMessage("Successfully set \(excludedAppIDs.count) excluded app IDs")
                    } catch {
                        writeMessage("Failed to set excluded app IDs: \(error)")
                    }
                } else {
                    writeMessage("iOS version too old for excludedAppBoundIdentifiers")
                }
            }
        } else {
            writeMessage("Protocol configuration is not NETunnelProviderProtocol")
        }
    }
    
    /**
     Resets app-based routing to default behavior
     */
    func resetAppBasedRouting() throws {
        writeMessage("Resetting app-based routing to default")
        
        if let tunnelProvider = self.protocolConfiguration as? NETunnelProviderProtocol {
            // Clear app-specific routing rules
            if #available(iOS 15.0, *) {
                tunnelProvider.includedAppBoundIdentifiers = []
                tunnelProvider.excludedAppBoundIdentifiers = []
            } else {
                writeMessage("Cannot reset app routing - iOS version too old")
            }
        }
    }
    
    /**
     Checks if an app is currently routed through the VPN
     - Parameter bundleID: The bundle identifier of the app to check
     - Returns: Boolean indicating if the app is routed through VPN
     */
    func isAppRoutedThroughVPN(bundleID: String) -> Bool {
        writeMessage("Checking if app \(bundleID) is routed through VPN")
        
        // For iOS, we determine this based on the exclusion/inclusion lists
        if let tunnelProvider = self.protocolConfiguration as? NETunnelProviderProtocol {
            if #available(iOS 15.0, *) {
                // If we have inclusion list, only apps in the list are routed through VPN
                if let includedAppIDs = tunnelProvider.includedAppBoundIdentifiers,
                   !includedAppIDs.isEmpty {
                    return includedAppIDs.contains { $0.stringValue == bundleID }
                }
                
                // If we have exclusion list, apps not in the list are routed through VPN
                if let excludedAppIDs = tunnelProvider.excludedAppBoundIdentifiers,
                   !excludedAppIDs.isEmpty {
                    return !excludedAppIDs.contains { $0.stringValue == bundleID }
                }
            }
        }
        
        // By default, all traffic goes through VPN
        return true
    }
    
    /**
     Gets a list of installed applications that can be used for split tunneling
     */
    func getInstalledApplications() -> [String: String] {
        writeMessage("Getting list of installed applications for split tunneling")
        
        // iOS restricts the ability to list all installed apps
        // Instead, we'll return an empty list with a note that apps need to be added manually
        // or retrieved via other means in the app extension
        
        writeMessage("iOS restrictions prevent automatic app listing - apps must be added manually")
        return [:]
    }
    
    /**
     Updates VPN configuration with split tunneling rules
     */
    func updateSplitTunnelingConfiguration(includeMode: Bool, appList: [String]) async {
        writeMessage("Updating split tunneling configuration: mode=\(includeMode), apps=\(appList.count)")
        
        await self.reloadService()
        
        // Reconfigure the protocol with new app rules
        do {
            try setupAppBasedRouting(appList: appList, includeMode: includeMode)
            writeMessage("Successfully updated split tunneling configuration")
        } catch {
            writeMessage("Failed to update split tunneling configuration: \(error)")
        }
    }
}
