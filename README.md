# Replacer - KernelSU Module

A KernelSU module that automatically replaces or deletes system files based on CSV configuration files.

## Features

- 📝 Simple CSV-based configuration
- 🌐 Web UI for easy configuration and module control
- 🔄 Automatic file and directory replacement
- 🗑️ File and directory deletion support
- 📂 Support for both files and directories
- 🔧 Variable substitution for module directory
- 📊 Hierarchical configuration with %include directive
- 📋 Detailed logging

## Installation

1. Download the module ZIP file
2. Install via KernelSU Manager
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
   - `${mod_dir}` or `${MODDIR}` will be replaced with the module directory path
   - Example: `/data/adb/modules/replacer`
7. **Deletion marker**: Use `_` (underscore) as the replacement path to delete/mask a file or directory
8. **Limitation**: Paths containing commas (`,`) are not supported due to CSV format constraints

## Directory Structure

```
/data/adb/modules/replacer/
├── module.prop          # Module metadata
├── service.sh           # Main script (runs on boot)
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

1. On boot, the `service.sh` script is executed
2. The script waits for the system to fully boot
3. It starts processing from `${mod_dir}/conf.csv`
4. When an `%include` directive is found:
   - If it points to a file: that file is processed
   - If it points to a directory: all `.csv` files in that directory are processed in sorted order
   - Circular includes are prevented automatically
5. For each replacement line:
   - If replacement is `_`: The file/directory is masked using bind mount or tmpfs
   - Otherwise: The file/directory is replaced using bind mount
6. All operations are logged to `/data/adb/replacer.log`

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
2. Verify `service.sh` has execute permissions
3. Check for syntax errors in CSV files

## License

This project is open source. Feel free to use, modify, and distribute.

## Credits

Created by cyanmint for KernelSU.