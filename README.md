# Replacer - KernelSU Module

A KernelSU module that automatically replaces or deletes system files based on CSV configuration files.

**Note:** This module is designed specifically for KernelSU (and its derivatives like KSUNext, APatch, Sukisu-Ultra, etc.). It does not support Magisk.

## Features

- 📝 Simple CSV-based configuration
- 🌐 Web UI for easy configuration and module control
- 🔄 Automatic file and directory replacement
- 🗑️ File and directory deletion support
- 📂 Support for both files and directories
- 🔧 KSU variable substitution support (${mod_dir})
- 📊 Hierarchical configuration with %include directive
- 📋 Detailed logging
- ⚡ Uses KSU-native `.replace` files for directory replacement
- 🛡️ **Bootloop protection** - automatically disables after 3 failed boots

## Bootloop Protection

The module includes a built-in safety mechanism to prevent boot loops:

- **Boot Flag System**: Creates a flag file on each boot
- **Auto-Detection**: Monitors for successful user login (device unlock)
- **Flag Clearing**: Removes flags when user unlocks device with password/PIN
- **Auto-Disable**: If 3 boot flags accumulate (3 boots without login), the module automatically disables itself
- **Safe Recovery**: Once disabled, fix your configuration and re-enable via KernelSU Manager

This ensures that if the module causes a boot issue, it will self-disable after 3 attempts, allowing you to boot into your device safely.

**Note**: The module does not restrict which files you can replace or delete. Users are responsible for understanding the impact of their modifications. Be careful when replacing critical system files.

## Installation

1. Download the module ZIP file
2. Install via KernelSU Manager (or compatible manager)
3. Reboot your device
4. Access the Web UI from KernelSU Manager to configure

## Web UI

The module includes a web-based configuration interface accessible through KernelSU Manager:

### Features:
- **Module Toggle**: Enable or disable the module without uninstalling
- **Configuration Tree View**: 
  - Visual hierarchy of all configuration files and their includes
  - Toggle individual files on/off
  - Disabling a parent file automatically disables all files it includes
  - See which files exist and which are missing
  - Click "Edit" button to edit any file in the tree
- **Configuration Editor**: Edit any configuration file directly from the UI
- **Live Validation**: Syntax highlighting and help text for configuration format
- **One-Click Save**: Save changes instantly (takes effect on next boot)

### Access:
1. Open KernelSU Manager
2. Navigate to the Replacer module
3. Tap "Open WebUI" or "Configure"
4. View the configuration tree, toggle files, or edit configurations

## Configuration

The module uses a hierarchical configuration system starting from `${mod_dir}/conf.csv`.

### Configuration Hierarchy

1. **Main Config**: `${mod_dir}/conf.csv` (editable via WebUI)
2. **System Config**: `/data/adb/replacer.conf` 
3. **Drop-in Configs**: `/data/adb/replacer.conf.d/*.csv`

### Include Directive

The `%include` directive allows you to include other configuration files or directories:

```csv
# Include a single file
%include, /data/adb/replacer.conf

# Include all CSV files from a directory
%include, /data/adb/replacer.conf.d/

# Include from module directory
%include, ${mod_dir}/custom.csv
```

**Note**: Circular includes are automatically prevented.

### File Naming

Files are processed in alphabetical/numerical order. It's recommended to prefix files with numbers:
- `10-fonts.csv`
- `20-apps.csv`
- `30-system.csv`

### CSV Format

Each line in the CSV file follows this format:
```
original_path, replacement_path
```

#### Examples

**Replace a file:**
```csv
/product/fonts/original.ttf, ${mod_dir}/files/new.ttf
```

**Delete a file:**
```csv
/system/priv-app/malware/malware.apk, _
```

**Replace a directory:**
```csv
/system/priv-app/app/, ${mod_dir}/replaceapp/
```

**Delete a directory:**
```csv
/system/priv-app/bloatware/, _
```

### Complete Example

Main config file: `${mod_dir}/conf.csv`
```csv
# Main configuration with includes
%include, /data/adb/replacer.conf
%include, /data/adb/replacer.conf.d/
```

System config: `/data/adb/replacer.conf`
```csv
# System-wide replacements
/product/fonts/original.ttf, /data/adb/fonts/new.ttf
```

Drop-in config: `/data/adb/replacer.conf.d/10-debloat.csv`
```csv
# Replace font files
/product/fonts/original.ttf, ${mod_dir}/files/new.ttf
/system/fonts/another.ttf, ${mod_dir}/files/replacement.ttf

# Remove bloatware
/system/priv-app/malware/malware.apk, _

# Replace entire app directory
/system/priv-app/app/, ${mod_dir}/replaceapp/
```

