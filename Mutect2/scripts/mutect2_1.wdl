task mkdir_variant {

	String dirName

	command {
		mkdir ${dirName}
	}

	output {
		File path = "${dirName}"
	}
}

task mkdir_merge {

	String dirName1

	command {
		mkdir ${dirName1}
	}

	output {
		File path = "${dirName1}"
	}
}

task PoN_per_sample {
	
	File normal_bam
	String sample_name
	String Ref_file
	String outdir

	command {
		java -jar /gatk/gatk.jar Mutect2 \
		-R ${Ref_file} \
		-I ${normal_bam} \
		-tumor ${sample_name} \
		--disable-read-filter MateOnSameContigOrNoMappedMateReadFilter \
		-O ${outdir + "/" + sample_name + "." + "normal1.vcf"}
	}

	output {
		File vcf = "${outdir}/${sample_name}.normal1.vcf"
	}

	runtime{
		docker:"gatk4/wd:latest"
		cpu:"4"
		memory:"30G"
	}

	meta {
		author: "Chunlei Yu: First, run Mutect2 in tumor-only mode on each normal sample."
	}
}
task merge_pon {
	Array[File] vcfs
	String outdir
	command <<<
		java -jar /gatk/gatk.jar CreateSomaticPanelOfNormals \
		-vcfs ${sep=" -vcfs " vcfs} \
		-O ${outdir + "/" + "merge_PoN.vcf"}

		echo '${outdir + "/" + "merge_PoN.vcf"}'
	>>>

	runtime{
		docker:"gatk4/wd:latest"
		cpu:"4"
		memory:"30G"
	}
	output {
		#File vcf = "${outdir}/merge_PoN.vcf"
		File vcf = stdout()
	}
	meta {
		author: "Chunlei Yu: Create a file ending with .args or .list extension with the paths to the VCFs from step 1, one per line. (refs: https://software.broadinstitute.org/gatk/documentation/tooldocs/4.0.5.0/org_broadinstitute_hellbender_tools_walkers_mutect_CreateSomaticPanelOfNormals.php)"
	}
}

task mutect_short_var {
	File tumor_bam
	File normal_bam
	File gnomad_vcf
	String tumor_name
	String normal_name
	File Ref_file
	File merge_PoN
#	String outdir
	command <<<
		java -jar /gatk/gatk.jar GetSampleName -R ${Ref_file} -I ${tumor_bam} -O tumor_name.txt -encode
		tumor_command_line="-I ${tumor_bam} -tumor `cat tumor_name.txt`"

		java -jar /gatk/gatk.jar GetSampleName -R ${Ref_file} -I ${normal_bam} -O normal_name.txt -encode
		normal_command_line="-I ${normal_bam} -normal `cat normal_name.txt`"

		java -jar /gatk/gatk.jar Mutect2 \
		-R ${Ref_file} \
		$tumor_command_line \
		$normal_command_line \
		-pon ${merge_PoN} \
		--germline-resource ${gnomad_vcf} \
		--af-of-alleles-not-in-resource 0.0000025 \
		--disable-read-filter MateOnSameContigOrNoMappedMateReadFilter \
		-O ${"somatic_m2.vcf"} \
		-bamout ${"tumor_normal_m2.bam"}
	>>>
	output { 
		File vcf = "somatic_m2.vcf"
		File bam = "tumor_normal_m2.bam"
	}

	runtime {
		docker:"gatk4/wd:latest"
		cpu:"4"
		memory:"30G"
	}

	meta {
		author: "Chunlei Yu"
	}
}

task getPipleupSummaries {
	File tumor_bam
	String sample_name
#	String outdir
	File variants_for_contamination

	command {
		java -jar /gatk/gatk.jar GetPileupSummaries \
		-I ${tumor_bam} \
		-V ${variants_for_contamination} \
		-O ${sample_name + ".getpileupsummaries.table"}
	}

	output { 
		File table = "${sample_name}.getpileupsummaries.table"
	}

	runtime{
		docker:"gatk4/wd:latest"
		cpu:"4"
		memory:"30G"
	}
	meta {
		author: "Chunlei Yu: run GetPileupSummaries on the tumor BAM to summarize read support for a set number of known variant sites"
	}
}

