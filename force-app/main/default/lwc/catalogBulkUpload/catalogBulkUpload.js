import { LightningElement, track } from 'lwc';
import { loadStyle, loadScript } from 'lightning/platformResourceLoader';
import processFile from '@salesforce/apex/CatalogUploadService.processFile';
import { readStoredThemeMode, persistThemeMode, computeEffectiveTheme } from './themeUtil';

/** Same-origin /resource/{name} — deploy this LWC without static resources in the same package. */
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

const UPLOAD_EXPORT_COLS = [
    { label: 'File', fieldName: 'fileName' },
    { label: 'OK', fieldName: 'successLabel' },
    { label: 'Rows', fieldName: 'rowsInserted' },
    { label: 'Catalog import Id', fieldName: 'catalogImportId' },
    { label: 'Message', fieldName: 'message' }
];

function readFileAsText(file) {
    return new Promise((resolve, reject) => {
        const reader = new FileReader();
        reader.onload = () => resolve(typeof reader.result === 'string' ? reader.result : '');
        reader.onerror = () => reject(reader.error);
        reader.readAsText(file);
    });
}

/**
 * Apex / LWC errors are not always { body: { message } }; avoid String(err) => "[object Object]".
 */
function formatUploadError(error) {
    if (!error) {
        return 'Unknown error';
    }
    if (typeof error === 'string') {
        return error;
    }
    if (error.message && typeof error.message === 'string') {
        return error.message;
    }
    const body = error.body;
    if (body) {
        if (typeof body.message === 'string' && body.message) {
            return body.message;
        }
        if (Array.isArray(body)) {
            const parts = body
                .map((row) => (row && typeof row.message === 'string' ? row.message : null))
                .filter(Boolean);
            if (parts.length) {
                return parts.join('; ');
            }
        }
        if (Array.isArray(body.pageErrors) && body.pageErrors.length) {
            const parts = body.pageErrors.map((pe) => pe.message || pe.statusCode).filter(Boolean);
            if (parts.length) {
                return parts.join('; ');
            }
        }
        try {
            return JSON.stringify(body);
        } catch (ignore) {
            /* fall through */
        }
    }
    if (error.statusText && typeof error.statusText === 'string') {
        return error.statusText;
    }
    return 'Request failed (see browser Network tab for details).';
}

export default class CatalogBulkUpload extends LightningElement {
    @track resultRows = [];
    working = false;
    statusMessage = '';
    themeMode = 'system';
    effectiveTheme = 'light';
    dragDepth = 0;
    _assetUrls = {};
    _themeStyleLoaded = false;
    jspdfScriptsLoaded = false;

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
            loadStyle(this, this._assetUrls.theme).catch(() => {
                /* ignore */
            });
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

    get rootClass() {
        return `cp-root cp-theme-${this.effectiveTheme}`;
    }

    get uploadZoneClass() {
        const drag = this.dragDepth > 0 ? ' cp-drag' : '';
        const busy = this.working ? ' cp-upload-disabled' : '';
        return `cp-upload${drag}${busy}`;
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

    get hasResults() {
        return this.resultRows && this.resultRows.length > 0;
    }

    get exportDisabled() {
        return !this.hasResults;
    }

    get bannerBody() {
        return (
            'Name each file {YYYY-MM}_{csp}_{schema}.csv (csp: aws, azure, gcp, oracle; schema: pricing, exceptions, parent). ' +
            'Pricing/exceptions: headers are API names or supported aliases. Parent: only the import header is saved — CSV data rows are not loaded into any object in this POC (success message explains skipped rows). ' +
            'In-app upload is limited to about 8,000 data rows and 1 MB per file — ' +
            'for very large catalogs (e.g. ~1M rows), use MuleSoft / SharePoint and Bulk API 2.0 (see docs/MULESOFT_CATALOG_INGEST.md).'
        );
    }

    handleDragOver(event) {
        event.preventDefault();
        event.stopPropagation();
        if (event.dataTransfer) {
            event.dataTransfer.dropEffect = 'copy';
        }
    }

    handleDragEnter(event) {
        event.preventDefault();
        this.dragDepth += 1;
    }

    handleDragLeave(event) {
        event.preventDefault();
        this.dragDepth = Math.max(0, this.dragDepth - 1);
    }

    handleDrop(event) {
        event.preventDefault();
        event.stopPropagation();
        this.dragDepth = 0;
        if (this.working) {
            return;
        }
        const dt = event.dataTransfer;
        if (!dt || !dt.files || !dt.files.length) {
            return;
        }
        const files = Array.from(dt.files).filter((f) => f.name && f.name.toLowerCase().endsWith('.csv'));
        if (files.length) {
            this.runUploads(files);
        }
    }

    handleFileChange(event) {
        const input = event.target;
        const files = input.files;
        if (!files || !files.length) {
            return;
        }
        this.runUploads(Array.from(files));
        input.value = '';
    }

    async runUploads(files) {
        this.working = true;
        this.statusMessage = '';
        const nextKey = this.resultRows.length;
        try {
            for (let i = 0; i < files.length; i++) {
                const f = files[i];
                this.statusMessage = `Processing ${i + 1} of ${files.length}: ${f.name}…`;
                const csvBody = await readFileAsText(f);
                const res = await processFile({ fileName: f.name, csvBody });
                const errs = res.errors && res.errors.length ? res.errors.join('; ') : '';
                const success = !!res.success;
                this.resultRows = [
                    ...this.resultRows,
                    {
                        key: `${nextKey + i}`,
                        fileName: f.name,
                        successLabel: success ? 'Yes' : 'No',
                        pillClass: success ? 'cp-pill cp-pill-yes' : 'cp-pill cp-pill-no',
                        rowsInserted: res.rowsInserted != null ? res.rowsInserted : 0,
                        catalogImportId: res.catalogImportId || '',
                        message: [res.message, errs].filter(Boolean).join(' — ')
                    }
                ];
            }
            this.statusMessage = files.length === 1 ? 'Done.' : `Done — ${files.length} files.`;
        } catch (e) {
            this.statusMessage = `Error: ${formatUploadError(e)}`;
        } finally {
            this.working = false;
        }
    }

    async handleExportCsv() {
        if (!this.hasResults) {
            return;
        }
        try {
            await this._ensureExportLib();
            window.CloudPrismExport.downloadCsv('bulk-upload-results', UPLOAD_EXPORT_COLS, this.resultRows);
        } catch (e) {
            // eslint-disable-next-line no-console
            console.error(e);
        }
    }

    async handleExportPdf() {
        if (!this.hasResults) {
            return;
        }
        try {
            await this._ensureExportScripts();
            window.CloudPrismExport.downloadPdf(
                'bulk-upload-results',
                'Bulk catalog upload — results',
                UPLOAD_EXPORT_COLS,
                this.resultRows
            );
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
        if (this.jspdfScriptsLoaded) {
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
        this.jspdfScriptsLoaded = true;
    }
}
