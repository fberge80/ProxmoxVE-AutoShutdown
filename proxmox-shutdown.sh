#!/bin/bash
# Arrêt programmé de Proxmox VE
# Arrête proprement les CTs et VMs avant d'éteindre le host

LOG="/var/log/proxmox-shutdown.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"
}

log "========================================"
log "Début de la procédure d'arrêt programmé"

# --- Arrêt des VMs KVM en cours d'exécution ---
RUNNING_VMS=$(qm list 2>/dev/null | awk 'NR>1 && $3=="running" {print $1}')

if [ -n "$RUNNING_VMS" ]; then
    for VMID in $RUNNING_VMS; do
        log "Arrêt de la VM $VMID (timeout 120s)..."
        qm shutdown "$VMID" --timeout 120
        if [ $? -eq 0 ]; then
            log "VM $VMID arrêtée proprement."
        else
            log "WARN: VM $VMID n'a pas répondu, arrêt forcé."
            qm stop "$VMID"
        fi
    done
else
    log "Aucune VM en cours d'exécution."
fi

# --- Arrêt des containers LXC en cours d'exécution ---
RUNNING_CTS=$(pct list 2>/dev/null | awk 'NR>1 && $2=="running" {print $1}')

if [ -n "$RUNNING_CTS" ]; then
    for CTID in $RUNNING_CTS; do
        log "Arrêt du container LXC $CTID (timeout 60s)..."
        pct shutdown "$CTID" --timeout 60
        if [ $? -eq 0 ]; then
            log "Container $CTID arrêté proprement."
        else
            log "WARN: Container $CTID n'a pas répondu, arrêt forcé."
            pct stop "$CTID"
        fi
    done
else
    log "Aucun container en cours d'exécution."
fi

# --- Extinction du host ---
log "Extinction du host Proxmox..."
/sbin/shutdown -h now