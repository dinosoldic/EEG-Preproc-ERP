# EEG Data Processing Project

## Project Overview
This project provides a set of functions for preprocessing, plotting, and exporting EEG data for further analysis in SPSS. It utilizes the EEGLAB toolbox to facilitate these tasks and offers two primary methods for preprocessing data: the standard `eegPreproc` function and the alternative `unfoldERPData` function based on [Unfold Toolbox](https://github.com/unfoldtoolbox/unfold) for handling overlapping Event-Related Potentials (ERPs).

## Benefits
- Streamlines the EEG data analysis process.
- Integrates seamlessly with EEGLAB for effective data handling.
- Outputs data in a format compatible with SPSS for statistical analysis.

## Prerequisites
- MATLAB with the EEGLAB and Unfold toolboxes installed.
- Basic understanding of EEG data analysis and MATLAB programming.

## Usage
1. **Preprocessing:** Use the `eegPreproc` function to preprocess your EEG data. This is the standard method for data preprocessing.
   Alternatively, use `unfoldERPData` when you need to handle overlapping ERPs. This method preprocesses the data with the same underlying preprocessing steps but includes extra handling to separate overlapping ERPs.
2. **Plotting ERP:** Use the `eegPlotERP` function to visualize the Event-Related Potentials (ERPs).
3. **Exporting to SPSS:** Use the `exportSPSS` function to export the processed data into an SPSS-compatible CSV file. If the data has already been exported during the ERP plotting step, you can skip this step. However, once you have saved `ALLEEGDATA`, you can call this function as many times as needed.

### Example Usage
```matlab
% Preprocess your EEG data with eegPreproc
eegPreproc;

% Or preprocess your EEG data with unfoldERPData
unfoldERPData;

% Plot the ERP
eegPlotERP;

% Export data to SPSS
exportSPSS;

% Or specify parameters if needed
exportSPSS(ALLEEGDATA, [100 200], EEG.times, {EEG.chanlocs.labels});
```

## Getting Help
For any questions or clarifications about using the scripts, please refer to the documentation at the beginning of each script. This documentation provides detailed explanations of the script’s purpose, parameters, and usage. It is designed to help you navigate through the preprocessing, plotting, and exporting steps effectively. If you encounter any issues not covered in the documentation, feel free to raise them in the [issues section](https://github.com/dinosoldic/EEG-Preproc-ERP/issues) of this repository.

## License

This project is licensed under the MIT License for the original code. 

However, it also includes portions of code from EEGLAB, which are licensed under the BSD 2-Clause License. 

For more details, see the [LICENSE](LICENSE) file.

## Acknowledgments
This project utilizes the EEGLAB toolbox, which is essential for EEG data processing and [Unfold Toolbox](https://github.com/unfoldtoolbox/unfold) (Ehinger BV, Dimigen O: "Unfold: An integrated toolbox for overlap correction, non-linear modeling, and regression-based EEG analysis", peerJ 2019, [DOI](https://doi.org/10.7717/peerj.7838)).
Thank you to the developers and contributors.
