#!/bin/bash

#Arch Linux automated install script by dionisis2014

C_RESET="\033[0m"
C_RED="\033[31m"
C_GREEN="\033[32m"
C_BLUE="\033[34m"
C_CYAN="\033[36m"
C_YELLOW="\033[33m"

M_RESET="\033[0m"
M_BOLD="\033[1m"

if [ $(whoami) != "root" ]
then
    printf "${C_RED}Script must be run as root! Aborted installation!${C_RESET}\n"
    exit 1
fi

printf "${M_BOLD}${C_CYAN}Arch Linux${C_RESET}${M_BOLD} automated install by ${C_GREEN}dionisis2014${C_RESET}\n\n"
printf "${C_YELLOW}Start installation? [Y/N]: ${C_RESET}"
read -r response
if [[ ! $response =~ ^(([yY]|([yY][eE][sS])))$ && ! $response =~ ^$ ]]
then
    printf "${C_RED}Aborted installation!${C_RESET}\n"
    exit 2
fi
echo

#NETWORKING
printf "${C_BLUE}${M_BOLD}Establishing DHCP connection ...${C_RESET}\n"
dhcpcd
echo
printf "${C_BLUE}${M_BOLD}Testing connection ...${C_RESET}\n"
if ping -q -c 5 -W 1 8.8.8.8 > /dev/null
then
    printf "${C_GREEN}Connection established${C_RESET}\n"
else
    printf "${C_RED}Connection failed! Aborted installation!${C_RESET}\n"
    exit 3
fi
echo

#TIME
printf "${C_BLUE}${M_BOLD}Setting NTP ...${C_RESET}\n"
timedatectl set-ntp true
echo

#PARTITIONING
efi=false
if [ -d "/sys/firmware/efi" ]
then
    printf "${C_BLUE}${M_BOLD}Running in EFI mode${C_RESET}\n"
    efi=true
fi
printf "${C_BLUE}{M_BOLD}Getting all available disks ...${C_RESET}\n"
disks=( $(lsblk -d -l -n | cut -d' ' -f1 | grep -E "[^loop^tmp^run]+") )
printf "${M_BOLD}Found disks:${C_RESET}\n"
printf "  %s\n" ${disks[@]}

while true
do
    printf "${C_YELLOW}Select disk to format:${C_RESET} "
    read -r disk
    if [[ " ${disks[@]} " =~ " $disk " ]]
    then
        printf "${C_YELLOW}Selected disk ${C_RESET}\"$disk\"\n"
        break
    else
        printf "${C_RED}Selected disk ${C_RESET}\"$disk\"${C_RED} doesn't exist!${C_RESET}\n"
    fi
done

while true
do
    printf "${C_BLUE}${M_BOLD}Opening cfdisk ...${C_RESET}\n"
    cfdisk /dev/$disk
    printf "${C_BLUE}${M_BOLD}Continue with installation? [Y/N]: ${C_RESET}"
    read -r response
    if [[ $response =~ ^(([yY]|([yY][eE][sS])))$ || $response =~ ^$ ]]
    then
        break
    fi
done

printf "${C_BLUE}${M_BOLD}Opening new shell to format partitions. Type \"exit\" to continue installation.${C_RESET}\n"
bash
printf "${C_BLUE}${M_BOLD}Opening new shell to mount partitions to \"/mnt\"."
if [ efi == true ]
then
    printf " Mount EFI partition to \"/mnt/efi\"."
fi
printf "Type exit to continue installation.${C_RESET}\n"
bash

#INSTALLATION
printf "${C_BLUE}${M_BOLD}Updating pacman databases ...${C_RESET}\n"
pacman -Sy
printf "${C_BLUE}${M_BOLD}Installing archlinux-keyring ...${C_RESET}\n"
pacman -S --noconfirm archlinux-keyring
printf "${C_BLUE}${M_BOLD}Installing base system ...${C_RESET}\n"
pacstrap /mnt linux linux-firmware nano reflector sudo git base-devel wget bash-completion openssh ntp bash networkmanager grub archlinux-keyring
printf "${C_BLUE}${M_BOLD}Generating fstab ...${C_RESET}\n"
genfstab -U /mnt >> /mnt/etc/fstab

