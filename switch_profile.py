#!/usr/bin/env python3

import iterm2
import sys

async def main(connection):
    if len(sys.argv) < 3:
        print("Usage: switch_profile.py <profile_name> <action>")
        sys.exit(1)

    profile_name = sys.argv[1]
    action = sys.argv[2]
    profile_name_default = "Default"

    app = await iterm2.async_get_app(connection)
    window = app.current_terminal_window
    if window is not None:
        session = window.current_tab.current_session
        profiles = await iterm2.Profile.async_get(connection)
        profile = next((p for p in profiles if p.name == profile_name), None)

        if profile:
            if action == "start":
                await session.async_set_profile(profile)
            elif action == "end":
                default_profile = next((p for p in profiles if p.name == profile_name_default), None)
                if default_profile:
                    await session.async_set_profile(default_profile)
        else:
            print(f"Profile '{profile_name}' not found.")
    else:
        print("No current window")

if __name__ == "__main__":
    iterm2.run_until_complete(main)
