#!/bin/bash

update_version() {
    # Parameters: new version and path to Info.plist
    local NEW_VERSION=$1
    local CONFIG_PATH=$2

    # Check if both parameters are provided
    if [ -z "$CONFIG_PATH" ]; then
        echo "Usage: update_version [<new-version>] <path-to-config-file>"
        return 1
    fi

    # Check if config file exists
    if [ ! -f "$CONFIG_PATH" ]; then
        echo "Config file not found at $CONFIG_PATH"
        return 1
    fi

    # Read the current build number
    local CURRENT_BUILD=$(grep 'CURRENT_PROJECT_VERSION' "$CONFIG_PATH" | awk -F= '{print $2}' | tr -d ' ')

    # Increment the build number
    local NEW_BUILD=$(($CURRENT_BUILD + 1))

    # Updating the xcconfig file with the new version
    sed -i '' "s/CURRENT_PROJECT_VERSION = $CURRENT_BUILD/CURRENT_PROJECT_VERSION = $NEW_BUILD/g" "$CONFIG_PATH"

    # Updating the xcconfig file with the new marketing version
    if [[ -n "$NEW_VERSION" ]]; then
        sed -i '' "s/^MARKETING_VERSION = .*/MARKETING_VERSION = $NEW_VERSION/" "$CONFIG_PATH"
    fi
    echo "Version updated to $NEW_VERSION with build number $NEW_BUILD in $CONFIG_PATH"
}


CONFIG_PATH="Email2/versions.xcconfig"

# Check if a version number is provided
if [ "$#" -ne 1 ]; then
    update_version "" $CONFIG_PATH
else
    # New version number (passed as a parameter)
    update_version $1 $CONFIG_PATH
fi
