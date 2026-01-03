public with sharing class SpeakerSlotController {

    public class SlotDTO {
        @AuraEnabled public Id sessionId;
        @AuraEnabled public Date sessionDate;
        @AuraEnabled public String startTime;
        @AuraEnabled public String endTime;
        @AuraEnabled public Boolean isBooked;
        @AuraEnabled public String title;
    }

    @AuraEnabled(cacheable=true)
    public static List<SlotDTO> getSlots(Id speakerId) {
        if (speakerId == null) {
            throw new AuraHandledException('Speaker is required');
        }

        Date today = Date.today();

        List<Session__c> sessions = [
            SELECT Id, Name, Session_Date__c, Start_Time__c, End_Time__c
            FROM Session__c
            WHERE Session_Date__c >= :today
            ORDER BY Session_Date__c, Start_Time__c
        ];

        Set<Id> bookedSessionIds = new Set<Id>();
        for (Speaker_Assignment__c sa : [
            SELECT Session__c
            FROM Speaker_Assignment__c
            WHERE Auditor__c = :speakerId
        ]) {
            bookedSessionIds.add(sa.Session__c);
        }

        List<SlotDTO> result = new List<SlotDTO>();

        for (Session__c s : sessions) {
            SlotDTO dto = new SlotDTO();
            dto.sessionId   = s.Id;
            dto.sessionDate = s.Session_Date__c;
            dto.title       = s.Name;

            // ✅ CORRECT APEX TIME FORMAT
            dto.startTime = formatTime(s.Start_Time__c);
            dto.endTime   = formatTime(s.End_Time__c);

            dto.isBooked = bookedSessionIds.contains(s.Id);
            result.add(dto);
        }

        return result;
    }

    @AuraEnabled(cacheable=true)
    public static Map<Date, List<SlotDTO>> getSlotsGroupedByDate(Id speakerId) {
        Map<Date, List<SlotDTO>> grouped = new Map<Date, List<SlotDTO>>();

        for (SlotDTO slot : getSlots(speakerId)) {
            if (!grouped.containsKey(slot.sessionDate)) {
                grouped.put(slot.sessionDate, new List<SlotDTO>());
            }
            grouped.get(slot.sessionDate).add(slot);
        }

        return grouped;
    }

    // 🔹 Helper
    private static String formatTime(Time t) {
        if (t == null) return null;

        String hour   = t.hour()   < 10 ? '0' + t.hour()   : String.valueOf(t.hour());
        String minute = t.minute() < 10 ? '0' + t.minute() : String.valueOf(t.minute());

        return hour + ':' + minute;
    }
}