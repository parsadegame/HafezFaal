$ErrorActionPreference = "Stop"

$Root     = "C:\Users\parsa\.opencode\bin\HafezFaalOffline"
$tplPath  = Join-Path $Root "templates\hafez-faal.template.html"
$jsonPath = Join-Path $Root "data\faals.json"
$outPath  = Join-Path $Root "app\src\main\assets\hafez-faal.html"

$utf8 = New-Object System.Text.UTF8Encoding($false)
$tpl  = [System.IO.File]::ReadAllText($tplPath, [System.Text.Encoding]::UTF8)
$json = [System.IO.File]::ReadAllText($jsonPath, [System.Text.Encoding]::UTF8)

# Escape characters that could break an inline <script> block or JS string literal.
$json = $json.Replace('<', '\u003c')
$json = $json.Replace([string][char]0x2028, '\u2028')
$json = $json.Replace([string][char]0x2029, '\u2029')

if ($tpl.IndexOf('/*POEMS*/[]') -lt 0) { throw "POEMS placeholder not found in template" }

$out = $tpl.Replace('/*POEMS*/[]', $json)
[System.IO.File]::WriteAllText($outPath, $out, $utf8)

$count = ([regex]::Matches($json, '"interpretation"')).Count
Write-Host "Embedded $count poems into hafez-faal.html ($([math]::Round((Get-Item $outPath).Length/1KB,1)) KB)"
