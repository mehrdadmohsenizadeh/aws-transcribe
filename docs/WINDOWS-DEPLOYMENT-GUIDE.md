# Windows Deployment Guide - Complete Walkthrough

**For Complete Beginners - Every Step Explained**

---

## ⚠️ Important Clarification: Bucket Name vs. Folder Path

**You mentioned bucket name `/04-california/`** - this is actually a **folder path inside the bucket**, not the bucket name itself.

Here's how S3 works:
```
s3://my-unique-bucket-name/04-california/aws_transcribe/ine/raw/video.ts
       ↑                    ↑
   Bucket Name         Folder Path (prefix)
```

**You need to choose a globally unique bucket name** (examples below in Step 4).

The folder structure `/04-california/aws_transcribe/ine/` is already configured in the code—you don't need to change it.

---

## Part 1: Install Required Software

### Step 1: Install AWS CLI

1. **Download AWS CLI Installer for Windows**
   - Go to: https://awscli.amazonaws.com/AWSCLIV2.msi
   - Click the link to download (file size: ~30MB)
   - Save it to your `Downloads` folder

2. **Run the Installer**
   - Double-click `AWSCLIV2.msi` in your Downloads folder
   - Click "Next" through the installation wizard
   - Accept the license agreement
   - Click "Install" (may require administrator password)
   - Click "Finish" when done

3. **Verify Installation**
   - Press `Windows Key + R`
   - Type `cmd` and press Enter (opens Command Prompt)
   - Type this command and press Enter:
   ```cmd
   aws --version
   ```
   - You should see something like:
   ```
   aws-cli/2.15.0 Python/3.11.6 Windows/10 exe/AMD64
   ```
   - If you see an error, **restart your computer** and try again

### Step 2: Install Git (Optional, but Recommended)

1. **Download Git for Windows**
   - Go to: https://git-scm.com/download/win
   - The download should start automatically
   - If not, click "Click here to download manually"

2. **Run the Installer**
   - Double-click the downloaded file (e.g., `Git-2.43.0-64-bit.exe`)
   - Click "Next" through the wizard
   - **Important**: On "Adjusting your PATH environment", select "Git from the command line and also from 3rd-party software"
   - Click "Next" for all other options (defaults are fine)
   - Click "Install"
   - Click "Finish"

3. **Verify Installation**
   - Open Command Prompt (Windows Key + R → type `cmd` → Enter)
   - Type:
   ```cmd
   git --version
   ```
   - Should see: `git version 2.43.0.windows.1` (or similar)

---

## Part 2: Get AWS Account Credentials

### Step 3: Create AWS Access Keys

1. **Log into AWS Console**
   - Go to: https://console.aws.amazon.com/
   - Enter your AWS account email and password
   - Complete MFA if enabled

2. **Navigate to IAM**
   - In the search bar at the top, type `IAM`
   - Click on "IAM" (Identity and Access Management)

3. **Create Access Key**
   - In the left sidebar, click "Users"
   - Click on your username
   - Click the "Security credentials" tab
   - Scroll down to "Access keys"
   - Click "Create access key"
   - Select "Command Line Interface (CLI)"
   - Check the confirmation box at the bottom
   - Click "Next"
   - Add description tag (optional): "Video Transcription Pipeline"
   - Click "Create access key"

4. **SAVE YOUR CREDENTIALS** (Critical Step!)
   - You'll see two values:
     - **Access key ID**: Looks like `AKIAIOSFODNN7EXAMPLE`
     - **Secret access key**: Looks like `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY`

   - **IMPORTANT**: Copy these to Notepad and save the file
   - You will **NEVER** see the secret key again after closing this window
   - Click "Download .csv file" as backup
   - Click "Done"

---

## Part 3: Configure AWS CLI

### Step 4: Set Up AWS Credentials

1. **Open Command Prompt**
   - Press `Windows Key + R`
   - Type `cmd` and press Enter

2. **Run AWS Configure**
   ```cmd
   aws configure
   ```

