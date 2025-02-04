###########################################################################################################################
### It should be noted that the end result of this simulation study (simulated.sum) is a matrix of size 144 x 7.        ###
### As described in the thesis, this matrix is split up in three smaller matrices. From these smaller matrices,         ###
### three matrices with the percentage of correctly selected dimensionalities, the percentage of too low selected       ###
### dimensionalities, and the percentage of too high selected dimensionalities are derived. The three matrices with     ###
### the percentages are eventually shown in the thesis (Table 5.1, 5.2, and 5.3). However, the code for going from      ###
### simulated.sum to the matrices shown in the thesis is not provided. This markdown file is solely meant to illustrate ###
### (in code) how the simulation study was done.                                                                        ###
###########################################################################################################################


###############################################################################
######################### Download the drug data set ##########################
###############################################################################

drugdat <- read.table('https://archive.ics.uci.edu/ml/machine-learning-databases/00373/drug_consumption.data', sep = ",")
# or
#drugdat <- read.table('drug_consumption.data', sep = ",")


# change codes of drug use
for (v in 14:32){
  drugdat[,v] = ifelse(drugdat[,v] == "CL3", 1, ifelse(drugdat[,v] == "CL4", 1, ifelse(drugdat[, v] == "CL5",1, ifelse(drugdat[,v] == "CL6", 1, 0))))
}

# add variable names
colnames(drugdat) = c(
  "id",
  "age",
  "gender",
  "educ",
  "country",
  "ethnic",
  "N",
  "E",
  "O",
  "A",
  "C",
  "I",
  "S",
  "Alcohol",
  "am",
  "Amyl",
  "Benzos",
  "Caff",
  "ca", 
  "Choc",
  "co",
  "Crack",
  "ex",
  "Heroin",
  "Ketamine",
  "LegalH",
  "lsd",
  "Meth",
  "Mushrooms",
  "Nicotine",
  "Semer",
  "VSA"
)

# get data matrix X
# (only age, gender, NEO-FFI-R questionnaire, BIS-11 questionnaire, and ImpSS questionnaire were used as predictors)
X = as.matrix(drugdat[,c(2,3,7:13)])

# get responses Y
Y = as.matrix(drugdat[,14:32])
# only five drugs (amphetamin, cannabis, coke, extasy, lsd) are used
Y = Y[, c(2, 6, 8, 10, 14)]

###############################################################################
########################## The additional functions ###########################
###############################################################################

# The loss function
ssdif = function(A,B){
  # sum of squared differences
  ss = sum((A - B)^2)
  
  return(ss)
}

# The svd function
mysvd = function(A, M){
  # an SVD procedure that keeps matrices
  I = nrow(A)
  J = ncol(A)
  svd.out = svd(A, nu = M, nv = M)
  U = matrix(svd.out$u, I, M)
  V = matrix(svd.out$v, J, M)
  D = diag(svd.out$d, M, M)
  
  result = list(
    u = U,
    v = V,
    d = D
  )
  return(result)
}


# The soft-thresholding function
soft.thres = function(z,gamma){
  z = sign(z) * pmax(abs(z) - gamma, 0)
  
  return(z)
}


# The predict function
predict.rjlda = function(newx, output){
  # sequence of lambdas
  lambdas = length(output$G.all)
  
  # center new X
  cont = output$continuous
  Xs = scale(newx[, cont], center = output$mx, scale = output$sdx)
  X = newx
  X[, cont] = Xs
  
  # initialize yhat for every lambda
  yhat.all = matrix(nrow = nrow(newx), ncol = lambdas)
  
  # for every lambda
  for(i in 1:lambdas){
    # discriminant scores 
    N = X %*% output$B.all[[i]]
    
    # get G
    G = output$G.all[[i]]
    rownames(G) = colnames(output$Y)
    
    # calculate distance between subjects (discriminant scores) and class coordinates
    ones.C = matrix(1, nrow(G), 1)
    ones.I = matrix(1, nrow(newx),1)
    D2 = diag(N %*% t(N)) %*% t(ones.C) + ones.I %*% 
      t(diag(G %*% t(G))) - 2* N %*% t(G) 
    colnames(D2) = colnames(output$Y)
    
    # assign person to class whose distance is smallest
    yhat.all[,i] = matrix(colnames(D2)[apply(D2, 1, which.min)],
                          nrow(newx), 1)
  }
  return(yhat.all)
}



###############################################################################
##########################    The main functions    ###########################
###############################################################################

