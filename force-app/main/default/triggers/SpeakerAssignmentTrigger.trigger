trigger SpeakerAssignmentTrigger on Speaker_Assignment__c (
    before insert,
    before update
) {
    // Run validation only before save (insert/update)
    if (Trigger.isBefore && (Trigger.isInsert || Trigger.isUpdate)) {
        SpeakerAssignmentHandler.validateSpeakerAvailability(
            Trigger.new,
            Trigger.isUpdate ? Trigger.oldMap : null
        );
    }

  
}