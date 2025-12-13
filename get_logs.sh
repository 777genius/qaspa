#!/bin/bash
gh api repos/777genius/qaspa/actions/jobs/57976370842/logs 2>&1 | grep "91merror" | head -20