# The jlda function
jlda = function(X, Y, M = 2, ord = 1){
  # Joint Linear Discriminant Analysis for multi-labelled data
  # INPUT
  # X: matrix of size n x P
  # Y: matrix of size n x R 
  # M: Number of dimensions
  # order:  1 - main effects
  #         2 - two-way interactions
  #         ...
  #         R - full
  # OUTPUT
  # --------------------------------------------
  
  library(nnet)
  n = nrow(X)
  P = ncol(X)
  R = ncol(Y)
  
  ##############################################
  ################## center X ##################
  ##############################################
  
  X. = X
  # which variables have more than 2 values (i.e. are continuous)
  cont = lapply(apply(X., 2, unique), length) > 2 
  
  Xc = scale(X.[, cont], center = TRUE, scale = TRUE)
  mx = attr(Xc, "scaled:center")
  sdx = attr(Xc, "scaled:scale")
  X.[, cont] = Xc
  Xs = as.matrix(X.)
  
  ##############################################
  ################# create Yi ##################
  ##############################################
  
  profile = matrix(NA, n, 1)
  for(i in 1:n){
    profile[i, 1] = paste(Y[i,], collapse = "")
  }
  Yi = class.ind(profile)
  
  ##############################################
  ################# create Z ###################
  ##############################################
  
  A = unique(Y)
  Aprofile = matrix(NA, nrow(A),1)
  for(i in 1:nrow(A)){
    Aprofile[i, 1] = paste(A[i,], collapse = "")
  }
  Ai = t(class.ind(Aprofile))
  aidx = rep(NA, nrow(A))
  for(j in 1:nrow(A)){
    aidx[j] = which(Ai[j,] == 1, arr.ind = TRUE)
  }
  A = A[aidx,]
  A = as.data.frame(A)
  rownames(A) = colnames(Yi)
  colnames(A) = colnames(Y)
  if (ord == 1){
    Z = model.matrix(~ ., data = A)
  }
  else if (ord == 2){
    Z = model.matrix(~ .^2, data = A)
  }
  else if (ord == 3){
    Z = model.matrix(~ .^3, data = A)
  }
  else if(ord == R){
    Z = diag(nrow(A))
  }
  
  ##############################################
  ############ Dzy and Dzy^(-1/2) ##############
  ##############################################
  
  Dy = t(Yi) %*% Yi
  Dzy = t(Z) %*% Dy %*% Z
  eig.dzy = eigen(Dzy)
  Dzy.invsqrt = eig.dzy$vectors %*% diag(sqrt(1/eig.dzy$values))
  
  ##############################################
  ################# U and V ####################
  ##############################################
  
  U = t(Xs) %*% Yi %*% Z %*% Dzy.invsqrt
  V = (1/n) * t(Xs) %*% Xs
  
  ##############################################
  ################## V^(-1/2) ##################
  ##############################################
  
  out.evd = eigen(V)
  V2 = out.evd$vectors %*% diag(sqrt(1/out.evd$values))
  
  ##############################################
  ################# B and G ####################
  ##############################################
  
  out.svd = mysvd(t(U) %*% V2, M = M)
  B = V2 %*% out.svd$v 
  G = Z %*% solve(Dzy) %*% t(Z) %*% t(Yi) %*% Xs %*% B  
  
  ##############################################
  ################### loss #####################
  ##############################################
  
  Loss = ssdif(Xs %*% B, Yi %*% G)
  
  ##############################################
  ################## output ####################
  ##############################################
  
  results = list(
    Xoriginal = X,
    Yoriginal = Y,
    Yprofile = profile,
    continuous = cont,
    mx = mx,
    sdx = sdx,
    X = Xs,
    Y = Yi,
    V = V2, 
    U = U,
    B = B,
    G = G,
    Z = Z,
    Bg = solve(t(Z) %*% Z) %*% t(Z) %*% G,
    N = Xs %*% B,
    Loss = Loss
  )  
}

