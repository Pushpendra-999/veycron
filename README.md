# veycron

**Automated Database Backup Service for Cloudflare R2**

A self-contained CLI service that schedules MongoDB and PostgreSQL database backups to Cloudflare R2 object storage, with cron scheduling, email notifications, and retention policies — all configured from the terminal.

```
  ██╗   ██╗███████╗██╗   ██╗ ██████╗██████╗  ██████╗ ███╗   ██╗
  ██║   ██║██╔════╝╚██╗ ██╔╝██╔════╝██╔══██╗██╔═══██╗████╗  ██║
  ██║   ██║█████╗   ╚████╔╝ ██║     ██████╔╝██║   ██║██╔██╗ ██║
  ╚██╗ ██╔╝██╔══╝    ╚██╔╝  ██║     ██╔══██╗██║   ██║██║╚██╗██║
   ╚████╔╝ ███████╗   ██║   ╚██████╗██║  ██║╚██████╔╝██║ ╚████║
    ╚═══╝  ╚══════╝   ╚═╝    ╚═════╝╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═══╝
```

> **Copyright (c) 2026 veycron**  
> **All rights and ownership belong to [https://github.com/Pushpendra-999/veycron.git](https://github.com/Pushpendra-999/veycron.git)**  
> See [POLICY.md](POLICY.md) for full policy, terms of service, and privacy details.

---

## Features

- **Multi-database support** — PostgreSQL (`pg_dump`) and MongoDB (`mongodump`)
- **Cloudflare R2 storage** — Upload backups to R2 via rclone with automatic path organization (`project/year/month/`)
- **Cron scheduling** — Automated backups on any cron schedule
- **Email notifications** — SMTP-based alerts on backup success/failure with project name in subject
- **Retention policies** — Auto-delete backups older than N days
- **Compression** — Gzip compression for smaller uploads
- **Multi-project** — Manage unlimited backup projects on one server
- **Interactive menu** — Full TUI menu or direct CLI commands
- **Zero UI** — 100% terminal-based, designed for headless servers
- **Install from GitHub** — One-line install, automatic updates
- **100% Self-Hosted & Private** — Zero telemetry, credentials stored with restricted permissions

## Requirements

| Tool       | Purpose              | Required |
|------------|----------------------|----------|
| `bash`     | Shell runtime        | ✅       |
| `jq`       | JSON config handling | ✅       |
| `rclone`   | R2 uploads           | ✅       |
| `crontab`  | Job scheduling       | ✅       |
| `curl`     | SMTP emails          | ✅       |
| `gzip`     | Compression          | ✅       |
| `pg_dump`  | PostgreSQL backups   | For PG   |
| `mongodump`| MongoDB backups      | For Mongo|

## Installation

### One-line install from GitHub

```bash
curl -fsSL https://raw.githubusercontent.com/Pushpendra-999/veycron/main/install.sh | sudo bash
```

### Manual install

```bash
git clone https://github.com/Pushpendra-999/veycron.git /opt/veycron
chmod +x /opt/veycron/bin/veycron
ln -sf /opt/veycron/bin/veycron /usr/local/bin/veycron
veycron init
```

### Install rclone (if not installed)

```bash
curl https://rclone.org/install.sh | sudo bash
```

## Quick Start

```bash
# 1. Initialize veycron
veycron init

# 2. Create a backup project (guided wizard)
veycron new

# 3. Configure email notifications
veycron smtp setup

# 4. Test a manual backup
veycron run my-project

# 5. Check status
veycron status
```

## Commands

### Core Commands

| Command              | Description                                   |
|----------------------|-----------------------------------------------|
| `veycron init`       | Initialize veycron (create directories/config) |
| `veycron menu`       | Open interactive menu                         |
| `veycron new`        | Create a new backup project (guided wizard)   |
| `veycron list`       | List all configured projects                  |
| `veycron status`     | Show status of all projects and system health |
| `veycron run <name>` | Manually trigger a backup                     |
| `veycron logs [name]`| View logs (all or project-specific)           |

### SMTP Commands

| Command              | Description                          |
|----------------------|--------------------------------------|
| `veycron smtp setup` | Configure SMTP email settings        |
| `veycron smtp status`| Show SMTP configuration status       |
| `veycron smtp test`  | Send a test email                    |

### Cron Commands

| Command                    | Description                     |
|----------------------------|---------------------------------|
| `veycron cron status`      | Show all cron jobs              |
| `veycron cron enable <name>` | Enable cron for a project     |
| `veycron cron disable <name>`| Disable cron for a project    |

### Management Commands

| Command                | Description                            |
|------------------------|----------------------------------------|
| `veycron edit <name>`  | Edit a project's configuration         |
| `veycron delete <name>`| Delete a project and its cron job      |
| `veycron doctor`       | Check system dependencies and health   |
| `veycron policy`       | Display copyright terms & policy info  |
| `veycron version`      | Show version and ownership details     |
| `veycron help`         | Show help                              |

## Setup Wizard (`veycron new`)

The `new` command walks you through a guided setup:

1. **Project name** — A slug identifier for this backup (e.g., `my-saas-app`)
2. **Database type** — PostgreSQL or MongoDB
3. **Database URI** — Connection string (entered securely, not echoed)
4. **Database name** — Which database to dump
5. **R2 credentials** — Access key, secret key, endpoint URL, bucket name
6. **Schedule** — Cron expression for automated backups
7. **Retention** — How many days to keep old backups
8. **Compression** — Whether to gzip the dump
9. **Email notifications** — Whether to send alerts and to which addresses

## Email Notifications

Emails include the **project name** in the subject line:

- ✅ `[my-saas-app] Backup Successful`
- ❌ `[my-saas-app] Backup FAILED`

The body includes project name, database type, file path, size, timestamp, and server hostname.

Configure SMTP once globally; each project can have its own list of notification recipients.

## Directory Structure

```
/opt/veycron/              # Installation (from GitHub)
├── bin/veycron             # CLI entry point
├── lib/                    # Library modules
├── install.sh              # Installer
├── uninstall.sh            # Uninstaller
├── POLICY.md               # Copyright terms & privacy policy
├── LICENSE                 # License terms & ownership
└── README.md

/etc/veycron/               # Data (configs, logs, secrets)
├── config.json             # Global config (SMTP, etc.)
├── rclone.conf             # Rclone remotes for R2
├── projects/               # Per-project configs
│   ├── my-app.json
│   └── staging-db.json
├── logs/                   # Log files
│   ├── system.log
│   ├── my-app.log
│   └── my-app-cron.log
└── tmp/                    # Temporary dump files
```

## Backup File Organization

Backups are stored in R2 with organized paths:

```
bucket-name/
└── project-name/
    └── 2026/
        └── 11/
            ├── project-name_20261124_020000.sql.gz
            └── project-name_20261125_020000.sql.gz
```

## Security

- All config files are stored with `chmod 600` (owner read/write only)
- Database URIs and SMTP passwords are stored in JSON config (not env vars)
- The `/etc/veycron` directory is `chmod 700`
- Secrets are entered with no-echo prompts
- Rclone uses a dedicated config file per installation
- Zero external telemetry or tracking

## Uninstall

```bash
sudo bash /opt/veycron/uninstall.sh
```

This removes the binary, symlink, and cron jobs. You'll be asked whether to keep the data directory.

## Copyright, Ownership & Policy

- **Copyright (c) 2026 veycron**
- **All rights and ownership belong to [https://github.com/Pushpendra-999/veycron.git](https://github.com/Pushpendra-999/veycron.git)**
- Full policy and legal terms: [POLICY.md](POLICY.md)
- Licensed under the [MIT License](LICENSE).
