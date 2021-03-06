#!/usr/bin/env Rscript


# Author: Tomas Bencomo
# R script to analyze gene expression data produced by HTSeq-count.
# Final step of the rna-pipeline
# Meant to be run after all HTSeq-count jobs have finished for a given collection of samples
# Script performs the following:
# 1) Checks if DESeq2 installed - if not, installs it
# 2) Parse command line to get the directory of the counts data, the list of sample conditions, and the directory to write output
# 3) Analyze RNA expression and write 3 output files:
# 	-Unfiltered output list with all data
#	-Filtered down-regulated file, filtered by pvalue <= .05
#	-Filtered up-regulated file, filted by pvalue <= .05
#
#
# Additionally, this script parses the names of the files in the counts directory to determine if the file is a Tumor or Normal sample. 
# As of now, it distinguishes by the following pattern: 'NS' or 'ctrl' is Normal and 'SC' or 'scc' is Tumor. 

#Packages - DESeq2, AnnotationDbi, org.Hs.eg.db, dplyr, stringr,tximport

#Install CRAN packages
list.of.packages <- c("dplyr", "stringr")
new.packages <- list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)

#install Bioconductor packages
source("https://bioconductor.org/biocLite.R")
list.of.pacakges <- c("DESeq2", "AnnotationDbi", "org.Hs.eg.db", "tximport")
new.packages <- list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) biocLite(new.packages)

require(DESeq2)
require(AnnotationDbi)
require(org.Hs.eg.db)
require(dplyr)
require(stringr)
require("tximport")

#Args we are expecting
# --countsDir directory with htseq counts files
# --sampleTypes list of sample conditions separated spaces
# --resultsDir directory to output results

args = commandArgs(trailingOnly=TRUE)

countsDir <- args[match("--countsDir", args) + 1]
directory <- countsDir

sampleFiles <- grep("*.genes.results*", list.files(directory), value=TRUE)
print(sampleFiles)


#determine which samples are tumors vs normal based on filename
sampleTypes <- c()
for(file in sampleFiles) {
        if(str_detect(file, 'NS') | str_detect(file, 'ctrl') | str_detect(file, 'CTR')) {
                sampleTypes <- c(sampleTypes, "Normal")
        } else {
                sampleTypes <- c(sampleTypes, "Tumor")
        }
}

#check to make sure the filepath is correct syntactically, so we can append to sample names to get read in files for tximport
if(substr(countsDir, nchar(countsDir), nchar(countsDir)) != '/') {
        countsDir <- paste(countsDir, '/', sep="")
}

#get sample names
names(sampleFiles) <- sapply(sampleFiles, function(x) substr(x, 0, str_locate(x, '.genes.results')[1]-1))

#correct filenames to include full path
sampleFiles <- sapply(sampleFiles, function(x) paste(countsDir, x, sep=""))

#set up tximport object
txi.rsem <- tximport(sampleFiles, type = 'rsem', txIn = FALSE, txOut = FALSE)
#head(txi.rsem$counts)
#tail(txi.rsem$counts)

txi.rsem$length[txi.rsem$length == 0] <- 1

sampleTable <- data.frame(condition = sampleTypes)
rownames(sampleTable) <- colnames(txi.rsem$counts)
#sampleTable


dds <- DESeqDataSetFromTximport(txi.rsem, sampleTable, ~condition)
#dds
dds <- DESeq(dds)
#quit()


#sampleCondition <- sampleTypes

resultsDir = args[match("--resultsDir", args) + 1]
setwd(resultsDir)

#sampleTable <- data.frame(sampleName = sampleFiles, fileName = sampleFiles, condition = sampleCondition)


res <- results(dds)
res <- data.frame(res)
res$gene_id <- rownames(res)
res <- res %>% filter(grepl('ENSG', gene_id))

gene_ids <- res$gene_id
gene_id_no_isoforms <- sapply(gene_ids, substr, 0, which(strsplit(gene_ids, "")[[1]]==".")-1)

res$ENSEMBL_CODE <- gene_id_no_isoforms
res$symbol <- mapIds(org.Hs.eg.db, keys=res$ENSEMBL_CODE, column="SYMBOL", keytype = "ENSEMBL", multiVals = "first")

sum(res$pvalue < .05, na.rm = TRUE)
sum(res$padj < .05, na.rm = TRUE)

print("Minimum pvalues, first for pvalue and then for padj")

min(res$pvalue, na.rm = TRUE)
min(res$padj, na.rm = TRUE)



#Analysis finished. Filter and save results
#First, write to csv file an unfiltered output list
resOrdered <- res[order(res$padj), ]
resOrdered <- data.frame(resOrdered)
resOrdered <- resOrdered[, c(8, 7, 9, 1, 2, 3, 4, 5, 6)]
write.csv(as.data.frame(resOrdered), file='unfiltered_normal_tumor_results.csv', row.names = FALSE)

#Now write upregulated file with padj <= .05
upregulated <- filter(resOrdered, log2FoldChange > 0 & padj <= .05)
head(upregulated)
dim(upregulated)

#Next write downregulated file with padj <= .05
downregulated <- filter(resOrdered, log2FoldChange < 0 & padj <= .05)
head(downregulated)
dim(downregulated)
write.csv(downregulated, file = 'downregulated_genes.csv', row.names = FALSE)


