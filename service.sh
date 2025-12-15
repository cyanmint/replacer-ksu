#!/system/bin/sh
# Service script for replacer module
# This script runs after boot completion to clear bootloop protection flags

MODDIR=${0%/*}
LOGFILE="/data/adb/replacer.log"
BOOTLOOP_PROTECTION_DIR="$MODDIR/bootloop_protection"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOGFILE"
}

log "Service script started - waiting for device unlock"

# Wait for boot to complete
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 1
done

log "Boot completed, waiting for user to unlock device"

# Wait for device to be unlocked (user enters password/PIN)
# When device is unlocked, the data partition is fully decrypted
# and various properties change. We check for common unlock indicators.

max_wait=300  # Wait up to 5 minutes for unlock
waited=0

while [ $waited -lt $max_wait ]; do
    # Check if device is unlocked by verifying if user is unlocked
    # Multiple methods to detect unlock:
    
    # Method 1: Check if lockscreen is dismissed (works on most devices)
    lockscreen_dismissed=$(getprop lockscreen.password_type 2>/dev/null)
    
    # Method 2: Check if user 0 is unlocked (Android 7+)
    user_unlocked=$(getprop ro.crypto.state 2>/dev/null)
    
    # Method 3: Check if boot animation has finished and we're past lockscreen
    boot_anim=$(getprop init.svc.bootanim 2>/dev/null)
    
    # Method 4: Check if system is ready and unlocked
    pm_ready=$(pm list packages com.android.systemui 2>/dev/null)
    
    # If any unlock indicator is positive, clear the flags
    if [ "$boot_anim" = "stopped" ] && [ -n "$pm_ready" ]; then
        # Give a bit more time to ensure user interaction
        sleep 10
        
        # Additional check: see if we can access user data
        if [ -d "/data/user/0" ] && [ -r "/data/user/0" ]; then
            log "Device appears to be unlocked, clearing boot flags"
            
            # Clear all boot flags
            if [ -d "$BOOTLOOP_PROTECTION_DIR" ]; then
                rm -f "$BOOTLOOP_PROTECTION_DIR"/boot_flag_*
                log "Boot flags cleared - successful user login detected"
            fi
            
            exit 0
        fi
    fi
    
    sleep 5
    waited=$((waited + 5))
done

log "Timeout waiting for device unlock after $max_wait seconds"
log "Boot flags NOT cleared - this boot may count toward bootloop detection"
