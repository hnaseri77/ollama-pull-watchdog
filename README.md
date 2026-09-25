# Ollama Pull Watchdog 🚀

[![Bash Script](https://img.shields.io/badge/Language-Bash-4EAA25.svg)](https://www.gnu.org/software/bash/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Ollama](https://img.shields.io/badge/Ollama-Compatible-black.svg)](https://ollama.ai)

A lightweight, zero-dependency Bash watchdog script designed to ensure reliable, uninterrupted downloads of large [Ollama](https://ollama.com/) models (e.g., `deepseek-r1:32b`, `qwen2.5-coder:32b`) over unstable or slow internet connections.

---

## 📌 The Problem

When downloading large LLM models using `ollama pull` on high-latency or unstable networks, downloads frequently stall (hang at 0 KB/s or stuck percentages) without exiting or throwing an error. Because the process remains alive, traditional retry loops fail to detect the failure, leaving your download frozen indefinitely.

## ✨ The Solution

**Ollama Pull Watchdog** runs alongside Ollama, measuring real-time network throughput directly from `/proc/net/dev`. If the download speed drops below a user-defined threshold, the script forcefully terminates the stalled process (`kill -9`) and automatically resumes the download from where it left off—all without root privileges (`sudo`).

---

## 🔑 Key Features

- **No `sudo` Required:** Reads network interface bytes via `/proc/net/dev` for non-privileged execution.
- **Custom Speed Thresholds:** Supports flexible speed definitions in `KB/s` or `MB/s` (e.g., `200K`, `1.5M`).
- **Enforced Safe Speed Limits:** Automatically sets a minimum safety floor (100 KB/s) to prevent premature termination during normal network jitter.
- **Connection Grace Period:** Includes a 4-second initialization delay to allow connection handshakes and manifest retrieval before speed evaluation begins.
- **Clean Signal Trapping:** Handles `Ctrl+C` (`SIGINT`) gracefully, terminating background tasks cleanly without infinite-loop traps.
- **Disk Usage Reporting:** Reports total downloaded blob size on each reconnect.
- **Desktop Notifications:** Sends system notifications via `notify-send` upon 100% download completion.

---

## 🛠️ Prerequisites

- **Linux OS** (Fedora, Ubuntu, Debian, Arch, etc.)
- **Ollama** installed and running.
- Basic utilities: `bash`, `awk`, `du` (installed by default on most Linux distributions).
- *(Optional)* `libnotify` for desktop notifications (`notify-send`).

---

## 🚀 Quick Start

### 1. Clone the Repository
```bash
git clone https://github.com/hnaseri77/ollama-pull-watchdog.git
cd ollama-pull-watchdog
```

### 2. Make the Script Executable
```bash
chmod +x ollama-pull-watchdog.sh
```

### 3. Run the Watchdog

#### Option A: Interactive Mode
Run the script without arguments, and it will prompt you for input:
```bash
./ollama-pull-watchdog.sh
```

#### Option B: Command Line Arguments
Pass the model name and optional speed threshold directly:
```bash
# Default speed threshold (200 KB/s)
./ollama-pull-watchdog.sh deepseek-r1:32b

# Custom threshold in KB/s
./ollama-pull-watchdog.sh qwen2.5-coder:32b 300K

# Custom threshold in MB/s
./ollama-pull-watchdog.sh llama3.3:70b 1.5M
```

---

## ⚙️ Speed Units & Configuration

| Input Example | Target Minimum Speed |
| :--- | :--- |
| `150K` / `150k` | 150 KB/s |
| `200K` *(Default)* | 200 KB/s |
| `1M` / `1m` | 1024 KB/s (1 MB/s) |
| `1.5M` | 1536 KB/s (1.5 MB/s) |

> **Note:** Any speed input lower than `100K` will automatically be elevated to `100K` to prevent unnecessary connection restarts.

---

## 🔍 How It Works

1. **Initialization:** Spawns `ollama pull <model>` as a background job.
2. **Grace Period:** Pauses for 4 seconds to let Ollama finish TLS handshakes and retrieve model manifests.
3. **Speed Sampling:** Reads network rx-bytes every 4 seconds and calculates average throughput:
   $$\text{Speed (KB/s)} = \frac{\Delta \text{Bytes}}{4 \times 1024}$$
4. **Action:** If throughput drops below the minimum speed threshold, the script kills the process, waits 4 seconds, and restarts the download loop seamlessly.

---

## 📜 License

This project is licensed under the [MIT License](LICENSE).
