#!/bin/bash

# Update package list and upgrade packages
echo "Updating package list and upgrading packages..."
sudo apt-get update -y || { echo "Update failed"; exit 1; }
sudo apt-get upgrade -y || { echo "Upgrade failed"; exit 1; }

# Install necessary certificates and dependencies
echo "Installing necessary certificates and dependencies..."
sudo apt-get install -y ca-certificates curl || { echo "Package installation failed"; exit 1; }

# Create the directory for keyrings
sudo mkdir -p /etc/apt/keyrings

# Add Docker's official GPG key
echo "Adding Docker's GPG key..."
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc || { echo "Failed to download GPG key"; exit 1; }

# Add the Docker repository
echo "Adding Docker repository..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list || { echo "Failed to add Docker repository"; exit 1; }

# Update apt sources
sudo apt-get update || { echo "Failed to update sources"; exit 1; }

# Install Docker
echo "Installing Docker..."
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose || { echo "Docker installation failed"; exit 1; }

echo "Docker installation complete!"

# Navigate to the repository and get docker-compose files
cd ~/raspberry-pi-setup

# Load environment variables from docker-compose.env file
if [ -f "./docker-compose.env" ]; then
  export $(grep -v '^#' ./docker-compose.env | xargs)
else
  echo "docker-compose.env file not found!"
  exit 1
fi

# Define the base directory for volumes
VOLUME_BASE="/srv"

# List of volume names you want to create
VOLUMES=("telegraf" "mosquitto" "homeassistant" "influxdb" "grafana")

# Create the volumes and set permissions
for VOLUME in "${VOLUMES[@]}"; do
    VOLUME_PATH="${VOLUME_BASE}/${VOLUME}"

    # Create the directory if it does not exist
    if [ ! -d "$VOLUME_PATH" ]; then
        echo "Creating volume at $VOLUME_PATH"
        mkdir -p "$VOLUME_PATH"
    else
        echo "Volume at $VOLUME_PATH already exists"
    fi

    # Change ownership to ensure Docker can access it (replace 'dockeruser' with your user if needed)
    echo "Setting permissions for $VOLUME_PATH"
    chown -R root:docker "$VOLUME_PATH"  # Make sure the Docker group has access

    # Set permissions to be open for Docker usage
    chmod -R 775 "$VOLUME_PATH"  # Allows read/write for owner and group, read for others

    # Optionally, you can make the group 'docker' if you want to ensure all Docker containers have access
    # This command may be useful if you want Docker containers to have access without being root
    # usermod -aG docker $(whoami)
done

# Define variables
CLONE_DIR="$PWD"  # Current directory where the repo is cloned

# Telegraf configuration
TELEGRAF_CONFIG_PATH="$CLONE_DIR/telegraf.conf"
TELEGRAF_DEST_DIR="$TELEGRAF_VOLUME"  # Use the TELEGRAF_VOLUME from the docker-compose.env file

# Mosquitto configuration
MOSQUITTO_CONFIG_PATH="$CLONE_DIR/mosquitto.conf"
MOSQUITTO_DEST_DIR="$MOSQUITTO_VOLUME"  # Use the MOSQUITTO_VOLUME from the docker-compose.env file

# Move the Telegraf configuration file if it exists
if [ -f "$TELEGRAF_CONFIG_PATH" ]; then
  echo "Moving Telegraf configuration to $TELEGRAF_DEST_DIR..."
  # Create destination directory if it doesn't exist
  sudo mkdir -p "$TELEGRAF_DEST_DIR"
  # Move the configuration file
  sudo mv "$TELEGRAF_CONFIG_PATH" "$TELEGRAF_DEST_DIR"
else
  echo "Telegraf configuration file not found in the current directory at $TELEGRAF_CONFIG_PATH"
  exit 1
fi

# Move the Mosquitto configuration file if it exists
if [ -f "$MOSQUITTO_CONFIG_PATH" ]; then
  echo "Moving Mosquitto configuration to $MOSQUITTO_DEST_DIR..."
  # Create destination directory if it doesn't exist
  sudo mkdir -p "$MOSQUITTO_DEST_DIR"
  # Move the configuration file
  sudo mv "$MOSQUITTO_CONFIG_PATH" "$MOSQUITTO_DEST_DIR"
else
  echo "Mosquitto configuration file not found in the current directory at $MOSQUITTO_CONFIG_PATH"
  exit 1
fi

# Prompt for passwords and update docker-compose.env
echo "Please enter the required passwords for the containers..."

# Define the variables from docker-compose.env that need to be updated
declare -A passwords
passwords=(
    ["INFLUXDB_ADMIN_PASSWORD"]="InfluxDB Admin Password"
    ["INFLUXDB_PASSWORD"]="InfluxDB User Password"
    ["GRAFANA_PASSWORD"]="Grafana Password"
    ["HA_PASSWORD"]="Home Assistant Password"
)

# Loop through the passwords and ask for user input
for key in "${!passwords[@]}"; do
    read -sp "Enter ${passwords[$key]}: " password
    echo
    # Update the docker-compose.env file with the user-provided passwords
    sed -i "s/^$key=.*/$key=$password/" docker-compose.env
done

# Check if Portainer is already installed (by checking if the Portainer container exists)
if ! docker ps -a --format '{{.Names}}' | grep -q 'portainer'; then
    echo "Portainer is not installed. Deploying Portainer..."

    # Run Portainer using the docker run command
    docker run -d \
        -p 8000:8000 \
        -p 9443:9443 \
        --name portainer \
        --restart=always \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v portainer_data:/data \
        portainer/portainer-ce:2.21.5

    echo "Portainer is now running."
else
    echo "Portainer is already deployed!"
fi

# Deploy the Docker Compose stacks
echo "Deploying Docker Compose stacks..."
docker-compose up -d

# Install Tailscale (latest version)
echo "Installing Tailscale..."
curl -fsSL https://tailscale.com/install.sh | sh

# Start Tailscale
echo "Starting Tailscale..."
sudo tailscale up

echo "Setup complete!"
