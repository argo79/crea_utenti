# 🎓 Script Creazione Utenti

Script Bash avanzato per la **gestione automatizzata degli utenti scolastici** su sistemi Linux.
Permette di creare, aggiornare e gestire utenti partendo da un file CSV, con supporto per:

* creazione account
* struttura directory organizzata per classe
* spazio web per ogni utente
* gestione password
* quote disco
* verifica e manutenzione automatica

---

## 🚀 Caratteristiche principali

✅ Creazione utenti da file CSV

✅ Struttura directory per classe (`/home/CLASSE/utente`)

✅ Spazio web automatico (`/var/www/html/CLASSE/utente`)

✅ Generazione password sicure

✅ Gestione quota disco per utente

✅ Aggiornamento utenti esistenti

✅ Logging completo operazioni

✅ Backup configurazioni

✅ Script modulare e riutilizzabile

---

## 📁 Struttura creata

Per ogni utente:

```
/home/CLASSE/username/          # Home directory
/var/www/html/CLASSE/username/  # Web directory
```

Accesso web:

```
http://localhost/CLASSE/username
```

---

## 📄 Formato file CSV

Il file `utenti.csv` deve avere questo formato:

```
nome,cognome,classe,password
Mario,Rossi,4AI,Password123
Luca,Bianchi,3BI,
```

📌 Note:

* La password è **opzionale**
* Se mancante o non valida → viene generata automaticamente

---

## ⚙️ Requisiti

* Linux (Debian/Ubuntu/Kali consigliato)
* Permessi **root / sudo**
* Web server:

  * Apache2 oppure Nginx
* SSH attivo
* (Opzionale) sistema quota:

  ```bash
  sudo apt install quota quotatool
  ```

---

## 🔧 Installazione

```bash
git clone https://github.com/argo79/crea_utenti.git
cd crea_utenti
chmod +x crea_utenti.sh
```

---

## ▶️ Utilizzo

### Creazione utenti

```bash
sudo ./crea_utenti.sh -c
```

---

### Lista utenti

```bash
./crea_utenti.sh -l
```

---

### Eliminazione utente

```bash
sudo ./crea_utenti.sh -d username
```

---

### Cambio password

```bash
sudo ./crea_utenti.sh -p username
```

---

### Verifica configurazione sistema

```bash
./crea_utenti.sh --check
```

---

### Impostare quota per utente

```bash
sudo ./crea_utenti.sh --set-quota username 200M
```

---

### Cambiare quota di default

```bash
sudo ./crea_utenti.sh --quota-size 500M -c
```

---

### Backup configurazioni

```bash
./crea_utenti.sh --backup
```

---

### Visualizzare password salvate

```bash
./crea_utenti.sh --verify
```

---

## 🔐 Gestione password

Le password vengono salvate in:

```
password_utenti.txt
```

Contiene:

* username
* classe
* password
* data creazione

⚠️ **IMPORTANTE:** proteggere questo file (contiene credenziali!)

---

## 💾 Gestione quota disco

* Default: **200MB per utente**
* Soft limit: **180MB**
* Configurabile via parametro `--quota-size`

---

## 🧠 Log operazioni

Tutte le operazioni vengono registrate in:

```
creazione_utenti.log
```

---

## ⚠️ Sicurezza

* Lo script deve essere eseguito come **root**
* Le password sono salvate in chiaro → usare solo in ambienti controllati
* Verificare i permessi delle directory web

---

## 🔄 Comportamento intelligente

Lo script:

* ✔️ NON ricrea utenti esistenti
* ✔️ verifica cosa manca
* ✔️ aggiunge solo i componenti mancanti
* ✔️ evita duplicazioni

---

## 📌 Esempio flusso

1. Prepari `utenti.csv`
2. Esegui:

```bash
sudo ./crea_utenti.sh -c
```

3. Lo script:

   * crea utenti
   * genera password
   * imposta quota
   * crea spazio web
   * salva tutto nei log

---

## 🧩 Possibili miglioramenti futuri

* Interfaccia web di gestione
* Integrazione LDAP/Active Directory
* Invio automatico email con credenziali
* Supporto database utenti
* Dashboard monitoraggio spazio disco

---

## 👨‍💻 Autore

Script per gestione utenti scolastici
Versione: 2.0 – Aprile 2026

---

## 📜 Licenza

Open Source – libero utilizzo e modifica

---

## 🆘 Supporto

Per assistenza:
📧 [arg0netds@gmail.com](mailto:arg0netds@gmail.com)
