Add-Type -AssemblyName System.Drawing

$sourcePath = "d:\cloudmood\cloudmood_web\public\logo-cloudmood.png"
if (-not (Test-Path $sourcePath)) {
    Write-Error "Source image not found at $sourcePath"
    exit 1
}

$sourceImg = [System.Drawing.Image]::FromFile($sourcePath)

$sizes = @{
    "mipmap-mdpi" = 48
    "mipmap-hdpi" = 72
    "mipmap-xhdpi" = 96
    "mipmap-xxhdpi" = 144
    "mipmap-xxxhdpi" = 192
}

$resDir = "d:\cloudmood\cloudmood_mobile\android\app\src\main\res"

function SaveRoundedImage($srcImg, $size, $destFile) {
    $bmp = New-Object System.Drawing.Bitmap($size, $size)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    
    $g.Clear([System.Drawing.Color]::Transparent)
    
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    
    # Calculate radius (14% of the size)
    $radius = [Math]::Max(2, [int]($size * 0.14))
    $diameter = $radius * 2
    
    # Create rounded rectangle path
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $rect = New-Object System.Drawing.RectangleF(0, 0, $size, $size)
    $arcRect = New-Object System.Drawing.RectangleF(0, 0, $diameter, $diameter)
    
    # Top-Left Arc
    $path.AddArc($arcRect, 180, 90)
    
    # Top-Right Arc
    $arcRect.X = $size - $diameter
    $path.AddArc($arcRect, 270, 90)
    
    # Bottom-Right Arc
    $arcRect.Y = $size - $diameter
    $path.AddArc($arcRect, 0, 90)
    
    # Bottom-Left Arc
    $arcRect.X = 0
    $path.AddArc($arcRect, 90, 90)
    
    $path.CloseFigure()
    
    # Set clip to the rounded path
    $g.SetClip($path)
    
    # Draw image
    $g.DrawImage($srcImg, 0, 0, $size, $size)
    
    # Save image
    $bmp.Save($destFile, [System.Drawing.Imaging.ImageFormat]::Png)
    
    # Clean up
    $path.Dispose()
    $g.Dispose()
    $bmp.Dispose()
}

foreach ($key in $sizes.Keys) {
    $size = $sizes[$key]
    $destPath = Join-Path $resDir $key
    $destFileLauncher = Join-Path $destPath "ic_launcher.png"
    $destFileLaunchImg = Join-Path $destPath "launch_image.png"
    
    if (-not (Test-Path $destPath)) {
        New-Item -ItemType Directory -Force -Path $destPath | Out-Null
    }
    
    Write-Host "Generating rounded image ($size x $size, radius 14%) for $key"
    
    SaveRoundedImage $sourceImg $size $destFileLauncher
    SaveRoundedImage $sourceImg $size $destFileLaunchImg
}

$sourceImg.Dispose()
Write-Host "Launcher icons and launch images with rounded corners generated successfully!"
