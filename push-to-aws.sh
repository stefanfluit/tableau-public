#!/usr/bin/env bash

# Author: Stefan Fluit (Forked from github.com/ryantbrown)
# Target: Push backup to AWS S3

# Set Bash behaviour
set -o errexit    # Exit on uncaught errors
set -o pipefail   # Fail pipe on first error

# Set AWS credentials and S3 paramters
declare AWS_KEY=""
declare AWS_SECRET=""
declare S3_BUCKET=""
declare S3_BUCKET_PATH="/"
declare S3_ACL="x-amz-acl:private"
declare path=$1

s3Upload() {
  local path=$1
  local file=$2
  local date=$(date +"%a, %d %b %Y %T %z")
  local content_type="application/octet-stream"
  local sig_string="PUT\n\n${content_type}\n${date}\n${S3_ACL}\n/${S3_BUCKET}${S3_BUCKET_PATH}${file}"
  local signature=$(echo -en "${sig_string}" | openssl sha1 -hmac "${AWS_SECRET}" -binary | base64)

  curl -X PUT -T "$path/$file" \
    -H "Host: ${S3_BUCKET}" \
    -H "Date: ${date}" \
    -H "Content-Type: ${content_type}" \
    -H "${S3_ACL}" \
    -H "Authorization: AWS ${AWS_KEY}:${signature}" \
    "https://${S3_BUCKET}${S3_BUCKET_PATH}${file}"
}

# loop through the path and upload the files
Loop_push(){
  for file in "$path"/*; do
    s3Upload "$path" "${file##*/}" "/"
  done
}

main() {
  printf "Starting backup\n"
  Loop_push && printf "Done\n"
}

main
