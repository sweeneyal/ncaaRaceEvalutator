function SetupProject()
    projectDir = GetProjectDir();
    addpath(fullfile(projectDir));
    cd(projectDir);
    savepath;
end