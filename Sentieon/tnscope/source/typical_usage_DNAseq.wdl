task mkdir {

	String dirName

	command {
		mkdir ${dirName}
	}

	output {
		File path = "${dirName}"
	}
}

task mkdir_vs {

	String dirName1
	String dirName2

	command {
		mkdir ${dirName1 + "_vs_" + dirName2}
	}

	output {
		File path = "${dirName1}_vs_${dirName2}"
	}
}

task mkdir_sample {
	String dirName1
	String dirName2

	command {
		mkdir ${dirName1 + "/" + dirName2}
	}

	output {
		File path = "${dirName1}/${dirName2}"
	}
}

task mkdir_variant {
	String dirName1

	command {
		mkdir ${dirName1}
	}
}
task bwa_mem {

 	Array[File] sample_info
	String sample_name_flag
	String Ref_file
	String outdir
	String rg
			
	command {
		sentieon bwa mem -M -R '@RG\tID:${rg}\tLB:lib1\tPL:ILLUMINA\tSM:${sample_name_flag}\tPU:unit1' -t 24 ${Ref_file} ${sample_info[1]} ${sample_info[2]} | sentieon util sort -r ${Ref_file} -o ${outdir}/${sample_name_flag}.sorted.bam -t 10 --sam2bam -i -
	}
  
	output {
		File bam = "${outdir}/${sample_name_flag}.sorted.bam"
	}
  
	runtime{
		docker:"sentieon_eaglenebula:latest"
		cpu:"4"
		memory:"90G"
	}
}


task metrics {
	File bam
	File Ref_file

	command {
		sentieon driver -t 10 -r ${Ref_file} -i ${bam} \
		--algo GCBias --summary ${"GC_SUMMARY_TXT"} ${"GC_METRIC_TXT"} \
		--algo MeanQualityByCycle ${"MQ_METRIC_TXT"} \
		--algo QualDistribution ${"QD_METRIC_TXT"} \
		--algo InsertSizeMetricAlgo ${"IS_METRIC_TXT"} \
		--algo AlignmentStat ${"ALN_METRIC_TXT"}
	}

	output {
		File gc = "GC_METRIC_TXT"
		File mq = "MQ_METRIC_TXT"
		File qd = "QD_METRIC_TXT"
		File is = "IS_METRIC_TXT"
		File ALN_METRIC_TXT = "ALN_METRIC_TXT"
	}
 
	runtime{
		docker:"sentieon_eaglenebula:latest"
		cpu:"4"
		memory:"10G"
	}

}

task plot_metrics {
	File gc
	File mq
	File qd
	File is

	command <<<
		sentieon plot GCBias -o ${gc}.pdf ${gc}
		sentieon plot MeanQualityByCycle -o ${mq}.pdf ${mq}
		sentieon plot QualDistribution -o ${qd} ${qd}.pdf
		sentieon plot InsertSizeMetricAlgo -o ${is}.pdf ${is}
	>>>

	output {
		File GC_METRIC_PDF = "${gc}.pdf"
		File MQ_METRIC_PDF = "${mq}.pdf"
		File QD_METRIC_PDF = "${qd}.pdf"
		File IS_METRIC_PDF = "${is}.pdf"
	}
 
	runtime{
		docker:"sentieon_eaglenebula:latest"
		cpu:"4"
		memory:"10G"
	}
}

task markdup {
	
	File bam

	command <<<
		sentieon driver -t 10 -i ${bam} \
		--algo LocusCollector --fun score_info ${"SCORE.gz"}

		sentieon driver -t 10 -i ${bam} \
		--algo Dedup --rmdup --score_info ${"SCORE.gz"}  \
		--metrics ${"DEDUP_METRIC_TXT"} ${"DEDUP_BAM"}
	>>>

	output {
		File bam = "DEDUP_BAM"
		File outmetric = "DEDUP_METRIC_TXT"
	}

	runtime{
		docker:"sentieon_eaglenebula:latest"
		cpu:"4"
		memory:"50G"
	}
}

task bqsr {
	
	File bam
	String Ref_file
	String knowsite1
	String knowsite2
	String knowsite3

	command {
		sentieon driver -t 10 -r ${Ref_file} -i ${bam} \
		--algo QualCal -k ${knowsite1} -k ${knowsite2} -k ${knowsite3} ${"recal_data.table"}
		#--algo ReadWriter ${bam}.realign.bam

		sentieon driver -t 10 -r ${Ref_file} -i ${bam} \
		-q ${"recal_data.table"} --algo QualCal -k ${knowsite1} -k ${knowsite2} -k ${knowsite3} \
		${"RECAL_DATA.TABLE.POST"} --algo ReadWriter ${"RECALIBRATED_BAM"}
	}

	output {
		File recal_table = "recal_data.table"
		File bam = "RECALIBRATED_BAM"
	}
	
	runtime{
		docker:"sentieon_eaglenebula:latest"
		cpu:"4"
		memory:"50G"
	}
}



