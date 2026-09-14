use std::collections::HashMap;
use std::env;
use std::fs::{self, File};
use std::io::Read;
use std::path::{Path, PathBuf};
use std::sync::mpsc;
use std::sync::{Arc, Mutex};
use std::thread;

use chrono::Utc;
use regex::Regex;
use serde::{Deserialize, Serialize};

/// High-level Threat Finding representation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Finding {
    pub label: String,
    pub path: String,
    pub reason: String,
    pub severity: String, // CRITICAL, HIGH, MEDIUM, LOW, INFO
    pub reasoning: String,
    pub threat_score: u32, // 0 - 100
    pub recommendation: String,
}

/// Aggregated Scan Statistics & Intelligence Report
#[derive(Debug, Default, Serialize, Deserialize, Clone)]
pub struct ScanStats {
    pub files_scanned: usize,
    pub dirs_scanned: usize,
    pub total_bytes_scanned: u64,
    pub critical_matches: usize,
    pub high_matches: usize,
    pub medium_matches: usize,
    pub low_matches: usize,
    pub max_entropy_found: f64,
    pub overall_threat_score: u32,
    pub duration_ms: u128,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct FullReport {
    pub timestamp: String,
    pub root_path: String,
    pub risk_level: String,
    pub threat_score: u32,
    pub stats: ScanStats,
    pub findings: Vec<Finding>,
}

/// Calculate Shannon Entropy of binary byte array (0.0 to 8.0)
/// High entropy (> 7.2) indicates compressed, packed, or encrypted payloads
pub fn calculate_entropy(bytes: &[u8]) -> f64 {
    if bytes.is_empty() {
        return 0.0;
    }
    let mut frequency = [0usize; 256];
    for &b in bytes {
        frequency[b as usize] += 1;
    }
    let len = bytes.len() as f64;
    let mut entropy = 0.0f64;
    for &count in &frequency {
        if count > 0 {
            let p = count as f64 / len;
            entropy -= p * p.log2();
        }
    }
    entropy
}

/// Magic byte inspection for file format classification & header verification
pub fn inspect_magic_bytes(bytes: &[u8], file_name: &str) -> Option<(&'static str, &'static str, &'static str, u32)> {
    if bytes.len() < 4 {
        return None;
    }
    let lowered = file_name.to_lowercase();

    // PE / Windows Executable (0x4D 0x5A -> "MZ")
    if bytes[0] == 0x4D && bytes[1] == 0x5A {
        if lowered.ends_with(".png") || lowered.ends_with(".jpg") || lowered.ends_with(".txt") {
            return Some((
                "Executable Header Spoofing",
                "CRITICAL",
                "File has image/text extension but contains Windows PE executable binary header (MZ).",
                95,
            ));
        }
        return Some((
            "Windows PE Binary Detected",
            "HIGH",
            "File contains native Portable Executable compiled code.",
            75,
        ));
    }

    // ELF Executable / Shared Object (0x7F 'E' 'L' 'F')
    if bytes[0] == 0x7F && bytes[1] == b'E' && bytes[2] == b'L' && bytes[3] == b'F' {
        if lowered.ends_with(".png") || lowered.ends_with(".jpg") || lowered.ends_with(".json") {
            return Some((
                "Linux/Android ELF Spoofing",
                "CRITICAL",
                "File disguised as non-executable resource but contains raw ELF native binary header.",
                95,
            ));
        }
        return Some((
            "ELF Native Binary Detected",
            "HIGH",
            "Native Linux/Android executable or shared library (.so) detected.",
            70,
        ));
    }

    // Android DEX Bytecode (0x64 0x65 0x78 0x0A -> "dex\n")
    if bytes[0] == 0x64 && bytes[1] == 0x65 && bytes[2] == 0x78 && bytes[3] == 0x0A {
        return Some((
            "Dalvik Executable (DEX)",
            "MEDIUM",
            "Contains standalone Android Dalvik bytecode payload.",
            60,
        ));
    }

    // ZIP / APK / JAR / DOCX (0x50 0x4B 0x03 0x04 -> "PK..")
    if bytes[0] == 0x50 && bytes[1] == 0x4B && bytes[2] == 0x03 && bytes[3] == 0x04 {
        if lowered.ends_with(".apk") {
            return Some((
                "Android Package Archive (APK)",
                "HIGH",
                "APK package detected. Requires manifest permission and bytecode inspection.",
                65,
            ));
        }
    }

    None
}

/// Advanced Heuristic & YARA-style Regex Pattern Matcher
pub fn scan_content_patterns(content: &str, regexes: &HashMap<&str, (Regex, &'static str, &'static str, u32)>) -> Vec<Finding> {
    let mut findings = Vec::new();

    for (name, (re, severity, reasoning, score)) in regexes {
        if re.is_match(content) {
            findings.push(Finding {
                label: name.to_string(),
                path: String::new(),
                reason: name.to_string(),
                severity: severity.to_string(),
                reasoning: reasoning.to_string(),
                threat_score: *score,
                recommendation: format!("Quarantine file or review pattern match for {}", name),
            });
        }
    }

    findings
}

/// Build Regex Rule Registry
fn build_rule_registry() -> HashMap<&'static str, (Regex, &'static str, &'static str, u32)> {
    let mut rules = HashMap::new();