3. **Enter Your Information** (press Enter after each line)

   **Prompt 1:**
   ```
   AWS Access Key ID [None]:
   ```
   → Paste your Access Key ID (from Step 3) and press Enter

   **Prompt 2:**
   ```
   AWS Secret Access Key [None]:
   ```
   → Paste your Secret Access Key (from Step 3) and press Enter

   **Prompt 3:**
   ```
   Default region name [None]:
   ```
   → Type `us-east-1` and press Enter

   **Prompt 4:**
   ```
   Default output format [None]:
   ```
   → Type `json` and press Enter

4. **Test Your Configuration**
   ```cmd
   aws sts get-caller-identity
   ```

   You should see output like:
   ```json
   {
       "UserId": "AIDAXXXXXXXXXXXXXXXXX",
       "Account": "123456789012",
       "Arn": "arn:aws:iam::123456789012:user/your-username"
   }
   ```

   ✅ If you see this, AWS CLI is working!
   ❌ If you see an error, double-check your access keys

---

## Part 4: Choose Your S3 Bucket Name

### Step 5: Create a Unique Bucket Name

**S3 bucket names must be globally unique across ALL AWS accounts worldwide.**

**Format Rules:**
- 3-63 characters long
- Only lowercase letters, numbers, and hyphens
- Must start and end with a letter or number
- No spaces, underscores, or special characters

**Examples of GOOD bucket names:**
```
video-transcribe-yourname-2025
ccna-study-materials-john-12345
ine-videos-prod-xyz789
transcripts-california-2025
```

**Examples of BAD bucket names:**
```
04-california          ❌ (starts with number)
My_Bucket              ❌ (capital letters and underscore)
video transcribe       ❌ (space)
/04-california/        ❌ (slashes - this is a folder path, not a name)
```

**Choose your bucket name now and write it down:**
```
My bucket name: ___________________________________
```

For this guide, I'll use the example: `video-transcribe-california-2025`

**Replace this with YOUR bucket name in all commands below.**

---

## Part 5: Download the Project Code

### Step 6: Clone the Repository

1. **Open Command Prompt**

2. **Navigate to Your Downloads Folder**
   ```cmd
   cd C:\Users\%USERNAME%\Downloads
   ```

3. **Clone the Repository**
   ```cmd
   git clone https://github.com/mehrdadmohsenizadeh/aws-transcribe.git
   ```

   You should see:
   ```
   Cloning into 'aws-transcribe'...
   remote: Enumerating objects: ...
   Receiving objects: 100% ...
   ```

4. **Navigate into the Project**
   ```cmd
   cd aws-transcribe
   ```

5. **Verify Files Are There**
   ```cmd
   dir
   ```

   You should see folders like:
   ```
   cloudformation
   docs
   lambda
   scripts
   ARCHITECTURE.md
   README.md
   ```

---

## Part 6: Deploy the Infrastructure

### Step 7: Set Your Configuration Variables

