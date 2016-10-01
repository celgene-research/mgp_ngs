#!/bin/bash

scriptDir=$( dirname $0 );
i=$1


$scriptDir/../RNA-Seq/10.bsub.STAR-human.sh  $i
$scriptDir/../RNA-Seq/12.bsub.bowtie-ERCC.sh $i
$scriptDir/../RNA-Seq/84.express-bowtie.sh $i
$scriptDir/../RNA-Seq/86.bsub.sailfish.sh

