% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/covariate_methods.R
\name{scott_fdrreg}
\alias{scott_fdrreg}
\title{scott_fdrreg: Wrapper for FDR regression (https://github.com/jgscott/FDRreg)}
\usage{
scott_fdrreg(unadj_p, filterstat, alpha, df = 3, lambda = 0.01)
}
\arguments{
\item{unadj_p}{Numeric vector of unadjusted p-values.}

\item{filterstat}{Factor to which different hypotheses belong}

\item{alpha}{Significance level at which to apply method}

\item{df}{Degrees of freedom for B-slines}

\item{lambda}{Ridge regularization parameter}
}
\value{
FDRreg multiple testing object
}
\description{
scott_fdrreg: Wrapper for FDR regression (https://github.com/jgscott/FDRreg)
}
\references{
James G. Scott, Ryan C. Kelly, Matthew A. Smith, Pengcheng Zhou, and Robert E. Kass. 
        "False discovery rate regression: application to neural synchrony detection in primary visual cortex." 
        Journal of the American Statistical Association (2015).
}
