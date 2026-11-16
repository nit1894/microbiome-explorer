composition_plot <- function(data, group_variable = "SampleID") {
  if (!group_variable %in% names(data)) group_variable <- "SampleID"
  data$DisplayGroup <- as.character(data[[group_variable]])
  ggplot2::ggplot(data, ggplot2::aes(
    x = SampleID, y = RelativeAbundance, fill = Taxon,
    text = paste0("Sample: ", SampleID, "<br>", group_variable, ": ", DisplayGroup,
                  "<br>Taxon: ", Taxon, "<br>Relative abundance: ",
                  scales::percent(RelativeAbundance, accuracy = 0.1))
  )) +
    ggplot2::geom_col(width = 0.86) +
    ggplot2::facet_grid(~DisplayGroup, scales = "free_x", space = "free_x") +
    ggplot2::scale_y_continuous(labels = scales::percent_format()) +
    ggplot2::labs(x = NULL, y = "Relative abundance", fill = "Taxon") +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 60, hjust = 1),
                   panel.grid.major.x = ggplot2::element_blank(),
                   legend.position = "bottom")
}

alpha_plot <- function(data, metric = "Shannon", group_variable = NULL) {
  if (is.null(group_variable) || !group_variable %in% names(data)) group_variable <- "SampleID"
  data$Group <- as.factor(data[[group_variable]])
  ggplot2::ggplot(data, ggplot2::aes(x = Group, y = .data[[metric]], color = Group,
                                    text = paste0("Sample: ", SampleID, "<br>", metric, ": ",
                                                  round(.data[[metric]], 3)))) +
    ggplot2::geom_boxplot(outlier.shape = NA, alpha = 0.15) +
    ggplot2::geom_jitter(width = 0.13, size = 2.8, alpha = 0.85) +
    ggplot2::labs(x = group_variable, y = metric, color = group_variable) +
    ggplot2::theme_minimal(base_size = 13) +
    ggplot2::theme(legend.position = "none", axis.text.x = ggplot2::element_text(angle = 35, hjust = 1))
}

pcoa_plot <- function(ordination, color_variable = NULL, shape_variable = NULL) {
  data <- ordination$points
  color_variable <- if (!is.null(color_variable) && color_variable %in% names(data)) color_variable else "SampleID"
  shape_variable <- if (!is.null(shape_variable) && shape_variable %in% names(data)) shape_variable else NULL
  data$ColorGroup <- as.factor(data[[color_variable]])
  if (!is.null(shape_variable)) data$ShapeGroup <- as.factor(data[[shape_variable]])
  mapping <- if (is.null(shape_variable)) {
    ggplot2::aes(x = PCoA1, y = PCoA2, color = ColorGroup,
                 text = paste0("Sample: ", SampleID, "<br>", color_variable, ": ", ColorGroup))
  } else {
    ggplot2::aes(x = PCoA1, y = PCoA2, color = ColorGroup, shape = ShapeGroup,
                 text = paste0("Sample: ", SampleID, "<br>", color_variable, ": ", ColorGroup,
                               "<br>", shape_variable, ": ", ShapeGroup))
  }
  ggplot2::ggplot(data, mapping) +
    ggplot2::geom_point(size = 3.4, alpha = 0.9) +
    ggplot2::labs(
      x = sprintf("PCoA 1 (%.1f%%)", ordination$variance[[1]]),
      y = sprintf("PCoA 2 (%.1f%%)", ordination$variance[[2]]),
      color = color_variable,
      shape = shape_variable
    ) +
    ggplot2::theme_minimal(base_size = 13) +
    ggplot2::theme(legend.position = "bottom")
}
