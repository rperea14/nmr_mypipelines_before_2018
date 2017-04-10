classdef dwi_ADRC < dwiMRI_Session
%%  classdef dwi_ADRC < dwiMRI_Session
%%  This class is a subclass of its parent class dwi_MRI_Session.m 
%%  (where it will inherent other methods). 
%%  Created by:
%%              Aaron Schultz
%%              Rodrigo D. Perea rperea@mgh.harvard.edu
%%
%%
    
    properties
       %root directoy where raw data lives:
       root = '/autofs/eris/bang/ADRC/Sessions/';
    end
    methods
        function obj = dwi_ADRC(sessionname,opt)
            %%%  If opt is passed, then the root Sessions folder will be 
            %%%  replaced with this argument.
            if nargin>1
                obj.root = opt;
            end
            
            obj.sessionname = sessionname;
            obj.root = [obj.root sessionname '/DWIs/'];
            obj.objectHome = obj.root;
            
            newroot = obj.root;
            oldroot = obj.root;
            
            %obj.setSPM12;  %No needed yet
            
            obj.dosave = true;

            if exist([obj.objectHome filesep sessionname '.mat'],'file')>0 
                load([obj.objectHome filesep sessionname '.mat']);
                oldroot = obj.root;
                obj.wasLoaded = true;
            else
                obj.setMyParams; 
            end
            
            if nargin>1
                if ~strcmpi(oldroot,newroot)
                    obj = replaceObjText(obj,{oldroot},{newroot});
                    obj.resave;
                end
            end
        end
        
        function obj=setMyParams(obj)
            
            obj.rawfiles = dir_wfp([obj.root 'Orig/*' obj.sessionname '*.nii']);
            obj.fsdir='/autofs/eris/bang/ADRC/FreeSurfer6.0/';
            obj.fsubj=obj.sessionname;
            obj.vox = [2 2 2];
            obj.TR = 1.08;
            obj.bb = [-78 -112 -70; 78 76 90];
            obj.interporder = 5;
                
        end
              
        function obj = CommonProc(obj)
            %%%
            obj.proc_t1_spm;
            %%%
            obj.Params.DropVols.in.dropVols = 1:10;
            obj.Params.DropVols.in.movefiles = '../01_DropVols/';
            obj.proc_drop_vols(obj.rawfiles);
            %%%
            obj.Params.Realign.in.movefiles = '../02_Realign/';
            obj.proc_realign(obj.Params.DropVols.out.fn);
            %%%
            obj.Params.Reslice.in.movefiles = '../03_Resliced/';
            obj.proc_reslice(obj.Params.DropVols.out.fn);
            %%%
            obj.Params.GradNonlinCorrect.in.movefiles = '../04_GradCorrect/';
            obj.Params.GradNonlinCorrect.in.prefix = 'gnc_';
            obj.Params.GradNonlinCorrect.in.gradfile = '/autofs/space/kant_004/users/ConnectomeScanner/Scripts/adrc_diff_prep/bash/gradient_nonlin_unwarp/gradient_coil_files/coeff_AS302.grad';
            obj.Params.GradNonlinCorrect.in.fn = obj.Params.Reslice.out.fn;
            obj.Params.GradNonlinCorrect.in.target = obj.Params.Reslice.out.meanimage;
            
            obj.Params.GradNonlinCorrect.out.warpfile = [];
            obj.Params.GradNonlinCorrect.out.meannii = [];
            obj.Params.GradNonlinCorrect.out.fn = [];
            obj.proc_gradient_nonlin_correct;
            %%%
            obj.Params.Implicit_Unwarp.in.movefiles = '../05_ImpUnwarp/';
            % obj.proc_implict_unwarping(obj.Params.GradNonlinCorrect.out.meanimage,  '/autofs/space/kant_004/users/ConnectomeScanner/Sessions/150430_8CS00315/restingState/05_ImpUnwarp/mmean.nii');
            obj.proc_implict_unwarping(obj.Params.GradNonlinCorrect.out.meanimage,  obj.Params.GradNonlinCorrect.out.fn);
            %%%
            obj.Params.Coreg.in.style = 'iuw';
            obj.Params.Coreg.in.movefiles = '../05_ImpUnwarp/';
            obj.proc_get_fs_labels;
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            obj.Params.ApplyNormNew.in.movefiles = '../06_Normed/';
            obj.Params.ApplyNormNew.in.regfile = obj.Params.spmT1_Proc.out.regfile;
            obj.Params.ApplyNormNew.in.prefix = 'nn2_';
            
            obj.Params.ApplyNormNew.in.fn = obj.Params.Implicit_Unwarp.out.newmean;
            obj.proc_applynorm_new;
            obj.Params.ApplyNormNew.out.normmean = obj.Params.ApplyNormNew.out.fn{1};
            
            obj.Params.ApplyNormNew.in.fn = obj.Params.Implicit_Unwarp.out.fn;
            obj.proc_applynorm_new;
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            obj.Params.Smooth.in.kernel = [6 6 6];
            obj.Params.Smooth.in.prefix = 'ss6_';
            obj.Params.Smooth.in.movefiles = '../07_Smoothed/';
            obj.proc_smooth(obj.Params.ApplyNormNew.out.fn);
            
