task vcf2maflite {
	File vcf
	String sample_name

	command {
		Rscript /usr/bin/vcf2maflite.r -i ${vcf} -o ${sample_name + "_pass.maflite"}
	}

	runtime {
		docker:"ycl/vcf2maflite:v2"
		cpu:"2"
		memory:"5G"
	}

	output {
		File maflite = "${sample_name}_pass.maflite"
	}
}

task oncotator {
	File maflite
	String sample_name
	File oncodb
	File tx

	command {
		oncotator -v --db-dir ${oncodb} \
		-c ${tx} \
		${maflite} ${sample_name + "_pass.maf"} hg19
	}

	runtime {
		docker:"ycl/oncotator:v1"
		cpu:"2"
		memory:"5G"
	}

	output {
		File maf = "${sample_name}_pass.maf"
	}
}

