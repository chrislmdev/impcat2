import { LightningElement, wire, track } from 'lwc';
import getCatalogRows from '@salesforce/apex/ServiceCatalogController.getCatalogRows';

const TOP_N = 3;
const CSP_KEYS = ['aws', 'azure', 'gcp', 'oracle'];
const IL_OPTIONS = ['IL2', 'IL3', 'IL4', 'IL5', 'IL6', 'COMM', 'TS'];

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
        const cat = (r.Category__c || '').trim();
        const sub = (r.Subcategory__c || '').trim();
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
        const csp = normalizeCsp(r.CSP__c);
        const cell = {
            id: r.Id,
            serviceName: r.Service__c || '',
            impactLevel: r.Impact_Level__c || ''
        };
        if (csp && g[csp]) {
            g[csp].push(cell);
        }
        if (r.Description__c && !g.description) {
            g.description = r.Description__c;
        }
    }
    return Object.values(map);
}

function mergeCellEntries(entries) {
    if (!entries || !entries.length) {
        return [];
    }
    const byName = new Map();
    for (const e of entries) {
        const k = String(e.serviceName || '')
            .toLowerCase()
            .replace(/\s+/g, ' ')
            .trim();
        if (!k) {
            continue;
        }
        if (!byName.has(k)) {
            byName.set(k, { ...e });
        } else {
            const t = byName.get(k);
            const a = String(t.impactLevel || '');
            const b = String(e.impactLevel || '');
            const merged = `${a}|${b}`;
            const tokens = [...new Set(merged.split('|').map((s) => s.trim()).filter(Boolean))];
            t.impactLevel = tokens.join('|');
        }
    }
    return [...byName.values()];
}

function filterGroups(groups, query) {
    const q = (query || '').trim().toLowerCase();
    if (!q) {
        return groups;
    }
    return groups.filter((g) => {
        const svcBlob = CSP_KEYS.flatMap((k) => (g[k] || []).map((e) => `${e.serviceName} ${e.impactLevel || ''}`)).join(' ');
        const blob = `${g.category} ${g.subcategoryLabel} ${g.description} ${svcBlob}`.toLowerCase();
        return (
            g.category.toLowerCase().includes(q) ||
            (g.subcategoryLabel || '').toLowerCase().includes(q) ||
            (g.description || '').toLowerCase().includes(q) ||
            blob.includes(q)
        );
    });
}

