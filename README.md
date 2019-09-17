# DCE-algorithm
The DCE (distance to canopy edge) algorithm is a MATLAB-based tool for the analysis of two-dimensional forest canopy structure. Using a binarized canopy raster (ASCII file) as input, it computes non-directional and directional distances to the canopy edge for every raster pixel. In principle, the algorithm consists of an iterative edge-detection routine run on the binary canopy map, where the pixels adjacent to the canopy edge are tagged and the process iterated to detect cells a step further away from the canopy edge. Thereby, pixels at the transition from canopy to open pixels are identified by applying a symmetric two‐dimensional moving average filter with a 3 × 3‐m window. 

The methodology was developed in a study that relates forest snow distribution to the spatial layout of canopy element. It is presented and outlined in detail in the following publication: 
Mazzotti, G., Currier, W. R., Deems, J. S., Pflug, J. M., Lundquist, J. D., and Jonas, T. (2019) Revisiting Snow Cover Variability and Canopy Structure within Forest Stands: Insights from Airborne Lidar Data. Water Resources Research, 55(7), 6198-6216. 

### Authors
Giulia Mazzotti and Tobias Jonas
WSL Institute for Snow and Avalanche Research
Davos Dorf, Switzerland
January 2019

## Getting started
The DCE algorithm consists of a single MATLAB script that incorporates all auxiliary functions. It is run from the command line of MATLAB. User settings are specified in the respective code section (c.f. documentation within the code). 

### Input data
The DCE-algorithm is run on a binary canopy map. However, it also accepts a canopy height model (CHM), which is then converted to a binary raster based on a user-define threshold. The input raster has to be provided in ASCII format. 

### Output files 
The algorithm can output different maps of non-directional and directional distance to canopy edge, based on specifications in the user settings. The output files are generated in ASCII format. 

