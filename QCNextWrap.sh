#!/usr/bin/sh
#To RUN
#bsub -P watcher -q compbio -J wrap -o wrap_out -e wrap_err -N ./QCNextWrap.sh <folder_path>

#Modified to allow for multiple files

numberoffile=0
folderlocation=$1
#"/research/dept/cmpb/genomicsLab/runs/NovaSeq/191007_A00641_0103_AHG3YMDRXX/Data/Intensities/BaseCalls/3D_Genome_Consortium_Baker"
NEW_UUID=${NEW_UUID:=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 6 | head -n 1)}
ffran="fastqfileran-$NEW_UUID.txt"
WRAPPERSCRIPT="$(pwd)/ToilQCNext.sh"
finaloutput="AllOutputFromFolder-$NEW_UUID.txt"
finalfolder="FinalFolder-$NEW_UUID"

echo $numberoffile > $ffran
echo "Working on Location: "$folderlocation > $ffran

#Parsing each file
mkdir -p ymls-$NEW_UUID
#mkdir -p FinalOutput-$NEW_UUID

for eachfile in $(ls -1 $folderlocation/*gz)
do 
count=10 #number of jobs submitted
jobcheck=$(bjobs -w | grep $NEW_UUID | wc -l)

while [ $jobcheck -gt $count ]; do
jobcheck=$(bjobs -w | grep $NEW_UUID | wc -l)
sleep 2m
done

while [ $jobcheck -le $count ]; do

echo "Processing this file: $eachfile"
numberoffile=$(echo "$numberoffile+1" | bc)
cp preparameters.yml ymls-$NEW_UUID/inputyml$numberoffile.yml
echo "  path: $eachfile" >> ymls-$NEW_UUID/inputyml$numberoffile.yml
echo "$numberoffile.  $eachfile" >> $ffran
echo "bsub -R "rusage[mem=10000]" -P watcher -q compbio -J $NEW_UUID-qcwrap$numberoffile -o $NEW_UUID-qc-out$numberoffile -e $NEW_UUID-qc-err$numberoffile -N $WRAPPERSCRIPT ymls-$NEW_UUID/inputyml$numberoffile.yml"
bsub -R "rusage[mem=10000]" -P watcher -q compbio -J $NEW_UUID-qcwrap$numberoffile -o $NEW_UUID-qc-out$numberoffile -e $NEW_UUID-qc-err$numberoffile -N $WRAPPERSCRIPT ymls-$NEW_UUID/inputyml$numberoffile.yml
break
jobcheck=$(bjobs -w | grep $NEW_UUID | wc -l)
done

done

#parsing all the stats files
jobcheck=$(bjobs -w | grep $NEW_UUID | wc -l)

while [ $jobcheck != 0 ]; do
jobcheck=$(bjobs -w | grep $NEW_UUID | wc -l)
done

if [ $jobcheck == 0 ]; 
then

mkdir -p $finalfolder
for eachfile in $(ls -1 $folderlocation/*gz)
do

NEWFOLDER=${eachfile##*/}
echo $NEWFOLDER
NEWFOLDER=${NEWFOLDER%.fastq.*}
header=$(head -n 1 $NEWFOLDER/*stats.txt)
tail -n 1 $NEWFOLDER/*stats.txt >> $finaloutput.temp
mv $NEWFOLDER $finalfolder/
done

echo $header > $finaloutput
cat $finaloutput.temp >> $finaloutput
rm -rf $finaloutput.temp
mv $NEW_UUID-qc-* $finalfolder/

echo "Text file for all results are found in: $finaloutput"
echo "Output folders are in: $finalfolder"

fi

