#!/bin/bash
echo "This script updates the working copy of the pipeline"
echo " and related libraries."
echo "Run this script after you have used a version control system (git,svn)"
echo " to download an updated copy of the pipeline"
echo "NOTE 1: this script has nothing to do with puppet and its tasks"
echo "NOTE 2: this script assumes that the working copy is in /celgene/software/"
echo "Example: cd ~/ngs; git pull; bash update.sh"

# script that updates the running copy of the pipeline with the contents of this version
scriptDir=$( dirname $0 );
DD=/celgene/software
BIN=/celgene/software/bin


rsync -avq --recursive $scriptDir/scripts_for_LSF/ ${DD}/scripts_for_LSF/
rsync -avq --recursive $scriptDir/NGS-pipeline/ ${DD}/NGS-pipeline/
rsync -avq --recursive $scriptDir/oodt/ ${DD}/oodt/
rsync -avq --recursive $scriptDir/Celgene/ ${DD}/perl/lib/perl5/Celgene/



chmod -R ug+rwx $DD/scripts_for_LSF/; chmod -R g-w $DD/scripts_for_LSF/; chmod -R o-rx $DD/scripts_for_LSF/

for i in `find $DD/NGS-pipeline/  | grep pl$`; do chmod 755 $i; ln -s  $i $BIN/$(basename $i); done
for i in `find $DD/NGS-pipeline/  | grep sh$`; do chmod 755 $i; ln -s $i $BIN/$(basename $i)  ; done
for i in `find $DD/NGS-pipeline/  | grep R$`; do chmod 755 $i; done
for i in `find $DD/oodt/  | grep sh$`; do chmod 755 $i; ln -s $i $BIN/$(basename $i)  ; done