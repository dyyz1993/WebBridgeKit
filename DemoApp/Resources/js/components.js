/**
 * UI Components Library
 * Reusable UI components with built-in functionality
 */

class Components {
    /**
     * Create a card component
     */
    static createCard(options = {}) {
        const {
            title = '',
            content = '',
            footer = '',
            classes = ''
        } = options;

        const card = document.createElement('div');
        card.className = `card ${classes}`;

        let html = '';
        if (title) {
            html += `<div class="card-header"><h3>${title}</h3></div>`;
        }
        if (content) {
            html += `<div class="card-body">${content}</div>`;
        }
        if (footer) {
            html += `<div class="card-footer">${footer}</div>`;
        }

        card.innerHTML = html;
        return card;
    }

    /**
     * Create a button component
     */
    static createButton(options = {}) {
        const {
            text = 'Button',
            type = 'primary',
            onClick = null,
            classes = '',
            icon = null
        } = options;

        const button = document.createElement('button');
        button.className = `btn btn-${type} ${classes}`;
        button.textContent = text;

        if (icon) {
            button.innerHTML = `${icon} ${text}`;
        }

        if (onClick) {
            button.addEventListener('click', onClick);
        }

        return button;
    }

    /**
     * Create an alert component
     */
    static createAlert(options = {}) {
        const {
            type = 'info',
            message = '',
            dismissible = false,
            classes = ''
        } = options;

        const alert = document.createElement('div');
        alert.className = `alert alert-${type} ${classes}`;
        alert.innerHTML = message;

        if (dismissible) {
            const closeBtn = document.createElement('button');
            closeBtn.innerHTML = '&times;';
            closeBtn.style.cssText = 'float: right; font-size: 20px; cursor: pointer;';
            closeBtn.addEventListener('click', () => alert.remove());
            alert.insertBefore(closeBtn, alert.firstChild);
        }

        return alert;
    }

    /**
     * Create a progress bar component
     */
    static createProgressBar(options = {}) {
        const {
            value = 0,
            max = 100,
            showLabel = true,
            animated = true,
            classes = ''
        } = options;

        const progress = document.createElement('div');
        progress.className = `progress ${animated ? 'progress-animated' : ''} ${classes}`;

        const bar = document.createElement('div');
        bar.className = 'progress-bar';
        bar.style.width = `${(value / max) * 100}%`;
        bar.setAttribute('role', 'progressbar');
        bar.setAttribute('aria-valuenow', value);
        bar.setAttribute('aria-valuemin', 0);
        bar.setAttribute('aria-valuemax', max);

        if (showLabel) {
            bar.textContent = `${Math.round((value / max) * 100)}%`;
        }

        progress.appendChild(bar);
        return progress;
    }

    /**
     * Create a spinner component
     */
    static createSpinner(options = {}) {
        const {
            size = 'md',
            classes = ''
        } = options;

        const spinner = document.createElement('div');
        spinner.className = `spinner spinner-${size} ${classes}`;
        return spinner;
    }

    /**
     * Create a badge component
     */
    static createBadge(options = {}) {
        const {
            text = '',
            type = 'primary',
            classes = ''
        } = options;

        const badge = document.createElement('span');
        badge.className = `badge badge-${type} ${classes}`;
        badge.textContent = text;
        return badge;
    }

    /**
     * Create a table component
     */
    static createTable(options = {}) {
        const {
            headers = [],
            rows = [],
            classes = ''
        } = options;

        const table = document.createElement('table');
        table.className = `table ${classes}`;

        if (headers.length > 0) {
            const thead = document.createElement('thead');
            const headerRow = document.createElement('tr');
            headers.forEach(header => {
                const th = document.createElement('th');
                th.textContent = header;
                headerRow.appendChild(th);
            });
            thead.appendChild(headerRow);
            table.appendChild(thead);
        }

        if (rows.length > 0) {
            const tbody = document.createElement('tbody');
            rows.forEach(row => {
                const tr = document.createElement('tr');
                row.forEach(cell => {
                    const td = document.createElement('td');
                    td.textContent = cell;
                    tr.appendChild(td);
                });
                tbody.appendChild(tr);
            });
            table.appendChild(tbody);
        }

        return table;
    }

    /**
     * Create a tabs component
     */
    static createTabs(options = {}) {
        const {
            tabs = [],
            activeIndex = 0,
            classes = ''
        } = options;

        const container = document.createElement('div');
        container.className = `tabs ${classes}`;

        const tabList = document.createElement('div');
        tabList.className = 'tab-list';
        tabList.style.cssText = 'display: flex; border-bottom: 1px solid #e0e0e0;';

        const tabPanels = [];

        tabs.forEach((tab, index) => {
            const tabButton = document.createElement('button');
            tabButton.className = `tab-button ${index === activeIndex ? 'active' : ''}`;
            tabButton.textContent = tab.label;
            tabButton.style.cssText = `
                padding: 12px 20px;
                border: none;
                background: ${index === activeIndex ? '#2563eb' : 'transparent'};
                color: ${index === activeIndex ? 'white' : '#374151'};
                cursor: pointer;
                border-bottom: 3px solid ${index === activeIndex ? '#2563eb' : 'transparent'};
            `;

            const tabPanel = document.createElement('div');
            tabPanel.className = 'tab-panel';
            tabPanel.style.cssText = `
                padding: 20px;
                display: ${index === activeIndex ? 'block' : 'none'};
            `;
            tabPanel.innerHTML = tab.content;

            tabButton.addEventListener('click', () => {
                // Deactivate all tabs
                tabList.querySelectorAll('.tab-button').forEach(btn => {
                    btn.style.background = 'transparent';
                    btn.style.color = '#374151';
                    btn.style.borderBottomColor = 'transparent';
                });
                tabPanels.forEach(panel => panel.style.display = 'none');

                // Activate clicked tab
                tabButton.style.background = '#2563eb';
                tabButton.style.color = 'white';
                tabButton.style.borderBottomColor = '#2563eb';
                tabPanel.style.display = 'block';
            });

            tabList.appendChild(tabButton);
            tabPanels.push(tabPanel);
        });

        container.appendChild(tabList);
        tabPanels.forEach(panel => container.appendChild(panel));

        return container;
    }

