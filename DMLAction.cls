/**
 * @File Name           :   DMLAction.cls
 * @Description         :   Utility invocable class for performing DML operations from Flow
 * @Author              :   Jack Huffman - Aleysian
 *==============================================================================
 * Ver         Date                     Author                    Modification
 *==============================================================================
 * 1.0      08.26.2025 				  Jack Huffman             	  Initial build
 **/
public with sharing class DMLAction {
    
    public enum DMLOperation {
        INSERT_OP,
        UPDATE_OP,
        DELETE_OP,
        UPSERT_OP
    }
    
    public class DMLRequest {
        @InvocableVariable(label='Records to Process' description='List of SObject records to perform DML operation on' required=true)
        public List<SObject> records;
        
        @InvocableVariable(label='DML Operation' description='Type of DML operation to perform' required=true)
        public String dmlOperation;
        
        @InvocableVariable(label='All or Nothing' description='If true, all records must succeed or all will be rolled back. If false, partial success is allowed.' required=false)
        public Boolean allOrNothing = true;
        
        @InvocableVariable(label='External ID Field' description='Field name for upsert operation (required for upsert)' required=false)
        public String externalIdField;
    }
    
    public class DMLResponse {
        @InvocableVariable(label='Success' description='Whether the DML operation was successful')
        public Boolean success;
        
        @InvocableVariable(label='Error Messages' description='List of error messages if the operation failed')
        public List<String> errorMessages;
        
        @InvocableVariable(label='Processed Records' description='List of records that were successfully processed')
        public List<SObject> processedRecords;
        
        @InvocableVariable(label='Failed Records' description='List of records that failed to process')
        public List<SObject> failedRecords;
        
        @InvocableVariable(label='Total Records Processed' description='Total number of records processed')
        public Integer totalRecordsProcessed;
        
        @InvocableVariable(label='Total Records Failed' description='Total number of records that failed')
        public Integer totalRecordsFailed;
    }
    
    @InvocableMethod(label='Perform DML Operation' description='Performs DML operations (insert, update, delete, upsert) on a list of SObject records with configurable error handling')
    public static List<DMLResponse> performDMLOperation(List<DMLRequest> requests) {
        List<DMLResponse> responses = new List<DMLResponse>();
        
        for (DMLRequest request : requests) {
            DMLResponse response = new DMLResponse();
            response.success = false;
            response.errorMessages = new List<String>();
            response.processedRecords = new List<SObject>();
            response.failedRecords = new List<SObject>();
            response.totalRecordsProcessed = 0;
            response.totalRecordsFailed = 0;
            
            try {
                // Validate input
                if (request.records == null || request.records.isEmpty()) {
                    response.errorMessages.add('No records provided for DML operation');
                    responses.add(response);
                    continue;
                }
                
                if (request.dmlOperation == null) {
                    response.errorMessages.add('DML operation type is required');
                    responses.add(response);
                    continue;
                }
                
                // Determine DML operation
                DMLOperation operation;
                try {
                    operation = DMLOperation.valueOf(request.dmlOperation.toUpperCase());
                } catch (Exception e) {
                    response.errorMessages.add('Invalid DML operation: ' + request.dmlOperation + '. Valid operations are: INSERT_OP, UPDATE_OP, DELETE_OP, UPSERT_OP');
                    responses.add(response);
                    continue;
                }
                
                // Perform DML operation based on allOrNothing flag
                if (request.allOrNothing == true) {
                    // All or nothing approach
                    response = performAllOrNothingDML(request, operation);
                } else {
                    // Partial success approach
                    response = performPartialSuccessDML(request, operation);
                }
                
            } catch (Exception e) {
                response.errorMessages.add('Unexpected error: ' + e.getMessage());
                response.totalRecordsFailed = request.records != null ? request.records.size() : 0;
            }
            
            responses.add(response);
        }
        
        return responses;
    }
    
    private static DMLResponse performAllOrNothingDML(DMLRequest request, DMLOperation operation) {
        DMLResponse response = new DMLResponse();
        response.success = false;
        response.errorMessages = new List<String>();
        response.processedRecords = new List<SObject>();
        response.failedRecords = new List<SObject>();
        response.totalRecordsProcessed = 0;
        response.totalRecordsFailed = 0;
        
        try {
            switch on operation {
                when INSERT_OP {
                    insert request.records;
                    response.processedRecords = request.records;
                    response.totalRecordsProcessed = request.records.size();
                }
                when UPDATE_OP {
                    update request.records;
                    response.processedRecords = request.records;
                    response.totalRecordsProcessed = request.records.size();
                }
                when DELETE_OP {
                    delete request.records;
                    response.processedRecords = request.records;
                    response.totalRecordsProcessed = request.records.size();
                }
                when UPSERT_OP {
                    if (String.isBlank(request.externalIdField)) {
                        response.errorMessages.add('External ID field is required for upsert operation');
                        response.totalRecordsFailed = request.records.size();
                        return response;
                    }
                    
                    // Get the SObject type and external ID field
                    String sObjectTypeName = request.records[0].getSObjectType().getDescribe().getName();
                    Schema.SObjectField externalIdField = Schema.getGlobalDescribe()
                        .get(sObjectTypeName)
                        .getDescribe()
                        .fields
                        .getMap()
                        .get(request.externalIdField);
                    
                    if (externalIdField == null) {
                        response.errorMessages.add('External ID field "' + request.externalIdField + '" not found on ' + sObjectTypeName);
                        response.totalRecordsFailed = request.records.size();
                        return response;
                    }
                    
                    Database.upsert(request.records, externalIdField);
                    response.processedRecords = request.records;
                    response.totalRecordsProcessed = request.records.size();
                }
            }
            
            response.success = true;
            
        } catch (DmlException e) {
            response.errorMessages.add('DML Error: ' + e.getMessage());
            response.totalRecordsFailed = request.records.size();
            
            // Add field-level errors if available
            for (Integer i = 0; i < e.getNumDml(); i++) {
                String errorMsg = 'Record ' + (e.getDmlIndex(i) + 1) + ': ' + e.getDmlMessage(i);
                response.errorMessages.add(errorMsg);
            }
        } catch (Exception e) {
            response.errorMessages.add('Unexpected error: ' + e.getMessage());
            response.totalRecordsFailed = request.records.size();
        }
        
        return response;
    }
    
    private static DMLResponse performPartialSuccessDML(DMLRequest request, DMLOperation operation) {
        DMLResponse response = new DMLResponse();
        response.success = false;
        response.errorMessages = new List<String>();
        response.processedRecords = new List<SObject>();
        response.failedRecords = new List<SObject>();
        response.totalRecordsProcessed = 0;
        response.totalRecordsFailed = 0;
        
        try {
            List<Database.SaveResult> saveResults;
            List<Database.DeleteResult> deleteResults;
            List<Database.UpsertResult> upsertResults;
            
            switch on operation {
                when INSERT_OP {
                    saveResults = Database.insert(request.records, false);
                    processSaveResults(saveResults, request.records, response);
                }
                when UPDATE_OP {
                    saveResults = Database.update(request.records, false);
                    processSaveResults(saveResults, request.records, response);
                }
                when DELETE_OP {
                    deleteResults = Database.delete(request.records, false);
                    processDeleteResults(deleteResults, request.records, response);
                }
                when UPSERT_OP {
                    if (String.isBlank(request.externalIdField)) {
                        response.errorMessages.add('External ID field is required for upsert operation');
                        response.totalRecordsFailed = request.records.size();
                        return response;
                    }
                    
                    // Get the SObject type and external ID field
                    String sObjectTypeName = request.records[0].getSObjectType().getDescribe().getName();
                    Schema.SObjectField externalIdField = Schema.getGlobalDescribe()
                        .get(sObjectTypeName)
                        .getDescribe()
                        .fields
                        .getMap()
                        .get(request.externalIdField);
                    
                    if (externalIdField == null) {
                        response.errorMessages.add('External ID field "' + request.externalIdField + '" not found on ' + sObjectTypeName);
                        response.totalRecordsFailed = request.records.size();
                        return response;
                    }
                    
                    upsertResults = Database.upsert(request.records, externalIdField, false);
                    processUpsertResults(upsertResults, request.records, response);
                }
            }
            
            // Consider operation successful if at least one record was processed
            response.success = response.totalRecordsProcessed > 0;
            
        } catch (Exception e) {
            response.errorMessages.add('Unexpected error: ' + e.getMessage());
            response.totalRecordsFailed = request.records.size();
        }
        
        return response;
    }
    
    private static void processSaveResults(List<Database.SaveResult> results, List<SObject> records, DMLResponse response) {
        for (Integer i = 0; i < results.size(); i++) {
            Database.SaveResult result = results[i];
            SObject record = records[i];
            
            if (result.isSuccess()) {
                response.processedRecords.add(record);
                response.totalRecordsProcessed++;
            } else {
                response.failedRecords.add(record);
                response.totalRecordsFailed++;
                
                String errorMsg = 'Record ' + (i + 1) + ': ';
                for (Database.Error error : result.getErrors()) {
                    errorMsg += error.getMessage() + '; ';
                }
                response.errorMessages.add(errorMsg);
            }
        }
    }
    
    private static void processDeleteResults(List<Database.DeleteResult> results, List<SObject> records, DMLResponse response) {
        for (Integer i = 0; i < results.size(); i++) {
            Database.DeleteResult result = results[i];
            SObject record = records[i];
            
            if (result.isSuccess()) {
                response.processedRecords.add(record);
                response.totalRecordsProcessed++;
            } else {
                response.failedRecords.add(record);
                response.totalRecordsFailed++;
                
                String errorMsg = 'Record ' + (i + 1) + ': ';
                for (Database.Error error : result.getErrors()) {
                    errorMsg += error.getMessage() + '; ';
                }
                response.errorMessages.add(errorMsg);
            }
        }
    }
    
    private static void processUpsertResults(List<Database.UpsertResult> results, List<SObject> records, DMLResponse response) {
        for (Integer i = 0; i < results.size(); i++) {
            Database.UpsertResult result = results[i];
            SObject record = records[i];
            
            if (result.isSuccess()) {
                response.processedRecords.add(record);
                response.totalRecordsProcessed++;
            } else {
                response.failedRecords.add(record);
                response.totalRecordsFailed++;
                
                String errorMsg = 'Record ' + (i + 1) + ': ';
                for (Database.Error error : result.getErrors()) {
                    errorMsg += error.getMessage() + '; ';
                }
                response.errorMessages.add(errorMsg);
            }
        }
    }
}
