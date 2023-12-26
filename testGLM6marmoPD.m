% GLM with Control vs. PD marmoset
% multi-subject with Tukey-Taper.
function testGLM6marmoPD
    fmribase = {'G:\marmoset'};
    paths = {
        {'pd_org'}, ... % pd
        {'pdctrl_org2','pdctrl_org3','pdctrl_org4'} % cn
        };
    outpath = 'results/';

    % load background nii
    backNii = 'data\sp2_avg_mri_exvivo_t2wi_v1.0.0RsfMRI.nii.gz';
    backinfo = niftiinfo(backNii);
    backV = niftiread(backinfo);
    backV = adjustVolumeDir(backV, backinfo);
    maskV = backV;
    maskV(maskV<1) = 0;
    maskV(maskV>0) = 1;

    aIdx = find(maskV>0); % used for volume mask

    % contrast image params
    contnames = {'PD'};
    contrasts = {[1 -1]'};
    Pth = 0.01; % pvalue threshold
    rangePlus = [nan 8];
    rangeMinus = [nan 8];
    isRtoL = false;

    % loading mean EPI NIfTI images
    B1 = [];
    X2 = [];
    for i=1:length(paths)
        path = paths{i};
        for k=1:length(path)
            listing = dir([fmribase{1} '/' path{k} '/gmw*.nii.gz']);
            for j=1:length(listing)
                name = listing(j).name;
                str = split(name,'.');
                sbjId = extractAfter(str{1},3);
                if isempty(str2num(sbjId)), continue; end
    
                % read mean EPI volumes
                tfmri = [fmribase{1} '/' path{k} '/gmw' sbjId '.nii.gz'];
                if ~exist(tfmri,'file')
                    disp(['file not found. please put NIfTI data. (skipped) : ' tfmri]);
                    continue;
                end
                disp(['loading : ' tfmri]);
                info = niftiinfo(tfmri);
                V = single(niftiread(info));
                V = adjustVolumeDir(V, info);
        
                % voxels from fMRI
                disp('apply mask atlas...');
                Z = V(aIdx);
                B1 = [B1; Z'];
        
                % design matrix
                if i > 1
                    B2 = [0 1]; % CN
                else 
                    B2 = [1 0]; % PD
                end
                X2 = cat(1, X2, B2);
            end
        end
    end
    B1(isnan(B1)) = 0; % there might be nan

    for tuM = 8:8
        betaBmat = [outpath 'glm6marmoPD-Tukey' num2str(tuM) 'full.mat'];
        if exist(betaBmat,'file')
            % load beta volumes
            load(betaBmat);
        else
            % calc 2nd-level estimation
            [B, RSS, df, X2is, tRs, R] = calcGlmTukey(B1, X2, tuM);

            [recel, FWHM] = estimateSmoothFWHM(R, RSS, df, maskV);

            % output beta matrix
            save(betaBmat,'B','RSS','X2is','tRs','recel','FWHM','df','-v7.3');
        end

        % GLM contrast images
        Ts = calcGlmContrastImage(contrasts, B, RSS, X2is, tRs);

        % GLM contrast image
        thParam = {df, Pth};
        clParam = {53, FWHM}; % clustering parameter for GLM contrast
        [Tth, Vts, Vfs, Tmaxs, Tcnts] = plotGlmContrastImage(contnames, Ts, thParam, clParam, maskV, true, isRtoL, backV, ...
            ['glm6marmoPD ' '2nd-mix-Tukey' num2str(tuM) 'full'], rangePlus, rangeMinus, [], [], []);

        % save T-value NIfTI volume
        saveContrastNii(backNii,contnames,Vts,outpath,['glm6marmoPD_2nd-mix-Tukey' num2str(tuM) 'th' 'full']);
    end
end

%%
function saveContrastNii(tfmri, contnames, V2s, path, outname)
    info = niftiinfo(tfmri);
    info.ImageSize = info.ImageSize(1:3);
    info.PixelDimensions = info.PixelDimensions(1:3);
    info.raw.dim(1) = 3;
    info.raw.dim(5) = 1;
    info.Datatype = 'single';
    info.BitsPerPixel = 32;
    for j=1:length(contnames)
        fname = [path outname '_' contnames{j} '.nii'];
        niftiwrite(V2s{j},fname,info,'Compressed',true);
    end
end

