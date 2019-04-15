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

task strelkasomatic {
	File normal_bam
	File tumor_bam
	File Ref_file
	String outprefix
	String tmpDIR = "strelkaTMP_" + outprefix

	command <<<
		mkdir ${tmpDIR}

		/opt/bin/configureStrelkaSomaticWorkflow.py \
		--normalBam ${normal_bam} --tumorBam ${tumor_bam} \
		--referenceFasta ${Ref_file} \
		--runDir ${tmpDIR}

		${tmpDIR}/runWorkflow.py -m local -j 10
		mv ${tmpDIR}/results/variants/somatic.snvs.vcf.gz ${outprefix}.strelka.somatic.snvs.vcf.gz
		mv ${tmpDIR}/results/variants/somatic.indels.vcf.gz ${outprefix}.strelka.somatic.indels.vcf.gz

	>>>

	runtime {
		docker: "strelka:v1"
		cpu:"2"
		memorty:"20G"
	}

	output {
		File SNVs = "${outprefix}.strelka.somatic.snvs.vcf.gz"
		File InDels = "${outprefix}.strelka.somatic.indels.vcf.gz"
	}
}

task strelkaGermline {
	Array[File] normal_bams
	File Ref_file
	String outprefix
	String tmpDIR = "strelkaTMP_" + outprefix 

	command <<<
		/opt/bin/configureStrelkaGermlineWorkflow.py \
		--bam ${sep=" --bam " normal_bams} \
		--ref ${Ref_file} \
		--runDir ${tmpDIR}

		${tmpDIR}/runWorkflow.py -m local -j 10
		mv ${tmpDIR}/results/variants/variants.vcf.gz ${outprefix}.strelka.germline.vcf.gz
		mv ${tmpDIR}/results/variants/genome.S1.vcf.gz ${outprefix}.strelka.genome.germline.gvcf.gz
	>>>
	runtime {
		docker: "strelka:v1"
		cpu:"2"
		memorty:"20G"
	}

	output {
		File strelkaGermlineVCF = "${outprefix}.strelka.germline.vcf.gz"
	}
}

task annovar {

	File vcf
	String dbpath
	String sample_name

	command {
		perl /BioBin/annovar/table_annovar.pl ${vcf} ${dbpath} -buildver hg19 -thread 5 -otherinfo -nastring . -protocol refGene,dbnsfp30a,clinvar_20170905,avsnp150,esp6500siv2_all  -operation g,f,f,f,f -nastring . -vcfinput --argument ',-score_threshold 0.01 -reverse,,,-score_threshold 0.01 -reverse' --outfile ${sample_name + ".annovar"} --gff3dbfile hg19_rmsk.gff
	}

	runtime {
		docker:"annovar:latest"
		cpu:"2"
		memory:"10G"
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
