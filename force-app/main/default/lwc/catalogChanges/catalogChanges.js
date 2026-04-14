import { LightningElement, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getDistinctImportMonths from '@salesforce/apex/CloudPrismCatalogController.getDistinctImportMonths';
import getCatalogChangeRows from '@salesforce/apex/CloudPrismCatalogController.getCatalogChangeRows';

const PRICING_COLS = [
    { label: 'CSP', fieldName: 'csp', type: 'text', sortable: true, initialWidth: 80 },
    { label: 'Catalog #', fieldName: 'catalogitemnumber', type: 'text', sortable: true },
    { label: 'Title', fieldName: 'title', type: 'text', wrapText: true, sortable: true },
    { label: 'Type', fieldName: 'change_type', type: 'text', initialWidth: 100, sortable: true },
    { label: 'JWCC (from)', fieldName: 'prevJwccUsd', type: 'text', initialWidth: 120, sortable: true },
    { label: 'JWCC (to)', fieldName: 'currJwccUsd', type: 'text', initialWidth: 120, sortable: true },
    { label: 'JWCC delta', fieldName: 'custDeltaUsd', type: 'text', initialWidth: 120, sortable: true },
    { label: 'Comm (from)', fieldName: 'prevCommUsd', type: 'text', initialWidth: 120, sortable: true },
    { label: 'Comm (to)', fieldName: 'currCommUsd', type: 'text', initialWidth: 120, sortable: true },
    { label: 'Comm delta', fieldName: 'commDeltaUsd', type: 'text', initialWidth: 120, sortable: true }
];

const EXCEPTION_COLS = [
    { label: 'CSP', fieldName: 'csp', type: 'text', sortable: true, initialWidth: 80 },
    { label: 'Exception ID', fieldName: 'exceptionuniqueid', type: 'text', sortable: true },
    { label: 'Short name', fieldName: 'csoshortname', type: 'text', sortable: true },
    { label: 'Type', fieldName: 'change_type', type: 'text', initialWidth: 100, sortable: true },
    { label: 'Status (prev → curr)', fieldName: 'statusPair', type: 'text', wrapText: true, sortable: true },
    { label: 'Impact (prev → curr)', fieldName: 'impactPair', type: 'text', wrapText: true, sortable: true },
    { label: 'Duration (prev → curr)', fieldName: 'durationPair', type: 'text', wrapText: true, sortable: true },
    { label: 'Plan (prev → curr)', fieldName: 'planPair', type: 'text', wrapText: true, sortable: true }
];

const PRICING_SORT_KEYS = {
    prevJwccUsd: 'prevJwccNum',
    currJwccUsd: 'currJwccNum',
    custDeltaUsd: 'custDeltaNum',
    prevCommUsd: 'prevCommNum',
    currCommUsd: 'currCommNum',
    commDeltaUsd: 'commDeltaNum'
};

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

    /** Valid From/To months selected and wire did not return an error. */
    get compareReady() {
        return (
            Boolean(this.monthFrom && this.monthTo && this.monthFrom < this.monthTo) &&
            this.error === undefined
        );
    }

    get showPricingEmpty() {
        return this.isPricingMode && this.compareReady && this.pricingRows.length === 0;
    }

    get showExceptionEmpty() {
        return !this.isPricingMode && this.compareReady && this.exceptionRows.length === 0;
    }

    get copySummaryDisabled() {
        return !this.compareReady;
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
                durationPair: pair(r.requestedduration_prev, r.requestedduration_curr),
                planPair: pair(r.suggestedplan_prev, r.suggestedplan_curr),
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

    handleCopyForJira() {
        const columns = this.isPricingMode ? PRICING_COLS : EXCEPTION_COLS;
        const rows = this.isPricingMode ? this.pricingRows : this.exceptionRows;
        const ctx = {
            mode: this.mode,
            monthFrom: this.monthFrom,
            monthTo: this.monthTo,
            cspLabel: labelForValue(this.cspOptions, this.cspFilter),
            changeTypeLabel: labelForValue(this.changeTypeOptions, this.changeTypeFilter),
            columns,
            rows
        };
        const html = buildJiraClipboardHtml(ctx);
        const plain = buildJiraClipboardText(ctx);
        this._dispatchClipboardCopyRich(html, plain, {
            successTitle: 'Copied to clipboard',
            successMessage:
                'HTML table — paste into Jira or Excel for a formatted grid. Plain-text Markdown is also on the clipboard.',
            errorMessage:
                'Your browser may block clipboard access. Try again or copy from the table manually.'
        });
    }

    handleCopyAsTsv() {
        const columns = this.isPricingMode ? PRICING_COLS : EXCEPTION_COLS;
        const rows = this.isPricingMode ? this.pricingRows : this.exceptionRows;
        const text = buildTsvClipboardText({
            mode: this.mode,
            monthFrom: this.monthFrom,
            monthTo: this.monthTo,
            cspLabel: labelForValue(this.cspOptions, this.cspFilter),
            changeTypeLabel: labelForValue(this.changeTypeOptions, this.changeTypeFilter),
            columns,
            rows
        });
        this._dispatchClipboardCopy(text, {
            successTitle: 'Copied to clipboard',
            successMessage: 'Tab-separated text with headers — paste into Excel.',
            errorMessage:
                'Your browser may block clipboard access. Try again or copy from the table manually.'
        });
    }

    _dispatchClipboardCopy(text, { successTitle, successMessage, errorMessage }) {
        copyTextToClipboard(text)
            .then(() => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: successTitle,
                        message: successMessage,
                        variant: 'success'
                    })
                );
            })
            .catch(() => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Copy failed',
                        message: errorMessage,
                        variant: 'error'
                    })
                );
            });
    }

    _dispatchClipboardCopyRich(html, plain, { successTitle, successMessage, errorMessage }) {
        copyRichToClipboard(html, plain)
            .then(() => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: successTitle,
                        message: successMessage,
                        variant: 'success'
                    })
                );
            })
            .catch(() => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Copy failed',
                        message: errorMessage,
                        variant: 'error'
                    })
                );
            });
    }
}

