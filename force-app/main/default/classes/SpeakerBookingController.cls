public with sharing class SpeakerBookingController {

    /* =====================================================
       Get Speaker Details
       Used by bookSession LWC (Right Section)
       ===================================================== */
    @AuraEnabled(cacheable=true)
    public static Speaker__c getSpeakerDetails(Id speakerId) {
        if (speakerId == null) {
            throw new AuraHandledException('Speaker Id is required');
        }

        return [
            SELECT Id, Name, Bio__c, Speciality__c, Email__c
            FROM Speaker__c
            WHERE Id = :speakerId
            LIMIT 1
        ];
    }

    /* =====================================================
       Create Speaker Assignment
       ===================================================== */
    @AuraEnabled
    public static void createAssignment(Id speakerId, Id sessionId) {
        if (speakerId == null || sessionId == null) {
            throw new AuraHandledException('Speaker and Session are required');
        }

        try {
            insert new Speaker_Assignment__c(
                Auditor__c = speakerId,
                Session__c = sessionId
            );
        } catch (DmlException e) {
            throw new AuraHandledException(
                'Unable to create assignment. Please try again.'
            );
        }
    }
}