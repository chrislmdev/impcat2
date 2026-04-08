/* global jsPDF */
(function () {
    function cellValue(row, fieldName) {
        if (!row || !fieldName) {
            return '';
        }
        if (Object.prototype.hasOwnProperty.call(row, fieldName)) {
            const v = row[fieldName];
            return v === undefined || v === null ? '' : v;
        }
        if (fieldName.indexOf('__c') > 0) {
            const stem = fieldName.slice(0, -3);
            const pascal = stem.replace(/_([a-zA-Z0-9])/g, function (_, ch) {
                return ch.toUpperCase();
            });
            const camel = pascal.charAt(0).toLowerCase() + pascal.slice(1) + '__c';
            if (Object.prototype.hasOwnProperty.call(row, camel)) {
                const v = row[camel];
                return v === undefined || v === null ? '' : v;
            }
        }
        return '';
    }

    function escapeCsvCell(val) {
        const s = String(val);
        if (/[",\r\n]/.test(s)) {
            return '"' + s.replace(/"/g, '""') + '"';
        }
        return s;
    }

    function downloadCsv(filenameBase, columns, rows) {
        const header = columns.map((c) => escapeCsvCell(c.label)).join(',');
        const lines = rows.map((r) => columns.map((c) => escapeCsvCell(cellValue(r, c.fieldName))).join(','));
        const body = [header, ...lines].join('\r\n');
        const blob = new Blob([body], { type: 'text/csv;charset=utf-8;' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = filenameBase + '-' + tsSuffix() + '.csv';
        a.click();
        URL.revokeObjectURL(url);
    }

    function downloadPdf(filenameBase, pdfTitle, columns, rows) {
        if (!window.jspdf || !window.jspdf.jsPDF) {
            throw new Error('jsPDF not loaded');
        }
        const { jsPDF } = window.jspdf;
        const doc = new jsPDF({ orientation: 'landscape', unit: 'pt', format: 'letter' });
        doc.setFontSize(12);
        doc.text(pdfTitle, 40, 36);
        const head = [columns.map((c) => c.label)];
        const body = rows.map((r) => columns.map((c) => String(cellValue(r, c.fieldName))));
        doc.autoTable({
            startY: 48,
            head,
            body,
            styles: { fontSize: 7, cellPadding: 3 },
            headStyles: { fillColor: [27, 94, 32] }
        });
        doc.save(filenameBase + '-' + tsSuffix() + '.pdf');
    }

    function tsSuffix() {
        const d = new Date();
        return (
            d.getFullYear() +
            pad(d.getMonth() + 1) +
            pad(d.getDate()) +
            '-' +
            pad(d.getHours()) +
            pad(d.getMinutes())
        );
    }

    function pad(n) {
        return n < 10 ? '0' + n : String(n);
    }

    window.CloudPrismExport = {
        cellValue: cellValue,
        downloadCsv: downloadCsv,
        downloadPdf: downloadPdf
    };
})();