function labelForValue(options, value) {
    if (!options || !options.length) {
        return value || '';
    }
    const v = value == null ? '' : String(value);
    const hit = options.find((o) => o.value === v);
    return hit ? hit.label : v || '—';
}

function escapeTsvCell(val) {
    if (val == null || val === undefined) {
        return '';
    }
    return String(val).replace(/\r\n/g, ' ').replace(/[\n\r\t]/g, ' ');
}

function buildTsv(columns, rows) {
    const labels = columns.map((c) => c.label);
    const fields = columns.map((c) => c.fieldName);
    const lines = [labels.join('\t')];
    for (const row of rows) {
        lines.push(fields.map((f) => escapeTsvCell(row[f])).join('\t'));
    }
    return lines.join('\n');
}

/** Pipes break Markdown tables; use broken bar so pasted Jira tables stay valid. */
function escapeMarkdownCell(val) {
    if (val == null || val === undefined) {
        return '';
    }
    return String(val)
        .replace(/\r\n/g, ' ')
        .replace(/[\n\r\t]/g, ' ')
        .replace(/\|/g, '\u00A6');
}

function buildMarkdownTable(columns, rows) {
    const labels = columns.map((c) => escapeMarkdownCell(c.label));
    const fields = columns.map((c) => c.fieldName);
    const headerLine = '| ' + labels.join(' | ') + ' |';
    const sepLine = '| ' + labels.map(() => '---').join(' | ') + ' |';
    const dataLines = rows.map(
        (row) => '| ' + fields.map((f) => escapeMarkdownCell(row[f])).join(' | ') + ' |'
    );
    return [headerLine, sepLine, ...dataLines].join('\n');
}

function buildClipboardHeader(ctx) {
    const title = ctx.mode === 'pricing' ? 'Pricing deltas' : 'Exception deltas';
    return [
        `CloudPrism — Catalog changes (${title})`,
        `From: ${ctx.monthFrom}   To: ${ctx.monthTo}`,
        `CSP: ${ctx.cspLabel}   Change type: ${ctx.changeTypeLabel}`,
        ''
    ].join('\n');
}

