#!/bin/bash

# Ask for the WARP license key
read -p "Enter your WARP license key: " LICENSE_KEY

# Download wgcf binary
echo "Downloading wgcf binary..."
wget https://github.com/ViRb3/wgcf/releases/download/v2.2.22/wgcf_2.2.22_linux_amd64 -O /usr/bin/wgcf
chmod +x /usr/bin/wgcf

# Register and generate initial wgcf config
echo "Registering wgcf..."
wgcf register
wgcf generate

# Update wgcf-account.toml with the provided license key
echo "Adding WARP license key to wgcf-account.toml..."
sed -i "s/^license_key =.*/license_key = '$LICENSE_KEY'/" wgcf-account.toml

# Update wgcf with the license key applied and regenerate the profile
echo "Updating wgcf with new settings..."
wgcf update
wgcf generate

# Install necessary packages
echo "Installing required packages..."
sudo apt install wireguard

# Modify the wgcf-profile.conf to disable table setting
echo "Modifying wgcf-profile.conf..."
sed -i '/\[Interface\]/a Table = off' wgcf-profile.conf

# Create the WireGuard directory if it doesn't exist
echo "Ensuring /etc/wireguard directory exists..."
sudo mkdir -p /etc/wireguard

# Move the profile to the WireGuard directory
echo "Moving wgcf-profile.conf to /etc/wireguard/warp.conf..."
sudo mv wgcf-profile.conf /etc/wireguard/warp.conf

# Enable and start the WARP interface
echo "Enabling and starting WARP..."
sudo systemctl enable --now wg-quick@warp

echo "Setup completed successfully!"
