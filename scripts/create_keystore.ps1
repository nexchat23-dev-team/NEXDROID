<#
Create a release keystore and key.properties for Android release builds.
Usage: run this from the project root in PowerShell (Admin not required):

    .\scripts\create_keystore.ps1

The script will ask for passwords and create:
 - android/app/keystore.jks
 - key.properties (in project root)

You must have `keytool` installed (comes with JDK). If `keytool` isn't found, install a JDK and ensure `keytool` is in PATH.
#>

Param()

function Prompt-Secret($prompt) {
    Write-Host $prompt -NoNewline
    $sec = Read-Host -AsSecureString
    return [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
}

# Paths
$projectRoot = Resolve-Path ".." -Relative | Split-Path -Parent
$keystorePath = Join-Path -Path $PSScriptRoot -ChildPath "..\android\app\keystore.jks"
$keystorePath = (Resolve-Path $keystorePath).ProviderPath
$keyPropsPath = Join-Path -Path $PSScriptRoot -ChildPath "..\key.properties"

if (-not (Get-Command keytool -ErrorAction SilentlyContinue)) {
    Write-Error "`nkeytool not found. Install JDK and ensure keytool is on PATH. Example: install OpenJDK and reopen PowerShell.`n"
    exit 1
}

Write-Host "Creating keystore at: $keystorePath"

$storePassword = Prompt-Secret "Enter keystore password: "
$keyPassword = Prompt-Secret "Enter key (alias) password (press Enter to use same as keystore): "
if ([string]::IsNullOrEmpty($keyPassword)) { $keyPassword = $storePassword }

$alias = Read-Host "Enter key alias (default: key0)"
if ([string]::IsNullOrEmpty($alias)) { $alias = 'key0' }

# Distinguished name fields
$cn = Read-Host "Your name or company (CN)"
$ou = Read-Host "Organizational unit (OU)"
$o = Read-Host "Organization (O)"
$l = Read-Host "City/Locality (L)"
$s = Read-Host "State/Province (ST)"
$c = Read-Host "Country code (C) (e.g. US)"
if ([string]::IsNullOrEmpty($cn)) { $cn = 'NEX' }
if ([string]::IsNullOrEmpty($c)) { $c = 'US' }

# Ensure directory exists
$keystoreDir = Split-Path -Path $keystorePath -Parent
if (-not (Test-Path $keystoreDir)) { New-Item -ItemType Directory -Path $keystoreDir | Out-Null }

# Build keytool command
$dname = "CN=$cn, OU=$ou, O=$o, L=$l, ST=$s, C=$c"
$keytoolArgs = "-genkeypair -v -keystore `"$keystorePath`" -alias $alias -keyalg RSA -keysize 2048 -validity 10000 -storepass $storePassword -keypass $keyPassword -dname `"$dname`""

Write-Host "Running keytool to create keystore..."
$keytoolCmd = "keytool $keytoolArgs"
Write-Host $keytoolCmd

$proc = Start-Process -FilePath keytool -ArgumentList $keytoolArgs -NoNewWindow -Wait -PassThru
if ($proc.ExitCode -ne 0) {
    Write-Error "keytool failed with exit code $($proc.ExitCode)"
    exit 1
}

# Write key.properties
$keyPropsContent = @"
storeFile=android/app/keystore.jks
storePassword=$storePassword
keyAlias=$alias
keyPassword=$keyPassword
"@
Set-Content -Path $keyPropsPath -Value $keyPropsContent -Force

Write-Host "Created keystore and key.properties successfully."
Write-Host "Keystore: $keystorePath"
Write-Host "Key properties: $keyPropsPath"
Write-Host "You can now run: flutter build apk --release"
