import { LightningElement, wire, track } from 'lwc';
import getDistinctImportMonths from '@salesforce/apex/CloudPrismCatalogController.getDistinctImportMonths';
import getCatalogChangeRows from '@salesforce/apex/CloudPrismCatalogController.getCatalogChangeRows';

const PRICING_COLS = [
    { label: 'CSP', fieldName: 'csp', type: 'text', initialWidth: 80 },
    { label: 'Catalog #', fieldName: 'catalogitemnumber', type: 'text' },
    { label: 'Title', fieldName: 'title', type: 'text', wrapText: true },
    { label: 'Type', fieldName: 'change_type', type: 'text', initialWidth: 100 },
    { label: 'JWCC (from)', fieldName: 'prevJwccUsd', type: 'text', initialWidth: 120 },
    { label: 'JWCC (to)', fieldName: 'currJwccUsd', type: 'text', initialWidth: 120 },
    { label: 'JWCC Δ', fieldName: 'custDeltaUsd', type: 'text', initialWidth: 120 },
    { label: 'Comm (from)', fieldName: 'prevCommUsd', type: 'text', initialWidth: 120 },
    { label: 'Comm (to)', fieldName: 'currCommUsd', type: 'text', initialWidth: 120 },
    { label: 'Comm Δ', fieldName: 'commDeltaUsd', type: 'text', initialWidth: 120 }
];

const EXCEPTION_COLS = [
    { label: 'CSP', fieldName: 'csp', type: 'text', initialWidth: 80 },
    { label: 'Exception ID', fieldName: 'exceptionuniqueid', type: 'text' },
    { label: 'Short name', fieldName: 'csoshortname', type: 'text' },
    { label: 'Type', fieldName: 'change_type', type: 'text', initialWidth: 100 },
    { label: 'Status (prev → curr)', fieldName: 'statusPair', type: 'text', wrapText: true },
    { label: 'Impact (prev → curr)', fieldName: 'impactPair', type: 'text', wrapText: true }
];

export default class CatalogChanges extends LightningElement {
    mode = 'pricing';
    monthFrom = '';
    monthTo = '';
    cspFilter = '';
    changeTypeFilter = '';

    @track pricingRows = [];
    @track exceptionRows = [];
    error;

    monthOptions = [];

    get schemaForMonths() {
        return this.mode === 'exceptions' ? 'exceptions' : 'pricing';
    }

    get changeEntityParam() {
        return this.mode === 'exceptions' ? 'exceptions' : 'pricing';
    }

    get cspOptions() {
        return [
            { label: 'All CSPs', value: '' },
            { label: 'AWS', value: 'aws' },
            { label: 'Azure', value: 'azure' },
            { label: 'GCP', value: 'gcp' },
            { label: 'Oracle', value: 'oracle' }
        ];
    }

    get changeTypeOptions() {
        return [
            { label: 'All types', value: '' },
            { label: 'Added', value: 'added' },
            { label: 'Removed', value: 'removed' },
            { label: 'Updated', value: 'updated' }
        ];
    }

    get pricingColumns() {
        return PRICING_COLS;
    }

    get exceptionColumns() {
        return EXCEPTION_COLS;
    }

    get isPricingMode() {
        return this.mode === 'pricing';
    }

    @wire(getDistinctImportMonths, { schemaName: '$schemaForMonths' })
    wiredMonths({ data, error }) {
        if (data) {
            this.monthOptions = data.map((m) => ({ label: m, value: m }));
        } else if (error) {
            this.monthOptions = [];
        }
    }

    @wire(getCatalogChangeRows, {
        entity: '$changeEntityParam',
        monthFrom: '$monthFrom',
        monthTo: '$monthTo',
        csp: '$cspFilter',
        changeType: '$changeTypeFilter'
    })
    wiredChanges({ data, error }) {
        if (error) {
            this.error = error;
            this.pricingRows = [];
            this.exceptionRows = [];
            return;
        }
        this.error = undefined;
        if (!data) {
            this.pricingRows = [];
            this.exceptionRows = [];
            return;
        }
        if (this.mode === 'pricing') {
            this.pricingRows = (data || []).map((r, i) => ({
                ...r,
                prevJwccUsd: formatUsd4(r.prev_jwcc),
                currJwccUsd: formatUsd4(r.curr_jwcc),
                custDeltaUsd: formatUsd4(r.cust_delta),
                prevCommUsd: formatUsd4(r.prev_comm),
                currCommUsd: formatUsd4(r.curr_comm),
                commDeltaUsd: formatUsd4(r.comm_delta),
                rowKey: (r.csp || '') + '|' + (r.catalogitemnumber || '') + '|' + i
            }));
            this.exceptionRows = [];
        } else {
            this.exceptionRows = (data || []).map((r, i) => ({
                ...r,
                statusPair: pair(r.exceptionstatus_prev, r.exceptionstatus_curr),
                impactPair: pair(r.impactlevel_prev, r.impactlevel_curr),
                rowKey: (r.csp || '') + '|' + (r.exceptionuniqueid || '') + '|' + i
            }));
            this.pricingRows = [];
        }
    }

    handleModePricing() {
        this.mode = 'pricing';
    }

    handleModeExceptions() {
        this.mode = 'exceptions';
    }

    handleMonthFrom(event) {
        this.monthFrom = event.detail.value;
    }

    handleMonthTo(event) {
        this.monthTo = event.detail.value;
    }

    handleCspChange(event) {
        this.cspFilter = event.detail.value;
    }

    handleChangeType(event) {
        this.changeTypeFilter = event.detail.value;
    }

    get errorMessage() {
        if (!this.error) return '';
        return this.error.body && this.error.body.message
            ? this.error.body.message
            : String(this.error);
    }

    get compareHint() {
        if (!this.monthFrom || !this.monthTo) {
            return 'Select From and To import months (load at least two months for the active schema).';
        }
        if (this.monthFrom >= this.monthTo) {
            return 'From month must be earlier than To month.';
        }
        return '';
    }

    get pricingButtonVariant() {
        return this.mode === 'pricing' ? 'brand' : 'neutral';
    }

    get exceptionsButtonVariant() {
        return this.mode === 'exceptions' ? 'brand' : 'neutral';
    }
}

function pair(a, b) {
    const p = a != null && a !== '' ? a : '—';
    const c = b != null && b !== '' ? b : '—';
    return p + ' → ' + c;
}

function formatUsd4(value) {
    if (value === null || value === undefined) {
        return '—';
    }
    const n = Number(value);
    if (Number.isNaN(n)) {
        return String(value);
    }
    return new Intl.NumberFormat('en-US', {
        style: 'currency',
        currency: 'USD',
        minimumFractionDigits: 4,
        maximumFractionDigits: 4
    }).format(n);
}
