# Variables
$siteName = "bdo.ph.com"
$hostnames = @("www.bdo.ph.com","bdo.ph.com")

# -----------------------------
# 1. REMOVE EXISTING IIS HTTPS BINDINGS
# -----------------------------
foreach ($h in $hostnames) {
    Get-WebBinding -Name $siteName -Protocol https -ErrorAction SilentlyContinue |
    Where-Object { $_.bindingInformation -eq "*:443:$h" } |
    ForEach-Object {
        Remove-WebBinding -Name $siteName -Protocol https -Port 443 -HostHeader $h
    }
}

# -----------------------------
# 2. REMOVE EXISTING SSL BINDINGS
# -----------------------------
Get-ChildItem IIS:\SslBindings |
Where-Object { $hostnames -contains $_.Host } |
Remove-Item -Force -ErrorAction SilentlyContinue

# -----------------------------
# 3. REMOVE OLD CERTIFICATES
# -----------------------------
Get-ChildItem Cert:\LocalMachine\My |
Where-Object { $_.Subject -like "*bdo.ph.com*" } |
Remove-Item -Force -ErrorAction SilentlyContinue

# -----------------------------
# 4. CREATE NEW CERTIFICATE
# -----------------------------
$cert = New-SelfSignedCertificate `
-DnsName $hostnames `
-CertStoreLocation "Cert:\LocalMachine\My"

$certThumbprint = $cert.Thumbprint

# -----------------------------
# 5. CREATE IIS HTTPS BINDINGS
# -----------------------------
foreach ($h in $hostnames) {
    New-WebBinding -Name $siteName -Protocol https -Port 443 -HostHeader $h
}

# -----------------------------
# 6. ASSIGN CERTIFICATE
# -----------------------------
Push-Location IIS:\SslBindings

foreach ($h in $hostnames) {
    $bindingPath = "0.0.0.0!443!$h"

    if (-not (Test-Path $bindingPath)) {
        New-Item $bindingPath -Thumbprint $certThumbprint -SSLFlags 1
    }
}

Pop-Location

# -----------------------------
# 7. TRUST CERT (OPTIONAL)
# -----------------------------
$certPath = "Cert:\LocalMachine\My\$certThumbprint"
$rootStore = New-Object System.Security.Cryptography.X509Certificates.X509Store("Root","LocalMachine")
$rootStore.Open("ReadWrite")
$rootStore.Add((Get-Item $certPath))
$rootStore.Close()

# -----------------------------
# 8. RESTART IIS
# -----------------------------
iisreset
