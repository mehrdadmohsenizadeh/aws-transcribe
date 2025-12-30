################################################################################
# Video Sync Script for Windows (PowerShell)
# Purpose: Continuously sync .ts video files to S3 bucket
# Author: Senior AWS Solutions Architect
################################################################################

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [switch]$Once,

    [Parameter(Mandatory=$false)]
    [int]$Interval = 60,

    [Parameter(Mandatory=$false)]
    [switch]$Help
)

# ============================================================================
# CONFIGURATION
# ============================================================================

$Script:Config = @{
    LocalFolder = $env:LOCAL_VIDEO_FOLDER ?? "C:\Videos"
    S3Bucket = $env:S3_BUCKET_NAME ?? "04-california"
    S3Prefix = "04-california/amazon_transcribe/ine/raw/"
    AWSProfile = $env:AWS_PROFILE ?? "default"
    AWSRegion = $env:AWS_REGION ?? "us-east-1"
    SyncInterval = $Interval
}

# ============================================================================
# LOGGING FUNCTIONS
# ============================================================================

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Type = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Type) {
        "INFO"    { "Cyan" }
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR"   { "Red" }
        default   { "White" }
    }

    Write-Host "[$Type] $timestamp - $Message" -ForegroundColor $color
}

function Log-Info    { param([string]$msg) Write-ColorOutput -Message $msg -Type "INFO" }
function Log-Success { param([string]$msg) Write-ColorOutput -Message $msg -Type "SUCCESS" }
function Log-Warning { param([string]$msg) Write-ColorOutput -Message $msg -Type "WARNING" }
function Log-Error   { param([string]$msg) Write-ColorOutput -Message $msg -Type "ERROR" }

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

function Show-Usage {
    @"
Video Sync Script for Windows

Usage: .\sync-videos.ps1 [OPTIONS]

Options:
    -Once              Run sync once and exit (default: continuous)
    -Interval <INT>    Set sync interval in seconds (default: 60)
    -Help              Show this help message

Environment Variables:
    LOCAL_VIDEO_FOLDER  Path to local folder with .ts files
    S3_BUCKET_NAME      S3 bucket name
    AWS_PROFILE         AWS CLI profile (default: default)
    AWS_REGION          AWS region (default: us-east-1)

Examples:
    # One-time sync
    `$env:LOCAL_VIDEO_FOLDER="C:\Videos"; `$env:S3_BUCKET_NAME="my-bucket"; .\sync-videos.ps1 -Once

    # Continuous sync every 120 seconds
    `$env:LOCAL_VIDEO_FOLDER="C:\Videos"; `$env:S3_BUCKET_NAME="my-bucket"; .\sync-videos.ps1 -Interval 120

    # Run as scheduled task (Windows Task Scheduler)
    schtasks /create /tn "VideoSync" /tr "powershell.exe -File C:\scripts\sync-videos.ps1" /sc hourly

"@
}

function Test-Prerequisites {
    Log-Info "Checking prerequisites..."

    # Check AWS CLI
    try {
        $awsVersion = aws --version 2>&1
        Log-Success "AWS CLI found: $awsVersion"
    } catch {
        Log-Error "AWS CLI is not installed or not in PATH"
        Log-Info "Download from: https://aws.amazon.com/cli/"
        exit 1
    }

    # Check local folder
    if (-not (Test-Path $Script:Config.LocalFolder)) {
        Log-Error "Local folder does not exist: $($Script:Config.LocalFolder)"
        Log-Info "Set LOCAL_VIDEO_FOLDER environment variable or update this script"
        exit 1
    }
    Log-Success "Local folder exists: $($Script:Config.LocalFolder)"

    # Test AWS credentials
    try {
        $null = aws sts get-caller-identity `
            --profile $Script:Config.AWSProfile `
            --region $Script:Config.AWSRegion `
            2>&1

        if ($LASTEXITCODE -ne 0) { throw "AWS credentials failed" }
        Log-Success "AWS credentials valid"
    } catch {
        Log-Error "AWS credentials are not configured properly"
        Log-Info "Run: aws configure --profile $($Script:Config.AWSProfile)"
        exit 1
    }

    # Test S3 bucket access
    try {
        $null = aws s3 ls "s3://$($Script:Config.S3Bucket)" `
            --profile $Script:Config.AWSProfile `
            --region $Script:Config.AWSRegion `
            2>&1

        if ($LASTEXITCODE -ne 0) { throw "S3 bucket not accessible" }
        Log-Success "S3 bucket accessible: s3://$($Script:Config.S3Bucket)"
    } catch {
        Log-Error "Cannot access S3 bucket: s3://$($Script:Config.S3Bucket)"
        Log-Info "Check bucket name and permissions"
        exit 1
    }
}

