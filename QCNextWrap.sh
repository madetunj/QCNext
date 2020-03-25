#!/usr/bin/sh
#To RUN
#bsub -P watcher -q compbio -J wrap -o wrap_out -e wrap_err -N ./QCNextWrap.sh <folder_path>

#Modified to allow for multiple files

numberoffile=0
folderlocation=$1
#"/research/dept/cmpb/genomicsLab/runs/NovaSeq/191007_A00641_0103_AHG3YMDRXX/Data/Intensities/BaseCalls/3D_Genome_Consortium_Baker"
NEW_UUID=${NEW_UUID:=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 6 | head -n 1)}
ffran="fastqfileran-$NEW_UUID.txt"
WRAPPERSCRIPT="$(pwd)/QCNext.sh"
finaloutput="AllOutputFromFolder-$NEW_UUID.txt"
finalfolder="FinalFolder-$NEW_UUID"

echo $numberoffile > $ffran
echo "Working on Location: "$folderlocation > $ffran

#Parsing each file
mkdir -p ymls
mkdir -p FinalOutput

for eachfile in $(ls -1 $folderlocation/*gz)
do 
count=2
jobcheck=$(bjobs -w | grep $NEW_UUID | wc -l)

while [ $jobcheck -gt $count ]; do
jobcheck=$(bjobs -w | grep $NEW_UUID | wc -l)
sleep 2m
done

while [ $jobcheck -le $count ]; do

echo "Processing this file: $eachfile"
numberoffile=$(echo "$numberoffile+1" | bc)
cp preparameters.yml ymls/inputyml$numberoffile.yml
echo "  path: $eachfile" >> ymls/inputyml$numberoffile.yml
echo "$numberoffile.  $eachfile" >> $ffran
echo "bsub -R "rusage[mem=10000]" -P watcher -q compbio -J $NEW_UUID-qcwrap$numberoffile -o qc-out$numberoffile -e qc-err$numberoffile -N $WRAPPERSCRIPT ymls/inputyml$numberoffile.yml"
bsub -R "rusage[mem=10000]" -P watcher -q compbio -J $NEW_UUID-qcwrap$numberoffile -o qc-out$numberoffile -e qc-err$numberoffile -N $WRAPPERSCRIPT ymls/inputyml$numberoffile.yml

jobcheck=$(bjobs -w | grep $NEW_UUID | wc -l)
done

done

#parsing all the stats files
for eachfile in $(ls -1 $folderlocation/*gz)
do 
NEWFOLDER=${eachfile##*/}
print $NEWFOLDER
NEWFOLDER=${NEWFOLDER%.*.*}
header=$(head -n 1 $NEWFOLDER/*stats.txt)
results=$results"\n"$(tail -n 1 $NEWFOLDER/*stats.txt)
mv $NEWFOLDER $finalfolder/
done

echo $header > $finaloutput
echo -e $results | tail -n +2 >> $finaloutput

echo "Text file for all results are found in: $finaloutput"
echo "Output folders are in: $finalfolder"
