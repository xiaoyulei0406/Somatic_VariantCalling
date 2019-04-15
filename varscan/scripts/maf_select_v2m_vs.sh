#每行以\t分割的记录NR>3
maf = $1
sample_name = $2

awk 'BEGIN { FS="\t"; OFS="\t" }; {if (NR>3 && $1 !="Unknown") {print $1,$5,$6,$7,$9,$10,$11,$13}}' ${maf} >${sample_name}.maf.select.txt

###
#Hugo_Symbol	Chromosome	Start_Position	End_Position	Variant_Classification	Variant_Type	Reference_Allele	Tumor_Seq_Allele2
#AL627309.1	1	133129	133129	3'Flank	SNP	G	A
#FAM132A	1	1178763	1178763	Intron	SNP	G	A
#TTC34	1	2585589	2585589	Intron	SNP	G	T
