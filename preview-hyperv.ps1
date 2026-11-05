[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$IsoPath,

    [string]$VMName = "XfceFirefoxKiosk",

    [string]$SwitchName = "Default Switch"
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command Get-VM -ErrorAction SilentlyContinue)) {
    throw "Hyper-V PowerShell tools are unavailable. Enable Hyper-V and run this in an elevated PowerShell session."
}

if (-not (Test-Path -LiteralPath $IsoPath -PathType Leaf)) {
    throw "ISO file not found: $IsoPath"
}

$resolvedIso = (Resolve-Path -LiteralPath $IsoPath).Path
if (Get-VM -Name $VMName -ErrorAction SilentlyContinue) {
    throw "A VM named '$VMName' already exists. Choose another -VMName or manage the existing VM in Hyper-V Manager."
}

if ([string]::IsNullOrWhiteSpace($SwitchName)) {
    $vm = New-VM -Name $VMName -Generation 2 -MemoryStartupBytes 4GB -NoVHD
} else {
    $null = Get-VMSwitch -Name $SwitchName -ErrorAction Stop
    $vm = New-VM -Name $VMName -Generation 2 -MemoryStartupBytes 4GB -NoVHD -SwitchName $SwitchName
}

Set-VMProcessor -VMName $VMName -Count 2
Set-VMMemory -VMName $VMName -DynamicMemoryEnabled $false
Add-VMDvdDrive -VMName $VMName -Path $resolvedIso

$dvd = Get-VMDvdDrive -VMName $VMName
Set-VMFirmware -VMName $VMName -EnableSecureBoot Off -FirstBootDevice $dvd

Start-VM -Name $VMName | Out-Null
Start-Process -FilePath "$env:WINDIR\System32\vmconnect.exe" -ArgumentList @("localhost", $VMName)

Write-Host "Started '$VMName' from $resolvedIso"
Write-Host "To stop it later: Stop-VM -Name '$VMName'"
