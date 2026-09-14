import 'dart:math';

class SecurityFinding {
  const SecurityFinding({
    required this.label,
    required this.reason,
    required this.severity,
    required this.reasoning,
    this.threatScore = 10,
    this.recommendation = 'Quarantine or inspect file before execution.',
  });

  final String label;
  final String reason;
  final String severity; // High, Medium, Low, Critical
  final String reasoning;
  final int threatScore; // 0 to 100
  final String recommendation;
}

/// Advanced Mime & Binary Header Inspector
String inferMimeType(String fileName, String? content, List<int>? bytes) {
  final lower = fileName.toLowerCase();

  if (bytes != null && bytes.length >= 4) {
    // ZIP / APK / JAR / DOCX / XLSX (0x50 0x4B 0x03 0x04)
    if (bytes[0] == 0x50 && bytes[1] == 0x4B && bytes[2] == 0x03 && bytes[3] == 0x04) {
      if (lower.endsWith('.apk')) return 'application/vnd.android.package-archive';
      if (lower.endsWith('.jar')) return 'application/java-archive';
      return 'application/zip';
    }
    // ELF Executable (Android / Linux) (0x7F 0x45 0x4C 0x46)
    if (bytes[0] == 0x7F && bytes[1] == 0x45 && bytes[2] == 0x4C && bytes[3] == 0x46) {
      return 'application/x-executable';
    }
    // Windows PE / EXE / DLL (0x4D 0x5A)
    if (bytes[0] == 0x4D && bytes[1] == 0x5A) {
      return 'application/x-msdownload';
    }
    // PDF Document (0x25 0x50 0x44 0x46)
    if (bytes[0] == 0x25 && bytes[1] == 0x50 && bytes[2] == 0x44 && bytes[3] == 0x46) {
      return 'application/pdf';
    }
  }

  if (lower.endsWith('.apk')) return 'application/vnd.android.package-archive';
  if (lower.endsWith('.jar')) return 'application/java-archive';
  if (lower.endsWith('.dex')) return 'application/x-android-dex';
  if (lower.endsWith('.so')) return 'application/x-sharedlib';
  if (lower.endsWith('.sh') || lower.endsWith('.bash')) return 'text/x-shellscript';
  if (lower.endsWith('.py')) return 'text/x-python';
  if (lower.endsWith('.js')) return 'application/javascript';
  if (lower.endsWith('.xml')) return 'application/xml';
  if (lower.endsWith('.txt') || lower.endsWith('.log')) return 'text/plain';

  if (content != null && content.contains('<manifest') && content.contains('android:name')) {
    return 'application/xml';
  }

  return 'application/octet-stream';
}

/// Calculate Shannon Entropy to detect packed / encrypted malware blobs
double calculateEntropy(List<int> bytes) {
  if (bytes.isEmpty) return 0.0;
  final frequencies = Map<int, int>();
  for (final byte in bytes) {
    frequencies[byte] = (frequencies[byte] ?? 0) + 1;
  }
  double entropy = 0.0;
  final len = bytes.length.toDouble();
  for (final count in frequencies.values) {
    final p = count / len;
    entropy -= p * (log(p) / log(2));
  }
  return entropy;
}