1. **Still in Command Prompt**, set your bucket name and email:

   **REPLACE THESE VALUES WITH YOUR OWN:**

   ```cmd
   set S3_BUCKET_NAME=video-transcribe-california-2025
   ```
   ↑ Replace with YOUR unique bucket name from Step 5

   ```cmd
   set NOTIFICATION_EMAIL=your-email@gmail.com
   ```
   ↑ Replace with YOUR email address (you'll get notifications here)

2. **Verify Variables Are Set**
   ```cmd
   echo %S3_BUCKET_NAME%
   echo %NOTIFICATION_EMAIL%
   ```

   Should print your bucket name and email

### Step 8: Deploy CloudFormation Stack

**This creates all AWS resources: S3 bucket, Lambda, Step Functions, etc.**

1. **Run the Deploy Command** (copy this entire block):

   ```cmd
   aws cloudformation create-stack --stack-name video-transcription-pipeline --template-body file://cloudformation/transcription-pipeline.yaml --parameters ParameterKey=S3BucketName,ParameterValue=%S3_BUCKET_NAME% ParameterKey=NotificationEmail,ParameterValue=%NOTIFICATION_EMAIL% --capabilities CAPABILITY_NAMED_IAM --region us-east-1
   ```

2. **Expected Output:**
   ```json
   {
       "StackId": "arn:aws:cloudformation:us-east-1:123456789012:stack/video-transcription-pipeline/..."
   }
   ```

   ✅ This means deployment started!

3. **Wait for Deployment to Complete** (takes 3-5 minutes)

   Run this command to wait:
   ```cmd
   aws cloudformation wait stack-create-complete --stack-name video-transcription-pipeline --region us-east-1
   ```

   - The command will appear "stuck" with no output—this is normal
   - After 3-5 minutes, you'll get back to the command prompt
   - No output = success!

4. **Verify Deployment**
   ```cmd
   aws cloudformation describe-stacks --stack-name video-transcription-pipeline --region us-east-1 --query "Stacks[0].StackStatus"
   ```

   Should print:
   ```
   "CREATE_COMPLETE"
   ```

### Step 9: Confirm Email Subscription

**AWS sends a confirmation email to verify you own the address.**

1. **Check Your Email Inbox**
   - Look for email from: `AWS Notifications <no-reply@sns.amazonaws.com>`
   - Subject: "AWS Notification - Subscription Confirmation"
   - **Check spam folder if you don't see it**

2. **Click "Confirm subscription"** in the email

3. **You'll see**: "Subscription confirmed!"

---

## Part 7: Deploy the Lambda Function Code

### Step 10: Package and Upload Lambda Code

**The CloudFormation template created the Lambda function, but it has placeholder code. Now we deploy the real code.**

1. **Navigate to Lambda Folder**
   ```cmd
   cd lambda\text-processor
   ```

2. **Check Python is Installed**
   ```cmd
   python --version
   ```

   - If you see `Python 3.x.x`, great!
   - If you see an error: Download Python from https://www.python.org/downloads/ and install it
   - **During install, check "Add Python to PATH"**

3. **Create Deployment Package**

   **If you have PowerShell** (recommended):
   ```cmd
   powershell Compress-Archive -Path lambda_function.py -DestinationPath function.zip -Force
   ```

   **If PowerShell doesn't work**, download 7-Zip from https://www.7-zip.org/ and use:
   ```cmd
   "C:\Program Files\7-Zip\7z.exe" a function.zip lambda_function.py
   ```

4. **Upload to AWS Lambda**
   ```cmd
   aws lambda update-function-code --function-name video-transcription-text-processor --zip-file fileb://function.zip --region us-east-1
   ```

5. **Expected Output:**
   ```json
   {
       "FunctionName": "video-transcription-text-processor",
       "Runtime": "python3.11",
       "State": "Active",
       ...
   }
   ```

   ✅ Lambda code deployed!

---

## Part 8: Set Up Video Sync Script

### Step 11: Configure the PowerShell Sync Script

**This script will automatically upload .ts files from your Downloads folder to S3.**

1. **Open Notepad**
   - Press `Windows Key + R`
   - Type `notepad` and press Enter

2. **Create Configuration File**

   Copy this text into Notepad:
   ```cmd
   @echo off
   set LOCAL_VIDEO_FOLDER=C:\Users\%USERNAME%\Downloads\transcripts
   set S3_BUCKET_NAME=video-transcribe-california-2025
   set AWS_REGION=us-east-1
   set AWS_PROFILE=default
   ```

   **IMPORTANT**: Replace `video-transcribe-california-2025` with YOUR bucket name!

3. **Save the File**
   - Click "File" → "Save As"
   - Navigate to: `C:\Users\YourUsername\Downloads\aws-transcribe\scripts\windows\`
   - Filename: `config.bat`
   - Save as type: "All Files (*.*)"
   - Click "Save"

4. **Navigate to Scripts Folder**
   ```cmd
   cd C:\Users\%USERNAME%\Downloads\aws-transcribe\scripts\windows
   ```

---

## Part 9: Test the Pipeline

### Step 12: Upload a Test Video

**Option 1: Using AWS CLI (Easiest)**

1. **Create Test Video Folder** (if it doesn't exist)
   ```cmd
   mkdir "C:\Users\%USERNAME%\Downloads\transcripts"
   ```

2. **Place a .ts video file** in `C:\Users\%USERNAME%\Downloads\transcripts\`

   For testing, you can use ANY small .ts file. If you don't have one:
   - Download a sample: https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/360/Big_Buck_Bunny_360_10s_1MB.ts
   - Or rename any .mp4 video to .ts for testing (won't process correctly but will test the workflow)

3. **Upload Using AWS CLI**

   **First, set your bucket name again** (if you closed the window):
   ```cmd
   set S3_BUCKET_NAME=video-transcribe-california-2025
   ```
   ↑ Replace with YOUR bucket name!

   **Upload the file**:
   ```cmd
   aws s3 cp "C:\Users\%USERNAME%\Downloads\transcripts\test-video.ts" s3://%S3_BUCKET_NAME%/04-california/aws_transcribe/ine/raw/test-video.ts --region us-east-1
   ```
   ↑ Replace `test-video.ts` with your actual filename!

4. **Expected Output**:
   ```
   upload: transcripts\test-video.ts to s3://video-transcribe-california-2025/04-california/aws_transcribe/ine/raw/test-video.ts
   ```

**Option 2: Using PowerShell Sync Script**

1. **Open PowerShell as Administrator**
   - Press `Windows Key`
   - Type `PowerShell`
   - Right-click "Windows PowerShell"
   - Click "Run as administrator"

2. **Navigate to Scripts Folder**
   ```powershell
   cd C:\Users\$env:USERNAME\Downloads\aws-transcribe\scripts\windows
   ```

3. **Set Variables**
   ```powershell
   $env:LOCAL_VIDEO_FOLDER = "C:\Users\$env:USERNAME\Downloads\transcripts"
   $env:S3_BUCKET_NAME = "video-transcribe-california-2025"
   ```
   ↑ Replace with YOUR bucket name!

4. **Run One-Time Sync**
   ```powershell
   .\sync-videos.ps1 -Once
   ```

5. **Expected Output**:
   ```
   [INFO] 2025-12-30 10:23:45 - ==========================================
   [INFO] 2025-12-30 10:23:45 - Video Sync Script (Windows)
   [INFO] 2025-12-30 10:23:45 - ==========================================
   [SUCCESS] AWS CLI found: aws-cli/2.15.0
   [SUCCESS] Local folder exists: C:\Users\...\Downloads\transcripts
   [SUCCESS] AWS credentials valid
   [SUCCESS] S3 bucket accessible
   [INFO] Found 1 .ts file(s) in local folder
   [SUCCESS] Uploaded 1 file(s) to S3
   ```

---

## Part 10: Monitor the Workflow

### Step 13: Watch Your Video Being Processed

**Option 1: AWS Console (Visual - Recommended for First Time)**

1. **Open Your Browser**
   - Go to: https://console.aws.amazon.com/states
   - Log in with your AWS credentials

2. **Select Your Region**
   - In the top-right corner, make sure it says "N. Virginia" (us-east-1)
   - If not, click the dropdown and select "US East (N. Virginia)"

3. **Find Your State Machine**
   - Click on `video-transcription-workflow`

4. **View Executions**
   - You should see a new execution (started within last 2 minutes)
   - Status will be "Running"
   - Click on it to see the visual graph

5. **Watch the Progress**
   - You'll see steps turning green as they complete:
     - ✅ ParseS3Event (1 second)
     - ✅ ValidateInputFile (1 second)
     - 🔄 StartMediaConvertJob (3-10 minutes depending on video length)
     - ⏳ StartTranscribeJob (pending)
     - ⏳ ProcessTranscriptToText (pending)

**Typical Timeline:**
- **5-minute test video**: ~8-12 minutes total
- **30-minute lecture**: ~35-40 minutes total
- **60-minute video**: ~70-80 minutes total

**Option 2: AWS CLI**

```cmd
aws stepfunctions list-executions --state-machine-arn arn:aws:states:us-east-1:YOUR_ACCOUNT_ID:stateMachine:video-transcription-workflow --max-results 1 --region us-east-1
```

---

## Part 11: Download Your Results

### Step 14: Get the Transcribed Text

**After the workflow completes**, download the final .txt file:

1. **List Files in S3**
   ```cmd
   aws s3 ls s3://%S3_BUCKET_NAME%/04-california/aws_transcribe/ine/text/ --region us-east-1
   ```

   Should show:
   ```
   2025-12-30 10:45:12       5234 test-video.txt
   ```

2. **Download the Text File**
   ```cmd
   aws s3 cp s3://%S3_BUCKET_NAME%/04-california/aws_transcribe/ine/text/test-video.txt "C:\Users\%USERNAME%\Downloads\test-video.txt" --region us-east-1
   ```

3. **Open and Read**
   ```cmd
   notepad "C:\Users\%USERNAME%\Downloads\test-video.txt"
   ```

4. **You Should See**: Clean, formatted text with no timestamps:
   ```
   Welcome to the CCNA certification course. Today we'll cover network fundamentals. The OSI model has seven layers...
   ```

---

## Part 12: Set Up Automatic Sync (Optional)

### Step 15: Run Sync Continuously in Background

**Option A: Manual (For Testing)**

1. Open PowerShell
2. Run:
   ```powershell
   cd C:\Users\$env:USERNAME\Downloads\aws-transcribe\scripts\windows
   $env:LOCAL_VIDEO_FOLDER = "C:\Users\$env:USERNAME\Downloads\transcripts"
   $env:S3_BUCKET_NAME = "video-transcribe-california-2025"
   .\sync-videos.ps1
   ```
3. Leave the window open—it syncs every 60 seconds
4. Press `Ctrl+C` to stop

**Option B: Scheduled Task (Production)**

1. **Open Task Scheduler**
   - Press `Windows Key`
   - Type "Task Scheduler"
   - Click "Task Scheduler"

2. **Create New Task**
   - Click "Create Task" (right sidebar)
   - Name: `Video Sync to S3`
   - Description: `Automatically sync .ts videos to AWS S3`
   - Select "Run whether user is logged on or not"
   - Check "Run with highest privileges"

3. **Triggers Tab**
   - Click "New..."
   - Begin the task: "At log on"
   - Repeat task every: "1 hour"
   - For a duration of: "Indefinitely"
   - Click "OK"

4. **Actions Tab**
   - Click "New..."
   - Action: "Start a program"
   - Program/script: `powershell.exe`
   - Add arguments:
   ```
   -ExecutionPolicy Bypass -File "C:\Users\YOUR_USERNAME\Downloads\aws-transcribe\scripts\windows\sync-videos.ps1" -Once
   ```
   ↑ Replace `YOUR_USERNAME` with your actual Windows username!

   - Click "OK"

5. **Click "OK"** to save the task

Now your videos will sync automatically every hour!

---

## 🎉 You're Done!

## Summary of What Happens Now

1. **You drop a .ts video** into `C:\Users\YourName\Downloads\transcripts\`
2. **Sync script uploads** to S3 (every hour, or run manually)
3. **AWS automatically**:
   - Transcodes .ts → .mp4 (MediaConvert)
   - Transcribes audio → .srt subtitles (Transcribe)
   - Cleans .srt → plain .txt (Lambda)
4. **You download** the .txt file for studying

---

## Quick Reference: Your Custom Values

**Write these down for future reference:**

```
S3 Bucket Name: _________________________________

Email Address: _________________________________

Local Video Folder: C:\Users\YourName\Downloads\transcripts

AWS Region: us-east-1

CloudFormation Stack: video-transcription-pipeline
```

---

## Troubleshooting

### Problem: "aws: command not found"
**Solution**: Restart your computer after installing AWS CLI

### Problem: "The security token included in the request is invalid"
**Solution**: Re-run `aws configure` and double-check your access keys

### Problem: "Bucket already exists"
**Solution**: Choose a different bucket name (must be globally unique)

### Problem: "Access Denied"
**Solution**: Make sure your IAM user has AdministratorAccess policy

### Problem: "Execution failed at MediaConvert"
**Solution**: Ensure your .ts file is a valid video (not renamed .txt or corrupted)

### Problem: "No files syncing"
**Solution**:
1. Check folder path: `C:\Users\YourName\Downloads\transcripts\`
2. Ensure files end with `.ts` extension
3. Run sync manually to see errors

---

## Need Help?

1. **Check CloudWatch Logs**:
   - https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#logsV2:log-groups
   - Look for `/aws/lambda/video-transcription-text-processor`

2. **Check Step Functions Console**:
   - https://console.aws.amazon.com/states/home?region=us-east-1
   - Click on failed execution to see exact error

3. **AWS Documentation**:
   - Step Functions: https://docs.aws.amazon.com/step-functions/
   - Transcribe: https://docs.aws.amazon.com/transcribe/

---

**🚀 Happy transcribing! Your CCNA study materials are now automated!**
