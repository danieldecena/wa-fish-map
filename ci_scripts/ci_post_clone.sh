#!/bin/zsh
# ci_post_clone.sh - Runs after Xcode Cloud clones the repository.

set -euo pipefail

echo "=== Xcode Cloud Post-Clone Setup ==="
echo "Xcode Version in Use:"
xcodebuild -version

echo "Checking iOS SDKs..."
xcodebuild -showsdks

# WAFishMap requires Xcode 26+ / iOS 26+ SDK due to glassEffect
# Note: Ensure the workflow in App Store Connect is configured 
# to use the latest Xcode version (Xcode 16 Beta / Xcode 26+ equivalent)

echo "=== Post-Clone Setup Complete ==="
