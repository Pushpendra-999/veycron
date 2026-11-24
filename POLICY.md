# veycron Terms of Service & Policy

**Version:** 1.0.0  
**Effective Date:** 2026  
**Official Repository:** [https://github.com/Pushpendra-999/veycron.git](https://github.com/Pushpendra-999/veycron.git)

---

## 1. Copyright & Ownership Statement

- **Copyright (c) 2026 veycron**.
- **All rights, title, interest, and intellectual property ownership belong exclusively to:**  
  👉 **`https://github.com/Pushpendra-999/veycron.git`**
- All copies, forks, distributions, or derivative works of veycron must retain this copyright and ownership attribution notice intact in all source files, documentation, and distributions.

---

## 2. Terms of Use

1. **Permitted Use:**  
   veycron is provided as a free, open-source server backup management utility under the terms of the [MIT License](LICENSE). You may use it for personal, commercial, and enterprise database backup workflows.

2. **Retention of Attribution:**  
   You agree not to remove, obfuscate, or alter any copyright notices, ownership statements, or legal notices affixed to or contained within veycron.

3. **User Responsibility:**  
   You are solely responsible for:
   - Ensuring you possess lawful authorization and permissions to access, dump, compress, and store the databases you configure.
   - Maintaining the security and confidentiality of your database credentials, Cloudflare R2 tokens, and SMTP credentials.
   - Verifying the integrity, completeness, and restorability of backup artifacts produced by your configured schedules.

---

## 3. Privacy, Data & Security Policy

1. **Zero Telemetry & Tracking:**  
   veycron is 100% self-hosted, headless, and privacy-respecting. It contains **no telemetry**, **no analytics**, and **no remote tracking**. No data is ever transmitted to the repository owners, third parties, or external monitoring endpoints.

2. **Data Flow & Storage:**  
   - All database dumps are generated locally on your server.
   - Backups are transferred directly from your server to your specified Cloudflare R2 bucket using your own rclone credentials.
   - Email notifications are transmitted directly from your server to your specified SMTP mail server.

3. **Local Credential Protection:**  
   - Configuration files are stored locally under `/etc/veycron/` with strict POSIX permissions (`chmod 600` for configs, `chmod 700` for directories).
   - Passwords and secret keys are collected via no-echo terminal prompts and stored only on your local filesystem.

---

## 4. Disclaimer of Warranty & Limitation of Liability

veycron is provided on an "AS IS" and "AS AVAILABLE" basis, without warranty of any kind, express or implied, including but not limited to the warranties of merchantability, fitness for a particular purpose, and non-infringement.

In no event shall the authors, copyright holders, or the repository [https://github.com/Pushpendra-999/veycron.git](https://github.com/Pushpendra-999/veycron.git) be held liable for any claim, damages, loss of data, backup failure, database corruption, or other liability arising from the use of or inability to use this software.

---

## 5. Contact & Upstream Inquiries

For official updates, issues, questions, and contributions, refer to the official repository:  
🌐 [https://github.com/Pushpendra-999/veycron.git](https://github.com/Pushpendra-999/veycron.git)
