#!/bin/bash

waybar &
disown
echo "my dingus my dingus"

pkill waybar && waybar &
disown