    rules.insert(
        "Reverse Shell / Socket Injection",
        (
            Regex::new(r"(?i)(nc\s+-e|bash\s+-i|/dev/tcp/|cmd\.exe\s+/c|powershell\s+-enc|powershell\.exe\s+-nop)").unwrap(),
            "CRITICAL",
            "Command line pattern used for establishing remote reverse shell connections.",
            98,
        ),
    );

    rules.insert(
        "Hardcoded AWS Access Key",
        (
            Regex::new(r"AKIA[0-9A-Z]{16}").unwrap(),
            "HIGH",
            "Hardcoded AWS Access Key ID discovered in source or configuration text.",
            85,
        ),
    );

    rules.insert(
        "Private RSA/PEM Key Leak",
        (
            Regex::new(r"-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----").unwrap(),
            "CRITICAL",
            "Unencrypted private key block found in file content.",
            95,
        ),
    );

    rules.insert(
        "Obfuscated Payload Execution",
        (
            Regex::new(r"(?i)(eval\(base64_decode|exec\(base64|Runtime\.getRuntime\(\)\.exec|ProcessBuilder)").unwrap(),
            "HIGH",
            "Obfuscated dynamic payload execution mechanism detected.",
            80,
        ),
    );

    rules.insert(
        "Dangerous Android Permissions",
        (
            Regex::new(r"(?i)(SYSTEM_ALERT_WINDOW|WRITE_SETTINGS|INSTALL_PACKAGES|READ_PRIVILEGED_PHONE_STATE|MOUNT_UNMOUNT_FILESYSTEMS|BIND_ACCESSIBILITY_SERVICE)").unwrap(),
            "MEDIUM",
            "High-privilege Android system permission request found.",
            60,
        ),
    );

    rules.insert(
        "Root Access Command Sequence",
        (
            Regex::new(r"(?i)(\bsu\s+-c\b|/system/xbin/su|/system/bin/su|\bchmod\s+777\b|\bchown\s+root\b)").unwrap(),
            "HIGH",
            "Privilege escalation or root access command sequence identified.",
            85,
        ),
    );

    rules.insert(
        "Potential Keylogger / Input Interception",
        (
            Regex::new(r"(?i)(SetWindowsHookEx|GetAsyncKeyState|GetKeyboardState|onKeyEvent|AccessibilityEvent)").unwrap(),
            "HIGH",
            "System hook or keystroke listening API calls found.",
            82,
        ),
    );

    rules.insert(
        "Insecure Plain HTTP Endpoint",
        (
            Regex::new(r"http://[a-zA-Z0-9\.\-]+\:[0-9]{2,5}").unwrap(),
            "LOW",
            "Unencrypted HTTP service connection string detected.",
            35,
        ),
    );

