# AWS Video Transcription Pipeline - Architecture

## Executive Summary

This document outlines a **production-grade**, **serverless** architecture for automated video transcription designed for educational content processing.

## Architecture Decision: Why NOT the Original Proposal

### ❌ Problems with Chained Lambda + S3 Events Approach

1. **Poor Observability**: No single view of workflow state across 3-4 Lambda functions
2. **Error Handling Nightmare**: If step 3 fails, steps 1-2 already completed—no atomic rollback
3. **Hidden Costs**: Each Lambda invocation has overhead; debugging requires CloudWatch log correlation
4. **FFmpeg in Lambda**:
   - 15-minute timeout limits (large .ts files will fail)
   - /tmp storage constraints (512MB default, 10GB max)
   - Layer size limits (250MB unzipped)
   - Cold start penalties with large binary layers

### ✅ Senior Architect Recommendation: Step Functions + MediaConvert

```
┌─────────────────────────────────────────────────────────────────┐
│                     PRODUCTION ARCHITECTURE                      │
└─────────────────────────────────────────────────────────────────┘

Local Machine (Win/Linux)
    │
    │ (AWS CLI sync / DataSync)
    ▼
┌─────────────────────────────────────────────────────────────────┐
│ S3 Bucket: s3://your-bucket/04-california/aws_transcribe/ine/  │
│                                                                  │
│   ├── raw/          (.ts files)                                 │
│   ├── transcoded/   (.mp4 files)                                │
│   ├── transcripts/  (.srt, .vtt files)                          │
│   └── text/         (.txt files)                                │
└─────────────────────────────────────────────────────────────────┘
    │
    │ S3 Event → EventBridge
    ▼
┌─────────────────────────────────────────────────────────────────┐
│              AWS Step Functions State Machine                    │
│                                                                  │
│  ┌─────────────────────────────────────────────────────┐        │
│  │ 1. Parse S3 Event & Validate File                   │        │
│  └─────────────────────────────────────────────────────┘        │
│                         │                                        │
│                         ▼                                        │
│  ┌─────────────────────────────────────────────────────┐        │
│  │ 2. Start MediaConvert Job (.ts → .mp4)              │        │
│  │    - Wait for completion (up to 24 hours)           │        │
│  │    - Auto-retry on transient failures                │        │
│  └─────────────────────────────────────────────────────┘        │
│                         │                                        │
│                         ▼                                        │
│  ┌─────────────────────────────────────────────────────┐        │
│  │ 3. Start AWS Transcribe Job (.mp4 → .srt/.vtt)      │        │
│  │    - Wait for completion                             │        │
│  │    - Subtitles format: srt, vtt                      │        │
│  └─────────────────────────────────────────────────────┘        │
│                         │                                        │
│                         ▼                                        │
│  ┌─────────────────────────────────────────────────────┐        │
│  │ 4. Lambda: Clean SRT → TXT                           │        │
│  │    - Strip timestamps, metadata                      │        │
│  │    - Extract pure spoken text                        │        │
│  └─────────────────────────────────────────────────────┘        │
│                         │                                        │
│                         ▼                                        │
│  ┌─────────────────────────────────────────────────────┐        │
│  │ 5. Success Notification (SNS/EventBridge)            │        │
│  └─────────────────────────────────────────────────────┘        │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Why This Architecture Is Superior

### 1. **Step Functions vs Chained Lambdas**

| Aspect | Chained Lambdas | Step Functions |
|--------|----------------|----------------|
| **Visibility** | CloudWatch Logs only | Visual workflow console |
| **Error Handling** | Manual retry logic | Built-in retry/catch |
| **Timeout** | 15 min per Lambda | Hours/days per workflow |
| **State Management** | DynamoDB required | Native state machine |
| **Debugging** | Log correlation hell | Execution history with inputs/outputs |
| **Cost** | $0.20 per 1M requests | $0.025 per 1K state transitions (cheaper for complex workflows) |

### 2. **MediaConvert vs FFmpeg in Lambda**

| Aspect | FFmpeg Lambda | MediaConvert |
|--------|--------------|--------------|
| **File Size Limit** | 10GB (/tmp) | None (S3-based) |
| **Processing Time** | 15 min max | Hours (no timeout) |
| **Quality** | Depends on FFmpeg config | Professional-grade, optimized |
| **Maintenance** | Manage FFmpeg binaries | Fully managed |
| **Pricing** | Lambda GB-seconds | $0.015/min (SD), $0.03/min (HD) |
| **Use Case** | Small files (<1GB, <10min) | Production video processing |

**Recommendation**: For educational videos (likely 30-60 minutes), MediaConvert is the **only production-viable option**.

## File Naming Convention

All stages preserve the base filename:
```
video01.ts → video01.mp4 → video01.srt → video01.txt
```

Implemented via:
- MediaConvert: Output file template
- Transcribe: `OutputKey` parameter
- Lambda: Regex-based filename parsing

## Cost Estimation (Per Hour of Video)

Assumptions: 1 hour of 720p video @ 2GB

| Service | Cost |
|---------|------|
| S3 Storage (4 files × 2GB) | $0.18/month |
| S3 PUT Requests | $0.0002 |
| MediaConvert (1 hour @ HD) | $1.80 |
| Transcribe (1 hour) | $0.024/min × 60 = $1.44 |
| Lambda (text processing) | ~$0.0001 |
| Step Functions | $0.025 per execution |
| **TOTAL per video** | **~$3.27** |

**Monthly (30 videos)**: ~$98 + $5.40 storage = **$103.40**

## Security & Compliance

- **Encryption**: S3 SSE-S3 (or SSE-KMS for sensitive content)
- **IAM**: Least-privilege policies (separate roles per service)
- **VPC**: Not required (all services are AWS-managed)
- **Logging**: CloudTrail + CloudWatch for audit trail

## Scalability

- **Concurrent Executions**: Step Functions supports 1M+ concurrent executions
- **MediaConvert**: Auto-scales, no queue limits
- **Transcribe**: 100 concurrent jobs per account (soft limit, increasable)

## Operational Excellence

### Monitoring
- CloudWatch alarms on Step Functions failures
- SNS notifications for workflow completion/errors
- X-Ray tracing for distributed debugging

### Disaster Recovery
- S3 versioning enabled (rollback capability)
- Cross-region replication (optional)
- Automated retries with exponential backoff

## Next Steps

1. Deploy infrastructure (CloudFormation/Terraform)
2. Configure local sync (AWS CLI sync script)
3. Test with sample .ts file
4. Monitor first execution in Step Functions console
5. Tune Transcribe accuracy (custom vocabulary if needed)
