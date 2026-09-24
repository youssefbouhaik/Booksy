#!/bin/bash
set -e

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="Booksy.app"
SYS_APP_PATH="/Applications/$APP_NAME"
USER_APP_PATH="$HOME/Applications/$APP_NAME"
DESKTOP_PATH="$HOME/Desktop/$APP_NAME"
WORKING_DIR_APP="$HOME/Desktop/Working_dir_Booksy/$APP_NAME"
APP_PATH="$SYS_APP_PATH"
ICON_SOURCE="$HOME/.books1_cache/icons/AppIcon_Coral.icns"

echo "==> Compiling Booksy native macOS binary..."
cd "$SOURCE_DIR"
swiftc -parse-as-library $(find "$SOURCE_DIR/Books/Books" -name "*.swift") -o "$SOURCE_DIR/Booksy_bin"

echo "==> Preparing $APP_NAME bundle..."
rm -rf "$APP_PATH" "$DESKTOP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS"
mkdir -p "$APP_PATH/Contents/Resources/scripts"

cp "$SOURCE_DIR/Booksy_bin" "$APP_PATH/Contents/MacOS/Booksy"
chmod +x "$APP_PATH/Contents/MacOS/Booksy"

# Bundle core aperture reader and speech scripts if available
if [ -d "$HOME/aperture-epub-reader" ]; then
    cp -f "$HOME/aperture-epub-reader"/*.py "$APP_PATH/Contents/Resources/scripts/" 2>/dev/null || true
fi

if [ -f "$ICON_SOURCE" ]; then
    cp "$ICON_SOURCE" "$APP_PATH/Contents/Resources/AppIcon.icns"
fi

cat << 'PLIST' > "$APP_PATH/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Booksy</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon.icns</string>
    <key>CFBundleIdentifier</key>
    <string>com.booksy.app</string>
    <key>CFBundleName</key>
    <string>Booksy</string>
    <key>CFBundleDisplayName</key>
    <string>Booksy</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    
    <!-- EPUB File Association for Open With -->
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key>
            <string>Electronic Publication (EPUB)</string>
            <key>CFBundleTypeRole</key>
            <string>Viewer</string>
            <key>LSHandlerRank</key>
            <string>Alternate</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>org.idpf.epub-container</string>
                <string>public.data</string>
                <string>org.idpf.epub</string>
            </array>
            <key>CFBundleTypeExtensions</key>
            <array>
                <string>epub</string>
                <string>EPUB</string>
            </array>
        </dict>
        <dict>
            <key>CFBundleTypeName</key>
            <string>Portable Document Format (PDF)</string>
            <key>CFBundleTypeRole</key>
            <string>Viewer</string>
            <key>LSHandlerRank</key>
            <string>Alternate</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>com.adobe.pdf</string>
            </array>
            <key>CFBundleTypeExtensions</key>
            <array>
                <string>pdf</string>
                <string>PDF</string>
            </array>
        </dict>
    </array>
    
    <!-- UTI Definitions -->
    <key>UTImportedTypeDeclarations</key>
    <array>
        <dict>
            <key>UTTypeIdentifier</key>
            <string>org.idpf.epub-container</string>
            <key>UTTypeDescription</key>
            <string>EPUB Electronic Publication</string>
            <key>UTTypeConformsTo</key>
            <array>
                <string>public.data</string>
                <string>public.composite-content</string>
            </array>
            <key>UTTypeTagSpecification</key>
            <dict>
                <key>public.filename-extension</key>
                <array>
                    <string>epub</string>
                    <string>EPUB</string>
                </array>
                <key>public.mime-type</key>
                <array>
                    <string>application/epub+zip</string>
                </array>
            </dict>
        </dict>
    </array>
    
    <!-- Privacy Descriptions for Persistent Folder Access -->
    <key>NSDownloadsFolderUsageDescription</key>
    <string>Booksy needs access to your Downloads folder to read and open EPUB books stored there.</string>
    <key>NSDocumentsFolderUsageDescription</key>
    <string>Booksy needs access to your Documents folder to open your book library.</string>
    <key>NSDesktopFolderUsageDescription</key>
    <string>Booksy needs access to your Desktop to open book files.</string>
</dict>
</plist>
PLIST

dot_clean "$APP_PATH"
find "$APP_PATH" -exec xattr -c {} + 2>/dev/null || true
codesign -s - --force --deep "$APP_PATH"

echo "==> Installing to /Applications/Booksy.app..."
rm -rf "$USER_APP_PATH" "$DESKTOP_PATH" "$WORKING_DIR_APP"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u "$USER_APP_PATH" 2>/dev/null || true
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u "$DESKTOP_PATH" 2>/dev/null || true
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u "$WORKING_DIR_APP" 2>/dev/null || true

/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP_PATH" 2>/dev/null || true
touch "$APP_PATH"

echo "==> Setting Finder full-bleed custom icon via NSWorkspace..."
swift - << 'SWIFT'
import Cocoa

let iconPath = ("~/.books1_cache/icons/AppIcon_Coral.icns" as NSString).expandingTildeInPath
if let img = NSImage(contentsOfFile: iconPath) {
    let p = "/Applications/Booksy.app"
    if FileManager.default.fileExists(atPath: p) {
        let res = NSWorkspace.shared.setIcon(img, forFile: p, options: [])
        print("Set Finder custom icon for \(p): \(res)")
    }
}
SWIFT

echo "==> Booksy.app built and installed to /Applications/Booksy.app successfully!"
