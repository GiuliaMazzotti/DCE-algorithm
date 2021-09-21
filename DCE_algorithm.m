%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% DCE ALGORITHM 
% DESCRIPTION 
%   This script includes the algorithm to compute non-directional and 
%   directional distances to canopy edge (DCE), presented in the
%   publication refernced below. 
%   The script includes 
%   1. A wrapper, which serves to define and load in user data, call the 
%      function to compute DCE and save the results
%   2. The main function to calculate directional and non-directional DCE 
%   3. Subfunctions to load and save the ascii grids called by the wrapper
%   4. The subfunction including the running mean filter called by the 
%      main DCE function
% 
% IMPLEMENTATION
%   Giulia Mazzotti and Tobias Jonas
%   WSL Institute for Snow and Avalanche Research SLF, Davos
%   contact: giulia.mazzotti@slf.ch
%   v1.1, 2019-01-01: First release
%   v1.2, 2019-11-14: Fixed development bugs (saving commands,
%         inconsistencies in grid sizes and dce values due to resizing) 
% 
% USER SETTINGS
%   Adapt path and file definitions as well as parameter settings in the 
%   wrapper under 'user settings'
% 
% INPUT DATA
%   This script requires a canopy height model (CHM) in ASCII format; 
%   Note that the CHM is resampled to a 1m resolution within the DCE
%   computation function, and converted back to the original resolution
%   thereafter; this is to ensure that the DCE value assigned to each pixel
%   corresponds to a distance in metres.
%   Also note that some NaN values are generated at the edge of the CHM 
%   during the smoothing procedure. The input CHM should therefore include  
%   a buffer.
% 
% OUTPUT
%   DCE grids in ascii format are saved in the user-defined directory. The
%   resolution and size of the DCE grids matches the CHM input.
%
% USAGE
%   Provide user input
%   Run script from the command line of Matlab
%   Subfunctions called by this script are included below the wrapper
%   This script was developed using Matlab 2016b 
%
% REFERENCE
%   Mazzotti, G., Currier, W. R., Deems, J. S., Pflug, J. M., Lundquist, 
%   J. D., and Jonas, T. (2019) Revisiting Snow Cover Variability and Canopy 
%   Structure within Forest Stands: Insights from Airborne Lidar Data. 
%   Water Resources Research, 55(7), 6198-6216. 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% WRAPPER 
% USER INPUT
% 1. Path and file definitions
% Directory of input CHM
infolder = 'C:\dce_input';
infolder = 'H:\code_development\forest_snow\DCE-algorithm\example_input';
% Directory of output files generated by this script
outfolder = 'C:\dce_output';
outfolder = 'H:\code_development\forest_snow\DCE-algorithm\example_output';
% Filename of input CHM grid in ascii format. This should either be a
% canopy height model, or a binary canopy raster with 1 = canopy pixels and
% 0 = open pixels. 
chm_infile = 'chm_test.asc'; 
% Output DCE grids filenames (can be left empty if the respective metric
% should not be computed)
dce_outfile = 'dce_test_out.asc'; 
ndce_outfile = 'ndce_test_out.asc'; 
sdce_outfile = 'sdce_test_out.asc'; 

