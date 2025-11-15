#!/bin/bash

# ULTIMATE RESPONSIVE TERMINAL DEMO
# Shows off adaptive layouts, animations, and real-time responsiveness

# Enable UTF-8
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Terminal control sequences
declare -A ESC=(
    [CLEAR]='\033[2J'
    [HOME]='\033[H'
    [HIDE_CURSOR]='\033[?25l'
    [SHOW_CURSOR]='\033[?25h'
    [ALT_SCREEN]='\033[?1049h'
    [NORMAL_SCREEN]='\033[?1049l'
    [BOLD]='\033[1m'
    [DIM]='\033[2m'
    [RESET]='\033[0m'
)

# 256 color support
color256() {
    echo -ne "\033[38;5;${1}m"
}

bg256() {
    echo -ne "\033[48;5;${1}m"
}

# RGB color support (if terminal supports it)
rgb() {
    echo -ne "\033[38;2;${1};${2};${3}m"
}

# Global state
WIDTH=0
HEIGHT=0
FRAME=0
RUNNING=1

# Get terminal size
update_size() {
    WIDTH=$(tput cols)
    HEIGHT=$(tput lines)
}

# Move cursor
move() {
    tput cup $1 $2
}

# Draw at position with color
draw_at() {
    local y=$1 x=$2 text=$3 color=$4
    move $y $x
    [ -n "$color" ] && color256 "$color"
    echo -n "$text"
    echo -ne "${ESC[RESET]}"
}

