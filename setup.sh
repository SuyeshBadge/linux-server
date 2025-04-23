#!/data/data/com.termux/files/usr/bin/bash

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