# The regularized jlda function
rjlda <- function(X, Y, M = 6, ord = 1, crititer = 1e-8, maxiter = 100, lambda.max = 1, lambda.min = 0){
  # regularized Joint Linear Discriminant Analysis for multi-labelled data
  # using alternating least squares algorithm
  # INPUT
  # X: matrix of size n x P
  # Y: matrix of size n x R 
  # M: Number of dimensions
  # order:  1 - main effects
  #         2 - two-way interactions
  #         ...
  #         R - full
  # crititer: critical value for convergence
  # maxiter: maximum number of iterations for convergence
  # lambda.max: biggest lambda of a grid of values for lambda
  # lambda.min: smallest lambda of a grid of values for lambda
  # OUTPUT
  # --------------------------------------------
  
  library(nnet)
  library(MASS)
  n = nrow(X)
  P = ncol(X)
  R = ncol(Y)
  
  ##############################################
  ################## center X ##################
  ##############################################
  
  X. = X
  cont = lapply(apply(X., 2, unique), length) > 2
  Xc = scale(X.[, cont], center = TRUE, scale = TRUE)
  mx = attr(Xc, "scaled:center")
  sdx = attr(Xc, "scaled:scale")
  X.[, cont] = Xc
  Xs = as.matrix(X.)
  
  ##############################################
  ################# create Yi ##################
  ##############################################
  
  profile = matrix(NA, n, 1)
  for(i in 1:n){
    profile[i, 1] = paste(Y[i,], collapse = "")
  }
  Yi = class.ind(profile)
  
  ##############################################
  ################# create Z ###################
  ##############################################
  
  A = unique(Y)
  Aprofile = matrix(NA, nrow(A),1)
  for(i in 1:nrow(A)){
    Aprofile[i, 1] = paste(A[i,], collapse = "")
  }
  Ai = t(class.ind(Aprofile))
  aidx = rep(NA, nrow(A))
  for(j in 1:nrow(A)){
    aidx[j] = which(Ai[j,] == 1, arr.ind = TRUE)
  }
  A = A[aidx,]
  A = as.data.frame(A)
  rownames(A) = colnames(Yi)
  colnames(A) = colnames(Y)
  if (ord == 1){
    Z = model.matrix(~ ., data = A)
  }
  else if (ord == 2){
    Z = model.matrix(~ .^2, data = A)
  }
  else if (ord == 3){
    Z = model.matrix(~ .^3, data = A)
  }
  else if(ord == R){
    Z = diag(nrow(A))
  }
  
  ##############################################
  ############ Dzy and Dzy^(-1/2) ##############
  ##############################################
  
  Dy = t(Yi) %*% Yi
  Dzy = t(Z) %*% Dy %*% Z
  Dzy.inv = ginv(Dzy)
  
  # part of G
  iYYYX = Z %*% Dzy.inv %*% t(Z) %*% t(Yi) %*% Xs
  
  # part of B
  iXXXY = solve(t(Xs) %*% Xs) %*% t(Xs) %*% Yi
  
  # lists to store all Bg's, B's, G's, and losses
  Bg.all = list()
  B.all = list()
  G.all = list()
  loss.all = list()
  
  # S columns of Z
  S = ncol(Z)
  
  # make a sequence of lambda's from smallest to biggest
  lambdaseq = seq(lambda.min, lambda.max, 0.01)
  
  ##############################################
  ## get B and Bg for first (smallest lambda) ##
  ##############################################
  
  # initialize B
  B = matrix(0, P, M)
  
  # initialize (random) Bg
  Bg = matrix(rnorm(S*M), S, M)
  
  # initialize G
  G = Z %*% Bg
  # which columns of G are not all 0
  dims = which(apply(G, 2, function(x)(all(x == 0)))==FALSE) 
  
  # initialize loss
  Loss = numeric(maxiter + 1)
  Loss[1] = Inf
  iter = 2
  
  # convergence is either TRUE or FALSE. It indicates whether the stopping criteria have been met
  converged = FALSE
  
  # start the algorithm
  while(!converged){
    # update B
    B = iXXXY %*% G
    
    # rescale B
    svd.out = mysvd(Xs %*% B, max(dims))
    B[, dims] = sqrt(n) * B %*% svd.out$v %*% ginv(svd.out$d)
    
    # update Bg
    Bg = soft.thres(ginv(t(Z) %*% t(Yi) %*% Yi %*% Z) %*% t(Z) %*% t(Yi) %*% Xs %*% B,
                    lambda.min)
    
    # update G
    G = Z %*% Bg
    # which columns are not all 0
    dims = which(apply(G, 2, function(x)(all(x == 0)))==FALSE)
    
    # check convergence
    Loss[iter] <- ssdif(Xs %*% B[, dims], Yi %*% G[, dims]) 
    converged <- ((Loss[iter-1]-Loss[iter]) < crititer | iter-1 >= maxiter)
    
    # some in between feedback
    #cat(iter, Loss[(iter - 1)], Loss[iter], "\n")
    
    # increase the iteration number
    iter <- iter + 1
  }
  
  # store B, G, loss and Bg for smallest lambda in the lists
  Bg.all[[1]] = Bg
  B.all[[1]] = B
  G.all[[1]] = G
  loss.all[[1]] = Loss[2:(iter-1)] 
  
  ###################################################
  ## use these results (Bg, B and G) from smallest ##
  ## lambda as start values for other lambdas      ##
  ###################################################
  
  for(lamb in 2:length(lambdaseq)){
    # previous matrix for B
    B = B.all[[(lamb-1)]]
    
    # previous matrix for Bg
    Bg = Bg.all[[(lamb-1)]]
    
    # initialize loss
    Loss = numeric(maxiter + 1)
    Loss[1] = Inf
    iter = 2
    
    # convergence is either TRUE or FALSE. It indicates whether the stopping criteria have been met
    converged = FALSE
    
    # start the algorithm
    while(!converged){
      # update B
      B = iXXXY %*% G
      
      # if the max dims is 0, it means everything is zero so continuing the function would be useless
      if(length(dims) == 0){
        cat("Stop, the dimension for lambda ", lambdaseq[lamb], " is 0. \n")
        break
      }
      
      # rescale B
      svd.out = mysvd(Xs %*% B, length(dims))
      B[, dims] = sqrt(n) * B %*% svd.out$v %*% ginv(svd.out$d)
      
      # update Bg
      Bg = soft.thres(ginv(t(Z) %*% t(Yi) %*% Yi %*% Z) %*% t(Z) %*% t(Yi) %*% Xs %*% B,
                      lambdaseq[lamb])
      
      # update G
      G = Z %*% Bg
      # which columns are not all 0
      dims = which(apply(G, 2, function(x)(all(x == 0)))==FALSE)
      
      # check convergence
      Loss[iter] <- ssdif(Xs %*% B[, dims], Yi %*% G[, dims]) 
      converged <- ((Loss[iter-1]-Loss[iter]) < crititer | iter-1 >= maxiter)
      
      # some in between feedback
      #cat(iter, lamb, Loss[(iter - 1)], Loss[iter], "\n")
      
      # increase the iteration number
      iter <- iter + 1
    }
    
    # store B, G, loss and Bg for different lambdas in the lists
    Bg.all[[lamb]] = Bg
    B.all[[lamb]] = B
    G.all[[lamb]] = G
    loss.all[[lamb]] = Loss[2:(iter-1)] 
    
  }
  ##############################################
  ################## output ####################
  ##############################################
  
  results = list(
    Xoriginal = X,
    Yoriginal = Y,
    Yprofile = profile,
    continuous = cont,
    mx = mx,
    sdx = sdx,
    X = Xs,
    Y = Yi,
    dims = dims, 
    B.all = B.all,
    Bg.all= Bg.all,
    G.all = G.all,
    Z = Z,
    lambda.sequence = lambdaseq,
    Loss.all = loss.all
  )
}

