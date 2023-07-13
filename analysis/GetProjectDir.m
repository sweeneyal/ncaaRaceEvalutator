function projectDir = GetProjectDir()
    filename   = mfilename('fullpath');
    projectDir = fileparts(sprintf('%s.m', filename));
end