% 2. Parameter settings
% Specify if CHM input is to be binarized (binarize_chm = 1) based on the
% threshold specified by the parameter height_cut. If binary CHM is
% provided, set binarize_chm = 0
binarize_chm = 0;
% Height cutoff: canopy height threshold used in the CHM binarization; a 
% height cutoff of 2m is recommended and commonly used in literature. Units
% should be consistent with the canopy height model used as input. 
height_cut = 2;
% Step number: number of iterations performed in the DCE algorithm, see the
% description of the main function below. This number should not exceed 300
% (internal limit of the smoothing function), and should be chosen large
% enough to fill all larger canopy gaps in the forest stand of interest
% (i.e. larger than half the diameter of the gap - e.g. a step nr of 70 
% should be sufficient if the largest gaps have a 100m diameter. However,
% some applications may favor a smaller number (e.g. canopy edge
% delineation).
step_nr = 450;
% Mode of DCE calculation according to description in main function below 
% set to 'all' to compute DCE, DCE-south and DCE-north;
% set to 'simple' to compute non-directional DCE only
% set to 'directional' to compute directional DCEs only
% east, west and other DCEs are not yet implemented in this script but
% could easily be added. 
mode = 'all';

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% CALCULATIONS
% 1. load CHM data
chm_grid = load_ascii_grid(fullfile(infolder,chm_infile));

% 2. binarize CHM based on height threshold height_cut
chm_bin = chm_grid; 
if binarize_chm
  chm_bin.data(chm_grid.data <= height_cut ) = 0; 
  chm_bin.data(chm_grid.data > height_cut) = 1;   
end

% 3. call function to calculate DCE
[dce_grid, ndce_grid, sdce_grid] = calcDCE(chm_bin,mode,step_nr);

% 4. save data
if strcmpi(mode,'all') || strcmpi(mode,'simple')
  save_ascii_grid(dce_grid, fullfile(outfolder,dce_outfile));
end
if strcmpi(mode,'all') || strcmpi(mode,'directional')
  save_ascii_grid(ndce_grid, fullfile(outfolder,ndce_outfile));
  save_ascii_grid(sdce_grid, fullfile(outfolder,sdce_outfile));
end 
% end of wrapper
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% MAIN FUNCTION:CALCULATE DCE 
function [dce_output, ndce_output, sdce_output] = calcDCE(chm_input,mode,step_nr)
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  % DESCRIPTION
  %  This function computes non-directional and directional (N, S) DCE
  %  (distance to the canopy edge) grids from a binarized CHM. See 
  %  Mazzotti et al. (manuscript submitted to WRR, January 2019) 
  %  for a description of the algorithm / the  parameters.
  % 
  % IMPLEMENTATION
  %  Giulia Mazzotti and Tobias Jonas
  %  WSL Institute for Snow and Avalanche Research SLF, Davos
  %  v1.1, 2019-01-01
  %
  % INPUTS
  % 1. chm_input: binarized chm as struct
  % 2. mode: select which DCE grids to compute
  %   'all': computes the non-directional, the north- and the south- DCE
  %   grids
  %   'simple': computes the non-directional DCE grid only
  %   'directional': computes the north- and south- DCE grids only 
  % 3. step_nr: number of smoothing iterations (max 300)
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
 
  % CALCULATIONS 
  % 1. Convert to 1m resolution 
  chm_data = chm_input; 
  chm_data.ncols = ceil(chm_input.ncols*chm_input.cellsize);
  chm_data.nrows = ceil(chm_input.nrows*chm_input.cellsize);
  chm_data.cellsize = 1; 
  chm_data.data = imresize(chm_input.data,chm_input.cellsize,'bilinear');
  chm_data.data(chm_data.data >= 0.5) = 1; 
  chm_data.data(chm_data.data < 0.5) = 0;     
  
  % 2. Calculate non-directional DCE 
  if strcmpi(mode,'all') || strcmpi(mode,'simple')
    % initialize DCE of open pixels: matrix with -1 = canopy, 0 = open 
    opnclasses = -chm_data.data;   
    % initialize DCE of canopy pixels: matrix with -1 = open, 0 = canopy 
    canclasses = chm_data.data-1;  
    % input to first step: binary chm grid with 1 = canopy pixels, 0 = open
    % pixels
    ingrid_opn = chm_data.data;
    ingrid_can = -(chm_data.data-1);
    % iterative edge detection for open and canopy pixel DCE separately 
    for ssx = 1: step_nr 
      % generate smoothed chm
      chmsm_opn = quickrm(ingrid_opn,1,'disk'); 
      chmsm_can = quickrm(ingrid_can,1,'disk'); 
      % detect edges and attribute value = step nr. 
      opnclasses(intersect(find(opnclasses == 0),find(chmsm_opn > 0 ))) = ssx;
      canclasses(intersect(find(canclasses == 0),find(chmsm_can > 0 ))) = ssx;
      % smoothed and re-binarized grids create input for next iteration;
      % use max filter for open and min filter for canopy pixels
      ingrid_opn = chmsm_opn;
      ingrid_opn(chmsm_opn > 0) = 1; 
      ingrid_can = chmsm_can;
      ingrid_can(chmsm_can > 0) = 1; 
    end 
    % set all canopy pixels (open pixels) to 0 in opn (can) DCE matrices 
    % (to allow merging of DCE of canopy and open pixels later on)
    opnclasses(opnclasses < 0) = 0; 
    canclasses(canclasses < 0) = 0;
    % merge DCE of canopy and open pixels 
    dceall_grid = canclasses-opnclasses;
    % set values that have not been defined to NaN
    dceall_grid(dceall_grid == 0) = nan;
    % initialize output struct
    dce_output = chm_input;
    % re-adapt to original size, ensuring that DCE value corresponds to
    % distance to canopy edge in metres 
    dce_output.data = imresize(dceall_grid,1/chm_input.cellsize,'bilinear');
    if size(dce_output.data,1) ~= dce_output.nrows
      dce_output.data = dce_output.data(1:dce_output.nrows,:);
    end
    if size(dce_output.data,2) ~= dce_output.ncols
      dce_output.data = dce_output.data(:,1:dce_output.ncols);
    end
    dce_output.data = -1*dce_output.data; 
    % visualize
    figure; imagesc(dceall_grid); 
  end 
  
  % 3. Calculate directional DCE 
  if strcmpi(mode,'all') || strcmpi(mode,'directional')
    % DCE-north (for north-exposed edges) 
    % initialize
    opnclasses = -chm_data.data;
    canclasses = chm_data.data-1;     
    ingrid_opn = chm_data.data;
    ingrid_can = -(chm_data.data-1);
    for ssx = 1: step_nr 
      % smoothing with asymmetric kernel
      chmsm_opn = quickrm(ingrid_opn,1,'disk_north'); 
      chmsm_can = quickrm(ingrid_can,1,'disk_south'); 
      opnclasses(intersect(find(opnclasses == 0),find(chmsm_opn > 0 ))) = ssx;
      canclasses(intersect(find(canclasses == 0),find(chmsm_can > 0 ))) = ssx;
      % compute input to next smoothing iteration
      ingrid_opn = chmsm_opn;
      ingrid_opn(chmsm_opn > 0) = 1; 
      ingrid_can = chmsm_can;
      ingrid_can(chmsm_can > 0) = 1; 
    end
    % merge DCE-north of open and canopy pixels
    ndceall_grid = nan(size(chm_data.data)); 
    ndceall_grid(opnclasses > 0) = -opnclasses(opnclasses > 0); 
    ndceall_grid(canclasses > 0) = canclasses(canclasses > 0); 
    ndceall_grid(canclasses == 0) = NaN;
    ndceall_grid(opnclasses == 0) = NaN;
    ndce_output = chm_input; 
    ndce_output.data = imresize(ndceall_grid,1/chm_input.cellsize,'bilinear');
    if size(ndce_output.data,1) ~= ndce_output.nrows
      ndce_output.data = ndce_output.data(1:ndce_output.nrows,:);
    end
    if size(ndce_output.data,2) ~= ndce_output.ncols
      ndce_output.data = ndce_output.data(:,1:ndce_output.ncols);
    end
    ndce_output.data = -1*ndce_output.data; 
    figure; imagesc(ndce_output.data); 
 
    % DCE-south (for sounorth-exposed edges) 
    opnclasses = -chm_data.data;
    canclasses = chm_data.data-1; 
    ingrid_opn = chm_data.data;
    ingrid_can = -(chm_data.data-1);
    for ssx = 1: step_nr 
      chmsm_opn = quickrm(ingrid_opn,1,'disk_south'); 
      chmsm_can = quickrm(ingrid_can,1,'disk_north');    
      opnclasses(intersect(find(opnclasses == 0),find(chmsm_opn > 0 ))) = ssx;
      canclasses(intersect(find(canclasses == 0),find(chmsm_can > 0 ))) = ssx;
      ingrid_opn = chmsm_opn;
      ingrid_opn(chmsm_opn > 0) = 1; 
      ingrid_can = chmsm_can;    
      ingrid_can(chmsm_can > 0) = 1;     
    end
    sdceall_grid = nan(size(chm_data.data)); 
    sdceall_grid(opnclasses > 0) = -opnclasses(opnclasses > 0); 
    sdceall_grid(canclasses > 0) = canclasses(canclasses > 0);  
    sdceall_grid(canclasses == 0) = NaN;
    sdceall_grid(opnclasses == 0) = NaN;
    sdce_output = chm_input; 
    sdce_output.data = imresize(sdceall_grid,1/chm_input.cellsize,'bilinear');
    if size(sdce_output.data,1) ~= sdce_output.nrows
      sdce_output.data = sdce_output.data(1:sdce_output.nrows,:);
    end
    if size(sdce_output.data,2) ~= sdce_output.ncols
      sdce_output.data = sdce_output.data(:,1:sdce_output.ncols);
    end
    sdce_output.data = -1*sdce_output.data; 
    figure; imagesc(sdce_output.data);
  end
  
  % empty outputs depending on mode selection
  if strcmpi(mode,'simple')
    sdce_output = [];
    ndce_output = [];
  elseif strcmpi(mode,'directional')
    dce_output = [];
  end
  
end
% end of main dce function
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% SUBFUNCTION: IMPORT ASCII GRID
function answer = load_ascii_grid(varargin)
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  % DESCRIPTION:
  %   loads grid in ASCII format
  %
  % IMPLEMENTATION:
  %   by TJ in November-2014 @ SLF Switzerland
  %   last changes 01.01.2019 / GM
  %
  % INPUT:
  %   prompts the user to select input file in case of nargin = 0
  %   else varargin{1} = path/file to grid to open
  %   supported formats: ASCII GIS
  % 
  % OUTPUT: grid structure with fields: ncols (number of columns), nrows
  %   (number of rows), cellsize (grid cell resolution), NODATA_value
  %   (value corresponding to NaN pixels), data (data matrix)
  %   or error message (char)
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  
  % CALCULATIONS
  answer = [];
  if nargin == 0
    [file,path] = uigetfile('*.*','Load MetDataWizard grid file');
    if isequal(file,0) || isequal(path,0)
      return;
    else
      filepath = fullfile(path,file);
    end
  else
    filepath = varargin{1};
  end
  fid = fopen(filepath,'r');
  if fid == -1
    answer = 'File inaccessible';
    return;
  end
  %reading grid according to ASCII GIS format
  answer = 'Error reading grid.ncols';  
  grid.ncols = fgets(fid);
  fix = strfind(lower(grid.ncols),'ncols');
  if isempty(fix)
    error(' ');
  end
  hlpstr = [grid.ncols(1:fix-1) grid.ncols(fix+5:end)];
  grid.ncols = str2num(hlpstr);
  answer = 'Error reading grid.nrows';  
  grid.nrows = fgets(fid);
  fix = strfind(lower(grid.nrows),'nrows');
  if isempty(fix)
    error(' ');
  end
  hlpstr = [grid.nrows(1:fix-1) grid.nrows(fix+5:end)];
  grid.nrows = str2num(hlpstr);
  answer = 'Error reading grid.xllcorner';  
  grid.xllcorner = fgets(fid);
  fix = strfind(lower(grid.xllcorner),'xllcorner');
  if isempty(fix)
    error(' ');
  end
  hlpstr = [grid.xllcorner(1:fix-1) grid.xllcorner(fix+9:end)];
  grid.xllcorner = str2num(hlpstr);
  answer = 'Error reading grid.yllcorner';  
  grid.yllcorner = fgets(fid);
  fix = strfind(lower(grid.yllcorner),'yllcorner');
  if isempty(fix)
    error(' ');
  end
  hlpstr = [grid.yllcorner(1:fix-1) grid.yllcorner(fix+9:end)];
  grid.yllcorner = str2num(hlpstr);
  answer = 'Error reading grid.cellsize';  
  grid.cellsize = fgets(fid);
  fix = strfind(lower(grid.cellsize),'cellsize');
  if isempty(fix)
    error(' ');
  end
  hlpstr = [grid.cellsize(1:fix-1) grid.cellsize(fix+8:end)];
  grid.cellsize = str2num(hlpstr);
  answer = 'Error reading grid.NODATA_value';  
  grid.NODATA_value = fgets(fid);
  fix = strfind(lower(grid.NODATA_value),'nodata_value');
  if isempty(fix)
    error(' ');
  end
  hlpstr = [grid.NODATA_value(1:fix-1) grid.NODATA_value(fix+12:end)];
  grid.NODATA_value = str2num(hlpstr);
  answer = 'Error reading grid.data';  
  formatstr = '';
  for cix = 1:grid.ncols
    formatstr = [formatstr '%f'];
  end
  data = textscan(fid,formatstr,grid.nrows);
  for cix = 1:grid.ncols
    grid.data(:,cix) = data{cix};
  end
  grid.data = flipud(grid.data); 
  clear data;
  fclose(fid);
  answer = grid;
end
% end of ascii grid import subfunction
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% SUBFUNCTION: SAVE ASCII GRID
function answer = save_ascii_grid(grid,varargin)
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  % DESCRIPTION:
  %   saves struct to file in ascii format
  %
  % IMPLEMENTATION:
  %   by TJ in November-2014 @ SLF Switzerland
  %   last changes 01.01.2019 / GM
  %
  % INPUT:
  %   grid: grid structure 
  %   prompts the user to select output file in case of nargin = 1
  %   else varargin{2} = path/file to grid to open
  %   supported formats: .mat / ASCII GIS
  %
  % OUTPUT: empty if succesful or error message (char)
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  
  % CALCULATIONS
  answer = [];
  if nargin == 1
    [file,path] = uiputfile('*.*','Save MetDataWizard grid file');
    if isequal(file,0) || isequal(path,0)
      return;
    else
      filepath = fullfile(path,file);
    end
  else
    filepath = varargin{1};
  end
  try 
    errmsg = 'The file is inaccessible';
    fid = fopen(filepath,'w');
    if fid == -1
      error(' ');
    end
    errmsg = 'Error while processing map';
    ncols = grid.ncols;
    ndval = grid.NODATA_value;
    data  = grid.data;
    data(isnan(data)) = ndval;
    errmsg = 'Error while writing grid header';
    fprintf(fid,'%s\t','ncols');
    fprintf(fid,'%04.0f\n',grid.ncols);
    fprintf(fid,'%s\t','nrows');
    fprintf(fid,'%04.0f\n',grid.nrows);
    fprintf(fid,'%s\t','xllcorner');
    fprintf(fid,'%8.2f\n',grid.xllcorner);
    fprintf(fid,'%s\t','yllcorner');
    fprintf(fid,'%8.2f\n',grid.yllcorner);
    fprintf(fid,'%s\t','cellsize');
    fprintf(fid,'%8.2f\n',grid.cellsize);
    fprintf(fid,'%s\t','NODATA_value');
    fprintf(fid,'%4.0f\n',grid.NODATA_value);
    errmsg = 'Error while writing grid data';
    formatstr = [];
    for cix = 1:ncols - 1
      formatstr = [formatstr '%g\t'];    
    end
    formatstr = [formatstr '%g\n'];
    fprintf(fid,formatstr,(flipud(data))');
    fclose(fid);
    return;
  catch
    answer = errmsg;
  end
end
% end of subfunction to save ascii grid
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% SUBFUNCTION: RUNNING MEAN FILTER
function outgrid = quickrm(ingrid,radius,type)
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  % DESCRIPTION
  % This function includes a smoothing routine that applies a running mean  
  % filter based on a convolution, where the smoothing window is 
  % characterized by a kernel. 
  % 
  % IMPLEMENTATION
  % Tobias Jonas and Giulia Mazzotti
  % WSL Institute for Snow and Avalanche Research SLF, Davos
  % v1.1, 2019-01-01
  %
  % INPUT: 
  % 1. ingrid: grid to be smoothed
  % 2. radius: radius of smoothing kernel
  % 3. type: weighting option
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  
  % CALCULATIONS 
  % check input arguments / set default values where necesary
  if nargin == 0
    error('provide input argument')
  elseif nargin == 1
    radius = 1;
    type   = 'square';
  elseif nargin == 2
    type   = 'square';
  end
  if abs(round(radius) - radius) > 0
    error('radius should be an integer')
  elseif radius <= 0
    error('radius should be a positive integer')
  elseif radius > 500
    error('radius should not exceed 300')
  end

  % evaluated weighting kernel
  switch lower(type)
  case 'square'
    kernel = ones(radius*2+1,radius*2+1);
  case '1-disk'
    kernel = [0.5 1 0.5; 1 1 1; 0.5 1 0.5];
  case 'disk'
    [x,y] = meshgrid([-radius:radius],[-radius:radius]);
    r = sqrt(x.^2+y.^2);
    kernel = double(r <= radius);
  case 'disk_south'
    [x,y] = meshgrid([-radius:radius],[-radius:radius]);
    r = sqrt(x.^2+y.^2);
    kernel = double(r <= radius & y < 0);
  case 'disk_north'
    [x,y] = meshgrid([-radius:radius],[-radius:radius]);
    r = sqrt(x.^2+y.^2);
    kernel = double(r <= radius & y > 0);
  case 'disk_west'
    [x,y] = meshgrid([-radius:radius],[-radius:radius]);
    r = sqrt(x.^2+y.^2);
    kernel = double(r <= radius & x < 0);
  case 'disk_east'
    [x,y] = meshgrid([-radius:radius],[-radius:radius]);
    r = sqrt(x.^2+y.^2);
    kernel = double(r <= radius & x > 0);
  case 'cols'
    kernel = ones(radius*2+1,1);
  case 'rows'
    kernel = ones(1,radius*2+1);
  otherwise
    error('input argument for type unknown')
  end
  kernel    = kernel./(sum(kernel(:)));
  
  % calculate running mean
  outgrid    = nan(size(ingrid));
  switch lower(type)
  case {'square','disk','disk_south','disk_north','disk_west','disk_east','1-disk'}
    outgrid(1+radius:end-radius,1+radius:end-radius) = conv2(ingrid,kernel,'valid');
  case 'cols'
    outgrid(1+radius:end-radius,:) = conv2(ingrid,kernel,'valid');
  case 'rows'
    outgrid(:,1+radius:end-radius) = conv2(ingrid,kernel,'valid');
  otherwise
    error('input argument for type unknown')
  end
end
% end of running mean filter subfunction
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
