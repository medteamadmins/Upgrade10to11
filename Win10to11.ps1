#Requires -RunAsAdministrator

<#
.DESCRIPTION
    This script downloads the official Windows 11 Installation Assistant from Microsoft,
    performs validation checks, and launches it with appropriate parameters for automated installation.
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
        "/SkipCompatCheck"
        "/SkipEULA"
        "/QuietInstall"
        "/MinimizeToTaskBar"
        "/auto"
        "/copylogs"
        $WorkingDirectory
    )
    
    try {
        $process = Start-Process -FilePath $ExecutableFile -ArgumentList $arguments -Verb RunAs -PassThru -ErrorAction Stop
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

#Add a message box.
  # Show countdown message box for 30 minutes
    Write-LogMessage "Starting 30-minute countdown notification..." -Level "Info"
   try{ 
    try {
        # Load Windows Forms assembly for message box
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
        
        # Create a custom form for countdown
        $form = New-Object System.Windows.Forms.Form
        $form.Text = "ATTENTION - Windows 11 Upgrade in Progress"
        $form.Size = New-Object System.Drawing.Size(500, 200)
        $form.StartPosition = "CenterScreen"
        $form.FormBorderStyle = "FixedDialog"
        $form.MaximizeBox = $false
        $form.MinimizeBox = $false
        $form.TopMost = $true
        $form.BackColor = [System.Drawing.Color]::White
        
        # Create label for main message
        $label = New-Object System.Windows.Forms.Label
        $label.Location = New-Object System.Drawing.Point(20, 20)
        $label.Size = New-Object System.Drawing.Size(460, 60)
        $label.Text = "Windows 11 upgrade is currently in progress, your computer will restart once complete. To monitor the installation status and view detailed progress, please click the Windows 11 Installation Assistant mini window located in the bottom left corner of your screen."
        $label.Font = New-Object System.Drawing.Font("Arial", 10, [System.Drawing.FontStyle]::Regular)
        $label.TextAlign = "MiddleCenter"
        $form.Controls.Add($label)
        
        # Create label for countdown
        $countdownLabel = New-Object System.Windows.Forms.Label
        $countdownLabel.Location = New-Object System.Drawing.Point(20, 90)
        $countdownLabel.Size = New-Object System.Drawing.Size(460, 30)
        $countdownLabel.Font = New-Object System.Drawing.Font("Arial", 12, [System.Drawing.FontStyle]::Bold)
        $countdownLabel.ForeColor = [System.Drawing.Color]::Blue
        $countdownLabel.TextAlign = "MiddleCenter"
        $form.Controls.Add($countdownLabel)
        
        # Create close button
        $closeButton = New-Object System.Windows.Forms.Button
        $closeButton.Location = New-Object System.Drawing.Point(200, 130)
        $closeButton.Size = New-Object System.Drawing.Size(100, 30)
        $closeButton.Text = "Close"
        $closeButton.Font = New-Object System.Drawing.Font("Arial", 10)
        $closeButton.Add_Click({ $form.Close() })
        $form.Controls.Add($closeButton)
        
        # Timer for countdown (30 minutes = 1800 seconds)
        $totalSeconds = 3600
        $currentSeconds = $totalSeconds
        
        $timer = New-Object System.Windows.Forms.Timer
        $timer.Interval = 1000 # 1 second
        
        $timer.Add_Tick({
            $script:currentSeconds--
            
            if ($script:currentSeconds -le 0) {
                $timer.Stop()
                $form.Close()
                return
            }
            
            # Calculate minutes and seconds remaining
            $minutes = [math]::Floor($script:currentSeconds / 60)
            $seconds = $script:currentSeconds % 60
            
            # Update countdown display
            $countdownLabel.Text = "Time remaining: $($minutes.ToString('00')):$($seconds.ToString('00'))"
            
            # Change color as time gets low
            if ($script:currentSeconds -le 300) { # Last 5 minutes
                $countdownLabel.ForeColor = [System.Drawing.Color]::Red
            }
            elseif ($script:currentSeconds -le 600) { # Last 10 minutes
                $countdownLabel.ForeColor = [System.Drawing.Color]::Orange
            }
        })
        
        # Initialize countdown display
        $countdownLabel.Text = "Time remaining: 60:00"
        
        # Start timer and show form
        $timer.Start()
        Write-LogMessage "Countdown message box displayed for 30 minutes" -Level "Success"
        
        # Show form as dialog (blocks execution until closed)
        $form.ShowDialog() | Out-Null
        
        # Clean up
        $timer.Stop()
        $timer.Dispose()
        $form.Dispose()
        
        Write-LogMessage "Countdown notification completed or closed by user" -Level "Info"
    }
    catch {
        Write-LogMessage "Failed to display countdown message box: $_" -Level "Warning"
        
        # Fallback to simple message box
        try {
            Add-Type -AssemblyName System.Windows.Forms
            [System.Windows.Forms.MessageBox]::Show(
                "Your computer is running an upgrade, and will restart once complete. To view the progress, please click Windows 11 Assistant at bottom left corner.`n`nThis notification will remain for 30 minutes.",
                "Windows 11 Upgrade in Progress",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
               
               )
        }
 
        catch {
            Write-LogMessage "Failed to display fallback message box: $_" -Level "Warning"
        }
    }
    
    Write-LogMessage "=== Script completed successfully ===" -Level "Success"
}
catch {
    Write-LogMessage "Unexpected error occurred: $_" -Level "Error"
    Write-LogMessage "Stack trace: $($_.ScriptStackTrace)" -Level "Error"
    exit 1
}



