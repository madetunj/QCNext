#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: Workflow

requirements:
  - class: SubworkflowFeatureRequirement
  - class: ScatterFeatureRequirement

inputs:
  reference: Directory
  fastqfile: File[]
  blacklistfile: File
  best_alignments: boolean?
  good_alignments: int?
  limit_alignments: int?
  processors: int?

  # MACS
  wiggle: boolean?
  single_profile: boolean?
  space: int?
  pvalue: string?


outputs:
  statsfile:
    type: File
    outputSource: PeaksQC/statsfile

  htmlfile:
    type: File
    outputSource: PeaksQC/htmlfile

  macsDir:
    type: Directory
    outputSource: MACS-Auto/macsDir

  sam_sort:
    outputSource: SamSort/outfile
    type: File

  fastq_metrics:
    outputSource: BasicMetrics/metrics_out
    type: File

  rmdup_bam:
    outputSource: SamRMDup/outfile
    type: File

  rmdup_index:
    outputSource: SamIndex/outfile
    type: File

  bklist_bam:
    outputSource: BkList/outfile
    type: File

  bklist_index: 
    outputSource: BkIndex/outfile
    type: File

  readqc_zip:
    outputSource: ReadQC/zipfile
    type: File

  readqc_html:
    outputSource: ReadQC/htmlfile
    type: File

  statsfile:
    type: File
    outputSource: PeaksQC/statsfile

  htmlfile:
    type: File
    outputSource: PeaksQC/htmlfile    
    
steps:
  BasicMetrics:
    in: 
      fastqfile: fastqfile
    out: [metrics_out]
    run: ../tools/basicfastqstats.cwl
    scatter: fastqfile

  TagLen:
    in: 
      datafile: BasicMetrics/metrics_out
    out: [tagLength]
    run: ../tools/taglength.cwl
   
  ReadQC:
    in:
      infile: fastqfile
    out: [htmlfile, zipfile]
    run: ../tools/fastqc.cwl
    scatter: infile

  Bowtie:
    run: ../tools/bowtie.cwl
    in:
      readLengthFile: TagLen/tagLength
      best_alignments: best_alignments
      good_alignments: good_alignments
      fastqfile: fastqfile
      limit_alignments: limit_alignments
      processors: processors
      reference: reference
    out: [samfile]
    scatter: fastqfile

  SamView:
    in:
      infile: Bowtie/samfile
    out: [outfile]
    run: ../tools/samtools-view.cwl

  SamSort:
    in:
      infile: SamView/outfile
    out: [outfile]
    run: ../tools/samtools-sort.cwl

  BkList:
    in:
      infile: SamSort/outfile
      blacklistfile: blacklistfile
    out: [outfile]
    run: ../tools/blacklist.cwl

  BkIndex:
    in:
      infile: BkList/outfile
    out: [bam2file, outfile]
    run: ../tools/samtools-index.cwl

  SamRMDup:
    in:
      infile: BkList/outfile
    out: [outfile]
    run: ../tools/samtools-mkdupr.cwl

  SamIndex:
    in:
      infile: SamRMDup/outfile
    out: [bam2file, outfile]
    run: ../tools/samtools-index.cwl

  STATbam:
    in:
      infile: SamView/outfile
    out: [outfile]
    run: ../tools/samtools-flagstat.cwl

  STATrmdup:
    in:
      infile: SamRMDup/outfile
    out: [outfile]
    run: ../tools/samtools-flagstat.cwl

  STATbk:
    in:
      infile: BkList/outfile
    out: [outfile]
    run: ../tools/samtools-flagstat.cwl

  MACS-Auto:
    in:
      treatmentfile: BkIndex/bam2file
      space: space
      pvalue: pvalue
      wiggle: wiggle
      single_profile: single_profile
    out: [ peaksbedfile, peaksxlsfile, summitsfile, wigfile, macsDir ]
    run: ../tools/macs1call.cwl

  PeaksQC:
    in:
      fastqmetrics: BasicMetrics/metrics_out
      fastqczip: ReadQC/zipfile
      bamfile: BkList/outfile
      peaksbed: MACS-Auto/peaksbedfile
      peaksxls: MACS-Auto/peaksxlsfile
      bamflag: STATbam/outfile
      rmdupflag: STATrmdup/outfile
      bkflag: STATbk/outfile
    out: [ statsfile, htmlfile ]
    run: ../tools/summarystats.cwl
