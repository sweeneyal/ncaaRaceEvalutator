% /////////////////////////////////////////////////////////////////////////////////////////////////////////////////// %

% Primary function definition. Runs the NCAA Race Evaluator tool.
% Arguments:
%   'numThreads' - integer number of threads to generate for each parallel execution.
function Results = NcaaRaceEvaluator(varargin)
    numThreads = 1;
    for i = 1:2:length(varargin)
        switch(varargin{i})
            case 'numThreads'
                numThreads = varargin{i + 1};
        end
    end

    % --------------------------------------------------------------------------------------------------------------- %

    % Print startup introduction.
    Introduction();

    Print('Reading NCAA D1 2019 Cross Country Championship Results...');
    skipAthletes    = exist('analysis/athletedata.mat', 'file');
    skipRaces       = exist('analysis/racedata.mat', 'file');
    skipPerformance = exist('analysis/performancedata.mat', 'file');
    options         = weboptions('Timeout',45);
    Results         = struct();

    t0 = tic;
    if (~skipAthletes)
        % Get the original NCAA D1 2019 Cross Country Championships
        ncaaD1Html = webread('https://www.tfrrs.org/results/xc/16731/NCAA_Division_I_Cross_Country_Championships', options);
        ncaaTree   = htmlTree(ncaaD1Html);
        
        % Extract runners from text so as to have a list of all runners necessary for the evaluation.
        % Use the href as part of that runner's entry in the lineup and parse that data.
        selector = 'A';
        subtrees = findElement(ncaaTree,selector);
        attr     = 'href';
        links    = getAttribute(subtrees,attr);
        indices  = contains(links, 'athlete', 'IgnoreCase', true);
        links    = links(indices);
        Print('Read results.');
    
        % --------------------------------------------------------------------------------------------------------------- %
    
        % Create struct of all athletes with their names, identifiers, and team ran for this season.
        Print('Collecting initial data on athletes...');
        [ids,  teams, names] = deal(cell(size(links)));
        CreateParallelPool(numThreads);
        parfor i = 1:length(links)
            % The TFRRS athlete links on the championship page contains an identifier, team, and name in that order
            tokens = regexpi(links(i), 'https://xc.tfrrs.org/athletes/(\d+)/(.*)/(.*).html', 'tokens');
            tokens = cellstr(tokens{:});
    
            [ids{i}, teams{i}, names{i}] = tokens{:};
        end
    
        if (any(isempty(ids) & isempty(teams) & isempty(names)))
            warning('Some athlete link references were not parsed correctly.');
        end
        KillParallelPool();
    
        Athletes       = struct();
        Athletes.Ids   = cellfun(@(x) str2double(x), ids, 'UniformOutput',true);
        Athletes.Teams = teams;
        Athletes.Names = names;
        Athletes.Links = links;
        Print('Athlete data established.');
    
        % --------------------------------------------------------------------------------------------------------------- %
    
        % For each athlete, find their results page and parse it for useful data.
        Print('Getting all results links for athletes...');
        [allRaceIds, allRaces, allRaceLinks] = deal(cell(size(Athletes.Ids)));
        CreateParallelPool(numThreads);
        parfor i = 1:length(Athletes.Ids)
            % TODO: Consider slicing the Athletes struct into portions for each parfor.
            athleteHtml = webread(Athletes.Links{i}, options); %#ok<PFBNS> 
            tree        = htmlTree(athleteHtml);
            selector    = 'A';
            subtrees    = findElement(tree,selector);
            attr        = 'href';
            links       = getAttribute(subtrees,attr);
            indices     = contains(links, '/results/xc/', 'IgnoreCase', true);
            links       = links(indices);
    
            % The TFRRS results links contain an identifier and a race name in that order.
            [ids, races] = deal(cell(size(links)));
            validIndices            = false(size(links));
            for j = 1:length(links)
                tokens = regexpi(links(j), 'https://xc.tfrrs.org/results/xc/(\d+)/(.*)', 'tokens');
                tokens = cellstr(tokens{:});
    
                % Sometimes the links contain a '?' character followed by the meet ID, we can ignore this because this race
                % is repeated later.
                if (contains(tokens{2}, '?'))
                    continue;
                end
        
                [ids{j}, races{j}] = tokens{:};
                validIndices(j)    = true;
            end
    
            % Filter out ids that were removed as duplicates early in the run.
            ids       = ids(validIndices);
            races     = races(validIndices);
            raceLinks = links(validIndices);
    
            % Filter out duplicate race IDs and pull the indices for the unique races.
            ids            = cellfun(@(x) str2double(x), ids, 'UniformOutput',true);
            [ids, indices] = unique(ids);
    
            % Add the race IDs and race names to cell arrays to be appended to the Athletes struct later.
            allRaceIds{i}   = ids;
            allRaces{i}     = races(indices);
            allRaceLinks{i} = raceLinks(indices);
            if (mod(i, 10) == 0)
                Print('Finished %d Athletes at %.2fs', i, toc(t0));
            end
        end
        KillParallelPool();
    
        Athletes.RaceIds   = allRaceIds;
        Athletes.Races     = allRaces;
        Athletes.RaceLinks = allRaceLinks;
        Print('All athlete performances collected, saving data...');
        save('analysis/athletedata');
    else
        Print('Past results found. Loading past results...');
        load('analysis/athletedata.mat'); %#ok<LOAD> 
        Print('Past results loaded.');
    end

    % --------------------------------------------------------------------------------------------------------------- %

    if (~skipRaces)
        % Evaluate the race ids and find all unique race ids and their corresponding race names.
        Print('Compiling list of unique races out of all competition data...');
        raceIds   = vertcat(Athletes.RaceIds{:});
        races     = vertcat(Athletes.Races{:});
        raceLinks = vertcat(Athletes.RaceLinks{:});
    
        [raceIds, indices] = unique(raceIds);
        races              = races(indices);
        raceLinks          = raceLinks(indices);
        Print('List of unique races compiled.');

        Print('Collecting all race data...');
        % TODO: Consider making this a parfor
        RaceData = cell(size(raceIds));
        for i = 1:length(raceIds)
            raceStr    = webread(raceLinks{i}, options);
            expression = '<(table).*?</\1>';
            matches    = regexp(raceStr,expression,'match');

            RaceTables = cell(size(matches));
            for j = 1:length(matches)
                RaceTable = ReadHtmlTable(matches{j});
                RaceTables{j} = RaceTable;
            end
            
            RaceData{i} = RaceTables;

            if (mod(i, 10) == 0)
                Print('Finished %d Races at %.2fs', i, toc(t0));
            end
        end
        Races.Ids      = raceIds;
        Races.Names    = races;
        Races.Links    = raceLinks;
        Races.RaceData = RaceData;
        toc;

        Print('All race data collected. Saving race data...');
        save('analysis/racedata');
        Print('Race data saved.');
    else
        Print('Past results found. Loading past results...');
        load('analysis/racedata.mat'); %#ok<LOAD> 
        Print('Past results loaded.');
    end

    if(~skipPerformance) 
        % TODO: Finish this.
        % Evaluate all running data.
        Print('Starting evaluation of races and running data...');

        [means, variances] = deal(zeros(size(Races.Ids)));
        for i = 1:length(Races.Ids)
            RaceTables = Races.RaceData{i};
            for j = 1:length(RaceTables)
                columnNames = RaceTables{j}.Properties.VariableDescriptions;
                if (strcmpi(columnNames{2}, 'team'))
                    % This is a teams table, ignore this table.
                    continue;
                end

                % Otherwise, need to evaluate this table.
                index = find(strcmpi(columnNames, 'time'));
                variableName = sprintf('data%d',index);
                times        = RaceTables{j}.(variableName);
                times        = datetime(times, 'InputFormat', 'mm:ss.SSS', 'Format', 'mm:ss.SSS');
                times        = rmmissing(times);
                
                timeAfterWinner = duration(times - times(1));
                secondsAfter    = seconds(timeAfterWinner);
                avgTimeAfter    = mean(secondsAfter);
                varianceAfter   = var(secondsAfter);

                % These two numbers are used to calculate the performance of the field. A lower mean and lower variance 
                % indicates that the field is well-matched. A higher mean and lower variance indicates that the field 
                % is outclassed by runners closer to the winner, but that runners closer to the winner are outliers. A
                % lower mean and higher variance indicates that the 


            end
        end
    end

