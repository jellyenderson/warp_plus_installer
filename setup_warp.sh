#!/bin/bash

# Copyright 2024, Jellyenderson

# WARP Status Function
show_warp_status() {
  echo -e "\e[1;33m============================\e[0m"
  echo -e "\e[1;96m   WARP Status\e[0m"
  echo -e "\e[1;33m============================\e[0m"
  if systemctl is-active --quiet wg-quick@warp; then
    echo -e "\e[1;93mWARP Status: \e[1;42m YES \e[0m"
  else
    echo -e "\e[1;93mWARP Status: \e[1;41m NO \e[0m"
  fi
  echo -e "\e[1;33m============================\e[0m"
}

# Menu function
show_menu() {
  echo -e "\e[1;33m============================\e[0m"
  echo -e "\e[1;96m   WARP Setup Menu\e[0m"
  echo -e "\e[1;33m============================\e[0m"
  echo -e "\e[1;34m1. Setup WARP\e[0m"
  echo -e "\e[1;34m2. Update WARP Configuration\e[0m"
  if systemctl is-active --quiet wg-quick@warp; then
    echo -e "\e[1;34m3. Uninstall WARP\e[0m"
  fi
  echo -e "\e[1;34m0. Quit\e[0m"
  echo -e "\e[1;33m============================\e[0m"
  echo -e "\e[1;95mCopyright 2024, Jellyenderson\e[0m"
  echo -e "\e[1;33m============================\e[0m"
}

# Function to download latest wgcf
install_latest_wgcf() {
  echo -e "\e[1;34mFetching latest wgcf release...\e[0m"
  LATEST_URL=$(curl -s https://api.github.com/repos/ViRb3/wgcf/releases/latest | grep browser_download_url | grep linux_amd64 | cut -d '"' -f 4 | head -n1)

  if [ -z "$LATEST_URL" ]; then
    echo -e "\e[1;31mError: Could not fetch latest wgcf release URL.\e[0m"
    return 1
  fi

  echo -e "\e[1;34mDownloading wgcf from: $LATEST_URL\e[0m"
  wget -q --show-progress "$LATEST_URL" -O /usr/bin/wgcf
  if [ $? -ne 0 ]; then
    echo -e "\e[1;31mError: Failed to download wgcf binary.\e[0m"
    return 1
  fi
  chmod +x /usr/bin/wgcf
}

# Function to setup WARP
setup_warp() {
  echo -e "\e[1;34mRemoving any existing WARP configuration...\e[0m"
  rm -f wgcf-account.toml wgcf-profile.conf
  sudo rm -f /etc/wireguard/warp.conf

  read -p "Do you have a WARP+ license key? (y/n): " HAS_LICENSE_KEY
  if [[ "$HAS_LICENSE_KEY" =~ ^[Yy]$ ]]; then
    read -p "Enter your WARP license key: " LICENSE_KEY
    if [ -z "$LICENSE_KEY" ]; then
      echo -e "\e[1;31mError: WARP license key cannot be empty.\e[0m"
      return
    fi
  fi

  install_latest_wgcf || return 1

  echo -e "\e[1;34mRegistering wgcf...\e[0m"
  yes | wgcf register || { echo -e "\e[1;31mError: Failed to register wgcf.\e[0m"; return 1; }

  echo -e "\e[1;34mGenerating wgcf profile...\e[0m"
  wgcf generate || { echo -e "\e[1;31mError: Failed to generate wgcf profile.\e[0m"; return 1; }

  if [[ ! -z "$LICENSE_KEY" ]]; then
    echo -e "\e[1;34mAdding WARP license key to wgcf-account.toml...\e[0m"
    sed -i "s/^license_key =.*/license_key = '$LICENSE_KEY'/" wgcf-account.toml
    echo -e "\e[1;34mUpdating wgcf with new license...\e[0m"
    wgcf update
    wgcf generate
  fi

  UBUNTU_VERSION=$(lsb_release -rs | cut -d '.' -f1)
  echo -e "\e[1;34mInstalling required packages...\e[0m"
  if [ "$UBUNTU_VERSION" -lt 24 ]; then
    sudo apt update && sudo apt install -y wireguard-dkms wireguard-tools resolvconf
  else
    sudo apt update && sudo apt install -y wireguard
  fi

  echo -e "\e[1;34mModifying wgcf-profile.conf...\e[0m"
  sed -i '/\[Interface\]/a Table = off' wgcf-profile.conf

  sudo mkdir -p /etc/wireguard
  sudo mv wgcf-profile.conf /etc/wireguard/warp.conf

  echo -e "\e[1;34mEnabling and starting WARP...\e[0m"
  sudo systemctl enable --now wg-quick@warp || { echo -e "\e[1;31mError: Failed to start WARP.\e[0m"; return 1; }

  echo -e "\e[1;32mSetup completed successfully!\e[0m"
}

# Function to update WARP configuration
update_warp_config() {
  echo -e "\e[1;34mRemoving any existing WARP configuration...\e[0m"
  rm -f wgcf-account.toml wgcf-profile.conf
  sudo rm -f /etc/wireguard/warp.conf

  read -p "Do you have a new WARP+ license key to update? (y/n): " HAS_LICENSE_KEY
  if [[ "$HAS_LICENSE_KEY" =~ ^[Yy]$ ]]; then
    read -p "Enter your new WARP license key: " LICENSE_KEY
    if [ -z "$LICENSE_KEY" ]; then
      echo -e "\e[1;31mError: WARP license key cannot be empty.\e[0m"
      return
    fi
    sed -i "s/^license_key =.*/license_key = '$LICENSE_KEY'/" wgcf-account.toml
    wgcf update
    wgcf generate
    sudo mv wgcf-profile.conf /etc/wireguard/warp.conf
  fi

  echo -e "\e[1;34mRestarting WARP interface...\e[0m"
  sudo systemctl restart wg-quick@warp || { echo -e "\e[1;31mError: Failed to restart WARP.\e[0m"; return 1; }

  echo -e "\e[1;32mWARP configuration updated successfully!\e[0m"
}

# Function to uninstall WARP
uninstall_warp() {
  sudo systemctl stop wg-quick@warp
  sudo systemctl disable wg-quick@warp
  sudo rm -f /etc/wireguard/warp.conf
  rm -f wgcf-account.toml wgcf-profile.conf
  sudo rm -f /usr/bin/wgcf
  sudo apt purge -y wireguard wireguard-tools wireguard-dkms resolvconf
  echo -e "\e[1;32mWARP uninstalled successfully!\e[0m"
}

# Main loop
while true; do
  show_warp_status
  show_menu
  read -p "Enter your choice [0-3]: " choice
  case $choice in
    1) setup_warp ;;
    2) update_warp_config ;;
    3) if systemctl is-active --quiet wg-quick@warp; then uninstall_warp; else echo -e "\e[1;31mInvalid option.\e[0m"; fi ;;
    0) echo -e "\e[1;34mExiting... Goodbye!\e[0m"; exit 0 ;;
    *) echo -e "\e[1;31mInvalid option, please try again.\e[0m" ;;
  esac
done
