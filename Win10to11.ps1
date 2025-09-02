#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Downloads and launches the Windows 11 Installation Assistant with enhanced error handling and logging.

.DESCRIPTION
    This script downloads the official Windows 11 Installation Assistant from Microsoft,
    performs validation checks, and launches it with appropriate parameters for automated installation.

.NOTES
    Author: Enhanced PowerShell Script
    Version: 2.0
    Requires: PowerShell 5.1+ and Administrator privileges
#>

[CmdletBinding()]
param(
    [string]$WorkingDirectory = "C:\temp",
    [string]$LogFile = "C:\temp\Win11Upgrade.log",
    [switch]$Quiet = $false
)

# Configuration
$DownloadUrl = "https://go.microsoft.com/fwlink/?linkid=2171764"
$ExecutableFile = Join-Path $WorkingDirectory "Win11Upgrade.exe"
$MaxRetries = 3
$TimeoutSeconds = 300

# Function to write log messages
function Write-LogMessage {
    param(
        [string]$Message,
        [ValidateSet("Info", "Warning", "Error", "Success")]
        [string]$Level = "Info"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Write to console with color coding
    if (-not $Quiet) {
        switch ($Level) {
            "Error" { Write-Host $logEntry -ForegroundColor Red }
            "Warning" { Write-Host $logEntry -ForegroundColor Yellow }
            "Success" { Write-Host $logEntry -ForegroundColor Green }
            default { Write-Host $logEntry -ForegroundColor White }
        }
    }
    
    # Write to log file
    try {
        Add-Content -Path $LogFile -Value $logEntry -ErrorAction Stop
    }
    catch {
        Write-Warning "Failed to write to log file: $_"
    }
}

# Function to test internet connectivity
function Test-InternetConnection {
    try {
        $null = Invoke-WebRequest -Uri "https://www.microsoft.com" -Method Head -TimeoutSec 10 -UseBasicParsing
        return $true
    }
    catch {
        return $false
    }
}

# Function to validate downloaded file
function Test-DownloadedFile {
    param([string]$FilePath)
    
    if (-not (Test-Path $FilePath)) {
        return $false
    }
    
    $fileInfo = Get-Item $FilePath
    # Check if file size is reasonable (should be several MB)
    if ($fileInfo.Length -lt 1MB) {
        Write-LogMessage "Downloaded file appears to be too small ($($fileInfo.Length) bytes)" -Level "Warning"
        return $false
    }
    
    return $true
}

# Main execution
try {
    Write-LogMessage "=== Windows 11 Upgrade Assistant Download Script Started ===" -Level "Info"
    Write-LogMessage "Working Directory: $WorkingDirectory" -Level "Info"
    Write-LogMessage "Log File: $LogFile" -Level "Info"
    
    # Check if running as administrator
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-LogMessage "This script requires administrator privileges. Please run as Administrator." -Level "Error"
        exit 1
    }
    
    # Test internet connectivity
    Write-LogMessage "Testing internet connectivity..." -Level "Info"
    if (-not (Test-InternetConnection)) {
        Write-LogMessage "No internet connection available. Cannot proceed with download." -Level "Error"
        exit 1
    }
    Write-LogMessage "Internet connectivity confirmed" -Level "Success"
    
    # Create working directory if it doesn't exist
    Write-LogMessage "Creating working directory: $WorkingDirectory" -Level "Info"
    if (-not (Test-Path $WorkingDirectory)) {
        try {
            New-Item -ItemType Directory -Force -Path $WorkingDirectory -ErrorAction Stop
            Write-LogMessage "Working directory created successfully" -Level "Success"
        }
        catch {
            Write-LogMessage "Failed to create working directory: $_" -Level "Error"
            exit 1
        }
    }
    else {
        Write-LogMessage "Working directory already exists" -Level "Info"
    }
    
    # Remove existing file if present
    if (Test-Path $ExecutableFile) {
        Write-LogMessage "Removing existing file: $ExecutableFile" -Level "Info"
        try {
            Remove-Item $ExecutableFile -Force -ErrorAction Stop
        }
        catch {
            Write-LogMessage "Failed to remove existing file: $_" -Level "Warning"
        }
    }
    
    # Download with retry logic
    $downloadSuccess = $false
    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        Write-LogMessage "Download attempt $attempt of $MaxRetries..." -Level "Info"
        
        try {
            # Use progress preference to show download progress
            $originalProgressPreference = $ProgressPreference
            if (-not $Quiet) { $ProgressPreference = 'Continue' }
            
            Invoke-WebRequest -Uri $DownloadUrl -OutFile $ExecutableFile -TimeoutSec $TimeoutSeconds -ErrorAction Stop
            
            $ProgressPreference = $originalProgressPreference
            
            # Validate downloaded file
            if (Test-DownloadedFile -FilePath $ExecutableFile) {
                $fileSize = (Get-Item $ExecutableFile).Length
                Write-LogMessage "Download completed successfully. File size: $([math]::Round($fileSize / 1MB, 2)) MB" -Level "Success"
                $downloadSuccess = $true
                break
            }
            else {
                Write-LogMessage "Downloaded file validation failed" -Level "Warning"
            }
        }
        catch {
            Write-LogMessage "Download attempt $attempt failed: $_" -Level "Warning"
            Start-Sleep -Seconds 5
        }
    }
    
    if (-not $downloadSuccess) {
        Write-LogMessage "Failed to download Windows 11 Installation Assistant after $MaxRetries attempts" -Level "Error"
        exit 1
    }
    
    # Launch the installation assistant
    Write-LogMessage "Launching Windows 11 Installation Assistant..." -Level "Info"
    $arguments = @(
        "/Install"
        "/QuietInstall"
        "/SkipEULA"
        "/copylogs"
        $WorkingDirectory
    )
    
    try {
        $process = Start-Process -FilePath $ExecutableFile -ArgumentList $arguments -PassThru -ErrorAction Stop
        Write-LogMessage "Windows 11 Installation Assistant launched successfully (Process ID: $($process.Id))" -Level "Success"
        Write-LogMessage "Installation logs will be copied to: $WorkingDirectory" -Level "Info"
    }
    catch {
        Write-LogMessage "Failed to launch Windows 11 Installation Assistant: $_" -Level "Error"
        exit 1
    }
    
    Write-LogMessage "=== Script completed successfully ===" -Level "Success"
}
catch {
    Write-LogMessage "Unexpected error occurred: $_" -Level "Error"
    Write-LogMessage "Stack trace: $($_.ScriptStackTrace)" -Level "Error"
    exit 1
}
finally {
    Write-LogMessage "=== Windows 11 Upgrade Assistant Download Script Ended ===" -Level "Info"
}