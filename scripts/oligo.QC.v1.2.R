######################################
## Quality control analysis report of Microarray Data 


######################################
#load packages needed for oligo run
library("siggenes")
library("RColorBrewer")
library("multtest")
library("limma")
library("oligo")
library("genefilter")
library("gplots")
library("ggplot2")
library("dendextend")
library("statmod")
library("annotate")


######################################
#clean up
rm(list = ls(all = TRUE)) # clear all variables
graphics.off()
path <- getwd()
path


######################################
# create directories needed
dir.create("qc_results")
dir.create("qc_results/raw_data")
dir.create("qc_results/plots")
dir.create("qc_results/tables")
dir.create("qc_results/metadata")
dir.create("qc_results/final")
######################################


######################################
#check raw data
#put raw data (.cel files) raw data/
files = list.files(path,recursive = T, pattern = ".CEL")
for (i in files)
{
  cmd=paste("cp ", paste(i), " qc_results/raw_data/",sep="")
  system(cmd)
}

setwd(path)


######################################
#metadata table
m <- list.files(path, recursive = T, pattern = "sample_preparation")
for (i in m)
{
  cmd=paste("cp ", paste(i), " qc_results/metadata/",sep="")
  system(cmd)
}

m <- list.files("qc_results/metadata/")
m <- read.table(m,  header = T,sep = "\t",na.strings =c("","NaN"),quote=NULL,stringsAsFactors=F,dec=".",fill=TRUE)
# create a new column `x` with all the columns collapsed together
cols <- names(m)
m$x <- apply(m[ ,cols],1,paste, collapse = "-")
m$x <- gsub(" ","",m$x)

#use filename to create a vector of regexes
files <- list.files("qc_results/raw_data/",recursive = T, pattern = ".CEL")
files <- gsub(".CEL","",files)

m$xx <- 0
for (i in files) {
  ifelse(m[grepl(i, m$x), "xx"] <- i,0)
}
m <- subset(m, !xx == 0)
m$xx <- paste(m$xx,".CEL",sep="")
m$filenames <- m$xx
m$xx <- NULL
m$x <- NULL

write.table(m, "qc_results/metadata/metadata.txt",append = FALSE, quote = FALSE, sep = "\t",eol = "\n", na = "NA", dec = ".", row.names = F,  col.names = T, qmethod = c("escape", "double"))

setwd(path)


######################################
#Metadata preparation
pd = read.AnnotatedDataFrame("qc_results/metadata/metadata.txt", header = TRUE)
pd
row.names(pd) = pd[["filenames"]]
row.names(pd)


######################################
#load raw data with that additonal piece of information
setwd(path)
celFiles <- list.celfiles("qc_results/raw_data",full.names=T)
data <- read.celfiles(celFiles,phenoData = pd,verbose = T)  
#changed to filenames, more secure then sampleNames



######################################
#a check:
identical(sampleNames(data),row.names(pd))


#fit Probe Level Models (PLMs) with probe- level and sample-level parameters.
#The resulting object is an oligoPLM object, which stores parameter estimates, residuals and weights.
Pset <- fitProbeLevelModel(data)


##################
#Diagnostic plots and analysis
##################
####set-up color code####
grps <- as.character(pData(data)$treatment)
grps <- as.factor(grps)
grps
display.brewer.all()
col = brewer.pal(length(levels(grps)),"Set1")
col = c(c(col)[grps])
col



#1)Correlation analysis between the samples and their repeated measurements
cor <- cor(exprs(data), use = "everything",method = c("pearson"))
write.table(cor, "qc_results/tables/pearson_correlation_all_data.tsv", append = FALSE, quote = FALSE, sep = "\t",eol = "\n", na = "NA", dec = ".", row.names = T,  col.names = NA, qmethod = c("escape", "double"))
#use that for matrix eventually such as in the DESeq2 package for RNA-Seq experiments



