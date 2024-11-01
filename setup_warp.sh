#!/bin/bash

# Copyright 2024, Jellyenderson

# Menu function
show_menu() {
  echo -e "\e[1;34m============================\e[0m"
  echo -e "\e[1;33m   WARP Setup Menu\e[0m"
  echo -e "\e[1;34m============================\e[0m"
  echo -e "\e[1;32m1. Setup WARP\e[0m"
  echo -e "\e[1;32m2. Update WARP Configuration\e[0m"
  if systemctl is-active --quiet wg-quick@warp; then
    echo -e "\e[1;32m3. Uninstall WARP\e[0m"
  fi
  echo -e "\e[1;32m4. Quit\e[0m"
  echo -e "\e[1;34m============================\e[0m"
  echo -e "\e[1;35mCopyright 2024, Jellyenderson\e[0m"
  echo -e "\e[1;34m============================\e[0m"
}

# Function to setup WARP
setup_warp() {
  # Remove any existing configuration before starting
  echo -e "\e[1;34mRemoving any existing WARP configuration...\e[0m"
  rm -f wgcf-account.toml
  rm -f wgcf-profile.conf
  sudo rm -f /etc/wireguard/warp.conf

  # Ask if the user has a WARP license key
  read -p "Do you have a WARP+ license key? (y/n): " HAS_LICENSE_KEY
  if [[ "$HAS_LICENSE_KEY" == "y" || "$HAS_LICENSE_KEY" == "Y" ]]; then
    read -p "Enter your WARP license key: " LICENSE_KEY
    if [ -z "$LICENSE_KEY" ]; then
      echo -e "\e[1;31mError: WARP license key cannot be empty.\e[0m"
      return
    fi
  fi

  # Download wgcf binary
  echo -e "\e[1;34mDownloading wgcf binary...\e[0m"
  wget -q --show-progress https://github.com/ViRb3/wgcf/releases/download/v2.2.22/wgcf_2.2.22_linux_amd64 -O /usr/bin/wgcf
  if [ $? -ne 0 ]; then
    echo -e "\e[1;31mError: Failed to download wgcf binary.\e[0m"
    return
  fi
  chmod +x /usr/bin/wgcf

  # Register and generate initial wgcf config
  echo -e "\e[1;34mRegistering wgcf...\e[0m"
  yes | wgcf register
  if [ $? -ne 0 ]; then
    echo -e "\e[1;31mError: Failed to register wgcf.\e[0m"
    return
  fi

  # Generate the wgcf profile
  echo -e "\e[1;34mGenerating wgcf profile...\e[0m"
  wgcf generate
  if [ $? -ne 0 ]; then
    echo -e "\e[1;31mError: Failed to generate wgcf profile.\e[0m"
    return
  fi

  # Update wgcf-account.toml with the provided license key, if available
  if [[ ! -z "$LICENSE_KEY" ]]; then
    echo -e "\e[1;34mAdding WARP license key to wgcf-account.toml...\e[0m"
    sed -i "s/^license_key =.*/license_key = '$LICENSE_KEY'/" wgcf-account.toml

    # Update wgcf with the license key applied and regenerate the profile
    echo -e "\e[1;34mUpdating wgcf with new settings...\e[0m"
    while true; do
      wgcf update
      wgcf generate

      # Check if the account type is now WARP+
      ACCOUNT_TYPE=$(wgcf status | grep -i "Account type" | awk '{print $NF}')
      if [[ "$ACCOUNT_TYPE" == "Plus" ]]; then
        echo -e "\e[1;32mWARP+ license applied successfully.\e[0m"
        break
      else
        echo -e "\e[1;33mAccount type still free. Retrying update...\e[0m"
      fi
    done
  fi

  # Determine Ubuntu version
  UBUNTU_VERSION=$(lsb_release -rs | cut -d '.' -f1)

  # Install necessary packages based on Ubuntu version
  echo -e "\e[1;34mInstalling required packages...\e[0m"
  if [ "$UBUNTU_VERSION" -lt 24 ]; then
    echo -e "\e[1;33mDetected Ubuntu version less than 24, installing wireguard-dkms, wireguard-tools, and resolvconf...\e[0m"
    sudo apt update && sudo apt install -y wireguard-dkms wireguard-tools resolvconf
  else
    echo -e "\e[1;33mDetected Ubuntu version 24 or later, installing wireguard...\e[0m"
    sudo apt update && sudo apt install -y wireguard
  fi

  if [ $? -ne 0 ]; then
    echo -e "\e[1;31mError: Failed to install required packages.\e[0m"
    return
  fi

  # Modify the wgcf-profile.conf to disable table setting
  echo -e "\e[1;34mModifying wgcf-profile.conf...\e[0m"
  sed -i '/\[Interface\]/a Table = off' wgcf-profile.conf

  # Create the WireGuard directory if it doesn't exist
  echo -e "\e[1;34mEnsuring /etc/wireguard directory exists...\e[0m"
  sudo mkdir -p /etc/wireguard

  # Move the profile to the WireGuard directory
  echo -e "\e[1;34mMoving wgcf-profile.conf to /etc/wireguard/warp.conf...\e[0m"
  sudo mv wgcf-profile.conf /etc/wireguard/warp.conf

  # Enable and start the WARP interface
  echo -e "\e[1;34mEnabling and starting WARP...\e[0m"
  sudo systemctl enable --now wg-quick@warp
  if [ $? -ne 0 ]; then
    echo -e "\e[1;31mError: Failed to enable and start the WARP interface.\e[0m"
    return
  fi

  echo -e "\e[1;32mSetup completed successfully!\e[0m"
}

