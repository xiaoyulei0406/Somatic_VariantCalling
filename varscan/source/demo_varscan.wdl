import "pre_processing.wdl" as maptool
import "varscan.wdl" as varscantool

workflow WES {
	
	Array[Array[Array[File]]] sample_info
	Array[File] sample_name
	Array[String] sample_name_F
	Array[Array[String]] vs_list
	File Ref
	File knowsite1_bqsr_golden_indel
	File knowsite2_bqsr_phase1_SNPs
	File knowsite3_bqsr_dbsnp
	File dbsnp
	File hapmap
	File gnomad_vcf
	String? view_para
	File dbpath
	File ref_fasta
	File filter_vcf
	File vep_path
	scatter (i in range(length(sample_info))) {
		call maptool.mkdir_vs as mk_vs{
			input: dirName1=sample_info[i][0][0], dirName2=vs_list[i][1]
		}
		call maptool.mkdir_sample as mk_tumor {
			input: dirName1 = mk_vs.path, dirName2 = vs_list[i][0]
		}
		call maptool.mkdir_sample as mk_normal {
			input: dirName1 = mk_vs.path, dirName2 = vs_list[i][1]
		}

		call maptool.bwa_mem as bwa_tumor {
			input: sample_info = sample_info[i][0], sample_name_flag = vs_list[i][0], Ref_file = Ref, outdir = mk_tumor.path
		}
		call maptool.bwa_mem as bwa_normal {
			input: sample_info = sample_info[i][1], sample_name_flag = vs_list[i][1], Ref_file = Ref, outdir = mk_normal.path
		}
		call maptool.samtobam as stb_tumor {
			input: sam = bwa_tumor.sam, para = view_para
		}
		call maptool.samtobam as stb_normal {
			input: sam = bwa_normal.sam, para = view_para
		}
		call maptool.sortbam as sort_tumor {
			input: bam = stb_tumor.outbam
		}
		call maptool.sortbam as sort_normal {
			input: bam = stb_normal.outbam
		}
		call maptool.markdup as dup_tumor {	
			input: bam = sort_tumor.outbam
		}
		call maptool.markdup as dup_normal {
			input: bam = sort_normal.outbam
		}
		call maptool.bqsr as bqsr_tumor {
			input: bam = dup_tumor.outbam, Ref_file = Ref, knowsite1 = knowsite1_bqsr_golden_indel, knowsite2 = knowsite2_bqsr_phase1_SNPs, knowsite3 = knowsite3_bqsr_dbsnp
		}
		call maptool.bqsr as bqsr_normal {
			input: bam = dup_normal.outbam, Ref_file = Ref, knowsite1 = knowsite1_bqsr_golden_indel, knowsite2 = knowsite2_bqsr_phase1_SNPs, knowsite3 = knowsite3_bqsr_dbsnp
		}
		call maptool.applybqsr as map_tumor {
			input: bam = dup_tumor.outbam, Ref_file = Ref, bqsr = bqsr_tumor.bqsr
		}
		call maptool.applybqsr as map_normal {
			input: bam = dup_normal.outbam, Ref_file = Ref, bqsr = bqsr_normal.bqsr
		}
		call varscantool.pileup as t_pileup {
			input: bam = map_tumor.outbam, Ref_file = Ref 
		}
		call varscantool.pileup as n_pileup {
			input: bam = map_normal.outbam, Ref_file = Ref
		}
		call varscantool.varscan_somatic as v_somatic {
			input: n_pileup = n_pileup.pileup, t_pileup = t_pileup.pileup, sample_name = sample_name_F[i]
		}
#		call varscantool.varscan_processSomatic  as v_prosomatic {
#			input: indel = v_somatic.indel, snp = v_somatic.snp, sample_name = sample_name_F[i]
#		}
		call varscantool.vcfcombine as combine {
			input: hc_Somatic_indel = v_somatic.hc_Somatic_indel, hc_Somatic_snp = v_somatic.hc_Somatic_snp,  sample_name = sample_name_F[i]
		}
		call varscantool.annovar as anno {
			input: vcf = combine.vcf, sample_name = sample_name_F[i], dbpath = dbpath
		}
		call varscantool.vcf2maf as v2m {
			input: vcf = combine.vcf, sample_name = sample_name_F[i], ref_fasta = ref_fasta, filter_vcf = filter_vcf, vep_path = vep_path
		}

	}
}
