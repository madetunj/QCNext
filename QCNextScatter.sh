#!/usr/bin/bash
#------
###SYNTAX to run
#bsub -R "rusage[mem=10000]" -P watcher -q compbio -J scatter_qc -o scatter_out -e scatter_err -N ./QCNextScatter.sh <folder location>
#bsub -R "rusage[mem=10000]" -P watcher -q compbio -J scatter_qc -o scatter_out -e scatter_err -N ./QCNextScatter.sh /research/dept/cmpb/genomicsLab/runs/NovaSeq/191007_A00641_0103_AHG3YMDRXX/Data/Intensities/BaseCalls/3D_Genome_Consortium_Baker
####

#------
###FILES
#------
#location of cwlfiles, change path to current working directory
location="/research/rgs01/project_space/zhanggrp/MethodDevelopment/common/modupe-qc-easton"

#template parameters file
preparameters="$location/prescatterparameters.yml"

#folderlocation
if [ $# -lt 1 ]; then
  echo ""
  echo 1>&2 Usage $0 ["fastqfiles folder"]
  echo ""
  exit 1
fi
folderlocation=$1

#CWL workflow
script="$location/workflows/QCNextScatter.cwl"

#temporary id tag
NEW_UUID=${NEW_UUID:=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 5 | head -n 1)"_"`date +%s`}

#temporary output & error files
out="$(pwd)/qcscatter-"$NEW_UUID"-outdir"
tmp="$(pwd)/qcscatter-"$NEW_UUID"-tmpdir"
logout="qcscatter-"$NEW_UUID"-outfile_out"
logerr="qcscatter-"$NEW_UUID"-outfile_err"
jobstore="qcscatter-"$NEW_UUID"-jobstore"
logtxt="qcscatter-"$NEW_UUID"-log.txt"

#finaloutput file
finaloutput="finaloutput-"$NEW_UUID".txt"

#creating the parameters file
numberoffile=0
parameters="parameter-"$NEW_UUID".yml"
cp -rf $preparameters $parameters
echo >> $parameters
echo "fastqfile:" >> $parameters
for eachfile in $(ls -1 $folderlocation/*gz)
do 
numberoffile=$(echo "$numberoffile+1" | bc)
echo "  - { class: File, path: $eachfile }" >> $parameters
done

#------
###Modules & PATH update
#------
module load node
module load fastqc/0.11.5
module load bowtie/1.2.2
module load samtools/1.9
module load macs/041014
module load R/3.6.1
module load bedtools/2.25.0
module load bedops/2.4.2
module load java/1.8.0_60

export R_LIBS_USER=$R_LIBS_USER:$location/R
export PATH=$PATH:$location/scripts

#------
###WORKFLOW
#------
##cwlexec 1st step
echo "STATUS:  Temporary files named with $NEW_UUID"
mkdir -p $tmp $out

rm -rf $jobstore $logtxt
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


# if workflow is sucessful, output specific files to specified folder
if [ -s $logout ]
then
  cat $out/*stats.txt | head -n 1 > $finaloutput
  header=$(cat $out/*stats.txt | head -n 1)
  cat $out/*stats.txt | grep -v "$header" >> $finaloutput

  echo "All $numberoffile fastq results can be found in: $finaloutput"
  echo "Output files are in : $out"

  echo "STATUS:  Complete"
else
  echo "ERROR:   Workflow failed"
fi