function applyMsFilters(groups, msCat, msIl, msCsp) {
    return groups.filter((g) => {
        const matchCat = msCat.length === 0 || msCat.includes(g.category);
        const matchIl =
            msIl.length === 0 ||
            CSP_KEYS.some((csp) =>
                (g[csp] || []).some((s) => {
                    const levels = String(s.impactLevel || '')
                        .split('|')
                        .map((l) => l.trim().toUpperCase())
                        .filter(Boolean);
                    return levels.some((lv) => msIl.includes(lv));
                })
            );
        const matchCsp =
            msCsp.length === 0 || CSP_KEYS.some((csp) => msCsp.includes(csp) && (g[csp] || []).length > 0);
        return matchCat && matchIl && matchCsp;
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
    return byCat;
}

export default class ServiceCatalog extends LightningElement {
    @track searchKey = '';
    @track categoryUi = {};
    @track msCat = [];
    @track msIl = [];
    @track msCsp = [];
    @track msOpen = null;
    @track themeLight = false;
    @track svcSortCol = 'category';
    @track svcSortDir = 1;

    rawRows = [];
    error;
    loadComplete = false;

    _windowClick = (e) => {
        if (this.msOpen == null) {
            return;
        }
        const toolbar = this.template.querySelector('.toolbar');
        if (!toolbar) {
            return;
        }
        const path = e.composedPath();
        const inside = path.some((el) => typeof el?.contains === 'function' && toolbar.contains(el));
        if (!inside) {
            this.msOpen = null;
        }
    };

    connectedCallback() {
        window.addEventListener('click', this._windowClick, true);
    }

    disconnectedCallback() {
        window.removeEventListener('click', this._windowClick, true);
    }

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

    /** Data exists but search / multi-select filters exclude every group (Phase A filter UX). */
    get isFilterEmpty() {
        return (
            this.loadComplete &&
            !this.hasError &&
            this.rawRows.length > 0 &&
            this.metaFilteredCount === 0
        );
    }

    get scopeClass() {
        return 'sc-scope' + (this.themeLight ? ' theme-light' : '');
    }

    get distinctCategories() {
        const s = new Set();
        (this.rawRows || []).forEach((r) => {
            const c = (r.Category__c || '').trim();
            if (c) {
                s.add(c);
            }
        });
        return [...s].sort((a, b) => a.localeCompare(b, undefined, { sensitivity: 'base' }));
    }

    get msCatLabel() {
        if (!this.msCat.length) {
            return 'All categories';
        }
        if (this.msCat.length === 1) {
            return this.msCat[0];
        }
        return `${this.msCat.length} categories`;
    }

    get msIlLabel() {
        if (!this.msIl.length) {
            return 'All levels';
        }
        if (this.msIl.length === 1) {
            return this.msIl[0];
        }
        return `${this.msIl.length} levels`;
    }

    get msCspLabel() {
        if (!this.msCsp.length) {
            return 'All CSPs';
        }
        if (this.msCsp.length === 1) {
            return this.msCsp[0].toUpperCase();
        }
        return `${this.msCsp.length} CSPs`;
    }

    get ilOptions() {
        return IL_OPTIONS.map((val) => ({
            val,
            selected: this.msIl.includes(val),
            key: val,
            optionClass: 'ms-option' + (this.msIl.includes(val) ? ' selected' : ''),
            dotClass: 'ms-option-dot opt-' + val.replace(/[^a-zA-Z0-9]/g, '_')
        }));
    }

    get cspOptions() {
        const defs = [
            { val: 'aws', label: 'AWS', href: '#logo-aws' },
            { val: 'azure', label: 'Azure', href: '#logo-azure' },
            { val: 'gcp', label: 'GCP', href: '#logo-gcp' },
            { val: 'oracle', label: 'Oracle', href: '#logo-oracle' }
        ];
        return defs.map((o) => ({
            ...o,
            key: o.val,
            optionClass: 'ms-option' + (this.msCsp.includes(o.val) ? ' selected' : '')
        }));
    }

    get catOptions() {
        return this.distinctCategories.map((c) => ({
            val: c,
            selected: this.msCat.includes(c),
            key: c,
            optionClass: 'ms-option' + (this.msCat.includes(c) ? ' selected' : '')
        }));
    }

    get themeToggleLabel() {
        return this.themeLight ? 'Dark mode' : 'Light mode';
    }

    get themePressedAria() {
        return this.themeLight ? 'true' : 'false';
    }

    get metaFilteredCount() {
        return this.getFilteredGroups().length;
    }

    get metaCategoryCount() {
        return new Set(this.getFilteredGroups().map((g) => g.category)).size;
    }

    get metaTotalGroups() {
        return groupRows(this.rawRows).length;
    }

    handleSearchInput(event) {
        this.searchKey = event.target.value;
    }

    toggleMs(event) {
        const which = event.currentTarget.dataset.which;
        this.msOpen = this.msOpen === which ? null : which;
    }

    toggleMsOpt(event) {
        const type = event.currentTarget.dataset.type;
        const val = event.currentTarget.dataset.val;
        const key = type === 'cat' ? 'msCat' : type === 'il' ? 'msIl' : 'msCsp';
        const arr = [...this[key]];
        const i = arr.indexOf(val);
        if (i >= 0) {
            arr.splice(i, 1);
        } else {
            arr.push(val);
        }
        this[key] = arr;
    }

    clearMs(event) {
        const type = event.currentTarget.dataset.type;
        if (type === 'cat') {
            this.msCat = [];
        } else if (type === 'il') {
            this.msIl = [];
        } else if (type === 'csp') {
            this.msCsp = [];
        }
    }

    clearAllFilters() {
        this.searchKey = '';
        this.msCat = [];
        this.msIl = [];
        this.msCsp = [];
        this.msOpen = null;
    }

    toggleTheme() {
        this.themeLight = !this.themeLight;
    }

    handleSortCategory() {
        if (this.svcSortCol === 'category') {
            this.svcSortDir = -this.svcSortDir;
        } else {
            this.svcSortCol = 'category';
            this.svcSortDir = 1;
        }
    }

    handleSortSubcategory() {
        if (this.svcSortCol === 'subcategory') {
            this.svcSortDir = -this.svcSortDir;
        } else {
            this.svcSortCol = 'subcategory';
            this.svcSortDir = 1;
        }
    }

    get thCategorySortClass() {
        return 'sortable ' + (this.svcSortCol === 'category' ? 'sorted' : '');
    }

    get thSubcategorySortClass() {
        return 'sortable ' + (this.svcSortCol === 'subcategory' ? 'sorted' : '');
    }

    get sortIndicatorCategory() {
        if (this.svcSortCol !== 'category') {
            return '↕';
        }
        return this.svcSortDir >= 0 ? '↑' : '↓';
    }

    get sortIndicatorSubcategory() {
        if (this.svcSortCol !== 'subcategory') {
            return '↕';
        }
        return this.svcSortDir >= 0 ? '↑' : '↓';
    }

    getCategoryState(name) {
        if (!this.categoryUi[name]) {
            this.categoryUi[name] = { showAll: false };
        }
        return this.categoryUi[name];
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
        const merged = mergeCellEntries(arr || []);
        if (!merged.length) {
            return [];
        }
        return merged
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

    getFilteredGroups() {
        let groups = groupRows(this.rawRows);
        groups = filterGroups(groups, this.searchKey);
        groups = applyMsFilters(groups, this.msCat, this.msIl, this.msCsp);
        return groups;
    }

    /**
     * Single #svcTable body: category band rows + data rows (+ optional show more/less), matching index.html renderServices.
     */
    get svcUnifiedRows() {
        const groups = this.getFilteredGroups();
        const byCat = bucketByCategory(groups);
        let names = Object.keys(byCat);
        const cmp = (a, b) => a.localeCompare(b, undefined, { sensitivity: 'base' });
        names.sort(cmp);
        if (this.svcSortCol === 'category') {
            if (this.svcSortDir < 0) {
                names = [...names].reverse();
            }
        }

        const rows = [];
        const subCmp = (a, b) =>
            (a.subcategoryLabel || '').localeCompare(b.subcategoryLabel || '', undefined, { sensitivity: 'base' });

        for (const name of names) {
            let list = [...(byCat[name] || [])];
            if (this.svcSortCol === 'subcategory') {
                list.sort((a, b) => subCmp(a, b) * this.svcSortDir);
            } else {
                list.sort(subCmp);
            }

            list = list.map((g) => this.enrichGroup(g));
            const st = this.getCategoryState(name);
            const showAll = st.showAll;
            const total = list.length;
            const rowCountLabel = `${total} comparison row${total === 1 ? '' : 's'}`;

            rows.push({
                trClass: 'svc-cat-band',
                isBand: true,
                key: `band-${name}`,
                categoryName: name,
                rowCountLabel
            });

            const visibleList = showAll ? list : list.slice(0, TOP_N);
            for (const g of visibleList) {
                rows.push({
                    trClass: 'svc-data-row',
                    isData: true,
                    key: `row-${g.groupKey}`,
                    category: g.category,
                    subcategoryLabel: g.subcategoryLabel,
                    description: g.description,
                    awsEntries: g.awsEntries,
                    azureEntries: g.azureEntries,
                    gcpEntries: g.gcpEntries,
                    oracleEntries: g.oracleEntries
                });
            }

            if (!showAll && total > TOP_N) {
                rows.push({
                    trClass: 'show-more-row',
                    isShowMore: true,
                    key: `more-${name}`,
                    categoryName: name,
                    hiddenCount: total - TOP_N
                });
            }
            if (showAll && total > TOP_N) {
                rows.push({
                    trClass: 'show-more-row',
                    isShowLess: true,
                    key: `less-${name}`,
                    categoryName: name
                });
            }
        }
        return rows;
    }

    get footerYearLabel() {
        try {
            return new Date().toLocaleString('en-US', { month: 'long', year: 'numeric' });
        } catch (e) {
            return '2026';
        }
    }

    get msCatBtnClass() {
        return 'ms-btn' + (this.msOpen === 'cat' ? ' open' : '');
    }

    get msIlBtnClass() {
        return 'ms-btn' + (this.msOpen === 'il' ? ' open' : '');
    }

    get msCspBtnClass() {
        return 'ms-btn' + (this.msOpen === 'csp' ? ' open' : '');
    }

    get msCatDropClass() {
        return 'ms-dropdown' + (this.msOpen === 'cat' ? ' open' : '');
    }

    get msIlDropClass() {
        return 'ms-dropdown' + (this.msOpen === 'il' ? ' open' : '');
    }

    get msCspDropClass() {
        return 'ms-dropdown' + (this.msOpen === 'csp' ? ' open' : '');
    }
}
