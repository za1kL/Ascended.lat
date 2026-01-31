// Anti-DevTools Detection
(function() {
    'use strict';
    
    // Detect when DevTools is opened
    const devtools = /./;
    devtools.toString = function() {
        this.opened = true;
        document.body.innerHTML = '<div style="display:flex;justify-content:center;align-items:center;height:100vh;font-family:monospace;font-size:24px;background:#0d1117;color:#58a6ff;">cmon bro atleast give a effort to skid my script??</div>';
    }
    
    setInterval(() => {
        console.log(devtools);
        console.clear();
    }, 1000);
    
    // Debugger trap
    setInterval(() => {
        debugger;
    }, 100);
})();

// Disable Right-Click
document.addEventListener('contextmenu', function(e) {
    e.preventDefault();
    alert('cmon bro atleast give a effort to skid my script??');
    return false;
});

// Disable Common Keyboard Shortcuts
document.addEventListener('keydown', function(e) {
    // F12 - Developer Tools
    if (e.key === 'F12') {
        e.preventDefault();
        alert('cmon bro atleast give a effort to skid my script??');
        return false;
    }
    
    // Ctrl+Shift+I - Developer Tools
    if (e.ctrlKey && e.shiftKey && e.key === 'I') {
        e.preventDefault();
        alert('cmon bro atleast give a effort to skid my script??');
        return false;
    }
    
    // Ctrl+Shift+J - Console
    if (e.ctrlKey && e.shiftKey && e.key === 'J') {
        e.preventDefault();
        alert('cmon bro atleast give a effort to skid my script??');
        return false;
    }
    
    // Ctrl+U - View Source
    if (e.ctrlKey && e.key === 'u') {
        e.preventDefault();
        alert('cmon bro atleast give a effort to skid my script??');
        return false;
    }
    
    // Ctrl+Shift+C - Inspect Element
    if (e.ctrlKey && e.shiftKey && e.key === 'C') {
        e.preventDefault();
        alert('cmon bro atleast give a effort to skid my script??');
        return false;
    }
});

// Disable text selection
document.addEventListener('selectstart', function(e) {
    e.preventDefault();
    return false;
});

// Detect if page is being loaded in an iframe
if (window.top !== window.self) {
    window.top.location = window.self.location;
}

console.log('%cStop!', 'color: red; font-size: 50px; font-weight: bold;');
console.log('%cThis is a browser feature intended for developers. If someone told you to copy-paste something here, it is a scam.', 'font-size: 16px;');
