#!/bin/bash


scriptDir=$( dirname $0 );
i=$1


$scriptDir/../QC/03.bsub.fastqQC.sh $i
$scriptDir/../QC/04.bsub.LaneDistribution.sh $i
$scriptDir/../QC/05.bsub.CutAdapt.sh $i