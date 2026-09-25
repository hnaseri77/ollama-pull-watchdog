#!/usr/bin/env bash

# --- 1. Model Name Handling ---
MODEL="$1"
if [ -z "$MODEL" ]; then
    echo "---------------------------------------------------"
    echo "Examples: deepseek-r1:32b, qwen2.5-coder:32b, llama3.3:70b"
    echo "---------------------------------------------------"
    read -p "Enter model name to download: " MODEL
fi

if [ -z "$MODEL" ]; then
    echo "Error: Model name cannot be empty."
    exit 1
fi

# --- 2. Speed Threshold Handling ---
RAW_SPEED="$2"
if [ -z "$RAW_SPEED" ]; then
    echo "---------------------------------------------------"
    echo "Speed Threshold Setup:"
    echo "  - Press [Enter] for default: 200 KB/s"
    echo "  - Examples: 150K, 300K, 1M (1024 KB/s), 1.5M"
    echo "  - Note: Minimum allowed threshold is 100 KB/s"
    echo "---------------------------------------------------"
    read -p "Enter min speed threshold [Default 200K]: " RAW_SPEED
fi

# Apply default if empty
if [ -z "$RAW_SPEED" ]; then
    RAW_SPEED="200K"
fi

# Parse Speed Function (Handles numbers, K/k, M/m)
parse_speed() {
    local input="$1"
    input=$(echo "$input" | tr -d ' ')
    
    if [[ "$input" =~ ^([0-9]+(\.[0-9]+)?)([kKmM]?)$ ]]; then
        local num="${BASH_REMATCH[1]}"
        local unit="${BASH_REMATCH[3]}"
        
        case "$unit" in
            [mM])
                awk -v n="$num" 'BEGIN {printf "%d\n", n * 1024}'
                ;;
            [kK]|"")
                awk -v n="$num" 'BEGIN {printf "%d\n", n}'
                ;;
        esac
    else
        echo "200"
    fi
}

MIN_SPEED_KBS=$(parse_speed "$RAW_SPEED")

# Enforce minimum speed limit (Cannot go below 100 KB/s)
if [ "$MIN_SPEED_KBS" -lt 100 ]; then
    echo "--> Notice: Minimum speed threshold cannot be less than 100 KB/s."
    echo "--> Setting threshold to 100 KB/s."
    MIN_SPEED_KBS=100
fi

# --- 3. Trap Ctrl+C (SIGINT) ---
cleanup() {
    echo -e "\n\n--> Download cancelled by user (Ctrl+C). Cleaning up..."
    kill -9 $PID 2>/dev/null
    exit 130
}
trap cleanup SIGINT SIGTERM

# --- 4. Helper Functions ---
get_rx_bytes() {
    awk '/:/ {sum += $2} END {print sum}' /proc/net/dev
}

get_saved_size() {
    local size
    size=$(du -sh /usr/share/ollama/.ollama/models/blobs 2>/dev/null | awk '{print $1}')
    if [ -n "$size" ]; then
        echo "$size"
    else
        size=$(du -sh /var/lib/ollama/.ollama/models/blobs 2>/dev/null | awk '{print $1}')
        if [ -n "$size" ]; then
            echo "$size"
        else
            echo "N/A"
        fi
    fi
}

echo "==================================================="
echo " Smart Ollama Downloader (v3.0)"
echo " Target Model : $MODEL"
echo " Min Speed    : ${MIN_SPEED_KBS} KB/s"
echo " Press Ctrl+C anytime to cancel and exit."
echo "==================================================="

# --- 5. Main Download Loop ---
while true; do
    echo "--> Starting/Resuming download for $MODEL..."
    
    ollama pull "$MODEL" &
    PID=$!

    # Grace Period: 5 seconds to allow connection & manifest handshake
    echo "--> Allowing 5s grace period for connection to establish..."
    sleep 5

    # Check if process exited during grace period (Success or Network Failure)
    if ! kill -0 $PID 2>/dev/null; then
        wait $PID 2>/dev/null
        EXIT_CODE=$?
        
        if [ $EXIT_CODE -eq 0 ]; then
            echo "==================================================="
            echo "--> SUCCESS: $MODEL downloaded 100%!"
            echo "==================================================="
            
            if command -v notify-send >/dev/null 2>&1; then
                notify-send "Ollama Downloader" "Model '$MODEL' downloaded successfully!" -i emblem-default
            fi
            break
        else
            echo "--> Connection interrupted or failed during initial setup. Retrying in 5 seconds..."
            sleep 5
            continue
        fi
    fi

    # Speed monitoring loop
    while kill -0 $PID 2>/dev/null; do
        RX1=$(get_rx_bytes)
        
        sleep 4
        
        if ! kill -0 $PID 2>/dev/null; then
            break
        fi
        
        RX2=$(get_rx_bytes)
        
        # Calculate speed (KB/s over 4 seconds interval)
        DIFF=$((RX2 - RX1))
        SPEED_KBS=$((DIFF / 4096))

        if [ "$SPEED_KBS" -lt "$MIN_SPEED_KBS" ]; then
            echo "!!! Speed Dropped: ${SPEED_KBS} KB/s (Threshold: ${MIN_SPEED_KBS} KB/s) !!!"
            echo "--> Killing process to force immediate reconnect..."
            
            kill -9 $PID 2>/dev/null
            
            SAVED=$(get_saved_size)
            if [ "$SAVED" != "N/A" ]; then
                echo "--> Total disk usage so far: $SAVED"
            fi
            
            echo "--> Waiting exactly 4 seconds before resuming..."
            sleep 4
            
            break
        fi
    done

    wait $PID 2>/dev/null
    EXIT_CODE=$?

    if [ $EXIT_CODE -eq 0 ]; then
        echo "==================================================="
        echo "--> SUCCESS: $MODEL downloaded 100%!"
        echo "==================================================="
        
        # Send Desktop Notification on Linux
        if command -v notify-send >/dev/null 2>&1; then
            notify-send "Ollama Downloader" "Model '$MODEL' downloaded successfully!" -i emblem-default
        fi
        break
    fi
done
