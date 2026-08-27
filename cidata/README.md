# Cidata contract

Omarchy unattended install looks for a second drive labeled `cidata`. If that drive is present, the installer copies these files into `/root`, skips the wizard, and reboots into the installed system. The files are the same ones the interactive wizard writes.

Source: https://omarchy.org/manual/unattended-installs/

## Files

| File | Required | In this repo | Why |
| --- | --- | --- | --- |
| `user_configuration.json` | yes | no | Disk geometry and, for LUKS, the passphrase in plaintext. Bake it locally. |
| `user_credentials.json` | yes | no | Username plus `openssl passwd -6` hashes. Never commit. |
| `user_full_name.txt` | no | yes | Git `user.name` on this host. |
| `user_email_address.txt` | no | yes | Git `user.email` on this host. |
| `user_encrypt_installation.txt` | no | yes | `true` because `ddbomarchy` uses LUKS. |
| `authorized_keys` | no | yes | SSH public keys only. Enables `sshd` and opens the firewall. |
| `tailscale_authkey` | no | no | A reusable Tailscale auth key is a secret. Join the tailnet after first boot. |
| `defer-provisioning` | no | no | This host is already owned. |

`user_encrypt_installation.txt` being `true` means someone still types the LUKS passphrase at first boot. Encrypted autoinstall is not fully unattended.

## This host

- Hostname: `ddbomarchy`
- Timezone: `America/New_York`
- Keyboard: `us`
- Disk: NVMe, LUKS, btrfs (`@`, `@home`, `@log`, `@pkg`)
- User: `david`

Generate credentials at bake time:

```
openssl passwd -6
```

Keep the hash and the LUKS passphrase in a password manager. Put them on the cidata volume, not in git.

The VM bake path that already builds a cidata VFAT image lives in the private `omarchy-vm` repo (`scripts/build-cidata.sh`). That path sets encryption to `false` so a VM can reboot without a passphrase prompt. This laptop is the opposite.
