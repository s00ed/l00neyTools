// AUTO ARABIC DETECTION - Add this to Code Snippet JS tab
(function() {
    'use strict';
    
    // Create and inject CSS styles once
    const styleId = 'siyuan-arabic-rtl-styles';
    if (!document.getElementById(styleId)) {
        const style = document.createElement('style');
        style.id = styleId;
        style.textContent = `
            /* RTL Arabic styles */
            .arabic-rtl {
                direction: rtl !important;
                text-align: right !important;
                font-family: 'Amiri', 'Noto Sans Arabic', 'Cairo', 'Segoe UI', Arial, sans-serif !important;
                transition: none !important;
            }
            
            .arabic-rtl ul,
            .arabic-rtl ol {
                direction: rtl !important;
                text-align: right !important;
                padding-right: 2em !important;
                padding-left: 0 !important;
            }
            
            .arabic-rtl li {
                text-align: right !important;
            }
            
            /* LTR styles */
            .english-ltr {
                direction: ltr !important;
                text-align: left !important;
                font-family: inherit !important;
                transition: none !important;
            }
            
            /* Prevent font flickering */
            .protyle-wysiwyg [data-node-id],
            .item__text,
            .protyle-title__input,
            .protyle-title,
            .file-tree .b3-list-item__text,
            .protyle-breadcrumb__item,
            .layout-tab-bar .item__text {
                transition: none !important;
            }
            
            /* Ensure code blocks remain LTR */
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
    
    // Cache for processed elements to avoid redundant checks
    const processedElements = new WeakMap();
    
    // Improved Arabic detection function
    function shouldApplyRTL(text) {
        if (!text || text.trim().length === 0) return false;
        
        // Arabic Unicode range: U+0600 to U+06FF
        const arabicRegex = /[\u0600-\u06FF]/g;
        const arabicMatches = text.match(arabicRegex) || [];
        
        // Count Arabic characters
        const arabicCount = arabicMatches.length;
        
        // Count English letters
        const englishRegex = /[a-zA-Z]/g;
        const englishMatches = text.match(englishRegex) || [];
        const englishCount = englishMatches.length;
        
        // Count total meaningful characters (excluding spaces, numbers, punctuation)
        const totalLetters = arabicCount + englishCount;
        
        // Only apply RTL if:
        // 1. There are Arabic characters AND
        // 2. Arabic characters are more than 30% of total letters OR
        // 3. Arabic characters are more than English characters
        if (arabicCount > 0) {
            if (totalLetters === 0) return arabicCount > 0; // Pure Arabic symbols/text
            
            const arabicRatio = arabicCount / totalLetters;
            return arabicRatio > 0.3 || arabicCount >= englishCount;
        }
        
        return false;
    }
    
    // Function to apply RTL/LTR styling using classes
    function applyDirectionClass(element, isRTL) {
        // Check if element has already been processed with the same result
        const lastState = processedElements.get(element);
        if (lastState === isRTL) return; // No change needed
        
        // Remove both classes first to prevent conflicts
        element.classList.remove('arabic-rtl', 'english-ltr');
        
        // Apply appropriate class
        if (isRTL) {
            element.classList.add('arabic-rtl');
        } else {
            element.classList.add('english-ltr');
        }
        
        // Cache the state
        processedElements.set(element, isRTL);
    }
    
    // Debounce function to prevent excessive updates
    function debounce(func, wait) {
        let timeout;
        return function executedFunction(...args) {
            const later = () => {
                clearTimeout(timeout);
                func(...args);
            };
            clearTimeout(timeout);
            timeout = setTimeout(later, wait);
        };
    }
    
    // Function to check and apply RTL to document content
    function checkAndApplyRTL() {
        // 1. Handle document content elements
        const contentElements = document.querySelectorAll('.protyle-wysiwyg [data-node-id]');
        
        contentElements.forEach(element => {
            // Skip code blocks and similar elements
            if (element.querySelector('code, pre, .code-block, .render-node') || 
                element.matches('code, pre, .code-block, .render-node')) {
                return;
            }
            
            const text = element.textContent || element.innerText;
            const isRTL = shouldApplyRTL(text);
            applyDirectionClass(element, isRTL);
        });
        
        // 2. Handle various UI elements
        const uiSelectors = [
            '.item__text',
            '.protyle-title__input',
            '.protyle-title',
            '.file-tree .b3-list-item__text',
            '.protyle-breadcrumb__item',
            '.layout-tab-bar .item__text'
        ];
        
        const uiElements = document.querySelectorAll(uiSelectors.join(', '));
        
        uiElements.forEach(element => {
            const text = element.textContent || element.innerText || element.value;
            const isRTL = shouldApplyRTL(text);
            applyDirectionClass(element, isRTL);
        });
    }
    
    // Debounced version of checkAndApplyRTL
    const debouncedCheck = debounce(checkAndApplyRTL, 100);
    
    // Run on page load
    setTimeout(checkAndApplyRTL, 500);
    
    // Optimized MutationObserver
    const observer = new MutationObserver(function(mutations) {
        let shouldCheck = false;
        
        for (const mutation of mutations) {
            // Check if the mutation is relevant
            if (mutation.type === 'childList' && mutation.addedNodes.length > 0) {
                shouldCheck = true;
                break;
            } else if (mutation.type === 'characterData' && mutation.target.nodeValue) {
                shouldCheck = true;
                break;
            }
        }
        
        if (shouldCheck) {
            debouncedCheck();
        }
    });
    
    // Start observing with optimized options
    observer.observe(document.body, {
        childList: true,
        subtree: true,
        characterData: true,
        attributes: false, // Don't observe attribute changes
        attributeOldValue: false
    });
    
    // Handle input events with debouncing
    document.addEventListener('input', debouncedCheck);
    
    // Handle focus events for title editing
    document.addEventListener('focus', function(e) {
        if (e.target.matches('.protyle-title__input, .item__text')) {
            setTimeout(() => {
                const text = e.target.textContent || e.target.innerText || e.target.value;
                const isRTL = shouldApplyRTL(text);
                applyDirectionClass(e.target, isRTL);
            }, 50);
        }
    }, true);
    
    // Run periodically as a fallback (less frequently)
    setInterval(checkAndApplyRTL, 5000);
    
    console.log('✅ Enhanced Arabic RTL detection (Stable Version) is now active!');
})();
