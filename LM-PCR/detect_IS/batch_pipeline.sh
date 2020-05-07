#!/usr/bin/env bash

#this script depends on the following environments and programs:
#Ubuntu (18.04.4 LTS)
#python2 (v2.7.17)
#cutadapt (v1.15)
#BWA (v0.7.17-r1188)
#bedtools (v2.27.0)
#samtools (v1.7)


#Removing the adaptor sequence with cutadapt
cutadapt -m 1 \
  -b GATCGGAAGAGCGGTTCAGCAGGAATGCCGAGACCG \
  -O 5 \
  test_data/test_R1.fastq \
  -o test_data/test_R1.cutadapt.fastq

#Extracting a read1 with "ViralEndSeq (i.e., TAGCA)" and excluding the ViralEndSeq and its upstream sequence from the read1
python2 programs/read_trimer.py \
  test_data/test_R1.cutadapt.fastq \
  TAGCA \
  test_data/test_R1.cutadapt.noVirus.fastq

#Extracting a sequence flagment with a read that satisfy the following criteria:
# number of N <=6
# read length >=20
# >=80% of bases are with >=20 quality score

python2 programs/fastqCleaner.py \
       test_data/test_R1.cutadapt.noVirus.fastq \
       test_data/test_R2.fastq \
       test_data/test_R1.clean.fastq \
       test_data/test_R2.clean.fastq

#Mapping read1 and read2 to the human reference sequence with the hiv-1 sequence
bwa mem -t 4 \
        -M \
        /media/jampei/backup/HD-LCU3/Works_with_SatoYorifumi/LMPCR/fasta/hg19_with_hiv1.fa \
        test_data/test_R1.clean.fastq \
        test_data/test_R2.clean.fastq \
        > test_data/test.sam


#Removing secondary alignments, unmapped read pairs, and multi-mapped reads
#Removing reads mapped to the hiv-1 sequence
#Removing read pairs mapped to different chromosomes
#Removing read pairs mapped to distant genomic positions (>=1000bp)
samtools view -Sh -F 268 -q 10 test_data/test.sam | \
  awk '(($3!="hiv1_hxb2")&&($7=="=")&&(-1001<$9)&&($9<1001)||($1~/^@/)){print}' \
  > test_data/test.filtered.sam

#Removing a sequence flagment with a read1 that is mapped to the genomic position next to the "ViralEndSeq (i.e., TAGCA)" in the human reference genome
python2 programs/seqFinder.py \
  test_data/test.filtered.sam \
  /media/jampei/backup/HD-LCU3/Works_with_SatoYorifumi/LMPCR/fasta/hg19_with_hiv1.fa \
  TAGCA \
  > test_data/test.filtered.rm_hum_TAGCA.sam

#Extracting an unique pair of an integration site and a break point (i.e., share site)
python programs/unique_flagment.py \
  test_data/test.filtered.rm_hum_TAGCA.sam \
  20 \
  2 \
  > test_data/test.unique_IS.txt

#Counting the number of break points in each integration site
#Theoretically, the number of break points represents the clone size.
bash programs/count_cell.sh \
     test_data/test.unique_IS.txt \
     test_data/test.cell_count.txt