%             obj.genTBRmaps(obj.Params.Smooth.out.fn);
            
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%             obj.Params.Smooth.in.kernel = [3 3 3];
%             obj.Params.Smooth.in.prefix = 'ss3_';
%             obj.Params.Smooth.in.movefiles = '../08_Smoothed/';
%             obj.proc_smooth(obj.Params.Implicit_Unwarp.out.fn);
            
            
%             obj.Params.ApplyReverseNormNew.in.movefiles = [obj.root '/08_Smoothed/templates/'];
%             obj.Params.ApplyReverseNormNew.in.fn = dir_wfp('/autofs/space/schopenhauer_002/users/MATLAB_Scripts/Atlas/fMRI/SchultzMaps/StandardTemplates/*.nii');
%             obj.Params.ApplyReverseNormNew.in.targ = [obj.Params.Smooth.out.fn{1} ',1'];
%             obj.Params.ApplyReverseNormNew.in.regfile = obj.Params.spmT1_Proc.out.iregfile;
%             obj.proc_apply_reservsenorm_new;
            
%             obj.genTBRmaps(obj.Params.Smooth.out.fn);

%             TBR(obj.Params.Smooth.out.fn,obj.Params.ApplyReverseNormNew.out.fn,[],[],'_Standard',[obj.root '/08_Smoothed/'],0);
%             TBR(obj.Params.Implicit_Unwarp.out.fn,obj.Params.ApplyReverseNormNew.out.fn,[],[],'_Standard',[obj.root '/05_ImpUnwarp/'],0);
        end
        
        function obj = LightClean(obj)
            obj.Params.Filter.in.highcut = [];
            obj.Params.Filter.in.lowcut = 0.01;
            
            obj.Params.CleanData.in.movefiles = '../LightClean/06_Cleaned/';
            obj.Params.CleanData.in.filter = 1;
            obj.Params.CleanData.in.motion = 1;
            obj.Params.CleanData.in.physio = 0;
            obj.Params.CleanData.in.deriv  = 1;
            obj.Params.CleanData.in.square = 1;
            obj.Params.CleanData.in.reduce = 0;
            obj.proc_regress_clean2(dir_wfp([obj.root '05_ImpUnwarp/uw_gnc_rr*.nii']));
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            obj.Params.ApplyNormNew.in.fn = obj.Params.CleanData.out.fn;
            obj.Params.ApplyNormNew.in.movefiles = '../07_Normed/';
            obj.Params.ApplyNormNew.in.regfile = obj.Params.spmT1_Proc.out.regfile;
            obj.Params.ApplyNormNew.in.prefix = 'nn2_';
            obj.proc_applynorm_new;
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            obj.Params.Smooth.in.kernel = [6 6 6];
            obj.Params.Smooth.in.prefix = 'ss6_';
            obj.Params.Smooth.in.movefiles = '../08_Smoothed/';
            obj.proc_smooth(obj.Params.ApplyNormNew.out.fn);
            
            %obj.genTBRmaps(obj.Params.Smooth.out.fn);
        end
        
        function obj = MediumClean(obj)
            obj.Params.ComputePhysioRegs.in.movefiles = 'PhysioRegs/';
            obj.Params.ComputePhysioRegs.in.type = 'indirecttpm';
            obj.Params.ComputePhysioRegs.in.whichparts = 1:3;
            obj.Params.ComputePhysioRegs.in.weighted = 1;
            obj.Params.ComputePhysioRegs.in.threshold = NaN;
            obj.Params.ComputePhysioRegs.in.prinComps = 0;
            obj.Params.ComputePhysioRegs.in.nPC = NaN;
            obj.Params.ComputePhysioRegs.in.resample = [1 0];
            obj.Params.ComputePhysioRegs.in.masks = [];
            obj.Params.ComputePhysioRegs.in.filename = 'Mean_PhysioRegs3.txt';
            obj.proc_compute_physio_regs(obj.Params.Implicit_Unwarp.out.fn);
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            obj.Params.Filter.in.highcut = 0;
            obj.Params.Filter.in.lowcut = 0.01;
            
            obj.Params.CleanData.in.movefiles = '../MediumClean/06_Cleaned/';
            obj.Params.CleanData.in.filter = 1;
            obj.Params.CleanData.in.motion = 1;
            obj.Params.CleanData.in.physio = 1;
            obj.Params.CleanData.in.deriv  = 1;
            obj.Params.CleanData.in.square = 1;
            obj.Params.CleanData.in.reduce = 0;
            obj.proc_regress_clean2(obj.Params.Implicit_Unwarp.out.fn);
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            obj.Params.ApplyNormNew.in.fn = obj.Params.CleanData.out.fn;
            obj.Params.ApplyNormNew.in.movefiles = '../07_Normed/';
            obj.Params.ApplyNormNew.in.regfile = obj.Params.spmT1_Proc.out.regfile;
            obj.Params.ApplyNormNew.in.prefix = 'nn2_';
            obj.proc_applynorm_new;
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            obj.Params.Smooth.in.kernel = [6 6 6];
            obj.Params.Smooth.in.prefix = 'ss6_';
            obj.Params.Smooth.in.movefiles = '../08_Smoothed/';
            obj.proc_smooth(obj.Params.ApplyNormNew.out.fn);
            
            %obj.genTBRmaps(obj.Params.Smooth.out.fn);
        end
        
        function obj = MediumClean2(obj)
            obj.Params.ComputePhysioRegs.in.movefiles = 'PhysioRegs/';
            obj.Params.ComputePhysioRegs.in.type = 'indirecttpm';
            obj.Params.ComputePhysioRegs.in.whichparts = 2:3;
            obj.Params.ComputePhysioRegs.in.weighted = 1;
            obj.Params.ComputePhysioRegs.in.threshold = NaN;
            obj.Params.ComputePhysioRegs.in.prinComps = 1;
            obj.Params.ComputePhysioRegs.in.nPC = 10;
            obj.Params.ComputePhysioRegs.in.resample = [1 0];
            obj.Params.ComputePhysioRegs.in.masks = [];
            obj.Params.ComputePhysioRegs.in.filename = 'Mean_PhysioRegs2.txt';
            obj.proc_compute_physio_regs(obj.Params.Implicit_Unwarp.out.fn);
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            obj.Params.Filter.in.highcut = 0.01;
            obj.Params.Filter.in.lowcut = nan;
            
            obj.Params.CleanData.in.movefiles = '../MediumClean2/06_Cleaned/';
            obj.Params.CleanData.in.filter = 1;
            obj.Params.CleanData.in.motion = 1;
            obj.Params.CleanData.in.physio = 1;
            obj.Params.CleanData.in.deriv  = 1;
            obj.Params.CleanData.in.square = 1;
            obj.Params.CleanData.in.reduce = 1;
            obj.proc_regress_clean(obj.Params.Implicit_Unwarp.out.fn);
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            obj.Params.ApplyNormNew.in.fn = obj.Params.CleanData.out.fn;
            obj.Params.ApplyNormNew.in.movefiles = '../07_Normed/';
            obj.Params.ApplyNormNew.in.regfile = obj.Params.spmT1_Proc.out.regfile;
            obj.Params.ApplyNormNew.in.prefix = 'nn2_';
            obj.proc_applynorm_new;
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            obj.Params.Smooth.in.kernel = [6 6 6];
            obj.Params.Smooth.in.prefix = 'ss6_';
            obj.Params.Smooth.in.movefiles = '../08_Smoothed/';
            obj.proc_smooth(obj.Params.ApplyNormNew.out.fn);
            
