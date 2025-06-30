%
% This function is intended for internal use in eegPlotERP to track loading progress.
% Author: Dino Soldic
% Email: dino.soldic@urjc.es
% Date: 2025-06-30

function iIncrementWaitbar(wb)
ud = wb.UserData;
ud(1) = ud(1) + 1;
waitbar(ud(1) / ud(2), wb);
wb.UserData = ud;
fprintf("Completion Percentage: %.2f%% \n", (ud(1) / ud(2)) * 100)
end