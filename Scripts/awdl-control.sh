#!/bin/bash
# WiFi Boost - AWDL Control Script
# This script manages AWDL state and is called by the Control Center widget

case "$1" in
    status)
        # Check if AWDL is running (UP and RUNNING in flags)
        if ifconfig awdl0 2>/dev/null | head -1 | grep -q "RUNNING"; then
            echo "on"
        else
            echo "off"
        fi
        ;;
    on)
        sudo /sbin/ifconfig awdl0 up
        echo "on"
        ;;
    off)
        sudo /sbin/ifconfig awdl0 down
        echo "off"
        ;;
    toggle)
        if ifconfig awdl0 2>/dev/null | head -1 | grep -q "RUNNING"; then
            sudo /sbin/ifconfig awdl0 down
            echo "off"
        else
            sudo /sbin/ifconfig awdl0 up
            echo "on"
        fi
        ;;
    *)
        echo "Usage: $0 {status|on|off|toggle}"
        exit 1
        ;;
esac
