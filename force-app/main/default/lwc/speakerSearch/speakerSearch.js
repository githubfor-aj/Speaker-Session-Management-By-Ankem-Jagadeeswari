// speakerSearch.js
import { LightningElement, track, wire } from 'lwc';
import searchSpeakers from '@salesforce/apex/SpeakerSearchController.searchSpeakers';
import { publish, MessageContext, APPLICATION_SCOPE } from 'lightning/messageService';
import SPEAKER_CHANNEL from '@salesforce/messageChannel/SpeakerSelected__c';

export default class SpeakerSearch extends LightningElement {
    name = '';
    speciality = '';
    @track speakers = [];

    specialityOptions = [
        { label: 'None', value: '' },
        { label: 'Apex', value: 'Apex' },
        { label: 'LWC', value: 'LWC' },
        { label: 'Integrations', value: 'Integrations' },
        { label: 'Architecture', value: 'Architecture' }
    ];

    @wire(MessageContext)
    messageContext;

    handleNameChange(event) {
        this.name = event.target.value;
    }

    handleSpecialityChange(event) {
        this.speciality = event.target.value;
    }

    handleSearch() {
        // Prevent search if no criteria are provided
        if (!this.name.trim() && !this.speciality) {
            this.speakers = [];
            return;
        }
        
        searchSpeakers({ nameKeyword: this.name, speciality: this.speciality })
            .then(result => { this.speakers = result; })
            .catch(error => { console.error('Search error:', error); });
    }

    // Handle event from child (speakerList)
    handleSpeakerSelected(event) {
        const speakerId = event.detail.speakerId;

        // Publish selected speaker via LMS
        publish(this.messageContext, SPEAKER_CHANNEL, { speakerId }, { scope: APPLICATION_SCOPE });
    }
}