#2)boxplot of raw log intensities
#Boxplots and histograms show the same differences in probe intensity behavior between arrays. In order to perform meaningful statistical analysis and inferences from the data, you need to ensure that all the samples are comparable. To examine and compare the overall distribution of log transformed PM intensities between the samples you can use a histogram but you will get a clearer view with a box plot. Box plots show:
## the median: center value, half of the intensities are lower than this value, half of the intensities are higher (= line in the box)
## the upper quartile: a quarter of the values are higher than this quartile (= upper border of the box)
## the lower quartile: a quarter of the values are lower than this quartile (= lower border of the box)
## the range: minimum and maximum value (= borders of the whiskers)
##individual extreme values (= points outside the whiskers)



pdf("qc_results/plots/Boxplot_raw_intensities.pdf")
par(oma=c(12,3,3,3))
par(mfrow = c(1,2))
boxplot(data, which='all', col=col,xlab="", main="", ylab="log2 signal intensity (PM+bg)", cex.axis=0.5, las=2)
legend("topright",col=levels(factor(col)),lwd=1,cex=0.5, legend=levels(grps))
boxplot(data, which='pm', col=col,xlab="", main="", ylab="log2 signal intensity (PM only)", cex.axis=0.5, las=2)
#boxplot(data, which='mm', col=col, xlab="", main="", ylab="log2 signal intensity (MM only)", cex.axis=0.5, las=2)
legend("topright",col=levels(factor(col)),lwd=1,cex=0.5, legend=levels(grps))
mtext("Visualization of raw data using Boxplots of log2 transformed intensity values. The Legend depicts colouring based on sample groups.\nPM=Perfect Match, bg=background", outer = T,side=1,cex=0.5,adj = 0)
dev.off()




#3)Pseudo chip images
#To produce a spatial image of probe log intensities and probe raw intensities
### Pseudo-image files
#Chip pseudo-images are very useful for detecting spatial differences (artifacts) on the invidual arrays (so not for comparing between arrays).

#chip file overview, does not work for oligo package this way????????
length = length(sampleNames(data))
length

# for (chip in 1:length){
#   png(paste("qc_results/plots/pseudo_image.", sampleNames(data)[chip], ".png", sep = ""))
#   image(data[,chip])
#   dev.off()
# }


#to check the positive and negative residuals:
# for (resid in 1:length){
#   png(paste("qc_results/plots/residual_image.", sampleNames(data)[resid], ".png", sep = ""))
#   par(mfrow = c(2,2))
#   image(Pset,which=resid,type="residuals",cex.main=0.8)
#   image(Pset,which=resid,type="pos.residuals",cex.main=0.8)
#   image(Pset,which=resid,type="neg.residuals",cex.main=0.8)
#   image(Pset,which=resid,type="sign.residuals",cex.main=0.8)
#   dev.off()
# }




#4)RLE and NUSE plots on dataset
#RLE:relative log expression
#NUSE:normalized unscaled standard error 
#In the NUSE plot, low-quality arrays are those that are significantly elevated or more spread out, relative to the other arrays. NUSE values are useful for comparing arrays within one dataset, but their magnitudes are not comparable across different datasets.
#In the RLE plot (Figure 3.3, bottom), problematic arrays are indicated by larger spread, by a center location different from y = 0, or both.

pdf("qc_results/plots/NUSE_plot.pdf")
par(oma=c(12,3,3,3)) 
NUSE(Pset, main="NUSE",ylim=c(0.5,2),outline=FALSE,col=col,las=2,cex.axis=0.5,ylab="Normalized Unscaled Error (NUSE) values",whisklty="dashed",staplelty=1,cex.axis=0.75)
dev.off()
pdf("qc_results/plots/RLE_plot.pdf")
par(oma=c(12,3,3,3)) 
RLE(Pset, main="RLE", ylim = c(-8, 8), outline = FALSE, col=col,las=2, cex.axis=0.5,ylab="Relative Log Expression (RLE) values",whisklty="dashed", staplelty=1,cex.axis=0.75)
dev.off()


