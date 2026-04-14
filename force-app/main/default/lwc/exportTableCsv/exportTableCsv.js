/** `prefix-YYYY-MM-DD.csv` for downloads */
export function catalogExportFilename(prefix) {
    return `${prefix}-${new Date().toISOString().slice(0, 10)}.csv`;
}

/**
 * Client-side CSV download (opens in Excel). UTF-8 BOM for Windows Excel.
 *
 * @param {Object} opts
 * @param {string} opts.filename - Base name or full name ending in .csv
 * @param {{ label: string, fieldName: string }[]} opts.columns
 * @param {Record<string, *>[]} opts.rows
 */
export function downloadCsv({ filename, columns, rows }) {
    const name =
        filename && filename.toLowerCase().endsWith('.csv') ? filename : `${filename || 'export'}.csv`;
    const header = columns.map((c) => formatCsvField(c.label)).join(',');
    const lines = [header];
    for (const row of rows || []) {
        lines.push(columns.map((c) => formatCsvField(cellValue(row, c.fieldName))).join(','));
    }
    const csv = '\uFEFF' + lines.join('\r\n');
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8' });
    const urlApi = typeof URL !== 'undefined' ? URL : window.URL;
    const doc = typeof document !== 'undefined' ? document : null;
    if (!doc || !doc.body) {
        throw new Error('Browser cannot access the document to start a download.');
    }

    // Legacy Edge / IE11 (rare): saves without a temporary URL.
    const nav = window.navigator;
    if (nav && typeof nav.msSaveOrOpenBlob === 'function') {
        nav.msSaveOrOpenBlob(blob, name);
        return;
    }

    const url = urlApi.createObjectURL(blob);
    const a = doc.createElement('a');
    a.href = url;
    a.download = name;
    a.setAttribute('download', name);
    a.style.display = 'none';
    doc.body.appendChild(a);
    // Defer click; revoking the blob URL in the same turn can cancel the download.
    window.setTimeout(() => {
        try {
            a.click();
        } finally {
            if (a.parentNode) {
                a.parentNode.removeChild(a);
            }
            window.setTimeout(() => {
                try {
                    urlApi.revokeObjectURL(url);
                } catch (ignore) {
                    /* noop */
                }
            }, 2500);
        }
    }, 0);
}

function cellValue(row, fieldName) {
    if (!row || !fieldName) {
        return '';
    }
    const v = row[fieldName];
    if (v == null || v === undefined) {
        return '';
    }
    if (typeof v === 'object') {
        return JSON.stringify(v);
    }
    return v;
}

function formatCsvField(value) {
    if (value == null || value === undefined) {
        return '';
    }
    const s = String(value);
    if (/[",\r\n]/.test(s)) {
        return '"' + s.replace(/"/g, '""') + '"';
    }
    return s;
}
