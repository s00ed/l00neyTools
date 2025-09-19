// SiYuan Full Arabic/English Direction  - Smart Mixed Text Handling

(function() {
    'use strict';

    // Inject styles
    const styleId = 'siyuan-arabic-rtl-styles';
    if (!document.getElementById(styleId)) {
        const style = document.createElement('style');
        style.id = styleId;
        style.textContent = `
            .arabic-rtl {
                direction: rtl !important;
                text-align: right !important;
                font-family: 'Amiri', 'Noto Sans Arabic', 'Cairo', 'Segoe UI', Arial, sans-serif !important;
                transition: none !important;
            }
            .english-ltr {
                direction: ltr !important;
                text-align: left !important;
                font-family: inherit !important;
                transition: none !important;
            }
            .arabic-rtl code,
            .arabic-rtl pre,
            .arabic-rtl .code-block,
            .arabic-rtl .render-node {
                direction: ltr !important;
                text-align: left !important;
                font-family: monospace !important;
            }
        `;
        document.head.appendChild(style);
    }

    const processedElements = new WeakMap();

    // Determine text direction based on first strong character
    function shouldApplyRTL(text) {
        if (!text || !text.trim()) return false;

        for (let i = 0; i < text.length; i++) {
            const char = text[i];
            if (/[\u0600-\u06FF]/.test(char)) return true;  // Arabic
            if (/[a-zA-Z]/.test(char)) return false;        // English
        }

        // fallback if no strong character
        return false;
    }

    function applyDirectionClass(element, isRTL) {
        const lastState = processedElements.get(element);
        if (lastState === isRTL) return;

        element.classList.remove('arabic-rtl', 'english-ltr');
        element.classList.add(isRTL ? 'arabic-rtl' : 'english-ltr');
        processedElements.set(element, isRTL);
    }

    function debounce(func, wait) {
        let timeout;
        return function(...args) {
            clearTimeout(timeout);
            timeout = setTimeout(() => func(...args), wait);
        };
    }

    function checkAndApplyRTL() {
        const contentElements = document.querySelectorAll('.protyle-wysiwyg [data-node-id]');
        contentElements.forEach(el => {
            if (el.querySelector('code, pre, .code-block, .render-node') || 
                el.matches('code, pre, .code-block, .render-node')) return;

            const text = el.textContent || el.innerText;
            const isRTL = shouldApplyRTL(text);
            applyDirectionClass(el, isRTL);
        });

        const uiSelectors = [
            '.item__text',
            '.protyle-title__input',
            '.protyle-title',
            '.file-tree .b3-list-item__text',
            '.protyle-breadcrumb__item',
            '.layout-tab-bar .item__text'
        ];
        document.querySelectorAll(uiSelectors.join(', ')).forEach(el => {
            const text = el.textContent || el.innerText || el.value;
            const isRTL = shouldApplyRTL(text);
            applyDirectionClass(el, isRTL);
        });
    }

    const debouncedCheck = debounce(checkAndApplyRTL, 100);

    setTimeout(checkAndApplyRTL, 500);

    const observer = new MutationObserver(mutations => {
        if (mutations.some(m => (m.type === 'childList' && m.addedNodes.length > 0) ||
                                 (m.type === 'characterData' && m.target.nodeValue))) {
            debouncedCheck();
        }
    });
    observer.observe(document.body, { childList: true, subtree: true, characterData: true });

    document.addEventListener('input', debouncedCheck);

    document.addEventListener('focus', e => {
        if (e.target.matches('.protyle-title__input, .item__text')) {
            setTimeout(() => {
                const text = e.target.textContent || e.target.innerText || e.target.value;
                const isRTL = shouldApplyRTL(text);
                applyDirectionClass(e.target, isRTL);
            }, 50);
        }
    }, true);

    setInterval(checkAndApplyRTL, 5000);

    console.log('✅ SiYuan Smart Arabic/English direction fix is active!');
})();
