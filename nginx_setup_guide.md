# Nginx Setup Guide for VPN Client Downloads

## Security Configuration

To properly serve VPN client downloads and hide server IP details, follow this configuration:

```nginx
# /etc/nginx/sites-available/vpn-downloads

server {
    listen 80;
    server_name vm779762.hosted-by.u1host.com;

    # Redirect HTTP to HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name vm779762.hosted-by.u1host.com;

    # SSL Certificate (use Let's Encrypt or your certificate)
    ssl_certificate /path/to/ssl/certificate.crt;
    ssl_certificate_key /path/to/ssl/private.key;

    # SSL Security Settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;

    # Security Headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";

    # Hide Nginx version
    server_tokens off;

    # Main location for VPN client downloads
    location /downloads/ {
        alias /var/www/vpn-downloads/;
        autoindex off;  # Disable directory listing
        try_files $uri =404;

        # Security headers for downloads
        add_header Content-Disposition "attachment";
        add_header X-Content-Type-Options nosniff;
        
        # Limit request size
        client_max_body_size 100M;
        
        # Rate limiting (optional)
        limit_req zone=download burst=5 nodelay;
    }

    # Main location for VPN configurations
    location /configs/ {
        alias /var/www/vpn-configs/;
        autoindex off;
        try_files $uri =404;

        # Security headers for configs
        add_header Content-Type application/json;
        add_header X-Content-Type-Options nosniff;
        
        # Limit access to known config file types
        location ~* \.(json|txt|yaml)$ {
            add_header Content-Disposition "attachment";
        }
    }

    # Block access to sensitive files
    location ~ /\. {
        deny all;
    }

    # Logging
    access_log /var/log/nginx/vpn_downloads_access.log;
    error_log /var/log/nginx/vpn_downloads_error.log;
}

# Rate limiting zone for downloads
limit_req_zone $binary_remote_addr zone=download:10m rate=10r/s;
```

## Required Steps to Set Up

1. **Install Nginx**:
```bash
sudo apt update
sudo apt install nginx -y
```

2. **Create the directory structure**:
```bash
sudo mkdir -p /var/www/vpn-downloads
sudo mkdir -p /var/www/vpn-configs

# Set appropriate permissions
sudo chown -R www-data:www-data /var/www/vpn-downloads
sudo chown -R www-data:www-data /var/www/vpn-configs
sudo chmod -R 755 /var/www/vpn-downloads
sudo chmod -R 755 /var/www/vpn-configs
```

3. **Configure the virtual host**:
```bash
sudo nano /etc/nginx/sites-available/vpn-downloads
```

Copy the configuration above into the file.

4. **Enable the site**:
```bash
sudo ln -s /etc/nginx/sites-available/vpn-downloads /etc/nginx/sites-enabled/
sudo nginx -t  # Test configuration
sudo systemctl reload nginx
```

5. **Setup SSL certificate** (recommended):
```bash
sudo apt install certbot python3-certbot-nginx -y
sudo certbot --nginx -d vm779762.hosted-by.u1host.com
```

6. **Upload your VPN client packages**:
Upload your compiled VPN client packages to `/var/www/vpn-downloads/`. For example:
- hiddify-windows.exe
- hiddify-macos.dmg
- hiddify-linux.AppImage
- hiddify-android.apk
- hiddify-ios.ipa

## Download URLs

With this setup, your download links will be:

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

## Additional Security Measures

1. **Block direct IP access**:
In your main nginx configuration (`/etc/nginx/nginx.conf`), add:
```nginx
server {
    listen 80 default_server;
    listen 443 default_server ssl;
    return 444;  # Close connection silently
}
```

2. **Configure firewall**:
```bash
sudo ufw allow 'Nginx Full'
sudo ufw --force enable
```

3. **Regular updates**:
```bash
sudo apt update && sudo apt upgrade
```

This configuration ensures that:
- Only your domain is accessible, hiding the IP address
- Downloads are served securely over HTTPS
- Directory listing is disabled
- Appropriate security headers are in place
- Rate limiting protects against abuse
- File types are properly handled
## Security Configuration

