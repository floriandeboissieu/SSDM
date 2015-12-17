#' @include checkargs.R
#' @importFrom shiny incProgress
#' @importFrom raster raster stack res extent crop reclassify as.factor
NULL

#'Load environmental variables
#'
#'Function to load environmental variables in the form of rasters to perform
#'\code{\link{modelling}}, \code{\link{ensemble_modelling}} or
#'\code{\link{stack_modelling}}.
#'
#'@param path character. Path to the directory that contains the environmental variables
#'  files.
#'@param files character. Files containing the environmental variables If NULL
#'  (default) all files present in the path in the selected format will
#'  be loaded.
#'@param format character. Format of environmental variables files
#'  (including .grd, .tif, .asc, .sdat, .rst, .nc, .tif, .envi, .bil, .img).
#'@param factors character. Specify whether an environmental variable is a categorical variable.
#'@param Norm logical. If set to true, normalizes environmental variables between 0 and 1.
#'@param tmp logical. If set to true, rasters are
#'  read in temporary file avoiding to overload the random access memory. But
#'  beware: if you close R, temporary files will be destroyed.
#'@param verbose logical. If set to true, allows the function to print text in the
#'  console.
#'@param GUI logical. Don't take that argument into account (parameter for the
#'  user interface).
#'
#'@return A stack containing the environmental rasters (normalized or
#'  not).
#'
#' @examples
#'\dontrun{
#' load.var(path)
#'}
#'
#'@seealso \code{\link{load_occ}} to load occurrences.
#'
#'@export
load_var <- function (path = getwd(), files = NULL,
                      format = c('.grd','.tif','.asc','.sdat','.rst','.nc','.tif','.envi','.bil','.img'),
                      factors = NULL, Norm = T, tmp = T, verbose = T, GUI = F) {
  # Check arguments
  .checkargs(path = path, files = files, format = format, factors = factors,
             Norm = Norm, tmp = tmp, verbose = verbose, GUI = GUI)

  # pdir = getwd()
  if(verbose) {cat('Variables loading \n')}
  # setwd(path)
  Env = stack()

  # Rasters loading
  files.null = files
  if (is.null(files)) {files.null = T} else {files.null = F}
  for (j in 1:length(format)) {
    if(files.null) {
      files = list.files(path = path, pattern = paste0('.',format[j],'$'))
    }
    if (length(files) > 0) {
      for (i in 1:length(files)){
        if(!is.null(path)){file = paste0(path,'/',files[[i]])} else {file = files[i]}
        Raster = raster(file)
        # Extent and resolution check
        reso = res(Raster)
        extent = extent(Raster)
        if (j == 1  && i == 1) {
          resostack = reso
          extentstack = extent
        } else {
          resostack[1] = max(reso[1], resostack[1])
          resostack[2] = max(reso[2], resostack[2])
          # Extent and resolution adpatation
          extentstack@xmin = max(extentstack@xmin, extent@xmin)
          extentstack@xmax = min(extentstack@xmax, extent@xmax)
          extentstack@ymin = max(extentstack@ymin, extent@ymin)
          extentstack@ymax = min(extentstack@ymax, extent@ymax)
        }
        if(GUI) {incProgress(1/(length(files)*3), detail = paste(i,'loaded'))}
      }
    }
  }

  if(verbose) {cat('Variables treatment \n')}

  if(verbose) {cat('   resolution and extent adaptation...')}
  for (j in 1:length(format)) {
    if(files.null) {
      files = list.files(path = path, pattern = paste0('.',format[j],'$'))
    }
    if (length(files) > 0) {
      for (i in 1:length(files)){
        if(!is.null(path)){file = paste0(path,'/',files[[i]])} else {file = files[i]}
        Raster = raster(file)
        Raster = reclassify(Raster, c(-Inf,-900,NA))
        Raster = crop(Raster, extentstack)
        names(Raster) = as.character(strsplit(files[i],format[j]))
        if (names(Raster) %in% factors) {
          Raster = raster::as.factor(Raster)
          row.names(Raster@data@attributes[[1]]) = Raster@data@attributes[[1]]$ID
          fun = max
        } else {fun = mean}
        if (round(res(Raster)[1], digits = 6) != round(resostack[1], digits = 6) || round(res(Raster)[2], digits = 6) != round(resostack[2], digits = 6)) {
          cat(c((res(Raster)[1]/resostack[1]),(res(Raster)[2]/resostack[2])))
          Raster = aggregate(Raster, fact = (res(Raster)[1]/resostack[1]), fun = fun)
        }
        Env = stack(Env, Raster)
        if(GUI) {incProgress((1/(length(files)*3)), detail = paste(i,'treated'))}
      }
    }
  }
  if(verbose) {cat('   done... \n')}


  # Normalizing variable
  if (Norm) {
    if(verbose) {cat('   normalizing continuous variable \n\n')}
    for (i in 1:length(Env@layers)) {
      #For not categorical variable
      if (!Env[[i]]@data@isfactor) {
        Env[[i]] = Env[[i]]/Env[[i]]@data@max
      }
      if(GUI) {incProgress((1/length(Env@layers)/3), detail = paste(i,'normalized'))}
    }
  }

  # setwd(pdir)

  # Temporary files
  if (tmp) {
    path = get("tmpdir",envir=.PkgEnv)
    if (!("./.rasters" %in% list.dirs())) (dir.create(paste0(path,'/.rasters')))
    for (i in 1:length(Env@layers)) {Env[[i]] = writeRaster(Env[[i]], paste0(path,"/.rasters/", names(Env[[i]])), overwrite = T)}
  }

  return(Env)
}