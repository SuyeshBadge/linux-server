#!/data/data/com.termux/files/usr/bin/bash
set -e

# Default values
SSH_PORT=8022
DISTRO="ubuntu"

# Help message function
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -p, --port PORT     Set SSH port (default: 8022)"
    echo "  -d, --distro DISTRO Choose Linux distribution (ubuntu, debian, alpine)"
    echo "  -h, --help          Show this help message"
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--port)
            SSH_PORT="$2"
            shift 2
            ;;
        -d|--distro)
            DISTRO="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            ;;
    esac
done

# Validate input
if ! [[ "$SSH_PORT" =~ ^[0-9]+$ ]] || [ "$SSH_PORT" -lt 1024 ] || [ "$SSH_PORT" -gt 65535 ]; then
    echo "❌ Error: Port must be a number between 1024 and 65535"
    exit 1
fi

case "$DISTRO" in
    ubuntu|debian|alpine)
        # Valid distro
        ;;
    *)
        echo "❌ Error: Unsupported distribution '$DISTRO'. Choose ubuntu, debian, or alpine."
        exit 1
        ;;
esac

echo "🔧 Configuration:"
echo "  • Linux Distribution: $DISTRO"
echo "  • SSH Port: $SSH_PORT"
echo

# Function to check if a package is installed
is_installed() {
    pkg list-installed | grep -q "^$1"
    return $?
}

# Function to install package if not already installed
install_pkg() {
    if ! is_installed "$1"; then
        echo "📦 Installing $1..."
        pkg install -y "$1" || { echo "❌ Failed to install $1"; exit 1; }
    else
        echo "✅ $1 already installed"
    fi
}

echo "📦 Updating Termux..."
pkg update -y && pkg upgrade -y || { echo "❌ Failed to update Termux packages"; exit 1; }

echo "📥 Installing essential packages..."
for package in curl wget git proot-distro openssh tsu vim termux-api; do
    install_pkg "$package"
done

echo "🐧 Installing $DISTRO..."
if proot-distro list-installed | grep -q "$DISTRO"; then
    echo "✅ $DISTRO already installed"
else
    proot-distro install "$DISTRO" || { echo "❌ Failed to install $DISTRO"; exit 1; }
fi

echo "⚙️ Setting up $DISTRO environment..."
proot-distro login "$DISTRO" -- bash -c "
# Redirect stderr to stdout so we can capture errors
exec 2>&1

# Update and install packages
echo '📦 Updating packages...'
apt update && apt upgrade -y || { echo '❌ Failed to update packages'; exit 1; }

echo '📦 Installing essential tools...'
apt install -y openssh-server git curl wget build-essential tmux vim || { echo '❌ Failed to install packages'; exit 1; }

# Set up SSH
echo '🔑 Setting up SSH...'
mkdir -p ~/.ssh
chmod 700 ~/.ssh
touch ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

# Configure SSH port
if grep -q '^Port ' /etc/ssh/sshd_config; then
    sed -i "s/^Port .*/Port $SSH_PORT/" /etc/ssh/sshd_config
else
    echo "Port $SSH_PORT" >> /etc/ssh/sshd_config
fi

# Set PATH
echo 'export PATH=\$PATH:/usr/sbin' >> ~/.bashrc
" || { echo "❌ Failed to set up $DISTRO environment"; exit 1; }

echo "🚀 Creating startup script..."
cat << EOF > ~/start-server.sh
#!/data/data/com.termux/files/usr/bin/bash
termux-wake-lock
proot-distro login $DISTRO -- bash -c '
if pgrep sshd > /dev/null; then
    echo "✅ SSH server is already running"
else
    /usr/sbin/sshd || service ssh start
    if [ \$? -eq 0 ]; then
        echo "✅ SSH server started successfully"
    else
        echo "❌ Failed to start SSH server"
        exit 1
    fi
fi
echo "✅ Server is running. SSH available at port $SSH_PORT."
'

# Keep the script running to maintain wake lock
echo "📱 Termux will stay awake. Press Ctrl+C to exit."
while true; do sleep 60; done
EOF

chmod +x ~/start-server.sh

# Check if Termux:Boot is installed
if [ -d "/data/data/com.termux.boot" ]; then
    echo "🔁 Setting up Termux:Boot..."
    mkdir -p ~/.termux/boot
    cp ~/start-server.sh ~/.termux/boot/startup.sh
    chmod +x ~/.termux/boot/startup.sh
else
    echo "ℹ️ Termux:Boot not detected. Skipping autostart configuration."
fi

# Get device IP
DEVICE_IP=$(ip addr | grep 'inet ' | grep -v '127.0.0.1' | head -n1 | awk '{print $2}' | cut -d/ -f1)

echo "✅ All done!"
echo
echo "📋 QUICK SETUP GUIDE"
echo "===================="
echo "1️⃣ To start your server manually, run:"
echo "   bash ~/start-server.sh"
echo
echo "2️⃣ To autostart on boot, install Termux:Boot from F-Droid:"
echo "   https://f-droid.org/packages/com.termux.boot/"
echo
echo "3️⃣ To SSH into your device (once running):"
echo "   ssh -p $SSH_PORT username@$DEVICE_IP"
echo
echo "4️⃣ To add your SSH public key to the authorized_keys file:"
echo "   cat ~/.ssh/id_rsa.pub | ssh -p $SSH_PORT username@$DEVICE_IP \"cat >> ~/.ssh/authorized_keys\""
echo 
echo "5️⃣ For help and options, run:"
echo "   $0 --help"
