import { LightningElement, wire, track } from 'lwc';
import getPricingItems from '@salesforce/apex/CloudPrismCatalogController.getPricingItems';

const COLS = [
    { label: 'CSP', fieldName: 'CSP__c', type: 'text', initialWidth: 90 },
    { label: 'Import month', fieldName: 'importMonth', type: 'text', initialWidth: 100 },
    { label: 'Category', fieldName: 'Focus_Category__c', type: 'text', initialWidth: 120 },
    { label: 'Title', fieldName: 'Title__c', type: 'text', wrapText: true },
    { label: 'Short name', fieldName: 'CSO_Short_Name__c', type: 'text' },
    { label: 'Catalog #', fieldName: 'Catalog_Item_Number__c', type: 'text' },
    { label: 'Comm. price', fieldName: 'List_Unit_Price__c', type: 'number', typeAttributes: { minimumFractionDigits: 4 } },
    { label: 'Comm. UoI', fieldName: 'Pricing_Unit__c', type: 'text' },
    { label: 'JWCC price', fieldName: 'JWCC_Unit_Price__c', type: 'number', typeAttributes: { minimumFractionDigits: 4 } },
    { label: 'JWCC UoI', fieldName: 'JWCC_Unit_Of_Issue__c', type: 'text' },
    { label: 'Disc./Prem.', fieldName: 'Discount_Premium_Fee__c', type: 'text' }
];

export default class PricingCatalog extends LightningElement {
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

    @wire(getPricingItems, {
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

