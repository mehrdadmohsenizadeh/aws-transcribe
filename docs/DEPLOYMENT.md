# Deployment Guide - AWS Video Transcription Pipeline

## Prerequisites

### Required Tools
- **AWS CLI** (v2.x or higher): [Installation Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- **AWS Account** with appropriate permissions
- **Git** (for cloning this repository)

### Required Permissions
Your AWS IAM user/role needs these permissions:
- CloudFormation: Full access (for stack deployment)
- S3: Full access (bucket creation)
- Lambda: Full access
- Step Functions: Full access
- IAM: Create/manage roles and policies
- MediaConvert: Full access
- Transcribe: Full access
- EventBridge: Full access
- SNS: Full access
- CloudWatch: Full access

**Recommendation**: Use `AdministratorAccess` for initial deployment, then restrict post-deployment.

---

## Deployment Steps

### Step 1: Configure AWS Credentials

```bash
# Configure AWS CLI
aws configure

# Provide:
# - AWS Access Key ID
# - AWS Secret Access Key
# - Default region (e.g., us-east-1)
# - Default output format (json)

# Verify configuration
aws sts get-caller-identity
```

Expected output:
```json
{
    "UserId": "AIDAXXXXXXXXXXXXXXXXX",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/your-username"
}
```

### Step 2: Choose a Globally Unique S3 Bucket Name

S3 bucket names must be globally unique. Choose a name like:
- `video-transcription-yourcompany-12345`
- `ine-ccna-videos-yourname`
- `transcribe-pipeline-prod-xyz`

**Rules**:
- 3-63 characters
- Lowercase letters, numbers, hyphens only
- Must start and end with letter or number

```bash
export S3_BUCKET_NAME="video-transcription-yourcompany-12345"
export NOTIFICATION_EMAIL="your-email@example.com"
```

### Step 3: Deploy CloudFormation Stack

```bash
# Navigate to repository
cd aws-transcribe

# Deploy the stack
aws cloudformation create-stack \
  --stack-name video-transcription-pipeline \
  --template-body file://cloudformation/transcription-pipeline.yaml \
  --parameters \
    ParameterKey=S3BucketName,ParameterValue=$S3_BUCKET_NAME \
    ParameterKey=NotificationEmail,ParameterValue=$NOTIFICATION_EMAIL \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1

# Monitor deployment (takes ~3-5 minutes)
aws cloudformation wait stack-create-complete \
  --stack-name video-transcription-pipeline \
  --region us-east-1

# Check status
aws cloudformation describe-stacks \
  --stack-name video-transcription-pipeline \
  --region us-east-1 \
  --query 'Stacks[0].StackStatus'
```

**Expected Output**: `"CREATE_COMPLETE"`

If deployment fails:
```bash
# Get error details
aws cloudformation describe-stack-events \
  --stack-name video-transcription-pipeline \
  --region us-east-1 \
  --max-items 10
```

### Step 4: Confirm SNS Email Subscription

1. Check your email inbox for a message from AWS SNS
2. Subject: "AWS Notification - Subscription Confirmation"
3. Click the **"Confirm subscription"** link
4. You'll see: "Subscription confirmed!"

### Step 5: Deploy Lambda Function Code

The CloudFormation template creates the Lambda function with placeholder code. Now deploy the actual code:

```bash
# Package Lambda function
cd lambda/text-processor
zip -r function.zip lambda_function.py

# Deploy to Lambda
aws lambda update-function-code \
  --function-name video-transcription-text-processor \
  --zip-file fileb://function.zip \
  --region us-east-1

# Verify deployment
aws lambda get-function \
  --function-name video-transcription-text-processor \
  --region us-east-1 \
  --query 'Configuration.[FunctionName,Runtime,LastModified,State]'
```

**Expected Output**:
```json
[
    "video-transcription-text-processor",
    "python3.11",
    "2025-12-30T12:34:56.000+0000",
    "Active"
]
```

### Step 6: Verify Infrastructure

```bash
# Get stack outputs
aws cloudformation describe-stacks \
  --stack-name video-transcription-pipeline \
  --region us-east-1 \
  --query 'Stacks[0].Outputs'
```

You should see:
- ✅ S3 Bucket Name
- ✅ Step Functions ARN
- ✅ Lambda Function ARN
- ✅ AWS Console links

### Step 7: Test with a Sample Video

**Option A: Upload via AWS CLI**
```bash
# Download a sample .ts video (or use your own)
# Upload to S3
aws s3 cp test-video.ts \
  s3://$S3_BUCKET_NAME/04-california/amazon_transcribe/ine/raw/test-video.ts \
  --region us-east-1

# Verify upload
aws s3 ls s3://$S3_BUCKET_NAME/04-california/amazon_transcribe/ine/raw/
```

**Option B: Upload via AWS Console**
1. Go to S3 Console: https://s3.console.aws.amazon.com
2. Click your bucket name
3. Navigate to `04-california/amazon_transcribe/ine/raw/`
4. Click **Upload** → Add `.ts` file → Upload

### Step 8: Monitor Workflow Execution

**Via AWS Console (Recommended for first test):**

1. Go to Step Functions Console: https://console.aws.amazon.com/states
2. Click `video-transcription-workflow`
3. You should see a new execution starting within 1-2 minutes
4. Click the execution to see visual progress

**Via AWS CLI:**
```bash
# Get latest execution
aws stepfunctions list-executions \
  --state-machine-arn $(aws cloudformation describe-stacks \
    --stack-name video-transcription-pipeline \
    --query 'Stacks[0].Outputs[?OutputKey==`StateMachineArn`].OutputValue' \
    --output text) \
  --max-results 1 \
  --region us-east-1

# Monitor specific execution
aws stepfunctions describe-execution \
  --execution-arn <EXECUTION_ARN> \
  --region us-east-1
```

**Execution Timeline** (for a 10-minute video):
- **0-1 min**: MediaConvert job starts
- **1-5 min**: Transcoding .ts → .mp4
- **5-6 min**: Transcribe job starts
- **6-16 min**: Transcription in progress
- **16 min**: Lambda processes SRT → TXT
- **Total**: ~16-20 minutes

### Step 9: Verify Output Files

```bash
# Check all output files
aws s3 ls s3://$S3_BUCKET_NAME/04-california/amazon_transcribe/ine/ --recursive

# Expected structure:
# raw/test-video.ts           (original)
# transcoded/test-video.mp4   (video)
# transcripts/test-video.srt  (subtitle)
# transcripts/test-video.vtt  (web subtitle)
# text/test-video.txt         (clean text)

# Download the final text file
aws s3 cp s3://$S3_BUCKET_NAME/04-california/amazon_transcribe/ine/text/test-video.txt .

# View content
cat test-video.txt
```

---

## Production Configuration

### Step 10: Set Up Continuous Local Sync

**For Linux/Mac:**
```bash
# Set environment variables
export LOCAL_VIDEO_FOLDER="/path/to/your/videos"
export S3_BUCKET_NAME="04-california"
export AWS_REGION="us-east-1"

# Run sync script
cd scripts/linux
./sync-videos.sh

# Or run once:
./sync-videos.sh --once

# Or with custom interval (120 seconds):
./sync-videos.sh --interval 120
```

**For Windows (PowerShell):**
```powershell
# Set environment variables
$env:LOCAL_VIDEO_FOLDER = "C:\Videos"
$env:S3_BUCKET_NAME = "04-california"
$env:AWS_REGION = "us-east-1"

# Run sync script
cd scripts\windows
.\sync-videos.ps1

# Or run once:
.\sync-videos.ps1 -Once

# Or with custom interval (120 seconds):
.\sync-videos.ps1 -Interval 120
```

### Step 11: Set Up as Background Service

**Linux (systemd):**

Create `/etc/systemd/system/video-sync.service`:
```ini
[Unit]
Description=Video Transcription S3 Sync
After=network.target

[Service]
Type=simple
User=your-username
Environment="LOCAL_VIDEO_FOLDER=/path/to/videos"
Environment="S3_BUCKET_NAME=04-california"
Environment="AWS_REGION=us-east-1"
ExecStart=/path/to/scripts/linux/sync-videos.sh
Restart=always
RestartSec=60

[Install]
WantedBy=multi-user.target
```

Enable and start:
```bash
sudo systemctl daemon-reload
sudo systemctl enable video-sync.service
sudo systemctl start video-sync.service
sudo systemctl status video-sync.service
```

**Windows (Task Scheduler):**
```powershell
# Create scheduled task (runs every hour)
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
  -Argument "-ExecutionPolicy Bypass -File C:\path\to\scripts\windows\sync-videos.ps1 -Once"

$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Hours 1)

$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -RunLevel Highest

Register-ScheduledTask -TaskName "VideoSync" -Action $action -Trigger $trigger -Principal $principal
```

---

## Monitoring & Operations

### View CloudWatch Logs

```bash
# Step Functions execution logs
aws logs tail /aws/vendedlogs/states/video-transcription-workflow --follow --region us-east-1

# Lambda function logs
aws logs tail /aws/lambda/video-transcription-text-processor --follow --region us-east-1
```

### Check Costs

```bash
# Get cost estimate (requires Cost Explorer API)
aws ce get-cost-and-usage \
  --time-period Start=2025-01-01,End=2025-01-31 \
  --granularity MONTHLY \
  --metrics UnblendedCost \
  --filter file://cost-filter.json
```

**cost-filter.json**:
```json
{
  "Tags": {
    "Key": "Project",
    "Values": ["video-transcription"]
  }
}
```

### Troubleshooting

**Issue: Step Functions not triggered after S3 upload**
```bash
# Check EventBridge rule
aws events list-rules --name-prefix video-transcription --region us-east-1

# Check EventBridge targets
aws events list-targets-by-rule --rule video-transcription-s3-upload-trigger --region us-east-1
```

**Issue: MediaConvert job fails**
```bash
# List recent jobs
aws mediaconvert list-jobs --max-results 10 --region us-east-1

# Get job details
aws mediaconvert get-job --id <JOB_ID> --region us-east-1
```

**Issue: Transcribe job fails**
```bash
# List recent jobs
aws transcribe list-transcription-jobs --max-results 10 --region us-east-1

# Get job details
aws transcribe get-transcription-job --transcription-job-name <JOB_NAME> --region us-east-1
```

---

## Cleanup

To delete all resources:

```bash
# Empty S3 bucket first (CloudFormation can't delete non-empty buckets)
aws s3 rm s3://$S3_BUCKET_NAME --recursive --region us-east-1

# Delete CloudFormation stack
aws cloudformation delete-stack \
  --stack-name video-transcription-pipeline \
  --region us-east-1

# Wait for deletion
aws cloudformation wait stack-delete-complete \
  --stack-name video-transcription-pipeline \
  --region us-east-1
```

---

## Advanced Configuration

### Custom Vocabulary for CCNA Terms

Create `custom-vocabulary.txt`:
```
OSPF
EIGRP
BGP
VLAN
HSRP
STP
```

Upload to S3:
```bash
aws s3 cp custom-vocabulary.txt s3://$S3_BUCKET_NAME/vocabulary/ccna-terms.txt
```

Update Step Functions to use custom vocabulary (modify `StartTranscribeJob` state):
```json
"Settings": {
  "VocabularyName": "ccna-vocabulary"
}
```

### Enable X-Ray Tracing

Already enabled in CloudFormation template. View traces:
```bash
# AWS Console
https://console.aws.amazon.com/xray
```

### Cost Optimization

1. **Reduce MediaConvert bitrate** (edit CloudFormation):
   - Change `MaxBitrate` from 5000000 to 3000000
   - Lower quality, lower cost

2. **Disable .vtt output** (if not needed):
   - Remove `vtt` from Subtitles.Formats array

3. **S3 Lifecycle policies** (already configured):
   - Raw .ts files deleted after 30 days

---

## Support

For issues or questions:
1. Check CloudWatch Logs
2. Review Step Functions execution history
3. Consult AWS documentation:
   - [MediaConvert](https://docs.aws.amazon.com/mediaconvert/)
   - [Transcribe](https://docs.aws.amazon.com/transcribe/)
   - [Step Functions](https://docs.aws.amazon.com/step-functions/)