To properly serve VPN client downloads and hide server IP details, follow this configuration:

```nginx
# /etc/nginx/sites-available/vpn-downloads

server {
    listen 80;
    server_name vm779762.hosted-by.u1host.com;

    # Redirect HTTP to HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name vm779762.hosted-by.u1host.com;

    # SSL Certificate (use Let's Encrypt or your certificate)
    ssl_certificate /path/to/ssl/certificate.crt;
    ssl_certificate_key /path/to/ssl/private.key;

    # SSL Security Settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;

    # Security Headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";

    # Hide Nginx version
    server_tokens off;

    # Main location for VPN client downloads
    location /downloads/ {
        alias /var/www/vpn-downloads/;
        autoindex off;  # Disable directory listing
        try_files $uri =404;

        # Security headers for downloads
        add_header Content-Disposition "attachment";
        add_header X-Content-Type-Options nosniff;
        
        # Limit request size
        client_max_body_size 100M;
        
        # Rate limiting (optional)
        limit_req zone=download burst=5 nodelay;
    }

    # Main location for VPN configurations
    location /configs/ {
        alias /var/www/vpn-configs/;
        autoindex off;
        try_files $uri =404;

        # Security headers for configs
        add_header Content-Type application/json;
        add_header X-Content-Type-Options nosniff;
        
        # Limit access to known config file types
        location ~* \.(json|txt|yaml)$ {
            add_header Content-Disposition "attachment";
        }
    }

    # Block access to sensitive files
    location ~ /\. {
        deny all;
    }

    # Logging
    access_log /var/log/nginx/vpn_downloads_access.log;
    error_log /var/log/nginx/vpn_downloads_error.log;
}

# Rate limiting zone for downloads
limit_req_zone $binary_remote_addr zone=download:10m rate=10r/s;
```

## Required Steps to Set Up

1. **Install Nginx**:
```bash
sudo apt update
sudo apt install nginx -y
```

2. **Create the directory structure**:
```bash
sudo mkdir -p /var/www/vpn-downloads
sudo mkdir -p /var/www/vpn-configs

# Set appropriate permissions
sudo chown -R www-data:www-data /var/www/vpn-downloads
sudo chown -R www-data:www-data /var/www/vpn-configs
sudo chmod -R 755 /var/www/vpn-downloads
sudo chmod -R 755 /var/www/vpn-configs
```

3. **Configure the virtual host**:
```bash
sudo nano /etc/nginx/sites-available/vpn-downloads
```

Copy the configuration above into the file.

4. **Enable the site**:
```bash
sudo ln -s /etc/nginx/sites-available/vpn-downloads /etc/nginx/sites-enabled/
sudo nginx -t  # Test configuration
sudo systemctl reload nginx
```

5. **Setup SSL certificate** (recommended):
```bash
sudo apt install certbot python3-certbot-nginx -y
sudo certbot --nginx -d vm779762.hosted-by.u1host.com
```

6. **Upload your VPN client packages**:
Upload your compiled VPN client packages to `/var/www/vpn-downloads/`. For example:
- hiddify-windows.exe
- hiddify-macos.dmg
- hiddify-linux.AppImage
- hiddify-android.apk
- hiddify-ios.ipa

## Download URLs

With this setup, your download links will be:

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

## Additional Security Measures

1. **Block direct IP access**:
In your main nginx configuration (`/etc/nginx/nginx.conf`), add:
```nginx
server {
    listen 80 default_server;
    listen 443 default_server ssl;
    return 444;  # Close connection silently
}
```

2. **Configure firewall**:
```bash
sudo ufw allow 'Nginx Full'
sudo ufw --force enable
```

3. **Regular updates**:
```bash
sudo apt update && sudo apt upgrade
```

This configuration ensures that:
- Only your domain is accessible, hiding the IP address
- Downloads are served securely over HTTPS
- Directory listing is disabled
- Appropriate security headers are in place
- Rate limiting protects against abuse
- File types are properly handled
