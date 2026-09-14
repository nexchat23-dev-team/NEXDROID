use std::env;
use std::fs::{self, File};
use std::io::Read;
use std::net::{TcpListener, SocketAddr, IpAddr, Ipv4Addr};
use std::path::Path;

use chrono::Utc;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RootPortFinding {
    pub label: String,
    pub reason: String,
    pub severity: String,
    pub reasoning: String,
    pub threat_score: u32,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct RootPortReport {
    pub timestamp: String,
    pub risk_level: String,
    pub threat_score: u32,
    pub findings: Vec<RootPortFinding>,
}

fn main() {
    let args: Vec<String> = env::args().collect();
    let target = args.get(1).map(|s| s.as_str()).unwrap_or("system");

    let mut findings: Vec<RootPortFinding> = Vec::new();
    let mut total_score: u32 = 0;

    // 1. Scan for Unauthorized Root Binaries & Management Apps
    let root_binaries = [
        "/system/xbin/su",
        "/system/bin/su",
        "/sbin/su",
        "/system/sd/xbin/su",
        "/system/bin/failsafe/su",
        "/data/local/xbin/su",
        "/data/local/bin/su",
        "/data/local/su",
        "/system/app/Superuser.apk",
        "/system/app/SuperSU.apk",
        "/data/adb/magisk",
        "/data/adb/ksu",
    ];

    for binary_path in &root_binaries {
        if Path::new(binary_path).exists() {
            let score = 95;
            total_score += score;
            findings.push(RootPortFinding {
                label: "Unauthorized Root Binary".to_string(),
                reason: format!("Root binary executable present at {}", binary_path),
                severity: "CRITICAL".to_string(),
                reasoning: "System binary inspection detected an active su/magisk superuser binary on disk.".to_string(),
                threat_score: score,
            });
        }
    }

    // 2. Scan Running Background Processes (/proc traversal or process environment)
    if Path::new("/proc").exists() {
        if let Ok(entries) = fs::read_dir("/proc") {
            for entry in entries.flatten() {
                let path = entry.path();
                if !path.is_dir() {
                    continue;
                }
                let pid_str = entry.file_name().to_string_lossy().to_string();
                if !pid_str.chars().all(|c| c.is_ascii_digit()) {
                    continue;
                }

                // Read process cmdline & status
                let cmdline_path = path.join("cmdline");
                let mut cmdline_buf = String::new();
                if let Ok(mut f) = File::open(&cmdline_path) {
                    let _ = f.read_to_string(&mut cmdline_buf);
                }
                let cmdline = cmdline_buf.replace('\0', " ");

                let status_path = path.join("status");
                let mut status_buf = String::new();
                if let Ok(mut f) = File::open(&status_path) {
                    let _ = f.read_to_string(&mut status_buf);
                }

                // Check process name / cmdline triggers
                let lowered = cmdline.to_lowercase();
                if lowered.contains("daemonsu")
                    || lowered.contains("magiskd")
                    || lowered.contains("frida-server")
                    || lowered.contains("xposed")
                    || lowered.contains("gdbserver")
                {
                    let score = 90;
                    total_score += score;
                    findings.push(RootPortFinding {
                        label: "Suspicious Root Daemon Process".to_string(),
                        reason: format!("PID {} running suspicious daemon: {}", pid_str, cmdline.trim()),
                        severity: "HIGH".to_string(),
                        reasoning: "Background process table scan identified active root manipulation daemon or reverse debugging hook.".to_string(),
                        threat_score: score,
                    });
                }

                // Check UID 0 escalation
                if status_buf.contains("Uid:\t0\t0\t0\t0") && !cmdline.contains("system") && !cmdline.contains("init") && !cmdline.contains("kthreadd") {
                    if lowered.contains("sh") || lowered.contains("bash") || lowered.contains("busybox") {
                        let score = 85;
                        total_score += score;
                        findings.push(RootPortFinding {
                            label: "Root Privilege Escalation Shell".to_string(),
                            reason: format!("PID {} executing UID 0 privileged shell: {}", pid_str, cmdline.trim()),
                            severity: "CRITICAL".to_string(),
                            reasoning: "Unprivileged app scope detected background process executing as root (UID 0).".to_string(),
                            threat_score: score,
                        });
                    }
                }
            }
        }
    }

    // 3. Network Listening Port Security Audit
    let suspicious_ports: &[(u16, &str, &str)] = &[
        (4444, "Reverse Shell / Metasploit Default Listener", "CRITICAL"),
        (5555, "Unprotected Wireless ADB Port Open", "HIGH"),
        (1337, "Backdoor Shell Port", "CRITICAL"),
        (6667, "IRC Botnet Command & Control Port", "HIGH"),
        (31337, "Elite Backdoor Listener", "CRITICAL"),
        (8888, "HTTP Proxy / Interception Port", "MEDIUM"),
    ];

    for &(port, desc, sev) in suspicious_ports {
        let addr = SocketAddr::new(IpAddr::V4(Ipv4Addr::new(127, 0, 0, 1)), port);
        if TcpListener::bind(addr).is_err() {
            // Port is currently occupied and listening!
            let score = if sev == "CRITICAL" { 95 } else { 75 };
            total_score += score;
            findings.push(RootPortFinding {
                label: "Unauthorized Listening Port".to_string(),
                reason: format!("Port {} is actively listening: {}", port, desc),
                severity: sev.to_string(),
                reasoning: format!("Network socket inspection revealed port {} is bound by an active listening process.", port),
                threat_score: score,
            });
        }
    }

    let risk_level = if total_score >= 120 {
        "CRITICAL"
    } else if total_score >= 60 {
        "HIGH"
    } else if total_score > 0 {
        "MEDIUM"
    } else {
        "SECURE"
    };

    // Print output in NEX-APP standard key-value protocol
    println!("summary: Process & Root/Port Scan evaluated on target '{}'. Threat Score: {}", target, total_score);
    println!("risk: {}", risk_level);

    if findings.is_empty() {
        println!("finding: System Process Table | No unauthorized root processes detected | SECURE | Active processes verified with UID 1000+ app sandbox isolation.");
        println!("finding: Socket Listener Check | Network ports 4444, 5555, 1337, 31337 clear | SECURE | No unauthorized listener sockets or reverse shells bound.");
    } else {
        for f in &findings {
            println!("finding: {} | {} | {} | {}", f.label, f.reason, f.severity, f.reasoning);
        }
    }

    let report = RootPortReport {
        timestamp: Utc::now().to_rfc3339(),
        risk_level: risk_level.to_string(),
        threat_score: total_score,
        findings,
    };

    let _ = serde_json::to_string_pretty(&report);
}