# The cross-validated regularized jlda function
cv.rjlda = function(X, Y, M = 6, K = 5, myseed, ord = 1,
                    lambda.min, lambda.max,
                    stderror = T, PE.2by2 = T){
  # cross-validated regularized Joint Linear Discriminant Analysis 
  # for multi-labelled data
  # INPUT
  # X: matrix of size n x P
  # Y: matrix of size n x R 
  # M: Number of dimensions
  # K: Number of folds for cross-validation
  # myseed: a seed for reproducibility
  # order:  1 - main effects
  #         2 - two-way interactions
  # lambda.max: biggest lambda of a grid of values for lambda
  # lambda.min: smallest lambda of a grid of values for lambda
  # stderror: boolean indicating usage of one-standard-error rule
  # PE.2by2: boolean indicating usage of marginal prediction error
  # OUTPUT
  # ------------------------------------------------------------
  
  ############################################
  ##### results on the complete data set ##### 
  ############################################ 
  
  set.seed(myseed)
  results.complete = rjlda(X, Y, M = M, ord = ord,
                           lambda.min = lambda.min,
                           lambda.max = lambda.max)
  lambdas = length(results.complete$lambda.sequence)
  
  ############################################
  ############# cross-validation #############
  ############################################ 
  
  n = nrow(X)
  R = ncol(results.complete$Yoriginal)
  
  # random folds
  folds <- cut(seq(1, n), breaks = K, labels=FALSE)
  folds = sample(folds)
  
  # extract the response profiles and the original Y 
  Yprofile = results.complete$Yprofile
  Yoriginal = results.complete$Yoriginal
  
  # initialize predictions matrix
  big.preds = matrix(NA, nrow(Y), ncol = lambdas)
  
  # initialize cross-validated prediction error matrix
  PE = matrix(nrow = lambdas, ncol = 1)
  
  # initialize prediction error per fold matrix
  PE.per.K = matrix(nrow = lambdas, ncol = K)
  
  # start cross-validation
  for(k in 1:K){
    # extract indices of current fold
    idx = which(folds == k, arr.ind = TRUE)
    
    # initialize predictions for current fold matrix
    predic = matrix(NA, nrow = length(idx), ncol = lambdas)
    
    # perform regularized JLDA on remaining folds
    out = rjlda(X[-idx, ], Y[-idx, ], M = M, ord = ord,
                lambda.max = lambda.max, lambda.min = lambda.min)
    
    # predict outcome for current fold
    predic = predict.rjlda(newx = X[idx, ], out)
    rownames(predic) = as.character(idx)
    
    # store predictions for current fold in predictions matrix
    big.preds[as.numeric(rownames(predic)), ] = predic
    
    # JOINT PREDICTION ERROR
    if(PE.2by2 == F){ 
      # initialize matrix with ones if predicted correctly, 0 otherwise
      # (for every lambda)
      preds.01 = matrix(nrow = length(idx), ncol = lambdas)
      
      # for every subject in the current fold
      for(i in 1:length(idx)){
        # for every value for lambda
        for(j in 1:lambdas){
          # if predicted response profile matches true response profile, add 1, otherwise 0
          if( predic[i,j] == Yprofile[
            as.numeric(rownames(predic)[i]),] ){
            preds.01[i,j] = 1
          }
          else{
            preds.01[i,j] = 0
          }
        }
      }
      
      # for every lambda, count how many times response profile is predicted correctly
      sums.28by28 = colSums(preds.01)/length(idx)
      
      # joint prediction error for the current fold
      PE.per.K[, k] = 1-sums.28by28
    } else{
      
      # MARGINAL PREDICTION ERROR
      
      # for every lambda, transform the predictions for current fold matrix (predic)
      # into matrix with 5 columns, one for each R
      for(l in 1:lambdas){
        predic.mat = matrix(nrow = length(idx), ncol = R)
        colnames(predic.mat) = colnames(Yoriginal)
        rownames(predic.mat) = as.numeric(names(
          strsplit(predic[,l], "")))
        
        for(i in 1:length(idx)){
          predic.mat[i, ] = as.numeric(strsplit(
            predic[i,l], "")[[1]])
        }
        
        # initialize matrix with ones if predicted correctly, 0 otherwise
        # (for every lambda)
        preds.01 = matrix(nrow = length(idx), ncol = R)
        
        # for every subject in the current fold
        for(i in 1:length(idx)){
          # for every response variable R
          for(r in 1:R){
            # if predicted outcome for R matches true outcome for R, add 1, otherwise 0
            if( predic.mat[i,r] == Yoriginal[
              as.numeric(rownames(predic.mat)[i]),r] ){
              preds.01[i,r] = 1
            }
            else{
              preds.01[i,r] = 0
            }
          }
        }
        
        # for every lambda, count how many times outcome for R is predicted correctly
        sums.2by2 = colSums(preds.01)/length(idx)
        
        # marginal prediction error for the current fold
        PE.per.K[l,k] = mean(1-sums.2by2)
      }
    }
  } # end of cross-validation
  
  # cross-validated prediction error for every lambda
  PE[,1] = round(rowMeans(PE.per.K), 7)
  
  # index for lambda with best results
  idx.lambda = which.min(PE) 
  
  # if the one-standard-error rule is applied
  if(stderror == T){
    # initialize matrix to store the standard errors
    SE = matrix(nrow = lambdas, ncol = 1)
    
    # for every lambda
    for(i in 1:lambdas){
      # standard deviation per lambda
      result = sd(PE.per.K[i,])
      
      # standard error per lambda
      SE[i,] = result/sqrt(K)
    } 
    
    # range of one standard error below the best PE and
    # one standard error above the best PE
    range = c(PE[idx.lambda, ] - SE[idx.lambda],
              PE[idx.lambda, ] + SE[idx.lambda])
    
    PE. = PE
    
    # if PE is one SE below the best PE and one SE above the best PE
    # set to 1 (:lambdas because most sparse model is desired)
    PE.[idx.lambda:lambdas,][
      PE.[idx.lambda:lambdas,] >= range[1] &
        PE.[idx.lambda:lambdas,] <= range[2] ] = 1
    
    # which of indices that are one SE below the best PE and one SE above the best PE
    # is biggest
    idx.stderror = max(which(PE.[,1] == 1.0))
  }
  
  ############################################
  ############ confusion matrices ############
  ############     per lambda     ############
  ############################################ 
  
  # initialize list to store confusion matrices
  list.Cj.matrix = list()
  
  # get names of the response profiles
  Yprofile.uniq = colnames(results.complete$Y)
  
  # number of response profiles
  n.Cj = ncol(results.complete$Y)
  
  # for every lambda
  for(i in 1:lambdas){
    # initialize empty matrix of size (in this case) 28x28
    list.Cj.matrix[[i]] = matrix(0, nrow = n.Cj, ncol = n.Cj)
    
    # get names of the response profiles
    colnames(list.Cj.matrix[[i]]) = Yprofile.uniq
    rownames(list.Cj.matrix[[i]]) = Yprofile.uniq
    
    # for every response profile
    for(r in 1:n.Cj){
      for(j in 1:n.Cj){
        # check if predicted response profile matches the actual response profile
        # count how many times this is the case and put this sum in confusion matrix
        list.Cj.matrix[[i]][r, j] = sum( 
          Yprofile == Yprofile.uniq[r] & 
            big.preds[,i] == Yprofile.uniq[j])
      }
    }
  }
  
  ############################################
  ############ confusion matrices ############
  ########## per response variable ###########
  ############    per lambda     #############
  ############################################ 
  
  # initialize list to store confusion matrices
  list.rCj.matrix = list()
  
  # for every lambda
  for(i in 1:lambdas){
    # initialize list of size R
    rCj.matrix = vector('list', ncol(results.complete$Yoriginal))
    
    # for every R
    for(z in 1:ncol(results.complete$Yoriginal)){
      # matrix Z for a single R
      Z.matrix = cbind(results.complete$Z[, 1+z],
                       1 - results.complete$Z[,1+z])
      
      # check if predicted response profile that contains the single R matches the actual 
      # response profile that contains the single R and count how many times this is the case
      # put this sum in 2x2 confusion matrix
      r.Cj = t(Z.matrix) %*% as.matrix(list.Cj.matrix[[i]]) %*%
        Z.matrix
      dimnames(r.Cj) = list(actual = c('1', '0'),
                            predicted = c('1', '0'))
      names(rCj.matrix)[z] = colnames(results.complete$Z)[z+1]
      
      # store 2x2 confusion matrix in list of size R
      rCj.matrix[[z]] = r.Cj
    }
    # for every lambda store the list of size R
    list.rCj.matrix[[i]] = rCj.matrix
  }
  
  ##############################################
  ################## output ####################
  ##############################################
  
  # if the one-standard-error rule is applied
  if(stderror == T){
    results = list(
      indx.lambda = idx.stderror,
      lambda = results.complete$lambda.sequence[idx.stderror], 
      prediction.errors = PE,
      confusion.matrices = list.Cj.matrix,
      confusion.matrices.per.R = list.rCj.matrix,
      best.PE = PE[idx.stderror, ],
      best.confusion.matrix = list.Cj.matrix[[idx.stderror]],
      best.confusion.matrix.per.R = list.rCj.matrix[[idx.stderror]]
    )
  } 
  else{
    # if the one-standard-error rule is NOT applied  
    results = list(
      indx.lambda = idx.lambda,
      lambda = results.complete$lambda.sequence[idx.lambda], 
      prediction.errors = PE,
      confusion.matrices = list.Cj.matrix,
      confusion.matrices.per.R = list.rCj.matrix,
      best.PE = PE[idx.lambda, ],
      best.confusion.matrix = list.Cj.matrix[[idx.lambda]],
      best.confusion.matrix.per.R = list.rCj.matrix[[idx.lambda]]
    )
  }
}

