library(optparse)
library(VariantAnnotation)
suppressMessages(suppressWarnings(require(optparse, quietly=TRUE)))

option_list = list(
  make_option(c("-i", "--input"),  type = "character", default = NULL,  help = "Input vcf file"),
  make_option(c("-o", "--output"), type = "character", default = "vars.maflite",  help = "Output MAFLITE")
)

parseobj = OptionParser(option_list=option_list)
opt = parse_args(parseobj)
#print(opt)
print(opt$input)

if (is.null(opt$input))
  stop(print_help(parseobj))

print('...loading VariantAnnotation package')
suppressMessages(suppressWarnings(require(VariantAnnotation, quietly=TRUE)))

print('...reading VCF')
vcf <- readVcf(opt$input, "hg19")

nalt <- elementNROWS(alt(vcf))
onealt <- nalt==1
vcf <- vcf[onealt,]

inf <- info(vcf)
rR <- rowRanges(vcf)
tab <- data.frame(chr=as.character(seqnames(rR)), startr=start(rR), end=end(rR), ref=as.character(rR$REF), alt=as.character(unlist(alt(vcf))), stringsAsFactors=FALSE)

del = sapply(tab$ref, nchar)  > sapply(tab$alt, nchar)
ins = sapply(tab$ref, nchar)  < sapply(tab$alt, nchar)

tab$alt[del] = "-"
tab$ref[ins] = "-"
#tab <- cbind(tab, inf[, c("DP", "ECNT")])
##set name for output maflite
names(tab) <- c("chr","start","end","ref_allele","alt_allele")
write.table(tab, file=opt$output, quote=FALSE, sep="\t", row.names=FALSE)

