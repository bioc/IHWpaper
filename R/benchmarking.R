# general functions to make it easy to benchmark FDR methods on given simulations..

#' run_evals: Main function to benchmark FDR methods on given simulations.
#' 
#' @param sim_funs List of simulation settings
#' @param fdr_methods List of FDR controlling methods to be benchmarked
#' @param nreps Integer, number of Monte Carlo replicates for the simulations 
#' @param alphas Numeric, vector of nominal significance levels 
#'	   at which to apply FDR controlling methods
#' @param ... Additional arguments passed to sim_fun_eval
#'
#' @return data.frame which summarizes results of numerical experiment
#'
#' @details
#'    This is the main workhorse function which runs all simulation benchmarks for IHWpaper.
#'    It receives input as described above, and the output is a data.frame with the
#'    following columns:
#'    \itemize{
#'			\item{fdr_method: }{Multiple testing method which was used}
#'          \item{fdr_pars: }{Custom parameters of the multiple testing method}
#'          \item{alpha: }{Nominal significance level at which the benchmark was run}
#'          \item{FDR: }{False Discovery Rate of benchmarked method on simulated dataset}
#'          \item{power: }{Power of benchmarked method on simulated dataset}
#'          \item{rj_ratio: }{Average rejections divided by total number of hypotheses}
#'			\item{FPR: }{False positive rate of benchmarked method on simulated dataset}
#'          \item{FWER: }{Familywise Error Rate of benchmarked method on simulated dataset}
#'          \item{nsuccessful: }{Number of successful evaluations of the method}
#'          \item{sim_method: }{Simulation scenario under which benchmark was run}
#'          \item{m: }{Total number of hypotheses}
#'          \item{sim_pars: }{Custom parameters of the simulation scenario}
#'    }
#'
#' @examples
#'    nreps <- 3 # monte carlo replicates
#'    ms <- 5000 # number of hypothesis tests
#'    eff_sizes <- c(2,3)
#'    sim_funs <- lapply(eff_sizes,
#'				function(x) du_ttest_sim_fun(ms,0.95,x, uninformative_filter=FALSE))
#' 	  continuous_methods_list <- list(bh,
#'                               	  lsl_gbh,
#'  	                          	  clfdr,
#'                                    ddhf)
#'   fdr_methods <- lapply(continuous_methods_list, continuous_wrap)
#'	 eval_table <- run_evals(sim_funs, fdr_methods, nreps, 0.1, BiocParallel=FALSE)
#'
#' @import dplyr
#' @importFrom BiocParallel bplapply
#' @export
run_evals <- function(sim_funs, fdr_methods, nreps, alphas,...){
	bind_rows(lapply(sim_funs, function(x) sim_fun_eval(x, fdr_methods, nreps, alphas, ...)))
}

sim_fun_eval <- function(sim_fun, fdr_methods, nreps, alphas, BiocParallel=TRUE){
	sim_seeds <- 1:nreps
	if (BiocParallel){
		evaluated_sims <- bplapply(sim_seeds, function(x) sim_eval(sim_fun, x, fdr_methods, alphas))
	} else {
		evaluated_sims <- lapply(sim_seeds, function(x) sim_eval(sim_fun, x, fdr_methods, alphas))
	}
	df <- dplyr::bind_rows(evaluated_sims)
	df <- dplyr::summarize(group_by(df, fdr_method, fdr_pars, alpha), FDR = mean(FDP),
		 power= mean(power), rj_ratio = mean(rj_ratio), FPR = mean(FPR), FDR_sd = sd(FDP), 
		 FWER=mean(FWER), nsuccessful = n())
	m  <- attr(sim_fun, "m")
	sim_method <- attr(sim_fun, "sim_method")
	sim_pars <- attr(sim_fun, "sim_pars")
	df <- mutate(df, sim_method = sim_method, m=  m, sim_pars = sim_pars)
	df
}

sim_eval <- function(sim_fun, seed, fdr_methods, alphas, print_dir = NULL){
	#print(paste("@@@@@ seed is ", seed))
	if (!is.null(print_dir)){
		sim_pars <- attr(sim_fun, "sim_pars")
		file_name <- paste0(print_dir, "seed", seed,"_", sim_pars, ".Rds")
		if (file.exists(file_name)){
			df <- readRDS(file_name)
		} else {
			sim <- sim_fun(seed) 
			df <- bind_rows(lapply(fdr_methods, function(fdr_method) sim_fdrmethod_eval(sim, fdr_method, alphas)))
			saveRDS(df, file=file_name)
		}
	} else {
		sim <- sim_fun(seed) 
		df <- bind_rows(lapply(fdr_methods, function(fdr_method) sim_fdrmethod_eval(sim, fdr_method, alphas)))
	}
	df
}

sim_fdrmethod_eval <- function(sim, fdr_method, alphas){
	bind_rows(lapply(alphas, function(a) sim_alpha_eval(sim, fdr_method, a)))
}

sim_alpha_eval <- function(sim, fdr_method, alpha){

	# tryCatch block mainly because many of the local fdr methods will occasionally crash
	df <- tryCatch({

    	df <- calculate_test_stats(sim, fdr_method, alpha)

		if (is.null(attr(fdr_method,"fdr_pars"))){
			fdr_pars <- NA
		} else{
			fdr_pars <- attr(fdr_method, "fdr_pars")
		}	
		df <- mutate(df, alpha= alpha, 
			fdr_pars = fdr_pars,
			fdr_method=attr(fdr_method,"fdr_method"))
		df
		
	}, error = function(e) {
    	 df <- data.frame()
    	 df		
		})
	df
}

calculate_test_stats <- function(sim, fdr_method, alpha){
	fdr_method_result <- fdr_method(sim, alpha)
	rejected <- rejected_hypotheses(fdr_method_result)
	rjs <- sum(rejected)
	false_rjs <- sum(sim$H == 0 & rejected)
	rj_ratio <- rjs/nrow(sim)
	FDP <- ifelse(rjs == 0, 0, false_rjs/rjs)
	power <- ifelse(sum(sim$H) == 0, NA, sum(sim$H == 1 & rejected)/sum(sim$H ==1))
	# in principle I should take special care in case only alternatives, but we are not
	# interested in this scenario...
	FPR <-  sum(sim$H == 0 & rejected)/sum(sim$H == 0)
	FWER <- as.numeric(false_rjs > 0)
	df <- data.frame(rj_ratio=rj_ratio, FDP=FDP, power=power, FPR=FPR, FWER=FWER)
	df
}

