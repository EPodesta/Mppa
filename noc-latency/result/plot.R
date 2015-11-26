library (plyr)
library (ggplot2)
library (reshape2)
library(scales) 

read_latency <- function (er) {
    filenames <- list.files (path = "./", pattern = er, full.names = TRUE)
    x <- do.call ("rbind", lapply (filenames, read.csv, header = TRUE, sep = ";"))
    #x <- ddply (x, .(direction, size), summarise, time = mean (time))
    return (x)
}

# Computes confidence interval from t-student dist.
# - values: a list of numbers (samples)
# - percentage: the percent range of the confidence interval (default is 95%)
error <- function (values, percentage) {
    n <- length (values)
    # half of error for each side
    t <- 1.0 - ((1.0 - percentage) / 2)
    return (qt (t, df = n - 1) * sd (values) / sqrt (n))
}

plot_latency <- function (title, f, er, scale) {
    x <- read_latency (er)
    # inserts error column for obtaining an 95% conf. interval
    x <- ddply (x, .(direction, size), summarise, e = error (time, 0.95), time = mean (time))
    plot <- ggplot (x, aes (factor (size), time, group = direction, colour = direction, shape = direction)) +
    theme_bw () +
    geom_point() +
    geom_line () +
    # displays nice confidence interval
    geom_ribbon (aes (ymin = time + e, ymax = time - e,
    		     	  fill = direction),
                 	  alpha = 0.2, linetype = 0) +
    guides(fill=FALSE) +
    xlab ("Number of bytes") +
    ylab ("Time (us)") +
    ggtitle(title) +
    guides(colour = guide_legend (nrow = 1)) +
    theme (legend.title = element_blank (),
           legend.position = "bottom",
           legend.direction = "vertical",
           axis.text.x = element_text(angle = 45, hjust = 1))

	   if ( !is.null(scale) )
	      plot <- plot + scale_y_continuous(breaks = c(scale), limits=c(min(scale), max(scale)))

	      plot

    ggsave (f)
}

plot_bandwidth <- function (title, f, dataframe, scale=NULL) {
    # inserts error column for obtaining an 95% conf. interval
    x <- ddply (dataframe, .(nb_clusters, size), summarise, e = error ( (size / 1024 / 1024 / 1024) * nb_clusters / (time / 1000000), 0.95), bandwidth = ( (mean(size) / 1024 / 1024 / 1024) * mean(nb_clusters)) / (mean(time) / 1000000))

    plot <- ggplot (x, aes (size, bandwidth, group = factor(nb_clusters), colour = factor(nb_clusters), shape = factor(nb_clusters))) +
    theme_bw () +
    geom_point() +
    geom_line () +
    # displays nice confidence interval
    geom_ribbon (aes (ymin = bandwidth + e, ymax = bandwidth - e,
    		     	  fill = factor(nb_clusters)),
                 	  alpha = 0.2, linetype = 0) +
    guides(fill=FALSE) +
    xlab ("Number of bytes") +
    ylab ("Bandwidth (GB/s)") +
    ggtitle(title) +
    guides(colour = guide_legend (nrow = 1)) +
    theme (legend.title = element_blank (),
           legend.position = "bottom",
           legend.direction = "vertical",
           axis.text.x = element_text(angle = 45, hjust = 1))

	   if ( !is.null(scale) )
	      plot <- plot + scale_y_continuous(breaks = c(scale), limits=c(min(scale), max(scale)))

	   #    plot

    ggsave (f)
}

#------------------------------------------------------------------------------

df <- rbind(read_latency ("portal-1-1.csv"), read_latency ("portal-1-2.csv"))
df <- rbind(df, read_latency ("portal-1-4.csv"))
df <- rbind(df, read_latency ("portal-1-8.csv"))
df <- rbind(df, read_latency ("portal-1-16.csv"))

io_clusters <- df[which(df$direction == "master-slave"), ]
clusters_io <- df[which(df$direction == "slave-master"), ]

plot_bandwidth ("Portal Bandwidth IO -> Clusters", "portal_bandwith_io_clusters.pdf", io_clusters, seq(0.0, 4, 0.2))
plot_bandwidth ("Portal Bandwidth Clusters -> IO", "portal_bandwith_clusters_io.pdf", clusters_io, seq(0.0, 2, 0.2))

# plot_latency ("channel: 1 IO - 1 cluster", "channel-1-1.pdf", "channel-1-1.csv", seq(0, 14000, 1000))
# plot_latency ("channel: 1 IO - 2 clusters", "channel-1-2.pdf", "channel-1-2.csv", seq(0, 28000, 2000))
# plot_latency ("channel: 1 IO - 4 clusters", "channel-1-4.pdf", "channel-1-4.csv", seq(0, 56000, 4000))
# plot_latency ("channel: 1 IO - 8 clusters", "channel-1-8.pdf", "channel-1-8.csv", seq(0, 112000, 8000))
# plot_latency ("channel: 1 IO - 16 clusters", "channel-1-16.pdf", "channel-1-16.csv", seq(0, 224000, 16000))

plot_latency ("portal: 1 IO - 1 cluster", "portal-1-1.pdf", "portal-1-1.csv", seq(0, 20000, 2000))
plot_latency ("portal: 1 IO - 2 clusters", "portal-1-2.pdf", "portal-1-2.csv", seq(0, 20000, 2000))
plot_latency ("portal: 1 IO - 4 clusters", "portal-1-4.pdf", "portal-1-4.csv", seq(0, 20000, 2000))
plot_latency ("portal: 1 IO - 8 clusters", "portal-1-8.pdf", "portal-1-8.csv", seq(0, 20000, 2000))
plot_latency ("portal: 1 IO - 16 clusters", "portal-1-16.pdf", "portal-1-16.csv", seq(0, 20000, 2000))
