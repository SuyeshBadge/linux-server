#!/data/data/com.termux/files/usr/bin/bash

# Check if ngrok is installed, if not download and extract it
if [ ! -f "./ngrok" ]; then
    echo "[INFO] ngrok not found. Downloading ngrok..."
    # Download ngrok for ARM (assuming Android device)
    curl -O https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-arm.tgz
    
    # Extract ngrok
    tar xvzf ngrok-v3-stable-linux-arm.tgz
    
    # Make ngrok executable
    chmod +x ngrok
    
    # Clean up
    rm ngrok-v3-stable-linux-arm.tgz
    
    echo "[INFO] You need to authenticate ngrok. Run './ngrok authtoken YOUR_AUTH_TOKEN' with your token from ngrok.com"
    echo "[INFO] Press Enter to continue once you've authenticated ngrok..."
    read
fi

# Create a tmux session to keep it alive
SESSION_NAME="ssh-tunnel"
tmux has-session -t $SESSION_NAME 2>/dev/null

if [ $? != 0 ]; then
    echo "[INFO] Starting tmux session '$SESSION_NAME'..."
    tmux new-session -d -s $SESSION_NAME
fi

# Inside tmux: start Ubuntu, SSH, and ngrok tunnel
tmux send-keys -t $SESSION_NAME "
echo '[INFO] Logging into Ubuntu and starting SSH...';
proot-distro login ubuntu -- bash -c \"
service ssh start;
echo '[INFO] SSH server started inside Ubuntu.';
\"
echo '[INFO] Starting ngrok tunnel on port 22...';
./ngrok tcp 127.0.0.1:8022;
" C-m

echo "✅ SSH Tunnel setup is running inside tmux session: $SESSION_NAME"
echo "You can attach with: tmux attach -t $SESSION_NAME"