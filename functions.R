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

# The cross-validation function
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



