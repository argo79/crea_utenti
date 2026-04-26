#!/bin/bash

# ============================================
# SCRIPT CREAZIONE UTENTI PER SCUOLA
# ============================================
# Versione: 2.0
# Autore: Script per Scuola
# Uso: ./crea_utenti.sh [OPZIONE]
# ============================================

# Configurazione
CSV_FILE="utenti.csv"
LOG_FILE="creazione_utenti.log"
PASSWORD_FILE="password_utenti.txt"
WEB_ROOT="/var/www/html"
SFTP_ROOT="/home"
PASSWORD_LENGTH=10
QUOTA_SIZE="200M"  # Limite spazio per utente (default 200 Mbyte)
QUOTA_SOFT="180M"  # Limite soft (warning)

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ============================================
# FUNZIONI DI UTILITY
# ============================================

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

generate_password() {
    openssl rand -base64 12 | tr -d "=+/" | cut -c1-$PASSWORD_LENGTH
}

validate_password() {
    local password=$1
    if [ ${#password} -lt 8 ]; then
        return 1
    fi
    return 0
}

save_password() {
    local username=$1
    local password=$2
    local classe=$3
    
    # Verifica se la password è già salvata
    if grep -q "Utente: $username" "$PASSWORD_FILE" 2>/dev/null; then
        return 0
    fi
    
    echo "=========================================" >> "$PASSWORD_FILE"
    echo "Utente: $username" >> "$PASSWORD_FILE"
    echo "Classe: $classe" >> "$PASSWORD_FILE"
    echo "Password: $password" >> "$PASSWORD_FILE"
    echo "Data creazione: $(date '+%Y-%m-%d %H:%M:%S')" >> "$PASSWORD_FILE"
    echo "=========================================" >> "$PASSWORD_FILE"
    echo "" >> "$PASSWORD_FILE"
}

create_user_home() {
    local username=$1
    local classe=$2
    
    # Crea struttura home directory con classe
    sudo mkdir -p "$SFTP_ROOT/$classe/$username"
    sudo chown "$username:$classe" "$SFTP_ROOT/$classe/$username"
    sudo chmod 750 "$SFTP_ROOT/$classe/$username"
}

create_web_space() {
    local username=$1
    local classe=$2
    
    # Crea directory web nella struttura CLASSE/username
    sudo mkdir -p "$WEB_ROOT/$classe/$username"
    
    # Crea index.html usando echo (evita problemi di encoding)
    sudo bash -c "cat > '$WEB_ROOT/$classe/$username/index.html'" << EOF
<!DOCTYPE html>
<html lang="it">
<head>
    <meta charset="UTF-8">
    <title>Pagina di $username</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .container { max-width: 800px; margin: auto; }
        h1 { color: #4CAF50; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Benvenuto nella pagina di $username</h1>
        <p>Classe: <strong>$classe</strong></p>
        <p>Limite spazio: <strong>$QUOTA_SIZE</strong></p>
        <p>Data creazione: $(date '+%d/%m/%Y')</p>
        <hr>
        <p><small>Area riservata agli studenti della classe $classe</small></p>
    </div>
</body>
</html>
EOF
    
    # Imposta permessi
    sudo chown -R "$username:$classe" "$WEB_ROOT/$classe/$username"
    sudo chmod 755 "$WEB_ROOT/$classe/$username"
}

# ============================================
# FUNZIONE PER IMPOSTARE QUOTA DISCO
# ============================================

set_quota() {
    local username=$1
    local quota_size=$2
    
    # Verifica se quota è installato
    if ! command -v setquota &> /dev/null; then
        echo -e "${YELLOW}   ⚠️ quota non installato, salto impostazione limite${NC}"
        log_message "WARNING: quota non installato per $username"
        return 1
    fi
    
    # Trova il dispositivo dove si trova /home
    local home_dev=$(df --output=source /home | tail -1)
    local home_mount=$(df --output=target /home | tail -1)
    
    # Calcola dimensione in kilobyte
    local quota_kb=$(echo $quota_size | sed 's/M/*1024/' | bc | cut -d. -f1)
    local soft_kb=$(echo $quota_size | sed 's/M/*1024*0.9/' | bc | cut -d. -f1)
    
    # Imposta quota per l'utente
    sudo setquota -u "$username" "$soft_kb" "$quota_kb" 0 0 "$home_mount" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}   ✓ Quota impostata: $quota_size${NC}"
        log_message "Quota $quota_size impostata per $username"
        return 0
    else
        echo -e "${YELLOW}   ⚠️ Impossibile impostare quota${NC}"
        return 1
    fi
}

# ============================================
# FUNZIONE PER VERIFICARE SPAZIO UTENTE
# ============================================

check_user_space() {
    local username=$1
    local classe=$2
    
    local home_size=$(du -sh "$SFTP_ROOT/$classe/$username" 2>/dev/null | cut -f1)
    local web_size=$(du -sh "$WEB_ROOT/$classe/$username" 2>/dev/null | cut -f1)
    
    echo -e "${CYAN}   Spazio utilizzato:${NC}"
    echo -e "      Home: $home_size"
    echo -e "      Web:  $web_size"
}

# ============================================
# FUNZIONE LISTA UTENTI
# ============================================

list_users() {
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${GREEN}   UTENTI CREATI DALLO SCRIPT${NC}"
    echo -e "${BLUE}=========================================${NC}"
    echo ""
    
    local found=0
    
    # Cerca utenti nelle directory delle classi in /home
    for classe_dir in /home/*/; do
        if [ -d "$classe_dir" ]; then
            classe=$(basename "$classe_dir")
            
            # Per ogni utente nella directory della classe
            for user_dir in "$classe_dir"*/; do
                if [ -d "$user_dir" ]; then
                    username=$(basename "$user_dir")
                    
                    # Salta se non è un utente valido
                    if id "$username" &>/dev/null 2>&1; then
                        found=1
                        gruppo=$(id -gn "$username" 2>/dev/null)
                        home_dir="$SFTP_ROOT/$classe/$username"
                        web_dir="$WEB_ROOT/$classe/$username"
                        
                        echo -e "${CYAN}📌 Utente: $username${NC}"
                        echo -e "   Classe: ${YELLOW}$classe${NC}"
                        echo -e "   Gruppo: $gruppo"
                        echo -e "   Home: $home_dir"
                        echo -e "   Quota: $QUOTA_SIZE"
                        
                        if [ -d "$web_dir" ]; then
                            echo -e "   Web: ${GREEN}✓ Presente${NC} (http://localhost/$classe/$username)"
                        else
                            echo -e "   Web: ${RED}✗ Non presente${NC}"
                        fi
                        
                        # Verifica spazio utilizzato
                        if [ -d "$home_dir" ]; then
                            local home_space=$(du -sh "$home_dir" 2>/dev/null | cut -f1)
                            echo -e "   Spazio home: $home_space"
                        fi
                        
                        if [ -f "$PASSWORD_FILE" ] && grep -q "Utente: $username" "$PASSWORD_FILE" 2>/dev/null; then
                            echo -e "   Password: ${GREEN}✓ Salvata${NC}"
                        else
                            echo -e "   Password: ${YELLOW}⚠️ Non trovata nel file${NC}"
                        fi
                        echo ""
                    fi
                fi
            done
        fi
    done
    
    if [ $found -eq 0 ]; then
        echo -e "${YELLOW}⚠️  Nessun utente trovato${NC}"
        echo ""
        echo -e "${CYAN}💡 Suggerimento:${NC}"
        echo "   Per creare utenti, usa: sudo ./crea_utenti.sh -c"
    fi
    
    echo -e "${BLUE}=========================================${NC}"
}

# ============================================
# FUNZIONE VERIFICA E CREAZIONE COMPONENTI MANCANTI
# ============================================

fix_missing_components() {
    local username=$1
    local classe=$2
    local password=$3
    
    local changes=0
    
    echo -e "${CYAN}▶️  Verifica utente: $username${NC}"
    echo "   Classe: $classe"
    
    # Verifica e crea home directory se mancante
    if [ ! -d "$SFTP_ROOT/$classe/$username" ]; then
        echo -e "${YELLOW}   ⚠️ Home directory mancante${NC}"
        create_user_home "$username" "$classe"
        changes=$((changes + 1))
    else
        echo -e "${GREEN}   ✓ Home directory OK${NC}"
    fi
    
    # Verifica e crea web directory se mancante
    if [ ! -d "$WEB_ROOT/$classe/$username" ]; then
        echo -e "${YELLOW}   ⚠️ Web directory mancante${NC}"
        create_web_space "$username" "$classe"
        changes=$((changes + 1))
    else
        echo -e "${GREEN}   ✓ Web directory OK${NC}"
    fi
    
    # Verifica e imposta quota se non impostata
    if command -v setquota &> /dev/null; then
        local quota_check=$(sudo quota -u "$username" 2>/dev/null | grep -v "Disk quotas")
        if [ -z "$quota_check" ] || [ "$quota_check" == "" ]; then
            echo -e "${YELLOW}   ⚠️ Quota non impostata${NC}"
            set_quota "$username" "$QUOTA_SIZE"
            changes=$((changes + 1))
        else
            echo -e "${GREEN}   ✓ Quota già impostata${NC}"
        fi
    fi
    
    # Verifica e salva password se non presente
    if [ -f "$PASSWORD_FILE" ] && ! grep -q "Utente: $username" "$PASSWORD_FILE" 2>/dev/null; then
        echo -e "${YELLOW}   ⚠️ Password non salvata${NC}"
        save_password "$username" "$password" "$classe"
        echo -e "${GREEN}   ✓ Password salvata${NC}"
        changes=$((changes + 1))
    else
        echo -e "${GREEN}   ✓ Password già salvata${NC}"
    fi
    
    if [ $changes -eq 0 ]; then
        echo -e "${GREEN}   ✅ Utente completo - tutto OK${NC}"
    else
        echo -e "${GREEN}   ✅ Utente aggiornato ($changes componenti aggiunti)${NC}"
    fi
    echo ""
}

# ============================================
# FUNZIONE CREAZIONE/AGGIORNAMENTO UTENTI
# ============================================

create_users() {
    local batch_mode=${1:-false}
    
    # Verifica se il file CSV esiste
    if [ ! -f "$CSV_FILE" ]; then
        echo -e "${RED}❌ File $CSV_FILE non trovato!${NC}"
        log_message "ERRORE: File $CSV_FILE non trovato"
        return 1
    fi
    
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${GREEN}         VERIFICA E CREAZIONE UTENTI IN CORSO...             ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}📊 Configurazione:${NC}"
    echo "   Quota disco per utente: $QUOTA_SIZE"
    echo "   Directory home: $SFTP_ROOT/CLASSE/utente/"
    echo "   Directory web:  $WEB_ROOT/CLASSE/utente/"
    echo ""
    
    # Inizializza file password se non esiste
    if [ ! -f "$PASSWORD_FILE" ]; then
        echo "=== PASSWORD UTENTI CREATE IL $(date '+%Y-%m-%d %H:%M:%S') ===" > "$PASSWORD_FILE"
        echo "" >> "$PASSWORD_FILE"
    fi
    
    local success_count=0
    local error_count=0
    local updated_count=0
    local line_num=0
    
    # Leggi il file CSV (formato: nome,cognome,classe,password)
    while IFS=',' read -r nome cognome classe password_utente || [ -n "$nome" ]; do
        line_num=$((line_num + 1))
        
        # Salta intestazione se presente
        if [ "$nome" == "nome" ] || [ "$nome" == "Nome" ]; then
            continue
        fi
        
        # Salta linee vuote
        if [ -z "$nome" ] && [ -z "$cognome" ]; then
            continue
        fi
        
        # Pulisci gli spazi
        nome=$(echo "$nome" | xargs)
        cognome=$(echo "$cognome" | xargs)
        classe=$(echo "$classe" | xargs)
        password_utente=$(echo "$password_utente" | xargs)
        
        # Verifica campi obbligatori
        if [ -z "$nome" ] || [ -z "$cognome" ] || [ -z "$classe" ]; then
            echo -e "${RED}❌ Linea $line_num: Campi mancanti (nome,cognome,classe obbligatori)${NC}"
            log_message "ERRORE: Linea $line_num - Campi mancanti"
            error_count=$((error_count + 1))
            continue
        fi
        
        # Costruisci username
        username=$(echo "${nome}.${cognome}" | tr '[:upper:]' '[:lower:]' | sed 's/à/a/g; s/è/e/g; s/é/e/g; s/ì/i/g; s/ò/o/g; s/ù/u/g' | sed 's/ //g')
        
        # Gestione password
        if [ -n "$password_utente" ] && validate_password "$password_utente"; then
            password="$password_utente"
            echo -e "${GREEN}   ✓ Password fornita valida${NC}"
        elif [ -n "$password_utente" ] && ! validate_password "$password_utente"; then
            password=$(generate_password)
            echo -e "${YELLOW}   ⚠️ Password fornita troppo corta, generata nuova${NC}"
        else
            password=$(generate_password)
            echo -e "${BLUE}   🔑 Password generata automaticamente${NC}"
        fi
        
        # Verifica se l'utente esiste
        if id "$username" &>/dev/null; then
            echo -e "${BLUE}📌 Utente esistente: $username${NC}"
            
            # Verifica e crea componenti mancanti
            fix_missing_components "$username" "$classe" "$password"
            updated_count=$((updated_count + 1))
            success_count=$((success_count + 1))
            
        else
            # Crea nuovo utente
            echo -e "${GREEN}🆕 Nuovo utente: $username${NC}"
            echo "   Nome: $nome $cognome"
            echo "   Classe: $classe"
            
            # Verifica se il gruppo classe esiste
            if ! getent group "$classe" > /dev/null; then
                echo -e "${BLUE}   📁 Creazione gruppo: $classe${NC}"
                sudo groupadd "$classe"
                log_message "Creato gruppo $classe"
            fi
            
            # Crea l'utente
            echo -e "${BLUE}   👤 Creazione utente...${NC}"
            sudo useradd -m -d "$SFTP_ROOT/$classe/$username" -g "$classe" -s /bin/bash "$username"
            
            if [ $? -eq 0 ]; then
                # Imposta la password
                echo "$username:$password" | sudo chpasswd
                
                # Crea strutture
                create_user_home "$username" "$classe"
                create_web_space "$username" "$classe"
                
                # Imposta quota
                set_quota "$username" "$QUOTA_SIZE"
                
                # Salva la password
                save_password "$username" "$password" "$classe"
                
                echo -e "${GREEN}   ✅ Utente creato con successo!${NC}"
                echo -e "${GREEN}   🔑 Password: $password${NC}"
                echo "   📁 Home: $SFTP_ROOT/$classe/$username"
                echo "   🌐 Web: http://localhost/$classe/$username"
                echo "   💾 Quota: $QUOTA_SIZE"
                echo ""
                
                log_message "Creato utente $username (classe $classe) con quota $QUOTA_SIZE"
                success_count=$((success_count + 1))
            else
                echo -e "${RED}   ❌ Errore nella creazione dell'utente${NC}"
                log_message "ERRORE: Creazione utente $username fallita"
                error_count=$((error_count + 1))
            fi
        fi
        
        echo "---"
        
    done < "$CSV_FILE"
    
    # Riepilogo finale
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${GREEN}                    RIEPILOGO OPERAZIONI                      ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo -e "${GREEN}✅ Operazioni completate: $success_count${NC}"
    echo -e "${CYAN}   - Nuovi utenti creati: $((success_count - updated_count))${NC}"
    echo -e "${CYAN}   - Utenti esistenti aggiornati: $updated_count${NC}"
    echo -e "${RED}❌ Errori: $error_count${NC}"
    echo -e "${YELLOW}📝 Password salvate in: $PASSWORD_FILE${NC}"
    echo -e "${CYAN}📋 Log operazioni: $LOG_FILE${NC}"
    echo -e "${MAGENTA}💾 Quota impostata: $QUOTA_SIZE per utente${NC}"
    echo ""
    
    if [ $success_count -gt 0 ]; then
        echo -e "${GREEN}🎉 Operazione completata!${NC}"
        echo -e "${YELLOW}📌 Struttura:${NC}"
        echo "   Home: /home/CLASSE/username/"
        echo "   Web:  /var/www/html/CLASSE/username/"
        echo "   Quota: $QUOTA_SIZE"
    fi
}

# ============================================
# FUNZIONE ELIMINA UTENTE
# ============================================

delete_user() {
    local username=$1
    
    if [ -z "$username" ]; then
        echo -e "${RED}❌ Specificare il nome utente da eliminare${NC}"
        echo "Uso: ./crea_utenti.sh -d username"
        exit 1
    fi
    
    if ! id "$username" &>/dev/null; then
        echo -e "${RED}❌ Utente $username non esiste${NC}"
        exit 1
    fi
    
    local classe=$(id -gn "$username" 2>/dev/null)
    
    echo -e "${YELLOW}⚠️  Eliminazione utente: $username (classe: $classe)${NC}"
    echo -n "Sei sicuro? (s/n): "
    read conferma
    
    if [ "$conferma" == "s" ]; then
        # Elimina directory web
        if [ -d "$WEB_ROOT/$classe/$username" ]; then
            sudo rm -rf "$WEB_ROOT/$classe/$username"
            echo -e "${GREEN}✓ Directory web eliminata${NC}"
        fi
        
        # Elimina utente
        sudo userdel -r "$username" 2>/dev/null
        
        # Elimina home directory
        if [ -d "$SFTP_ROOT/$classe/$username" ]; then
            sudo rm -rf "$SFTP_ROOT/$classe/$username"
            echo -e "${GREEN}✓ Home directory eliminata${NC}"
        fi
        
        # Pulisci directory classe se vuote
        if [ -d "$WEB_ROOT/$classe" ] && [ -z "$(ls -A "$WEB_ROOT/$classe" 2>/dev/null)" ]; then
            sudo rmdir "$WEB_ROOT/$classe" 2>/dev/null
            echo -e "${GREEN}✓ Directory classe web vuota eliminata${NC}"
        fi
        
        if [ -d "$SFTP_ROOT/$classe" ] && [ -z "$(ls -A "$SFTP_ROOT/$classe" 2>/dev/null)" ]; then
            sudo rmdir "$SFTP_ROOT/$classe" 2>/dev/null
            echo -e "${GREEN}✓ Directory classe home vuota eliminata${NC}"
        fi
        
        echo -e "${GREEN}✓ Utente $username eliminato completamente${NC}"
        log_message "Utente $username eliminato (classe $classe)"
    else
        echo -e "${BLUE}Operazione annullata${NC}"
    fi
}

# ============================================
# FUNZIONE CAMBIA PASSWORD
# ============================================

change_password() {
    local username=$1
    
    if [ -z "$username" ]; then
        echo -e "${RED}❌ Specificare il nome utente${NC}"
        echo "Uso: ./crea_utenti.sh -p username"
        exit 1
    fi
    
    if ! id "$username" &>/dev/null; then
        echo -e "${RED}❌ Utente $username non esiste${NC}"
        exit 1
    fi
    
    sudo passwd "$username"
    
    if [ $? -eq 0 ]; then
        echo "" >> "$PASSWORD_FILE"
        echo "=========================================" >> "$PASSWORD_FILE"
        echo "PASSWORD MODIFICATA MANUALMENTE" >> "$PASSWORD_FILE"
        echo "Utente: $username" >> "$PASSWORD_FILE"
        echo "Data modifica: $(date '+%Y-%m-%d %H:%M:%S')" >> "$PASSWORD_FILE"
        echo "=========================================" >> "$PASSWORD_FILE"
        echo "" >> "$PASSWORD_FILE"
    fi
}

# ============================================
# FUNZIONE VERIFICA CONFIGURAZIONE
# ============================================

check_config() {
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${GREEN}   VERIFICA CONFIGURAZIONE SISTEMA${NC}"
    echo -e "${BLUE}=========================================${NC}"
    echo ""
    
    if [ "$EUID" -eq 0 ]; then
        echo -e "${GREEN}✓${NC} Sei root"
    else
        echo -e "${RED}✗${NC} Non sei root (usa sudo)"
    fi
    
    if systemctl is-active --quiet apache2 2>/dev/null; then
        echo -e "${GREEN}✓${NC} Apache2 attivo"
    elif systemctl is-active --quiet nginx 2>/dev/null; then
        echo -e "${GREEN}✓${NC} Nginx attivo"
    else
        echo -e "${RED}✗${NC} Web server non trovato"
    fi
    
    if systemctl is-active --quiet sshd 2>/dev/null || systemctl is-active --quiet ssh 2>/dev/null; then
        echo -e "${GREEN}✓${NC} SSH attivo"
    else
        echo -e "${RED}✗${NC} SSH non attivo"
    fi
    
    # Verifica quota
    if command -v setquota &> /dev/null; then
        echo -e "${GREEN}✓${NC} Quota installato"
    else
        echo -e "${YELLOW}⚠️ Quota non installato (opzionale)${NC}"
        echo "   Installa con: sudo apt-get install quota quotatool"
    fi
    
    if [ -d "$WEB_ROOT" ]; then
        echo -e "${GREEN}✓${NC} Web root: $WEB_ROOT"
    else
        echo -e "${RED}✗${NC} Web root non trovata"
    fi
    
    if [ -f "$CSV_FILE" ]; then
        echo -e "${GREEN}✓${NC} File CSV: $CSV_FILE"
        echo -e "   Numero linee: $(wc -l < $CSV_FILE)"
    else
        echo -e "${RED}✗${NC} File CSV non trovato"
    fi
    
    echo ""
    echo -e "${CYAN}📊 Configurazione quota:${NC}"
    echo "   Limite default: $QUOTA_SIZE"
    echo ""
    
    echo -e "${BLUE}=========================================${NC}"
}

# ============================================
# FUNZIONE PER MODIFICARE QUOTA
# ============================================

set_quota_for_user() {
    local username=$1
    local quota_size=$2
    
    if [ -z "$username" ] || [ -z "$quota_size" ]; then
        echo -e "${RED}❌ Uso: ./crea_utenti.sh --set-quota username 200M${NC}"
        return 1
    fi
    
    if ! id "$username" &>/dev/null; then
        echo -e "${RED}❌ Utente $username non esiste${NC}"
        return 1
    fi
    
    set_quota "$username" "$quota_size"
}

# ============================================
# FUNZIONE HELP
# ============================================

show_help() {
    clear
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${GREEN}                CREAZIONE UTENTI PER SCUOLA - HELP                ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${YELLOW}📖 SINOSSI:${NC}"
    echo -e "    ${CYAN}./crea_utenti.sh${NC} [OPZIONE]"
    echo ""
    
    echo -e "${YELLOW}🎯 DESCRIZIONE:${NC}"
    echo "    Script per la creazione/aggiornamento automatico di utenti scolastici"
    echo "    Verifica cosa esiste e crea solo i componenti mancanti"
    echo "    Include gestione quota disco per ogni utente"
    echo ""
    
    echo -e "${YELLOW}⚙️  OPZIONI:${NC}"
    echo -e "    ${CYAN}-h, --help${NC}              Mostra questo help"
    echo -e "    ${CYAN}-c, --create${NC}            Esegui verifica e creazione utenti"
    echo -e "    ${CYAN}-f, --file FILE${NC}         Specifica un file CSV diverso"
    echo -e "    ${CYAN}-l, --list${NC}              Lista tutti gli utenti"
    echo -e "    ${CYAN}-d, --delete USER${NC}       Elimina un utente"
    echo -e "    ${CYAN}-p, --passwd USER${NC}       Cambia password"
    echo -e "    ${CYAN}--check${NC}                 Verifica configurazione sistema"
    echo -e "    ${CYAN}--set-quota USER SIZE${NC}   Imposta quota per utente (es: 200M, 1G)"
    echo -e "    ${CYAN}--quota-size SIZE${NC}       Modifica quota default (es: --quota-size 500M)"
    echo -e "    ${CYAN}--verify${NC}                Verifica password salvate"
    echo -e "    ${CYAN}--backup${NC}                Crea backup configurazioni"
    echo -e "    ${CYAN}--version${NC}               Mostra versione"
    echo ""
    
    echo -e "${YELLOW}💾 GESTIONE QUOTA:${NC}"
    echo "    Lo script imposta automaticamente un limite di spazio per ogni utente"
    echo "    Default: $QUOTA_SIZE"
    echo ""
    echo "    Per modificare il default:"
    echo "    ${CYAN}./crea_utenti.sh --quota-size 500M -c${NC}"
    echo ""
    echo "    Per impostare quota a un utente esistente:"
    echo "    ${CYAN}./crea_utenti.sh --set-quota mario.rossi 300M${NC}"
    echo ""
    
    echo -e "${YELLOW}📁 STRUTTURA:${NC}"
    echo "    /home/CLASSE/utente/          - Home directory"
    echo "    /var/www/html/CLASSE/utente/  - Web directory"
    echo "    Quota: $QUOTA_SIZE per utente"
    echo ""
    
    echo -e "${YELLOW}📁 FORMATO CSV:${NC}"
    echo "    nome,cognome,classe,password"
    echo "    Esempio: Mario,Rossi,4AI,Password123"
    echo ""
    
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${GREEN}       per assistenza: arg0netds@gmail.com                   ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
}

# ============================================
# FUNZIONE VERSIONE
# ============================================

show_version() {
    echo -e "${GREEN}Script Creazione Utenti Scuola${NC}"
    echo -e "Versione: ${CYAN}2.0${NC}"
    echo -e "Ultimo aggiornamento: ${YELLOW}Aprile 2026${NC}"
    echo -e "Licenza: ${BLUE}Open Source${NC}"
    echo -e "Quota default: ${MAGENTA}$QUOTA_SIZE${NC}"
}

# ============================================
# FUNZIONE BACKUP
# ============================================

backup_config() {
    echo -e "${YELLOW}📦 Creazione backup configurazioni...${NC}"
    
    if [ -f "$PASSWORD_FILE" ]; then
        cp "$PASSWORD_FILE" "$PASSWORD_FILE.backup.$(date +%Y%m%d_%H%M%S)"
        echo -e "${GREEN}✓ Backup password creato${NC}"
    fi
    
    if [ -f "$LOG_FILE" ]; then
        cp "$LOG_FILE" "$LOG_FILE.backup.$(date +%Y%m%d_%H%M%S)"
        echo -e "${GREEN}✓ Backup log creato${NC}"
    fi
    
    # Backup configurazione quota
    if [ -f "/etc/quota.conf" ]; then
        cp "/etc/quota.conf" "/etc/quota.conf.backup.$(date +%Y%m%d_%H%M%S)"
        echo -e "${GREEN}✓ Backup quota creato${NC}"
    fi
    
    echo -e "${GREEN}✅ Backup completati${NC}"
}

# ============================================
# FUNZIONE VERIFICA PASSWORD
# ============================================

verify_passwords() {
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${GREEN}   VERIFICA PASSWORD UTENTI${NC}"
    echo -e "${BLUE}=========================================${NC}"
    echo ""
    
    if [ ! -f "$PASSWORD_FILE" ]; then
        echo -e "${RED}❌ File password non trovato!${NC}"
        echo "Esegui prima la creazione utenti"
        return 1
    fi
    
    echo -e "${YELLOW}Password salvate:${NC}"
    echo ""
    cat "$PASSWORD_FILE"
}

# ============================================
# FUNZIONE MAIN
# ============================================

main() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}❌ Questo script deve essere eseguito con sudo${NC}"
        exit 1
    fi
    
    create_users
}

