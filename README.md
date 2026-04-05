# ProxmoxVE-AutoShutdown

Script Bash d'arrêt automatique planifié pour Proxmox VE 9.1.x

## Contexte
Homelab personnel Proxmox Virtual Environnement. Le script arrête
proprement les containers LXC et VMs KVM avant d'éteindre le host,
avec journalisation horodatée.

## Utilisation
Copier le script dans /usr/local/sbin/, le rendre exécutable,
puis le planifier via cron :
    chmod 700 /usr/local/sbin/proxmox-shutdown.sh
    crontab -e  # ajouter : 0 22 * * * /usr/local/sbin/proxmox-shutdown.sh

## Environnement
- Proxmox VE 9.1.x
- Debian 12 (Bookworm)