printf "${C_BLUE}${M_BOLD}Creating script file for arch-chroot environment ...${C_RESET}\n"
cat > "/mnt/tmp/script.sh" << EOF
#!/bin/bash

#Arch Linux automated install script by dionisis2014

C_RESET="\033[0m"
C_RED="\033[31m"
C_GREEN="\033[32m"
C_BLUE="\033[34m"
C_CYAN="\033[36m"
C_YELLOW="\033[33m"

M_RESET="\033[0m"
M_BOLD="\033[1m"

#CONFIGURATION
printf "\${C_BLUE}\${M_BOLD}Setting time zone ...\${C_RESET}\n"
ln -sf /usr/share/zoneinfo/Europe/Athens /etc/localtime
printf "\${C_BLUE}\${M_BOLD}Setting clock RTC from system time ...\${C_RESET}\n"
hwclock --systohc
printf "\${C_BLUE}\${M_BOLD}Setting locale to \${C_YELLOW}en_US.UTF-8\${C_BLUE} ...\${C_RESET}\n"
sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
echo LANG=en_US.UTF-8 >> /etc/locale.conf
printf "\${C_BLUE}\${M_BOLD}Generating locales ...\${C_RESET}\n"
locale-gen
printf "\${C_YELLOW}\${M_BOLD}Enter hostname: \${C_RESET}\n"
read -r name
echo "\$name" >> /etc/hostname
printf "\${C_BLUE}\${M_BOLD}Generating hosts file ...\${C_RESET}\n"
printf "\n127.0.0.1\tlocalhost\n::1\t\t\tlocalhost\n127.0.1.1\t\${name}.localdomain\t\${name}\n" >> /etc/hosts
printf "\${C_YELLOW}\${M_BOLD}Setting root password ...\${C_RESET}\n"
passwd
printf "\${C_BLUE}\${M_BOLD}Installing CPU ucode ...\${C_RESET}\n"
model=\$(cat /proc/cpuinfo | grep -m 1 "^vendor_id.*:" | cut -d' ' -f2)
if [ "\$model" == "GenuineIntel" ]
then
    pacman -S --noconfirm intel-ucode
else
    pacman -S --noconfirm amd-ucode
fi
printf "\${C_BLUE}\${M_BOLD}Enabling services ...\${C_RESET}\n"
systemctl enable sshd
systemctl enable ntpd
systemctl enable NetworkManager
printf "\${C_BLUE}\${M_BOLD}Enabling wheel group ...\${C_RESET}\n"
sed -i 's/^# %wheel ALL=(ALL) ALL/ %wheel ALL=(ALL) ALL/' /etc/locale.gen
while true
do
    printf "\${C_YELLOW}\${M_BOLD}Enter new user name: \${C_RESET}\n"
    read -r user
    if [[ "\$user" =~ ^([A-Za-z0-9._-]+)\$ ]]
    then
        break
    else
       printf "\${C_RED}Selected username \${C_RESET}\"\$user\"\${C_RED} is invalid!\${C_RESET}\n"
    fi
done
useradd -m -g users -G wheel -s /bin/bash "\$user"
printf "\${C_YELLOW}\${M_BOLD}Setting user password ...\${C_RESET}\n"
passwd "\$user"
printf "\${C_BLUE}\${M_BOLD}Installing boot loader ...\${C_RESET}\n"
if [ -d "/efi" ]
then
    pacman -S --noconfirm efibootmgr
    grub-install --target=x86_64-efi --efi-directory=efi --bootloader-id=GRUB
else
    printf "\${C_BLUE}\${M_BOLD}Opening new shell to install bootloader. Type \"grub-install /dev/<disk>\" and then exit to continue installation.\${C_RESET}\n"
    bash
    grub-mkconfig -o /boot/grub/grub.cfg
fi
EOF
chmod +x "/mnt/tmp/script.sh"
printf "${C_BLUE}${M_BOLD}Entering arch-chroot ...${C_RESET}\n"
arch-chroot /mnt "/mnt/tmp/$0"
sh "/mnt/tmp/script.sh"
if [ $? ]
then
    printf "${C_RED}Subscript failed! Aborted installation!${C_RESET}\n"
    exit 4
fi

printf "${C_GREEN}${M_BOLD}Installation finished! Shutdown computer and remove live media.\n"
