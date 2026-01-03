public with sharing class SpeakerSearchController {

    /**
     * Search speakers by Name and/or Speciality
     * Used by: speakerSearch LWC
     */
    @AuraEnabled(cacheable=true)
    public static List<Speaker__c> searchSpeakers(
        String nameKeyword,
        String speciality
    ) {
        // Build base query
        String soql = 'SELECT Id, Name, Email__c, Bio__c, Speciality__c ' +
                      'FROM Speaker__c WHERE Id != null';

        // Optional filters
        if (String.isNotBlank(nameKeyword)) {
            soql += ' AND Name LIKE \'%' + String.escapeSingleQuotes(nameKeyword) + '%\'';
        }

        if (String.isNotBlank(speciality)) {
            soql += ' AND Speciality__c = :speciality';
        }

        soql += ' ORDER BY Name';

        return Database.query(soql);
    }
}