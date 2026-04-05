#!/bin/bash
# Indique au système quel interpréteur utiliser pour exécuter ce fichier.
# /bin/bash = le shell Bash. Sans cette ligne, le système ne sait pas comment lire le script.

# Arrêt programmé de Proxmox VE
# Arrête proprement les CTs et VMs avant d'éteindre le host
# Ces deux lignes sont des commentaires purement descriptifs, ignorés à l'exécution.

LOG="/var/log/proxmox-shutdown.log"
# Déclare une variable nommée LOG.
# Elle contient le chemin du fichier journal (log).
# On l'utilise ensuite via $LOG pour ne pas répéter le chemin partout.

log() {
# Déclare une fonction nommée "log".
# Une fonction est un bloc de code réutilisable qu'on appelle par son nom.

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"
    # echo : affiche du texte.
    # $(...) : exécute une commande à l'intérieur et insère son résultat.
    # date '+%Y-%m-%d %H:%M:%S' : génère la date et l'heure au format 2025-04-01 21:59:00.
    # $* : représente tous les arguments passés à la fonction (le message à loguer).
    # >> "$LOG" : ajoute (append) la ligne à la fin du fichier $LOG sans l'écraser.
    #             Un seul > écraserait le fichier à chaque fois.
}
# Fin de la déclaration de la fonction log.

log "========================================"
# Appelle la fonction log avec ce séparateur visuel comme argument.
# Résultat dans le fichier : [2025-04-01 22:00:01] ========================================

log "Début de la procédure d'arrêt programmé"
# Appelle à nouveau la fonction log avec ce message.
# Chaque appel à log() écrit une nouvelle ligne horodatée dans le fichier journal.

# --- Arrêt des VMs KVM en cours d'exécution ---
# Commentaire de section, ignoré à l'exécution.

RUNNING_VMS=$(qm list 2>/dev/null | awk 'NR>1 && $3=="running" {print $1}')
# Déclare la variable RUNNING_VMS et lui assigne le résultat de la commande entre $(...).
#
# qm list : commande Proxmox qui liste toutes les VMs avec leur état.
# 2>/dev/null : redirige les erreurs (stderr) vers /dev/null (la "poubelle" Linux).
#               Évite d'afficher des erreurs si aucune VM n'existe.
# | (pipe) : envoie la sortie de qm list comme entrée à la commande suivante (awk).
#
# awk 'NR>1 && $3=="running" {print $1}' :
#   awk est un outil de traitement de texte ligne par ligne.
#   NR>1 : ignore la première ligne (l'en-tête du tableau).
#   $3=="running" : ne garde que les lignes où la 3e colonne vaut "running".
#   {print $1} : affiche uniquement la 1re colonne = l'ID de la VM.
#
# Résultat : RUNNING_VMS contient la liste des IDs des VMs actives (ex: "100\n101").

if [ -n "$RUNNING_VMS" ]; then
# Structure conditionnelle : "si ... alors".
# [ -n "..." ] : teste si la chaîne de caractères est non vide (-n = non-null).
# Si RUNNING_VMS contient au moins un ID, on entre dans le bloc.
# Si aucune VM ne tourne, RUNNING_VMS est vide et on saute au "else" (il n'y en a pas ici).

    for VMID in $RUNNING_VMS; do
    # Boucle "for" : répète le bloc pour chaque valeur de la liste RUNNING_VMS.
    # À chaque itération, VMID prend l'ID d'une VM (ex: 100, puis 101, etc.).

        log "Arrêt de la VM $VMID (timeout 120s)..."
        # Appelle la fonction log avec un message incluant l'ID de la VM en cours.
        # $VMID est remplacé par sa valeur réelle (ex: "Arrêt de la VM 100...").

        qm shutdown "$VMID" --timeout 120
        # qm shutdown : envoie un signal d'arrêt propre à la VM (équivalent à "éteindre" dans l'OS).
        # "$VMID" : l'ID de la VM ciblée.
        # --timeout 120 : attend 120 secondes maximum que la VM s'arrête proprement.

        if [ $? -eq 0 ]; then
        # $? : variable spéciale qui contient le code de retour de la dernière commande.
        #   0 = succès, autre valeur = erreur.
        # -eq 0 : teste si ce code est égal à 0 (arrêt réussi).

            log "VM $VMID arrêtée proprement."
            # La VM s'est arrêtée dans le délai imparti : on logue le succès.

        else
        # Si le code de retour n'est pas 0 (la VM n'a pas répondu dans les 120s).

            log "WARN: VM $VMID n'a pas répondu, arrêt forcé."
            # On logue un avertissement.

            qm stop "$VMID"
            # qm stop : coupe l'alimentation de la VM immédiatement (arrêt brutal).
            # Équivalent à débrancher la prise. Utilisé en dernier recours.

        fi
        # Fin du bloc if/else.

    done
    # Fin de la boucle for. On passe à la VM suivante, ou on sort si la liste est épuisée.

else
# Bloc exécuté si RUNNING_VMS est vide (aucune VM active).

    log "Aucune VM en cours d'exécution."
    # On logue simplement l'information.

fi
# Fin de la structure if/else.

# --- Arrêt des containers LXC en cours d'exécution ---
# Commentaire de section.

RUNNING_CTS=$(pct list 2>/dev/null | awk 'NR>1 && $2=="running" {print $1}')
# Même logique que pour les VMs, mais avec les containers LXC.
# pct list : commande Proxmox qui liste tous les containers LXC.
# $2=="running" : la colonne "état" est ici en 2e position (différent des VMs où c'était la 3e).
# Résultat : RUNNING_CTS contient les IDs des containers actifs.

if [ -n "$RUNNING_CTS" ]; then
# Même test : on entre dans le bloc uniquement si des containers tournent.

    for CTID in $RUNNING_CTS; do
    # Boucle sur chaque ID de container. CTID prend successivement chaque valeur.

        log "Arrêt du container LXC $CTID (timeout 60s)..."
        # Log avec l'ID du container en cours. Timeout plus court que les VMs (60s vs 120s)
        # car les containers LXC s'arrêtent généralement plus vite que des VMs complètes.

        pct shutdown "$CTID" --timeout 60
        # pct shutdown : arrêt propre du container LXC (équivalent à qm shutdown pour les VMs).
        # --timeout 60 : attend 60 secondes maximum.

        if [ $? -eq 0 ]; then
        # Même vérification du code de retour que pour les VMs.

            log "Container $CTID arrêté proprement."

        else

            log "WARN: Container $CTID n'a pas répondu, arrêt forcé."

            pct stop "$CTID"
            # pct stop : arrêt brutal du container (équivalent à qm stop pour les VMs).

        fi

    done

else

    log "Aucun container en cours d'exécution."

fi

# --- Extinction du host ---
# Commentaire de section.

log "Extinction du host Proxmox..."
# Dernière entrée dans le journal avant l'extinction.

/sbin/shutdown -h now
# /sbin/shutdown : commande système d'extinction.
# -h : "halt", éteint complètement la machine (par opposition à -r qui redémarre).
# now : exécute l'arrêt immédiatement, sans délai.
# On utilise le chemin absolu /sbin/shutdown par sécurité dans les scripts cron,
# car le PATH (liste des dossiers où chercher les commandes) peut être réduit.
