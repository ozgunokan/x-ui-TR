#!/bin/bash

red='\033;31m'
green='\033;32m'
yellow='\033;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Fatal error: ${plain} Please run this script with root privilege \n " && exit 1

# Check OS and set release variable
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    release=$ID
elif [[ -f /usr/lib/os-release ]]; then
    source /usr/lib/os-release
    release=$ID
else
    echo "Failed to check the system OS, please contact the author!" >&2
    exit 1
fi
echo "The OS release is: $release"

arch() {
    case "$(uname -m)" in
    x86_64 | x64 | amd64) echo 'amd64' ;;
    i*86 | x86) echo '386' ;;
    armv8* | armv8 | arm64 | aarch64) echo 'arm64' ;;
    armv7* | armv7 | arm) echo 'armv7' ;;
    armv6* | armv6) echo 'armv6' ;;
    armv5* | armv5) echo 'armv5' ;;
    s390x) echo 's390x' ;;
    *) echo -e "${green}Unsupported CPU architecture! ${plain}" && rm -f install.sh && exit 1 ;;
    esac
}

ARCH_TYPE=$(arch)
echo "arch: $ARCH_TYPE"

install_dependencies() {
    case "${release}" in
    ubuntu | debian | armbian)
        apt-get update && apt-get install -y -q wget curl tar tzdata cron
        ;;
    centos | almalinux | rocky | ol)
        yum -y update && yum install -y -q wget curl tar tzdata cronie
        ;;
    fedora | amzn)
        dnf -y update && dnf install -y -q wget curl tar tzdata cronie
        ;;
    arch | manjaro | parch)
        pacman -Syu --noconfirm wget curl tar tzdata cronie
        ;;
    opensuse-tumbleweed)
        zypper refresh && zypper -q install -y wget curl tar timezone cron
        ;;
    *)
        apt-get update && apt install -y -q wget curl tar tzdata cron
        ;;
    esac
}

gen_random_string() {
    local length="$1"
    local random_string=$(LC_ALL=C tr -dc 'a-zA-Z0-9' </dev/urandom | fold -w "$length" | head -n 1)
    echo "$random_string"
}

