#!/bin/bash
LOCK_FILE="/var/lib/dpkg/lock-frontend"
LOCK_FILE2="/var/lib/apt/lists/lock"

check_and_kill_lock() {
    for lock in "$LOCK_FILE" "$LOCK_FILE2"; do
        if sudo fuser "$lock" &>/dev/null; then
            echo "🔒 Lock file $lock is in use."
            PID=$(sudo fuser "$lock" 2>/dev/null)
            echo "➡️  Process holding the lock: PID $PID"

            sudo kill -9 $PID
            echo "✅ Process $PID killed."            
        else
            echo "✅ Lock file $lock is free."
        fi
    done
}

fix_dpkg_if_needed() {
    echo "🔧 Running 'sudo dpkg --configure -a' to fix interrupted installations..."
    sudo dpkg --configure -a
    echo "✅ Done."
}

check_and_kill_lock
sleep 2
fix_dpkg_if_needed

# Define Colors
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
NC="\033[0m" 

# Define Tasks
tasks=("Update and Upgrade System 🛠️"
       "Remove Existing XAMPP 🗑️"
       "Remove Existing Apache2 🗑️"
       "Install Apache2 🌐"
       "Check MySQL Installation 🗄️"
       "Remove MySQL Server 🗑️"
       "Install MySQL Server 🗄️"
       "Secure MySQL Server 🔒"
       "Test MySQL Server 🗄️"
       "Check PHP Installation 🧩"
       "Install PHP 🧩"
       "Install phpMyAdmin 🛠️")

task_status=() 
for _ in "${tasks[@]}"; do
    task_status+=("Pending")
done

# Function to render the terminal screen
render_screen() {
    clear
    echo -e "${BLUE}========================================${NC}"
    echo -e "${YELLOW}    🚀 LAMP Stack Installation 🚀     ${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo
    for i in "${!tasks[@]}"; do
        if [ "${task_status[$i]}" == "Done" ]; then
            echo -e "${GREEN}[✔] ${tasks[$i]}${NC}"
        elif [ "${task_status[$i]}" == "Failed" ]; then
            echo -e "${RED}[✘] ${tasks[$i]}${NC}"
        elif [ "${task_status[$i]}" == "In Progress" ]; then
            echo -e "${BLUE}[🔄] ${tasks[$i]}${NC}"
        else
            echo -e "${YELLOW}[ ] ${tasks[$i]}${NC}"
        fi
    done
    echo
    echo -e "${BLUE}========================================${NC}"
    echo
}

# Function to update task status
update_task_status() {
    task_status[$1]=$2
    render_screen
    sleep 1
}

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ Please run this script as root or use sudo!${NC}"
    exit 1
fi

# Start Installation
render_screen

# 1. Update and Upgrade System
update_task_status 0 "In Progress"
lsb_release -a

sudo apt-get update -y  && sudo apt-get upgrade -y --assume-yes  
if [ $? -eq 0 ]; then
    update_task_status 0 "Done"
else
    update_task_status 0 "Failed"
    exit 1
fi

# 2. Remove Existing XAMPP
update_task_status 1 "In Progress"
if [ -d "/opt/lampp" ]; then
    sudo /opt/lampp/uninstall >/dev/null 2>&1
    sudo rm -rf /opt/lampp/ >/dev/null 2>&1
    update_task_status 1 "Done"
else
    update_task_status 1 "Done"
fi

# 3. Remove Existing Apache2
update_task_status 2 "In Progress"
if systemctl status apache 2>/dev/null 2>&1; then
    sudo apt-get remove --purge apache2 -y >/dev/null 2>&1
    sudo apt-get autoremove -y >/dev/null 2>&1
    sudo apt-get autoclean -y >/dev/null 2>&1
    update_task_status 2 "Done"
else
    update_task_status 2 "Done"
fi

# 4. Install Apache2
update_task_status 3 "In Progress"
sudo apt-get install apache2 -y 
if [ $? -eq 0 ]; then
    sudo ufw allow 'Apache' >/dev/null 2>&1
    sudo ufw enable >/dev/null 2>&1
    sudo systemctl restart apache2 >/dev/null 2>&1
    update_task_status 3 "Done"
else
    update_task_status 3 "Failed"
    exit 1
fi

# 5. Check MySQL Installation
update_task_status 4 "In Progress"
if dpkg --get-selections | grep -q mysql; then
    print_status "MySQL is installed. Proceeding to removal."
    update_task_status 4 "Done"
else
    print_status "No MySQL installation found."
    update_task_status 4 "Done"
fi

