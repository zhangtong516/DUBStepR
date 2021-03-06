#' @title Determine the optimal feature set using Density Index (DI)
#' @param filt.data log-transformed filtered gene-expression matrix
#' @param ordered.genes genes ordered after stepwise regression
#' @param elbow.pt Elbow point to start determining optimal feature set
#' @param k number of nearest neighbours for CI computation
#' @param num.pcs number of principal components to represent sc data. Default is 15.
#' @param error Acceptable error margin for kNN computation. Default is 0.
#' @return optimal set of feature genes
#'
#' @export
#'
getOptimalFeatureSet <- function(filt.data, ordered.genes, elbow.pt = 25, k = 10, num.pcs = 15, error = 0) {

    # Initialise variables
    mean_knn_vec <- c()
    minNumGenes = ""
    numStepsUnchangedMin = 0

    # Progress bar
    print("Determining optimal feature set")
    pb <- txtProgressBar(min = elbow.pt, max = length(ordered.genes), style = 3)

    # For each neighbour
    for(num_genes in seq(from = elbow.pt, to = length(ordered.genes), by = 25)) {
        # Initialise number of genes
        neighbour_feature_genes <- ordered.genes[1:num_genes]

        # Run PCA on the feature data
        log.feature.data <-
            filt.data[neighbour_feature_genes, ]
        pca.obj <-
            irlba::prcomp_irlba(
                x = Matrix::t(log.feature.data),
                n = min(num.pcs, (length(
                    neighbour_feature_genes
                ) - 1)),
                center = TRUE,
                scale. = FALSE
            )

        pca.data <- pca.obj$x
        rownames(pca.data) <- colnames(log.feature.data)

        # Compute k-NN distance
        system.time(
            my.knn <- RANN::nn2(
                data = pca.data,
                k = (k + 1),
                treetype = "kd",
                searchtype = "standard",
                eps = error
            )
        )

        nn.dists <- my.knn$nn.dists
        rownames(nn.dists) <- rownames(pca.data)

        # Remove first column as it consists of zeroes
        nn.dists <- nn.dists[,-1]

        # Calculate length scale to normalise distances
        sdVec <- pca.obj$sdev
        length_scale <- sqrt(sum(sdVec ^ 2))

        # Scale k-NN distances by length scale
        mean_nn_dist <- mean(x = nn.dists)
        scaled_mean_nn_dist <- mean_nn_dist / length_scale
        names(scaled_mean_nn_dist) <- num_genes

        mean_knn_vec <-
            append(mean_knn_vec, scaled_mean_nn_dist)

        # Check if the minima has been updated
        if (which.min(mean_knn_vec) != minNumGenes) {
            minNumGenes = which.min(mean_knn_vec)
            numStepsUnchangedMin = 0
        } else {
            numStepsUnchangedMin = numStepsUnchangedMin + 1
        }

        # Set progress bar
        setTxtProgressBar(pb = pb, value = num_genes)
    }

    # Determine optimal feature set
    optimal_feature_genes <- ordered.genes[1:as.numeric(names(minNumGenes))]

    return(list("optimal.feature.genes" = optimal_feature_genes, "density.index" = mean_knn_vec))
}
