import { LightningElement, wire, track } from 'lwc';
import { loadStyle, loadScript } from 'lightning/platformResourceLoader';
import getDistinctImportMonths from '@salesforce/apex/CloudPrismCatalogController.getDistinctImportMonths';
import getCatalogChangeRows from '@salesforce/apex/CloudPrismCatalogController.getCatalogChangeRows';
import getCloudPrismStaticAssetUrls from '@salesforce/apex/CloudPrismCatalogController.getCloudPrismStaticAssetUrls';
import { readStoredThemeMode, persistThemeMode, computeEffectiveTheme } from './themeUtil';

const PRICING_COLS = [
    { label: 'CSP', fieldName: 'csp', type: 'text', sortable: true, initialWidth: 80 },
    { label: 'Catalog #', fieldName: 'catalogitemnumber', type: 'text', sortable: true },
    { label: 'Title', fieldName: 'title', type: 'text', wrapText: true, sortable: true },
    { label: 'Type', fieldName: 'change_type', type: 'text', initialWidth: 100, sortable: true },
    { label: 'JWCC (from)', fieldName: 'prevJwccUsd', type: 'text', initialWidth: 120, sortable: true },
    { label: 'JWCC (to)', fieldName: 'currJwccUsd', type: 'text', initialWidth: 120, sortable: true },
    { label: 'JWCC Δ', fieldName: 'custDeltaUsd', type: 'text', initialWidth: 120, sortable: true },
    { label: 'Comm (from)', fieldName: 'prevCommUsd', type: 'text', initialWidth: 120, sortable: true },
    { label: 'Comm (to)', fieldName: 'currCommUsd', type: 'text', initialWidth: 120, sortable: true },
    { label: 'Comm Δ', fieldName: 'commDeltaUsd', type: 'text', initialWidth: 120, sortable: true }
];

const EXCEPTION_COLS = [
    { label: 'CSP', fieldName: 'csp', type: 'text', sortable: true, initialWidth: 80 },
    { label: 'Exception ID', fieldName: 'exceptionuniqueid', type: 'text', sortable: true },
    { label: 'Short name', fieldName: 'csoshortname', type: 'text', sortable: true },
    { label: 'Type', fieldName: 'change_type', type: 'text', initialWidth: 100, sortable: true },
    { label: 'Status (prev → curr)', fieldName: 'statusPair', type: 'text', wrapText: true, sortable: true },
    { label: 'Impact (prev → curr)', fieldName: 'impactPair', type: 'text', wrapText: true, sortable: true }
];

/** Datatable sorts formatted USD columns; compare using numeric fields. */
const PRICING_SORT_KEYS = {
    prevJwccUsd: 'prevJwccNum',
    currJwccUsd: 'currJwccNum',
    custDeltaUsd: 'custDeltaNum',
    prevCommUsd: 'prevCommNum',
    currCommUsd: 'currCommNum',
    commDeltaUsd: 'commDeltaNum'
};

