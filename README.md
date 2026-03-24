# Minimal GRUB Theme

A truly minimal GRUB theme with interactive installer that lets you set font size and boot timeout (delay automatic boot).

![minimal-grub-menu](https://github.com/user-attachments/assets/074b1f6a-ab50-41ca-98c9-c735febd95a8)

## Installation

```bash
git clone https://github.com/aspy606/minimal-grub-theme.git
cd minimal-grub-theme
sudo bash ./Install.sh
```

## What `Install.sh` does

- Detects GRUB directory: `/boot/grub2` or `/boot/grub`
- Detects mkconfig tool: `grub2-mkconfig` or `grub-mkconfig`
- Prompts for:
  - Font size (generates a custom font from `./minimal/font.ttf`)
  - Boot timeout (updates `GRUB_TIMEOUT` in `/etc/default/grub` and writes a `.bak` backup)
- Copies the theme to: `$GRUB_DIR/themes/minimal`
- Sets `GRUB_THEME=.../theme.txt` in `/etc/default/grub`
- Regenerates GRUB config: `$GRUB_DIR/grub.cfg`

## Uninstallation

```bash
sudo bash ./Uninstall.sh
```

## What `Uninstall.sh` does

- Removes the installed theme directory from `$GRUB_DIR/themes/minimal`
- Restores the `.bak` grub file from `/etc/default/grub.bak`
- Regenerates GRUB config: `$GRUB_DIR/grub.cfg` to finally undo the changes
