#!/bin/bash


scriptDir=$( dirname $0 );
i=$1


$scriptDir/../bin/32.bsub.bamQC-BamIndex.sh $i
$scriptDir/../bin/33.bsub.bamQC-CollectAlnMetrics.sh $i
$scriptDir/../bin/34.bsub.bamQC-InsertSizeMetrics.sh $i
$scriptDir/../bin/35.bsub.bamQC-CollectRNASeqMetrics.sh $i
$scriptDir/../bin/36.bsub.bamQC-MarkDuplicates.sh $i
$scriptDir/../bin/37.bsub.bamQC-LibraryComplexity.sh $i