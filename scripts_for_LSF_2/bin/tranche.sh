#!/bin/bash
scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh

input=$1

i=$(
grep VQSRTrancheBOTH99.00to99.90 $1 |\
rev |\
cut -f1 -d ' ' |\
rev |\
sed 's/">//'
)

echo $i