    rules
}

/// Scan a single file and generate findings
pub fn scan_single_file(path: &Path, rules: &HashMap<&str, (Regex, &'static str, &'static str, u32)>) -> (Vec<Finding>, u64, f64) {
    let mut findings = Vec::new();
    let mut file_size = 0u64;
    let mut entropy = 0.0f64;

    let path_str = path.to_string_lossy().to_string();
    let file_name = path.file_name().unwrap_or_default().to_string_lossy().to_string();

    if let Ok(metadata) = path.metadata() {
        file_size = metadata.len();
    }

    // Skip scanning files larger than 50MB for speed unless requested
    if file_size > 50 * 1024 * 1024 {
        findings.push(Finding {
            label: file_name.clone(),
            path: path_str.clone(),
            reason: "Oversized Payload File".into(),
            severity: "LOW".into(),
            reasoning: "File exceeds 50MB scan size safety margin.".into(),
            threat_score: 20,
            recommendation: "Inspect large archive manually if unexpected.".into(),
        });
        return (findings, file_size, 0.0);
    }

    if let Ok(mut f) = File::open(path) {
        let mut buffer = Vec::new();
        if f.read_to_end(&mut buffer).is_ok() {
            // 1. Calculate Entropy
            entropy = calculate_entropy(&buffer);
            if entropy > 7.35 && buffer.len() > 1024 {
                findings.push(Finding {
                    label: file_name.clone(),
                    path: path_str.clone(),
                    reason: "High Entropy (Packed / Encrypted)".into(),
                    severity: "HIGH".into(),
                    reasoning: format!("Entropy of {:.2} indicates obfuscated or packed binary payload.", entropy),
                    threat_score: 78,
                    recommendation: "Decompress or reverse-engineer binary payload.".into(),
                });
            }

            // 2. Magic Byte Header Checks
            if let Some((reason, severity, reasoning, score)) = inspect_magic_bytes(&buffer, &file_name) {
                findings.push(Finding {
                    label: file_name.clone(),
                    path: path_str.clone(),
                    reason: reason.into(),
                    severity: severity.into(),
                    reasoning: reasoning.into(),
                    threat_score: score,
                    recommendation: "Audit executable payload structure.".into(),
                });
            }

            // 3. UTF-8 Text Regex & Signature Scan
            if let Ok(text) = String::from_utf8(buffer) {
                let text_findings = scan_content_patterns(&text, rules);
                for mut tf in text_findings {
                    tf.path = path_str.clone();
                    tf.label = file_name.clone();
                    findings.push(tf);
                }
            }
        }
    }

    // 4. File Extension / Naming heuristics
    let lowered_name = file_name.to_lowercase();
    if lowered_name.contains("payload") || lowered_name.contains("loader") || lowered_name.contains("dropper") || lowered_name.contains("exploit") {
        findings.push(Finding {
            label: file_name.clone(),
            path: path_str.clone(),
            reason: "Suspicious Artifact Filename".into(),
            severity: "MEDIUM".into(),
            reasoning: "Filename pattern matches common exploit or malware dropper naming conventions.".into(),
            threat_score: 65,
            recommendation: "Inspect directory for malware staging.".into(),
        });
    }

    (findings, file_size, entropy)
}

