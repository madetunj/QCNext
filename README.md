# Subset of ChromatinSE-pipeline for QC metrics in Dr. Easton's lab.

### To execute wrapper script
	 bsub -R "rusage[mem=10000]" -P watcher -q compbio -J qc-cwl -o qc-cwl_out -e qc-cwl_err -N ./QCNext.sh 

#### NOTE: Change location parameter to the current working directory

### To execute CWL workflow
	 cwlexec -p -w tmpdir -o outdir -c config.file -p workflows/QCNext.sh parameter-qcnext.yml 1>log_out 2>log_err 
	 
