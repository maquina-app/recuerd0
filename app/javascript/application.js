// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import "house"

if ("serviceWorker" in navigator) {
  navigator.serviceWorker.register("/service-worker.js", { scope: "/" })
}

// Custom Turbo Confirmation Dialog
document.addEventListener('DOMContentLoaded', () => {
  // Override Turbo's default confirmation method
  Turbo.config.forms.confirm = (message, element) => {
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
    const data = element?.dataset ?? {};

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
