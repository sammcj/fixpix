#!/bin/bash

# Function to check current scaling settings for an app
check_scaling() {
  local bundle_id=$1
  local container_path
  container_path=$(find_container_path "$bundle_id")
  local pref_domain="$bundle_id"

  if [ -n "$container_path" ]; then
    pref_domain="$container_path/Data/Library/Preferences/$bundle_id.plist"
  fi

  # Check if the pref domain exists
  if [ ! -f "$pref_domain" ]; then
    echo "No preferences found for $bundle_id"
    echo "Tried looking in: $pref_domain"
    echo "Status: Using default scaling"
    return
  fi

  # Read the current scaling factor
  local scale_factor last_window_scale
  scale_factor=$(defaults read "$pref_domain" "iOSMacScaleFactor" 2>/dev/null)
  last_window_scale=$(defaults read "$pref_domain" "UINSLastUsedWindowScaleFactor" 2>/dev/null)

  echo "Current settings for $bundle_id:"
  echo "Preference file: $pref_domain"

  if [ -n "$scale_factor" ]; then
    if [ "$scale_factor" = "1" ]; then
      echo "Status: Native scaling enabled (iOSMacScaleFactor = 1)"
    else
      echo "Status: Custom scaling (iOSMacScaleFactor = $scale_factor)"
    fi
  else
    echo "Status: Using default scaling (no iOSMacScaleFactor set)"
  fi

  if [ -n "$last_window_scale" ]; then
    echo "Last used window scale: $last_window_scale"
  fi
}

# Function to get bundle info, handling both wrapped and regular apps
get_bundle_info() {
  local app_path="$1"
  local bundle_id=""
  local app_name=""

  # Check if this is a wrapped app
  if [ -L "$app_path/WrappedBundle" ] && [ -d "$app_path/Wrapper" ]; then
    # Get the actual app bundle inside Wrapper
    local wrapped_app
    wrapped_app=$(find "$app_path/Wrapper" -name "*.app" -maxdepth 1)
    if [ -n "$wrapped_app" ]; then
      bundle_id=$(defaults read "$wrapped_app/Info.plist" CFBundleIdentifier 2>/dev/null)
      app_name=$(defaults read "$wrapped_app/Info.plist" CFBundleDisplayName 2>/dev/null)
      if [ -z "$app_name" ]; then
        app_name=$(defaults read "$wrapped_app/Info.plist" CFBundleName 2>/dev/null)
      fi
    fi
  else
    # Regular app bundle
    bundle_id=$(defaults read "$app_path/Contents/Info.plist" CFBundleIdentifier 2>/dev/null)
    app_name=$(defaults read "$app_path/Contents/Info.plist" CFBundleDisplayName 2>/dev/null)
    if [ -z "$app_name" ]; then
      app_name=$(defaults read "$app_path/Contents/Info.plist" CFBundleName 2>/dev/null)
    fi
  fi

  echo "$bundle_id:$app_name"
}

# Function to check if a bundle is an iOS/iPadOS app
is_ios_app() {
  local app_path="$1"
  local info_plist="$app_path/Contents/Info.plist"

  # Check for WrappedBundle/Wrapper structure first
  if [ -L "$app_path/WrappedBundle" ] && [ -d "$app_path/Wrapper" ]; then
    return 0 # This is an iOS app
  fi

  # If no WrappedBundle/Wrapper, check Info.plist
  if [ ! -f "$info_plist" ]; then
    return 1
  fi

  # Check for iOS-specific keys in Info.plist
  local is_ios=0

  # Check LSRequiresIPhoneOS
  if defaults read "$info_plist" LSRequiresIPhoneOS 2>/dev/null; then
    is_ios=1
  fi

  # Check DTPlatformName for iphoneos
  if [ "$is_ios" -eq 0 ]; then
    local platform
    platform=$(defaults read "$info_plist" DTPlatformName 2>/dev/null)
    if [[ "$platform" == *"iphoneos"* ]]; then
      is_ios=1
    fi
  fi

  # Check UIDeviceFamily (1 = iPhone, 2 = iPad)
  if [ "$is_ios" -eq 0 ]; then
    local device_family
    device_family=$(defaults read "$info_plist" UIDeviceFamily 2>/dev/null)
    if [[ "$device_family" == *"1"* ]] || [[ "$device_family" == *"2"* ]]; then
      is_ios=1
    fi
  fi

  return $((!is_ios))
}

# Function to find the actual container path for an app
find_container_path() {
  local bundle_id=$1
  local container_path=""

  # First check direct bundle ID path
  if [ -d "$HOME/Library/Containers/$bundle_id" ]; then
    container_path="$HOME/Library/Containers/$bundle_id"
  else
    # Search for UUID-based container using metadata
    local containers_dir="$HOME/Library/Containers"
    if [ -d "$containers_dir" ]; then
      while IFS= read -r container; do
        if [ -f "$container/.com.apple.containermanagerd.metadata.plist" ]; then
          local metadata_identifier
          metadata_identifier=$(defaults read "$container/.com.apple.containermanagerd.metadata.plist" "MCMMetadataIdentifier" 2>/dev/null)
          if [ "$metadata_identifier" = "$bundle_id" ]; then
            container_path="$container"
            break
          fi
        fi
      done < <(find "$containers_dir" -type d -maxdepth 1)
    fi
  fi

  echo "$container_path"
}

