#!/system/bin/sh
# TWRP Touch Fix for Samsung S22+ (g0q) — STM touchscreen driver
# Problem: STM driver enters gesture-only mode after first tap on Android 15 firmware
# Solution: Force active mode and rebind the SPI driver

LOG_TAG="twrp-touch-fix"

log_msg() {
    echo "$LOG_TAG: $1" >> /tmp/recovery.log
}

log_msg "Starting touch fix..."

# Method 1: Force active mode via sysfs
for path in /sys/class/sec/tsp /sys/devices/virtual/sec/tsp; do
    if [ -d "$path" ]; then
        log_msg "Found touch sysfs at $path"
        # Force active scanning mode (disable gesture-only)
        echo "fix_active_mode,1" > "$path/cmd" 2>/dev/null && \
            log_msg "fix_active_mode applied"
        # Disable LPWG (Low Power Wake Gesture) which causes the issue
        echo "set_lpwg_mode,0" > "$path/cmd" 2>/dev/null && \
            log_msg "LPWG disabled"
        # Force touchscreen to normal operation mode
        echo "set_power_mode,1" > "$path/cmd" 2>/dev/null && \
            log_msg "Power mode set to active"
    fi
done

# Method 2: Rebind STM SPI driver (nuclear option - fully reinits touch)
STM_DRIVER_PATH=""
for d in /sys/bus/spi/drivers/stm_ts_spi /sys/bus/spi/drivers/fts_ts_spi; do
    if [ -d "$d" ]; then
        STM_DRIVER_PATH="$d"
        break
    fi
done

if [ -n "$STM_DRIVER_PATH" ]; then
    log_msg "Found STM driver at $STM_DRIVER_PATH"
    # Find the bound device
    SPI_DEV=$(ls "$STM_DRIVER_PATH" 2>/dev/null | grep "spi")
    if [ -n "$SPI_DEV" ]; then
        log_msg "Rebinding $SPI_DEV..."
        echo "$SPI_DEV" > "$STM_DRIVER_PATH/unbind" 2>/dev/null
        sleep 1
        echo "$SPI_DEV" > "$STM_DRIVER_PATH/bind" 2>/dev/null
        log_msg "Driver rebound: $SPI_DEV"
    fi
fi

# Method 3: Set input device to direct mode (bypass gesture filter)
for input_dev in /sys/class/input/input*; do
    name=$(cat "$input_dev/name" 2>/dev/null)
    case "$name" in
        *stm*|*STM*|*fts*|*sec_touchscreen*)
            log_msg "Found touch input: $name"
            # Disable wakeup gesture that interferes with normal touch
            echo 0 > "$input_dev/device/wakeup_gesture" 2>/dev/null
            ;;
    esac
done

log_msg "Touch fix complete"