###############################################################################
##########################      The simulation      ###########################
###############################################################################

library(gtools)
library(MASS)

# repetitions
N = 2

#######################################################
######################### 1 ###########################
#### Extract mean of each predictor variable       ####
#######################################################

cont = lapply(apply(X, 2, unique), length) > 2
Xc = scale(X[, cont], center = TRUE, scale = TRUE)
mx = attr(Xc, "scaled:center")

#######################################################
######################### 2 ###########################
#### Extract the covariance matrix or use          ####
#### independent predictors                        ####
#######################################################

covX = cov(X[, -2]) 
covXzeros = diag(diag(covX))
colnames(covXzeros) = colnames(covX)
rownames(covXzeros) = rownames(covX)

# booleans for within-design factors
combis = permutations(2,2, c(T,F), repeats.allowed = T)

# possible combinations between-design factors
combi = expand.grid(M = c(2,3,4),
                    n = c(100, 1000, 2000),
                    cov = c('covX', 'covXzeros'),
                    order = c(1, 2))

# create names for the combinations
a = paste(combi[, 1], combi[,2], combi[, 3], combi[, 4], sep = ".")
b = paste('M', a, sep = "")
c = sub(pattern = ".", replacement = "n", x = b, fixed = T)
d = sub(pattern = ".", replacement = "", x = c, fixed = T)
e = sub(pattern = ".", replacement = "or", x = d, fixed = T)

