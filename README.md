# 🖥️ Linux Monitoring & Alerting Script

This is a lightweight Bash monitoring script designed to run on a Linux server or virtual machine. It checks for critical system health indicators and sends you an email alert if anything needs attention.

## 📌 Before You Start

Make sure to:

 Add your email address and set your preferred alert thresholds in the .env file.



## 🚀 How to Run
You can run the script manually or schedule it via cron:
```bash
bash monitor.sh
```
To run it periodically (e.g., every hour), add this to your crontab:
```bash
0 * * * * /path/to/monitor.sh
```

## 💡 Why I Created This
As part of my journey learning and practicing DevOps skills, I built this script to simulate real-world monitoring and alerting pipelines on a Linux-based server. The goal was to:

Reinforce Bash scripting and systems knowledge

Build hands-on Linux experience

Integrate log capture, alert logic, and basic CI/CD patterns

Create a reusable health-check tool for small projects or home labs

## 🔍 What It Checks
Check Type	What it does
CPU usage	Detects high overall CPU load and CPU-hungry processes
Memory usage	Checks both global and per-process memory consumption
Disk space	Warns when disk usage is high
Docker logs	Scans for errors in logs from running and stopped containers
DNS check	Verifies important domain names resolve correctly
System services	Ensures essential services are active
Nginx config	Tests Nginx syntax validity (if installed)

All output is logged to a timestamped file in:
/monitore/logs/


## ✉️ Email Alerting
If any issues are detected, the script will automatically email the full log using ssmtp.

To make this work:

Install ssmtp on your system.

Configure it to send emails via your SMTP provider (e.g., Gmail).

Make sure your .env contains a valid recipient in TEST_MAIL.
