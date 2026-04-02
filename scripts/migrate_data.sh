#!/bin/bash

# Configuration
OLD_ID="com.neewy.tracker-app"
NEW_ID="com.neewy.stanza"
OLD_PATH="$HOME/Library/Containers/$OLD_ID/Data/Library/Application Support"
NEW_PATH="$HOME/Library/Containers/$NEW_ID/Data/Library/Application Support"
BACKUP_DIR="stanza_migration_backup_$(date +%Y%m%d_%H%M%S)"

echo "🚀 Stanza Data Migration Utility"
echo "--------------------------------"

# 1. Check for old data
if [ ! -d "$OLD_PATH" ]; then
    echo "❌ Error: Could not find old TrackerApp data at $OLD_PATH"
    echo "Please ensure you have run TrackerApp on this machine at least once."
    exit 1
fi

# 2. Check for new data (ensure container exists)
if [ ! -d "$NEW_PATH" ]; then
    echo "⚠️ Warning: New Stanza path $NEW_PATH does not exist."
    echo "Creating it now..."
    mkdir -p "$NEW_PATH"
fi

# 3. Create Backup
echo "📦 Backing up old data to $BACKUP_DIR..."
mkdir -p "$BACKUP_DIR"
cp -R "$OLD_PATH"/* "$BACKUP_DIR/"

# 4. Perform Migration
echo "🚚 Moving database files to new Stanza container..."
FILES=("default.store" "default.store-shm" "default.store-wal")

for file in "${FILES[@]}"; do
    if [ -f "$OLD_PATH/$file" ]; then
        echo "   - Migrating $file..."
        cp "$OLD_PATH/$file" "$NEW_PATH/$file"
    else
        echo "   - Skipping $file (not found in old container)"
    fi
done

echo "--------------------------------"
echo "✅ Migration Complete!"
echo "You can now launch Stanza. Your previous entries should be visible."
echo "Note: A backup copy was kept in $BACKUP_DIR"
