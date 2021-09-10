#!/bin/sh

#bash set environment variables for TF
export ARM_CLIENT_ID="client-id" 
export ARM_CLIENT_SECRET="secrets"
export ARM_TENANT_ID="tenant-id"
export ARM_SUBSCRIPTION_ID="sub-id"

#Get variables
env | grep ARM
