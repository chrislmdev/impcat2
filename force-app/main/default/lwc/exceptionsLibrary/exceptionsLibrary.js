import { LightningElement, wire, track } from 'lwc';
import { loadStyle, loadScript } from 'lightning/platformResourceLoader';
import getExceptionItems from '@salesforce/apex/CloudPrismCatalogController.getExceptionItems';
import getDistinctImportMonths from '@salesforce/apex/CloudPrismCatalogController.getDistinctImportMonths';
import { readStoredThemeMode, persistThemeMode, computeEffectiveTheme } from './themeUtil';

function buildCloudPrismAssetUrls() {
    const origin = typeof window !== 'undefined' && window.location ? window.location.origin : '';
    const r = (name) => `${origin}/resource/${encodeURIComponent(name)}`;
    return {
        theme: r('CloudPrismThemeStyles'),
        jspdfUmd: r('jspdfUmd'),
        jspdfAutotable: r('jspdfAutotable'),
        exportLib: r('cloudPrismExportLib')
    };
}

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
    _assetUrls = {};
    _themeStyleLoaded = false;
    exportScriptsLoaded = false;

    sortedBy = 'Exception_Unique_Id__c';
    sortedDirection = 'asc';
    rawRows = [];

    monthOptions = [];
    statusOptions = [];
    /** Status picklist built from statuses seen in wire results (no separate Apex). */
    _seenStatuses = new Set();

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

        this._assetUrls = buildCloudPrismAssetUrls();
        if (this._assetUrls.theme && !this._themeStyleLoaded) {
            this._themeStyleLoaded = true;
            loadStyle(this, this._assetUrls.theme).catch(() => {});
        }
    }

    disconnectedCallback() {
        if (this._mq && this._boundMq) {
            this._mq.removeEventListener('change', this._boundMq);
        }
    }

    _applyEffectiveTheme() {
        this.effectiveTheme = computeEffectiveTheme(this.themeMode);
    }

    handleThemeSystem() {
        this.themeMode = 'system';
        persistThemeMode(this.themeMode);
        this._applyEffectiveTheme();
    }

    handleThemeLight() {
        this.themeMode = 'light';
        persistThemeMode(this.themeMode);
        this.effectiveTheme = 'light';
    }

    handleThemeDark() {
        this.themeMode = 'dark';
        persistThemeMode(this.themeMode);
        this.effectiveTheme = 'dark';
    }

    @wire(getDistinctImportMonths, { schemaName: 'exceptions' })
    wiredMonths({ data, error }) {
        if (data) {
            this.monthOptions = data.map((m) => ({ label: m, value: m }));
        } else if (error) {
            this.monthOptions = [];
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
            (data || []).forEach((r) => {
                const s = r.Exception_Status__c;
                if (s) {
                    this._seenStatuses.add(s);
                }
            });
            this.statusOptions = Array.from(this._seenStatuses)
                .sort()
                .map((st) => ({ label: st, value: st }));
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

    async handleExportCsv() {
        if (!this.hasRows) {
            return;
        }
        try {
            await this._ensureExportLib();
            window.CloudPrismExport.downloadCsv('exceptions-library', EXPORT_COLS, this.rows);
        } catch (e) {
            // eslint-disable-next-line no-console
            console.error(e);
        }
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

    _getAssetUrls() {
        if (this._assetUrls && this._assetUrls.exportLib) {
            return this._assetUrls;
        }
        this._assetUrls = buildCloudPrismAssetUrls();
        return this._assetUrls;
    }

    async _ensureExportLib() {
        if (window.CloudPrismExport) {
            return;
        }
        const urls = this._getAssetUrls();
        if (!urls.exportLib) {
            throw new Error('cloudPrismExportLib static resource missing in org.');
        }
        await loadScript(this, urls.exportLib);
    }

    async _ensureExportScripts() {
        if (this.exportScriptsLoaded) {
            return;
        }
        const urls = this._getAssetUrls();
        if (!urls.jspdfUmd || !urls.jspdfAutotable || !urls.exportLib) {
            throw new Error('jspdfUmd, jspdfAutotable, or cloudPrismExportLib static resource missing in org.');
        }
        if (!window.jspdf || !window.jspdf.jsPDF) {
            await loadScript(this, urls.jspdfUmd);
        }
        await loadScript(this, urls.jspdfAutotable);
        if (!window.CloudPrismExport) {
            await loadScript(this, urls.exportLib);
        }
        this.exportScriptsLoaded = true;
    }

    get errorMessage() {
        if (!this.error) {
            return '';
        }
        return this.error.body && this.error.body.message ? this.error.body.message : String(this.error);
    }
}
