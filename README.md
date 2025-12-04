# LiteSpeed SSL Renewal Script (Webroot, Non-Interactive)

A **lightweight Bash script** to automatically renew SSL certificates for LiteSpeed web server sites using **Let's Encrypt** in **webroot mode**.  
The script handles:

- Automatic SSL renewal.
- Proper `.well-known/acme-challenge` creation with permissions.
- Fixing LiteSpeed vhost context if it points to the wrong directory.
- Verifying SSL certificates after renewal.

---

## Features

- Non-interactive, suitable for automated cron jobs.
- Detects if SSL is already valid and skips unnecessary renewals.
- Works for multiple domains with separate LiteSpeed users.
- Updates vhost configuration dynamically to point to the correct certificate files.
- Supports testing ACME challenge setup with a sample file.

---

## Requirements

- Linux server with **LiteSpeed Web Server** installed.
- `certbot` installed.
- `systemctl` for restarting/reloading LiteSpeed.
- Shell access to the server.

---

## Installation

1. Clone the repository or download the script:

```bash
git clone https://github.com/yourusername/renew_ssl.git
cd renew_ssl
```

2. Make the script executable:

```bash
chmod +x renew_sslcert.sh
```

3. Ensure certbot is installed:

```bash
sudo apt update
sudo apt install certbot -y
```

---

## Usage

```bash
./renew_sslcert.sh <domain>
```

### Example:

```bash
./renew_sslcert.sh example.com
```