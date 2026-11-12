// Hudhud's password manager choice (bunix: docs/browser.md, "Password manager").

import 'chrome://resources/cr_elements/cr_button/cr_button.js';
import 'chrome://resources/cr_elements/cr_radio_button/cr_radio_button.js';
import 'chrome://resources/cr_elements/cr_radio_group/cr_radio_group.js';
import 'chrome://resources/cr_elements/cr_shared_style.css.js';
import './shared_style.css.js';

import {I18nMixin} from 'chrome://resources/cr_elements/i18n_mixin.js';
import {WebUiListenerMixin} from 'chrome://resources/cr_elements/web_ui_listener_mixin.js';
import {sendWithPromise} from 'chrome://resources/js/cr.js';
import {PolymerElement} from 'chrome://resources/polymer/v3_0/polymer/polymer_bundled.min.js';

import {getTemplate} from './hudhud_password_manager_choice.html.js';

// What chrome/browser/hudhud_password_manager/password_manager_choice_page.cc
// sends: the choice, and the password-manager extensions Hudhud offers.
interface ExtensionPasswordManager {
  id: string;
  name: string;
  installed: boolean;
  enabled: boolean;
}

interface ChoiceState {
  // 'builtin', 'off', or the id of one of `managers`.
  choice: string;
  managers: ExtensionPasswordManager[];
}

const BUILT_IN = 'builtin';

// Unicode's FIRST STRONG ISOLATE and POP DIRECTIONAL ISOLATE
const FIRST_STRONG_ISOLATE = '\u2068';
const POP_DIRECTIONAL_ISOLATE = '\u2069';

// An extension's name is Latin even in an Arabic sentence.  Isolating it
// keeps it whole ("1Password" starts with a digit) and keeps the sentence's
// own punctuation on the right side of it, in both directions.
function isolate(name: string): string {
  return FIRST_STRONG_ISOLATE + name + POP_DIRECTIONAL_ISOLATE;
}

const HudhudPasswordManagerChoiceElementBase =
    WebUiListenerMixin(I18nMixin(PolymerElement));

/**
 * Who saves and fills in the user's passwords: Hudhud's own password manager,
 * a password-manager extension, or nobody.
 *
 * On the Settings page it is the list to choose from.  With `full-page` (in
 * password_manager_app.html) it is the whole page whenever Hudhud's own
 * password manager is not the one chosen: what is chosen, a button to open,
 * install or turn on the extension, and the list to choose again.  The app
 * hides its own page while this one has the `replaces-built-in` attribute.
 */
export class HudhudPasswordManagerChoiceElement extends
    HudhudPasswordManagerChoiceElementBase {
  static get is() {
    return 'hudhud-password-manager-choice';
  }

  static get template() {
    return getTemplate();
  }

  static get properties() {
    return {
      fullPage: {
        type: Boolean,
        value: false,
        reflectToAttribute: true,
      },

      replacesBuiltIn: {
        type: Boolean,
        computed: 'computeReplacesBuiltIn_(choice_)',
        reflectToAttribute: true,
      },

      // Until the browser answers, the page shows Hudhud's own password
      // manager, as it does for most users.
      choice_: {
        type: String,
        value: BUILT_IN,
      },

      managers_: {
        type: Array,
        value: () => [],
      },

      // The chosen extension; null for Hudhud's own password manager and for
      // none.
      chosenManager_: {
        type: Object,
        computed: 'computeChosenManager_(choice_, managers_)',
      },
    };
  }

  declare fullPage: boolean;
  declare replacesBuiltIn: boolean;
  declare private choice_: string;
  declare private managers_: ExtensionPasswordManager[];
  declare private chosenManager_: ExtensionPasswordManager|null;

  override connectedCallback() {
    super.connectedCallback();

    // The browser tells every open page when the choice changes, or when one
    // of the extensions is installed, removed, turned on or off.
    this.addWebUiListener(
        'hudhud-password-manager-changed',
        (state: ChoiceState) => this.applyState_(state));
    sendWithPromise<ChoiceState>('hudhudGetPasswordManagerChoice')
        .then(state => this.applyState_(state));
  }

  private applyState_(state: ChoiceState) {
    this.managers_ = state.managers;
    this.choice_ = state.choice;
  }

  private computeReplacesBuiltIn_(choice: string): boolean {
    return choice !== BUILT_IN;
  }

  private computeChosenManager_(
      choice: string,
      managers: ExtensionPasswordManager[]): ExtensionPasswordManager|null {
    return managers.find(manager => manager.id === choice) || null;
  }

  private onSelectedChanged_(e: CustomEvent<{value: string}>) {
    const selected = e.detail.value;
    // The radio group also says so when the page itself sets the choice.
    const isNewChoice = !!selected && selected !== this.choice_;
    if (!isNewChoice) {
      return;
    }
    // The browser answers with 'hudhud-password-manager-changed'.
    chrome.send('hudhudSetPasswordManagerChoice', [selected]);
  }

  private onOpenClick_() {
    // The browser opens the extension, its Web Store page, or its
    // chrome://extensions page, whichever applies.
    chrome.send('hudhudOpenPasswordManager', [this.chosenManager_!.id]);
  }

  private getStatusTitle_(manager: ExtensionPasswordManager|null): string {
    if (!manager) {
      return this.i18n('hudhudPasswordManagerOffTitle');
    }
    return this.i18n(
        'hudhudPasswordManagerInExtensionTitle', isolate(manager.name));
  }

  private getStatusDescription_(manager: ExtensionPasswordManager|null):
      string {
    if (!manager) {
      return this.i18n('hudhudPasswordManagerOffDescription');
    }
    return this.i18n(
        'hudhudPasswordManagerInExtensionDescription', isolate(manager.name));
  }

  // Why the extension cannot be opened yet; empty when it can.  (Polymer can
  // still call this, and the next, while the chosen extension's part of the
  // page goes away: hence the null.)
  private getExtensionNote_(manager: ExtensionPasswordManager|null): string {
    if (!manager) {
      return '';
    }
    const name = isolate(manager.name);
    if (!manager.installed) {
      return this.i18n('hudhudPasswordManagerNotInstalled', name);
    }
    if (!manager.enabled) {
      return this.i18n('hudhudPasswordManagerDisabled', name);
    }
    return '';
  }

  private getOpenButtonLabel_(manager: ExtensionPasswordManager|null):
      string {
    if (!manager) {
      return '';
    }
    const name = isolate(manager.name);
    if (!manager.installed) {
      return this.i18n('hudhudPasswordManagerInstall', name);
    }
    if (!manager.enabled) {
      return this.i18n('hudhudPasswordManagerTurnOn', name);
    }
    return this.i18n('hudhudPasswordManagerOpen', name);
  }
}

declare global {
  interface HTMLElementTagNameMap {
    'hudhud-password-manager-choice': HudhudPasswordManagerChoiceElement;
  }
}

customElements.define(
    HudhudPasswordManagerChoiceElement.is, HudhudPasswordManagerChoiceElement);