%             obj.Params.Smooth.in.kernel = [4 4 4];
%             obj.Params.Smooth.in.prefix = 'ss4_';
%             obj.Params.Smooth.in.movefiles = '../08_Smoothed/';
%             obj.proc_smooth(obj.Params.ApplyNormNew.out.fn);
            
            obj.genTBRmaps(obj.Params.Smooth.out.fn);
            obj.ExtractBOIs_v2(obj.Params.Smooth.out.fn)
        end
        
        function obj = HeavyClean(obj)
            obj.Params.ComputePhysioRegs.in.movefiles = 'PhysioRegs/';
            obj.Params.ComputePhysioRegs.in.type = 'indirecttpm';
            obj.Params.ComputePhysioRegs.in.whichparts = 1:6;
            obj.Params.ComputePhysioRegs.in.weighted = 1;
            obj.Params.ComputePhysioRegs.in.threshold = NaN;
            obj.Params.ComputePhysioRegs.in.prinComps = 1;
            obj.Params.ComputePhysioRegs.in.nPC = 10;
            obj.Params.ComputePhysioRegs.in.resample = [1 0];
            obj.Params.ComputePhysioRegs.in.masks = [];
            obj.Params.ComputePhysioRegs.in.filename = 'PCA_PhysioRegs.txt';
            obj.proc_compute_physio_regs(obj.Params.Implicit_Unwarp.out.fn);
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            obj.Params.Filter.in.highcut = 0;
            obj.Params.Filter.in.lowcut = 0.01;
            
            obj.Params.CleanData.in.movefiles = '../HeavyClean/06_Cleaned/';
            obj.Params.CleanData.in.filter = 1;
            obj.Params.CleanData.in.motion = 1;
            obj.Params.CleanData.in.physio = 1;
            obj.Params.CleanData.in.deriv  = 1;
            obj.Params.CleanData.in.square = 1;
            obj.Params.CleanData.in.reduce = 1;
            obj.proc_regress_clean2(obj.Params.Implicit_Unwarp.out.fn);
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            obj.Params.ApplyNormNew.in.fn = obj.Params.CleanData.out.fn;
            obj.Params.ApplyNormNew.in.movefiles = '../07_Normed/';
            obj.Params.ApplyNormNew.in.regfile = obj.Params.spmT1_Proc.out.regfile;
            obj.Params.ApplyNormNew.in.prefix = 'nn2_';
            obj.proc_applynorm_new;
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            obj.Params.Smooth.in.kernel = [6 6 6];
            obj.Params.Smooth.in.prefix = 'ss6_';
            obj.Params.Smooth.in.movefiles = '../08_Smoothed/';
            obj.proc_smooth(obj.Params.ApplyNormNew.out.fn);
            
