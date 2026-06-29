<#
Universal Datto RMM Deployment Framework v1.0 (Starter Edition)
Author: Fardeen Salmani

Change these variables only:
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$AppName = "Foxit PDF Reader"
$InstallerName = "FoxitPDFReader_Setup.exe"
$DetectionPattern = "Foxit"
$SilentArgs = "/S /v/qn"
$TimeoutSeconds = 900

$LogDir="C:\ProgramData\DattoRMM\Logs"
New-Item -ItemType Directory -Force -Path $LogDir|Out-Null
$LogFile=Join-Path $LogDir "$($AppName -replace '[^\w]','_')_$(Get-Date -f yyyyMMdd_HHmmss).log"

function Write-Log{
param([string]$Message,[string]$Level="INFO")
$line="[{:s}][$Level] $Message" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
$line|Out-File -FilePath $LogFile -Append -Encoding utf8
Write-Output $line
}

function Get-InstalledApp{
$paths=@(
"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
"HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)
Get-ItemProperty $paths -EA SilentlyContinue|Where-Object{$_.DisplayName -match $DetectionPattern}|Select-Object -First 1
}

function Find-Installer{
$roots=@((Get-Location).Path,$PSScriptRoot,$env:TEMP,"C:\Temp")|Where-Object{$_}
foreach($r in $roots){
$p=Join-Path $r $InstallerName
if(Test-Path $p){return $p}
}
throw "Installer not found."
}

Write-Log "Starting deployment of $AppName"

$app=Get-InstalledApp
if($app){
Write-Log "$($app.DisplayName) already installed. Version $($app.DisplayVersion)"
exit 0
}

$installer=Find-Installer
Write-Log "Installer: $installer"

$sig=Get-AuthenticodeSignature $installer
Write-Log "Signature: $($sig.Status)"

$hash=(Get-FileHash $installer -Algorithm SHA256).Hash
Write-Log "SHA256: $hash"

$temp=Join-Path $env:TEMP $InstallerName
Copy-Item $installer $temp -Force

$p=Start-Process -FilePath $temp -ArgumentList $SilentArgs -PassThru

if(-not $p.WaitForExit($TimeoutSeconds*1000)){
try{$p.Kill()}catch{}
Write-Log "Installer timeout." "ERROR"
exit 1
}

Write-Log "ExitCode=$($p.ExitCode)"

if($p.ExitCode -notin @(0,3010,1641)){
Write-Log "Installation failed." "ERROR"
exit 1
}

Start-Sleep 5
$app=Get-InstalledApp
if(-not $app){
Write-Log "Validation failed." "ERROR"
exit 1
}

Remove-Item $temp -Force -EA SilentlyContinue
Write-Log "SUCCESS: $($app.DisplayName) $($app.DisplayVersion)"
exit 0