#5)Histogram to compare log2 intensities vs density between arrays
#density plots of log base 2 intensities (log2(PMij) for array i and probe j) of perfect match probes for comparison of probe intensity behavior between different arrays. If you see differences in shape or center of the distributions, it means that normalization is required.
pdf("qc_results/plots/Histogramm_log2_intensities_vs_density.pdf")
hist(data,col = col, lty = 1, xlab="log2 intensity", ylab="density", xlim = c(2, 12), type="l")
legend("topright",col = col, lwd=1, legend=sampleNames(data),cex=0.5)
dev.off()



#6)MA plots raw data
#The MAplot also allows summarization, so groups can be compared more easily:

pdf("qc_results/plots/MA_plot_before_normalization_groups.pdf")
MAplot(data, pairs=TRUE, groups=grps,na.rm=TRUE)
dev.off()


#7) RNA degradation check, not yet possible with oligo package, maybe use xps package for this??
#pdf("out/RNA degradation plot.pdf")
#plotAffyRNAdeg(AffyRNAdeg(data), col=darkColors(59))
#legend(1,70, col=darkColors(59), lwd=1, legend=sampleNames(data),cex=0.75)
#dev.off()


#8)PCA plot before normalization
#You want to see which genes that mean the most for the differences between the samples, and therefore your samples should be in the rows and your genes should be in the columns.
#there t():
pca_before <- prcomp(t(exprs(data)), scores=TRUE, scale. = TRUE, cor=TRUE)
summary(pca_before)
# sqrt of eigenvalues
pca_before$sdev
#loadings
head(pca_before$rotation)
#PCs (aka scores)
head(pca_before$x)

# create data frame with scores
scores_before = as.data.frame(pca_before$x)
# plot of observations


#reorder grps just for pca plot
grps_pca <- grps

pdf("qc_results/plots/PCA_before_normalization.pdf")
ggplot(data = scores_before, aes(x = PC1, y = PC2,colour=grps_pca)) +
  geom_hline(yintercept = 0, colour = "gray65") +
  geom_vline(xintercept = 0, colour = "gray65") +
  #geom_text(colour = "black",label=sampleNames(data), size = 2,angle=40) +
  #scale_fill_manual(values=c("#E41A1C", "#377EB8", "#4DAF4A"), breaks=c("Parabel", "Simbox", "Texus"), labels=c("Parabel", "Simbox", "Texus")) +
  geom_point(aes(shape = factor(data$treatment)),size=2) + 
  #scale_colour_manual(values = c("#E41A1C","#377EB8", "#4DAF4A"))
  #scale_shape_manual(values=1:nlevels(col)) +
  theme(legend.title=element_blank()) +  ## turn off legend title
  ggtitle("PCA plot before normalization")
dev.off()


#Summary of QC analysis:
#clear grouping towards subjects thus Texus samples clearly separate from Simbox and parabel samples.
#also the 4 samples from Parabel are clearly different in the NUSE plot as well. But whiskers overlay.

#Something like this could be done here
#to remove low quality arrays do e.g.
#data
#lowQ = match("<sampleName>", sampleNames(data))
#data = data[, -lowQ]


setwd(path)



##################
#Data Normalization
##################
#some flexibility for rma and or gcRMA etc is needed. Be sure that oligo and affy are not loaded at the same time

#do something like this here if needed
# detach("package:affycoretools", unload=TRUE)
# detach("package:affy", unload=TRUE)

#as default do rma here....
eset <- rma(data)  #depending on chip such as ST chips, default used is target="core"
#should not use rma(target ="probeset") for the Gene ST arrays, because tons of the probesets only have one probe at that summarization level.
#just to check, in case of ST arrays
#dim(rma(data,target="probeset"))
#dim(rma(data,target="core"))

