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
task co_realign {
	File tumor_recalibrate_bam
	File normal_recalibrate_bam
#	File tumor_recal_table
#	File normal_recal_table
	String knowsite1
	String knowsite2
	String knowsite3
	File Ref_file

	command {

		sentieon driver -t 10 -r ${Ref_file} -i ${tumor_recalibrate_bam} -i ${normal_recalibrate_bam} \
		--algo Realigner -k ${knowsite1} -k ${knowsite2} -k ${knowsite3} \
		${"corealgined_bam"}
	}
	output { 
		File corealgined_bam = "corealgined_bam"
	}

	runtime {
		docker:"sentieon_eaglenebula:latest"
		cpu:"4"
		memory:"30G"
	}

}
task variant_call_tn {
	File corealgined_bam
	String tumor_name
	String normal_name
	File Ref_file
	String dbsnp
#	String outdir
	command <<<
		sentieon driver -t 10 -r ${Ref_file} -i ${corealgined_bam} \
		--algo TNhaplotyper --tumor_sample ${tumor_name} \
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





