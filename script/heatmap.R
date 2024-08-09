#!/usr/bin/env Rscript
#
# Written by Dave Tang
# Year 2023
#

args <- commandArgs()
file_arg <- grep("--file", args, value = TRUE)
script_dir <- dirname(strsplit(file_arg, '=')[[1]][2])
ver_file <- paste0(script_dir, '/.version')
script_ver <- readLines(ver_file)

suppressPackageStartupMessages(library(optparse))
suppressPackageStartupMessages(library(pheatmap))
suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(tidyr))

# optional args
option_list <- list(
   make_option(c("-v", "--version"), action = "store_true", help =
               "Show script version and exit"),
   make_option(c("-o", "--out"), default = "heatmap.png",
               help = "Output heatmap file name (default = %default)"),
   make_option(c("-m", "--matrix"), default = "matrix.csv",
               help = "Output matrix file name (default = %default)"),
   make_option(c("-c", "--cluster_cols"), action = "store_true", default = FALSE,
               help = "Cluster columns (default = %default)")
)

# create your own usage
opt_parse <- OptionParser(usage = "%prog [options] directory",
                          option_list = option_list)

# set positional_arguments to TRUE
opt <- parse_args(opt_parse, positional_arguments = TRUE)

if(length(opt$options$version) > 0){
   message(script_ver)
   quit()
}

# print usage if no positional args provided
if (length(opt$args) == 0){
   print_help(opt_parse)
   stop("Please provide an input directory")
}

my_dir <- opt$args[1]

if(!dir.exists(my_dir)){
   stop(paste0(my_dir, " does not exist"))
}

lapply(
  list.files(my_dir, pattern = ".csv$", full.names = TRUE),
  function(x){
    cbind(gene = sub("\\.\\w+$", "", basename(x)), read.csv(x))
  }
) |>
  do.call("rbind", args = _) -> my_df

# Split `id` column.
do.call("rbind", strsplit(x = my_df$id, split = "\\.")) |>
  as.data.frame() -> id_split

colnames(id_split) <- c('root', 'system', 'organ', 'tissue')

# Rename tissues.
cap_first <- function(x){
  s <- strsplit(x, "")[[1]][1]
  return(sub(s, toupper(s), x))
}

id_split$tissue <- tolower(id_split$tissue)
id_split$tissue <- sapply(id_split$tissue, cap_first)

my_df <- cbind(my_df, id_split)
my_df <- my_df[order(my_df$gene, my_df$system), ]
my_df$system <- factor(my_df$system, levels = unique(my_df$system))
my_df$organ <- factor(my_df$organ, levels = unique(my_df$organ))
my_df$tissue <- factor(my_df$tissue, levels = unique(my_df$tissue))

my_df |>
  dplyr::select(gene, median, tissue) |>
  tidyr::pivot_wider(names_from = tissue, values_from = median) -> my_df_wide

my_mat <- as.matrix(my_df_wide[, -1])
row.names(my_mat) <- my_df_wide$gene
my_order <- colnames(my_mat)
write.csv(my_mat, file = opt$options$matrix, quote = FALSE)

my_df |>
  dplyr::select(system, tissue) |>
  dplyr::distinct() |>
  dplyr::arrange(match(tissue, my_order)) |>
  dplyr::select(-tissue) -> sample_anno

row.names(sample_anno) <- my_order

# used to introduce gaps in the heatmap if no clustering
sample_anno$system |>
  as.numeric() |>
  diff() -> my_breaks
my_breaks <- which(my_breaks == 1)

if(opt$options$cluster_cols == TRUE){
   p <- pheatmap(my_mat, annotation_col = sample_anno, silent = TRUE)
} else {
   p <- pheatmap(my_mat, annotation_col = sample_anno, cluster_cols = FALSE, gaps_col = my_breaks, silent = TRUE)
}

my_width  <- 800 * sqrt(nrow(my_mat))
my_height <- 400 * sqrt(nrow(my_mat))

save_pheatmap_png <- function(x, filename, width=my_width, height=my_height, res = 300){
   png(filename, width = width, height = height, res = res)
   grid::grid.newpage()
   grid::grid.draw(x$gtable)
   dev.off()
}

save_pheatmap_png(p, opt$options$out)

message("Done")
quit()
