import "pre_processing.wdl" as maptasks
import "strelka.wdl" as strelkatasks
workflow strelka {
	
	Array[Array[Array[File]]] sample_info
	Array[String] sample_name
	Array[Array[String]] vs_list
	File Ref
	String? view_para

	scatter (i in range(length(sample_info))) {
		call maptasks.mkdir_vs as mk_vs{
			input: dirName1=sample_info[i][0][0], dirName2=vs_list[i][1]
		}
		call maptasks.mkdir_sample as mk_tumor {
			input: dirName1 = mk_vs.path, dirName2 = vs_list[i][0]
		}
		call maptasks.mkdir_sample as mk_normal {
			input: dirName1 = mk_vs.path, dirName2 = vs_list[i][1]
		}

		call maptasks.bwa_mem as bwa_tumor {
			input: sample_info = sample_info[i][0], sample_name_flag = vs_list[i][0], Ref_file = Ref, outdir = mk_tumor.path
		}
		call maptasks.bwa_mem as bwa_normal {
			input: sample_info = sample_info[i][1], sample_name_flag = vs_list[i][1], Ref_file = Ref, outdir = mk_normal.path
		}
		call maptasks.samtobam as stb_tumor {
			input: sam = bwa_tumor.sam, para = view_para
		}
		call maptasks.samtobam as stb_normal {
			input: sam = bwa_normal.sam, para = view_para
		}
		call maptasks.sortbam as sort_tumor {
			input: bam = stb_tumor.outbam
		}
		call maptasks.sortbam as sort_normal {
			input: bam = stb_normal.outbam
		}
		call maptasks.markdup as dup_tumor {	
			input: bam = sort_tumor.outbam
		}
		call maptasks.markdup as dup_normal {
			input: bam = sort_normal.outbam
		}
		call maptasks.markdup_bai as markdup_bai_t {
			input: bam = dup_tumor.outbam
		}
		call maptasks.markdup_bai as markdup_bai_n {
			input: bam = dup_normal.outbam
		}
		call strelkatasks.strelkasomatic as strelkasomatic {
			input: tumor_bam = dup_tumor.outbam, normal_bam=dup_normal.outbam, Ref_file = Ref, outprefix = sample_name[i] 
		}
	}

	call strelkatasks.strelkaGermline as strelkaGermline {
		input: normal_bams=dup_normal.outbam, Ref_file = Ref, outprefix = "JC"
	}
}
