classdef dwi_HAB < dwiMRI_Session
%%  classdef dwi_ADRC < dwiMRI_Session
%%  This class is a subclass of its parent class dwi_MRI_Session.m 
%%  (where it will inherent other methods). 
%%  Created by:
%%              Aaron Schultz aschultz@martinos.org
%%              Rodrigo Perea rpereacamargo@mgh.harvard.edu
%%
%%
%%      Dependencies:
%%          -FreeSurfer v6.0
%%          -SPM8
%%          -Ants tools
%%          -DSI_studio
%%  *Only filesep wit '/' are used in the properties class declaration.
%%   Besides these, all should be any operating system compatible (tested in CentOS Linux)
    properties
       
       %root directoy where raw data lives:
       root_location = '/cluster/sperling/HAB/Project1/DWIs_30b700/Sessions/';
       dcm_location = '/cluster/sperling/HAB/Project1/DICOM_ARCHIVE/All_DICOMS/';
       session_location='/cluster/sperling/HAB/Project1/Sessions/'
       %sh dependencies:
       rotatae_bvecs_sh='/cluster/sperling/HAB/Project1/Scripts/DWIs/mod_fdt_rotate_bvecs.sh ';
       
       %template dependencies:
       HABn272_meanFA='/cluster/hab/HAB/Project1/DWIs_30b700/HABn272_MNI_Target/HABn272_meanFA.nii.gz';
       HABn272_meanFA_skel_dst='/cluster/hab/HAB/Project1/DWIs_30b700/HABn272_MNI_Target/HABn272_mean_FA_skeleton_mask_dst.nii.gz';
       ref_region='/usr/pubsw/packages/fsl/5.0.9/data/standard/LowerCingulum_1mm.nii.gz'
    end
    methods
        function obj = dwi_HAB(sessionname,opt)
            %%%  If opt is passed, then the root Sessions folder will be 
            %%%  replaced with this argument.
            if nargin>1
                odbj.root = opt;
            end
            
            %For compiler code:
            if ~isdeployed()
                addpath(genpath('/autofs/space/kant_004/users/rdp20/scripts/matlab'));
            end
            
            obj.sessionname = sessionname;
            obj.root = [obj.root_location sessionname '/DWIs/'];
            obj.dcm_location= [ obj.dcm_location sessionname filesep ];
            obj.session_location= [ obj.session_location sessionname filesep ];
            
            %If the folder <XX>/DWIs/ does not exist, then create it!             
            if exist(obj.root,'dir')==0
                obj.make_root();
            end
            
            obj.objectHome = obj.root ;
            if exist([obj.objectHome filesep sessionname '.mat'],'file')>0 
                load([obj.objectHome filesep sessionname '.mat']);
                oldroot = obj.root;
                obj.wasLoaded = true;
            else
                obj.setMyParams; 
            end
       
            
            %Check if *.nii.gz files exist, if not get them from DCM2nii:
            obj.rawfiles = dir_wfp([obj.root 'Orig/*.nii.gz' ] );
            if isempty(obj.rawfiles)
               obj.getDCM2nii();
            end
            
            
            if nargin>1
                if ~strcmpi(oldroot,newroot)
                    obj = replaceObjText(obj,{oldroot},{newroot});
                    obj.resave;
                end
            end
            
            %Continue with CommonProc
            obj.CommonProc;
            
        end
        
        function obj=setMyParams(obj)
            %Global parameters:
            obj.vox= [2 2 2 ];
        	obj.setDefaultParams; %from dwiMRI_Session class
       end
              
        function obj = CommonProc(obj)
            obj.dosave = 1 ; %To record MAT file
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %Get rawfiles and locations:
            obj.fsdir=[ '/cluster/hab/FreeSurfer/' obj.sessionname ] ;
            if isempty(obj.rawfiles)
              obj.rawfiles = dir_wfp([obj.root 'Orig/*.nii.gz' ] );
            end
            
            %For BET2:
            obj.Params.Bet2.in.movefiles = ['..' filesep '01_Bet'];
            obj.Params.Bet2.in.fracthrsh = 0.4;
            obj.Params.Bet2.in.fn = obj.rawfiles;
            
            obj.proc_bet2();
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %For EDDY:
            obj.Params.Eddy.in.movefiles = ['..' filesep '02_Eddy'];
            obj.Params.Eddy.in.fn=obj.rawfiles;
            obj.Params.Eddy.in.bvals=strrep(obj.rawfiles,'.nii.gz','.bvals');
            obj.Params.Eddy.in.bvecs=strrep(obj.rawfiles,'.nii.gz','.voxel_space.bvecs');
            obj.Params.Eddy.in.mask = obj.Params.Bet2.out.mask;
            obj.Params.Eddy.in.index= ones(1,35) ; %for 35 volumes
            obj.Params.Eddy.in.acqp= [ 0 -1 0 0.102]; %based on HAB diff sequence
            
            obj.proc_eddy();
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %For B0mean:
            obj.Params.B0mean.in.movefiles = ['..' filesep '03_B0mean'];
            obj.Params.B0mean.in.fn=obj.Params.Eddy.out.fn;
            obj.Params.B0mean.in.b0_nvols=5;
            
            obj.proc_meanb0();
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %For DTIFIT:
            obj.Params.Dtifit.in.movefiles = [ '..' filesep 'Recon_dtifit' ];
            obj.Params.Dtifit.in.fn = obj.Params. Eddy.out.fn;
            obj.Params.Dtifit.in.bvecs = obj.Params.Eddy.out.bvecs;
            obj.Params.Dtifit.in.bvals = obj.Params.Eddy.in.bvals;
            obj.Params.Dtifit.in.mask = obj.Params.Eddy.in.mask;
            
            obj.proc_dtifit();
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %For GQI:
            obj.Params.GQI.in.movefiles = [ '..' filesep 'Recon_gqi' ];
            obj.Params.GQI.in.fn = obj.Params. Eddy.out.fn;
            obj.Params.GQI.in.bvecs = obj.Params.Eddy.out.bvecs;
            obj.Params.GQI.in.bvals = obj.Params.Eddy.in.bvals;
            obj.Params.GQI.in.mask = obj.Params.Eddy.in.mask;
            %obj.Params.GQI.sh = '/usr/pubsw/packages/DSI-Studio/20160715/dsi_studio_run';
            
            obj.proc_gqi();
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %For AntsReg:
            obj.Params.AntsReg.in.movefiles = ['..' filesep 'Ants_CoReg' ];
            obj.Params.AntsReg.in.fn = obj.Params.Dtifit.out.FA ;
            obj.Params.AntsReg.in.ref = obj.HABn272_meanFA;
            obj.Params.AntsReg.in.prefix = [ obj.sessionname '_2_HABn272_' ] ;
            
            obj.proc_antsreg();
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %For Skeletonize:
            obj.Params.Skeletonize.in.movefiles = ['..' filesep 'Skeletonize' ];
            obj.Params.Skeletonize.in.fn = obj.Params.AntsReg.out.fn ;
            obj.Params.Skeletonize.in.meanFA = obj.HABn272_meanFA;
            obj.Params.Skeletonize.in.skel_dst = obj.HABn272_meanFA_skel_dst;
            obj.Params.Skeletonize.in.thr = '0.3';
            obj.Params.Skeletonize.in.ref_region = obj.ref_region;
            
            
            obj.Params.Skeletonize.in.prefix = [ '_skelHABn272' ] ;
            
            obj.proc_skeletonize();
            
            
            
        end
        
        function resave(obj)
            save([obj.objectHome filesep obj.sessionname '.mat'],'obj');
        end
        
      
    end
    
    methods ( Access = protected ) 
        function obj = getDCM2nii(obj)
            %For proc_DCM2NII:
            obj.Params.DCM2NII.specific_vols=35;
            obj.Params.DCM2NII.scanlog = [ obj.session_location  filesep 'LogFiles' ...
                filesep 'scan.log' ] ;
            if ~exist(obj.Params.DCM2NII.scanlog,'file')
                error(['No scanlog found in:' obj.Params.DCM2NII.scanlog '. Exiting...']);
            end
            objParams.DCM2NII.seq_names='DIFFUSION_HighRes_30';
            try
                [ ~ , obj.Params.DCM2NII.in.nvols ] = system([ 'cat ' ...
                    obj.Params.DCM2NII.scanlog ...
                    ' | grep ' objParams.DCM2NII.seq_names ' | grep " 35 " | tail -1 | awk ''{ print $7 }'' ' ]);
            catch
                errormsg=['DCM2NII: No 35 vols. when reading scanlog located in: ' ... 
                    obj.Params.DCM2NII.scanlog '\n' ];
                obj.UpdateErrors(errormsg);
            end
            obj.Params.DCM2NII.in.nvols=str2num(obj.Params.DCM2NII.in.nvols);
            [ ~ , obj.Params.DCM2NII.in.first_dcmfiles ] = system([ 'cat ' ...
                obj.Params.DCM2NII.scanlog ...
                ' | grep ' objParams.DCM2NII.seq_names ' | grep " 35 " | tail -1 | awk ''{ print $8 }'' ' ]);
            
            obj.Params.DCM2NII.out.location = [ obj.root 'Orig' filesep ];
            obj.Params.DCM2NII.out.fn = [ objParams.DCM2NII.seq_names '.nii.gz' ];
            obj.Params.DCM2NII.in.fsl2std_param = '-1 0 0 254 \n0 1 0 254 \n0 0 -1 0 \n0 0 0 1';
            obj.proc_dcm2nii
        end
    end
end