/// Comprehensive Security Threat Signal Detector
List<SecurityFinding> detectSuspiciousSignals(
  String fileName,
  int sizeBytes,
  String? content, [
  List<int>? bytes,
]) {
  final lower = fileName.toLowerCase();
  final findings = <SecurityFinding>[];
  final mimeType = inferMimeType(fileName, content, bytes);
  final contentValue = content?.toLowerCase() ?? '';

  // 1. High-Risk Binary Package Check
  if (lower.endsWith('.apk') ||
      lower.endsWith('.dex') ||
      lower.endsWith('.so') ||
      lower.endsWith('.exe') ||
      mimeType.contains('x-executable') ||
      mimeType.contains('package-archive')) {
    findings.add(const SecurityFinding(
      label: 'Executable / Package Artifact',
      reason: 'Binary package detected',
      severity: 'High',
      threatScore: 65,
      reasoning: 'Installable binaries or shared libraries can execute native bytecode and bypass user sandbox.',
      recommendation: 'Verify digital signature before granting package installation permissions.',
    ));
  }

  // 2. High Entropy Analysis (Packed Malware Indicator)
  if (bytes != null && bytes.length > 1024) {
    final entropy = calculateEntropy(bytes.sublist(0, min(bytes.length, 65536)));
    if (entropy > 7.4) {
      findings.add(SecurityFinding(
        label: 'High Entropy Payload (${entropy.toStringAsFixed(2)})',
        reason: 'Possible encrypted/packed malware',
        severity: 'High',
        threatScore: 85,
        reasoning: 'Entropy score above 7.4 indicates heavily obfuscated or packed executable payload.',
        recommendation: 'Subject payload to deep dynamic sandbox analysis.',
      ));
    }
  }

  // 3. Android High-Risk Permission Analysis
  final dangerousPermissions = [
    'system_alert_window',
    'receive_boot_completed',
    'read_sms',
    'send_sms',
    'install_packages',
    'device_admin',
    'bind_accessibility_service',
    'request_install_packages',
    'read_call_log',
    'record_audio',
    'camera',
  ];

  for (final perm in dangerousPermissions) {
    if (contentValue.contains(perm)) {
      findings.add(SecurityFinding(
        label: 'Dangerous Permission: ${perm.toUpperCase()}',
        reason: 'Android Manifest Security Risk',
        severity: (perm == 'bind_accessibility_service' || perm == 'device_admin') ? 'Critical' : 'High',
        threatScore: 90,
        reasoning: 'Permission "$perm" can be exploited for keylogging, overlay attacks, or persistent backdoor access.',
        recommendation: 'Restrict or revoke this permission in app settings.',
      ));
    }
  }

  // 4. Reverse Shell & Exploitative Command Signature Engine
  final exploits = [
    ('nc -e', 'Netcat Reverse Shell', 'Critical', 95),
    ('/bin/sh', 'Shell Binary Execution', 'High', 80),
    ('chmod 777', 'Insecure File Permission Grant', 'High', 75),
    ('eval(base64', 'Obfuscated Script Execution', 'High', 85),
    ('su -c', 'Root Privilege Escalation Demand', 'Critical', 95),
    ('ptrace', 'Process Injection / Debug Hooking', 'High', 80),
    ('mprotect', 'Dynamic Memory Protection Bypass', 'High', 85),
    ('pm install', 'Silent APK Auto-Installer', 'High', 70),
    ('curl | sh', 'Remote Pipeline Execution', 'Critical', 95),
  ];

  for (final (sig, label, sev, score) in exploits) {
    if (contentValue.contains(sig)) {
      findings.add(SecurityFinding(
        label: label,
        reason: 'Exploit Pattern Matched',
        severity: sev,
        threatScore: score,
        reasoning: 'Contains signature "$sig" frequently associated with rootkits, trojans, or remote access tools.',
        recommendation: 'Quarantine immediately and block execution.',
      ));
    }
  }

  // 5. Sensitive Credential & Keyword Detection
  if (lower.contains('password') ||
      lower.contains('secret') ||
      lower.contains('private_key') ||
      lower.contains('id_rsa') ||
      lower.contains('keystore')) {
    findings.add(const SecurityFinding(
      label: 'Sensitive Secret Asset',
      reason: 'Key / Credential Exposure Risk',
      severity: 'Medium',
      threatScore: 50,
      reasoning: 'File name suggests unencrypted private key, certificate, or password storage.',
      recommendation: 'Move file into Secure Vault.',
    ));
  }

  // 6. Large File Size Warning
  if (sizeBytes > 250 * 1024 * 1024) {
    findings.add(SecurityFinding(
      label: 'Large Binary Dump (${(sizeBytes / 1024 / 1024).toStringAsFixed(1)} MB)',
      reason: 'Oversized Asset',
      severity: 'Low',
      threatScore: 20,
      reasoning: 'Payload size exceeds typical application parameters.',
      recommendation: 'Scan disk usage and archive if unneeded.',
    ));
  }

  return findings;
}

/// Advanced HTML Security Audit Report Builder
String buildReportHtml(String title, String summary, List<SecurityFinding> findings) {
  final rows = findings.map((f) {
    final color = f.severity == 'Critical'
        ? '#EF4444'
        : f.severity == 'High'
            ? '#F97316'
            : f.severity == 'Medium'
                ? '#3B82F6'
                : '#22C55E';
    return '''
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.1);">
      <td style="padding:10px; font-weight:bold; color:#FFF;">${f.label}</td>
      <td style="padding:10px; color:#A0AEC0;">${f.reason}</td>
      <td style="padding:10px; color:$color; font-weight:bold;">${f.severity} (${f.threatScore}/100)</td>
      <td style="padding:10px; color:#CBD5E1;">${f.reasoning}</td>
      <td style="padding:10px; color:#22C55E; font-size:11px;">${f.recommendation}</td>
    </tr>''';
  }).join();

  final overallRisk = findings.any((f) => f.severity == 'Critical' || f.severity == 'High')
      ? 'CRITICAL RISK DETECTED'
      : findings.isEmpty
          ? 'SYSTEM HEALTHY - NO THREATS'
          : 'NEEDS REVIEW';

  return '''<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <title>$title</title>
    <style>
      body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: #060A18; color: #FFF; padding: 24px; }
      h1 { color: #22C55E; margin-bottom: 4px; }
      .badge { display: inline-block; padding: 6px 14px; background: rgba(34, 197, 94, 0.2); border: 1px solid #22C55E; border-radius: 999px; font-size: 12px; font-weight: bold; color: #22C55E; }
      table { width: 100%; border-collapse: collapse; margin-top: 20px; background: #0F172A; border-radius: 12px; overflow: hidden; }
      th { background: #1E293B; padding: 12px; text-align: left; font-size: 12px; color: #94A3B8; }
    </style>
  </head>
  <body>
    <h1>$title</h1>
    <div class="badge">$overallRisk</div>
    <p style="color:#94A3B8; margin-top: 12px;">$summary</p>
    <table>
      <thead>
        <tr>
          <th>Finding</th>
          <th>Type</th>
          <th>Severity & Score</th>
          <th>Reasoning</th>
          <th>Remediation</th>
        </tr>
      </thead>
      <tbody>$rows</tbody>
    </table>
  </body>
</html>''';
}

/// Text Security Audit Report Builder
String buildReportText(String title, String summary, List<SecurityFinding> findings) {
  final buffer = StringBuffer();
  buffer.writeln('====================================================');
  buffer.writeln(' $title');
  buffer.writeln('====================================================');
  buffer.writeln(summary);
  buffer.writeln('');
  buffer.writeln('DETAILED THREAT FINDINGS:');
  buffer.writeln('----------------------------------------------------');
  for (final f in findings) {
    buffer.writeln('[${f.severity.toUpperCase()}] (${f.threatScore}/100) ${f.label}');
    buffer.writeln('  Reason: ${f.reason}');
    buffer.writeln('  Details: ${f.reasoning}');
    buffer.writeln('  Action: ${f.recommendation}');
    buffer.writeln('');
  }
  return buffer.toString();
}
