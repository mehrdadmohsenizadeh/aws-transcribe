"""
Lambda Function: SRT to Clean Text Processor
Purpose: Strip timestamps and metadata from .srt files, output clean spoken text

Author: Senior AWS Solutions Architect
"""

import boto3
import re
import os
from typing import Dict, Any
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3_client = boto3.client('s3')


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Main Lambda handler

    Expected Input:
    {
        "bucket": "04-california",
        "srtKey": "amazon_transcribe/ine/transcripts/video01.srt",
        "baseFilename": "video01"
    }

    Returns:
    {
        "statusCode": 200,
        "txtKey": "amazon_transcribe/ine/text/video01.txt",
        "textLength": 15234
    }
    """

    try:
        # Extract parameters
        bucket = event['bucket']
        srt_key = event['srtKey']
        base_filename = event['baseFilename']

        logger.info(f"Processing SRT file: s3://{bucket}/{srt_key}")

        # Download SRT file from S3
        srt_content = download_srt(bucket, srt_key)

        # Parse and clean SRT content
        clean_text = parse_srt_to_text(srt_content)

        # Upload clean text to S3
        txt_key = f"amazon_transcribe/ine/text/{base_filename}.txt"
        upload_text(bucket, txt_key, clean_text)

        logger.info(f"Successfully created clean text: s3://{bucket}/{txt_key}")
        logger.info(f"Text length: {len(clean_text)} characters")

        return {
            'statusCode': 200,
            'txtKey': txt_key,
            'textLength': len(clean_text),
            'message': 'Successfully processed SRT to clean text'
        }

    except Exception as e:
        logger.error(f"Error processing SRT file: {str(e)}", exc_info=True)
        raise


def download_srt(bucket: str, key: str) -> str:
    """
    Download SRT file from S3 and return content as string
    """
    try:
        response = s3_client.get_object(Bucket=bucket, Key=key)
        content = response['Body'].read().decode('utf-8')
        logger.info(f"Downloaded {len(content)} bytes from s3://{bucket}/{key}")
        return content
    except s3_client.exceptions.NoSuchKey:
        logger.error(f"SRT file not found: s3://{bucket}/{key}")
        raise
    except Exception as e:
        logger.error(f"Failed to download SRT: {str(e)}")
        raise


def parse_srt_to_text(srt_content: str) -> str:
    """
    Parse SRT format and extract only spoken text

    SRT Format:
    1
    00:00:00,000 --> 00:00:03,500
    Welcome to the CCNA course.

    2
    00:00:03,500 --> 00:00:07,000
    Today we'll cover network fundamentals.

    Output:
    Welcome to the CCNA course. Today we'll cover network fundamentals.
    """

    # Split into subtitle blocks
    blocks = re.split(r'\n\s*\n', srt_content.strip())

    text_lines = []

    for block in blocks:
        if not block.strip():
            continue

        lines = block.strip().split('\n')

        # SRT format: [index, timestamp, text...]
        # We need to skip index (line 0) and timestamp (line 1)
        if len(lines) >= 3:
            # Lines 2+ contain the actual text
            subtitle_text = ' '.join(lines[2:])

            # Clean up any residual metadata/tags
            subtitle_text = clean_subtitle_text(subtitle_text)

            if subtitle_text:
                text_lines.append(subtitle_text)

    # Join all text with spaces, normalize whitespace
    clean_text = ' '.join(text_lines)
    clean_text = re.sub(r'\s+', ' ', clean_text).strip()

    # Add paragraph breaks every ~500 characters for readability
    clean_text = add_paragraph_breaks(clean_text)

    return clean_text


def clean_subtitle_text(text: str) -> str:
    """
    Remove subtitle-specific markup and artifacts
    """
    # Remove HTML-like tags (e.g., <i>, </i>, <b>, etc.)
    text = re.sub(r'<[^>]+>', '', text)

    # Remove subtitle formatting codes (e.g., {\an8}, {\pos(192,240)})
    text = re.sub(r'\{[^}]+\}', '', text)

    # Remove speaker labels if present (e.g., "Speaker 1: ")
    text = re.sub(r'^Speaker \d+:\s*', '', text)

    # Remove any [SOUND EFFECTS] or (background noise) markers
    text = re.sub(r'\[.*?\]', '', text)
    text = re.sub(r'\(.*?\)', '', text)

    # Normalize whitespace
    text = re.sub(r'\s+', ' ', text).strip()

    return text


def add_paragraph_breaks(text: str, chars_per_paragraph: int = 500) -> str:
    """
    Add paragraph breaks for better readability
    This helps when studying - breaks text into digestible chunks
    """
    if len(text) <= chars_per_paragraph:
        return text

    words = text.split()
    paragraphs = []
    current_paragraph = []
    current_length = 0

    for word in words:
        current_paragraph.append(word)
        current_length += len(word) + 1  # +1 for space

        # Break at sentence end near target length
        if current_length >= chars_per_paragraph and word.endswith(('.', '!', '?')):
            paragraphs.append(' '.join(current_paragraph))
            current_paragraph = []
            current_length = 0

    # Add remaining words
    if current_paragraph:
        paragraphs.append(' '.join(current_paragraph))

    return '\n\n'.join(paragraphs)


def upload_text(bucket: str, key: str, content: str) -> None:
    """
    Upload clean text to S3 with optimized settings
    """
    try:
        s3_client.put_object(
            Bucket=bucket,
            Key=key,
            Body=content.encode('utf-8'),
            ContentType='text/plain; charset=utf-8',
            ServerSideEncryption='AES256',  # Encrypt at rest
            Metadata={
                'source': 'aws-transcribe-pipeline',
                'format': 'clean-text'
            }
        )
        logger.info(f"Uploaded clean text to s3://{bucket}/{key}")
    except Exception as e:
        logger.error(f"Failed to upload text: {str(e)}")
        raise


# For local testing
if __name__ == "__main__":
    # Test with sample SRT content
    sample_srt = """1
00:00:00,000 --> 00:00:03,500
Welcome to the CCNA certification course.

2
00:00:03,500 --> 00:00:07,000
Today we'll cover network fundamentals.

3
00:00:07,000 --> 00:00:11,500
The OSI model has seven layers.
"""

    clean_text = parse_srt_to_text(sample_srt)
    print("Clean Text Output:")
    print(clean_text)
