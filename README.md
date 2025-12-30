# AWS Video Transcription Pipeline

**Production-Grade Serverless Architecture for Educational Video Processing**

Automatically transcode, transcribe, and format video content for study materials—designed specifically for CCNA exam preparation but adaptable for any educational content.

---

## 🎯 Overview

This solution provides a **fully automated, serverless pipeline** that:

1. ✅ **Ingests** `.ts` video files from local storage → S3
2. ✅ **Transcodes** `.ts` → `.mp4` using AWS MediaConvert
3. ✅ **Transcribes** audio → `.srt` and `.vtt` subtitles using AWS Transcribe
4. ✅ **Formats** subtitles → clean `.txt` study materials

### Why This Architecture?

| Decision | Alternative | Why We Chose This |
|----------|------------|-------------------|
| **Step Functions** | Chained Lambda functions | Better visibility, error handling, workflow management |
| **MediaConvert** | FFmpeg in Lambda | No file size limits, professional quality, no timeout issues |
| **EventBridge** | S3 Event Notifications | More flexible event routing, easier debugging |
| **Serverless** | EC2-based processing | Pay-per-use, auto-scaling, zero maintenance |

**See [ARCHITECTURE.md](./ARCHITECTURE.md) for detailed technical rationale.**

---

## 🚀 Quick Start (5 Minutes)

