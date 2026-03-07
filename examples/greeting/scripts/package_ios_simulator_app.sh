#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 4 ]; then
  echo "usage: $0 <products-dir> <executable-name> <bundle-id> <minimum-os-version>" >&2
  exit 64
fi

products_dir=$1
executable_name=$2
bundle_id=$3
minimum_os_version=$4

executable_path="$products_dir/$executable_name"
app_dir="$products_dir/$executable_name.app"

if [ ! -f "$executable_path" ]; then
  echo "missing executable: $executable_path" >&2
  exit 1
fi

rm -rf "$app_dir"
mkdir -p "$app_dir"
cp "$executable_path" "$app_dir/$executable_name"

shopt -s nullglob
for bundle in "$products_dir"/*.bundle; do
  cp -R "$bundle" "$app_dir/"
done

cat > "$app_dir/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>$executable_name</string>
  <key>CFBundleExecutable</key>
  <string>$executable_name</string>
  <key>CFBundleIdentifier</key>
  <string>$bundle_id</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$executable_name</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSRequiresIPhoneOS</key>
  <true/>
  <key>MinimumOSVersion</key>
  <string>$minimum_os_version</string>
  <key>UIDeviceFamily</key>
  <array>
    <integer>1</integer>
    <integer>2</integer>
  </array>
  <key>UILaunchScreen</key>
  <dict/>
  <key>UISupportedInterfaceOrientations</key>
  <array>
    <string>UIInterfaceOrientationPortrait</string>
    <string>UIInterfaceOrientationLandscapeLeft</string>
    <string>UIInterfaceOrientationLandscapeRight</string>
  </array>
</dict>
</plist>
EOF

codesign --force --sign - "$app_dir" >/dev/null
