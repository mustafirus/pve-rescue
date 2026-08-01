# PVE Rescue

Інструмент для збірки мінімального завантажувального rescue-образу для серверів Proxmox VE.

## Що будується

```
pve_output/
  pve-rescue.kernel    # Ядро Proxmox (vmlinuz)
  pve-rescue.initrd    # Мінімальний initramfs (busybox + модулі)
  pve-rescue.squashfs  # Повний Debian/Proxmox rootfs (zstd)
  pve-rescue.iso       # Гібридний ISO (BIOS + UEFI через GRUB)
```

## Швидкий старт

```bash
# Збірка
./pve-rescue

# Записати ISO на USB
dd if=pve_output/pve-rescue.iso of=/dev/sdX bs=4M status=progress
```

### PXE (iPXE)
```
kernel http://<srv>/pve-rescue.kernel ro
initrd http://<srv>/pve-rescue.initrd
initrd http://<srv>/pve-rescue.squashfs /pve-rescue.squashfs
boot
```

### SSH-ключі через cmdline (PXE/GRUB)
```
linux /vmlinuz ro rescue.sshkeys=http://<srv>/keys.txt
```

## Залежності хоста

Скрипт сам перевіряє наявність і виводить команду встановлення:

```
mmdebstrap squashfs-tools xorriso mtools grub-common grub-pc-bin grub-efi-amd64-bin wget cpio zstd
```

## Структура репозиторію

```
pve-rescue                  # Головний скрипт збірки
initrd-init                 # Init-скрипт всередині initramfs
install.conf                # Маніфест: які файли куди і з якими правами
symlinks.conf               # Маніфест: які symlinks створити в rootfs
hooks/
  pve-rescue-prune          # mmdebstrap hook: прибирає непотрібні модулі/firmware/docs
  pve-rescue-configure      # mmdebstrap hook: встановлює файли, налаштовує систему
rootfs_tools/               # Файли що потрапляють в образ (згідно install.conf)
  pve-chroot                # Авто-монтування ZFS + chroot в Proxmox
  pve-umount                # Розмонтування + експорт ZFS пулу
  rescue-init.sh            # Run-once SSH налаштування (з .bashrc)
  rescue-setup.sh           # systemd oneshot: завантажує SSH-ключі, генерує MOTD
  rescue-setup.service      # systemd unit для rescue-setup.sh
  sshd_rescue.conf          # Конфіг SSH
  10-rescue-dhcp.network    # systemd-networkd: DHCP на всіх інтерфейсах
  autologin.conf            # getty override: autologin root + пауза Enter
  logind-override.conf      # logind: обмеження до 4 TTY
  bashrc                    # /root/.bashrc
  motd                      # Статичний шаблон MOTD (перезаписується при завантаженні)
  rescue-ip.sh              # /etc/profile.d: показує IP при логіні
  proxmox.sources           # APT-джерело Proxmox (всередині образу)
  proxmox-archive-keyring.gpg  # GPG-ключ Proxmox (завантажується автоматично)
  *.pub                     # SSH публічні ключі — вшиваються в authorized_keys
```

## Як працює завантаження

```
1. Ядро → initramfs (initrd-init)
2. initrd шукає pve-rescue.squashfs:
     - в initramfs (PXE: другий initrd)
     - на CD-ROM або USB (блок-пристрої)
3. squashfs монтується read-only
4. overlayfs (tmpfs upper) → writable rootfs
5. switch_root → systemd
```

## Інструменти в образі

| Команда | Призначення |
|---------|-------------|
| `pve-chroot [/mnt] [rpool]` | Імпортує ZFS пул і робить chroot в Proxmox |
| `pve-umount [/mnt] [rpool]` | Розмонтовує і робить export пулу |
| `zpool import -a -f -N` | Ручний імпорт ZFS пулів |
| `vgchange -ay` | Активація LVM |
| `smartctl -a /dev/sdX` | SMART-діагностика дисків |
| `partclone.*` | Резервне копіювання розділів |
| `gdisk` | Редагування GPT таблиці |
| `btrfs` | Робота з Btrfs |

## Перший логін

При першому вході в shell (на будь-якому з 4 TTY):
- Якщо в образ вшиті SSH-ключі (`*.pub` в `rootfs_tools/`) — SSH запускається автоматично
- Якщо ключів немає — пропонується встановити пароль для root і запустити SSH

## Очищення

```bash
rm -rf pve_output pve_rescue_build
```

> Головний скрипт робить це автоматично на початку кожної збірки.

## Додавання SSH-ключів в образ

Покласти файл `ім'я.pub` в `rootfs_tools/` — він автоматично потрапить в `authorized_keys` при збірці.