#eset=object of class ExpressionSet described in the Biobase vignette
#it does
#Background correcting
#Normalizing
#Calculating Expression

#Currently the rma function implements RMA in the following manner
#1. Probe specific correction of the PM probes using a model based on observed intensity being the sum of signal and noise
#2. Normalization of corrected PM probes using quantile normalization (Bolstad et al., 2003)
#3. Calculation of Expression measure using median polish.



##########################
#Quality plots
#########################
#when data analysis of actin and GAPDH expression as well as other control probes is needed see affy.masterv1.2_2.R script and work it in here.


#boxplot after normalization
pdf("qc_results/plots/Boxplot_after_normalization.pdf")
par(oma=c(10,2,2,2))
boxplot(exprs(eset), col=col,which='both', xlab="", main="", ylab="log2 signal intensity", cex.axis=0.4, las=2)
dev.off()

#Scatter matrix of arrays against one another
#png("out/Scatter plot after normalization.png")
#scatter <- pairs(exprs(eset), pch=".",main="Scatter plots", cex=0.5)
#dev.off()
#this plot indicate high or low correlation of the data. PCA and such as are useful to reduce complexity.

#MVA plots of arrays against one another (log-intensity vs log-ratio). A matrix of M vs. A plots is produced. Plots are made on the upper triangle and the IQR of the Ms are displayed in the lower triangle
#index <- which(eset[["treatment"]] == "g") 
#A <- rowMeans(exprs(eset[, index])) - rowMeans(exprs(eset[, -index]))
#M <- rowMeans(exprs(eset))

#pdf("out/MA plot after normalizationXXX.pdf")
#smoothScatter(M, A, ylab = "Average Log2 Intensity (M)", xlab = "Log2-ratio treatment(s) vs control (A)", main = "MA #plot after normalization")
#abline(h = c(-1,1))
#dev.off()


#The MAplot also allows summarization, so groups can be compared more easily:
pdf("qc_results/plots/MA_plot_after_normalization_groups.pdf")
MAplot(exprs(eset), pairs=TRUE, groups=grps)
dev.off()


#clustering
#for arrays, problem: arrays are not row names but at column position, thus transpose is needed
d <- dist(t(exprs(eset))) # find distance matrix
d
hc <- hclust(d)               # apply hierarchical clustering
#plot(hc)

dend <- as.dendrogram(hc)
#remember groups, assign a new color code
labels_colors(dend) <- col[order.dendrogram(dend)]
#colorCodes = c("red", "blue", "green")
pdf("qc_results/plots/Cluster_Dendogram.pdf")
par(oma=c(10,2,2,2))
dend %>% set("labels_cex",0.5) %>% plot()
legend("topright",col=levels(factor(col)),lwd=1,cex=0.5, legend=levels(grps))
dev.off()


#PCA after normalization
pca <- prcomp(t(exprs(eset)), scores=TRUE, cor=TRUE)

summary(pca)
# sqrt of eigenvalues
pca$sdev
#loadings
head(pca$rotation)
#PCs (aka scores)
head(pca$x)

# create data frame with scores
scores_after = as.data.frame(pca$x)
# plot of observations
pdf("qc_results/plots/PCA_after_normalization.pdf")
ggplot(data = scores_after, aes(x = PC1, y = PC2,colour=grps_pca)) +
  geom_hline(yintercept = 0, colour = "gray65") +
  geom_vline(xintercept = 0, colour = "gray65") +
  #geom_text(colour = "black",label=sampleNames(data), size = 2,angle=40) +
  #scale_fill_manual(values=c("#E41A1C", "#377EB8", "#4DAF4A"), breaks=c("Parabel", "Simbox", "Texus"), labels=c("Parabel", "Simbox", "Texus")) +
  geom_point(aes(shape = factor(data$treatment)),size=2) + 
  #scale_colour_manual(values = c("#E41A1C","#377EB8", "#4DAF4A"))
  #scale_shape_manual(values=1:nlevels(col)) +
  theme(legend.title=element_blank()) +  ## turn off legend title
  ggtitle("PCA plot after normalization")
