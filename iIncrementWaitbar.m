function iIncrementWaitbar(wb)
ud = wb.UserData;
ud(1) = ud(1) + 1;
waitbar(ud(1) / ud(2), wb);
wb.UserData = ud;
fprintf("Completion Percentage: %.2f%% \n", (ud(1) / ud(2)) * 100)
end