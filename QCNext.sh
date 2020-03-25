#!/usr/bin/env bash
#------
###SYNTAX to run
#bsub -R "rusage[mem=10000]" -P watcher -q compbio -J qc-cwl -o qc-cwl_out -e qc-cwl_err -N ./QCNext.sh
####

#------
###FILES
#------
#location of cwlfiles, change path to current working directory
location=$(pwd)

#configuration file
config="$location/LSFqc.json"

#input parameters yml file
parameterfile=$1
parameterfile=${parameterfile:=parameter-qcnext.yml}
parameters="$location/$parameterfile"

#CWL workflow
script="$location/workflows/QCNext.cwl"

#temporary id tag
NEW_UUID=${NEW_UUID:=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 5 | head -n 1)"_"`date +%s`}

#temporary output & error files
out="$(pwd)/qcnext-"$NEW_UUID"-outdir"
tmp="$(pwd)/qcnext-"$NEW_UUID"-tmpdir"
logout="qcnext-"$NEW_UUID"-outfile_out"
logerr="qcnext-"$NEW_UUID"-outfile_err"

#------
###Modules & PATH update
#------
module load /rgs01/project_space/zhanggrp/MethodDevelopment/common/CWL/modulefiles/cwlexec/latest
module load node
module load fastqc/0.11.5
module load bowtie/1.2.2
module unload samtools
module load samtools/1.9
module load macs/041014
module load R/3.6.1
module load bedtools/2.25.0
module load bedops/2.4.2
module load java/1.8.0_60

export PATH=$PATH:$location/scripts
export R_LIBS_USER=$R_LIBS_USER:$location/R #to find SPP local package

#------
###WORKFLOW
#------
##cwlexec 1st step
echo "STATUS:  Temporary files named with $NEW_UUID"
mkdir -p $tmp $out
cwlexec -p -w $tmp -o $out -c $config -p $script $parameters 1>$logout 2>$logerr

#optional step
# if workflow is sucessful, output specific files to specified folder
if [ -s $logout ]
then
  qcsummary.pl -i $logout
  rm -rf *$NEW_UUID*
  echo "UPDATE:  Completed $NEW_UUID"
else
  echo "ERROR:   Workflow failed"
fi
