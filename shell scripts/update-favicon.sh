#!/bin/bash
# update-favicon.sh
# Automates replacing DSM's default favicon with my custom favicon.

# Paths
DSM_DIR="/usr/syno/synoman/webman"
SOURCE_ICON="/volume1/web/dan/favicon.ico"
TARGET_ICON="$DSM_DIR/favicon.ico"
BACKUP_ICON="$DSM_DIR/favicon_backup.ico"

echo "=== Updating DSM favicon ==="

# Step 1: Backup existing favicon
if [ -f "$TARGET_ICON" ]; then
    echo "Backing up existing favicon..."
    mv "$TARGET_ICON" "$BACKUP_ICON"
fi

# Step 2: Copy new favicon from your site folder
if [ -f "$SOURCE_ICON" ]; then
    echo "Copying new favicon..."
    cp "$SOURCE_ICON" "$TARGET_ICON"
else
    echo "Source favicon not found at $SOURCE_ICON"
    exit 1
fi

# Step 3: Set correct permissions
echo "Setting permissions..."
chmod 644 "$TARGET_ICON"

# Step 4: Restart DSM web service to flush cache
echo "Restart services or server to apply changes..."