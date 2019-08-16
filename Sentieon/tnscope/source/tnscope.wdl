task variant_call_tn {
	File tumor_dedup_bam
	File normal_dedup_bam
	File tumor_recal_table
	File normal_recal_table
	String tumor_name
	String normal_name
	File Ref_file
	String dbsnp
	command <<<
		sentieon driver -t 10 -r ${Ref_file} \
		-i ${tumor_dedup_bam} -q ${tumor_recal_table} \
		-i ${normal_dedup_bam} -q ${normal_recal_table} \
		--algo TNscope \
		--tumor_sample ${tumor_name} \
		--normal_sample ${normal_name} --dbsnp ${dbsnp} \
		${tumor_name}_tn.vcf

	>>>
	output { 
		File tnvcf = "${tumor_name}_tn.vcf"
	}

	runtime {
		docker:"sentieon_eaglenebula:latest"
		cpu:"4"
		memory:"30G"
	}

	meta {
		author: "Chunlei Yu"
	}
}