function buildJiraClipboardText(ctx) {
    return buildClipboardHeader(ctx) + buildMarkdownTable(ctx.columns, ctx.rows);
}

function escapeHtml(str) {
    return String(str)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;');
}

function escapeHtmlCell(val) {
    if (val == null || val === undefined) {
        return '';
    }
    const s = String(val).replace(/\r\n/g, ' ').replace(/[\n\r\t]/g, ' ');
    return escapeHtml(s);
}

function buildHtmlTable(columns, rows) {
    const fields = columns.map((c) => c.fieldName);
    const ths = columns.map((c) => `<th>${escapeHtmlCell(c.label)}</th>`).join('');
    const trHead = `<thead><tr>${ths}</tr></thead>`;
    const trs = rows
        .map(
            (row) =>
                '<tr>' +
                fields.map((f) => `<td>${escapeHtmlCell(row[f])}</td>`).join('') +
                '</tr>'
        )
        .join('');
    return (
        '<table border="1" cellpadding="4" cellspacing="0" ' +
        'style="border-collapse:collapse;font-family:Segoe UI,Arial,sans-serif;font-size:12px">' +
        trHead +
        '<tbody>' +
        trs +
        '</tbody></table>'
    );
}

function buildJiraClipboardHtml(ctx) {
    const title = ctx.mode === 'pricing' ? 'Pricing deltas' : 'Exception deltas';
    const headBlock =
        '<p style="margin:0 0 8px 0"><strong>' +
        escapeHtml(`CloudPrism — Catalog changes (${title})`) +
        '</strong></p>' +
        '<p style="margin:0 0 4px 0">' +
        escapeHtml(`From: ${ctx.monthFrom}   To: ${ctx.monthTo}`) +
        '</p>' +
        '<p style="margin:0 0 12px 0">' +
        escapeHtml(`CSP: ${ctx.cspLabel}   Change type: ${ctx.changeTypeLabel}`) +
        '</p>';
    const inner = headBlock + buildHtmlTable(ctx.columns, ctx.rows);
    return (
        '<!DOCTYPE html><html><head><meta charset="utf-8"></head><body style="font-family:Segoe UI,Arial,sans-serif;font-size:12px">' +
        inner +
        '</body></html>'
    );
}

function buildTsvClipboardText(ctx) {
    return buildClipboardHeader(ctx) + buildTsv(ctx.columns, ctx.rows);
}

/**
 * Writes real HTML table + plain Markdown fallback (Excel/Jira use HTML; plain for text-only targets).
 */
function copyRichToClipboard(html, plain) {
    if (
        navigator.clipboard &&
        typeof navigator.clipboard.write === 'function' &&
        typeof ClipboardItem !== 'undefined'
    ) {
        try {
            const item = new ClipboardItem({
                'text/html': new Blob([html], { type: 'text/html' }),
                'text/plain': new Blob([plain], { type: 'text/plain' })
            });
            return navigator.clipboard.write([item]);
        } catch (e) {
            /* fall through to plain text */
        }
    }
    return copyTextToClipboard(plain);
}

function copyTextToClipboard(text) {
    if (navigator.clipboard && typeof navigator.clipboard.writeText === 'function') {
        return navigator.clipboard.writeText(text);
    }
    return new Promise((resolve, reject) => {
        try {
            const ta = document.createElement('textarea');
            ta.value = text;
            ta.setAttribute('readonly', '');
            ta.style.position = 'fixed';
            ta.style.left = '-9999px';
            document.body.appendChild(ta);
            ta.select();
            const ok = document.execCommand('copy');
            document.body.removeChild(ta);
            if (ok) {
                resolve();
            } else {
                reject(new Error('execCommand copy failed'));
            }
        } catch (e) {
            reject(e);
        }
    });
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
        return nb == null || nb === '' ? -1 : 1;
    }
    if (!numA && numB) {
        return na == null || na === '' ? 1 : -1;
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