# Function to update WARP configuration
update_warp_config() {
  # Remove any existing configuration before updating
  echo -e "\e[1;34mRemoving any existing WARP configuration...\e[0m"
  rm -f wgcf-account.toml
  rm -f wgcf-profile.conf
  sudo rm -f /etc/wireguard/warp.conf

  # Ask if the user has a new WARP license key
  read -p "Do you have a new WARP+ license key to update? (y/n): " HAS_LICENSE_KEY
  if [[ "$HAS_LICENSE_KEY" == "y" || "$HAS_LICENSE_KEY" == "Y" ]]; then
    read -p "Enter your new WARP license key: " LICENSE_KEY
    if [ -z "$LICENSE_KEY" ]; then
      echo -e "\e[1;31mError: WARP license key cannot be empty.\e[0m"
      return
    fi

    echo -e "\e[1;34mUpdating WARP license key...\e[0m"
    sed -i "s/^license_key =.*/license_key = '$LICENSE_KEY'/" wgcf-account.toml

    # Update wgcf and regenerate profile until WARP+ is confirmed
    while true; do
      wgcf update
      wgcf generate

      # Check if the account type is now WARP+
      ACCOUNT_TYPE=$(wgcf status | grep -i "Account type" | awk '{print $NF}')
      if [[ "$ACCOUNT_TYPE" == "Plus" ]]; then
        echo -e "\e[1;32mWARP+ license applied successfully.\e[0m"
        break
      else
        echo -e "\e[1;33mAccount type still free. Retrying update...\e[0m"
      fi
    done

    # Move the updated profile to the WireGuard directory
    echo -e "\e[1;34mMoving updated wgcf-profile.conf to /etc/wireguard/warp.conf...\e[0m"
    sudo mv wgcf-profile.conf /etc/wireguard/warp.conf
  fi

  # Restart the WARP interface to apply changes
  echo -e "\e[1;34mRestarting WARP interface...\e[0m"
  sudo systemctl restart wg-quick@warp
  if [ $? -ne 0 ]; then
    echo -e "\e[1;31mError: Failed to restart the WARP interface.\e[0m"
    return
  fi

  echo -e "\e[1;32mWARP configuration updated successfully!\e[0m"
}

# Function to uninstall WARP
uninstall_warp() {
  echo -e "\e[1;34mStopping WARP interface...\e[0m"
  sudo systemctl stop wg-quick@warp

  echo -e "\e[1;34mDisabling WARP interface...\e[0m"
  sudo systemctl disable wg-quick@warp

  echo -e "\e[1;34mRemoving WARP configuration...\e[0m"
  sudo rm -f /etc/wireguard/warp.conf

  echo -e "\e
