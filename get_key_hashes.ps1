# get_key_hashes.ps1
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "   Cloudmood Social Login Hash Helper     " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

$keystorePath = Join-Path $env:USERPROFILE ".android\debug.keystore"
if (-not (Test-Path $keystorePath)) {
    Write-Host "Keystore debug.keystore khong tim thay tai: $keystorePath" -ForegroundColor Red
    Write-Host "Vui long build du an Android it nhat mot lan de tu dong tao keystore debug." -ForegroundColor Yellow
    Exit
}

Write-Host "Dang tim kiem keytool..." -ForegroundColor Gray
$keytool = "keytool"
$keytoolExists = Get-Command $keytool -ErrorAction SilentlyContinue

if (-not $keytoolExists) {
    # Check common JDK/Java installation paths
    $javaPaths = @(
        "C:\Program Files\Java\*\bin\keytool.exe",
        "C:\Program Files (x86)\Java\*\bin\keytool.exe",
        "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe",
        "C:\Program Files\Android\Android Studio\jre\bin\keytool.exe",
        "C:\Program Files\Android\Android Studio\jdk\bin\keytool.exe"
    )
    foreach ($pathPattern in $javaPaths) {
        $resolved = Resolve-Path $pathPattern -ErrorAction SilentlyContinue
        if ($resolved) {
            $keytool = $resolved[0].Path
            break
        }
    }
}

$keytoolResolved = Get-Command $keytool -ErrorAction SilentlyContinue

if (-not $keytoolResolved) {
    Write-Host "Khong tim thay lenh 'keytool' trong he thong." -ForegroundColor Red
    Write-Host "Hay cai dat JDK/Android Studio hoac them thu muc bin cua JDK vao bien moi truong PATH." -ForegroundColor Yellow
    Exit
}

Write-Host "Dang doc thong tin tu Keystore: $keystorePath" -ForegroundColor Gray
$output = & $keytool -list -v -alias androiddebugkey -keystore $keystorePath -storepass android 2>&1

$sha1Line = $output | Out-String | Select-String -Pattern "SHA1:\s+([0-9A-Fa-f:]+)"
if ($sha1Line) {
    $sha1 = $sha1Line.Matches[0].Groups[1].Value
    Write-Host "`n[1] MA SHA-1 (Dung cho Google/Firebase):" -ForegroundColor Green
    Write-Host $sha1 -ForegroundColor White
    
    # Convert SHA-1 hex to Base64 Key Hash for Facebook
    $hexString = $sha1.Replace(":", "")
    $bytes = New-Object Byte[] ($hexString.Length / 2)
    for ($i = 0; $i -lt $hexString.Length; $i += 2) {
        $bytes[$i / 2] = [Convert]::ToByte($hexString.Substring($i, 2), 16)
    }
    $facebookKeyHash = [Convert]::ToBase64String($bytes)
    
    Write-Host "`n[2] MA KEY HASH (Dung cho Facebook Developers):" -ForegroundColor Green
    Write-Host $facebookKeyHash -ForegroundColor White
    Write-Host "`n==========================================" -ForegroundColor Cyan
    Write-Host "Hay copy va dan cac ma tren vao trang cau hinh tuong ung." -ForegroundColor Yellow
} else {
    Write-Host "Khong the trich xuat ma SHA1 tu output cua keytool." -ForegroundColor Red
    Write-Host "Chi tiet loi:" -ForegroundColor Yellow
    Write-Output $output
}
