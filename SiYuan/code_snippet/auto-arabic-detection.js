// AUTO ARABIC DETECTION - Add this to Code Snippet JS tab

(function() {
    // Improved Arabic detection function
    function shouldApplyRTL(text) {
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
            if (totalLetters === 0) return false;
            
            const arabicRatio = arabicCount / totalLetters;
            return arabicRatio > 0.3 || arabicCount >= englishCount;
        }
        
        return false;
    }
    
    // Function to check and apply RTL to elements
    function checkAndApplyRTL() {
        // Find all text content elements
        const elements = document.querySelectorAll('.protyle-wysiwyg [data-node-id]');
        
        elements.forEach(element => {
            const text = element.textContent || element.innerText;
            
            if (shouldApplyRTL(text)) {
                // Apply RTL styling
                element.style.direction = 'rtl';
                element.style.textAlign = 'right';
                element.style.fontFamily = "'Amiri', 'Noto Sans Arabic', Arial, sans-serif";
                
                // Handle lists specifically
                const lists = element.querySelectorAll('ul, ol');
                lists.forEach(list => {
                    list.style.direction = 'rtl';
                    list.style.textAlign = 'right';
                });
                
                // Handle list items
                const listItems = element.querySelectorAll('li');
                listItems.forEach(li => {
                    li.style.textAlign = 'right';
                });
            } else if (!element.querySelector('code, pre, .code-block, .render-node')) {
                // If no Arabic text and no code blocks, keep LTR
                element.style.direction = 'ltr';
                element.style.textAlign = 'left';
            }
        });
    }
    
    // Run on page load
    checkAndApplyRTL();
    
    // Run when new content is added (observer for dynamic content)
    const observer = new MutationObserver(function(mutations) {
        let shouldCheck = false;
        mutations.forEach(function(mutation) {
            if (mutation.type === 'childList' || mutation.type === 'characterData') {
                shouldCheck = true;
            }
        });
        
        if (shouldCheck) {
            setTimeout(checkAndApplyRTL, 100); // Small delay to ensure content is rendered
        }
    });
    
    // Start observing
    const targetNode = document.querySelector('.protyle-wysiwyg') || document.body;
    observer.observe(targetNode, {
        childList: true,
        subtree: true,
        characterData: true
    });
    
    // Also run on input events for real-time detection
    document.addEventListener('input', function(e) {
        if (e.target.closest('.protyle-wysiwyg')) {
            setTimeout(checkAndApplyRTL, 50);
        }
    });
    
    // Run periodically as a fallback
    setInterval(checkAndApplyRTL, 2000);
    
    console.log('✅ Auto Arabic RTL detection is now active!');
})();