fn main() {
    let start_time = std::time::Instant::now();
    let args: Vec<String> = env::args().collect();

    let mut root = ".";
    let mut json_mode = false;
    let mut max_threads = 4;

    let mut i = 1;
    while i < args.len() {
        match args[i].as_str() {
            "--json" => json_mode = true,
            "--path" if i + 1 < args.len() => {
                i += 1;
                root = &args[i];
            }
            "--threads" if i + 1 < args.len() => {
                i += 1;
                if let Ok(t) = args[i].parse::<usize>() {
                    max_threads = t.max(1).min(16);
                }
            }
            s if !s.startsWith('-') => root = s,
            _ => {}
        }
        i += 1;
    }

    let root_path = Path::new(root);
    let rules = Arc::new(build_rule_registry());

    // Collect target file list via WalkDir
    let mut file_queue = Vec::new();
    let mut dirs_scanned = 0usize;

    if root_path.exists() {
        if root_path.is_file() {
            file_queue.push(root_path.to_path_buf());
        } else {
            for entry in walkdir::WalkDir::new(root_path).into_iter().filter_map(|e| e.ok()) {
                if entry.file_type().is_dir() {
                    dirs_scanned += 1;
                } else if entry.file_type().is_file() {
                    file_queue.push(entry.path().to_path_buf());
                }
            }
        }
    }

    let total_files = file_queue.len();

    // Multi-threaded work distribution
    let (tx, rx) = mpsc::channel();
    let file_queue = Arc::new(Mutex::new(file_queue));

    let mut handles = Vec::new();
    for _ in 0..max_threads {
        let queue = Arc::clone(&file_queue);
        let rules_ref = Arc::clone(&rules);
        let thread_tx = tx.clone();

        let handle = thread::spawn(move || {
            loop {
                let next_file = {
                    let mut q = queue.lock().unwrap();
                    q.pop()
                };

                match next_file {
                    Some(path) => {
                        let (findings, bytes, entropy) = scan_single_file(&path, &rules_ref);
                        let _ = thread_tx.send((findings, bytes, entropy));
                    }
                    None => break,
                }
            }
        });
        handles.push(handle);
    }
    drop(tx); // Drop master sender so rx closes when threads finish

    let mut all_findings = Vec::new();
    let mut stats = ScanStats {
        files_scanned: total_files,
        dirs_scanned,
        ..Default::default()
    };

    while let Ok((findings, bytes, entropy)) = rx.recv() {
        stats.total_bytes_scanned += bytes;
        if entropy > stats.max_entropy_found {
            stats.max_entropy_found = entropy;
        }

        for finding in findings {
            match finding.severity.as_str() {
                "CRITICAL" => stats.critical_matches += 1,
                "HIGH" => stats.high_matches += 1,
                "MEDIUM" => stats.medium_matches += 1,
                "LOW" => stats.low_matches += 1,
                _ => {}
            }
            all_findings.push(finding);
        }
    }

    for handle in handles {
        let _ = handle.join();
    }

    stats.duration_ms = start_time.elapsed().as_millis();

    // Calculate Overall Threat Score (0 - 100)
    let calculated_score = (stats.critical_matches * 30 + stats.high_matches * 15 + stats.medium_matches * 5 + stats.low_matches * 1) as u32;
    let overall_threat_score = calculated_score.min(100);
    stats.overall_threat_score = overall_threat_score;

    let risk_level = match overall_threat_score {
        80..=100 => "CRITICAL RISK",
        50..=79 => "HIGH RISK",
        20..=49 => "MEDIUM RISK",
        1..=19 => "LOW RISK",
        
        _ => "CLEAN",
    };

    if json_mode {
        let report = FullReport {
            timestamp: Utc::now().to_rfc3339(),
            root_path: root_path.to_string_lossy().to_string(),
            risk_level: risk_level.to_string(),
            threat_score: overall_threat_score,
            stats,
            findings: all_findings,
        };
        println!("{}", serde_json::to_string_pretty(&report).unwrap_or_default());
    } else {
        println!("summary:NEX Multi-Threaded Security Engine scanned {} files across {} dirs in {}ms.", stats.files_scanned, stats.dirs_scanned, stats.duration_ms);
        println!("risk:{}", risk_level);
        println!("threat_score:{}", overall_threat_score);
        println!("stats:files={}|dirs={}|bytes={}|critical={}|high={}|medium={}|low={}|max_entropy={:.2}",
            stats.files_scanned, stats.dirs_scanned, stats.total_bytes_scanned, stats.critical_matches, stats.high_matches, stats.medium_matches, stats.low_matches, stats.max_entropy_found
        );

        for f in &all_findings {
            println!("finding:{}|{}|{}|{}|score={}", f.label, f.reason, f.severity, f.reasoning, f.threat_score);
        }
    }
}
