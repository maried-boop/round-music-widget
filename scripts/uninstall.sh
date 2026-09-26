#!/bin/zsh

set -euo pipefail

app_name="Round Music Widget"
launch_agent_label="com.mariedrouvin.round-music-widget.music-watcher"
install_directory="${ROUND_MUSIC_WIDGET_INSTALL_DIR:-$HOME/Applications}"
launch_agents_directory="${ROUND_MUSIC_WIDGET_LAUNCH_AGENTS_DIR:-$HOME/Library/LaunchAgents}"
installed_app="$install_directory/$app_name.app"
launch_agent_path="$launch_agents_directory/$launch_agent_label.plist"
launch_domain="gui/$(/usr/bin/id -u)"

if [[ "${ROUND_MUSIC_WIDGET_SKIP_LAUNCH:-0}" != "1" && -f "$launch_agent_path" ]]; then
    /bin/launchctl bootout "$launch_domain" "$launch_agent_path" >/dev/null 2>&1 || true
fi

/usr/bin/pkill -x RoundMusicWidget >/dev/null 2>&1 || true

if [[ -f "$launch_agent_path" ]]; then
    /bin/rm -f "$launch_agent_path"
fi

if [[ -d "$installed_app" ]]; then
    /bin/rm -rf "$installed_app"
fi

echo "Uninstalled Round Music Widget"