# Create gradient text
gradient_text() {
    local text="$1"
    local start_color=$2
    local length=${#text}

    for ((i=0; i<length; i++)); do
        local color=$((start_color + i % 100))
        color256 $color
        echo -n "${text:$i:1}"
    done
    echo -ne "${ESC[RESET]}"
}

# Draw animated title
draw_title() {
    local title="╔══════════════════════════════════════════════════════════════╗"
    local title2="║     ULTRA RESPONSIVE TERMINAL DASHBOARD - CLAUDE CODE      ║"
    local title3="╚══════════════════════════════════════════════════════════════╝"

    # Center title
    local start_x=$(( (WIDTH - 64) / 2 ))
    [ $start_x -lt 0 ] && start_x=0

    # Animated rainbow effect
    local color=$((51 + (FRAME % 200)))

    move 0 $start_x
    color256 $color
    echo -n "${title:0:$WIDTH}"

    move 1 $start_x
    color256 $((color + 20))
    echo -ne "${ESC[BOLD]}"
    echo -n "${title2:0:$WIDTH}"
    echo -ne "${ESC[RESET]}"

    move 2 $start_x
    color256 $color
    echo -n "${title3:0:$WIDTH}"
    echo -ne "${ESC[RESET]}"
}

# Draw live size indicator
draw_size_indicator() {
    local y=4
    local size_text="Terminal Size: ${WIDTH} × ${HEIGHT}"
    local x=$(( (WIDTH - ${#size_text}) / 2 ))
    [ $x -lt 0 ] && x=0

    draw_at $y $x "$size_text" 226
}

# Draw animated bars
draw_bars() {
    local start_y=6
    local bar_height=$((HEIGHT - 12))
    [ $bar_height -lt 5 ] && bar_height=5
    [ $bar_height -gt 20 ] && bar_height=20

    local num_bars=$((WIDTH / 6))
    [ $num_bars -gt 30 ] && num_bars=30

    for ((i=0; i<num_bars; i++)); do
        local height=$((1 + (FRAME + i * 7) % bar_height))
        local x=$((i * 6 + 2))

        # Choose color based on height
        local color
        if [ $height -lt $((bar_height / 3)) ]; then
            color=46  # Green
        elif [ $height -lt $((bar_height * 2 / 3)) ]; then
            color=226 # Yellow
        else
            color=196 # Red
        fi

        # Draw bar from bottom up
        for ((j=0; j<height; j++)); do
            local y=$((start_y + bar_height - j - 1))
            draw_at $y $x "███" $color
        done
    done

    # Label
    move $((start_y + bar_height + 1)) $((WIDTH / 2 - 15))
    color256 51
    echo -n "Real-time Animated Visualization"
    echo -ne "${ESC[RESET]}"
}

# Draw spinning loader
draw_loader() {
    local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    local idx=$((FRAME % ${#frames[@]}))
    local y=$((HEIGHT - 8))
    local x=$((WIDTH / 2 - 10))

    draw_at $y $x "Processing: ${frames[$idx]}" 51
}

# Draw responsive grid
draw_grid() {
    local grid_y=$((HEIGHT - 6))
    [ $grid_y -lt 10 ] && grid_y=10

    local boxes=$((WIDTH / 25))
    [ $boxes -lt 1 ] && boxes=1
    [ $boxes -gt 10 ] && boxes=10

    local box_width=$((WIDTH / boxes - 2))
    [ $box_width -lt 10 ] && box_width=10

    for ((i=0; i<boxes; i++)); do
        local x=$((i * (box_width + 2) + 1))
        local color=$((33 + i * 20))

        # Top border
        draw_at $grid_y $x "┌$(printf '─%.0s' $(seq 1 $((box_width - 2))))┐" $color

        # Content
        local value=$((RANDOM % 100))
        local content=$(printf "Box%d:%2d%%" $((i+1)) $value)
        draw_at $((grid_y + 1)) $((x + 1)) "$(printf '%-*s' $((box_width - 2)) "$content")" $color

        # Bottom border
        draw_at $((grid_y + 2)) $x "└$(printf '─%.0s' $(seq 1 $((box_width - 2))))┘" $color
    done
}

# Draw instructions
draw_instructions() {
    local y=$((HEIGHT - 2))

    # Clear line first
    move $y 0
    printf "%${WIDTH}s" " "

    local text="Press 'q' or Ctrl+C to quit • Resize your terminal to see magic! ✨"
    local x=$(( (WIDTH - ${#text}) / 2 ))
    [ $x -lt 0 ] && x=0

    move $y $x
    echo -ne "${ESC[BOLD]}"
    color256 46
    echo -n "$text"
    echo -ne "${ESC[RESET]}"

    # Status line
    move $((HEIGHT - 1)) 0
    bg256 235
    printf "%${WIDTH}s" " "

    move $((HEIGHT - 1)) 1
    color256 51
    echo -n "⚡ FPS: $((FRAME % 60)) | Frame: $FRAME | Status: RUNNING"

    move $((HEIGHT - 1)) $((WIDTH - 25))
    color256 226
    echo -n "$(date '+%H:%M:%S')"
    echo -ne "${ESC[RESET]}"
}

# Draw wave pattern
draw_wave() {
    local y=$((HEIGHT / 2))
    local amplitude=3
    local frequency=0.5

    for ((x=0; x<WIDTH; x++)); do
        local offset=$(echo "scale=2; s(($x + $FRAME) * $frequency / 10) * $amplitude" | bc -l)
        offset=$(printf "%.0f" "$offset")
        local wave_y=$((y + offset))

        if [ $wave_y -ge 6 ] && [ $wave_y -lt $((HEIGHT - 8)) ]; then
            local color=$((51 + (x + FRAME) % 180))
            draw_at $wave_y $x "~" $color
        fi
    done
}

# Main render function
render() {
    update_size

    # Clear screen
    echo -ne "${ESC[CLEAR]}${ESC[HOME]}"

    # Draw all elements
    draw_title
    draw_size_indicator
    draw_bars
    draw_wave
    draw_loader
    draw_grid
    draw_instructions

    ((FRAME++))
}

# Handle resize
handle_resize() {
    update_size
}

# Handle input
handle_input() {
    local key
    # Use IFS= and read with timeout, check if read succeeds
    if IFS= read -rsn1 -t 0.05 key 2>/dev/null; then
        case "$key" in
            q|Q)
                RUNNING=0
                ;;
            $'\e')
                # Escape key
                RUNNING=0
                ;;
        esac
    fi
}

# Cleanup
cleanup() {
    RUNNING=0
    # Restore terminal state
    stty sane 2>/dev/null
    tput cnorm 2>/dev/null
    echo -ne "${ESC[SHOW_CURSOR]}${ESC[NORMAL_SCREEN]}${ESC[CLEAR]}${ESC[HOME]}"
    echo ""
    echo -e "\033[38;5;46m✓ Thank you for watching the demo!\033[0m"
    echo -e "\033[38;5;51m  This demo shows adaptive terminal layouts that respond to resize events.\033[0m"
    echo ""
    exit 0
}

# Main loop
main() {
    # Setup
    trap cleanup EXIT INT TERM
    trap handle_resize WINCH

    # Hide cursor and switch to alternate screen
    stty -echo 2>/dev/null
    tput civis 2>/dev/null
    echo -ne "${ESC[ALT_SCREEN]}${ESC[HIDE_CURSOR]}"

    # Initial size
    update_size

    # Animation loop
    while [ $RUNNING -eq 1 ]; do
        render
        handle_input

        # Check if we should exit
        [ $RUNNING -eq 0 ] && break

        sleep 0.05  # ~20 FPS
    done

    cleanup
}

# Check if bc is available for wave calculations
if ! command -v bc &> /dev/null; then
    # Simple version without wave
    draw_wave() { :; }
fi

# Run!
main
