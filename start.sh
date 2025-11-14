#!/bin/bash

shell=$SHELL
if [[ "$shell" == *"zsh"* ]]; then
    BASHRC="$HOME/.zshrc"
else
    BASHRC="$HOME/.bashrc"
fi
BASHRC_BACKUP="$HOME/.bashrc.backup"
MOTD_SCRIPT="$HOME/.my_banner.sh"

# ---------- PACKAGE CHECK ----------
check_pkg() {
    pkg="$1"
    if command -v dpkg >/dev/null 2>&1; then
        dpkg -s "$pkg" >/dev/null 2>&1
    elif command -v rpm >/dev/null 2>&1; then
        rpm -q "$pkg" >/dev/null 2>&1
    elif command -v pacman >/dev/null 2>&1; then
        pacman -Q "$pkg" >/dev/null 2>&1
    elif command -v brew >/dev/null 2>&1; then
        brew list --formula | grep -q "^$pkg\$"
    else
        command -v "$pkg" >/dev/null 2>&1
    fi
}

for pkg in figlet toilet bc wget; do
    if ! check_pkg "$pkg"; then
        echo "❌ $pkg is NOT installed!"
        echo "Install it first:"
        if command -v apt >/dev/null 2>&1; then echo "sudo apt install -y $pkg"
        elif command -v dnf >/dev/null 2>&1; then echo "sudo dnf install -y $pkg"
        elif command -v pacman >/dev/null 2>&1; then echo "sudo pacman -S $pkg"
        fi
        exit 1
    fi
done

# ---------- WRITE THE REAL MOTD SCRIPT ----------
create_motd_script() {
cat > "$MOTD_SCRIPT" << 'EOF'
#!/bin/bash

USERNAME="__USERNAME__"

# Auto terminal width
WIDTH=$(tput cols)

# Ensure figlet font
FONT="ansi-shadow.flf"
URL="https://github.com/xero/figlet-fonts/raw/refs/heads/master/ANSI%20Shadow.flf"

if [ ! -e "$HOME/$FONT" ]; then
    wget -q -O "$HOME/$FONT" "$URL"
fi

# --- CPU TEMP (Robust Auto-Detect) ---
CPU_TEMP="N/A"
best_temp=0

for zone in /sys/class/thermal/thermal_zone*; do
    type=$(cat "$zone/type" 2>/dev/null | tr -d '\n')

    # Valid CPU sensors based on your system
    if [[ "$type" == "TCPU" || "$type" == "x86_pkg_temp" ]]; then
        raw=$(cat "$zone/temp" 2>/dev/null)
        if [[ "$raw" =~ ^[0-9]+$ ]]; then
            CPU_TEMP=$(( raw / 1000 ))
            break
        fi
    fi

    # fallback: track highest valid temp
    raw=$(cat "$zone/temp" 2>/dev/null)
    if [[ "$raw" =~ ^[0-9]+$ && $raw -gt $best_temp ]]; then
        best_temp=$raw
    fi
done

# If still N/A, fallback to highest sensor
if [[ "$CPU_TEMP" == "N/A" && $best_temp -gt 0 ]]; then
    CPU_TEMP=$(( best_temp / 1000 ))
fi





# RAM
RAM_USED=$(free -h | awk '/Mem:/ {print $3 "/" $2}')

# STORAGE
STORAGE=$(df -h ~ | awk 'NR==2 {print $3 "/" $2}')

clear

echo -e "\033[1;36m"
figlet -f "$HOME/$FONT" -w "$WIDTH" "$USERNAME"
echo -e "\033[0m"

echo -e "\033[1;33m   Welcome, \033[1;32m$USERNAME\033[0m\n"
echo -e "\033[1;36m   CPU Temp      : \033[1;32m${CPU_TEMP}°C\033[0m"
echo -e "\033[1;36m   RAM Usage     : \033[1;32m${RAM_USED}\033[0m"
echo -e "\033[1;36m   Storage Usage : \033[1;32m${STORAGE}\033[0m\n"

# ┌────── box ──────┐ auto resize
LINE="  $USERNAME Online ✓  "
LEN=${#LINE}
BORDER=$(printf '─%.0s' $(seq 1 $LEN))

echo -e "\033[1;35m┌$BORDER┐"
echo -e "│$LINE│"
echo -e "└$BORDER┘\033[0m\n"

echo -e "\033[1;36m➤ \033[1;32mStay focused. Stay curious. Stay unstoppable.\033[0m\n"
EOF
chmod +x "$MOTD_SCRIPT"
}

# ---------- INSTALL ----------
install_banner() {
    read -p "Enter your preferred username: " USERNAME
    [[ -z "$USERNAME" ]] && echo "Invalid name!" && exit

    create_motd_script
    sed -i "s/__USERNAME__/$USERNAME/g" "$MOTD_SCRIPT"

    if [[ ! -f "$BASHRC_BACKUP" ]]; then
        cp "$BASHRC" "$BASHRC_BACKUP"
    fi

    if ! grep -qxF "bash $MOTD_SCRIPT" "$BASHRC"; then
        echo "bash $MOTD_SCRIPT" >> "$BASHRC"
    fi

    echo "✔ Installed. Restarting Your terminal."
    sleep 2
    source "$BASHRC"
    exit

}

# ---------- UNINSTALL ----------
uninstall_banner() {
    sed -i "\|$MOTD_SCRIPT|d" "$BASHRC"
    rm -f "$MOTD_SCRIPT"
    echo "✔ Removed banner."
}

# ---------- PREVIEW ----------
preview_banner() {
    read -p "Enter username for preview: " NAME
    sed "s/__USERNAME__/$NAME/g" "$MOTD_SCRIPT" | bash
}

# ---------- MENU ----------
while true; do
    clear
    echo "========== Banner Installer =========="
    echo "1) Install Banner"
    echo "2) Preview Banner"
    echo "3) Uninstall / Restore"
    echo "4) Exit"
    echo "======================================"
    read -p "Choose an option: " opt

    case "$opt" in
        1) install_banner ;;
        2) preview_banner ;;
        3) uninstall_banner ;;
        4) exit 0 ;;
        *) echo "Invalid!" ;;
    esac

    read -p "Press Enter..."
done