end

% Fancy introduction function.
% Arguments:
%   None
function Introduction()
    PrintDashes(80);
    Print('\tNCAA Race Evaluator v%d.%d.%d', 1,0,0);
    PrintDashes(80);
end

% Standardized printing function.
% Takes string input and appends a newline to the end of the string if no newline currently exists.
% Arguments:
%   str      - String to print
%   varargin - Standard formatting arguments to fprintf.
function Print(str, varargin)
    if (~strcmpi(str(end-1:end), '\n'))
        str(end+1:end+2) = '\n';
    end
    fprintf(1, str, varargin{:});
end

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

% HTML Table parsing function.
% Reads column names from table header using regex, and then parses table data to produce a MATLAB table.
% Arguments:
%   html - HTML text pulled from website.
function Table = ReadHtmlTable(html)
    % Read the columns from the table header.
    expression = '<(thead).*?</\1>';
    matches    = regexp(html,expression,'match');
    tree     = htmlTree(matches{1});
    selector = 'th';
    subtrees = findElement(tree,selector);
    columns  = convertStringsToChars(extractHTMLText(subtrees))';
    columns  = cellfun(@(x) regexprep(x,'[^a-zA-Z0-9]',''), columns, 'UniformOutput', false);
    columns  = lower(columns);

    % Read the data values from the table body and append to a cell array.
    expression = '<(tbody).*?</\1>';
    matches    = regexp(html,expression,'match');
    tree     = htmlTree(matches{1});
    selector = 'tr';
    subtrees = findElement(tree,selector);
    data     = cell(length(subtrees), length(columns));
    for i = 1:length(subtrees)
        selector     = 'td';
        datatrees    = findElement(subtrees(i),selector);
        dataValues   = convertStringsToChars(extractHTMLText(datatrees))';
        [data{i, :}] = dataValues{:};
    end

    % Create a table from the results.
    Table = cell2table(data);
    Table.Properties.VariableDescriptions = columns;
end