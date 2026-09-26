#!/bin/zsh

set -euo pipefail

script_dir="${0:A:h}"
project_root="${script_dir:h}"
app_name="Round Music Widget"
executable_name="RoundMusicWidget"
watcher_executable_name="MusicLifecycleWatcher"
app_bundle="$project_root/dist/$app_name.app"
contents_dir="$app_bundle/Contents"

swift build \
    --package-path "$project_root" \
    --configuration release

binary_directory="$(
    swift build \
        --package-path "$project_root" \
        --configuration release \
        --show-bin-path
)"

if [[ -d "$app_bundle" ]]; then
    /bin/rm -rf "$app_bundle"
fi

/bin/mkdir -p \
    "$contents_dir/MacOS" \
    "$contents_dir/Helpers" \
    "$contents_dir/Resources"

/bin/cp \
    "$binary_directory/$executable_name" \
    "$contents_dir/MacOS/$executable_name"

/bin/cp \
    "$binary_directory/$watcher_executable_name" \
    "$contents_dir/Helpers/$watcher_executable_name"

/bin/cp \
    "$project_root/Info.plist" \
    "$contents_dir/Info.plist"

/usr/bin/codesign \
    --force \
    --sign - \
    "$contents_dir/Helpers/$watcher_executable_name"

/usr/bin/codesign \
    --force \
    --sign - \
    "$contents_dir/MacOS/$executable_name"

/usr/bin/codesign \
    --force \
    --sign - \
    "$app_bundle"

/usr/bin/codesign \
    --verify \
    --deep \
    --strict \
    "$app_bundle"

echo "$app_bundle"
