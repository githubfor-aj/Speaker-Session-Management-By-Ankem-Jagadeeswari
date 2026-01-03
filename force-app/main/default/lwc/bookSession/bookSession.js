import { LightningElement, api, track, wire } from 'lwc';
import { subscribe, MessageContext, APPLICATION_SCOPE } from 'lightning/messageService';
import SPEAKER_CHANNEL from '@salesforce/messageChannel/SpeakerSelected__c';
import getSpeakerDetails from '@salesforce/apex/SpeakerBookingController.getSpeakerDetails';
import getSlotsGroupedByDate from '@salesforce/apex/SpeakerSlotController.getSlotsGroupedByDate';
import createAssignment from '@salesforce/apex/SpeakerBookingController.createAssignment';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class BookSession extends LightningElement {
    subscription;

    _speakerId;
    @track speaker = {};
    @track slotsByDate = {};
    @track calendarDates = [];
    @track isSpeakerSelected = false;

    // UI state
    todayStr = new Date().toISOString().split('T')[0];
    @track selectedDate = this.todayStr;
    @track showOnlySelected = false;
    @track todayScrolled = false; // ✅ new flag for scrolling today

    weekDays = ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'];
    monthLabel = '';
    currentMonth;
    currentYear;

    @wire(MessageContext) messageContext;

    @api
    get speakerId() { return this._speakerId; }
    set speakerId(value) {
        this._speakerId = value;
        if (value) {
            this.loadSpeaker();
            this.loadSlots();
        } else {
            this.speaker = {};
            this.slotsByDate = {};
            this.calendarDates = [];
            this.selectedDate = this.todayStr;
        }
    }

    connectedCallback() {
        if (!this._speakerId) {
            this.subscribeToMessageChannel();
        }
    }

    subscribeToMessageChannel() {
        if (this.subscription) return;
        this.subscription = subscribe(
            this.messageContext,
            SPEAKER_CHANNEL,
            (message) => this.handleSpeakerSelected(message),
            { scope: APPLICATION_SCOPE }
        );
    }

    handleSpeakerSelected(message) {
        if (message && message.speakerId) {
            this.speakerId = message.speakerId;
            this.isSpeakerSelected = true;
        }
    }

    async loadSpeaker() {
        try {
            this.speaker = await getSpeakerDetails({ speakerId: this._speakerId });
        } catch (e) {
            this.showToast('Error', e.body?.message || e.message, 'error');
        }
    }

    async loadSlots() {
        try {
            const slots = await getSlotsGroupedByDate({ speakerId: this._speakerId });
            this.slotsByDate = slots;
            this.initCalendar();
        } catch (e) {
            this.showToast('Error', e.body?.message || e.message, 'error');
        }
    }

    initCalendar() {
        const seed = this.parseYmd(this.selectedDate) || new Date();
        this.currentMonth = seed.getMonth();
        this.currentYear = seed.getFullYear();
        this.updateMonthLabel();
        this.computeCalendarDates();
    }

    prevMonth() {
        this.currentMonth--;
        if (this.currentMonth < 0) { this.currentMonth = 11; this.currentYear--; }
        this.updateMonthLabel();
        this.computeCalendarDates();
    }

    nextMonth() {
        this.currentMonth++;
        if (this.currentMonth > 11) { this.currentMonth = 0; this.currentYear++; }
        this.updateMonthLabel();
        this.computeCalendarDates();
    }

    updateMonthLabel() {
        const months = ['January','February','March','April','May','June','July','August','September','October','November','December'];
        this.monthLabel = months[this.currentMonth] + ' ' + this.currentYear;
    }

    computeCalendarDates() {
    const lastDay = new Date(this.currentYear, this.currentMonth + 1, 0);
    const dates = [];

    for (let d = 1; d <= lastDay.getDate(); d++) {
        const isoStr = `${this.currentYear}-${String(this.currentMonth + 1).padStart(2,'0')}-${String(d).padStart(2,'0')}`;
        const currentDate = new Date(this.currentYear, this.currentMonth, d);

        // Get slots for this date
        let daySlots = [];
        if (this.slotsByDate && typeof this.slotsByDate === 'object') {
            for (const [key, slots] of Object.entries(this.slotsByDate)) {
                const keyDate = new Date(key);
                if (keyDate.toDateString() === currentDate.toDateString()) {
                    daySlots = slots;
                    break;
                }
            }
        }

        const isFuture = this.isDateFuture(isoStr);
        const hasAnySessions = Array.isArray(daySlots) && daySlots.length > 0;
        const hasAvailableSlot = daySlots.some(s => !s.isBooked && !this.checkForOverlap(s, currentDate));
        const isFullyBookedOrOverlapped = hasAnySessions && !hasAvailableSlot;

        // CSS classes
        let css = 'day slds-col slds-text-align_center slds-p-around_xx-small';
        const isSelected = isoStr === this.selectedDate;
        const isDisabled = !isFuture || !hasAnySessions;

        if (isFullyBookedOrOverlapped) css += ' full';  // orange
        if (isDisabled) css += ' past';                 // disabled
        if (isoStr === this.todayStr) css += ' today';
        if (isSelected) css += ' selected';

        // Tooltip
        const tooltip = !isFuture ? 'Past date' : !hasAnySessions ? 'No sessions' : isFullyBookedOrOverlapped ? 'Fully booked / Overlapped' : 'Select a slot to book';

        // Prepare slot info
        const renderedSlots = (daySlots || []).map(s => {
            const isOverlapping = this.checkForOverlap(s, currentDate);
            return { 
                ...s, 
                isDisabled: s.isBooked || !isFuture || isOverlapping, 
                buttonLabel: s.isBooked ? 'Booked' : isOverlapping ? 'Overlapped' : 'Book', 
                buttonVariant: isOverlapping ? 'destructive' : 'neutral' 
            };
        });

        const todayDate = new Date();
        const isToday = currentDate.toDateString() === todayDate.toDateString();

        dates.push({
            date: isoStr,
            label: d,
            css,
            tooltip,
            slots: hasAnySessions ? renderedSlots : [],
            isFuture,
            hasAnySessions,
            hasAvailableSlot,
            isFullyBookedOrOverlapped,
            isSelected,
            isDisabled,
            isToday
        });
    }

    this.calendarDates = dates;

    // Scroll to today only once
    if (!this.todayScrolled) {
        this.todayScrolled = true;
        requestAnimationFrame(() => {
            const todayElement = this.template.querySelector('.day.today');
            if (todayElement) {
                todayElement.scrollIntoView({ behavior: 'smooth', inline: 'center' });
            }
        });
    }
}


    async bookSlot(event) {
        const sessionId = event.currentTarget.dataset.id;
        try {
            await createAssignment({ speakerId: this._speakerId, sessionId });

            const updatedSlotsByDate = JSON.parse(JSON.stringify(this.slotsByDate));
            Object.values(updatedSlotsByDate).forEach(slots => {
                slots.forEach(slot => { if (slot.sessionId === sessionId) slot.isBooked = true; });
            });
            this.slotsByDate = updatedSlotsByDate;

            this.initCalendar();
            this.showToast('Success','Session booked successfully!','success');
        } catch (e) {
            this.showToast('Error', e.body?.message || e.message, 'error');
        }
    }

    handleDateChange(event) {
        const newVal = event.target.value;
        if (!newVal) return;
        this.selectedDate = newVal;

        const picked = this.parseYmd(newVal);
        if (picked && (picked.getMonth() !== this.currentMonth || picked.getFullYear() !== this.currentYear)) {
            this.currentMonth = picked.getMonth();
            this.currentYear = picked.getFullYear();
            this.updateMonthLabel();
        }
        this.computeCalendarDates();
    }

   handleDayClick(event) {
    const dateStr = event.currentTarget.dataset.date;
    const day = this.calendarDates.find(d => d.date === dateStr);

    // Disable click if date is past or has no sessions
    if (!dateStr || !day || day.isDisabled) return;

    this.selectedDate = dateStr;
    const picked = this.parseYmd(dateStr);
    if (picked && (picked.getMonth() !== this.currentMonth || picked.getFullYear() !== this.currentYear)) {
        this.currentMonth = picked.getMonth();
        this.currentYear = picked.getFullYear();
        this.updateMonthLabel();
    }
    this.computeCalendarDates();
    }


    handleToggleSelected(event) {
        this.showOnlySelected = event.target.checked;
    }

    parseYmd(ymd) {
        if (!ymd) return null;
        const [y, m, d] = ymd.split('-').map(Number);
        if (Number.isNaN(y) || Number.isNaN(m) || Number.isNaN(d)) return null;
        return new Date(y, m - 1, d);
    }

    isDateFuture(ymd) {
        const dateOnly = this.parseYmd(ymd);
        if (!dateOnly) return false;
        const now = new Date();
        const nowOnly = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        return dateOnly >= nowOnly;
    }

    checkForOverlap(slot, selectedDate) {
        let daySlots = [];
        for (const [key, slots] of Object.entries(this.slotsByDate || {})) {
            const keyDate = new Date(key);
            if (keyDate.toDateString() === selectedDate.toDateString()) {
                daySlots = slots;
                break;
            }
        }
        const bookedSlots = daySlots.filter(s => s.isBooked && s.sessionId !== slot.sessionId);
        for (const booked of bookedSlots) {
            const slotStart = this.parseTime(slot.startTime);
            const slotEnd = this.parseTime(slot.endTime);
            const bookedStart = this.parseTime(booked.startTime);
            const bookedEnd = this.parseTime(booked.endTime);
            if (slotStart < bookedEnd && slotEnd > bookedStart) return true;
        }
        return false;
    }

    parseTime(timeStr) {
        const [hours, minutes] = timeStr.split(':').map(Number);
        return hours * 60 + minutes;
    }

    get selectedDaySlots() {
        const selectedDateObj = this.parseYmd(this.selectedDate);
        if (!selectedDateObj) return [];
        const selectedDay = this.calendarDates.find(day => this.parseYmd(day.date)?.toDateString() === selectedDateObj.toDateString());
        if (!selectedDay || !selectedDay.slots) return [];

        return selectedDay.slots.map(s => {
            const isFuture = this.isDateFuture(this.selectedDate);
            const isOverlapping = this.checkForOverlap(s, selectedDateObj);
            return { ...s, isDisabled: s.isBooked || !isFuture || isOverlapping, buttonLabel: s.isBooked ? 'Booked' : isOverlapping ? 'Overlapped' : 'Book', isOverlapping, buttonVariant: isOverlapping ? 'destructive' : 'neutral' };
        });
    }

    get calendarDatesToRender() {
        return this.showOnlySelected ? this.calendarDates.filter(d => d.date === this.selectedDate) : this.calendarDates;
    }

    showToast(title,message,variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}