const PRICING_EXPORT_COLS = PRICING_COLS.map((c) => ({ label: c.label, fieldName: c.fieldName }));
const EXCEPTION_EXPORT_COLS = EXCEPTION_COLS.map((c) => ({ label: c.label, fieldName: c.fieldName }));

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

    themeMode = 'system';
    effectiveTheme = 'light';
    _assetUrls = {};
    _themeStyleLoaded = false;

    pricingSortedBy = 'csp';
    pricingSortDirection = 'asc';
    exceptionSortedBy = 'exceptionuniqueid';
    exceptionSortDirection = 'asc';

    _rawPricingRows = [];
    _rawExceptionRows = [];

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

    get hasActiveRows() {
        return this.isPricingMode ? this.pricingRows.length > 0 : this.exceptionRows.length > 0;
    }

    get exportDisabled() {
        return !this.hasActiveRows;
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

        getCloudPrismStaticAssetUrls()
            .then((urls) => {
                this._assetUrls = urls || {};
                const themeUrl = this._assetUrls.theme;
                if (themeUrl && !this._themeStyleLoaded) {
                    this._themeStyleLoaded = true;
                    return loadStyle(this, themeUrl);
                }
                return undefined;
            })
            .catch(() => {
                /* ignore */
            });
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
            this._rawPricingRows = [];
            this._rawExceptionRows = [];
            return;
        }
        this.error = undefined;
        if (!data) {
            this.pricingRows = [];
            this.exceptionRows = [];
            this._rawPricingRows = [];
            this._rawExceptionRows = [];
            return;
        }
        if (this.mode === 'pricing') {
            const stripPriceKeys = (o) => {
                const keys = [
                    'prev_jwcc',
                    'prevJwcc',
                    'curr_jwcc',
                    'currJwcc',
                    'cust_delta',
                    'custDelta',
                    'prev_comm',
                    'prevComm',
                    'curr_comm',
                    'currComm',
                    'comm_delta',
                    'commDelta'
                ];
                keys.forEach((k) => {
                    delete o[k];
                });
            };
            this._rawPricingRows = (data || []).map((r, i) => {
                const cat =
                    apexField(r, 'catalogitemnumber') ??
                    apexField(r, 'catalogItemNumber') ??
                    '';
                const row = {
                    ...r,
                    prevJwccUsd: formatUsd4(apexField(r, 'prev_jwcc')),
                    currJwccUsd: formatUsd4(apexField(r, 'curr_jwcc')),
                    custDeltaUsd: formatUsd4(apexField(r, 'cust_delta')),
                    prevCommUsd: formatUsd4(apexField(r, 'prev_comm')),
                    currCommUsd: formatUsd4(apexField(r, 'curr_comm')),
                    commDeltaUsd: formatUsd4(apexField(r, 'comm_delta')),
                    prevJwccNum: toSortableNum(apexField(r, 'prev_jwcc')),
                    currJwccNum: toSortableNum(apexField(r, 'curr_jwcc')),
                    custDeltaNum: toSortableNum(apexField(r, 'cust_delta')),
                    prevCommNum: toSortableNum(apexField(r, 'prev_comm')),
                    currCommNum: toSortableNum(apexField(r, 'curr_comm')),
                    commDeltaNum: toSortableNum(apexField(r, 'comm_delta')),
                    rowKey: (apexField(r, 'csp') || '') + '|' + cat + '|' + i
                };
                stripPriceKeys(row);
                return row;
            });
            this._rawExceptionRows = [];
            this.exceptionRows = [];
            this.applyPricingSort();
        } else {
            this._rawExceptionRows = (data || []).map((r, i) => ({
                ...r,
                statusPair: pair(r.exceptionstatus_prev, r.exceptionstatus_curr),
                impactPair: pair(r.impactlevel_prev, r.impactlevel_curr),
                rowKey: (r.csp || '') + '|' + (r.exceptionuniqueid || '') + '|' + i
            }));
            this._rawPricingRows = [];
            this.pricingRows = [];
            this.applyExceptionSort();
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

    handlePricingSort(event) {
        const { fieldName, sortDirection } = event.detail;
        this.pricingSortedBy = fieldName;
        this.pricingSortDirection = sortDirection;
        this.applyPricingSort();
    }

    handleExceptionSort(event) {
        const { fieldName, sortDirection } = event.detail;
        this.exceptionSortedBy = fieldName;
        this.exceptionSortDirection = sortDirection;
        this.applyExceptionSort();
    }

    applyPricingSort() {
        this.pricingRows = sortRows(
            this._rawPricingRows,
            this.pricingSortedBy,
            this.pricingSortDirection,
            PRICING_SORT_KEYS
        );
    }

    applyExceptionSort() {
        this.exceptionRows = sortRows(
            this._rawExceptionRows,
            this.exceptionSortedBy,
            this.exceptionSortDirection,
            null
        );
    }

    async handleExportCsv() {
        if (!this.hasActiveRows) {
            return;
        }
        try {
            await this._ensureExportLib();
            const cols = this.isPricingMode ? PRICING_EXPORT_COLS : EXCEPTION_EXPORT_COLS;
            const rows = this.isPricingMode ? this.pricingRows : this.exceptionRows;
            const base = this.isPricingMode ? 'catalog-changes-pricing' : 'catalog-changes-exceptions';
            window.CloudPrismExport.downloadCsv(base, cols, rows);
        } catch (e) {
            // eslint-disable-next-line no-console
            console.error(e);
        }
    }

    async handleExportPdf() {
        if (!this.hasActiveRows) {
            return;
        }
        try {
            await this._ensureExportScripts();
            const cols = this.isPricingMode ? PRICING_EXPORT_COLS : EXCEPTION_EXPORT_COLS;
            const rows = this.isPricingMode ? this.pricingRows : this.exceptionRows;
            const title = this.isPricingMode ? 'Catalog Changes — Pricing' : 'Catalog Changes — Exceptions';
            const base = this.isPricingMode ? 'catalog-changes-pricing' : 'catalog-changes-exceptions';
            window.CloudPrismExport.downloadPdf(base, title, cols, rows);
        } catch (e) {
            // eslint-disable-next-line no-console
            console.error(e);
        }
    }

    async _resolveAssetUrls() {
        if (this._assetUrls && this._assetUrls.exportLib) {
            return this._assetUrls;
        }
        const urls = await getCloudPrismStaticAssetUrls();
        this._assetUrls = urls || {};
        const themeUrl = this._assetUrls.theme;
        if (themeUrl && !this._themeStyleLoaded) {
            this._themeStyleLoaded = true;
            await loadStyle(this, themeUrl).catch(() => {});
        }
        return this._assetUrls;
    }

    async _ensureExportLib() {
        if (window.CloudPrismExport) {
            return;
        }
        const urls = await this._resolveAssetUrls();
        if (!urls.exportLib) {
            throw new Error('cloudPrismExportLib static resource missing in org.');
        }
        await loadScript(this, urls.exportLib);
    }

    async _ensureExportScripts() {
        const urls = await this._resolveAssetUrls();
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

function toSortableNum(value) {
    if (value === null || value === undefined || value === '') {
        return null;
    }
    const n = Number(value);
    return Number.isNaN(n) ? null : n;
}

function sortRows(rows, fieldName, direction, sortKeyMap) {
    const clone = [...rows];
    const dir = direction === 'asc' ? 1 : -1;
    clone.sort((a, b) => {
        const cmp = compareByField(a, b, fieldName, sortKeyMap);
        return cmp * dir;
    });
    return clone;
}

function compareByField(a, b, fieldName, sortKeyMap) {
    const sortKey = sortKeyMap && sortKeyMap[fieldName] ? sortKeyMap[fieldName] : fieldName;
    const na = a[sortKey];
    const nb = b[sortKey];
    const numA = typeof na === 'number' && !Number.isNaN(na);
    const numB = typeof nb === 'number' && !Number.isNaN(nb);
    if (numA && numB) {
        if (na === nb) {
            return 0;
        }
        return na < nb ? -1 : 1;
    }
    if (numA && !numB) {
        return nb == null || nb === '' ? 1 : -1;
    }
    if (!numA && numB) {
        return na == null || na === '' ? -1 : 1;
    }
    const sa = na == null || na === '' ? '' : String(na).toLowerCase();
    const sb = nb == null || nb === '' ? '' : String(nb).toLowerCase();
    return sa.localeCompare(sb, undefined, { numeric: true, sensitivity: 'base' });
}

/**
 * Read a property from an Apex DTO as returned over @wire — keys may be snake_case or camelCase.
 */
function apexField(row, snakeName) {
    if (!row || !snakeName) {
        return undefined;
    }
    if (Object.prototype.hasOwnProperty.call(row, snakeName)) {
        return row[snakeName];
    }
    const camel = snakeName.replace(/_([a-z])/g, (_, ch) => ch.toUpperCase());
    if (camel !== snakeName && Object.prototype.hasOwnProperty.call(row, camel)) {
        return row[camel];
    }
    return undefined;
}

/**
 * Explicit $ prefix — more reliable than Intl currency in some Lightning contexts.
 */
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
