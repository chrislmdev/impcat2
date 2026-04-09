import { LightningElement, wire, track } from 'lwc';
import getServiceCatalogRows from '@salesforce/apex/CloudPrismServiceCatalogController.getServiceCatalogRows';

const CSPS = [
    { key: 'aws', label: 'AWS' },
    { key: 'azure', label: 'Azure' },
    { key: 'gcp', label: 'GCP' },
    { key: 'oracle', label: 'Oracle' }
];
const TOP_N = 3;
const IL_OPTIONS = [
    { label: 'IL2', value: 'IL2' },
    { label: 'IL3', value: 'IL3' },
    { label: 'IL4', value: 'IL4' },
    { label: 'IL5', value: 'IL5' },
    { label: 'IL6', value: 'IL6' }
];

function parseImpactLevels(raw) {
    if (!raw) {
        return [];
    }
    return raw
        .split(/[|,\s]+/)
        .map((s) => s.trim().toUpperCase())
        .filter((s) => /^IL\d+$/i.test(s));
}

function sortBucket(rows) {
    return [...rows].sort((a, b) => {
        const pa = a.popularityScore != null ? Number(a.popularityScore) : 0;
        const pb = b.popularityScore != null ? Number(b.popularityScore) : 0;
        if (pb !== pa) {
            return pb - pa;
        }
        return (a.serviceName || '').localeCompare(b.serviceName || '');
    });
}

export default class ServiceCatalog extends LightningElement {
    rawRows = [];
    error;

    searchKey = '';
    selectedCategoryValues = [];
    selectedImpactValues = [];
    @track cspEnabled = { aws: true, azure: true, gcp: true, oracle: true };
    @track expandedCategoryMap = {};
    @track expandedCellMap = {};

    categoryOptions = [];

    impactOptions = IL_OPTIONS;

    @wire(getServiceCatalogRows)
    wiredRows({ data, error }) {
        if (data) {
            this.rawRows = data;
            this.error = undefined;
            this.categoryOptions = this.buildCategoryOptions(data);
        } else if (error) {
            this.error = error;
            this.rawRows = [];
            this.categoryOptions = [];
        }
    }

    buildCategoryOptions(rows) {
        const set = new Set();
        for (const r of rows || []) {
            if (r.focusCategory) {
                set.add(r.focusCategory);
            }
        }
        return [...set]
            .sort((a, b) => a.localeCompare(b))
            .map((c) => ({ label: c, value: c }));
    }

    handleSearchChange(event) {
        this.searchKey = event.target.value;
    }

    handleCategoryFilterChange(event) {
        this.selectedCategoryValues = event.detail.value || [];
    }

    handleImpactFilterChange(event) {
        this.selectedImpactValues = event.detail.value || [];
    }

    handleCspToggle(event) {
        const k = event.currentTarget.dataset.csp;
        if (!k) {
            return;
        }
        this.cspEnabled = { ...this.cspEnabled, [k]: !this.cspEnabled[k] };
    }

    toggleCategory(event) {
        const cat = event.currentTarget.dataset.cat;
        if (!cat) {
            return;
        }
        const isOpen = this.expandedCategoryMap[cat] !== false;
        this.expandedCategoryMap = { ...this.expandedCategoryMap, [cat]: !isOpen };
    }

    toggleCellExpand(event) {
        const cellKey = event.currentTarget.dataset.key;
        if (!cellKey) {
            return;
        }
        const cur = !!this.expandedCellMap[cellKey];
        this.expandedCellMap = { ...this.expandedCellMap, [cellKey]: !cur };
    }

    get filteredRows() {
        const rows = this.rawRows || [];
        const q = (this.searchKey || '').trim().toLowerCase();
        const catSel = this.selectedCategoryValues || [];
        const ilSel = new Set(this.selectedImpactValues || []);

        return rows.filter((r) => {
            if (!this.cspEnabled[(r.csp || '').toLowerCase()]) {
                return false;
            }
            if (catSel.length > 0 && !catSel.includes(r.focusCategory)) {
                return false;
            }
            const rowIls = parseImpactLevels(r.impactLevel);
            if (ilSel.size > 0 && !rowIls.some((il) => ilSel.has(il))) {
                return false;
            }
            if (!q) {
                return true;
            }
            const blob = [
                r.serviceName,
                r.description,
                r.focusCategory,
                r.comparisonSubcategory,
                r.impactLevel
            ]
                .filter(Boolean)
                .join(' ')
                .toLowerCase();
            return blob.includes(q);
        });
    }

    get catalogSections() {
        const rows = this.filteredRows;
        if (!rows.length) {
            return [];
        }

        const byCat = new Map();
        for (const r of rows) {
            const cat = r.focusCategory || 'Other';
            const gk = `${r.focusCategory || ''}||${r.comparisonSubcategory || ''}`;
            if (!byCat.has(cat)) {
                byCat.set(cat, new Map());
            }
            const gmap = byCat.get(cat);
            if (!gmap.has(gk)) {
                gmap.set(gk, {
                    groupKey: gk,
                    subcategory: r.comparisonSubcategory || '',
                    description: '',
                    buckets: { aws: [], azure: [], gcp: [], oracle: [] }
                });
            }
            const g = gmap.get(gk);
            if (!g.description && r.description) {
                g.description = r.description;
            }
            const ck = (r.csp || '').toLowerCase();
            if (g.buckets[ck]) {
                g.buckets[ck].push(r);
            }
        }

        const sections = [];
        const catNames = [...byCat.keys()].sort((a, b) => a.localeCompare(b));

        for (const catName of catNames) {
            const gmap = byCat.get(catName);
            const groups = [];
            const gkeys = [...gmap.keys()].sort();

            for (const gk of gkeys) {
                const g = gmap.get(gk);
                const cells = {};
                for (const { key } of CSPS) {
                    const sorted = sortBucket(g.buckets[key] || []);
                    const decorate = (r) => ({
                        ...r,
                        rowKey: `${r.id || 'x'}|${r.csp}|${r.serviceName}|${r.comparisonSubcategory}`,
                        impactList: parseImpactLevels(r.impactLevel)
                    });
                    const top = sorted.slice(0, TOP_N).map(decorate);
                    const rest = sorted.slice(TOP_N).map(decorate);
                    const cellKey = `${g.groupKey}|${key}`;
                    const expanded = !!this.expandedCellMap[cellKey];
                    const restCt = rest.length;
                    cells[key] = {
                        top,
                        rest,
                        restCount: restCt,
                        expanded,
                        cellKey,
                        hasMore: restCt > 0,
                        expandButtonLabel: restCt ? (expanded ? 'Show less' : `+${restCt} more`) : ''
                    };
                }
                const cellColumns = CSPS.map(({ key, label }) => ({
                    csp: key,
                    cspLabel: label,
                    ...cells[key]
                }));
                groups.push({
                    groupKey: g.groupKey,
                    subcategory: g.subcategory,
                    description: g.description || '—',
                    cells,
                    cellColumns
                });
            }

            const expanded = this.expandedCategoryMap[catName] !== false;
            sections.push({
                name: catName,
                expanded,
                chevron: expanded ? '▼' : '▶',
                groups
            });
        }
        return sections;
    }

    get cspButtonRow() {
        return CSPS.map((c) => ({
            ...c,
            variant: this.cspEnabled[c.key] ? 'brand' : 'neutral'
        }));
    }

    get hasRows() {
        return (this.rawRows || []).length > 0;
    }

    get showEmptyFiltered() {
        return this.hasRows && this.filteredRows.length === 0;
    }

}

