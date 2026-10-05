Add-Type -AssemblyName System.Drawing
$logo = 'D:\Projects\Trackie\assets\images\logo.png'
$logoPadded = 'D:\Projects\Trackie\assets\images\logo_padded.png'

function Make-Transparent($path) {
    $img = [System.Drawing.Image]::FromFile($path)
    $bmp = New-Object System.Drawing.Bitmap($img)
    $img.Dispose()
    
    # Loop through all pixels
    for ($x = 0; $x -lt $bmp.Width; $x++) {
        for ($y = 0; $y -lt $bmp.Height; $y++) {
            $pixel = $bmp.GetPixel($x, $y)
            if ($pixel.R -ge 230 -and $pixel.G -ge 230 -and $pixel.B -ge 230) {
                $bmp.SetPixel($x, $y, [System.Drawing.Color]::Transparent)
            }
        }
    }
    
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
}

Make-Transparent $logo
Make-Transparent $logoPadded

Write-Host 'Images processed'
