// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// Close any open dropdown menus in the given root element.
// TODO: Remove once maquina-components gem adds teardown() to dropdown_menu_controller.
function closeOpenDropdowns(root) {
  root.querySelectorAll('[data-controller="dropdown-menu"][data-state="open"]').forEach((dropdown) => {
    dropdown.setAttribute("data-state", "closed")

    const content = dropdown.querySelector('[data-dropdown-menu-target="content"]')
    if (content) {
      content.setAttribute("data-state", "closed")
      content.hidden = true
    }

    const trigger = dropdown.querySelector('[data-dropdown-menu-target="trigger"]')
    if (trigger) {
      trigger.setAttribute("aria-expanded", "false")
    }
  })
}

// Clean the snapshot before Turbo caches it on navigation away.
document.addEventListener("turbo:before-cache", () => {
  closeOpenDropdowns(document)
})

// Clean the cached body before Turbo renders it on Back/Forward navigation.
// This prevents the brief flash of an open dropdown while the snapshot is painted.
document.addEventListener("turbo:before-render", (event) => {
  closeOpenDropdowns(event.detail.newBody)
})

// Custom Turbo Confirmation Dialog
document.addEventListener('DOMContentLoaded', () => {
  // Override Turbo's default confirmation method
  Turbo.config.forms.confirm = (message, element) => {
    const dialog = document.getElementById('turbo-confirm');

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
