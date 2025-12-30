#!/bin/bash
################################################################################
# Video Sync Script for Linux
# Purpose: Continuously sync .ts video files to S3 bucket
# Author: Senior AWS Solutions Architect
################################################################################

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================
LOCAL_FOLDER="${LOCAL_VIDEO_FOLDER:-/path/to/your/videos}"
S3_BUCKET="${S3_BUCKET_NAME:-04-california}"
S3_PREFIX="04-california/amazon_transcribe/ine/raw/"
AWS_PROFILE="${AWS_PROFILE:-default}"
AWS_REGION="${AWS_REGION:-us-east-1}"

# Sync interval in seconds (default: 60 seconds)
SYNC_INTERVAL="${SYNC_INTERVAL:-60}"

# ============================================================================
# COLORS FOR OUTPUT
# ============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# FUNCTIONS
# ============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed. Install it from: https://aws.amazon.com/cli/"
        exit 1
    fi

    log_success "AWS CLI found: $(aws --version)"

    # Check if local folder exists
    if [ ! -d "$LOCAL_FOLDER" ]; then
        log_error "Local folder does not exist: $LOCAL_FOLDER"
        log_info "Set LOCAL_VIDEO_FOLDER environment variable or update this script"
        exit 1
    fi

    log_success "Local folder exists: $LOCAL_FOLDER"

    # Test AWS credentials
    if ! aws sts get-caller-identity --profile "$AWS_PROFILE" --region "$AWS_REGION" &> /dev/null; then
        log_error "AWS credentials are not configured properly"
        log_info "Run: aws configure --profile $AWS_PROFILE"
        exit 1
    fi

    log_success "AWS credentials valid"

    # Test S3 bucket access
    if ! aws s3 ls "s3://$S3_BUCKET" --profile "$AWS_PROFILE" --region "$AWS_REGION" &> /dev/null; then
        log_error "Cannot access S3 bucket: s3://$S3_BUCKET"
        log_info "Check bucket name and permissions"
        exit 1
    fi

    log_success "S3 bucket accessible: s3://$S3_BUCKET"
}

sync_files() {
    log_info "Starting sync: $LOCAL_FOLDER -> s3://$S3_BUCKET/$S3_PREFIX"

    # Count .ts files in local folder
    local file_count=$(find "$LOCAL_FOLDER" -type f -name "*.ts" | wc -l)
    log_info "Found $file_count .ts file(s) in local folder"

    if [ "$file_count" -eq 0 ]; then
        log_warning "No .ts files found to sync"
        return
    fi

    # Perform sync with retry logic
    local max_retries=4
    local retry_count=0
    local retry_delay=2

    while [ $retry_count -lt $max_retries ]; do
        if aws s3 sync "$LOCAL_FOLDER" "s3://$S3_BUCKET/$S3_PREFIX" \
            --profile "$AWS_PROFILE" \
            --region "$AWS_REGION" \
            --exclude "*" \
            --include "*.ts" \
            --storage-class STANDARD \
            --no-progress \
            2>&1 | tee /tmp/aws-sync.log; then

            # Parse output to show uploaded files
            local uploaded=$(grep -c "upload:" /tmp/aws-sync.log || true)

            if [ "$uploaded" -gt 0 ]; then
                log_success "Uploaded $uploaded file(s) to S3"
                grep "upload:" /tmp/aws-sync.log | while read -r line; do
                    log_info "  $line"
                done
            else
                log_info "All files already synced (no changes)"
            fi

            return 0
        else
            retry_count=$((retry_count + 1))
            if [ $retry_count -lt $max_retries ]; then
                log_warning "Sync failed, retrying in ${retry_delay}s (attempt $retry_count/$max_retries)"
                sleep $retry_delay
                retry_delay=$((retry_delay * 2))  # Exponential backoff
            else
                log_error "Sync failed after $max_retries attempts"
                return 1
            fi
        fi
    done
}

continuous_sync() {
    log_info "Starting continuous sync mode (interval: ${SYNC_INTERVAL}s)"
    log_info "Press Ctrl+C to stop"

    while true; do
        sync_files
        log_info "Waiting ${SYNC_INTERVAL} seconds until next sync..."
        sleep "$SYNC_INTERVAL"
    done
}

show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
    --once              Run sync once and exit (default: continuous)
    --interval SECONDS  Set sync interval in seconds (default: 60)
    --help              Show this help message

Environment Variables:
    LOCAL_VIDEO_FOLDER  Path to local folder with .ts files
    S3_BUCKET_NAME      S3 bucket name
    AWS_PROFILE         AWS CLI profile (default: default)
    AWS_REGION          AWS region (default: us-east-1)
    SYNC_INTERVAL       Sync interval in seconds (default: 60)

Example:
    # One-time sync
    LOCAL_VIDEO_FOLDER=/videos S3_BUCKET_NAME=my-bucket $0 --once

    # Continuous sync every 120 seconds
    LOCAL_VIDEO_FOLDER=/videos S3_BUCKET_NAME=my-bucket $0 --interval 120

EOF
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    local run_once=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --once)
                run_once=true
                shift
                ;;
            --interval)
                SYNC_INTERVAL="$2"
                shift 2
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    # Print configuration
    echo ""
    log_info "=========================================="
    log_info "Video Sync Script"
    log_info "=========================================="
    log_info "Local Folder: $LOCAL_FOLDER"
    log_info "S3 Destination: s3://$S3_BUCKET/$S3_PREFIX"
    log_info "AWS Profile: $AWS_PROFILE"
    log_info "AWS Region: $AWS_REGION"
    log_info "=========================================="
    echo ""

    # Check prerequisites
    check_prerequisites

    # Run sync
    if [ "$run_once" = true ]; then
        log_info "Running one-time sync"
        sync_files
        log_success "Sync completed"
    else
        continuous_sync
    fi
}

# Trap Ctrl+C and cleanup
trap 'log_info "Sync stopped by user"; exit 0' INT TERM

main "$@"