dev.off()



#shows scree plot to verify plotting of PC1 vs PC2
library("affycoretools")
pdf("qc_results/plots/PCs.pdf")
plotPCA(exprs(eset),main="Principal component analysis (PCA)", screeplot=TRUE, outside=TRUE)
dev.off()

#unload affy related packages again as analysis is focused on using oligo package function:
detach("package:affycoretools", unload=TRUE)
#detach("package:affy", unload=TRUE)




##########################################################################
# Non-specific filtering of data
# let us explore how nonspecific filtering can improve our analysis. To this end, we calculate the overall variability across arrays of each probe set, regardless of the sample labels. For this, we use the function rowSds, which calculates the standard deviation for each row. A reasonable alternative would be to calculate the interquartile range (IQR).
sds = rowSds(exprs(eset))
sh = shorth(sds)
sh

#We can plot the histogram of the distribution of sds. The function shorth calculates the midpoint of the shorth (the shortest interval containing half of the data), and is in many cases a reasonable estimator of the ???peak??? of a distribution. Its value is drawn as a dashed vertical line in Figure.

pdf("qc_results/plots/Histogram_of_sds.pdf")
hist(sds, breaks=50, xlab="standard deviation")
abline(v=sh, col="blue", lwd=3, lty=2)
dev.off()

#There are a large number of probe sets with very low variability.We can safely assume that we will not be able to infer differential expression for their target genes. If there is differential expression between groups of samples, this will be reflected in higher overall variability. The benefit from eliminating probe sets with low overall variability at this stage of the analysis is that this ameliorates the multiple testing problem. By reducing the number of tests to be carried out, we increase the power to detect differential expression for the remaining, more variable, and hencemore informative probe sets. Hence, let us discard those probe sets whose standard deviation is below the value of sh.

eset_filt_sds = eset[sds>=sh,]
dim(exprs(eset))
dim(exprs(eset_filt_sds))

#alternative: IQR
iqrCutoff <- 0.3  #choose depending on dataset
Iqr <- apply(exprs(eset), 1, IQR)
pdf("qc_results/plots/Histogram_of_IQR.pdf")
hist(Iqr, breaks=50, xlab="standard deviation")
abline(v=iqrCutoff, col="blue", lwd=3, lty=2)
dev.off()
selected <- Iqr > iqrCutoff
eset_filt_iqr <- eset[selected,]
dim(eset_filt_iqr)

#A related approach would be to discard all probe sets with consistently low expression values. The idea is similar: those probe sets most likely match transcripts whose expression we cannot detect at all, and hence we need not test them for differential expression.
#To summarize, nonspecific filtering of probe sets aims to reduce the number of statistical tests performed, and hence to increase the power to detect differential expression in view of multiple testing adjustments (von Heydebreck et al., 2004).

#compare both sds and IQR and choose reasonably.
dim(exprs(eset_filt_sds))  #
dim(eset_filt_iqr)  #
dim(exprs(eset)) #

#write to file for customer to plot e.g. in excel:
write.exprs(eset, "qc_results/tables/RMAnorm_nonfiltered.txt")
write.exprs(eset_filt_sds, "qc_results/tables/RMAnorm_sds.filtered.txt")
#write.exprs(eset_filt_iqr, "out/RMAnorm_iqr.filtered.txt")


#save esets
save(list=c("pd","eset", "eset_filt_sds"), file="qc_results/final/eset.Rdata")

#save image
setwd(path)



#end of script
####-------------save Sessioninfo
fn <- paste("qc_results/tables/sessionInfo_",format(Sys.Date(), "%d_%m_%Y"),".txt",sep="")
sink(fn)
sessionInfo()
sink()
####---------END----save Sessioninfo 







