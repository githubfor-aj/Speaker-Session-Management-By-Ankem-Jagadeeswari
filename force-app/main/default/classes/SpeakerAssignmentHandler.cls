public class SpeakerAssignmentHandler {

    /**
     * Validates that a Speaker (Auditor) is not double-booked
     * for overlapping sessions on the same date.
     *
     * @param newList  Trigger.new
     * @param oldMap   Trigger.oldMap (null for insert)
     */
    public static void validateSpeakerAvailability(
        List<Speaker_Assignment__c> newList,
        Map<Id, Speaker_Assignment__c> oldMap
    ) {

        // -----------------------------
        // 1. Collect Speaker & Session Ids
        // -----------------------------
        Set<Id> speakerIds = new Set<Id>();
        Set<Id> sessionIds = new Set<Id>();

        for (Speaker_Assignment__c sa : newList) {
            if (sa.Auditor__c != null && sa.Session__c != null) {
                speakerIds.add(sa.Auditor__c);
                sessionIds.add(sa.Session__c);
            }
        }

        if (speakerIds.isEmpty()) {
            return;
        }

        // -----------------------------
        // 2. Load Session details
        // -----------------------------
        Map<Id, Session__c> sessionMap = new Map<Id, Session__c>(
            [SELECT Session_Date__c, Start_Time__c, End_Time__c
             FROM Session__c
             WHERE Id IN :sessionIds]
        );

        // -----------------------------
        // 3. Load Existing Assignments
        // -----------------------------
        List<Speaker_Assignment__c> existingAssignments = [
            SELECT Id, Auditor__c,
                   Session__r.Session_Date__c,
                   Session__r.Start_Time__c,
                   Session__r.End_Time__c
            FROM Speaker_Assignment__c
            WHERE Auditor__c IN :speakerIds
        ];

        // -----------------------------
        // 4. NEW vs EXISTING
        // -----------------------------
        for (Speaker_Assignment__c newSA : newList) {

            // Skip update if no relevant field changed
            if (oldMap != null && oldMap.containsKey(newSA.Id)) {
                Speaker_Assignment__c oldSA = oldMap.get(newSA.Id);
                if (oldSA.Auditor__c == newSA.Auditor__c &&
                    oldSA.Session__c == newSA.Session__c) {
                    continue;
                }
            }

            Session__c newSession = sessionMap.get(newSA.Session__c);
            if (newSession == null) continue;

            for (Speaker_Assignment__c existingSA : existingAssignments) {
                if (existingSA.Id == newSA.Id) continue;

                if (existingSA.Auditor__c == newSA.Auditor__c &&
                    existingSA.Session__r.Session_Date__c == newSession.Session_Date__c &&
                    isOverlapping(
                        newSession.Start_Time__c,
                        newSession.End_Time__c,
                        existingSA.Session__r.Start_Time__c,
                        existingSA.Session__r.End_Time__c
                    )) {

                    newSA.addError('Speaker is already booked for this time.');
                }
            }
        }

        // -----------------------------
        // 5. NEW vs NEW (Bulk Safety)
        // -----------------------------
        for (Integer i = 0; i < newList.size(); i++) {
            for (Integer j = i + 1; j < newList.size(); j++) {

                Speaker_Assignment__c a = newList[i];
                Speaker_Assignment__c b = newList[j];

                if (a.Auditor__c != b.Auditor__c) continue;

                Session__c sa = sessionMap.get(a.Session__c);
                Session__c sb = sessionMap.get(b.Session__c);

                if (sa != null && sb != null &&
                    sa.Session_Date__c == sb.Session_Date__c &&
                    isOverlapping(
                        sa.Start_Time__c, sa.End_Time__c,
                        sb.Start_Time__c, sb.End_Time__c
                    )) {

                    a.addError('Speaker is already booked for this time.');
                    b.addError('Speaker is already booked for this time.');
                }
            }
        }
    }

    /**
     * Time overlap utility
     */
    private static Boolean isOverlapping(
        Time start1, Time end1,
        Time start2, Time end2
    ) {
        return start1 < end2 && end1 > start2;
    }
}