%             obj.genTBRmaps(obj.Params.Smooth.out.fn);
        end
        
        function obj = FixClean(obj)
            
        end
        
        function obj = MapBOIsToNativeSpace(obj)
            obj.setSPM12;
            fn = dir_wfp('/autofs/space/aristotle_003/users/FC_and_Cognition/TBR_Templates/FROIS/renamed/*.nii');
            fn = [fn; dir_wfp('/autofs/space/aristotle_003/users/FC_and_Cognition/TBR_Templates/SensoryBOIs2/*.nii')];
            
            obj.Params.ApplyReverseNormNew.in.movefiles = [obj.root 'BOIs/'];
            obj.Params.ApplyReverseNormNew.in.fn = fn;
            obj.Params.ApplyReverseNormNew.in.targ = obj.Params.Implicit_Unwarp.out.newmean;
            obj.Params.ApplyReverseNormNew.in.regfile = obj.Params.spmT1_Proc.out.iregfile;
            
            obj.proc_apply_reservsenorm_new;
        end
        
        function obj = proc_gradient_nonlin_correct(obj)
            wasRun = false;
            target = obj.Params.GradNonlinCorrect.in.target;
            [m h] = openIMG(target); if h.pinfo(1)~=1; h.pinfo(1)=1; spm_write_vol(h,m); end
            [a b c] = fileparts(target);
            outpath = obj.getPath(a,obj.Params.GradNonlinCorrect.in.movefiles);

            
            % addpath(genpath('/autofs/space/kant_002/users/rperea/DrigoScripts/adrc_diff/adrc_diff_prep/'));
            % mris_gradient_nonlin__unwarp_volume__batchmode_HCPS_v3(target, [outpath 'gc_mean.nii'], 'coeff_AS302.grad');
            
            infile = target;
            outfile = [outpath 'gnc_' b c];
            gradfile = obj.Params.GradNonlinCorrect.in.gradfile;
            
            %%% Compute the grdient nonlinearity correction
            if exist([outpath b '_deform_grad_rel.nii'],'file')==0
                cmd=['sh /autofs/space/kant_004/users/ConnectomeScanner/Scripts/adrc_diff_prep/run_mris_gradient_nonlin__unwarp_volume__batchmode_ADRC_v3.sh ' ...
                    '/usr/pubsw/common/matlab/8.5 ' ...
                    infile ' ' outfile ' ' gradfile ' '];
                system(cmd);
                wasRun = true;
            end
            obj.Params.GradNonlinCorrect.out.warpfile = [outpath b '_deform_grad_rel.nii'];
            
            %%% Apply the correction to the mean image.
            if exist(outfile,'file')==0
                cmd = ['applywarp -i ' infile ' -r ' infile ' -o ' outfile ' -w ' obj.Params.GradNonlinCorrect.out.warpfile ' --interp=spline'];
                runFS(cmd,pwd,3);
                system(['gunzip ' outpath '*.gz']);
                wasRun = true;
            end
            obj.Params.GradNonlinCorrect.out.meanimage = outfile;
            
            %%% Apply correction to full dataset
            fn = obj.Params.Reslice.out.fn;
            for ii = 1:numel(fn);
                infile = fn{ii};
                [a b c] = fileparts(infile);
                outpath = obj.getPath(a,obj.Params.GradNonlinCorrect.in.movefiles);
                outfile = [outpath 'gnc_' b c];
                if exist(outfile,'file')==0
                    cmd = ['applywarp -i ' infile ' -r ' infile ' -o ' outfile ' -w ' obj.Params.GradNonlinCorrect.out.warpfile ' --interp=spline'];
                    runFS(cmd,pwd,3);
                    system(['gunzip ' outpath '*.gz']);
                    wasRun = true;
                end
                obj.Params.GradNonlinCorrect.out.fn{ii,1} = outfile;
            end
            
            obj.UpdateHist(obj.Params.GradNonlinCorrect,'proc_gradient_nonlin_correct',obj.Params.GradNonlinCorrect.out.warpfile,wasRun);
        end
        
        function resave(obj)
            save([obj.objectHome filesep obj.sessionname '.mat'],'obj');
        end
        
      
    end
end