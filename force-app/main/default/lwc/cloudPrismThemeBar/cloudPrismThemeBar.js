import { LightningElement, api } from 'lwc';

/**
 * Dispatches cloudprismthemechange with detail.mode: 'system' | 'light' | 'dark'
 */
export default class CloudPrismThemeBar extends LightningElement {
    @api systemButtonVariant = 'border-filled';
    @api lightButtonVariant = 'border-filled';
    @api darkButtonVariant = 'border-filled';

    handleThemeSystem() {
        this._emit('system');
    }

    handleThemeLight() {
        this._emit('light');
    }

    handleThemeDark() {
        this._emit('dark');
    }

    _emit(mode) {
        this.dispatchEvent(
            new CustomEvent('cloudprismthemechange', {
                bubbles: true,
                composed: true,
                detail: { mode }
            })
        );
    }
}
