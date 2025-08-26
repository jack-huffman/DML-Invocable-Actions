/**
* @File Name           :   DMLActionTest.cls
 * @Description         :   Test class for DMLAction class
 * @Author              :   Jack Huffman - Aleysian
 *==============================================================================
 * Ver         Date                     Author                    Modification
 *==============================================================================
 * 1.0      08.26.2025 				  Jack Huffman             	  Initial build
 **/
@IsTest
private class DMLActionTest {
    
    @TestSetup
    static void setupTestData() {
        // Create test accounts for testing
        List<Account> testAccounts = new List<Account>();
        for (Integer i = 1; i <= 5; i++) {
            testAccounts.add(new Account(
                Name = 'Test Account ' + i,
                BillingCity = 'Test City ' + i,
                BillingState = 'Test State'
            ));
        }
        insert testAccounts;
    }
    
    @IsTest
    static void testInsertOperationAllOrNothing() {
        // Test data
        List<Account> accountsToInsert = new List<Account>();
        for (Integer i = 1; i <= 3; i++) {
            accountsToInsert.add(new Account(
                Name = 'New Account ' + i,
                BillingCity = 'New City ' + i
            ));
        }
        
        // Create request
        DMLAction.DMLRequest request = new DMLAction.DMLRequest();
        request.records = accountsToInsert;
        request.dmlOperation = 'INSERT_OP';
        request.allOrNothing = true;
        
        Test.startTest();
        List<DMLAction.DMLResponse> responses = DMLAction.performDMLOperation(new List<DMLAction.DMLRequest>{request});
        Test.stopTest();
        
        // Assertions
        System.assertEquals(1, responses.size(), 'Should return one response');
        DMLAction.DMLResponse response = responses[0];
        System.assertEquals(true, response.success, 'Operation should be successful');
        System.assertEquals(3, response.totalRecordsProcessed, 'Should process 3 records');
        System.assertEquals(0, response.totalRecordsFailed, 'Should have no failed records');
        System.assertEquals(3, response.processedRecords.size(), 'Should have 3 processed records');
        System.assertEquals(0, response.failedRecords.size(), 'Should have no failed records');
        System.assertEquals(0, response.errorMessages.size(), 'Should have no error messages');
    }
    
    @IsTest
    static void testUpdateOperationAllOrNothing() {
        // Get existing accounts
        List<Account> existingAccounts = [SELECT Id, Name, BillingCity FROM Account LIMIT 3];
        
        // Update accounts
        for (Account acc : existingAccounts) {
            acc.BillingCity = 'Updated City';
        }
        
        // Create request
        DMLAction.DMLRequest request = new DMLAction.DMLRequest();
        request.records = existingAccounts;
        request.dmlOperation = 'UPDATE_OP';
        request.allOrNothing = true;
        
        Test.startTest();
        List<DMLAction.DMLResponse> responses = DMLAction.performDMLOperation(new List<DMLAction.DMLRequest>{request});
        Test.stopTest();
        
        // Assertions
        System.assertEquals(1, responses.size(), 'Should return one response');
        DMLAction.DMLResponse response = responses[0];
        System.assertEquals(true, response.success, 'Operation should be successful');
        System.assertEquals(3, response.totalRecordsProcessed, 'Should process 3 records');
        System.assertEquals(0, response.totalRecordsFailed, 'Should have no failed records');
    }
    
    @IsTest
    static void testDeleteOperationAllOrNothing() {
        // Get existing accounts
        List<Account> existingAccounts = [SELECT Id FROM Account LIMIT 2];
        
        // Create request
        DMLAction.DMLRequest request = new DMLAction.DMLRequest();
        request.records = existingAccounts;
        request.dmlOperation = 'DELETE_OP';
        request.allOrNothing = true;
        
        Test.startTest();
        List<DMLAction.DMLResponse> responses = DMLAction.performDMLOperation(new List<DMLAction.DMLRequest>{request});
        Test.stopTest();
        
        // Assertions
        System.assertEquals(1, responses.size(), 'Should return one response');
        DMLAction.DMLResponse response = responses[0];
        System.assertEquals(true, response.success, 'Operation should be successful');
        System.assertEquals(2, response.totalRecordsProcessed, 'Should process 2 records');
        System.assertEquals(0, response.totalRecordsFailed, 'Should have no failed records');
    }
    
