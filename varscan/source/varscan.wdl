task mkdir_varscan {

	String dirName

	command {
		mkdir ${dirName}
	}

	output {
		File path = "${dirName}"
	}
}

task pileup {
	File Ref_file
	File bam
	command {
		/BioBin/samtools/samtools mpileup \
		-q 1 -f ${Ref_file} ${bam} > ${bam +".mpileup"}
	}
		output {
		File pileup = "${bam}.mpileup"
	}
	runtime {
		docker:"bwa:base"
		cpu:"10"
		memory:"50G"
	}
	meta {
		author: "Chunlei Yu: Genrate a file.pileup."
	}
}
task varscan_somatic {
	File n_pileup
	File t_pileup
	String sample_name
	command <<<
		java -jar /opt/VarScan.v2.3.9.jar somatic \
		${n_pileup} \
		${t_pileup} \
		${sample_name} \
		--min-coverage 8 \
		--min-coverage-normal 8 \
		--min-coverage-tumor 6 \
		--min-var-freq 0.1 \
		--min-avg-qual 15 \
		--strand-filter 1 \
		--p-value 0.99 \
		--somatic-p-value 0.05 \
		--output-vcf 1

		java -jar /opt/VarScan.v2.3.9.jar processSomatic ${sample_name + ".snp.vcf"}

		java -jar /opt/VarScan.v2.3.9.jar processSomatic ${sample_name + ".indel.vcf"}
	>>>
	output { 
		File snp = "${sample_name}.snp.vcf"
		File indel = "${sample_name}.indel.vcf"
		File indel_somatic_vcf = "${sample_name}.indel.Somatic.vcf"
		File snp_somatic_vcf = "${sample_name}.snp.Somatic.vcf"
		File indel_Germline_vcf = "${sample_name}.indel.Germline.vcf"
		File snp_Germline_vcf = "${sample_name}.snp.Germline.vcf"
		File indel_LOH_vcf = "${sample_name}.indel.LOH.vcf"
		File snp_LOH_vcf = "${sample_name}.snp.LOH.vcf"
		File hc_Somatic_indel = "${sample_name}.indel.Somatic.hc.vcf"
		File hc_Somatic_snp = "${sample_name}.snp.Somatic.hc.vcf"
		File hc_Germline_indel = "${sample_name}.indel.Germline.hc.vcf"
		File hc_Germline_snp = "${sample_name}.snp.Somatic.hc.vcf"
		File hc_LOH_indel = "${sample_name}.indel.LOH.hc.vcf"
		File hc_LOH_snp = "{sample_name}.snp.LOH.hc.vcf"

	}

	runtime {
		docker:"jbioi/varscan-2.3.9:latest"
		cpu:"4"
		memory:"30G"
	}

	meta {
		author: "Chunlei Yu"
	}
}

task vcfcombine {
	File hc_Somatic_indel
	File hc_Somatic_snp
	String sample_name
	command {
		vcfcombine ${hc_Somatic_snp} ${hc_Somatic_indel} > ${sample_name + "_combine.vcf"}
	}
	output { 
		File vcf = "${sample_name}_combine.vcf"
	}
	runtime {
		docker:"erictdawson/svdocker:latest"
		cpu:"4"
		memory:"30G"
	}

	meta {
		author: "Chunlei Yu"
	}
}

task annovar {

	File vcf
	String dbpath
	String sample_name

	command {
		perl /BioBin/annovar/table_annovar.pl ${vcf} ${dbpath} -buildver hg19 -thread 5 -otherinfo -nastring . -protocol refGene,dbnsfp30a,clinvar_20170905,avsnp150,esp6500siv2_all  -operation g,f,f,f,f -nastring . -vcfinput --argument ',-score_threshold 0.01 -reverse,,,-score_threshold 0.01 -reverse' --outfile ${sample_name + ".annovar"} --gff3dbfile hg19_rmsk.gff
	}

	runtime{
		docker:"annovar:latest"
		cpu:"5"
		memory:"20G"
	}
	meta {
		author: "Chunlei Yu"
	}
}

task vcf2maf {
	File vcf
	String sample_name
	File ref_fasta
	File filter_vcf
	File vep_path
	command {
		perl /opt/vcf2maf.pl --input-vcf ${vcf} --output-maf ${sample_name + ".maf"} \
		--vep-data ${vep_path} \
		--ref-fasta ${ref_fasta} --filter-vcf ${filter_vcf}
	}
	runtime {
		docker:"opengenomics/vcf2maf:latest"
		cpu:"2"
		memory:"5G"
	}
}