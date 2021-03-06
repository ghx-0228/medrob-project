classdef utils
    % utilities methods
    properties
        % null
    end
    methods (Static)
        
        function [clientID,vrep] = init_connection()
            
            % function used to initialize connection with vrep side
            
            fprintf(1,'START...  \n');
            vrep=remApi('remoteApi'); % using the prototype file (remoteApiProto.m)
            vrep.simxFinish(-1); % just in case, close all opened connections
            clientID=vrep.simxStart('127.0.0.1',19999,true,true,5000,5);
            fprintf(1,'client %d\n', clientID);
            if (clientID > -1)
                fprintf(1,'Connection: OK... \n');
            else
                fprintf(2,'Connection: ERROR \n');
                return;
            end
        end
        
        
        function [sync]  = syncronize(ID, vrep, h_joints, h_RCM, h_VS, h_EE)
      
            % used to wait to receive non zero values from vrep model
            % usually matlab and vrep need few seconds to send valid values
            
            sync = false;
            while ~sync
                % syncronizing all joints
                [~,~] = vrep.simxGetJointPosition(ID, h_joints(1), vrep.simx_opmode_streaming);
                [~,~] = vrep.simxGetJointPosition(ID, h_joints(2), vrep.simx_opmode_streaming);
                [~,~] = vrep.simxGetJointPosition(ID, h_joints(3), vrep.simx_opmode_streaming);
                [~,~] = vrep.simxGetJointPosition(ID, h_joints(4), vrep.simx_opmode_streaming);
                [~,~] = vrep.simxGetJointPosition(ID, h_joints(5), vrep.simx_opmode_streaming);
                [~,v1]=vrep.simxGetJointPosition(ID,h_joints(6),vrep.simx_opmode_streaming);
                sync = norm(v1,2)~=0;                
            end
            
            sync = false;
            while ~sync
                % syncronizing position of joint 6 wrt RCM
                [~, v2]=vrep.simxGetObjectPosition(ID, h_joints(6), h_RCM, vrep.simx_opmode_streaming);
                [~, ~]=vrep.simxGetObjectOrientation(ID, h_joints(6), h_RCM, vrep.simx_opmode_streaming); 
                % syncronizing position of joint 6 wrt VS
                [~, ~]=vrep.simxGetObjectPosition(ID, h_joints(6), h_VS, vrep.simx_opmode_streaming);
                [~, ~]=vrep.simxGetObjectOrientation(ID, h_joints(6), h_VS, vrep.simx_opmode_streaming);
                
                % syncronizing position of EE handle wrt VS
                [~, ~]=vrep.simxGetObjectPosition(ID, h_EE, h_VS, vrep.simx_opmode_streaming);
                [~, ~]=vrep.simxGetObjectOrientation(ID, h_EE, h_VS, vrep.simx_opmode_streaming);
                % syncronizing position of EE handle wrt RCM
                [~, ~]=vrep.simxGetObjectPosition(ID, h_EE, h_RCM, vrep.simx_opmode_streaming);
                [~, ~]=vrep.simxGetObjectOrientation(ID, h_EE, h_RCM, vrep.simx_opmode_streaming);
                             
                sync = norm(v2,2)~=0;
            end
            
            sync = false;            
            while ~sync
                % syncronizing position of RCM wrt VS
                [~, v3]=vrep.simxGetObjectPosition(ID, h_RCM ,h_VS, vrep.simx_opmode_streaming);
                [~, ~]=vrep.simxGetObjectOrientation(ID, h_RCM ,h_VS, vrep.simx_opmode_streaming);
                % syncronizing position of VS wrt RCM
                [~, ~]=vrep.simxGetObjectPosition(ID, h_VS, h_RCM, vrep.simx_opmode_streaming);
                [~, ~]=vrep.simxGetObjectOrientation(ID, h_VS, h_RCM, vrep.simx_opmode_streaming);
                
                sync = norm(v3,2)~=0;
            end
            
        end
        
        
        
        
        function [J] = build_point_jacobian(u,v,z,fl)
            
            % function used to build interaction matrix
            
            J = [ -fl/z     0          u/z     (u*v)/fl        -(fl+(u^2)/fl)      v; ...
                0         -fl/z      v/z     (fl+(v^2)/fl)    -(u*v)/fl          -u];
            
        end
        
        function [relative] = getPoseInRCM(vs2rcm,ee_pose_VS)           
            
            % INPUTS:
            % vs2rcm : 6x1 vector of position and orientation of RCM wrt VS
            % ee_pose_VS : pose of EE wrt VS
            
            % OUTPUT: pose in RCM frame
            
            
            % extracting rot. matrix associated to orientation described in euler
            % angles of RCM wrt VS.
            % This is used in calculating the relative position
            rotm_VS_RCM = eul2rotm(vs2rcm(4:6)', 'XYZ'); % vrep default eul represent.
            
            % This rot. matrix is the one attached to the relative position of EE wrt
            % VS.
            % ee_pose(4:6) is an euler angles representation from which i get a rot.
            % matrix. This is used in calculating the new orientation
            rotm_VS_EE = eul2rotm(ee_pose_VS(4:6)',  'XYZ');
            
            % This is [x y z] expressed in RCM frame starting from [x y z] in VS reference.
            relative_position = -(rotm_VS_RCM')*vs2rcm(1:3) + (rotm_VS_RCM')*ee_pose_VS(1:3);
            
            % This R4 matrix is the rotation matrix from RCM to EE
            % It's the result of concatenating RCM -> VS -> EE matrices
            R4 = rotm_VS_RCM\rotm_VS_EE; % inv(RotMatrix)*R3 -> same notation
            
            % From this rotation matrix extract euler angles orientation
            relative_orientation = rotm2eul(R4,'XYZ');
            
            % output
            relative = [relative_position; relative_orientation'];
            
        end
        
        function [error] = computeError(desired, current)
            % computes error between poses
            error = [desired(1:3)- current(1:3); angdiff(current(4:6),desired(4:6) )];
        end
        
        function [] = compute_grasp(clientID, h_7sx, h_7dx, vrep)
            % NOT USED
            
            % this function computes a grasp (only image rendering)
            % no interaction with objects
            
            sx = vrep.simxGetJointPosition(clientID,h_7sx,vrep.simx_opmode_streaming);
            dx = vrep.simxGetJointPosition(clientID,h_7dx,vrep.simx_opmode_streaming);
            
            % open
            while sx < 3.14/4
                [~] = vrep.simxSetJointPosition(clientID, h_7sx, sx, vrep.simx_opmode_streaming);
                sx = sx + 0.02;
                [~] = vrep.simxSetJointPosition(clientID, h_7dx, sx, vrep.simx_opmode_streaming);
                dx = dx + 0.02;
                pause(0.05);
            end
            
            pause(1);
            
            % close
            while sx > 0
                [~] = vrep.simxSetJointPosition(clientID, h_7sx, sx, vrep.simx_opmode_streaming);
                sx = sx - 0.02;
                [~] = vrep.simxSetJointPosition(clientID, h_7dx, sx, vrep.simx_opmode_streaming);
                dx = dx - 0.02;
                pause(0.05);
            end
        end
        
        function [pose] = getPose(who,wrt_who,ID,vrep)
                        
            %reading where's the dummy
            [~, position] = vrep.simxGetObjectPosition(ID, who, wrt_who, vrep.simx_opmode_streaming);
            [~, orientation] = vrep.simxGetObjectOrientation(ID, who, wrt_who, vrep.simx_opmode_streaming);
            pose = [position, orientation]';
        
        end
        
        
    end
end