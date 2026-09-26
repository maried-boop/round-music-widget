#!/bin/zsh

set -euo pipefail

script_directory="${0:A:h}"
project_root="${script_directory:h}"
app_name="Round Music Widget"
launch_agent_label="com.mariedrouvin.round-music-widget.music-watcher"
install_directory="${ROUND_MUSIC_WIDGET_INSTALL_DIR:-$HOME/Applications}"
launch_agents_directory="${ROUND_MUSIC_WIDGET_LAUNCH_AGENTS_DIR:-$HOME/Library/LaunchAgents}"
installed_app="$install_directory/$app_name.app"
watcher_path="$installed_app/Contents/Helpers/MusicLifecycleWatcher"
launch_agent_path="$launch_agents_directory/$launch_agent_label.plist"
launch_agent_template="$project_root/launchd/$launch_agent_label.plist"
launch_domain="gui/$(/usr/bin/id -u)"

if ! /usr/bin/xcrun --find swift >/dev/null 2>&1; then
    echo "Swift is missing. Install Apple's Command Line Tools with: xcode-select --install" >&2
    exit 1
fi

"$project_root/scripts/package-app.sh" >/dev/null

/bin/mkdir -p "$install_directory" "$launch_agents_directory"

if [[ -f "$launch_agent_path" && "${ROUND_MUSIC_WIDGET_SKIP_LAUNCH:-0}" != "1" ]]; then
    /bin/launchctl bootout "$launch_domain" "$launch_agent_path" >/dev/null 2>&1 || true
fi

if [[ -d "$installed_app" ]]; then
    /usr/bin/pkill -x RoundMusicWidget >/dev/null 2>&1 || true
    /bin/rm -rf "$installed_app"
fi

/usr/bin/ditto "$project_root/dist/$app_name.app" "$installed_app"

temporary_plist="$(/usr/bin/mktemp "$launch_agents_directory/.round-music-widget.XXXXXX")"
/bin/cp "$launch_agent_template" "$temporary_plist"
/usr/bin/plutil \
    -replace ProgramArguments.0 \
    -string "$watcher_path" \
    "$temporary_plist"
/usr/bin/plutil -lint "$temporary_plist" >/dev/null
/bin/chmod 644 "$temporary_plist"
/bin/mv -f "$temporary_plist" "$launch_agent_path"

if [[ "${ROUND_MUSIC_WIDGET_SKIP_LAUNCH:-0}" != "1" ]]; then
    /bin/launchctl bootstrap "$launch_domain" "$launch_agent_path"
fi

echo "Installed $installed_app"
echo "Open Apple Music to show the widget. macOS may ask for permission to control Music."
