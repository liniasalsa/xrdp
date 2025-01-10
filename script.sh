#!/bin/bash

# Function to display an error message and exit
function display_error() {
    echo "Error: $1"
    exit 1
}

# Function to prompt user for confirmation
function prompt_confirmation() {
    read -p "$1 (y/n): " response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        return 0  # User confirmed
    else
        return 1  # User did not confirm
    fi
}

# Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
    display_error "This script must be run as root. Please use sudo."
fi

# Display a warning and prompt for confirmation
echo "This script will install xrdp, ngrok, change the root password, and launch xrdp on port 3389."
prompt_confirmation "Do you want to continue?"

# Prompt user for root password
read -s -p "Enter the new root password: " root_password
echo

# Change root password
echo "root:$root_password" | chpasswd

# Install necessary packages
apt-get update || display_error "Failed to update package list"
apt install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common \
    xfce4 \
    xfce4-goodies \
    gdebi \
    wget \
    unzip \
    dbus-x11 \
    xfce4-terminal \
    firefox \
    xrdp || display_error "Failed to install required packages"

# Configure XRDP to use Xfce
echo "xfce4-session" > /etc/skel/.xsession

# Start the xrdp service
sudo service xrdp start || display_error "Failed to start XRDP service"

# Check if ngrok is already present
if ! command -v ngrok &> /dev/null; then
    prompt_confirmation "Ngrok is not installed. Do you want to download it?"
    # Download and extract ngrok
    wget --no-check-certificate https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz || display_error "Failed to download Ngrok"
    tar -xzf ngrok-v3-stable-linux-amd64.tgz || display_error "Failed to extract Ngrok"
    rm ngrok-v3-stable-linux-amd64.tgz
fi

# Prompt user for ngrok authtoken
read -p "Enter your ngrok authtoken: " authtoken

# Set ngrok authtoken and launch ngrok in the background
./ngrok authtoken "$authtoken" || display_error "Failed to authenticate Ngrok"
./ngrok tcp 3389 &

# Start xrdp in the background
xrdp &

# Display instructions to the user
IP_ADDRESS=$(hostname -I | awk '{print $1}')
echo "===================================================="
echo "XRDP and Ngrok are running."
echo "You can now connect to XRDP via the following ngrok TCP address:"
echo "Ngrok Address: $(curl -s localhost:4040/api/tunnels | jq -r '.tunnels[0].public_url')"
echo "IP Address: $IP_ADDRESS"
echo "Port: 3389"
echo "===================================================="
