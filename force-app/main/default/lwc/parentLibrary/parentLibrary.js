import { LightningElement, wire, track } from 'lwc';
import getParentItems from '@salesforce/apex/CloudPrismCatalogController.getParentItems';

const COLS = [
    { label: 'CSP', fieldName: 'CSP__c', type: 'text', sortable: true, initialWidth: 90 },
    { label: 'Import month', fieldName: 'importMonth', type: 'text', sortable: true, initialWidth: 100 },
    { label: 'Title', fieldName: 'Title__c', type: 'text', wrapText: true, sortable: true },
    { label: 'CSP name (file col)', fieldName: 'CSP_Name__c', type: 'text', sortable: true },
    { label: 'Short name', fieldName: 'CSO_Short_Name__c', type: 'text', sortable: true },
    { label: 'Category', fieldName: 'Category__c', type: 'text', sortable: true },
    { label: 'Impact level', fieldName: 'Impact_Level__c', type: 'text', sortable: true },
    { label: 'Product URL', fieldName: 'Product_URL__c', type: 'url', sortable: true },
    { label: 'Available for usage', fieldName: 'Available_For_Usage__c', type: 'text', sortable: true }
];

export default class ParentLibrary extends LightningElement {
    columns = COLS;
    @track rows = [];
    error;

    cspFilter = '';
    searchKey = '';

    sortedBy = 'Title__c';
    sortedDirection = 'asc';
    rawRows = [];

    get cspOptions() {
        return [
            { label: 'All CSPs', value: '' },
            { label: 'AWS', value: 'aws' },
            { label: 'Azure', value: 'azure' },
            { label: 'GCP', value: 'gcp' },
            { label: 'Oracle', value: 'oracle' }
        ];
    }

    @wire(getParentItems, {
        csp: '$cspFilter',
        searchKey: '$searchKey',
        rowLimit: 500
    })
    wiredItems({ data, error }) {
        if (data) {
            this.rawRows = data.map((r) => ({
                ...r,
                importMonth: r.Catalog_Import__r ? r.Catalog_Import__r.Import_Month__c : ''
            }));
            this.sortData(this.sortedBy, this.sortedDirection);
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.rows = [];
            this.rawRows = [];
        }
    }

    handleSort(event) {
        const { fieldName, sortDirection } = event.detail;
        this.sortedBy = fieldName;
        this.sortedDirection = sortDirection;
        this.sortData(fieldName, sortDirection);
    }

    sortData(fieldName, direction) {
        const clone = [...this.rawRows];
        const dir = direction === 'asc' ? 1 : -1;
        clone.sort((a, b) => {
            const va = sortVal(a[fieldName]);
            const vb = sortVal(b[fieldName]);
            const cmp = compareStrings(va, vb);
            return cmp * dir;
        });
        this.rows = clone;
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

function sortVal(v) {
    if (v === null || v === undefined) {
        return '';
    }
    if (typeof v === 'number' && !Number.isNaN(v)) {
        return v;
    }
    return String(v).toLowerCase();
}

function compareStrings(va, vb) {
    if (typeof va === 'number' && typeof vb === 'number') {
        if (va === vb) {
            return 0;
        }
        return va < vb ? -1 : 1;
    }
    const sa = va === '' || va === null || va === undefined ? '' : String(va);
    const sb = vb === '' || vb === null || vb === undefined ? '' : String(vb);
    return sa.localeCompare(sb, undefined, { numeric: true, sensitivity: 'base' });
}