# 6. Remove MySQL Server
update_task_status 5 "In Progress"
sudo apt-get remove --purge -y '*mysql*'
sudo apt-get autoremove -y >/dev/null 2>&1
sudo apt-get autoclean -y >/dev/null 2>&1
update_task_status 5 "Done"

# 7. Install MySQL Server
update_task_status 6 "In Progress"
sudo apt-get install mysql-server -y 
if [ $? -eq 0 ]; then
    update_task_status 6 "Done"
else
    update_task_status 6 "Failed"
    exit 1
fi

# 8. Secure MySQL Server
update_task_status 7 "In Progress"
sudo apt-get install -y expect >/dev/null 2>&1
SECURE_MYSQL=$(expect -c "
set timeout 1
spawn sudo mysql_secure_installation
expect \"VALIDATE PASSWORD plugin?\"
send \"y\r\"
expect \"Please enter 0 = LOW, 1 = MEDIUM and 2 = STRONG\"
send \"0\r\"
expect \"New password:\"
send \"Ufaz_2019\r\"
expect \"Re-enter new password:\"
send \"Ufaz_2019\r\"
expect \"Remove anonymous users?\"
send \"y\r\"
expect \"Disallow root login remotely?\"
send \"y\r\"
expect \"Remove test database and access to it?\"
send \"n\r\"
expect \"Reload privilege tables now?\"
send \"y\r\"
expect eof
")
echo "$SECURE_MYSQL"
update_task_status 7 "Done"

# 9. Test MySQL Server
update_task_status 8 "In Progress"
sudo mysql -u root -pUfaz_2019 -e "CREATE DATABASE IF NOT EXISTS UFAZ;ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'Ufaz_2019';
FLUSH PRIVILEGES;
" >/dev/null 2>&1

sudo systemctl restart mysql >/dev/null 2>&1

if [ $? -eq 0 ]; then
    update_task_status 8 "Done"
else
    update_task_status 8 "Failed"
    exit 1
fi

# 10. Check PHP Installation
update_task_status 9 "In Progress"
if php -v >/dev/null 2>&1; then
    sudo apt-get remove --purge -y '*php*' >/dev/null 2>&1
    sudo apt-get autoremove -y >/dev/null 2>&1
    sudo apt-get autoclean -y >/dev/null 2>&1
    update_task_status 9 "Done"
else
    update_task_status 9 "Done"
fi

# 11. Install PHP
update_task_status 10 "In Progress"
sudo apt-get install php libapache2-mod-php -y 
if [ $? -eq 0 ]; then
    echo "<?php phpinfo(); ?>" | sudo tee /var/www/html/info.php >/dev/null
    sudo systemctl restart apache2 >/dev/null 2>&1
    update_task_status 10 "Done"
else
    update_task_status 10 "Failed"
    exit 1
fi

# 12. Install phpMyAdmin
update_task_status 11 "In Progress"
sudo apt-get install phpmyadmin -y
if [ $? -eq 0 ]; then
    update_task_status 11 "Done"
else
    update_task_status 11 "Failed"
    exit 1
fi

sudo ln -s /usr/share/phpmyadmin /var/www/html/phpmyadmin >/dev/null 2>&1

# Completion Message and Usage Instructions
render_screen
echo -e "${GREEN}🎉 LAMP Stack Installation Complete! 🎉${NC}"
echo
echo -e "${BLUE}========================================${NC}"
echo -e "${YELLOW}        How to Use LAMP Stack         ${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "🌐 ${GREEN}Apache2:${NC} Visit ${YELLOW}http://localhost${NC} to check if Apache is running."
echo -e "🗄️ ${GREEN}MySQL:${NC} Use ${YELLOW}mysql -u root -p${NC} to access the MySQL console."
echo -e "🧩 ${GREEN}PHP:${NC} Visit ${YELLOW}http://localhost/info.php${NC} to verify PHP installation."
echo -e "🛠️ ${GREEN}phpMyAdmin:${NC} Access phpMyAdmin at ${YELLOW}http://localhost/phpmyadmin${NC}."
echo -e "    Default login is ${YELLOW}root${NC}, and use the MySQL password set during installation. (Ufaz_2019)"
echo
echo -e "${BLUE}========================================${NC}"
echo
echo -e "🙏 ${GREEN}If you found this script helpful, follow me on GitHub: ${YELLOW}https://github.com/martian58${NC} 🙌"
echo -e "🛠️ ${GREEN}If you found bugs you can always contribute or create issues.${NC}"
echo
echo -e "${BLUE}========================================${NC}"
echo -e "${YELLOW}Thank you! 🚀${NC}"