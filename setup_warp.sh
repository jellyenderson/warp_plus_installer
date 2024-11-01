#!/bin/bash

# Copyright 2024, Jellyenderson

# Menu function
show_menu() {
  echo "============================"
  echo "   WARP Setup Menu"
  echo "============================"
  echo "1. Setup WARP"
  echo "2. Update WARP Configuration"
  echo "3. Quit"
  echo "============================"
  echo "Copyright 2024, Jellyenderson"
  echo "============================"
}

# Function to setup WARP
setup_warp() {
  # Ask for the WARP license key
  read -p "Enter your WARP license key: " LICENSE_KEY
  if [ -z "$LICENSE_KEY" ]; then
    echo "Error: WARP license key cannot be empty."
    return
  fi

  # Download wgcf binary
  echo "Downloading wgcf binary..."
  wget -q --show-progress https://github.com/ViRb3/wgcf/releases/download/v2.2.22/wgcf_2.2.22_linux_amd64 -O /usr/bin/wgcf
  if [ $? -ne 0 ]; then
    echo "Error: Failed to download wgcf binary."
    return
  fi
  chmod +x /usr/bin/wgcf

  # Register and generate initial wgcf config
  echo "Registering wgcf..."
  yes | wgcf register
  if [ $? -ne 0 ]; then
    echo "Error: Failed to register wgcf."
    return
  fi

  wgcf generate
  if [ $? -ne 0 ]; then
    echo "Error: Failed to generate wgcf profile."
    return
  fi

  # Update wgcf-account.toml with the provided license key
  echo "Adding WARP license key to wgcf-account.toml..."
  sed -i "s/^license_key =.*/license_key = '$LICENSE_KEY'/" wgcf-account.toml

  # Update wgcf with the license key applied and regenerate the profile
  echo "Updating wgcf with new settings..."
  wgcf update
  wgcf generate

  # Determine Ubuntu version
  UBUNTU_VERSION=$(lsb_release -rs | cut -d '.' -f1)

  # Install necessary packages based on Ubuntu version
  echo "Installing required packages..."
  if [ "$UBUNTU_VERSION" -lt 24 ]; then
    echo "Detected Ubuntu version less than 24, installing wireguard-dkms, wireguard-tools, and resolvconf..."
    sudo apt update && sudo apt install -y wireguard-dkms wireguard-tools resolvconf
  else
    echo "Detected Ubuntu version 24 or later, installing wireguard..."
    sudo apt update && sudo apt install -y wireguard
  fi

  if [ $? -ne 0 ]; then
    echo "Error: Failed to install required packages."
    return
  fi

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
  if [ $? -ne 0 ]; then
    echo "Error: Failed to enable and start the WARP interface."
    return
  fi

  echo "Setup completed successfully!"
}

# Function to update WARP configuration
update_warp_config() {
  # Update wgcf-account.toml with the new license key
  read -p "Enter your new WARP license key: " LICENSE_KEY
  if [ -z "$LICENSE_KEY" ]; then
    echo "Error: WARP license key cannot be empty."
    return
  fi

  echo "Updating WARP license key..."
  sed -i "s/^license_key =.*/license_key = '$LICENSE_KEY'/" wgcf-account.toml

  # Update wgcf and regenerate profile
  echo "Updating wgcf with new settings..."
  wgcf update
  wgcf generate

  # Move the updated profile to the WireGuard directory
  echo "Moving updated wgcf-profile.conf to /etc/wireguard/warp.conf..."
  sudo mv wgcf-profile.conf /etc/wireguard/warp.conf

  # Restart the WARP interface to apply changes
  echo "Restarting WARP interface..."
  sudo systemctl restart wg-quick@warp
  if [ $? -ne 0 ]; then
    echo "Error: Failed to restart the WARP interface."
    return
  fi

  echo "WARP configuration updated successfully!"
}

# Main loop
while true; do
  show_menu
  read -p "Enter your choice [1-3]: " choice
  case $choice in
    1)
      setup_warp
      ;;
    2)
      update_warp_config
      ;;
    3)
      echo "Exiting... Goodbye!"
      exit 0
      ;;
    *)
      echo "Invalid option, please try again."
      ;;
  esac
done
