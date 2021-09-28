# This file uses the parametric bootstrap in parallel (using the shared-memory parallelism)to sample parameters
# for a quadratic model of global sea-level rise
#
# This model is parameterized as SL = a(t-t_0)^2 + b(t-t_0) + c (in mm)

# load packages
library(parallel) # manages cluster
library(doParallel) # creates parallel backend
library(foreach) # provides parallel for loops

ncpu <- parallel::detectCores() - 1 # number of (logical) CPUs to use
nboot <- 10000 # number of bootstrap replicates
set.seed(1000) # set random seed

# Read in data
sl_data <- read.table("../data/gslGRL2008.txt", skip=14, header=FALSE)

# Extract years and global mean sea level (in mm)
yrs <- sl_data[, 1] # years
sl <- sl_data[, 2] # global mean sea level

# find the best-fit quadratic model by minimizing RMSE
rmse <- function(params, func, time, dat) {
    sqrt(mean((dat - func(params, time))^2))
}

sim_sl <- function(params, t) {
    a <- params[1]
    b <- params[2]
    c <- params[3]
    t0 <- params[4]

    a * (t - t0)^2 + b * (t - t0) + c
}

start <- c(0, 0, -100, 1800) # starting value for optimization
best_fit <- optim(start, rmse, gr = NULL, func = sim_sl, time = yrs, dat = sl)
best_params <- best_fit$par
best_sl_predict <- sim_sl(best_params, yrs)

# Time to bootstrap the residuals
# compute the residuals
resids <- sl - best_sl_predict

# generate bootstrap replicates of the residuals
resid_boot <- sample(resids, length(yrs) * nboot, replace=TRUE)
resid_boot <- matrix(resid_boot, nrow=nboot, ncol=length(yrs))
# add residuals onto the best fit
sl_boot <- sweep(resid_boot, 2, best_sl_predict, FUN="+")

# Set up the cluster environment
cl <- parallel::makeCluster(ncpu) # create the cluster 
doParallel::registerDoParallel(cl) # register it as the backend

# Loop over bootstrapped realizations and estimate parameters
# you could also do this with parallel apply functions if you'd made a more clever wrapper function
start.time <- Sys.time() # start timing
params_boot <- foreach(i=1:nboot, .combine="rbind", .inorder=TRUE) %dopar% {
    fit <- optim(start, rmse, gr=NULL, func=sim_sl, time=yrs, dat=sl_boot[i, ])$par
}

Sys.time() - start.time # report run time

# Shut down the cluster
parallel::stopCluster(cl)

# Plot obtained sampling distributions
parnames <- c("a", "b", "c", "t0")
pdf("sl_boot_plots.pdf")
par(mfrow=c(2, 2))
for (j in 1:length(parnames)) {
    hist(params_boot[, j], prob=TRUE, col="grey", main=parnames[j], xlab="value")
    abline(v=best_params[j], col="red", lwd=2)
}
dev.off()