# Security Policy

Foundation provisions a Mac. Its first run is a script you clone and execute, which downloads and
runs two installers from the internet and hands over to steps that use `sudo`:

```bash
git clone https://github.com/IvanPavlak/Foundation.git ~/Development/GitHub/Foundation
~/Development/GitHub/Foundation/Unix/bootstrap.sh
```

Because of this, we take the security of Foundation seriously and ask that you do too.

---

## Threat model

| Capability | Why it matters |
| --- | --- |
| **Installers piped into a shell** | `Unix/bootstrap.sh` installs chezmoi with `curl -fsLS https://get.chezmoi.io` when it is missing, and the first apply's `bootstrap-first-run` installs Homebrew with its official install script. Users trust those hosts, GitHub and the ref they cloned. |
| **`sudo` steps** | Bootstrap's power, firewall, software update and rename-the-Mac steps, and Homebrew itself, ask for the administrator password. A bug there acts with root rights. |
| **Installs third-party software** | `brew bundle` installs the formulae and casks of `Unix/Brewfile` and a fork's `Brewfile.local`; a malicious or typosquatted entry, or a trusted third-party tap, runs on the Mac. |
| **Links dotfiles and writes backups** | chezmoi links files into your home folder, replacing real files after copying them into `Backups/Unix/`. A path-handling bug could link over, or copy from, an unintended location. |
| **AI managed settings** | The AI artifacts step can write Claude Code's managed settings under `/Library/Application Support/ClaudeCode`, which bind every session on the Mac. |
| **Git credentials** | The shipped git overrides route GitHub credentials through the GitHub CLI (`gh auth git-credential`). Mishandling a token (logging it, writing it to a tracked file) is a security issue. |

### In scope

- Remote code execution, privilege escalation or arbitrary file writes introduced by Foundation
  code (`Unix/bootstrap.sh`, the Bootstrap steps, the commands and libraries).
- Command injection through config values, hostnames, paths or the `$DEV` / `$HOME` expansion.
- Leakage of secrets into logs (`Unix/logs`), console output, backups or committed files.
- Insecure download or verification logic.
- Link or path-traversal bugs that write outside the intended folders.

### Out of scope

- Vulnerabilities in software Foundation merely installs (report those upstream), unless Foundation
  pins a known-malicious version.
- Issues that need an attacker to already have administrator rights on the Mac.
- The inherent risk of running an installer script - documented and mitigated by the guidance
  below, not a bug.

---

## Supported versions

Security fixes go to `master` and the most recent tagged release.

| Version / ref | Supported |
| --- | --- |
| `master` (latest) | :white_check_mark: |
| Latest release tag | :white_check_mark: |
| Older tags / commits | :x: |
| Forks | :x: (report to the fork's maintainer) |

---

## Reporting a vulnerability

**Please do NOT report security vulnerabilities through public GitHub issues, discussions or pull
requests.**

Report privately using **GitHub Security Advisories**:

1. Go to the repository's **Security** tab.
2. Click **Report a vulnerability** to open a private
   [GitHub Security Advisory](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability).
3. Provide as much detail as you can: a description and its impact, the affected files or commands
   and the commit, step-by-step reproduction (a minimal config fragment or command line is ideal),
   and any proof of concept or log lines (redact secrets).

Please give us a reasonable opportunity to investigate and fix before any public disclosure. We
support coordinated disclosure and credit reporters (with permission).

### Response timeline

This is a personal project maintained in spare time; these are good-faith targets, not SLAs:

| Stage | Target |
| --- | --- |
| Acknowledge your report | within **72 hours** |
| Initial assessment | within **7 days** |
| Status updates | at least every **7 days** until resolved |
| Fix or mitigation for confirmed high-severity issues | typically within **30 days** |
| Public advisory and credit | after a fix is released (coordinated with you) |

---

## Guidance for users - review before running

- **Read [`Unix/bootstrap.sh`](bootstrap.sh) before running it**, and skim
  `Unix/modules/Bootstrap` and the Brewfiles. `Unix/bootstrap.sh --dry-run` and
  `Bootstrap --dry-run` say what they would do without doing it.
- **Clone a ref you have reviewed.** Prefer a tag over `master`, and review again when you update.
- **Inspect the config.** `Unix/Brewfile`, your `Brewfile.local`, `bootstrap.conf` and the `Unix/home`
  link templates decide what is installed, linked and changed. Do not run someone else's overlays
  blindly.
- **Never commit a token** or share a log that holds one.
- **Try it on a separate macOS user or a virtual machine first.**
- **Use the official repository**, `https://github.com/IvanPavlak/Foundation`; be wary of forks or
  copies elsewhere.

If something about a script looks wrong, stop and report it before running it.