## Syntax Rules

1. **Comments**: Lines starting with `#` are ignored
2. **Empty lines**: Empty lines are ignored
3. **Include directive**: `%include, /path/to/file_or_directory` includes other configurations
4. **Paths ending with `/`**: Treated as directories
5. **Paths without trailing `/`**: Treated as files
6. **Variable substitution**:
   - `${mod_dir}` is automatically substituted by KernelSU with the module directory path
   - Example: `${mod_dir}` → `/data/adb/modules/replacer`
   - The module does not perform this substitution - KSU handles it natively
7. **Deletion marker**: Use `_` (underscore) as the replacement path to delete/mask a file or directory
8. **Limitation**: Paths containing commas (`,`) are not supported due to CSV format constraints
9. **KSU-only**: This module uses KSU-specific features (`.replace` files) and does not support Magisk

## Directory Structure

```
/data/adb/modules/replacer/
├── module.prop          # Module metadata
├── post-fs-data.sh      # Main script (runs early in boot, before system apps load)
├── customize.sh         # Installation script
├── conf.csv             # Main configuration (editable via WebUI)
├── webroot/             # Web UI files
│   ├── index.html
│   └── webui.js
└── files/               # Your replacement files go here
    └── ...

/data/adb/
├── replacer.conf        # System-wide configuration
└── replacer.conf.d/     # Drop-in configuration directory
    ├── 10-fonts.csv
    ├── 20-apps.csv
    └── ...
```

## Logging

The module creates a log file at `/data/adb/replacer.log` with detailed information about:
- Configuration files processed
- Replacements performed
- Deletions performed
- Any errors encountered

To view the log:
```bash
cat /data/adb/replacer.log
```

## How It Works

1. During early boot (post-fs-data stage), the `post-fs-data.sh` script is executed
2. This runs **before system apps are detected**, ensuring replacements take effect immediately
3. KSU automatically substitutes `${mod_dir}` variables before the script runs
4. It starts processing from `${mod_dir}/conf.csv`
5. When an `%include` directive is found:
   - If it points to a file: that file is processed
   - If it points to a directory: all `.csv` files in that directory are processed in sorted order
   - Circular includes are prevented automatically
6. For each replacement line:
   - If replacement is `_`: The file/directory is masked using bind mount or tmpfs
   - Otherwise: The file/directory is replaced using bind mount
   - For directories, KSU's native `.replace` mechanism is leveraged
7. All operations are logged to `/data/adb/replacer.log`

### KSU-Specific Features

This module utilizes KernelSU-specific features:
- **Variable substitution**: KSU handles `${mod_dir}` before the module processes configs
- **`.replace` files**: For complete directory replacement (KSU native feature)
- **Early boot hooks**: Uses `post-fs-data.sh` for early execution

**Note**: This module is not compatible with Magisk due to reliance on KSU-specific features.


## Tips

- **Use numbered prefixes** for configuration files to control processing order
- **Test carefully** before applying to important system files
- **Check the log** at `/data/adb/replacer.log` if something doesn't work
- **Backup important files** before replacing them
- Place your replacement files in the module's `files/` directory or any subdirectory

## Troubleshooting

### Replacements not working

1. Check the log file: `cat /data/adb/replacer.log`
2. Verify paths are correct (including trailing `/` for directories)
3. Ensure replacement files exist at the specified paths
4. Verify CSV syntax is correct (comma-separated, no extra quotes)

### Module not loading

1. Check KernelSU Manager for error messages
2. Verify `post-fs-data.sh` has execute permissions
3. Check for syntax errors in CSV files

### Bootloop protection activated

If the module has auto-disabled due to bootloop protection:

1. **Check the log**: `cat /data/adb/replacer.log` to see what happened
2. **Review your configuration**: Look for problematic replacements in your CSV files
3. **Fix the issue**: Comment out or remove problematic entries
4. **Re-enable the module**: Remove the `disable` file from the module directory:
   ```bash
   rm /data/adb/modules/replacer/disable
   ```
5. **Clear boot flags** (optional): `rm -rf /data/adb/modules/replacer/bootloop_protection/boot_flag_*`
6. **Reboot**: Test your changes

The bootloop protection counter resets after each successful user login (device unlock with password/PIN).

## License

This project is open source. Feel free to use, modify, and distribute.

## Credits

Created by cyanmint for KernelSU.