function Invoke-SyncWithRetry {
    $maxRetries = 4
    $retryDelay = 2

    for ($attempt = 1; $attempt -le $maxRetries; $attempt++) {
        try {
            # Execute AWS S3 sync
            $output = aws s3 sync $Script:Config.LocalFolder "s3://$($Script:Config.S3Bucket)/$($Script:Config.S3Prefix)" `
                --profile $Script:Config.AWSProfile `
                --region $Script:Config.AWSRegion `
                --exclude "*" `
                --include "*.ts" `
                --storage-class STANDARD `
                --no-progress `
                2>&1

            if ($LASTEXITCODE -eq 0) {
                # Parse output
                $uploadLines = $output | Select-String -Pattern "upload:"
                if ($uploadLines) {
                    Log-Success "Uploaded $($uploadLines.Count) file(s) to S3"
                    foreach ($line in $uploadLines) {
                        Log-Info "  $line"
                    }
                } else {
                    Log-Info "All files already synced (no changes)"
                }
                return $true
            } else {
                throw "AWS CLI returned exit code: $LASTEXITCODE"
            }

        } catch {
            if ($attempt -lt $maxRetries) {
                Log-Warning "Sync failed, retrying in ${retryDelay}s (attempt $attempt/$maxRetries)"
                Start-Sleep -Seconds $retryDelay
                $retryDelay *= 2  # Exponential backoff
            } else {
                Log-Error "Sync failed after $maxRetries attempts: $_"
                return $false
            }
        }
    }
}

function Sync-Files {
    $s3Destination = "s3://$($Script:Config.S3Bucket)/$($Script:Config.S3Prefix)"
    Log-Info "Starting sync: $($Script:Config.LocalFolder) -> $s3Destination"

    # Count .ts files
    $tsFiles = Get-ChildItem -Path $Script:Config.LocalFolder -Filter "*.ts" -File -Recurse
    $fileCount = ($tsFiles | Measure-Object).Count
    Log-Info "Found $fileCount .ts file(s) in local folder"

    if ($fileCount -eq 0) {
        Log-Warning "No .ts files found to sync"
        return
    }

    # Perform sync
    Invoke-SyncWithRetry
}

function Start-ContinuousSync {
    Log-Info "Starting continuous sync mode (interval: $($Script:Config.SyncInterval)s)"
    Log-Info "Press Ctrl+C to stop"

    while ($true) {
        Sync-Files
        Log-Info "Waiting $($Script:Config.SyncInterval) seconds until next sync..."
        Start-Sleep -Seconds $Script:Config.SyncInterval
    }
}

# ============================================================================
# MAIN
# ============================================================================

function Main {
    if ($Help) {
        Show-Usage
        exit 0
    }

    # Print configuration
    Write-Host ""
    Log-Info "=========================================="
    Log-Info "Video Sync Script (Windows)"
    Log-Info "=========================================="
    Log-Info "Local Folder: $($Script:Config.LocalFolder)"
    Log-Info "S3 Destination: s3://$($Script:Config.S3Bucket)/$($Script:Config.S3Prefix)"
    Log-Info "AWS Profile: $($Script:Config.AWSProfile)"
    Log-Info "AWS Region: $($Script:Config.AWSRegion)"
    Log-Info "=========================================="
    Write-Host ""

    # Check prerequisites
    Test-Prerequisites

    # Run sync
    if ($Once) {
        Log-Info "Running one-time sync"
        Sync-Files
        Log-Success "Sync completed"
    } else {
        Start-ContinuousSync
    }
}

# Trap Ctrl+C
trap {
    Log-Info "Sync stopped by user"
    exit 0
}

# Execute
Main
