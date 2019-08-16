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
		cpu:"20"
		memory:"50G"
	}

	meta {
		author: "Chunlei Yu: First, run Mutect2 in tumor-only mode on each normal sample."
	}
}
task merge_arg {

	Array[File] normal1_vcf_list

	command {
		echo "${sep='\n' normal1_vcf_list}" > normal1_vcf_list.args
	#	print normal1_vcf_list.args
		java -jar /gatk/gatk.jar CreateSomaticPanelOfNormals \
		-vcfs normal1_vcf_list.args \
		-O merge_PoN.vcf
	#	java -jar /gatk/gatk.jar CreateSomaticPanelOfNormals \
	#	-vcfs ${sep=' -vcfs ' normal1_vcf_list.args} \
	#	-O ${"merge_PoN.vcf"}
	}

	runtime{
		docker:"gatk4/wd:latest"
		cpu:"4"
		memory:"30G"
	}
	output {
#		File args = "normal1_vcf_list.args"
		File vcf = "merge_PoN.vcf"	
}
	meta {
		author: "Chunlei Yu: Create a file ending with .args or .list extension with the paths to the VCFs from step 1, one per line. (refs: https://software.broadinstitute.org/gatk/documentation/tooldocs/4.0.5.0/org_broadinstitute_hellbender_tools_walkers_mutect_CreateSomaticPanelOfNormals.php)"
	}

}
task vm {
	String dirName

	command {
		mkdir ${dirName}
	}

	output {
		File path = "${dirName}"
	}
}

task mutect_short_var {
	File tumor_bam
	File normal_bam
	String gnomad_vcf
	String sample_name
	String Ref_file
	File merge_PoN
	String outdir
	command {
		java -jar /gatk/gatk.jar Mutect2 \
		-R ${Ref_file} \
		-I ${tumor_bam} \
		-I ${normal_bam} \
		-tumor ${sample_name}_tumor \
		-normal ${sample_name}_normal \
		-pon ${merge_PoN} \
		--germline-resource ${gnomad_vcf} \
		--af-of-alleles-not-in-resource 0.0000025 \
		--disable-read-filter MateOnSameContigOrNoMappedMateReadFilter \
		-O ${outdir + "/" + "somatic_m2.vcf"} \
		-bamout ${outdir + "/" + "tumor_normal_m2.bam"}
	}
	output { 
		File vcf = "${outdir}/somatic_m2.vcf"
		File bam = "${outdir}/tumor_normal_m2.bam"
	}

	runtime{
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
	String outdir
	String gnomad_vcf

	command {
		java -jar /gatk/gatk.jar GetPileupSummaries \
		-I ${tumor_bam} \
		-V ${gnomad_vcf} \
		-O ${outdir + "/" + sample_name + ".getpileupsummaries.table"}
	}

	output { 
		File table = "${outdir}/${sample_name}.getpileupsummaries.table"
	}

	runtime{
		docker:"gatk4/wd:latest"
		cpu:"10"
		memory:"50G"
	}
	meta {
		author: "Chunlei Yu: run GetPileupSummaries on the tumor BAM to summarize read support for a set number of known variant sites"
	}
}

task CalculateContamination {
	File table
	String outdir
	String sample_name

	command {
		java -jar /gatk/gatk.jar CalculateContamination \
		-I ${table} \
		-O ${outdir + "/" + sample_name + ".calculatecontamination.table"}
	}

	output {
		File table = "${outdir}/${sample_name}.calculatecontamination.table"
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
	String outdir
	String sample_name

	command {
		java -jar /gatk/gatk.jar -V ${somatic_m2_vcf} \
		--contamination-table ${calculatecontamination_table} \
		-O ${outdir + "/" + sample_name + "somatic_oncefiltered.vcf"}
	}

	output {
		File vcf = "${outdir}/${sample_name}.somatic_oncefiltered.vcf"
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


