#!/system/bin/sh
# post-fs-data script for replacer module
# This script runs early in boot process, before system apps are detected
# This ensures file replacements are applied before apps load

MODDIR=${0%/*}
LOGFILE="/data/adb/replacer.log"
DISABLED_FILES_DIR="$MODDIR/disabled_files"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOGFILE"
}

# Check if a file is disabled via WebUI
is_file_disabled() {
    local file_path="$1"
    # Use md5 hash of path as marker filename
    local marker="$DISABLED_FILES_DIR/$(echo -n "$file_path" | md5sum | cut -d' ' -f1)"
    
    if [ -f "$marker" ]; then
        return 0  # File is disabled
    else
        return 1  # File is enabled
    fi
}

log "Replacer module started (post-fs-data stage)"
log "MODDIR: $MODDIR"
log "Processing replacer configuration files..."

# Track processed files to prevent infinite loops
PROCESSED_FILES="/tmp/replacer_processed_$$"
: > "$PROCESSED_FILES"

# Function to process a single CSV file
process_csv_file() {
    local csv_file="$1"
    
    # Check if file exists
    if [ ! -f "$csv_file" ]; then
        log "File not found: $csv_file"
        return
    fi
    
    # Check if file is disabled via WebUI
    if is_file_disabled "$csv_file"; then
        log "File is disabled via WebUI, skipping: $csv_file"
        return
    fi
    
    # Check if already processed (prevent circular includes)
    if grep -qxF "$csv_file" "$PROCESSED_FILES" 2>/dev/null; then
        log "Skipping already processed file: $csv_file"
        return
    fi
    
    # Mark as processed
    echo "$csv_file" >> "$PROCESSED_FILES"
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
        
        # Check for %include directive
        if [ "$original" = "%include" ]; then
            log "Found include directive: $replacement"
            
            # Expand ${mod_dir} or ${MODDIR} in include path
            replacement=$(echo "$replacement" | sed "s|\${mod_dir}|$MODDIR|g" | sed "s|\${MODDIR}|$MODDIR|g")
            
            # Check if it's a directory or file
            if [ -d "$replacement" ]; then
                log "Including directory: $replacement"
                # Process all CSV files in the directory in sorted order
                for include_file in "$replacement"/*.csv; do
                    if [ -f "$include_file" ]; then
                        process_csv_file "$include_file"
                    fi
                done
            elif [ -f "$replacement" ]; then
                log "Including file: $replacement"
                process_csv_file "$replacement"
            else
                log "Include path not found: $replacement"
            fi
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
}

# Main entry point - start with conf.csv in module directory
MAIN_CONFIG="$MODDIR/conf.csv"

if [ -f "$MAIN_CONFIG" ]; then
    log "Starting with main config: $MAIN_CONFIG"
    process_csv_file "$MAIN_CONFIG"
else
    log "Main config not found: $MAIN_CONFIG"
    log "Creating default config with includes..."
    
    # Create default conf.csv if it doesn't exist
    cat > "$MAIN_CONFIG" << 'EOF'
# Replacer main configuration
# This file supports %include directive to include other configurations

# Include system-wide configuration
%include, /data/adb/replacer.conf

# Include all configurations from directory
%include, /data/adb/replacer.conf.d/
EOF
    
    log "Created default config, processing it now..."
    process_csv_file "$MAIN_CONFIG"
fi

# Cleanup
rm -f "$PROCESSED_FILES"

log "Replacer module initialization completed"