# Function to list all iOS/iPadOS apps
list_ios_apps() {
  local search_paths=("/Applications" "$HOME/Applications")

  for search_path in "${search_paths[@]}"; do
    if [ ! -d "$search_path" ]; then
      continue
    fi

    echo "Searching in $search_path..."

    # Find all .app bundles
    while IFS= read -r app_path; do
      if is_ios_app "$app_path"; then
        local bundle_info app_name bundle_id
        bundle_info=$(get_bundle_info "$app_path")
        bundle_id=${bundle_info%%:*}
        app_name=${bundle_info#*:}

        echo "Found iOS app: $app_name ($bundle_id)"
        echo "Path: $app_path"
        # Check if it's a wrapped app
        if [ -L "$app_path/WrappedBundle" ] && [ -d "$app_path/Wrapper" ]; then
          echo "Type: Wrapped iOS app"
        fi
        echo "---"
      fi
    done < <(find "$search_path" -name "*.app" -maxdepth 2)
  done
}

# Function to search for apps with matching bundle IDs
search_bundle_id() {
  local search_string=$1
  local search_paths=("/Applications" "$HOME/Applications")

  for search_path in "${search_paths[@]}"; do
    if [ ! -d "$search_path" ]; then
      continue
    fi

    # Find all .app bundles
    while IFS= read -r app_path; do
      if is_ios_app "$app_path"; then
        local bundle_info app_name bundle_id
        bundle_info=$(get_bundle_info "$app_path")
        bundle_id=${bundle_info%%:*}
        app_name=${bundle_info#*:}

        if [[ "$bundle_id" == *"$search_string"* ]] || [[ "$app_name" == *"$search_string"* ]]; then
          echo "Found iOS app: $app_name ($bundle_id)"
          echo "Path: $app_path"
          # Check if it's a wrapped app
          if [ -L "$app_path/WrappedBundle" ] && [ -d "$app_path/Wrapper" ]; then
            echo "Type: Wrapped iOS app"
          fi
          echo "---"
        fi
      fi
    done < <(find "$search_path" -name "*.app" -maxdepth 2)
  done
}

# Function to enable native scaling for an app
enable_native_scaling() {
  local bundle_id=$1
  local container_path
  container_path=$(find_container_path "$bundle_id")
  local pref_domain="$bundle_id"

  if [ -n "$container_path" ]; then
    pref_domain="$container_path/Data/Library/Preferences/$bundle_id.plist"
  fi

  # Set scaling to native (1.0)
  defaults write "$pref_domain" "iOSMacScaleFactor" -float 1.0
  # Clear the last used window scale factor
  defaults delete "$pref_domain" "UINSLastUsedWindowScaleFactor" 2>/dev/null

  echo "Enabled native scaling for $bundle_id"
  echo "Preference file: $pref_domain"
}

# Function to disable native scaling (return to default)
disable_native_scaling() {
  local bundle_id=$1
  local pref_domain="$bundle_id"

  local container_path="$HOME/Library/Containers/$bundle_id"
  if [ -d "$container_path" ]; then
    pref_domain="$container_path/Data/Library/Preferences/$bundle_id.plist"
  fi

  # Remove the scaling factor to return to default
  defaults delete "$pref_domain" "iOSMacScaleFactor" 2>/dev/null
  defaults delete "$pref_domain" "UINSLastUsedWindowScaleFactor" 2>/dev/null

  echo "Disabled native scaling for $bundle_id"
}

# Main command processing
case "$1" in
"list")
  list_ios_apps
  ;;
"search")
  if [ -z "$2" ]; then
    echo "Error: Search string required"
    echo "Usage: $0 search <search_string>"
    exit 1
  fi
  search_bundle_id "$2"
  ;;
"enable")
  if [ -z "$2" ]; then
    echo "Error: Bundle ID required"
    echo "Usage: $0 enable <bundle_id>"
    exit 1
  fi
  enable_native_scaling "$2"
  ;;
"disable")
  if [ -z "$2" ]; then
    echo "Error: Bundle ID required"
    echo "Usage: $0 disable <bundle_id>"
    exit 1
  fi
  disable_native_scaling "$2"
  ;;
"check")
  if [ -z "$2" ]; then
    echo "Error: Bundle ID required"
    echo "Usage: $0 check <bundle_id>"
    exit 1
  fi
  check_scaling "$2"
  ;;
*)
  echo "Usage: $0 <command> [args]"
  echo "Commands:"
  echo "  list                     List all iOS/iPadOS apps"
  echo "  search <search_string>   Search for apps with matching bundle IDs"
  echo "  check <bundle_id>        Check current scaling settings"
  echo "  enable <bundle_id>       Enable native scaling for an app"
  echo "  disable <bundle_id>      Disable native scaling for an app"
  echo ""
  echo "Example:"
  echo "  $0 list"
  echo "  $0 search myapp"
  echo "  $0 check com.example.myapp"
  echo "  $0 enable com.example.myapp"
  ;;
esac
