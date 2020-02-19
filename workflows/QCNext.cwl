#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: Workflow

requirements:
  - class: SubworkflowFeatureRequirement

inputs:
  reference: Directory
  fastqfile: File
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

  textfile:
    type: File
    outputSource: PeaksQC/textfile

  readqc_zip:
    outputSource: ReadQC/zipfile
    type: File

  readqc_html:
    outputSource: ReadQC/htmlfile
    type: File


steps:
  BasicMetrics:
    requirements:
      ResourceRequirement:
        ramMax: 20000
        coresMin: 1
    in: 
      fastqfile: fastqfile
    out: [metrics_out]
    run: ../tools/basicfastqstats.cwl

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

  Bowtie:
    requirements:
      ResourceRequirement:
        ramMax: 10000
        coresMin: 5
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
    out: [outfile]
    run: ../tools/samtools-index.cwl

  SamRMDup:
    in:
      infile: BkList/outfile
    out: [outfile]
    run: ../tools/samtools-mkdupr.cwl

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

  MACS:
    requirements:
      ResourceRequirement:
        ramMax: 10000
        coresMin: 1
    in:
      treatmentfile: BkIndex/outfile
      space: space
      pvalue: pvalue
      wiggle: wiggle
      single_profile: single_profile
    out: [ peaksbedfile, peaksxlsfile, summitsfile, wigfile, macsDir ]
    run: ../tools/macs1call.cwl

  Bklist2Bed:
    in:
      infile: BkIndex/outfile
    out: [ outfile ]
    run: ../tools/bamtobed.cwl

  SortBed:
    requirements:
      ResourceRequirement:
        ramMax: 10000
        coresMin: 1
    in:
      infile: Bklist2Bed/outfile
    out: [outfile]
    run: ../tools/sortbed.cwl

  runSPP:
    requirements:
      ResourceRequirement:
        ramMax: 10000
        coresMin: 1
    in:
      infile: BkIndex/outfile
    out: [spp_out]
    run: ../tools/runSPP.cwl

  CountIntersectBed:
    in:
      peaksbed: MACS/peaksbedfile
      bamtobed: SortBed/outfile
    out: [outfile]
    run: ../tools/intersectbed.cwl

  PeaksQC:
    requirements:
      ResourceRequirement:
        ramMax: 10000
        coresMin: 1
    in:
      fastqmetrics: BasicMetrics/metrics_out
      fastqczip: ReadQC/zipfile
      sppfile: runSPP/spp_out
      bambed: Bklist2Bed/outfile
      countsfile: CountIntersectBed/outfile
      peaksxls: MACS/peaksxlsfile
      bamflag: STATbam/outfile
      rmdupflag: STATrmdup/outfile
      bkflag: STATbk/outfile
    out: [ statsfile, htmlfile, textfile ]
    run: ../tools/summarystatsv2.cwl
