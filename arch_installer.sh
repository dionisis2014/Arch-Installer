#!/bin/bash

#   Arch Linux install script created by dionisis2014
#
#   User takes full responsibility for any damage
#   done to the system by the usage of this script

RST="\033[0;0m"
BOLD="\033[1m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
MAGENTA="\033[35m"

EFI_SET=1
HOSTNAME=""
USERNAME=""

function question () {
    local answer
    read -r answer
    if [[ ${answer} =~ ^([yY]|([yY][eE][sS]))?$ ]]
    then
        return 0
    else
        return 1
    fi
}

function question_exit () {
    question
    if [[ $? == 0 ]]
    then
        return 0
    else
        printf "${BOLD}${RED}$1${RST}\n"
        exit 1
    fi
}

printf "${BOLD}${BLUE}Arch Linux${RST}${BOLD} installation script by${GREEN} dionisis2014${RST}\n"
echo

printf "${BOLD}${MAGENTA}Step 1: Answer questions about installation below${RST}\n"
printf "${BOLD}${YELLOW}Are you ready to procced? [Y/N]: ${RST}"
question_exit "Aborted installation!"

while true
do
    printf "${BOLD}${YELLOW}Enter hostname: ${RST}"
    read -r response
    if [[ ${response} =~ ^([a-zA-Z0-9.-_]+)$ ]]
    then
        HOSTNAME=$response
        break
    else
        printf "${BOLD}${RED}Hostname ${RST}${BOLD}\"${response}\"${RED} is invalid!${RST}\n"
    fi
done

while true
do
    printf "${BOLD}${YELLOW}Enter username: ${RST}"
    read -r response
    if [[ ${response} =~ ^([a-zA-Z0-9.-_]+)$ ]]
    then
        USERNAME=$response
        break
    else
        printf "${BOLD}${RED}Username ${RST}${BOLD}\"${response}\"${RED} is invalid!${RST}\n"
    fi
done

if [[ -d /sys/firmware/efi ]]
then
    printf "${BOLD}${BLUE}Detected that system is running under UEFI${RST}\n"
    printf "${BOLD}${YELLOW}Would you like to install for UEFI? [Y/N]: ${RST}"
    question
    EFI_SET=$?
fi

printf "${BOLD}${BLUE}Installation configuration:${RST}\n"
printf "\tInstall for UEFI:\t "
if [[ ${EFI_SET} == 0 ]]
then
    printf "${GREEN}true${RST}\n"
else
    printf "${RED}false${RST}\n"
fi
printf "\tHostname:\t\t $HOSTNAME\n"
printf "\tUsername:\t\t $USERNAME\n"
echo

printf "${BOLD}${MAGENTA}Step 2: Select drive to install to${RST}\n"
printf "${BOLD}${YELLOW}Are you ready to procced? [Y/N]: ${RST}"
question_exit "Aborted installation!"

DISKS=( $(lsblk -d -i -l -n -p | cut -d' ' -f1) )
printf "${BOLD}${BLUE}Available disks:${RST}\n"
for disk in ${DISKS[@]}
do
    printf "\t${disk}\n"
done
DISK=""
while true
do
    printf "${BOLD}${YELLOW}Please select a disk from above: ${RST}"
    read -r response
    if [[ " ${DISKS[@]} " =~ " ${response} " ]]
    then
    DISK=$response
        break
    else
        printf "${DISKS[*]}\n"
        printf "${BOLD}${RED}Drive ${RST}${BOLD}\"${response}\"${RED} doesn't exist!${RST}\n"
    fi
done
echo

printf "${BOLD}${MAGENTA}Step 3: Installation${RST}\n"
printf "${BOLD}${YELLOW}Are you ready to procced? [Y/N]: ${RST}"
question_exit "Aborted installation!"

printf "${BOLD}${BLUE}Running DHCPCD ...${RST}\n"
dhcpcd
printf "${BOLD}${BLUE}Enabling NTP ...${RST}\n"
timedatectl set-ntp true
printf "${BOLD}${BLUE}Formatting drive ...${RST}\n"
if [[ $EFI_SET == 0 ]]
then
    fdisk ${DISK} << EOF
