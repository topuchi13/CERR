function infoS = CERR2WebrtDB(dirPath)
%CERR2DB.m
%This function writes CERR plans under dirPath to Database
%
%APA, 02/28/2011

dirPath = '/Users/aptea/Desktop/Duke_test_data';
%dirPath = '/Users/aptea/Desktop/Duke_test_data_1_plan';

study_id = 1;

%Store Log
infoS = struct('fullFileName','','allStructureNames','','allDoseNames','','error','');
infoS(1) = [];


%Find all CERR files
fileC = {};
if strcmpi(dirPath,'\') || strcmpi(dirPath,'/')
    filesTmp = getCERRfiles(dirPath(1:end-1));
else
    filesTmp = getCERRfiles(dirPath);
end
fileC = [fileC filesTmp];

%Extablish Database connection
setdbprefs({'NullStringRead';'NullNumberRead';'DataReturnFormat';'errorhandling'},{'';'NaN';'structure';'report'})

%Loop over CERR plans
for iFile=1:length(fileC)
        
    drawnow
    
    fileNum = length(infoS)+1;
    
    try
        planC = loadPlanC(fileC{iFile},tempdir);
        planC = updatePlanFields(planC);
    catch
        disp([fileC{iFile}, ' failed to load'])
        infoS(fileNum).error = 'Failed to Load';
        continue
    end
    
    infoS(fileNum).fullFileName = fileC{iFile};
    
    global planC
    
    % Quality assurance
    quality_assure_planC
    
    indexS = planC{end};  
    
    %MySQL database (Development)
    % conn = database('webCERR_development','root','aa#9135','com.mysql.jdbc.Driver','jdbc:mysql://127.0.0.1/webCERR_development');  
    conn = database('riview_dev','aptea','aptea654','com.mysql.jdbc.Driver','jdbc:mysql://plmpdb1.mskcc.org/riview_dev');  
    
    % Get patient_id
    for scanNum = 1:length(planC{indexS.scan})
        
        scanUID = planC{indexS.scan}(1).scanUID;
        
        %Find the matching patient in the database
        sqlq_find_patient = ['Select patient_id from scans where scan_uid = ''', scanUID,''''];
        pat_raw = exec(conn, sqlq_find_patient);
        pat = fetch(pat_raw);
        pat = pat.Data;
        if isstruct(pat)
            patient_id = pat.patient_id;
            break;
        else
            %New Patient
            patient_id = [];
        end
        
    end
       
    %Insert New patient into database
    patientName = planC{indexS.scan}(1).scanInfo(1).patientName;
    date_str = datestr(now,'yyyy-mm-dd HH:MM:SS');
    if ~isstruct(pat)
        %patient_id = char(java.util.UUID.randomUUID);
        if isempty(patient_id)
            insert(conn,'patients',{'study_id','first_name','last_name','created_at','updated_at'},{study_id,patientName,patientName,date_str,date_str});             
        else
            update(conn,'patients',{'id','study_id','first_name','last_name','updated_at'},{patient_id,study_id,patientName,patientName,date_str});
        end
    end    
    
    %Get patient_id
    if isempty(patient_id)
        sqlq_find_patient = ['Select id from patients where created_at = ''', date_str,''''];
        pat_raw = exec(conn, sqlq_find_patient);
        pat = fetch(pat_raw);
        pat = pat.Data;
        patient_id = pat.id;
    end
    
    close(conn)
    
    %Store file location in database
    scan_type = planC{indexS.scan}(1).scanType;
    write_cerr_file_location_to_webrtDB(patient_id,study_id,scan_type,fileC{iFile})    
    
    %Write "scan" to database
    write_scan_to_webrtDB(patient_id)
    
    %Write "structure" database
    write_structure_to_webrtDB(patient_id)
    
    %Write "dose" database
    write_dose_to_webrtDB(patient_id)
    
    %Write "DVH" to database
    write_dvh_to_webrtDB(patient_id)
    
    %Write Images and pointers to database
    write_images_to_webrtDB(patient_id)
    
    %Record logsd
    infoS(fileNum).allStructureNames = {planC{indexS.structures}.structureName};    
    infoS(fileNum).allDoseNames = {planC{indexS.dose}.fractionGroupID};
    
    close(conn)
    
    clear global planC
    
end


return;

