#!/usr/bin/env bash

export AWS_ACCESS_KEY_ID=
export AWS_SECRET_ACCESS_KEY=
export AWS_SESSION_TOKEN=

aws iam create-user --user-name iamuser1
aws iam attach-user-policy --user-name iamuser1 --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
aws iam create-access-key --user-name iamuser1 

