import "typical_usage_DNAseq.wdl" as maptool
import "variant_calling.wdl" as mu
workflow WES {
	
	Array[Array[Array[File]]] sample_info
	Array[String] sample_name
	Array[Array[String]] vs_list
	File Ref
	File knowsite1_bqsr_golden_indel
	File knowsite2_bqsr_phase1_SNPs
	File knowsite3_bqsr_dbsnp
	File dbsnp

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
			input: sample_info = sample_info[i][0], sample_name_flag = vs_list[i][0], Ref_file = Ref, outdir = mk_tumor.path, rg = vs_list[i][0]
		}
		call maptool.bwa_mem as bwa_normal {
			input: sample_info = sample_info[i][1], sample_name_flag = vs_list[i][1], Ref_file = Ref, outdir = mk_normal.path, rg = vs_list[i][1]
		}
		call maptool.metrics as metrics_t {
			input: bam = bwa_tumor.bam, Ref_file = Ref
		}
		call maptool.metrics as metrics_n {
			input: bam = bwa_normal.bam, Ref_file = Ref
		}
		call maptool.plot_metrics as plot_metrics_t {
			input: gc=metrics_t.gc, mq=metrics_t.mq, qd = metrics_t.qd, is = metrics_t.is
		}
		call maptool.plot_metrics as plot_metrics_n {
			input: gc=metrics_n.gc, mq=metrics_n.mq, qd = metrics_n.qd, is = metrics_n.is
		}
		call maptool.markdup as dup_tumor {	
			input: bam = bwa_tumor.bam
		}
		call maptool.markdup as dup_normal {
			input: bam = bwa_normal.bam
		}
		call maptool.bqsr as bqsr_tumor {
			input: bam = dup_tumor.bam, Ref_file = Ref, knowsite1 = knowsite1_bqsr_golden_indel, knowsite2 = knowsite2_bqsr_phase1_SNPs, knowsite3 = knowsite3_bqsr_dbsnp
		}
		call maptool.bqsr as bqsr_normal {
			input: bam = dup_normal.bam, Ref_file = Ref, knowsite1 = knowsite1_bqsr_golden_indel, knowsite2 = knowsite2_bqsr_phase1_SNPs, knowsite3 = knowsite3_bqsr_dbsnp
		}
		call mu.co_realign as co_realign {
			input: tumor_recalibrate_bam = bqsr_tumor.bam, normal_recalibrate_bam=bqsr_normal.bam, Ref_file = Ref, knowsite1 = knowsite1_bqsr_golden_indel, knowsite2 = knowsite2_bqsr_phase1_SNPs, knowsite3 = knowsite3_bqsr_dbsnp
		}
		call mu.variant_call_tn as mu_tn {
			input: corealgined_bam = co_realign.corealgined_bam, tumor_name = vs_list[i][0], normal_name = vs_list[i][1],  Ref_file = Ref, dbsnp = dbsnp
		}

	}
}
