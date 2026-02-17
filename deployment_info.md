# Deployment Information

## Server Details
- Domain: vm779762.hosted-by.u1host.com
- IP Address: 144.31.227.53 (used internally, not exposed in public links)

## Download Links Structure
The following URL structure should be used for downloading the simplified VPN client applications. Only the domain should be used in public-facing communications:

### Windows
- `https://vm779762.hosted-by.u1host.com/downloads/hiddify-windows.exe`

### macOS
- `https://vm779762.hosted-by.u1host.com/downloads/hiddify-macos.dmg`

### Linux
- `https://vm779762.hosted-by.u1host.com/downloads/hiddify-linux.AppImage`

### Android
- `https://vm779762.hosted-by.u1host.com/downloads/hiddify-android.apk`

### iOS
- `https://vm779762.hosted-by.u1host.com/downloads/hiddify-ios.ipa`

## Web Server Configuration
To serve these files securely, a web server (Nginx) should be configured to serve static files from a downloads directory. See nginx_setup_guide.md for complete configuration instructions including:

- SSL certificate setup for HTTPS serving
- Security headers to protect downloads
- Access control and rate limiting
- IP address hiding by rejecting direct IP access
- Proper MIME types for various file formats

## Server Details
- Domain: vm779762.hosted-by.u1host.com
- IP Address: 144.31.227.53 (used internally, not exposed in public links)

## Download Links Structure
The following URL structure should be used for downloading the simplified VPN client applications. Only the domain should be used in public-facing communications:

### Windows
- `https://vm779762.hosted-by.u1host.com/downloads/hiddify-windows.exe`

### macOS
- `https://vm779762.hosted-by.u1host.com/downloads/hiddify-macos.dmg`

### Linux
- `https://vm779762.hosted-by.u1host.com/downloads/hiddify-linux.AppImage`

### Android
- `https://vm779762.hosted-by.u1host.com/downloads/hiddify-android.apk`

### iOS
- `https://vm779762.hosted-by.u1host.com/downloads/hiddify-ios.ipa`

## Web Server Configuration
To serve these files securely, a web server (Nginx) should be configured to serve static files from a downloads directory. See nginx_setup_guide.md for complete configuration instructions including:

- SSL certificate setup for HTTPS serving
- Security headers to protect downloads
- Access control and rate limiting
- IP address hiding by rejecting direct IP access
- Proper MIME types for various file formats
- Domain: vm779762.hosted-by.u1host.com
- IP Address: 144.31.227.53

## Download Links Structure
The following URL structure can be used for downloading the simplified VPN client applications:

### Windows
- `http://vm779762.hosted-by.u1host.com/downloads/hiddify-windows.exe`
- `http://144.31.227.53/downloads/hiddify-windows.exe`

### macOS
- `http://vm779762.hosted-by.u1host.com/downloads/hiddify-macos.dmg`
- `http://144.31.227.53/downloads/hiddify-macos.dmg`

### Linux
- `http://vm779762.hosted-by.u1host.com/downloads/hiddify-linux.AppImage`
- `http://144.31.227.53/downloads/hiddify-linux.AppImage`

### Android
- `http://vm779762.hosted-by.u1host.com/downloads/hiddify-android.apk`
- `http://144.31.227.53/downloads/hiddify-android.apk`

### iOS
- `http://vm779762.hosted-by.u1host.com/downloads/hiddify-ios.ipa`
- `http://144.31.227.53/downloads/hiddify-ios.ipa`

## Web Server Configuration
To serve these files, a web server (Apache/Nginx) should be configured to serve static files from a downloads directory.
