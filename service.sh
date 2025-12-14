#!/system/bin/sh
# Service script for replacer module
# This script processes CSV files in /data/adb/replacer.d/ and performs replacements

MODDIR=${0%/*}
CONFIG_DIR="/data/adb/replacer.d"
LOGFILE="/data/adb/replacer.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOGFILE"
}

log "Replacer module started"
log "MODDIR: $MODDIR"

# Create config directory if it doesn't exist
if [ ! -d "$CONFIG_DIR" ]; then
    mkdir -p "$CONFIG_DIR"
    log "Created config directory: $CONFIG_DIR"
fi

# Wait for boot to complete
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 1
done

# Additional wait to ensure system is ready
sleep 5

log "Processing replacer configuration files..."

# Process all CSV files in sorted order
for csv_file in "$CONFIG_DIR"/*.csv; do
    if [ ! -f "$csv_file" ]; then
        continue
    fi
    
    log "Processing file: $csv_file"
    
    # Read CSV file line by line
    while IFS= read -r line || [ -n "$line" ]; do
        # Trim leading and trailing whitespace for comment detection
        trimmed_line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        # Skip empty lines and comments
        if [ -z "$trimmed_line" ] || echo "$trimmed_line" | grep -q "^#"; then
            continue
        fi
        
        # Parse CSV line (format: original_path, replacement_path)
        original=$(echo "$line" | cut -d',' -f1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        replacement=$(echo "$line" | cut -d',' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        # Skip if original path is empty
        if [ -z "$original" ]; then
            continue
        fi
        
        log "Processing: '$original' -> '$replacement'"
        
        # Expand ${mod_dir} or ${MODDIR} in replacement path
        replacement=$(echo "$replacement" | sed "s|\${mod_dir}|$MODDIR|g" | sed "s|\${MODDIR}|$MODDIR|g")
        
        # Check if this is a deletion (replacement is underscore)
        if [ "$replacement" = "_" ]; then
            log "Deleting: $original"
            
            # Check if path ends with / (directory)
            case "$original" in
                */)
                    # Mask directory by creating empty tmpfs
                    original="${original%/}"  # Remove trailing slash
                    if [ -d "$original" ]; then
                        mount -t tmpfs -o size=1k tmpfs "$original" 2>/dev/null && \
                            log "Successfully masked directory: $original" || \
                            log "Failed to mask directory: $original"
                    else
                        log "Directory not found: $original"
                    fi
                    ;;
                *)
                    # Mask file with /dev/null
                    if [ -e "$original" ]; then
                        mount -o bind /dev/null "$original" 2>/dev/null && \
                            log "Successfully masked file: $original" || \
                            log "Failed to mask file: $original"
                    else
                        log "File not found: $original"
                    fi
                    ;;
            esac
        else
            # This is a replacement
            log "Replacing: $original with $replacement"
            
            # Check if paths end with / (directories)
            case "$original" in
                */)
                    # Directory replacement
                    original="${original%/}"  # Remove trailing slash
                    replacement="${replacement%/}"  # Remove trailing slash
                    
                    if [ ! -d "$replacement" ]; then
                        log "Replacement directory not found: $replacement"
                        continue
                    fi
                    
                    if [ ! -d "$original" ]; then
                        log "Original directory not found: $original"
                        continue
                    fi
                    
                    mount -o bind "$replacement" "$original" 2>/dev/null && \
                        log "Successfully replaced directory: $original" || \
                        log "Failed to replace directory: $original"
                    ;;
                *)
                    # File replacement
                    if [ ! -e "$replacement" ]; then
                        log "Replacement file not found: $replacement"
                        continue
                    fi
                    
                    if [ ! -e "$original" ]; then
                        log "Original file not found: $original"
                        continue
                    fi
                    
                    mount -o bind "$replacement" "$original" 2>/dev/null && \
                        log "Successfully replaced file: $original" || \
                        log "Failed to replace file: $original"
                    ;;
            esac
        fi
    done < "$csv_file"
    
    log "Finished processing: $csv_file"
done

log "Replacer module initialization completed"
