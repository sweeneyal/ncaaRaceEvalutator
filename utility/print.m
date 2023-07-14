% Standardized printing function.
% Takes string input and appends a newline to the end of the string if no newline currently exists.
% Arguments:
%   str      - String to print
%   varargin - Standard formatting arguments to fprintf.
function Print(str, varargin)

    if (~strcmpi(str(end - 1:end), '\n'))
        str(end + 1:end + 2) = '\n';
    end

    fprintf(1, str, varargin{:});
end
