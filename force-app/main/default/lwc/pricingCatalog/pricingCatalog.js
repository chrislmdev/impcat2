import { LightningElement, wire, track } from 'lwc';
import { loadStyle, loadScript } from 'lightning/platformResourceLoader';
import getPricingItems from '@salesforce/apex/CloudPrismCatalogController.getPricingItems';
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
    { label: 'Category', fieldName: 'Focus_Category__c', type: 'text', sortable: true, initialWidth: 120 },
    { label: 'Title', fieldName: 'Title__c', type: 'text', wrapText: true, sortable: true },
    { label: 'Short name', fieldName: 'CSO_Short_Name__c', type: 'text', sortable: true },
    { label: 'Catalog #', fieldName: 'Catalog_Item_Number__c', type: 'text', sortable: true },
    {
        label: 'Comm. price',
        fieldName: 'List_Unit_Price__c',
        type: 'currency',
        sortable: true,
        typeAttributes: { currencyCode: 'USD' },
        initialWidth: 130
    },
    { label: 'Comm. UoI', fieldName: 'Pricing_Unit__c', type: 'text', sortable: true },
    {
        label: 'JWCC price',
        fieldName: 'JWCC_Unit_Price__c',
        type: 'currency',
        sortable: true,
        typeAttributes: { currencyCode: 'USD' },
        initialWidth: 130
    },
    { label: 'JWCC UoI', fieldName: 'JWCC_Unit_Of_Issue__c', type: 'text', sortable: true },
    { label: 'Disc./Prem.', fieldName: 'Discount_Premium_Fee__c', type: 'text', sortable: true }
];

/** Export uses stable string values (currency shown as plain numbers in CSV/PDF) */
const EXPORT_COLS = [
    { label: 'CSP', fieldName: 'CSP__c' },
    { label: 'Import month', fieldName: 'importMonth' },
    { label: 'Category', fieldName: 'Focus_Category__c' },
    { label: 'Title', fieldName: 'Title__c' },
    { label: 'Short name', fieldName: 'CSO_Short_Name__c' },
    { label: 'Catalog #', fieldName: 'Catalog_Item_Number__c' },
    { label: 'List price', fieldName: 'List_Unit_Price__c' },
    { label: 'Pricing unit', fieldName: 'Pricing_Unit__c' },
    { label: 'JWCC price', fieldName: 'JWCC_Unit_Price__c' },
    { label: 'JWCC UoI', fieldName: 'JWCC_Unit_Of_Issue__c' },
    { label: 'Discount/Premium', fieldName: 'Discount_Premium_Fee__c' }
];

export default class PricingCatalog extends LightningElement {
    columns = COLS;
    @track rows = [];
    error;

    cspFilter = '';
    searchKey = '';
    importMonthFilter = '';
    focusCategoryFilter = '';

    themeMode = 'system';
    effectiveTheme = 'light';
    _assetUrls = {};
    _themeStyleLoaded = false;
    exportScriptsLoaded = false;

    sortedBy = 'Catalog_Item_Number__c';
    sortedDirection = 'asc';
    rawRows = [];

    monthOptions = [];
    categoryOptions = [];
    /** Category picklist from Focus_Category__c seen in wire results (no getDistinctFocusCategories Apex). */
    _seenFocusCategories = new Set();

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

    get categoryFilterOptions() {
        return [{ label: 'All categories', value: '' }, ...this.categoryOptions];
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

    @wire(getDistinctImportMonths, { schemaName: 'pricing' })
    wiredMonths({ data, error }) {
        if (data) {
            this.monthOptions = data.map((m) => ({ label: m, value: m }));
        } else if (error) {
            this.monthOptions = [];
        }
    }

    @wire(getPricingItems, {
        csp: '$cspFilter',
        searchKey: '$searchKey',
        importMonth: '$importMonthFilter',
        focusCategory: '$focusCategoryFilter',
        rowLimit: 2000
    })
    wiredItems({ data, error }) {
        if (data) {
            (data || []).forEach((r) => {
                const c = r.Focus_Category__c;
                if (c) {
                    this._seenFocusCategories.add(c);
                }
            });
            this.categoryOptions = Array.from(this._seenFocusCategories)
                .sort()
                .map((cat) => ({ label: cat, value: cat }));
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

    handleCategoryFilterChange(event) {
        this.focusCategoryFilter = event.detail.value;
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

    async handleExportCsv() {
        if (!this.hasRows) {
            return;
        }
        try {
            await this._ensureExportLib();
            window.CloudPrismExport.downloadCsv('pricing-catalog', EXPORT_COLS, this.rows);
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
            window.CloudPrismExport.downloadPdf('pricing-catalog', 'Pricing Catalog', EXPORT_COLS, this.rows);
        } catch (e) {
            // eslint-disable-next-line no-console
            console.error(e);
        }
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
