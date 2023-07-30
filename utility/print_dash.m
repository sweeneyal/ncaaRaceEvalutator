% Dash printing function.
% Prints up to the number of dashes.
% Arguments:
%   numDashes - number of dashes to print.
function PrintDashes(numDashes)
    dashes = blanks(numDashes);

    for i = 1:numDashes
        dashes(i) = '-';
    end

    disp(dashes);
end
