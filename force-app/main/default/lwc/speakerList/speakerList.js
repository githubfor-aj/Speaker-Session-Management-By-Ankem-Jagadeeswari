// speakerList.js
import { LightningElement, api } from 'lwc';

export default class SpeakerList extends LightningElement {
    @api speakers;

    columns = [
        { label: 'Name', fieldName: 'Name' },
        { label: 'Email', fieldName: 'Email__c' },
        { label: 'Speciality', fieldName: 'Speciality__c' },
        {
            type: 'button',
            typeAttributes: {
                label: 'View',
                name: 'view',
                variant: 'brand'
            }
        }
    ];

    handleRowAction(event) {
        const row = event.detail.row;

        // Dispatch to parent
        this.dispatchEvent(new CustomEvent('speakerselected', {
            detail: { speakerId: row.Id }
        }));
    }
}