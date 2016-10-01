#!/bin/bash

scriptDir=$( dirname $0 );
i=$1


$scriptDir/../RNA-Seq/40.bsub.htseqCount.sh  $i

