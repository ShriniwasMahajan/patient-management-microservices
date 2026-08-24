#!/bin/bash

set -e # Stops the script if any command fails

aws cloudformation delete-stack --stack-name patient-management

aws cloudformation deploy --stack-name=patient-management --template-file "./cdk.out/localstack.template.json"

aws elbv2 describe-load-balancers --query "LoadBalancers[0].DNSName" --output-text