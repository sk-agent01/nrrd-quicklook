#!/bin/bash
# Create a Finder Quick Action (Service) for NRRD preview
# This allows right-click -> Quick Actions -> Preview NRRD

SERVICE_NAME="Preview NRRD"
SERVICE_DIR="$HOME/Library/Services/${SERVICE_NAME}.workflow"
SCRIPT_PATH="$HOME/.local/bin/nrrd-preview"

# Check if preview script exists
if [ ! -f "$SCRIPT_PATH" ]; then
    echo "Error: nrrd-preview not found. Run install_qlgenerator.sh first."
    exit 1
fi

# Create workflow directory
mkdir -p "$SERVICE_DIR/Contents"

# Create Info.plist
cat > "$SERVICE_DIR/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSServices</key>
    <array>
        <dict>
            <key>NSMenuItem</key>
            <dict>
                <key>default</key>
                <string>Preview NRRD</string>
            </dict>
            <key>NSMessage</key>
            <string>runWorkflowAsService</string>
            <key>NSSendFileTypes</key>
            <array>
                <string>public.data</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
EOF

# Create document.wflow (Automator workflow)
cat > "$SERVICE_DIR/Contents/document.wflow" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>AMApplicationBuild</key>
    <string>523</string>
    <key>AMApplicationVersion</key>
    <string>2.10</string>
    <key>AMDocumentVersion</key>
    <string>2</string>
    <key>actions</key>
    <array>
        <dict>
            <key>action</key>
            <dict>
                <key>AMActionVersion</key>
                <string>2.0.3</string>
                <key>AMApplication</key>
                <array>
                    <string>Automator</string>
                </array>
                <key>AMBundleIdentifier</key>
                <string>com.apple.RunShellScript</string>
                <key>AMName</key>
                <string>Run Shell Script</string>
                <key>AMParameters</key>
                <dict>
                    <key>COMMAND_STRING</key>
                    <string>for f in "\$@"; do
    if [[ "\$f" == *.nrrd ]] || [[ "\$f" == *.nhdr ]]; then
        output="/tmp/nrrd_preview_\$\$.jpg"
        $SCRIPT_PATH "\$f" -o "\$output" 2>/dev/null
        if [ -f "\$output" ]; then
            open "\$output"
        fi
    fi
done</string>
                    <key>CheckedForUserDefaultShell</key>
                    <true/>
                    <key>inputMethod</key>
                    <integer>1</integer>
                    <key>shell</key>
                    <string>/bin/bash</string>
                    <key>source</key>
                    <string></string>
                </dict>
            </dict>
            <key>isViewVisible</key>
            <integer>1</integer>
        </dict>
    </array>
    <key>connectors</key>
    <dict/>
    <key>workflowMetaData</key>
    <dict>
        <key>workflowTypeIdentifier</key>
        <string>com.apple.Automator.servicesMenu</string>
    </dict>
</dict>
</plist>
EOF

echo "Created Finder Quick Action: $SERVICE_NAME"
echo ""
echo "Usage:"
echo "  1. Right-click on a .nrrd file in Finder"
echo "  2. Select: Quick Actions -> Preview NRRD"
echo "  3. Preview image opens in Preview.app"
