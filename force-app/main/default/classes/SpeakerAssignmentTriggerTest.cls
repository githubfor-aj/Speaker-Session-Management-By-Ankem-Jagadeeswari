@IsTest
public class SpeakerAssignmentTriggerTest {

    /* -----------------------------
       TEST DATA SETUP (RUNS ONCE)
       ----------------------------- */
    @TestSetup
    static void setupData() {

        // Speakers
        Speaker__c sp1 = new Speaker__c(
            Name = 'Ravi Kumar',
            Email__c = 'ravi@test.com',
            Speciality__c = 'Apex'
        );
        Speaker__c sp2 = new Speaker__c(
            Name = 'Anita Sharma',
            Email__c = 'anita@test.com',
            Speciality__c = 'LWC'
        );
        insert new List<Speaker__c>{ sp1, sp2 };

        // Sessions (same day)
        Session__c s1 = new Session__c(
            Name = 'Session 1',
            Session_Date__c = Date.today().addDays(1),
            Start_Time__c = Time.newInstance(10, 0, 0, 0),
            End_Time__c   = Time.newInstance(11, 0, 0, 0),
            Level__c = 'Beginner'
        );

        Session__c s2 = new Session__c(
            Name = 'Session 2',
            Session_Date__c = Date.today().addDays(1),
            Start_Time__c = Time.newInstance(10, 30, 0, 0),
            End_Time__c   = Time.newInstance(11, 30, 0, 0),
            Level__c = 'Intermediate'
        );

        Session__c s3 = new Session__c(
            Name = 'Session 3',
            Session_Date__c = Date.today().addDays(1),
            Start_Time__c = Time.newInstance(11, 30, 0, 0),
            End_Time__c   = Time.newInstance(12, 30, 0, 0),
            Level__c = 'Advanced'
        );

        insert new List<Session__c>{ s1, s2, s3 };
    }

    /* -----------------------------
       TEST 1: VALID INSERT (PASS)
       ----------------------------- */
    @IsTest
    static void testValidInsert() {

        Speaker__c sp = [SELECT Id FROM Speaker__c WHERE Name='Ravi Kumar' LIMIT 1];
        Session__c s3 = [SELECT Id FROM Session__c WHERE Name='Session 3' LIMIT 1];

        Test.startTest();
        insert new Speaker_Assignment__c(
            Auditor__c = sp.Id,
            Session__c = s3.Id
        );
        Test.stopTest();
    }

    /* -----------------------------
       TEST 2: INSERT CONFLICT (FAIL)
       ----------------------------- */
    @IsTest
    static void testInsertConflict() {

        Speaker__c sp = [SELECT Id FROM Speaker__c WHERE Name='Ravi Kumar' LIMIT 1];
        List<Session__c> sessions =
            [SELECT Id FROM Session__c ORDER BY Name];

        insert new Speaker_Assignment__c(
            Auditor__c = sp.Id,
            Session__c = sessions[0].Id
        );

        Test.startTest();
        try {
            insert new Speaker_Assignment__c(
                Auditor__c = sp.Id,
                Session__c = sessions[1].Id
            );
            System.assert(false, 'Conflict should have been detected');
        } catch (DmlException e) {
            System.assert(
                e.getMessage().contains('already'),
                'Expected overlap error message'
            );
        }
        Test.stopTest();
    }

    /* -----------------------------
       TEST 3: BULK INSERT CONFLICT
       ----------------------------- */
    @IsTest
    static void testBulkInsertConflict() {

        Speaker__c sp = [SELECT Id FROM Speaker__c WHERE Name='Ravi Kumar' LIMIT 1];
        List<Session__c> sessions =
            [SELECT Id FROM Session__c ORDER BY Name];

        List<Speaker_Assignment__c> batch = new List<Speaker_Assignment__c>{
            new Speaker_Assignment__c(Auditor__c = sp.Id, Session__c = sessions[0].Id),
            new Speaker_Assignment__c(Auditor__c = sp.Id, Session__c = sessions[1].Id)
        };

        Test.startTest();
        try {
            insert batch;
            System.assert(false, 'Bulk conflict should have been detected');
        } catch (DmlException e) {
            System.assert(
                e.getMessage().contains('already'),
                'Expected bulk overlap error'
            );
        }
        Test.stopTest();
    }

    /* -----------------------------
       TEST 4: MULTIPLE SPEAKERS OK
       ----------------------------- */
    @IsTest
    static void testMultipleSpeakersSameSession() {

        List<Speaker__c> speakers = [SELECT Id FROM Speaker__c];
        Session__c session =
            [SELECT Id FROM Session__c WHERE Name='Session 1' LIMIT 1];

        Test.startTest();
        insert new Speaker_Assignment__c(
            Auditor__c = speakers[0].Id,
            Session__c = session.Id
        );
        insert new Speaker_Assignment__c(
            Auditor__c = speakers[1].Id,
            Session__c = session.Id
        );
        Test.stopTest();
    }

    /* -----------------------------
       TEST 5: UPDATE AUDITOR CONFLICT
       ----------------------------- */
    @IsTest
    static void testUpdateAuditorConflict() {

        List<Speaker__c> speakers = [SELECT Id FROM Speaker__c ORDER BY Name];
        List<Session__c> sessions = [SELECT Id FROM Session__c ORDER BY Name];

        Speaker_Assignment__c sa1 = new Speaker_Assignment__c(
            Auditor__c = speakers[0].Id,
            Session__c = sessions[0].Id
        );
        insert sa1;

        Speaker_Assignment__c sa2 = new Speaker_Assignment__c(
            Auditor__c = speakers[1].Id,
            Session__c = sessions[1].Id
        );
        insert sa2;

        // Change auditor to create conflict
        sa2.Auditor__c = speakers[0].Id;

        Test.startTest();
        try {
            update sa2;
            System.assert(false, 'Update conflict should have failed');
        } catch (DmlException e) {
            System.assert(
                e.getMessage().contains('already'),
                'Expected update conflict error'
            );
        }
        Test.stopTest();
    }
}