g
n


+500M
n



w
EOF
    mkfs.fat -F -F -F32 "${DISK}1"
    mkfs.ext4 -F -F "${DISK}2"
else
    fdisk ${DISK} << EOF
g
n



w
EOF
    mkfs.ext4 -F -F "${DISK}1"
fi
printf "${BOLD}${BLUE}Mounting filesystem ...${RST}\n"
if [[ $EFI_SET == 0 ]]
then
    mount "${DISK}2" /mnt
else
    mount "${DISK}1" /mnt
fi
printf "${BOLD}${BLUE}Updating pacman databases ...${RST}\n"
pacman -Sy
printf "${BOLD}${BLUE}Installing archlinux-keyring ...${RST}\n"
pacman -S --noconfirm archlinux-keyring
printf "${BOLD}${BLUE}Installing base packages ...${RST}\n"
pacstrap /mnt base linux linux-firmware nano reflector sudo git base-devel wget bash bash-completion openssh ntp networkmanager dhcpcd grub archlinux-keyring
printf "${BOLD}${BLUE}Generating FSTAB ...${RST}\n"
genfstab -U /mnt >> /mnt/etc/fstab
printf "${BOLD}${BLUE}Setting locale ...${RST}\n"
arch-chroot /mnt ln -sf /usr/share/zoneinfo/Europe/Athens /etc/localtime
printf "${BOLD}${BLUE}Setting hardware clock from system time ...${RST}\n"
arch-chroot /mnt hwclock --systohc
printf "${BOLD}${BLUE}Generating locales ...${RST}\n"
arch-chroot /mnt sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
arch-chroot /mnt locale-gen
arch-chroot /mnt echo LANG=en_US.UTF-8 >> /etc/locale.conf
printf "${BOLD}${BLUE}Generating hostname and hosts file ...${RST}\n"
arch-chroot /mnt echo ${HOSTNAME} > /etc/hostname
arch-chroot /mnt printf "\n127.0.0.1\t\tlocalhost\n::1\t\t\tlocalhost\n127.0.1.1\t${HOSTNAME}.localdomain\t${HOSTNAME}\n" >> /etc/hosts
printf "${BOLD}${BLUE}Setting root password ...${RST}\n"
arch-chroot /mnt passwd
printf "${BOLD}${BLUE}Installing CPU microcode ...${RST}\n"
if [[ $( cat /proc/cpuinfo | grep -m 1 "^vendor_id" | cut -d' ' -f2 ) =~ "GenuineIntel" ]]
then
    arch-chroot /mnt pacman -S --noconfirm intel-ucode
else
    arch-chroot /mnt pacman -S --noconfirm amd-ucode
fi
printf "${BOLD}${BLUE}Enabling systemd services ...${RST}\n"
arch-chroot /mnt systemctl enable sshd
arch-chroot /mnt systemctl enable ntpd
arch-chroot /mnt systemctl enable NetworkManager
printf "${BOLD}${BLUE}Enabling wheel group ...${RST}\n"
arch-chroot /mnt sed -i 's/^# %wheel ALL=(ALL) ALL/ %wheel ALL=(ALL) ALL/' /etc/sudoers
printf "${BOLD}${BLUE}Adding new user ...${RST}\n"
arch-chroot /mnt useradd -m -g users -G wheel -s /bin/bash "$USERNAME"
printf "${BOLD}${BLUE}Setting user password ...${RST}\n"
arch-chroot /mnt passwd "$USERNAME"
if [[ EFI_SET == 0 ]]
then
    printf "${BOLD}${BLUE}Installing bootloader for UEFI ...${RST}\n"
    arch-chroot /mnt pacman -S --noconfirm efibootmgr
    arch-chroot /mnt mkdir /efi
    arch-chroot /mnt mount "$DISK1" /efi
    arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=efi --bootloader-id=GRUB
else
    printf "${BOLD}${BLUE}Installing bootloader ...${RST}\n"
    arch-chroot /mnt grub-install "$DISK"
fi
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

printf "${BOLD}${GREEN}Installation script finished successfully!${RST}\n"
