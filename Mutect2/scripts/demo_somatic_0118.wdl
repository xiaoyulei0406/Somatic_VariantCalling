import "pre_processing.wdl" as maptool
import "mutect2_1.wdl" as mu
import "anno_oncotator.wdl" as anno
workflow WES {
	
	Array[Array[Array[File]]] sample_info
	Array[String] sample_name
	Array[Array[String]] vs_list
	File Ref
	File knowsite1_bqsr_golden_indel
	File knowsite2_bqsr_phase1_SNPs
	File knowsite3_bqsr_dbsnp
	File dbsnp
	File hapmap
	File gnomad_vcf
	File variants_for_contamination
	File merge_pon_vcf
	File dbpath
	String? view_para
	File oncodb
	File tx

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
		call mu.mutect_short_var as mu_var {
			input: tumor_bam = map_tumor.outbam, normal_bam=map_normal.outbam, gnomad_vcf = gnomad_vcf, tumor_name = sample_info[i][0][0], normal_name = sample_info[i][1][0],  Ref_file = Ref, merge_PoN = merge_pon_vcf
		}
		call mu.getPipleupSummaries as pileup {
			input: tumor_bam = map_tumor.outbam, sample_name = sample_name[i], variants_for_contamination = variants_for_contamination
		}
		call mu.CalculateContamination as cal_contamination {
			input: table = pileup.table, sample_name = sample_name[i]
		}
		call mu.FilterMutectCalls as filteronce {
			input: somatic_m2_vcf = mu_var.vcf, calculatecontamination_table = cal_contamination.table, sample_name = sample_name[i]
		}
#		call mu.count_pass_once as count_pass_once {
#			input: vcf = filteronce.vcf, sample_name = sample_name[i]
#		}
		call mu.CollectSequencingArtifactMetrics as collectseq {
			input: bam = map_tumor.outbam, sample_name = sample_name[i], Ref_file = Ref
		}
		call mu.FilterByOrientationBias as filtertwice {
			input: vcf = filteronce.vcf, sample_name = sample_name[i], txt = collectseq.pre_adapter_detail
		}
		call mu.count_pass_twice as count_pass_twice {
			input:vcf = filtertwice.vcf, sample_name = sample_name[i]
		}
		call anno.vcf2maflite  {
			input: vcf = count_pass_twice.pass_twicefilterd, sample_name = sample_name[i]
		}
		call anno.oncotator {
			input: maflite = vcf2maflite.maflite, sample_name = sample_name[i], oncodb = oncodb, tx = tx
		}

	}
}
