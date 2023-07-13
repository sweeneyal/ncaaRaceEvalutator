% /////////////////////////////////////////////////////////////////////////////////////////////////////////////////// %

function CreateParallelPool(numProcesses, varargin)
    % --------------------------------------------------------------------------------------------------------------- %
    persistent lastNumProcesses
    try
        if (isempty(lastNumProcesses) || lastNumProcesses ~= numProcesses)
            parpool(numProcesses);
            lastNumProcesses = numProcesses;
        end
    catch
        delete(gcp('nocreate'))
        parpool(numProcesses);
    end
end