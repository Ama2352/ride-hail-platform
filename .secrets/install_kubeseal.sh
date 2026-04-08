#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "--- 🛡️ Starting Kubeseal CLI installation ---"

# 1. Fetch the latest version tag from GitHub API
echo "🔍 Checking for the latest version..."
KUBESEAL_VERSION=$(curl -s https://api.github.com/repos/bitnami-labs/sealed-secrets/releases/latest | grep tag_name | cut -d '"' -f 4 | sed 's/v//')

# Check if version retrieval was successful
if [ -z "$KUBESEAL_VERSION" ]; then
    echo "❌ Failed to fetch version info. Please check your internet connection!"
    exit 1
fi

echo "✅ Found version: v${KUBESEAL_VERSION}"

# 2. Create a temporary directory for download
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

# 3. Download the linux-amd64 binary package
echo "📥 Downloading kubeseal-linux-amd64..."
wget -q "https://github.com/bitnami-labs/sealed-secrets/releases/download/v${KUBESEAL_VERSION}/kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz"

# 4. Extract the downloaded archive
echo "📦 Extracting archive..."
tar -xzf "kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz"

# 5. Install the binary to /usr/local/bin (requires sudo privileges)
echo "🚀 Installing to system path (requires sudo)..."
sudo install -m 755 kubeseal /usr/local/bin/kubeseal

# 6. Clean up temporary files
rm -rf "$TEMP_DIR"

# 7. Verify the installation
echo "--- 🎉 Installation complete! ---"
kubeseal --version