f = numeric()
for(i in 1:length(e)){
  g = c(paste(e[i], gsub(pattern = ".",
                         replacement = "p", 
                         x = paste('s',paste(combis[, 1],
                                             combis[,2], sep = "."),
                                   sep = ""),
                         fixed = T), sep = "-"))
  f = c(f, g)
}

# initialize a list with a matrix for every combination
sim.sum.list = list()

# start simulation
# for every combination
for(comb in 1:nrow(combi)){
  # initialize matrix to store the results
  rep.simulated = matrix(nrow = N, ncol = nrow(combis))
  
  # extract the values of the factors of the combination
  M = combi[comb, 1]
  n = combi[comb, 2]
  covar = eval(parse(text = as.character(combi[comb, 3])))
  or = combi[comb, 4]
  
  ########################################################
  ######################### 3 ############################
  #### Perform JLDA on drug data and extract B and G  ####
  ########################################################
  
  base = jlda(X, Y, M = M, ord = or)
  B = base$B
  G = base$G
  
  # start repetitions
  for(j in 1:N){
    #######################################################
    ######################### 4 ###########################
    #### Generate 100 (or n) new X from multivariate   ####
    #### distribution with mean mx and covariance      ####
    #### matrix covX or covXzeros                      ####
    #######################################################
    
    X.new = mvrnorm(n = n, mu = mx, Sigma = covar)
    # in real dataset 0.48246 Female, -0.48246 Male 
    # here 1 is female, 0 is male
    gender = rbinom(n, size = 1, prob = 0.5) 
    gender = ifelse(gender == 1, 0.48246, -0.48246)
    X.new = cbind(X.new, gender)
    X.new = X.new[, c(1, 9, 2, 3, 4, 5, 6, 7, 8)]
    
    #######################################################
    ######################### 5 ###########################
    #### Compute H = XB which is a n x M matrix        ####
    #######################################################
    
    H = X.new %*% B
    
    #######################################################
    ######################### 6 ###########################
    #### Compute the distances between H and G, D(H,G) ####
    #### with elements d_{ic}, the distance from       ####
    #### person i to class c (c = 1...Cj)              ####
    #### D(H,G) is a n x Cj matrix                     ####
    #######################################################
    
    ones.C = matrix(1, nrow(G), 1)
    ones.I = matrix(1, nrow(X.new),1)
    D = diag(H %*% t(H)) %*% t(ones.C) + ones.I %*%
      t(diag(G %*% t(G))) - 2 * H %*% t(G) 
    
    #######################################################
    ######################### 7 ###########################
    #### Compute probabilities, p_{ic}, for every      ####
    #### person for every class. This is done by       ####
    ####        p = exp(-D^2)/rowSums(exp(-D^2))       ####
    #### The matrix p consists of elements p_{ic} and  ####
    #### is of size n x Cj                             ####
    #######################################################
    
    p = exp(-D^2)/rowSums(exp(-D^2))
    colnames(p) = colnames(D)
    
    # could be bad luck and generate values for a person i that are outliers
    # in such a case, generate new values
    if(any(rowSums(exp(-D^2)) == 0)){
      while(anyNA(p)){
        index = unique(which(is.na(p), arr.ind = T)[, 1]) 
        n.extra = length(unique(which(is.na(p), arr.ind = T)[,1]))
        
        # 1: Generate new X
        X.extra = mvrnorm(n = n.extra, mu = mx, Sigma = covar)
        gender.extra = rbinom(n = n.extra, size = 1, prob = 0.5) # 1 is female, 0 is male
        gender.extra = ifelse(gender.extra == 1, 0.48246, -0.48246)
        X.extra = matrix(c(X.extra, gender.extra), nrow = n.extra, ncol = ncol(X.new))
        X.extra = matrix(X.extra[, c(1, 9, 2, 3, 4, 5, 6, 7, 8)], nrow = n.extra, ncol = ncol(X.new))
        colnames(X.extra) = colnames(X.new)
        
        # 2: Compute H = XB 
        H.extra = X.extra %*% B
        
        # 3: Compute the distances between H and G; D(H;G) 
        ones.C.extra = matrix(1, nrow(G), 1)
        ones.I.extra = matrix(1, nrow(X.extra),1)
        D.extra = diag(H.extra %*% t(H.extra)) %*% t(ones.C.extra) + ones.I.extra %*%
          t(diag(G %*% t(G))) - 2 * H.extra %*% t(G) 
        
        # 4: Compute probabilities for every person for every class.
        p.extra = exp(-D.extra^2)/rowSums(exp(-D.extra^2))
        colnames(p.extra) = colnames(D.extra)
        p[index, ] = p.extra
      }
    }
    
    ########################################################
    ######################### 8 ############################
    #### For every person, generate a y* from the       ####
    #### multinomial distribution (this is the profile, ####
    #### not the observations on the different response ####
    #### variables). This is done with the rmultinom    ####
    #### function. When you have 3 classes and the      ####
    #### probabilities for person i are 0.2, 0.3, 0.5   ####
    #### then rmultinom(1, 1, c(0.2, 0.3, 0.5))         ####
    ########################################################
    
    y.star = matrix(nrow = n, ncol = 1)
    for(s in 1:n){
      y = rmultinom(1, 1, p[s,])
      y.star[s, ] = rownames(which(y == 1, arr.ind = T))
    }
    
    ########################################################
    ######################### 9 ############################
    #### Transform the profiles in y* to responses on   ####
    #### each of the five response variables. This      ####
    #### results in the matrix Y*new which is a         ####
    #### n x R matrix                                   ####
    ########################################################
    
    Y.new = matrix(nrow = n, ncol = 5)
    colnames(Y.new) = c('am', ', ca', 'co', 'ex', 'lsd')
    for(w in 1:n){
      R = as.numeric(strsplit(y.star[w, ], "")[[1]])
      for(r in 1:5){
        Y.new[w, r] = R[r]
      }
    }
    
    # apply to rjlda function
    simulated = rjlda(X.new, Y.new) 
    for(c in 1:nrow(combis)){
      
      # apply to cv.rjlda function
      cv.simulated = cv.rjlda(X.new, Y.new, myseed = 2306, lambda.min = 0,
                              lambda.max = 1, ord = or, stderror = combis[c,1], 
                              PE.2by2 =combis[c, 2])
      
      # get lambda
      indx = cv.simulated$indx.lambda
      
      # get selected dimensionality
      dim = max(which(apply(simulated$G.all[[indx]],
                            2, function(x)(all(x == 0)))==FALSE))
      
      # add to matrix
      rep.simulated[j, c] = dim
    }
  }
  
  # matrix which indicates how many times each dimension is selected for certain combination
  sim.sum = matrix(nrow = 4, ncol = 6)
  colnames(sim.sum) = c('M=1', 'M=2', 'M=3', 'M=4', 'M=5', 'M=6')
  
  # for every dimensionality M, M = 1, ..., 6
  for(m in 1:ncol(sim.sum)){
    # for every within-design factor
    for(w in 1:ncol(rep.simulated)){
      # count how many times each dimension is selected
      sim.sum[w, m] = sum(rep.simulated[,w] == m)
    }
  }
  
  # add this matrix to the list
  sim.sum.list[[comb]] = sim.sum
}

# turn the list into one matrix
simulated.sum = do.call(rbind, sim.sum.list)
rownames(simulated.sum) = f

# the rows of some designs don't add up to 1000 as they should. This is because the 
# selected dimensionality was 0. Therefore, adding a column to simulated.sum with M = 0.
extra.col = matrix(data = 0, nrow = nrow(simulated.sum), ncol = 1)
colnames(extra.col) = c('M=0')
for(i in 1:nrow(simulated.sum)){
  if(rowSums(simulated.sum)[i] != N){
    extra.col[i, 1] = N - rowSums(simulated.sum)[i]
  }
}

simulated.sum = cbind(extra.col, simulated.sum)

# output
simulated.sum





