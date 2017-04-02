#################################################################
##                                                             ##
##   (c) Adeline Marinho <adelsud6@gmail.com>                  ##
##                                                             ##
##       Image Processing Division                             ##
##       National Institute for Space Research (INPE), Brazil  ##
##                                                             ##
##                                                             ##
##   R script to plot input data                               ##
##                                                             ##  
##                                             2017-03-31      ##
##                                                             ##
##                                                             ##
#################################################################

#' @title Plot Input Maps 
#' @name stilf_plot_maps_input
#' @aliases stilf_plot_maps_input
#' @author Adeline M. Maciel
#' @docType data
#'
#' @description Plot map ggplot2 for all input data
#' 
#' @usage stilf_plot_maps_input (data_tb = NULL, EPSG_WGS84 = TRUE, 
#' custom_palette = FALSE, RGB_color = NULL)
#' 
#' @param data_tb         Tibble. A tibble with values longitude and latitude and other values
#' @param EPSG_WGS84      Character. A reference coordinate system. If TRUE, the values of latitude and longitude alredy use this coordinate system, if FALSE, the data set need to be transformed
#' @param custom_palette  Boolean. A TRUE or FALSE value. If TRUE, user will provide its own color palette setting! Default is FALSE
#' @param RGB_color       Character. A vector with color names to map legend, for example, c("Green","Blue"). Default is the color brewer 'Paired'

#' @keywords datasets
#' @return Plot with input data as colored map
#' @import dplyr sp ggplot2 RColorBrewer
#' @export
#'
#' @examples \dontrun{
#' 
#' library(stilf)
#' 
#' stilf_starting_point()
#' 
#' # open a CSV file example
#' file_json = "./inst/example_json_Sinop_part.json"
#' 
#' # open file JSON
#' input_tb_raw_json <- file_json %>% 
#'   stilf_fromJSON() 
#' input_tb_raw_json
#' 
#' # plot maps input data
#' stilf_plot_maps_input(input_tb_raw_json, EPSG_WGS84 = TRUE, 
#' custom_palette = FALSE)
#' 
#' 
#'}
#'

# plot maps for input data
stilf_plot_maps_input <- function(data_tb = NULL, EPSG_WGS84 = TRUE, custom_palette = FALSE, RGB_color = NULL) { 
  
  # Ensure if parameters exists
  ensurer::ensure_that(data_tb, !is.null(data_tb), 
                       err_desc = "data_tb tibble, file must be defined!\nThis data can be obtained using stilf predicates holds or occurs.")
  ensurer::ensure_that(EPSG_WGS84, !is.null(EPSG_WGS84), 
                       err_desc = "EPSG_WGS84 must be defined, if exists values of longitude and latitude (TRUE ou FALSE)! Default is TRUE")
  ensurer::ensure_that(custom_palette, !is.null(custom_palette), 
                       err_desc = "custom_palette must be defined, if wants use its own color palette setting! Default is FALSE")
  #ensurer::ensure_that(RGB_color, custom_palette == TRUE & is.character(RGB_color), 
  #                    err_desc = "RGB_color must be defined, if custom_palette equals TRUE, then provide a list of colors with the same length its number of legend! Default is the color brewer 'Paired'")
                      # & (length(RGB_color) == length(unique(data_tb$label)))

  input_data <- data_tb
 
  # create points  
  .createPoints(input_data, EPSG_WGS84)
  
  a <- data.frame(Reduce(rbind, points_input_map.list))
  
  rownames(a) <- NULL
  a <- data.frame(a) %>% dplyr::filter(a$w != "NA")
  a$x <- as.integer(a$x)
  a$y <- as.integer(a$y)
  a$w <- as.factor(a$w)
  a$z <- as.factor(a$z)
  map_input_df <- NULL
  map_input_df <- a
  
  map_input_df <- map_input_df[order(map_input_df$w),] # order by years
  rownames(map_input_df) <- seq(length=nrow(map_input_df)) # reset row numbers
  
  # insert own colors palette
  if(custom_palette == TRUE){
    if(is.null(RGB_color) | length(RGB_color) != length(unique(data_tb$label))){
      cat("\nIf custom_palette = TRUE, a RGB_color vector with colors must be defined!")
      cat("\nProvide a list of colors with the same length of the number of legend!\n") 
    } else {
      my_palette = RGB_color  
    }
  } else {
    # more colors
    colour_count = length(unique(map_input_df$z))
    my_palette = colorRampPalette(RColorBrewer::brewer.pal(name="Paired", n = 12))(colour_count)
  } 
  
  # plot images all years
  g <- ggplot2::ggplot(map_input_df, aes(map_input_df$x, map_input_df$y)) +
        geom_raster(aes_string(fill=map_input_df$"z")) +
        scale_y_continuous(expand = c(0, 0), breaks = NULL) +
        scale_x_continuous(expand = c(0, 0), breaks = NULL) +
        facet_wrap("w") +
        coord_fixed(ratio = 1) + 
        #coord_fixed(ratio = 1/cos(mean(x)*pi/180)) +
        theme(legend.position = "bottom", strip.text = element_text(size=10)) +
        xlab("") +
        ylab("") +
        scale_fill_manual(name="Legend:", values = my_palette)
        #scale_fill_brewer(name="Legend:", palette= "Paired")

  print(g)
  
  map_input_df <<- map_input_df
  
}


# create points
.createPoints <- function(input_data, EPSG_WGS84){ 
  
  map_tb <- input_data 

  dates <- unique(lubridate::year(map_tb$end_date))
  indexLong <- which(colnames(map_tb) == "longitude")
  indexLat <- which(colnames(map_tb) == "latitude")
  indexLabel <- which(colnames(map_tb) == "label")
  
  # save points in environment
  points_input_map.list <- NULL
  points_input_map.list <<- list()
  
  for(x in 1:length(dates)){
 
    map <- dplyr::filter(map_tb, grepl(dates[x], as.character(map_tb$end_date), fixed = TRUE))
    pts <- map[c(indexLong:indexLat,indexLabel)] # long, lat and class
    colnames(pts) <- c('x', 'y', 'z')
    
    if (EPSG_WGS84 == TRUE) {
      # converte to sinusoidal projection in case values in Longitude and Latitude
      d <- data.frame("x" = pts$x, "y" = pts$y, "z" = pts$z, "w"= dates[x])
      sp::coordinates(d) <- cbind(pts$x, pts$y)  
      sp::proj4string(d) <- sp::CRS("+proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0")
      CRS.new <- sp::CRS("+proj=sinu +lon_0=0 +x_0=0 +y_0=0 +a=6371007.181 +b=6371007.181 +units=m +no_defs")
      d <- sp::spTransform(d, CRS.new)
      
    } else if (EPSG_WGS84 == FALSE) {
      # use in case data from SciDB col and row
      d <- data.frame(x=pts$x, y=pts$y, z=pts$z, w=dates[x])
      sp::coordinates(d) <- cbind(pts$x, pts$y)  
    } else {
      stop("FALSE/TRUE")
    }
    
    pts1 <- as.data.frame(d)
    colnames(pts1) <- c('x1', 'y1', 'z', 'w', 'x', 'y')
    pts1 <- data.frame(pts1$x,pts1$y,pts1$z,pts1$w,pts1$x1,pts1$y1)
    names(pts1)[1:6] = c('x', 'y', 'z','w','x1', 'y1')
    points_input_map.list[[paste("pts_",dates[x], sep = "")]] <<- pts1

  }
  
}  




