# Replacer - KernelSU Module

A KernelSU module that automatically replaces or deletes system files based on CSV configuration files.

## Features

- 📝 Simple CSV-based configuration
- 🔄 Automatic file and directory replacement
- 🗑️ File and directory deletion support
- 📂 Support for both files and directories
- 🔧 Variable substitution for module directory
- 📊 Multiple configuration files support (processed in sorted order)
- 📋 Detailed logging

## Installation

1. Download the module ZIP file
2. Install via KernelSU Manager
3. Reboot your device

## Configuration

Configuration files are placed in `/data/adb/replacer.d/` and must have a `.csv` extension.

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

File: `/data/adb/replacer.d/10-replace-font.csv`
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
3. **Paths ending with `/`**: Treated as directories
4. **Paths without trailing `/`**: Treated as files
5. **Variable substitution**:
   - `${mod_dir}` or `${MODDIR}` will be replaced with the module directory path
   - Example: `/data/adb/modules/replacer`
6. **Deletion marker**: Use `_` (underscore) as the replacement path to delete/mask a file or directory

## Directory Structure

```
/data/adb/modules/replacer/
├── module.prop          # Module metadata
├── service.sh           # Main script (runs on boot)
├── customize.sh         # Installation script
└── files/               # Your replacement files go here
    └── ...

/data/adb/replacer.d/    # Configuration directory
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
3. All `.csv` files in `/data/adb/replacer.d/` are processed in sorted order
4. For each line in the CSV:
   - If replacement is `_`: The file/directory is masked using bind mount to `/dev/null`
   - Otherwise: The file/directory is replaced using bind mount
5. All operations are logged to `/data/adb/replacer.log`

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