    /**
     * Create an accordion component
     */
    static createAccordion(options = {}) {
        const {
            items = [],
            classes = ''
        } = options;

        const accordion = document.createElement('div');
        accordion.className = `accordion ${classes}`;

        items.forEach((item, index) => {
            const itemDiv = document.createElement('div');
            itemDiv.className = 'accordion-item';
            itemDiv.style.cssText = 'border: 1px solid #e0e0e0; margin-bottom: 5px; border-radius: 4px; overflow: hidden;';

            const header = document.createElement('div');
            header.className = 'accordion-header';
            header.style.cssText = `
                padding: 15px;
                background: #f9f9f9;
                cursor: pointer;
                display: flex;
                justify-content: space-between;
                align-items: center;
            `;
            header.innerHTML = `<strong>${item.title}</strong><span>▼</span>`;

            const content = document.createElement('div');
            content.className = 'accordion-content';
            content.style.cssText = `
                padding: 15px;
                display: ${index === 0 ? 'block' : 'none'};
                background: white;
            `;
            content.innerHTML = item.content;

            header.addEventListener('click', () => {
                const isOpen = content.style.display !== 'none';
                content.style.display = isOpen ? 'none' : 'block';
                header.querySelector('span').textContent = isOpen ? '▼' : '▲';
            });

            itemDiv.appendChild(header);
            itemDiv.appendChild(content);
            accordion.appendChild(itemDiv);
        });

        return accordion;
    }

    /**
     * Create a modal component
     */
    static createModal(options = {}) {
        const {
            title = '',
            content = '',
            showClose = true,
            size = 'md',
            classes = ''
        } = options;

        const modal = document.createElement('div');
        modal.className = `modal ${classes}`;
        modal.style.cssText = `
            display: none;
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background: rgba(0,0,0,0.5);
            z-index: 1000;
            align-items: center;
            justify-content: center;
        `;

        const sizes = {
            sm: '400px',
            md: '600px',
            lg: '800px',
            xl: '1000px'
        };

        const dialog = document.createElement('div');
        dialog.style.cssText = `
            background: white;
            border-radius: 8px;
            width: 90%;
            max-width: ${sizes[size]};
            max-height: 90vh;
            overflow-y: auto;
            box-shadow: 0 4px 20px rgba(0,0,0,0.3);
        `;

        let html = '';
        if (title || showClose) {
            html += `<div style="padding: 20px; border-bottom: 1px solid #e0e0e0; display: flex; justify-content: space-between; align-items: center;">`;
            if (title) html += `<h3 style="margin: 0;">${title}</h3>`;
            if (showClose) html += `<button class="modal-close" style="background: none; border: none; font-size: 24px; cursor: pointer;">&times;</button>`;
            html += `</div>`;
        }
        html += `<div style="padding: 20px;">${content}</div>`;

        dialog.innerHTML = html;
        modal.appendChild(dialog);

        // Close functionality
        const close = () => modal.style.display = 'none';
        dialog.querySelector('.modal-close').addEventListener('click', close);
        modal.addEventListener('click', (e) => {
            if (e.target === modal) close();
        });

        modal.show = () => modal.style.display = 'flex';
        modal.hide = () => modal.style.display = 'none';

        return modal;
    }

    /**
     * Create a tooltip component
     */
    static createTooltip(options = {}) {
        const {
            target = null,
            text = '',
            position = 'top'
        } = options;

        if (!target) return null;

        const tooltip = document.createElement('div');
        tooltip.className = 'tooltip';
        tooltip.textContent = text;
        tooltip.style.cssText = `
            position: absolute;
            background: #374151;
            color: white;
            padding: 5px 10px;
            border-radius: 4px;
            font-size: 12px;
            white-space: nowrap;
            z-index: 100;
            display: none;
        `;

        target.style.position = 'relative';
        target.appendChild(tooltip);

        target.addEventListener('mouseenter', () => {
            tooltip.style.display = 'block';
            const rect = target.getBoundingClientRect();
            const positions = {
                top: { bottom: '100%', left: '50%', transform: 'translateX(-50%)', marginBottom: '5px' },
                bottom: { top: '100%', left: '50%', transform: 'translateX(-50%)', marginTop: '5px' },
                left: { right: '100%', top: '50%', transform: 'translateY(-50%)', marginRight: '5px' },
                right: { left: '100%', top: '50%', transform: 'translateY(-50%)', marginLeft: '5px' }
            };
            Object.assign(tooltip.style, positions[position]);
        });

        target.addEventListener('mouseleave', () => {
            tooltip.style.display = 'none';
        });

        return tooltip;
    }
}

// Auto-initialize components on page load
document.addEventListener('DOMContentLoaded', () => {
    console.log('Components library loaded');

    // Auto-initialize data-component elements
    document.querySelectorAll('[data-component]').forEach(el => {
        const componentName = el.dataset.component;
        console.log(`Auto-initializing component: ${componentName}`);
    });
});

// Export for use in other modules
if (typeof module !== 'undefined' && module.exports) {
    module.exports = Components;
}