# ============================================
# PARSING DEI PARAMETRI
# ============================================

# Gestione parametri speciali prima del case
while [[ $# -gt 0 ]]; do
    case "$1" in
        --quota-size)
            QUOTA_SIZE="$2"
            QUOTA_SOFT=$(echo "$2" | sed 's/M/*0.9/' | bc | cut -d. -f1)M
            echo -e "${GREEN}✅ Quota default modificata in: $QUOTA_SIZE${NC}"
            shift 2
            ;;
        *)
            break
            ;;
    esac
done

# Gestione comandi principali
case "$1" in
    -h|--help)
        show_help
        exit 0
        ;;
    -c|--create)
        main
        exit 0
        ;;
    -b|--batch)
        BATCH_MODE=true
        main
        exit 0
        ;;
    -f|--file)
        CSV_FILE="$2"
        shift
        main
        exit 0
        ;;
    -d|--delete)
        delete_user "$2"
        exit 0
        ;;
    -l|--list)
        list_users
        exit 0
        ;;
    -p|--passwd)
        change_password "$2"
        exit 0
        ;;
    -g|--group)
        echo -e "${YELLOW}Creazione gruppo: $2${NC}"
        groupadd "$2"
        echo -e "${GREEN}✅ Gruppo $2 creato${NC}"
        exit 0
        ;;
    -v|--version)
        show_version
        exit 0
        ;;
    --check)
        check_config
        exit 0
        ;;
    --backup)
        backup_config
        exit 0
        ;;
    --verify)
        verify_passwords
        exit 0
        ;;
    --set-quota)
        set_quota_for_user "$2" "$3"
        exit 0
        ;;
    "")
        show_help
        exit 0
        ;;
    *)
        echo -e "${RED}❌ Opzione non riconosciuta: $1${NC}"
        echo -e "Usa ${CYAN}./crea_utenti.sh -h${NC} per l'help"
        exit 1
        ;;
esac