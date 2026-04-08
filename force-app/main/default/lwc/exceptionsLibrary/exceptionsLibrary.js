import { LightningElement, wire, track } from 'lwc';
import { loadStyle, loadScript } from 'lightning/platformResourceLoader';
import getExceptionItems from '@salesforce/apex/CloudPrismCatalogController.getExceptionItems';
import getDistinctImportMonths from '@salesforce/apex/CloudPrismCatalogController.getDistinctImportMonths';
import getDistinctExceptionStatuses from '@salesforce/apex/CloudPrismCatalogController.getDistinctExceptionStatuses';
import CLOUD_PRISM_THEME_STYLES from '@salesforce/resourceUrl/CloudPrismThemeStyles';
import JSPDF_UMD from '@salesforce/resourceUrl/jspdfUmd';
import JSPDF_AUTOTABLE from '@salesforce/resourceUrl/jspdfAutotable';
import CLOUD_PRISM_EXPORT_LIB from '@salesforce/resourceUrl/cloudPrismExportLib';
import { readStoredThemeMode, persistThemeMode, computeEffectiveTheme } from './themeUtil';

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
        label: 'Security',
        fieldName: 'Exception_Security__c',
        type: 'text',
        wrapText: true,
        sortable: true
    }
];

const EXPORT_COLS = [
    { label: 'CSP', fieldName: 'CSP__c' },
    { label: 'Import month', fieldName: 'importMonth' },
    { label: 'Exception ID', fieldName: 'Exception_Unique_Id__c' },
    { label: 'Short name', fieldName: 'CSO_Short_Name__c' },
    { label: 'Impact level', fieldName: 'Impact_Level__c' },
    { label: 'Status', fieldName: 'Exception_Status__c' },
    { label: 'PWS requirement', fieldName: 'Exception_PWS_Requirement__c' },
    { label: 'Basis', fieldName: 'Exception_Basis_For_Request__c' },
    { label: 'Security', fieldName: 'Exception_Security__c' }
];

export default class ExceptionsLibrary extends LightningElement {
    columns = COLS;
    @track rows = [];
    error;

    cspFilter = '';
    searchKey = '';
    importMonthFilter = '';
    exceptionStatusFilter = '';

    themeMode = 'system';
    effectiveTheme = 'light';
    exportScriptsLoaded = false;

    sortedBy = 'Exception_Unique_Id__c';
    sortedDirection = 'asc';
    rawRows = [];

    monthOptions = [];
    statusOptions = [];

    get cspOptions() {
        return [
            { label: 'All CSPs', value: '' },
            { label: 'AWS', value: 'aws' },
            { label: 'Azure', value: 'azure' },
            { label: 'GCP', value: 'gcp' },
            { label: 'Oracle', value: 'oracle' }
        ];
    }

    get monthFilterOptions() {
        return [{ label: 'All months', value: '' }, ...this.monthOptions];
    }

    get statusFilterOptions() {
        return [{ label: 'All statuses', value: '' }, ...this.statusOptions];
    }

    get rootClass() {
        return `cp-root cp-theme-${this.effectiveTheme}`;
    }

    get systemButtonVariant() {
        return this.themeMode === 'system' ? 'brand' : 'border-filled';
    }

    get lightButtonVariant() {
        return this.themeMode === 'light' ? 'brand' : 'border-filled';
    }

    get darkButtonVariant() {
        return this.themeMode === 'dark' ? 'brand' : 'border-filled';
    }

    get hasRows() {
        return this.rows && this.rows.length > 0;
    }

    get exportDisabled() {
        return !this.hasRows;
    }

    connectedCallback() {
        this.themeMode = readStoredThemeMode();
        this._applyEffectiveTheme();
        this._mq = window.matchMedia('(prefers-color-scheme: dark)');
        this._boundMq = () => {
            if (this.themeMode === 'system') {
                this.effectiveTheme = this._mq.matches ? 'dark' : 'light';
            }
        };
        this._mq.addEventListener('change', this._boundMq);

        loadStyle(this, CLOUD_PRISM_THEME_STYLES).catch(() => {});
    }

    disconnectedCallback() {
        if (this._mq && this._boundMq) {
            this._mq.removeEventListener('change', this._boundMq);
        }
    }

    _applyEffectiveTheme() {
        this.effectiveTheme = computeEffectiveTheme(this.themeMode);
    }

    handleThemeChange(event) {
        this.themeMode = event.detail.mode;
        persistThemeMode(this.themeMode);
        this._applyEffectiveTheme();
    }

    @wire(getDistinctImportMonths, { schemaName: 'exceptions' })
    wiredMonths({ data, error }) {
        if (data) {
            this.monthOptions = data.map((m) => ({ label: m, value: m }));
        } else if (error) {
            this.monthOptions = [];
        }
    }

    @wire(getDistinctExceptionStatuses)
    wiredStatuses({ data, error }) {
        if (data) {
            this.statusOptions = data.map((s) => ({ label: s, value: s }));
        } else if (error) {
            this.statusOptions = [];
        }
    }

    @wire(getExceptionItems, {
        csp: '$cspFilter',
        searchKey: '$searchKey',
        importMonth: '$importMonthFilter',
        exceptionStatus: '$exceptionStatusFilter',
        rowLimit: 2000
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

    handleCspChange(event) {
        this.cspFilter = event.detail.value;
    }

    handleSearchChange(event) {
        this.searchKey = event.detail.value;
    }

    handleMonthFilterChange(event) {
        this.importMonthFilter = event.detail.value;
    }

    handleStatusFilterChange(event) {
        this.exceptionStatusFilter = event.detail.value;
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
            const va = this._sortVal(a, fieldName);
            const vb = this._sortVal(b, fieldName);
            if (va < vb) {
                return -1 * dir;
            }
            if (va > vb) {
                return 1 * dir;
            }
            return 0;
        });
        this.rows = clone;
    }

    _sortVal(row, fieldName) {
        const v = row[fieldName];
        if (v === null || v === undefined) {
            return '';
        }
        if (typeof v === 'number') {
            return v;
        }
        return String(v).toLowerCase();
    }

    handleExportCsv() {
        if (!this.hasRows || !window.CloudPrismExport) {
            return;
        }
        window.CloudPrismExport.downloadCsv('exceptions-library', EXPORT_COLS, this.rows);
    }

    async handleExportPdf() {
        if (!this.hasRows) {
            return;
        }
        try {
            await this._ensureExportScripts();
            window.CloudPrismExport.downloadPdf('exceptions-library', 'Exceptions Library', EXPORT_COLS, this.rows);
        } catch (e) {
            // eslint-disable-next-line no-console
            console.error(e);
        }
    }

    async _ensureExportScripts() {
        if (this.exportScriptsLoaded) {
            return;
        }
        await loadScript(this, JSPDF_UMD);
        await loadScript(this, JSPDF_AUTOTABLE);
        await loadScript(this, CLOUD_PRISM_EXPORT_LIB);
        this.exportScriptsLoaded = true;
    }

    get errorMessage() {
        if (!this.error) {
            return '';
        }
        return this.error.body && this.error.body.message ? this.error.body.message : String(this.error);
    }
}
