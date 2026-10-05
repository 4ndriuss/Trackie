Add-Type -AssemblyName System.Drawing
$source = 'C:\Users\Richtjhie\.gemini\antigravity\brain\1ac28499-3276-4d33-86f3-6502f0eb0a56\.user_uploaded\media_1791103297528.jpg'
$logo = 'D:\Projects\Trackie\assets\images\logo.png'
$logoPadded = 'D:\Projects\Trackie\assets\images\logo_padded.png'

$img = [System.Drawing.Image]::FromFile($source)

# logo.png (zoomed 1.35x)
$zoom1 = 1.35
$w1 = [math]::Round($img.Width * $zoom1)
$h1 = [math]::Round($img.Height * $zoom1)
$bmp1 = New-Object System.Drawing.Bitmap($img.Width, $img.Height)
$g1 = [System.Drawing.Graphics]::FromImage($bmp1)
$g1.Clear([System.Drawing.Color]::White)
$g1.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g1.DrawImage($img, ($img.Width - $w1)/2, ($img.Height - $h1)/2, $w1, $h1)
$g1.Dispose()
$bmp1.Save($logo, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp1.Dispose()

# logo_padded.png (zoomed 1.05x)
$zoom2 = 1.05
$w2 = [math]::Round($img.Width * $zoom2)
$h2 = [math]::Round($img.Height * $zoom2)
$bmp2 = New-Object System.Drawing.Bitmap($img.Width, $img.Height)
$g2 = [System.Drawing.Graphics]::FromImage($bmp2)
$g2.Clear([System.Drawing.Color]::White)
$g2.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g2.DrawImage($img, ($img.Width - $w2)/2, ($img.Height - $h2)/2, $w2, $h2)
$g2.Dispose()
$bmp2.Save($logoPadded, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp2.Dispose()

$img.Dispose()
Write-Host 'Images saved'
