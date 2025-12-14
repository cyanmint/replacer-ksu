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
unzip -o "$ZIPFILE" 'service.sh' -d "$MODPATH" >&2

# Set permissions
set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/service.sh" 0 0 0755

# Create config directory
CONFIG_DIR="/data/adb/replacer.d"
if [ ! -d "$CONFIG_DIR" ]; then
    mkdir -p "$CONFIG_DIR"
    ui_print "Created config directory: $CONFIG_DIR"
fi

# Extract example configuration if it exists
if unzip -l "$ZIPFILE" | grep -q "example.csv"; then
    unzip -o "$ZIPFILE" 'example.csv' -d "$CONFIG_DIR" >&2
    ui_print "Installed example configuration to $CONFIG_DIR"
fi

ui_print ""
ui_print "Installation complete!"
ui_print "Place your CSV configuration files in:"
ui_print "$CONFIG_DIR"
ui_print ""
ui_print "See README for configuration format."
ui_print "********************************"
