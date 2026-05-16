# Minimal GRUB Theme

A minimal text-only GRUB theme with a safer installer, generated lightweight PF2
font, NixOS module support, and a grey bottom countdown label.

![minimal-grub-menu](https://github.com/user-attachments/assets/074b1f6a-ab50-41ca-98c9-c735febd95a8)

## What Changed

- The installer is non-interactive and does not write GRUB config unless
  `--apply` is passed.
- The font is generated during install/build instead of being edited in the repo.
- The default generated font is named `custom`, matching `minimal/theme.txt`.
- The default font range is Latin-focused to reduce GRUB rendering work.
- The theme shows `Booting in N` in grey at the bottom of the GRUB screen.

## NixOS

This repo exposes a flake package and a NixOS module. The module only configures
the GRUB theme when GRUB is already enabled; it does not switch your system from
systemd-boot to GRUB.

Example flake usage:

```nix
{
  inputs.minimal-grub-theme.url = "path:/home/edward/Documents/projects/minimal-grub-theme";

  outputs = { nixpkgs, minimal-grub-theme, ... }: {
    nixosConfigurations.hostname = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        minimal-grub-theme.nixosModules.default
        ./configuration.nix
      ];
    };
  };
}
```

Then, in your NixOS configuration where GRUB is enabled:

```nix
{
  boot.loader.grub.minimalTheme = {
    enable = true;
    fontSize = 28;
    fontRange = "0x20-0x7e,0xa0-0xff,0x2010-0x2026";
    timeout = 5;
  };
}
```

If your GRUB menu entries need non-Latin characters, set a broader `fontRange`.

## Portable Install

Preview the install without writing anything:

```bash
./Install.sh --dry-run --timeout 5 --font-size 28
```

Apply the install on traditional GRUB systems:

```bash
sudo ./Install.sh --apply --timeout 5 --font-size 28
```

The installer copies only `theme.txt` and a freshly generated `custom.pf2` into
the GRUB theme directory. It writes managed GRUB settings only when `--apply` is
used:

```bash
GRUB_THEME="/boot/grub/themes/minimal/theme.txt"
GRUB_TIMEOUT=5
GRUB_TIMEOUT_STYLE=menu
```

If `/etc/default/grub.d` exists, a managed drop-in is written there. Otherwise a
managed block is added to `/etc/default/grub`. Existing files are backed up with
a timestamp before modification.

Useful options:

```bash
sudo ./Install.sh --apply --theme-dir /boot/grub/themes/minimal
sudo ./Install.sh --apply --mkconfig never
sudo ./Install.sh --apply --font-range "0x20-0x2fff"
```

For custom mkconfig commands, pass the full command:

```bash
sudo ./Install.sh --apply --mkconfig "grub-mkconfig -o /boot/grub/grub.cfg"
```

## Uninstall

Preview removal:

```bash
./Uninstall.sh --dry-run
```

Remove managed files and config:

```bash
sudo ./Uninstall.sh --apply
```

The uninstaller removes only the managed theme directory and the managed GRUB
config snippet/block. It does not restore a whole old `/etc/default/grub`
backup over your current config.

## Build Font Manually

```bash
scripts/build-font.sh --font-size 28 --output /tmp/custom.pf2
```

The default range is:

```text
0x20-0x7e,0xa0-0xff,0x2010-0x2026
```

That range is intentionally small for responsiveness. Broaden it if your GRUB
entries use characters outside basic Latin, Latin-1, and common punctuation.
