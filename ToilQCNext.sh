#!/usr/bin/bash
#------
###SYNTAX to run
#bsub -R "rusage[mem=10000]" -P watcher -q compbio -J qc-toil -o qc-toil_out -e qc-toil_err -N ./ToilQCNext.sh
####

#------
###FILES
#------
#location of cwlfiles, change path to current working directory
location="/research/rgs01/project_space/zhanggrp/MethodDevelopment/common/modupe-qc-easton"

#input parameters yml file
parameterfile=$1
parameterfile=${parameterfile:=parameter-qcnext.yml}
parameters="$location/$parameterfile"

#CWL workflow
script="$location/workflows/QCNext.cwl"

#temporary id tag
NEW_UUID=${NEW_UUID:=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 5 | head -n 1)"_"`date +%s`}

#temporary output & error files
out="$(pwd)/qctoilnext-"$NEW_UUID"-outdir"
tmp="$(pwd)/qctoilnext-"$NEW_UUID"-tmpdir"
logout="qctoilnext-"$NEW_UUID"-log_out"
logerr="qctoilnext-"$NEW_UUID"-log_err"
jobstore="qctoilnext-"$NEW_UUID"-jobstore"
logtxt="qctoilnext-"$NEW_UUID"-log.txt"

#------
###Modules & PATH update
#------
module load /rgs01/project_space/zhanggrp/MethodDevelopment/common/CWL/modulefiles/cwlexec/latest
module load node
module load fastqc/0.11.5
module load bowtie/1.2.2
module load macs/041014
module load bedtools/2.25.0
module load bedops/2.4.2
module load java/1.8.0_60
module load R/3.6.1
module load samtools/1.9 #required

export PATH=$PATH:$location/scripts
export R_LIBS_USER=$R_LIBS_USER:$location/R #to find SPP local package

# which samtools

#------
###WORKFLOW
#------
##cwlexec 1st step
echo "STATUS:  Temporary files named with $NEW_UUID"
mkdir -p $tmp $out
#cwlexec -p -w $tmp -o $out -c $config -p $script $parameters 1>$logout 2>$logerr

toil-cwl-runner --batchSystem=lsf \
--preserve-entire-environment \
--disableCaching \
--logFile $logtxt \
--jobStore $jobstore \
--clean never \
--workDir $tmp \
--cleanWorkDir never \
--outdir $out \
$script $parameters 1>$logout 2>$logerr

# optional step
# if workflow is sucessful, output specific files to specified folder

if [ -s $logout ]
then
  qcsummary.pl -i $logout -toil
  rm -rf *$NEW_UUID*
  echo "UPDATE:  Completed $NEW_UUID"
else
  echo "ERROR:   Workflow failed"
fi
