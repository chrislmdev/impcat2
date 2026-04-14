import { LightningElement, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { catalogExportFilename, downloadCsv } from 'c/exportTableCsv';
import getPricingItems from '@salesforce/apex/CloudPrismCatalogController.getPricingItems';

const COLS = [
    { label: 'CSP', fieldName: 'CSP__c', type: 'text', sortable: true, initialWidth: 90 },
    { label: 'Import month', fieldName: 'importMonth', type: 'text', sortable: true, initialWidth: 100 },
    { label: 'Category', fieldName: 'Focus_Category__c', type: 'text', sortable: true, initialWidth: 120 },
    { label: 'Title', fieldName: 'Title__c', type: 'text', wrapText: true, sortable: true },
    { label: 'Short name', fieldName: 'CSO_Short_Name__c', type: 'text', sortable: true },
    { label: 'Catalog #', fieldName: 'Catalog_Item_Number__c', type: 'text', sortable: true },
    {
        label: 'Comm. price',
        fieldName: 'commPriceUsd',
        type: 'text',
        sortable: true,
        initialWidth: 130
    },
    { label: 'Comm. UoI', fieldName: 'Pricing_Unit__c', type: 'text', sortable: true },
    {
        label: 'JWCC price',
        fieldName: 'jwccPriceUsd',
        type: 'text',
        sortable: true,
        initialWidth: 130
    },
    { label: 'JWCC UoI', fieldName: 'JWCC_Unit_Of_Issue__c', type: 'text', sortable: true },
    { label: 'Disc./Prem.', fieldName: 'Discount_Premium_Fee__c', type: 'text', sortable: true }
];

export default class PricingCatalog extends LightningElement {
    columns = COLS;
    @track rows = [];
    error;

    cspFilter = '';
    searchKey = '';

    sortedBy = 'Catalog_Item_Number__c';
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

    @wire(getPricingItems, {
        csp: '$cspFilter',
        searchKey: '$searchKey',
        rowLimit: 500
    })
    wiredItems({ data, error }) {
        if (data) {
            this.rawRows = data.map((r) => {
                const listP = fieldFromRow(r, 'List_Unit_Price__c');
                const jwccP = fieldFromRow(r, 'JWCC_Unit_Price__c');
                const row = {
                    ...r,
                    importMonth: r.Catalog_Import__r ? r.Catalog_Import__r.Import_Month__c : '',
                    commPriceUsd: formatUsd4(listP),
                    jwccPriceUsd: formatUsd4(jwccP),
                    listUnitPriceNum: toSortableNum(listP),
                    jwccPriceNum: toSortableNum(jwccP)
                };
                ['List_Unit_Price__c', customFieldToJsName('List_Unit_Price__c'), 'JWCC_Unit_Price__c', customFieldToJsName('JWCC_Unit_Price__c')]
                    .filter(Boolean)
                    .forEach((k) => {
                        delete row[k];
                    });
                return row;
            });
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
            const cmp = compareByField(a, b, fieldName);
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
            filename: catalogExportFilename('pricing-catalog'),
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

function compareByField(a, b, fieldName) {
    let va;
    let vb;
    if (fieldName === 'commPriceUsd') {
        va = a.listUnitPriceNum;
        vb = b.listUnitPriceNum;
    } else if (fieldName === 'jwccPriceUsd') {
        va = a.jwccPriceNum;
        vb = b.jwccPriceNum;
    } else {
        va = sortableScalar(a[fieldName]);
        vb = sortableScalar(b[fieldName]);
    }
    return compareValues(va, vb);
}

function sortableScalar(v) {
    if (v === null || v === undefined) {
        return '';
    }
    if (typeof v === 'number' && !Number.isNaN(v)) {
        return v;
    }
    return String(v).toLowerCase();
}

function compareValues(va, vb) {
    const na = typeof va === 'number' && !Number.isNaN(va);
    const nb = typeof vb === 'number' && !Number.isNaN(vb);
    if (na && nb) {
        if (va === vb) {
            return 0;
        }
        return va < vb ? -1 : 1;
    }
    if (na && !nb) {
        return -1;
    }
    if (!na && nb) {
        return 1;
    }
    const sa = va === null || va === undefined ? '' : String(va);
    const sb = vb === null || vb === undefined ? '' : String(vb);
    return sa.localeCompare(sb, undefined, { numeric: true, sensitivity: 'base' });
}

function toSortableNum(value) {
    if (value === null || value === undefined || value === '') {
        return null;
    }
    const n = Number(value);
    return Number.isNaN(n) ? null : n;
}

function fieldFromRow(row, apiName) {
    if (!row || !apiName) {
        return undefined;
    }
    if (Object.prototype.hasOwnProperty.call(row, apiName)) {
        return row[apiName];
    }
    const camel = customFieldToJsName(apiName);
    if (camel && Object.prototype.hasOwnProperty.call(row, camel)) {
        return row[camel];
    }
    return undefined;
}

/** Custom field API name to common LWC wire key, e.g. List_Unit_Price__c -> listUnitPrice__c */
function customFieldToJsName(apiName) {
    if (!apiName || !apiName.endsWith('__c')) {
        return null;
    }
    const stem = apiName.slice(0, -3);
    const pascal = stem.replace(/_([a-zA-Z0-9])/g, (_, ch) => ch.toUpperCase());
    const first = pascal.charAt(0).toLowerCase() + pascal.slice(1);
    return first + '__c';
}

function formatUsd4(value) {
    if (value === null || value === undefined) {
        return '—';
    }
    const n = Number(value);
    if (Number.isNaN(n)) {
        return String(value);
    }
    const neg = n < 0;
    const abs = Math.abs(n);
    const body = abs.toLocaleString('en-US', {
        minimumFractionDigits: 4,
        maximumFractionDigits: 4
    });
    return (neg ? '-' : '') + '$' + body;
}