    @IsTest
    static void testPartialSuccessInsert() {
        // Create accounts with some invalid data
        List<Account> accountsToInsert = new List<Account>();
        
        // Valid account
        accountsToInsert.add(new Account(
            Name = 'Valid Account',
            BillingCity = 'Valid City'
        ));
        
        // Invalid account (missing required Name field)
        accountsToInsert.add(new Account(
            BillingCity = 'Invalid City'
        ));
        
        // Valid account
        accountsToInsert.add(new Account(
            Name = 'Another Valid Account',
            BillingCity = 'Another Valid City'
        ));
        
        // Create request
        DMLAction.DMLRequest request = new DMLAction.DMLRequest();
        request.records = accountsToInsert;
        request.dmlOperation = 'INSERT_OP';
        request.allOrNothing = false;
        
        Test.startTest();
        List<DMLAction.DMLResponse> responses = DMLAction.performDMLOperation(new List<DMLAction.DMLRequest>{request});
        Test.stopTest();
        
        // Assertions
        System.assertEquals(1, responses.size(), 'Should return one response');
        DMLAction.DMLResponse response = responses[0];
        System.assertEquals(true, response.success, 'Operation should be partially successful');
        System.assertEquals(2, response.totalRecordsProcessed, 'Should process 2 valid records');
        System.assertEquals(1, response.totalRecordsFailed, 'Should have 1 failed record');
        System.assertEquals(2, response.processedRecords.size(), 'Should have 2 processed records');
        System.assertEquals(1, response.failedRecords.size(), 'Should have 1 failed record');
        System.assert(response.errorMessages.size() > 0, 'Should have error messages');
    }
    
    @IsTest
    static void testInvalidDMLOperation() {
        List<Account> accounts = new List<Account>{
            new Account(Name = 'Test Account')
        };
        
        DMLAction.DMLRequest request = new DMLAction.DMLRequest();
        request.records = accounts;
        request.dmlOperation = 'INVALID_OP';
        request.allOrNothing = true;
        
        Test.startTest();
        List<DMLAction.DMLResponse> responses = DMLAction.performDMLOperation(new List<DMLAction.DMLRequest>{request});
        Test.stopTest();
        
        // Assertions
        System.assertEquals(1, responses.size(), 'Should return one response');
        DMLAction.DMLResponse response = responses[0];
        System.assertEquals(false, response.success, 'Operation should fail');
        System.assertEquals(0, response.totalRecordsProcessed, 'Should process 0 records');
        System.assertEquals(0, response.totalRecordsFailed, 'Should have 0 failed records');
        System.assert(response.errorMessages.size() > 0, 'Should have error messages');
    }
    
    @IsTest
    static void testEmptyRecordsList() {
        DMLAction.DMLRequest request = new DMLAction.DMLRequest();
        request.records = new List<Account>();
        request.dmlOperation = 'INSERT_OP';
        request.allOrNothing = true;
        
        Test.startTest();
        List<DMLAction.DMLResponse> responses = DMLAction.performDMLOperation(new List<DMLAction.DMLRequest>{request});
        Test.stopTest();
        
        // Assertions
        System.assertEquals(1, responses.size(), 'Should return one response');
        DMLAction.DMLResponse response = responses[0];
        System.assertEquals(false, response.success, 'Operation should fail');
        System.assertEquals(0, response.totalRecordsProcessed, 'Should process 0 records');
        System.assert(response.errorMessages.size() > 0, 'Should have error messages');
    }
    
    @IsTest
    static void testNullRecords() {
        DMLAction.DMLRequest request = new DMLAction.DMLRequest();
        request.records = null;
        request.dmlOperation = 'INSERT_OP';
        request.allOrNothing = true;
        
        Test.startTest();
        List<DMLAction.DMLResponse> responses = DMLAction.performDMLOperation(new List<DMLAction.DMLRequest>{request});
        Test.stopTest();
        
        // Assertions
        System.assertEquals(1, responses.size(), 'Should return one response');
        DMLAction.DMLResponse response = responses[0];
        System.assertEquals(false, response.success, 'Operation should fail');
        System.assertEquals(0, response.totalRecordsProcessed, 'Should process 0 records');
        System.assert(response.errorMessages.size() > 0, 'Should have error messages');
    }
    
    @IsTest
    static void testMultipleRequests() {
        // First request - insert accounts
        List<Account> accountsToInsert = new List<Account>{
            new Account(Name = 'Multi Test 1'),
            new Account(Name = 'Multi Test 2')
        };
        
        DMLAction.DMLRequest request1 = new DMLAction.DMLRequest();
        request1.records = accountsToInsert;
        request1.dmlOperation = 'INSERT_OP';
        request1.allOrNothing = true;
        
        // Second request - update existing accounts
        List<Account> existingAccounts = [SELECT Id, Name FROM Account LIMIT 2];
        for (Account acc : existingAccounts) {
            acc.Name = acc.Name + ' - Updated';
        }
        
        DMLAction.DMLRequest request2 = new DMLAction.DMLRequest();
        request2.records = existingAccounts;
        request2.dmlOperation = 'UPDATE_OP';
        request2.allOrNothing = true;
        
        Test.startTest();
        List<DMLAction.DMLResponse> responses = DMLAction.performDMLOperation(new List<DMLAction.DMLRequest>{request1, request2});
        Test.stopTest();
        
        // Assertions
        System.assertEquals(2, responses.size(), 'Should return two responses');
        
        // Check first response (insert)
        DMLAction.DMLResponse response1 = responses[0];
        System.assertEquals(true, response1.success, 'First operation should be successful');
        System.assertEquals(2, response1.totalRecordsProcessed, 'Should process 2 records');
        
        // Check second response (update)
        DMLAction.DMLResponse response2 = responses[1];
        System.assertEquals(true, response2.success, 'Second operation should be successful');
        System.assertEquals(2, response2.totalRecordsProcessed, 'Should process 2 records');
    }
}