task CalculateContamination {
	File table
#	String outdir
	String sample_name

	command {
		java -jar /gatk/gatk.jar CalculateContamination \
		-I ${table} \
		-O ${sample_name + ".calculatecontamination.table"}
	}

	output {
		File table = "${sample_name}.calculatecontamination.table"
	}

	runtime{
		docker:"gatk4/wd:latest"
		cpu:"4"
		memory:"30G"
	}
	meta {
		author: "Chunlei Yu: estimate contamination with CalculateContamination."
	}

}

task FilterMutectCalls {
	File somatic_m2_vcf
	File calculatecontamination_table
#	String outdir
	String sample_name

	command {
		java -jar /gatk/gatk.jar FilterMutectCalls -V ${somatic_m2_vcf} \
		--contamination-table ${calculatecontamination_table} \
		-O ${sample_name + ".somatic_oncefiltered.vcf"}
	}

	output {
		File vcf = "${sample_name}.somatic_oncefiltered.vcf"
	}

	runtime{
		docker:"gatk4/wd:latest"
		cpu:"4"
		memory:"30G"
	}
	meta {
		author: "Chunlei Yu: Filter the Mutect2 callset with FilterMutectCalls."
	}
}
task count_pass_once {
	File vcf
	String sample_name

	command <<<
#		cat ${vcf} | grep -v '^#' > ${sample_name + ".pass_oncefilterd.txt"}
#
#		cat ${vcf} | grep -v '#' | awk '$7=="PASS"' >> ${sample_name + ".pass_oncefilterd.txt"}
#
#		cat ${vcf} | grep -v '#' | awk '$7=="PASS"' | wc -l > ${sample_name + ".count_pass_oncefilterd"}
		pass_oncefilterd = "pass_oncefilterd.txt"
		cat ${vcf} | grep -v '^#' > $pass_oncefilterd

		cat ${vcf} | grep -v '#' | awk '$7=="PASS"' >> $pass_oncefilterd
		count_pass_oncefilterd = "count_pass_oncefilterd.txt"
		cat ${vcf} | grep -v '#' | awk '$7=="PASS"' | wc -l > $count_pass_oncefilterd
	>>>
#	runtime{
#		docker:"bwa:base"
#		cpu:"4"
#		memory:"30G"
#	}
	output {
#		File pass_oncefilterd = "${sample_name}.pass_oncefilterd.txt"
#		File count = "{sample_name}.count_pass_oncefilterd"
		File pass_once = "pass_oncefilterd.txt"
		File count = "count_pass_oncefilterd.txt"

	}
}

task CollectSequencingArtifactMetrics {
	File bam
	String sample_name
	String Ref_file

	command <<<
		java -jar /gatk/gatk.jar CollectSequencingArtifactMetrics -I ${bam} \
		-O ${sample_name + ".tumor_artifact"} \
		--FILE_EXTENSION ".txt" \
		-R ${Ref_file}
	>>>
	output {
		File pre_adapter_detail = "${sample_name}.tumor_artifact.pre_adapter_detail_metrics.txt"
	}

	runtime{
		docker:"gatk4/wd:latest"
		cpu:"4"
		memory:"30G"
	}
	meta {
		author: "Chunlei Yu: Collect metrics on sequence context artifacts with CollectSequencingArtifactMetrics"
	}

}

task FilterByOrientationBias {
	File vcf
	String sample_name
	File txt

	command {
		java -jar /gatk/gatk.jar FilterByOrientationBias \
		-AM G/T \
		-AM C/T \
		-V ${vcf} \
		-P ${txt} \
		-O ${sample_name + ".twicefilterd.vcf"}
	}

	output {
		File vcf ="${sample_name}.twicefilterd.vcf"
	}

	runtime{
		docker:"gatk4/wd:latest"
		cpu:"4"
		memory:"30G"
	}
	meta {
		author: "Chunlei Yu: Filter the Mutect2 callset with FilterByOrientationBias."
	}
}
task count_pass_twice {
	File vcf
	String sample_name

	command {
		sh /opt/hard_filerd.sh ${vcf} ${sample_name}
	}

	runtime{
		docker:"shscript:v1"
		cpu:"4"
		memory:"10G"
	}
	output {

		File pass_twicefilterd = "${sample_name}_pass_oncefilterd.vcf"
	}
}


