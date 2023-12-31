#' analyze_dataset: Basically performs preprocessing and then returns analyzed RNASeq dataset (diff. expression)
#'           , i.e. the DESeq2 result whose p-values and baseMean statistics can then be used with IHW
#'
#'
#' @param dataset  Character, name of dataset to be preprocessed, only 3 choices currently available ("airway","bottomly","hammer")
#' @param res      (default TRUE): return result table, rather than DESeq2 object
#'
#' @return Preprocessed dataset
#' @examples bottomly <- analyze_dataset("bottomly")
#'
#' @importFrom Biobase pData rowMax rowMin
#' @importFrom SummarizedExperiment assay colData
#' @importFrom BiocGenerics counts updateObject
#' @importFrom DESeq2 DESeqDataSet DESeq DESeqDataSetFromMatrix results
#' @import genefilter
#' @importFrom utils data
#' @export
analyze_dataset <- function(dataset=c("airway","bottomly","hammer"), res= TRUE) {

    if (dataset=="airway") {
      airway <- NULL
      if (!requireNamespace("airway", quietly = TRUE)){
        stop("airway data package required.")
      }
      data("airway", package="airway",envir=environment())
      dds <- DESeqDataSetFromMatrix(countData = assay(airway),
                                    colData = colData(airway),
                                    design = ~ cell + dex)
      # have to use hack above, because
      # dds <- DESeqDataSet(se = airway, design = ~ cell + dex)
      # throws the following error for some reason:
      # "Error in checkSlotAssignment(object, name, value)
      #  assignment of an object of class "ShallowSimpleListAssays"
      #  is not valid for slot 'assays' in an 
      #  object of class "DESeqDataSet"; is(value, "Assays") is not TRUE
      dds <- DESeq(dds)
      
    } else if (dataset == "bottomly") {
      bottomly.eset <- NULL
      load(system.file("extdata/real_data", "bottomly_eset.RData", package = "IHWpaper"),
        envir= environment())
      countData <- Biobase::exprs(bottomly.eset)
      colData <- pData(bottomly.eset)
      dds <- DESeqDataSetFromMatrix(countData = countData, colData = colData , design = ~strain)
      dds <- DESeq(dds)

    } else if (dataset == "hammer") {
      hammer.eset <- NULL
      load(system.file("extdata/real_data", "hammer_eset.RData", package = "IHWpaper"),
                        envir=environment())
      countData <- Biobase::exprs(hammer.eset)
      colData <- pData(hammer.eset)
      dds <- DESeqDataSetFromMatrix(countData = countData, colData = colData , design = ~protocol)
      dds <- dds[, dds$Time == "2 months"]
      dds <- DESeq(dds)
      
    } else {
      stop("No such dataset currently available!")
    }

  if (res){
    vars <- rowVars(counts(dds,normalized=TRUE))
    resDf <- as.data.frame(results(dds))
    resDf$var <- vars
    resDf$max <- rowMax(counts(dds,normalized=TRUE))
    resDf$min <- rowMin(counts(dds,normalized=TRUE))
    resDf <-subset(resDf, !is.na(resDf$pvalue)) #maybe remove that since IHW should be able to handle NAs anyway
    return (resDf)
  } else {
    return (dds)
  }

}