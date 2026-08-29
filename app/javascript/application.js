// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import "house"

if ("serviceWorker" in navigator) {
  navigator.serviceWorker.register("/service-worker.js", { scope: "/" })
}

// Custom Turbo Confirmation Dialog
//
// Turbo synthesises a bare <form> from any data-turbo-method link and copies
// only eight attributes onto it (action, method, data-turbo-frame,
// data-turbo-action, data-turbo-confirm, data-turbo-stream). Our
// confirm_title/confirm_button/confirm_severity attributes are NOT among them,
// and a synthesised form has no submitter — so for every dropdown menu item the
// handler below used to receive `undefined` and fall back to "Confirm".
// Recording the clicked trigger is the only way to get the authored copy back.
// Never let a morph overwrite the field the visitor is currently typing in.
//
// The workspaces filter submits debounced and morphs the page in place. Without
// this guard, the response for an earlier keystroke morphs its own (older)
// value back into the input: typing "systemd" reliably ends up as "s", because
// each render resets the field to whatever the server last saw. Idiomorph
// restores focus and caret, but it has no way to know the value it is writing
// is already stale.
//
// Scoped deliberately to the focused element, rather than data-turbo-permanent
// on the input: the server must still be able to reset the field when the
// visitor is NOT typing in it (the "Clear filter" link, a sort change).
document.addEventListener('turbo:before-morph-element', (event) => {
  const el = event.target;
  if (el !== document.activeElement) return;
  if (el instanceof HTMLTextAreaElement ||
      (el instanceof HTMLInputElement && !['checkbox', 'radio', 'submit', 'button'].includes(el.type))) {
    event.preventDefault();
  }
});

let lastConfirmTrigger = null;
document.addEventListener('click', (event) => {
  const trigger = event.target?.closest?.('[data-turbo-confirm]');
  if (trigger) lastConfirmTrigger = trigger;
}, true);

document.addEventListener('DOMContentLoaded', () => {
  // Override Turbo's default confirmation method. Turbo calls this with
  // (message, submitter, formElement); real forms carry the data on one of
  // those two, links do not.
  Turbo.config.forms.confirm = (message, submitter, formElement) => {
    const dialog = document.getElementById('turbo-confirm');
    const defaults = {
      title: dialog?.querySelector('#turbo-confirm-title')?.dataset.defaultText,
      confirmLabel: dialog?.querySelector('[data-behavior="confirm"]')?.dataset.defaultText
    };

    if (!dialog) {
      console.error('Turbo confirm dialog not found');
      return Promise.resolve(false);
    }

    // Get the inner content div
    const contentDiv = dialog.querySelector('[data-state]');

    // Update the message
    const messageElement = dialog.querySelector('#turbo-confirm-message');
    if (messageElement) {
      messageElement.textContent = message;
    }

    // The trigger names what is about to happen. Severity drives the confirm
    // button's variant, so a reversible action (archive) is not dressed in the
    // same red as an irreversible one (permanent delete).
    const titleElement = dialog.querySelector('#turbo-confirm-title');
    const confirmElement = dialog.querySelector('[data-behavior="confirm"]');

    // Prefer whichever element actually carries the authored copy. The recorded
    // trigger is only trusted when its own confirm message is the one being
    // shown, so a stale click can never relabel a later dialog.
    const carriesConfirmCopy = (el) =>
      el?.dataset?.confirmTitle || el?.dataset?.confirmButton || el?.dataset?.confirmSeverity;
    const source =
      [submitter, formElement].find(carriesConfirmCopy) ??
      (lastConfirmTrigger?.dataset?.turboConfirm === message ? lastConfirmTrigger : null);
    const data = source?.dataset ?? {};

    if (titleElement) {
      titleElement.textContent = data.confirmTitle || defaults.title;
    }
    if (confirmElement) {
      confirmElement.textContent = data.confirmButton || defaults.confirmLabel;
      confirmElement.setAttribute(
        'data-variant',
        data.confirmSeverity === 'warning' ? 'default' : 'destructive'
      );
    }

    // Set state to open for animations
    if (contentDiv) {
      contentDiv.setAttribute('data-state', 'open');
    }

    // Show the modal
    dialog.showModal();

    // Return a promise that resolves based on user action
    return new Promise((resolve) => {
      const cancelButton = dialog.querySelector('[data-behavior="cancel"]');
      const confirmButton = dialog.querySelector('[data-behavior="confirm"]');

      const cleanup = () => {
        // Set state to closed for animations
        if (contentDiv) {
          contentDiv.setAttribute('data-state', 'closed');
        }

        // Wait for animation to complete
        setTimeout(() => {
          dialog.close();
          if (contentDiv) {
            contentDiv.setAttribute('data-state', 'open');
          }
          cancelButton.removeEventListener('click', handleCancel);
          confirmButton.removeEventListener('click', handleConfirm);
          dialog.removeEventListener('cancel', handleCancel);
        }, 150);
      };

      const handleCancel = () => {
        cleanup();
        resolve(false);
      };

      const handleConfirm = () => {
        cleanup();
        resolve(true);
      };

      // Handle button clicks
      cancelButton.addEventListener('click', handleCancel, { once: true });
      confirmButton.addEventListener('click', handleConfirm, { once: true });

      // Handle ESC key (triggers 'cancel' event on dialog)
      dialog.addEventListener('cancel', (e) => {
        e.preventDefault(); // Prevent default close behavior
        handleCancel();
      }, { once: true });
    });
  };
});
