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
    type: File[]
    outputSource: PeaksQC/statsfile

  htmlfile:
    type: File[]
    outputSource: PeaksQC/htmlfile

  textfile:
    type: File[]
    outputSource: PeaksQC/textfile

  readqc_zip:
    outputSource: ReadQC/zipfile
    type: File[]

  readqc_html:
    outputSource: ReadQC/htmlfile
    type: File[]


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
    scatter: fastqfile

  TagLen:
    in: 
      datafile: BasicMetrics/metrics_out
    out: [tagLength]
    run: ../tools/taglength.cwl
    scatter: datafile
   
  ReadQC:
    in:
      infile: fastqfile
    out: [htmlfile, zipfile]
    run: ../tools/fastqc.cwl
    scatter: infile

  Bowtie:
    requirements:
      ResourceRequirement:
        ramMax: 10000
        coresMin: 20
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
    scatter: [readLengthFile, fastqfile]
    scatterMethod: dotproduct

  SamView:
    in:
      infile: Bowtie/samfile
    out: [outfile]
    run: ../tools/samtools-view.cwl
    scatter: infile

  SamSort:
    in:
      infile: SamView/outfile
    out: [outfile]
    run: ../tools/samtools-sort.cwl
    scatter: infile

  BkList:
    in:
      infile: SamSort/outfile
      blacklistfile: blacklistfile
    out: [outfile]
    run: ../tools/blacklist.cwl
    scatter: infile

  BkIndex:
    in:
      infile: BkList/outfile
    out: [outfile]
    run: ../tools/samtools-index.cwl
    scatter: infile

  SamRMDup:
    in:
      infile: BkList/outfile
    out: [outfile]
    run: ../tools/samtools-mkdupr.cwl
    scatter: infile

  STATbam:
    in:
      infile: SamView/outfile
    out: [outfile]
    run: ../tools/samtools-flagstat.cwl
    scatter: infile

  STATrmdup:
    in:
      infile: SamRMDup/outfile
    out: [outfile]
    run: ../tools/samtools-flagstat.cwl
    scatter: infile

  STATbk:
    in:
      infile: BkList/outfile
    out: [outfile]
    run: ../tools/samtools-flagstat.cwl
    scatter: infile

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
    scatter: treatmentfile

  Bklist2Bed:
    in:
      infile: BkIndex/outfile
    out: [ outfile ]
    run: ../tools/bamtobed.cwl
    scatter: infile

  SortBed:
    requirements:
      ResourceRequirement:
        ramMax: 10000
        coresMin: 1
    in:
      infile: Bklist2Bed/outfile
    out: [outfile]
    run: ../tools/sortbed.cwl
    scatter: infile

  runSPP:
    requirements:
      ResourceRequirement:
        ramMax: 10000
        coresMin: 1
    in:
      infile: BkIndex/outfile
    out: [spp_out]
    run: ../tools/runSPP.cwl
    scatter: infile

  CountIntersectBed:
    requirements:
      ResourceRequirement:
        ramMax: 10000
        coresMin: 1
    in:
      peaksbed: MACS/peaksbedfile
      bamtobed: SortBed/outfile
    out: [outfile]
    run: ../tools/intersectbed.cwl
    scatter: [peaksbed, bamtobed]
    scatterMethod: dotproduct

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
    scatter: [fastqmetrics, fastqczip, sppfile, bambed, countsfile, peaksxls, bamflag, rmdupflag, bkflag]
    scatterMethod: dotproduct
