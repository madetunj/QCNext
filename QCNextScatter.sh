#!/usr/bin/env bash
#------
###SYNTAX to run
#bsub -R "rusage[mem=10000]" -P watcher -q compbio -J qc-cwl -o qc-cwl_out -e qc-cwl_err -N ./QCNextScatter.sh
####

#------
###FILES
#------
location=$(pwd)
config="$location/LSFqc.json"
parameters="$location/parameter-qcnextscatter.yml"
firstscript="$location/workflows/QCNextScatter.cwl"
NEW_UUID=${NEW_UUID:=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 5 | head -n 1)"_"`date +%s`} #temporary file for the 2nd step

#temporary output & error files
out="$(pwd)/"$NEW_UUID"-outdir"
tmp="$(pwd)/"$NEW_UUID"-tmpdir"
logout="qcnext-"$NEW_UUID"-outfile_out"
logerr="qcnext-"$NEW_UUID"-outfile_err"

#------
###Modules & PATH update
#------
module load /rgs01/project_space/zhanggrp/MethodDevelopment/common/CWL/modulefiles/cwlexec/latest
module load node
module load fastqc/0.11.5
module load python/3.7.0
module load bowtie/1.2.2
module load samtools/1.9
module load macs/041014
module load R/3.6.1
module load bedtools/2.25.0
module load bedops/2.4.2
module load java/1.8.0_60
 
export PATH=$PATH:$location/scripts

#------
###WORKFLOW
#------
##cwlexec 1st step
echo "STATUS:  Temporary files named with $NEW_UUID"
mkdir -p $tmp $out
cwlexec -p -w $tmp -o $out -c $config -p $firstscript $parameters 1>$logout 2>$logerr
