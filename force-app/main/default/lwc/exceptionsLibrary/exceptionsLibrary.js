import { LightningElement, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { catalogExportFilename, downloadCsv } from 'c/exportTableCsv';
import getExceptionItems from '@salesforce/apex/CloudPrismCatalogController.getExceptionItems';

const COLS = [
    { label: 'CSP', fieldName: 'CSP__c', type: 'text', sortable: true, initialWidth: 90 },
    { label: 'Import month', fieldName: 'importMonth', type: 'text', sortable: true, initialWidth: 100 },
    { label: 'Exception ID', fieldName: 'Exception_Unique_Id__c', type: 'text', sortable: true },
    { label: 'Short name', fieldName: 'CSO_Short_Name__c', type: 'text', sortable: true },
    { label: 'Impact level', fieldName: 'Impact_Level__c', type: 'text', sortable: true },
    { label: 'Status', fieldName: 'Exception_Status__c', type: 'text', sortable: true },
    {
        label: 'PWS requirement',
        fieldName: 'Exception_PWS_Requirement__c',
        type: 'text',
        wrapText: true,
        sortable: true
    },
    {
        label: 'Basis',
        fieldName: 'Exception_Basis_For_Request__c',
        type: 'text',
        wrapText: true,
        sortable: true
    },
    {
        label: 'Requested duration',
        fieldName: 'Exception_Requested_Duration__c',
        type: 'text',
        sortable: true
    },
    {
        label: 'Suggested plan',
        fieldName: 'Exception_Suggested_Plan__c',
        type: 'text',
        wrapText: true,
        sortable: true
    }
];

export default class ExceptionsLibrary extends LightningElement {
    columns = COLS;
    @track rows = [];
    error;

    cspFilter = '';
    searchKey = '';

    sortedBy = 'Exception_Unique_Id__c';
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

    @wire(getExceptionItems, {
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

    get exportDisabled() {
        return !this.rows || this.rows.length === 0;
    }

    handleExportCsv() {
        downloadCsv({
            filename: catalogExportFilename('exceptions-library'),
            columns: COLS,
            rows: this.rows
        });
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Export started',
                message: `Downloading ${this.rows.length} row(s). Server limit is 500 rows per query.`,
                variant: 'success'
            })
        );
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