### Prerequisites
- AWS Account ([create one](https://aws.amazon.com/free/))
- AWS CLI installed ([install guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html))
- `.ts` video files ready to process

### Deploy in 3 Commands

```bash
# 1. Configure AWS credentials
aws configure

# 2. Clone this repository
git clone https://github.com/your-org/aws-transcribe.git
cd aws-transcribe

# 3. Deploy infrastructure
export S3_BUCKET_NAME="04-california"
export NOTIFICATION_EMAIL="your-email@example.com"

aws cloudformation create-stack \
  --stack-name video-transcription-pipeline \
  --template-body file://cloudformation/transcription-pipeline.yaml \
  --parameters \
    ParameterKey=S3BucketName,ParameterValue=$S3_BUCKET_NAME \
    ParameterKey=NotificationEmail,ParameterValue=$NOTIFICATION_EMAIL \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1

# Wait for completion (~5 minutes)
aws cloudformation wait stack-create-complete \
  --stack-name video-transcription-pipeline \
  --region us-east-1

# 4. Deploy Lambda code
cd lambda/text-processor
zip -r function.zip lambda_function.py
aws lambda update-function-code \
  --function-name video-transcription-text-processor \
  --zip-file fileb://function.zip \
  --region us-east-1

# 5. Test with a video
aws s3 cp your-video.ts s3://$S3_BUCKET_NAME/04-california/amazon_transcribe/ine/raw/
```

**That's it!** Monitor progress in the [Step Functions Console](https://console.aws.amazon.com/states).

---

## 📁 Project Structure

```
aws-transcribe/
├── ARCHITECTURE.md                    # Technical design decisions
├── README.md                          # This file
│
├── cloudformation/
│   └── transcription-pipeline.yaml   # Infrastructure as Code
│
├── step-functions/
│   └── transcription-workflow.json   # State machine definition
│
├── lambda/
│   └── text-processor/
│       ├── lambda_function.py        # SRT → TXT converter
│       └── requirements.txt
│
├── scripts/
│   ├── linux/
│   │   └── sync-videos.sh           # Auto-sync for Linux/Mac
│   └── windows/
│       └── sync-videos.ps1          # Auto-sync for Windows
│
└── docs/
    └── DEPLOYMENT.md                 # Comprehensive deployment guide
```

---

## 🏗️ Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    Local Machine (Win/Linux)                 │
│                     ├── video01.ts                           │
│                     ├── video02.ts                           │
│                     └── video03.ts                           │
└─────────────────────────────────────────────────────────────┘
                              │
                    AWS CLI sync / PowerShell
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  S3 Bucket: s3://04-california/04-california/amazon_transcribe/  │
│                                                              │
│  ├── raw/          (.ts files)                              │
│  ├── transcoded/   (.mp4 files)                             │
│  ├── transcripts/  (.srt, .vtt files)                       │
│  └── text/         (.txt files)                             │
└─────────────────────────────────────────────────────────────┘
                              │
                      S3 Event → EventBridge
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│           AWS Step Functions (Orchestrator)                  │
│                                                              │
│   1. Validate file (.ts)                                    │
│   2. MediaConvert: .ts → .mp4 (waits for completion)        │
│   3. Transcribe: .mp4 → .srt, .vtt (waits for completion)   │
│   4. Lambda: .srt → clean .txt                              │
│   5. Notify completion (SNS)                                │
└─────────────────────────────────────────────────────────────┘
```

---

## 💰 Cost Estimate

**Assumptions**: 1 hour of 720p video, processed once

| Service | Cost |
|---------|------|
| MediaConvert (1 hour HD transcoding) | $1.80 |
| Transcribe (60 minutes audio) | $1.44 |
| S3 Storage (8GB total) | $0.18/month |
| Lambda (text processing) | $0.0001 |
| Step Functions (1 execution) | $0.025 |
| **Total per video** | **~$3.27** |

**Monthly (30 videos)**: ~$103/month

💡 **Optimization tips**:
- Lower MediaConvert bitrate (saves ~30%)
- Delete raw `.ts` files after 7 days (auto-configured)
- Use S3 Intelligent-Tiering for long-term storage

---

## 📖 Documentation

- **[ARCHITECTURE.md](./ARCHITECTURE.md)**: Detailed technical design, trade-offs, and rationale
- **[docs/DEPLOYMENT.md](./docs/DEPLOYMENT.md)**: Step-by-step deployment with troubleshooting

---

## 🔧 Usage

### Automated Sync (Recommended for Production)

**Linux/Mac:**
```bash
export LOCAL_VIDEO_FOLDER="/path/to/videos"
export S3_BUCKET_NAME="04-california"

# Continuous sync every 60 seconds
./scripts/linux/sync-videos.sh

# Or one-time sync
./scripts/linux/sync-videos.sh --once
```

**Windows (PowerShell):**
```powershell
$env:LOCAL_VIDEO_FOLDER = "C:\Videos"
$env:S3_BUCKET_NAME = "04-california"

# Continuous sync every 60 seconds
.\scripts\windows\sync-videos.ps1

# Or one-time sync
.\scripts\windows\sync-videos.ps1 -Once
```

### Manual Upload

```bash
aws s3 cp video.ts s3://04-california/04-california/amazon_transcribe/ine/raw/
```

### Download Results

```bash
# Download all processed text files
aws s3 sync s3://04-california/04-california/amazon_transcribe/ine/text/ ./study-materials/
```

---

## 🔍 Monitoring

### AWS Console (Visual)

1. **Step Functions**: https://console.aws.amazon.com/states
   - View workflow execution in real-time
   - See which step is currently running
   - Inspect inputs/outputs of each stage

2. **CloudWatch Logs**:
   - Lambda logs: `/aws/lambda/video-transcription-text-processor`
   - Step Functions logs: `/aws/vendedlogs/states/video-transcription-workflow`

### AWS CLI

```bash
# List recent Step Functions executions
aws stepfunctions list-executions \
  --state-machine-arn $(aws cloudformation describe-stacks \
    --stack-name video-transcription-pipeline \
    --query 'Stacks[0].Outputs[?OutputKey==`StateMachineArn`].OutputValue' \
    --output text) \
  --max-results 5

# Get execution details
aws stepfunctions describe-execution --execution-arn <ARN>

# View Lambda logs
aws logs tail /aws/lambda/video-transcription-text-processor --follow
```

---

## 🛠️ Customization

### Change Transcription Language

Edit `cloudformation/transcription-pipeline.yaml`:
```yaml
LanguageCode: "es-US"  # Change to Spanish
```

### Add Custom CCNA Vocabulary

```bash
# Create vocabulary file
cat > ccna-vocabulary.txt << EOF
OSPF
EIGRP
BGP
VLAN
EOF

# Upload to S3
aws s3 cp ccna-vocabulary.txt s3://04-california/vocabulary/

# Update Step Functions to reference it
# (See docs/DEPLOYMENT.md#advanced-configuration)
```

### Adjust Video Quality (Lower Costs)

Edit `cloudformation/transcription-pipeline.yaml`:
```yaml
MaxBitrate: 3000000  # Reduce from 5000000 (saves ~30%)
```

---

## 🧪 Testing

### Test Lambda Function Locally

```bash
cd lambda/text-processor
python3 lambda_function.py
```

### Test with Sample SRT File

```python
import lambda_function

sample_srt = """1
00:00:00,000 --> 00:00:03,500
Welcome to CCNA course.

2
00:00:03,500 --> 00:00:07,000
Today we cover OSPF routing.
"""

clean_text = lambda_function.parse_srt_to_text(sample_srt)
print(clean_text)
# Output: "Welcome to CCNA course. Today we cover OSPF routing."
```

---

## ❓ FAQ

**Q: Why MediaConvert instead of FFmpeg in Lambda?**
A: FFmpeg in Lambda has 15-minute timeout and 10GB storage limits. MediaConvert is purpose-built for video, has no limits, and better quality.

**Q: Can I process multiple videos in parallel?**
A: Yes! Each S3 upload triggers a separate Step Functions execution. AWS auto-scales.

**Q: What if transcription quality is poor?**
A: Use custom vocabulary for technical terms (see Customization above).

**Q: How do I delete everything?**
A: See [docs/DEPLOYMENT.md#cleanup](./docs/DEPLOYMENT.md#cleanup)

**Q: Can I use this for languages other than English?**
A: Yes! Transcribe supports 100+ languages. Change `LanguageCode` in CloudFormation.

---

## 🤝 Contributing

Contributions welcome! Please:
1. Fork this repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License - see [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- Built for CCNA exam preparation but applicable to any educational content
- Architecture follows AWS Well-Architected Framework principles
- Designed for operational excellence, security, and cost optimization

---

## 📞 Support

- **Documentation**: See [docs/](./docs/) folder
- **Issues**: [GitHub Issues](https://github.com/your-org/aws-transcribe/issues)
- **AWS Support**: [AWS Support Center](https://console.aws.amazon.com/support/)

---

**Built with ❤️ by Senior AWS Solutions Architects**

*Transform your video content into study materials in minutes, not hours.*