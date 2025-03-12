#!/bin/bash
set -e

# Configuration Variables
HOSTNAME="Outernet"
PORT=7777
MAP="aneurismiv"
PASSWORD=""
MAXPLAYERS=60
STEAM_USERNAME="anonymous"  # Change if needed
APP_ID="2832030"  # Game/App ID for SteamCMD
INSTALL_DIR="$HOME/aniv"
SERVER_EXECUTABLE="$INSTALL_DIR/aniv_server.x86_64"
LOGS_DIR="$INSTALL_DIR/logs"
SERVER_LOG="$LOGS_DIR/server.log"
DB_PATH="$HOME/.config/unity3d/Vellocet/ANEURISM IV/aniv.db"
OPS_CFG="$HOME/.config/unity3d/Vellocet/ANEURISM IV/ops.cfg"
DATE_FORMAT="+%Y-%m-%d %H:%M:%S"
STEAMCMD_DIR="$HOME/steamcmd"

# Auto-restart configuration (in hours)
RESTART_INTERVAL_HOURS=0  # Default to 3 hours, modify as needed

# Ensure necessary directories exist
mkdir -p "$LOGS_DIR"
mkdir -p "$STEAMCMD_DIR"

# Function to install or update the server
install_server() {
    echo "[$(date "$DATE_FORMAT")] Installing/updating Aneurism IV server..."

    # Install SteamCMD if not present
    if [ ! -f "$STEAMCMD_DIR/steamcmd.sh" ]; then
        echo "[$(date "$DATE_FORMAT")] SteamCMD not found, downloading..."
        mkdir -p "$STEAMCMD_DIR"
        cd "$STEAMCMD_DIR"
        curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf -
    fi

    # Install or update the server using SteamCMD
    $STEAMCMD_DIR/steamcmd.sh +force_install_dir "$INSTALL_DIR" +login "$STEAM_USERNAME" +app_update "$APP_ID" validate +quit

    echo "[$(date "$DATE_FORMAT")] Server installed/updated successfully."
}

# Function to start the server
start_server() {
    echo "[$(date "$DATE_FORMAT")] Checking if the server is already running..."
    if pgrep -f "$SERVER_EXECUTABLE" > /dev/null; then
        echo "[$(date "$DATE_FORMAT")] Server is already running."
        return 1
    fi

    echo "[$(date "$DATE_FORMAT")] Starting the server..."

    # Move old logs if they exist
    if [ -f "$SERVER_LOG" ]; then
        echo "[$(date "$DATE_FORMAT")] Archiving old logs..."
        mv "$SERVER_LOG" "$LOGS_DIR/server_$(date "+%Y-%m-%d_%H-%M-%S").log"
    fi

    chmod +x "$SERVER_EXECUTABLE"

    # Start the server
    cd "$INSTALL_DIR"
    if [ -z "$PASSWORD" ]; then
        $SERVER_EXECUTABLE -map "$MAP" -maxplayers "$MAXPLAYERS" -timestamps > "$SERVER_LOG" 2>&1 &
    else
        $SERVER_EXECUTABLE -map "$MAP" -password "$PASSWORD" -maxplayers "$MAXPLAYERS" -timestamps > "$SERVER_LOG" 2>&1 &
    fi

    sleep 2  # Give it some time to start

    if pgrep -f "$SERVER_EXECUTABLE" > /dev/null; then
        echo "[$(date "$DATE_FORMAT")] Server started successfully."
    else
        echo "[$(date "$DATE_FORMAT")] Failed to start the server. Check the log for details: $SERVER_LOG"
    fi
}

# Function to stop the server
stop_server() {
    echo "[$(date "$DATE_FORMAT")] Checking if the server is running..."
    if ! pgrep -f "$SERVER_EXECUTABLE" > /dev/null; then
        echo "[$(date "$DATE_FORMAT")] No running server instance found."
        return 1
    fi

    echo "[$(date "$DATE_FORMAT")] Stopping the server..."
    pkill -f "$SERVER_EXECUTABLE"
    if [ $? -eq 0 ]; then
        echo "[$(date "$DATE_FORMAT")] Server stopped successfully."
    else
        echo "[$(date "$DATE_FORMAT")] Failed to stop the server."
        return 1
    fi
}

# Function to restart the server
restart_server() {
    stop_server
    sleep 2
    start_server
}

# Function to show logs
show_logs() {
    echo "[$(date "$DATE_FORMAT")] Showing server logs..."
    tail -f "$SERVER_LOG"
}

# Function to delete the database
delete_database() {
    echo "[$(date "$DATE_FORMAT")] Deleting the database..."
    rm -f "$DB_PATH"
    echo "[$(date "$DATE_FORMAT")] Database deleted."
}

# Function to add an op
add_op() {
    if [ $# -ne 1 ]; then
        echo "Usage: $0 add_op <op_name>"
        return 1
    fi
    echo "[$(date "$DATE_FORMAT")] Adding op: $1..."
    echo "$1" >> "$OPS_CFG"
    echo "[$(date "$DATE_FORMAT")] Op added."
}

# Function to remove an op
remove_op() {
    if [ $# -ne 1 ]; then
        echo "Usage: $0 remove_op <op_name>"
        return 1
    fi
    echo "[$(date "$DATE_FORMAT")] Removing op: $1..."
    sed -i "/^$1$/d" "$OPS_CFG"
    echo "[$(date "$DATE_FORMAT")] Op removed."
}

# Function to auto-restart the server at a given interval
auto_restart_server() {
    echo "[$(date "$DATE_FORMAT")] Auto-restart is enabled. Server will restart every $RESTART_INTERVAL_HOURS hour(s)."

    while true; do
        echo "[$(date "$DATE_FORMAT")] Waiting for $RESTART_INTERVAL_HOURS hour(s) before restart..."
        sleep $((RESTART_INTERVAL_HOURS * 3600))

        echo "[$(date "$DATE_FORMAT")] Stopping the server for auto-restart..."
        stop_server
        echo "[$(date "$DATE_FORMAT")] Updating the server during auto-restart..."
        install_server
        echo "[$(date "$DATE_FORMAT")] Restarting the server after update..."
        start_server
        echo "[$(date "$DATE_FORMAT")] Server auto-restart complete."
    done
}

# Main script logic
case "$1" in
    start)
        start_server
        ;;
    stop)
        stop_server
        ;;
    restart)
        restart_server
        ;;
    logs)
        show_logs
        ;;
    install)
        install_server
        ;;
    delete_db)
        delete_database
        ;;
    add_op)
        add_op "$2"
        ;;
    remove_op)
        remove_op "$2"
        ;;
    auto_restart)
        auto_restart_server
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|logs|install|delete_db|add_op|remove_op|auto_restart}"
        exit 1
        ;;
esac
