import { LightningElement, wire, track } from 'lwc';
import getExceptionItems from '@salesforce/apex/CloudPrismCatalogController.getExceptionItems';

const COLS = [
    { label: 'CSP', fieldName: 'CSP__c', type: 'text', initialWidth: 90 },
    { label: 'Import month', fieldName: 'importMonth', type: 'text', initialWidth: 100 },
    { label: 'Exception ID', fieldName: 'Exception_Unique_Id__c', type: 'text' },
    { label: 'Short name', fieldName: 'CSO_Short_Name__c', type: 'text' },
    { label: 'Impact level', fieldName: 'Impact_Level__c', type: 'text' },
    { label: 'Status', fieldName: 'Exception_Status__c', type: 'text' },
    { label: 'PWS requirement', fieldName: 'Exception_PWS_Requirement__c', type: 'text', wrapText: true },
    { label: 'Basis', fieldName: 'Exception_Basis_For_Request__c', type: 'text', wrapText: true }
];

export default class ExceptionsLibrary extends LightningElement {
    columns = COLS;
    @track rows = [];
    error;

    cspFilter = '';
    searchKey = '';

    get cspOptions() {
        return [
            { label: 'All CSPs', value: '' },
            { label: 'AWS', value: 'aws' },
            { label: 'Azure', value: 'azure' },
            { label: 'GCP', value: 'gcp' },
            { label: 'Oracle', value: 'oracle' }
        ];
    }

    @wire(getExceptionItems, {
        csp: '$cspFilter',
        searchKey: '$searchKey',
        rowLimit: 500
    })
    wiredItems({ data, error }) {
        if (data) {
            this.rows = data.map((r) => ({
                ...r,
                importMonth: r.Catalog_Import__r ? r.Catalog_Import__r.Import_Month__c : ''
            }));
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.rows = [];
        }
    }

    handleCspChange(event) {
        this.cspFilter = event.detail.value;
    }

    handleSearchChange(event) {
        this.searchKey = event.detail.value;
    }

    get errorMessage() {
        if (!this.error) return '';
        return this.error.body && this.error.body.message
            ? this.error.body.message
            : String(this.error);
    }
}