config_after_install() {
    local existing_username=$(/usr/local/x-ui/x-ui setting -show true | grep -Ei 'username:' | awk '{print $2}' | tr -d '\r')
    local existing_password=$(/usr/local/x-ui/x-ui setting -show true | grep -Ei 'password:' | awk '{print $2}' | tr -d '\r')
    local existing_webBasePath=$(/usr/local/x-ui/x-ui setting -show true | grep -Ei 'webBasePath:' | awk '{print $2}' | tr -d '\r')

    if [[ ${#existing_webBasePath} -lt 4 ]]; then
        if [[ "$existing_username" == "admin" && "$existing_password" == "admin" || -z "$existing_username" ]]; then
            local config_webBasePath=$(gen_random_string 15)
            local config_username=$(gen_random_string 10)
            local config_password=$(gen_random_string 10)

            read -p "Would you like to customize the Panel Port settings? (If not, random port will be applied) [y/n]: " config_confirm
            if [[ "${config_confirm}" == "y" || "${config_confirm}" == "Y" ]]; then
                read -p "Please set up the panel port: " config_port
                echo -e "${yellow}Your Panel Port is: ${config_port}${plain}"
            else
                local config_port=$(shuf -i 1024-62000 -n 1)
                echo -e "${yellow}Generated random port: ${config_port}${plain}"
            fi

            /usr/local/x-ui/x-ui setting -username "${config_username}" -password "${config_password}" -port "${config_port}" -webBasePath "${config_webBasePath}"
            echo -e "This is a fresh installation, generating random login info for security concerns:"
            echo -e "###############################################"
            echo -e "${green}Username: ${config_username}${plain}"
            echo -e "${green}Password: ${config_password}${plain}"
            echo -e "${green}Port: ${config_port}${plain}"
            echo -e "${green}WebBasePath: /${config_webBasePath}/${plain}"
            echo -e "###############################################"
            echo -e "${yellow}If you forgot your login info, you can type 'x-ui settings' to check${plain}"
        else
            local config_webBasePath=$(gen_random_string 15)
            echo -e "${yellow}WebBasePath is missing or too short. Generating a new one...${plain}"
            /usr/local/x-ui/x-ui setting -webBasePath "${config_webBasePath}"
            echo -e "${green}New WebBasePath: /${config_webBasePath}/${plain}"
        fi
    else
        if [[ "$existing_username" == "admin" && "$existing_password" == "admin" ]]; then
            local config_username=$(gen_random_string 10)
            local config_password=$(gen_random_string 10)

            echo -e "${yellow}Default credentials detected. Security update required...${plain}"
            /usr/local/x-ui/x-ui setting -username "${config_username}" -password "${config_password}"
            echo -e "Generated new random login credentials:"
            echo -e "###############################################"
            echo -e "${green}Username: ${config_username}${plain}"
            echo -e "${green}Password: ${config_password}${plain}"
            echo -e "###############################################"
            echo -e "${yellow}If you forgot your login info, you can type 'x-ui settings' to check${plain}"
        else
            echo -e "${green}Username, Password, and WebBasePath are properly set. Exiting...${plain}"
        fi
    fi

    /usr/local/x-ui/x-ui migrate
}

install_x-ui() {
    if [[ -e /usr/local/x-ui-backup/ ]]; then
        read -p "Failed installation detected. Do you want to restore previously installed version? [y/n]? " restore_confirm
        if [[ "${restore_confirm}" == "y" || "${restore_confirm}" == "Y" ]]; then
            systemctl stop x-ui
            [[ -f /usr/local/x-ui-backup/x-ui.db ]] && mv /usr/local/x-ui-backup/x-ui.db /etc/x-ui/ -f
            mv /usr/local/x-ui-backup/ /usr/local/x-ui/ -f
            systemctl start x-ui
            echo -e "${green}previous installed x-ui restored successfully${plain}, it is up and running now..."
            exit 0
        else
            echo -e "Continuing installing x-ui ..."
        fi
    fi

    cd /usr/local/

    if [ $# == 0 ]; then
        last_version=$(curl -Ls "https://api.github.com/repos/ozgunokan/x-ui/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}Failed to fetch x-ui version, it maybe due to Github API restrictions, please try it later${plain}"
            exit 1
        fi
        echo -e "Got x-ui latest version: ${last_version}, beginning the installation..."
        url="https://github.com/ozgunokan/x-ui/releases/download/${last_version}/x-ui-linux-${ARCH_TYPE}.tar.gz"
    else
        last_version=$1
        url="https://github.com/ozgunokan/x-ui/releases/download/${last_version}/x-ui-linux-${ARCH_TYPE}.tar.gz"
        echo -e "Beginning to install x-ui $1"
    fi

    wget -N --no-check-certificate -O /usr/local/x-ui-linux-${ARCH_TYPE}.tar.gz ${url}
    if [[ $? -ne 0 ]]; then
        echo -e "${red}Downloading x-ui failed, please be sure that your server can access Github ${plain}"
        exit 1
    fi

    if [[ -e /usr/local/x-ui/ ]]; then
        systemctl stop x-ui
        rm -rf /usr/local/x-ui-backup/
        mv /usr/local/x-ui/ /usr/local/x-ui-backup/ -f
        [[ -d /etc/x-ui ]] && cp -rf /etc/x-ui/x-ui.db /usr/local/x-ui-backup/ 2>/dev/null
    fi

    tar zxvf x-ui-linux-${ARCH_TYPE}.tar.gz
    rm x-ui-linux-${ARCH_TYPE}.tar.gz -f
    cd x-ui
    chmod +x x-ui

    if [[ "${ARCH_TYPE}" == "armv7" ]]; then
        if [[ -f "bin/xray-linux-armv7" ]]; then
            mv bin/xray-linux-armv7 bin/xray-linux-arm
        fi
        [[ -f "bin/xray-linux-arm" ]] && chmod +x bin/xray-linux-arm
    else
        [[ -f "bin/xray-linux-${ARCH_TYPE}" ]] && chmod +x bin/xray-linux-${ARCH_TYPE}
    fi
    
    chmod +x x-ui
    [[ -f "x-ui.service" ]] && cp -f x-ui.service /etc/systemd/system/
    
    wget --no-check-certificate -O /usr/bin/x-ui https://raw.githubusercontent.com/ozgunokan/x-ui/main/x-ui.sh
    chmod +x /usr/bin/x-ui

    config_after_install
    rm /usr/local/x-ui-backup/ -rf
    
    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui
    echo -e "${green}x-ui ${last_version}${plain} installation finished, it is up and running now..."
    echo -e ""
    echo -e "You may access the Panel with following URL(s):${yellow}"
    /usr/local/x-ui/x-ui uri
    echo -e "${plain}"
    echo "X-UI Control Menu Usage"
    echo "------------------------------------------"
    echo "SUBCOMMANDS:"
    echo "x-ui              - Admin Management Script"
    echo "x-ui start        - Start"
    echo "x-ui stop         - Stop"
    echo "x-ui restart      - Restart"
    echo "x-ui status       - Current Status"
    echo "x-ui settings     - Current Settings"
    echo "x-ui enable       - Enable Autostart on OS Startup"
    echo "x-ui disable      - Disable Autostart on OS Startup"
    echo "x-ui log          - Check Logs"
    echo "x-ui update       - Update"
    echo "x-ui install      - Install"
    echo "x-ui uninstall    - Uninstall"
    echo "x-ui help         - Control Menu Usage"
    echo "------------------------------------------"
}

echo -e "${green}Running...${plain}"
install_dependencies
install_x-ui $1
