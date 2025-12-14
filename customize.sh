#!/system/bin/sh
# Customize script for replacer module installation

SKIPUNZIP=1

# Print installation message
ui_print "********************************"
ui_print "     Replacer KSU Module        "
ui_print "********************************"
ui_print ""
ui_print "Installing Replacer module..."

# Extract module files
unzip -o "$ZIPFILE" 'module.prop' -d "$MODPATH" >&2
unzip -o "$ZIPFILE" 'post-fs-data.sh' -d "$MODPATH" >&2
unzip -o "$ZIPFILE" 'conf.csv' -d "$MODPATH" >&2

# Extract webroot directory
unzip -o "$ZIPFILE" 'webroot/*' -d "$MODPATH" >&2

# Set permissions
set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/post-fs-data.sh" 0 0 0755

# Create config directories
mkdir -p /data/adb/replacer.conf.d
ui_print "Created config directory: /data/adb/replacer.conf.d"

# Extract example configuration if it exists
if unzip -l "$ZIPFILE" | grep -q "example.csv"; then
    unzip -o "$ZIPFILE" 'example.csv' -d /data/adb/replacer.conf.d >&2
    ui_print "Installed example configuration"
fi

# Create default replacer.conf if it doesn't exist
if [ ! -f /data/adb/replacer.conf ]; then
    cat > /data/adb/replacer.conf << 'EOF'
# System-wide replacer configuration
# Add your global replacements here

# Example:
# /system/fonts/myfont.ttf, /data/adb/fonts/newfont.ttf
EOF
    ui_print "Created default /data/adb/replacer.conf"
fi

ui_print ""
ui_print "Installation complete!"
ui_print ""
ui_print "✓ Web UI available in KernelSU Manager"
ui_print ""
ui_print "Configuration hierarchy:"
ui_print "1. $MODPATH/conf.csv (main)"
ui_print "2. /data/adb/replacer.conf"
ui_print "3. /data/adb/replacer.conf.d/*.csv"
ui_print ""
ui_print "See README for configuration format."
ui_print "********************************"
