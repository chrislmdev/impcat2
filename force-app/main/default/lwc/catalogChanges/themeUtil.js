export const THEME_KEY = 'cloudprism.theme';
export const LEGACY_THEME_KEY = 'cloudprism.catalogBulkUpload.theme';

export function readStoredThemeMode() {
    try {
        let stored = localStorage.getItem(THEME_KEY);
        if (stored === 'light' || stored === 'dark' || stored === 'system') {
            return stored;
        }
        stored = localStorage.getItem(LEGACY_THEME_KEY);
        if (stored === 'light' || stored === 'dark' || stored === 'system') {
            localStorage.setItem(THEME_KEY, stored);
            return stored;
        }
    } catch (e) {
        /* ignore */
    }
    return 'system';
}

export function persistThemeMode(mode) {
    try {
        localStorage.setItem(THEME_KEY, mode);
    } catch (e) {
        /* ignore */
    }
}

export function computeEffectiveTheme(themeMode) {
    if (themeMode === 'system') {
        return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
    }
    return themeMode;
}
