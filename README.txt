MATLAB TFT DATA ANALYSIS TOOLKIT
This collection of MATLAB scripts provides a workflow for importing, visualizing, and batch-processing Thin-Film Transistor (TFT) IV curve data from two different data format (.hpg or .xlsx formats).

CORE WORKFLOW
The workflow is a two-step process:
1. Import Data:
Use one of the Importer scripts to parse your raw data folders. This will consolidate all measurements into a single .mat file (e.g., My_Experiment_Data.mat) containing a masterTable.
   * IV_Curve_HPG_Importer.m (for .hpg files from HP 4145B)
   * IV_Curve_XLSX_Importer.m (for .xlsx files from B2902B)
   2. Plot Data:
Use the generated .mat file as the input for the plotting scripts.
      * IV_Curve_Plotter.m: Interactively load a .mat file and generate plots for specific devices or parameters in the MATLAB figure window.
      * IV_Curve_Plot_Saver.m: Batch-process a .mat file to save all possible plot combinations (by device, by parameter) as .png image files in a structured output folder.
      * IV_Curve_Plot_Saver_Par.m: Use for batch processing more than 100 plots at a time.

REQUIRED FOLDER STRUCTURES
The importer scripts are very specific about how your data must be organized.

1. Folder Structure for .hpg Data
This format, used by IV_Curve_HPG_Importer.m, expects a 4-level nested structure. The parameter (e.g., VG=0) is defined by the name of the folder containing the .hpg files.
      * Level 1: A top-level folder containing all your devices.
      * Level 2: A folder for each individual Device.
      * Level 3: Output and Transfer test type folders.
      * Level 4: A folder for each parameter (e.g., VG=0, VD=5). The name of this folder is what will be used in the plot legends.
      * Files: The raw .hpg files are inside the parameter folders and should be numbered (same way SaveScreens2.ahk names the files).
Example Structure (.hpg):
My_HPG_Experiment/
|
+-- Device_A/
| |
| +-- Output/
| | +-- VG=0/
| | | +-- 1.hpg
| | | +-- 2.hpg
| | | +-- ...
| | |
| | +-- VG=-10/
| | +-- 1.hpg
| | +-- ...
| |
| +-- Transfer/
| +-- VD=1/
| | +-- 1.hpg
| | +-- ...
| |
| +-- VD=5/
| +-- 1.hpg
| +-- ...
|
+-- Device_B/
|
+-- Output/
| +-- VG=0/
| | +-- ...
| +-- ...
|
+-- Transfer/
+-- VD=1/
| +-- ...
+-- ...

2. Folder Structure for .xlsx Data
This format, used by IV_Curve_XLSX_Importer.m, is flatter. The parameter is not defined by a folder name, but is instead read from the data inside the .xlsx file (specifically, by finding the VDS or VG values in the data, which starts at row 120).
      * Level 1: A top-level folder containing all your devices.
      * Level 2: A folder for each individual Device.
      * Level 3: Output and Transfer test type folders.
      * Files: The raw .xlsx files are placed directly inside the Output and Transfer folders. Names do not matter.
Note: The script will automatically skip any temporary Excel files it finds (e.g., ~$my_data.xlsx).
Example Structure (.xlsx):
My_XLSX_Experiment/
|
+-- 26062025_Etched/
| |
| +-- Output/
| | +-- 01_measurement.xlsx
| | +-- 02_measurement.xlsx
| | +-- ...
| |
| +-- Transfer/
| +-- 01_transfer_data.xlsx
| +-- ...
|
+-- 27062025_Annealed/
| |
| +-- Output/
| | +-- some_file_name.xlsx
| | +-- ...
| |
| +-- Transfer/
| |+-- another_file_name.xlsx
| |+-- ...