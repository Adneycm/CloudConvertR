#!/bin/bash

# AWS access key
read -p "Enter your AWS access key: " aws_access_key
export AWS_ACCESS_KEY_ID="$aws_access_key"

# AWS secret key
read -p "Enter your AWS secret key: " aws_secret_key
export AWS_SECRET_ACCESS_KEY="$aws_secret_key"

# Email notification
read -p "Enter your email: " email
export TF_VAR_email=$email

