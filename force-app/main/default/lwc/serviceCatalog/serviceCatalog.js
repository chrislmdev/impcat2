import { LightningElement, wire, track } from 'lwc';
import getCatalogRows from '@salesforce/apex/ServiceCatalogController.getCatalogRows';

const TOP_N = 3;

function normalizeCsp(raw) {
    if (!raw) {
        return null;
    }
    const s = String(raw).trim().toLowerCase();
    if (s === 'aws' || s === 'amazon' || s.startsWith('amazon')) {
        return 'aws';
    }
    if (s === 'azure' || s === 'microsoft' || s.includes('azure')) {
        return 'azure';
    }
    if (s === 'gcp' || s === 'google' || s.includes('google')) {
        return 'gcp';
    }
    if (s === 'oracle' || s === 'oci' || s.includes('oracle')) {
        return 'oracle';
    }
    return null;
}

function groupRows(rows) {
    const map = {};
    for (const r of rows) {
        const cat = (r.category || '').trim();
        const sub = (r.subcategory || '').trim();
        const key = `${cat.toLowerCase()}|${sub.toLowerCase()}`;
        if (!map[key]) {
            map[key] = {
                groupKey: key,
                category: cat,
                subcategoryLabel: sub,
                description: '',
                aws: [],
                azure: [],
                gcp: [],
                oracle: []
            };
        }
        const g = map[key];
        const csp = normalizeCsp(r.csp);
        const cell = {
            id: r.id,
            serviceName: r.service || '',
            impactLevel: r.impactLevel || ''
        };
        if (csp && g[csp]) {
            g[csp].push(cell);
        }
        if (r.description && !g.description) {
            g.description = r.description;
        }
    }
    return Object.values(map);
}

function filterGroups(groups, query) {
    const q = (query || '').trim().toLowerCase();
    if (!q) {
        return groups;
    }
    return groups.filter((g) => {
        const svcBlob = ['aws', 'azure', 'gcp', 'oracle']
            .flatMap((k) => (g[k] || []).map((e) => `${e.serviceName} ${e.impactLevel || ''}`))
            .join(' ');
        const blob = `${g.category} ${g.subcategoryLabel} ${g.description} ${svcBlob}`.toLowerCase();
        return (
            g.category.toLowerCase().includes(q) ||
            (g.subcategoryLabel || '').toLowerCase().includes(q) ||
            (g.description || '').toLowerCase().includes(q) ||
            blob.includes(q)
        );
    });
}

function bucketByCategory(groups) {
    const byCat = {};
    for (const g of groups) {
        const c = g.category || '—';
        if (!byCat[c]) {
            byCat[c] = [];
        }
        byCat[c].push(g);
    }
    for (const k of Object.keys(byCat)) {
        byCat[k].sort((a, b) =>
            (a.subcategoryLabel || '').localeCompare(b.subcategoryLabel || '', undefined, { sensitivity: 'base' })
        );
    }
    return byCat;
}

export default class ServiceCatalog extends LightningElement {
    @track searchKey = '';
    /** @type {object} keyed by category name */
    @track categoryUi = {};

    rawRows = [];
    error;
    loadComplete = false;

    @wire(getCatalogRows)
    wiredRows(value) {
        const { data, error } = value;
        if (data !== undefined) {
            this.loadComplete = true;
            this.rawRows = data;
            this.error = undefined;
        } else if (error) {
            this.loadComplete = true;
            this.error = error;
            this.rawRows = [];
        }
    }

    get loading() {
        return !this.loadComplete;
    }

    get hasError() {
        return !!this.error;
    }

    get errorMessage() {
        return this.error ? this.error.body?.message || this.error.message || String(this.error) : '';
    }

    get isEmpty() {
        return this.loadComplete && !this.hasError && this.rawRows.length === 0;
    }

    handleSearchInput(event) {
        this.searchKey = event.target.value;
    }

    getCategoryState(name) {
        if (!this.categoryUi[name]) {
            this.categoryUi[name] = { collapsed: false, showAll: false };
        }
        return this.categoryUi[name];
    }

    toggleCategory(event) {
        const name = event.currentTarget.dataset.category;
        const s = { ...this.getCategoryState(name) };
        s.collapsed = !s.collapsed;
        this.categoryUi = { ...this.categoryUi, [name]: s };
    }

    toggleShowMore(event) {
        const name = event.currentTarget.dataset.category;
        const s = { ...this.getCategoryState(name) };
        s.showAll = !s.showAll;
        this.categoryUi = { ...this.categoryUi, [name]: s };
    }

    impactClass(token) {
        const u = String(token || '')
            .trim()
            .toUpperCase();
        if (u === 'COMM') {
            return 'ib il-COMM';
        }
        if (u === 'TS') {
            return 'ib il-TS';
        }
        if (u.startsWith('IL')) {
            return `ib il-${u}`;
        }
        return 'ib il-generic';
    }

    tokenizeImpact(raw) {
        if (!raw) {
            return [];
        }
        return String(raw)
            .split('|')
            .map((s) => s.trim())
            .filter(Boolean)
            .map((label) => {
                const u = label.toUpperCase();
                return { label: u, cssClass: this.impactClass(u) };
            });
    }

    entriesForCsp(arr) {
        if (!arr || !arr.length) {
            return [];
        }
        return [...arr]
            .map((e) => ({
                serviceName: e.serviceName,
                badges: this.tokenizeImpact(e.impactLevel)
            }))
            .sort((a, b) => a.serviceName.localeCompare(b.serviceName, undefined, { sensitivity: 'base' }));
    }

    enrichGroup(g) {
        return {
            ...g,
            awsEntries: this.entriesForCsp(g.aws),
            azureEntries: this.entriesForCsp(g.azure),
            gcpEntries: this.entriesForCsp(g.gcp),
            oracleEntries: this.entriesForCsp(g.oracle)
        };
    }

    get categorySections() {
        const groups = groupRows(this.rawRows);
        const filtered = filterGroups(groups, this.searchKey);
        const byCat = bucketByCategory(filtered);
        const names = Object.keys(byCat).sort((a, b) => a.localeCompare(b, undefined, { sensitivity: 'base' }));

        return names.map((name) => {
            const list = byCat[name].map((g) => this.enrichGroup(g));
            const st = this.getCategoryState(name);
            const collapsed = st.collapsed;
            const showAll = st.showAll;
            const visibleGroups = showAll ? list : list.slice(0, TOP_N);
            const showMore = !showAll && list.length > TOP_N;
            const showLess = showAll && list.length > TOP_N;

            return {
                key: name,
                name,
                collapsed,
                chevron: collapsed ? '▶' : '▼',
                expanded: !collapsed,
                visibleGroups,
                showMore,
                showLess,
                hiddenCount: Math.max(0, list.length - TOP_N),
                totalInCategory: list.length,
                rowCountLabel: `${list.length} comparison row${list.length === 1 ? '' : 's'}`
            };
        });
    }

    get metaLine() {
        const groups = groupRows(this.rawRows);
        const filtered = filterGroups(groups, this.searchKey);
        const cats = new Set(filtered.map((g) => g.category)).size;
        return `Showing ${filtered.length} comparison rows in ${cats} FOCUS categories`;
    }
}
