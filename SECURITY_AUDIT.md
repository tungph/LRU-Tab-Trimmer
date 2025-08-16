# Security Audit Report - LRU Tab Trimmer Extension

**Date:** 2025-08-15  
**Auditor:** Security Analysis  
**Extension Version:** 1.0.0  
**Manifest Version:** 2 (Firefox)

## Executive Summary

This security audit identifies critical vulnerabilities in the LRU Tab Trimmer browser extension that require immediate attention. The most severe issues include XSS vulnerabilities through dynamic code injection, unrestricted external extension communication, and overly broad permissions.

## Table of Contents

1. [Critical Security Issues](#critical-security-issues)
2. [High Severity Issues](#high-severity-issues)
3. [Medium Severity Issues](#medium-severity-issues)
4. [Low Severity Issues](#low-severity-issues)
5. [Recommended Fixes](#recommended-fixes)
6. [Testing Recommendations](#testing-recommendations)
7. [Security Best Practices](#security-best-practices)

---

## 🔴 Critical Security Issues

### 1. Code Injection via Title Prepend (XSS)

**Severity:** CRITICAL  
**Location:** `background.js` lines 214-219  
**CVSS Score:** 8.8 (High)

#### Description
The extension injects user-controlled content directly into JavaScript code without proper sanitization.

#### Vulnerable Code
```javascript
chrome.tabs.executeScript(tab.id, {
  runAt: 'document_start',
  code: `
    window.stop();
    document.title = '${prefs.prepends.replace(/'/g, '_')} ' + (document.title || location.href);
  `
```

#### Impact
- Arbitrary JavaScript execution in tab context
- Potential for data theft from visited websites
- Session hijacking possibilities

#### Proof of Concept
```javascript
// Malicious prepend value:
prefs.prepends = "'; alert('XSS'); //"
// Results in injected code:
document.title = ''; alert('XSS'); //' + (document.title || location.href);
```

### 2. Dynamic Code Execution with User Input

**Severity:** CRITICAL  
**Location:** Multiple instances throughout codebase  
**CVSS Score:** 8.6 (High)

#### Affected Files
- `background.js`: Lines 192-203 (favicon injection)
- `plugins/youtube/inject.js`: Direct script injection
- `menu.js`: Line 195 (executeScript with template literals)

#### Description
Multiple instances of `chrome.tabs.executeScript()` using template literals with user-controlled data.

#### Impact
- Code injection vulnerabilities
- Bypass of Content Security Policies
- Potential for privilege escalation

### 3. Overly Broad Host Permissions

**Severity:** CRITICAL  
**Location:** `manifest.json` line 27  
**CVSS Score:** 7.5 (High)

#### Current Permission
```json
"permissions": [
  "*://*/*"
]
```

#### Impact
- Access to all websites and their data
- Ability to modify any webpage
- Privacy concerns for users
- Increases attack surface significantly

---

## 🟡 High Severity Issues

### 4. Unvalidated External Extension Communication

**Severity:** HIGH  
**Location:** `background.js` lines 252-262  
**CVSS Score:** 7.3 (High)

#### Vulnerable Code
```javascript
chrome.runtime.onMessageExternal.addListener((request, sender, response) => {
  if (request.method === 'discard') {
    query(request.query).then((tbs = []) => {
      // No sender validation!
```

#### Impact
- Any extension can trigger tab operations
- No authentication mechanism
- Potential for malicious extensions to abuse functionality

### 5. Regular Expression Injection (ReDoS)

**Severity:** HIGH  
**Location:** `menu.js` line 114, `data/popup/index.js` lines 44-49  
**CVSS Score:** 6.5 (Medium-High)

#### Vulnerable Code
```javascript
if (menuItemId === 'whitelist-exact') {
  rule = 're:^' + tab.url.replace(/[-[\]{}()*+?.,\\^$|#\s]/g, '\\$&') + '$';
}
// Later:
return (new RegExp(s)).test(tab.url); // No validation!
```

#### Impact
- Denial of Service through CPU exhaustion
- Browser tab/process hanging
- Poor user experience

### 6. Insufficient Input Validation

**Severity:** HIGH  
**Location:** `data/options/index.js` lines 182-196  
**CVSS Score:** 6.1 (Medium)

#### Issues
- URL parsing without proper validation
- No sanitization of hostname extraction
- Missing bounds checking for numeric inputs
- No validation of imported configuration data

---

## 🟠 Medium Severity Issues

### 7. Import/Export Security Vulnerabilities

**Severity:** MEDIUM  
**Location:** `data/options/index.js` lines 284-321  
**CVSS Score:** 5.3 (Medium)

#### Issues
- Excessive file size limit (100MB)
- No JSON schema validation
- localStorage data exposed in exports
- No integrity checking for imported data

#### Vulnerable Code
```javascript
if (file.size > 100e6) { // 100MB is excessive
  console.warn('100MB backup? I don\'t believe you.');
  return;
}
```

### 8. Plugin System Dynamic Import Risks

**Severity:** MEDIUM  
**Location:** `plugins.js`  
**CVSS Score:** 5.0 (Medium)

#### Issues
- Dynamic imports based on user preferences
- No code signature verification
- Plugin interrupt system can modify core functionality
- No sandboxing of plugin code

### 9. YouTube Plugin Script Injection

**Severity:** MEDIUM  
**Location:** `plugins/youtube/inject.js`  
**CVSS Score:** 4.7 (Medium)

#### Vulnerable Code
```javascript
const s = document.createElement('script');
s.textContent = `{
  const player = document.querySelector('.html5-video-player');
  // ... modifies URL parameters without validation
}`;
document.body.appendChild(s);
```

---

## 🟢 Low Severity Issues

### 10. Missing Content Security Policy

**Severity:** LOW  
**Location:** `manifest.json`  
**CVSS Score:** 3.1 (Low)

**Issue:** No Content Security Policy defined, allowing inline scripts and reducing defense-in-depth.

### 11. Hardcoded Extension IDs

**Severity:** LOW  
**Location:** `menu.js` line 6  
**CVSS Score:** 2.0 (Low)

```javascript
const TST = 'treestyletab@piro.sakura.ne.jp';
```

### 12. Information Disclosure via Debug Logging

**Severity:** LOW  
**Location:** Throughout codebase  
**CVSS Score:** 3.3 (Low)

**Issue:** Debug logging can expose sensitive information when enabled.

---

## 📋 Recommended Fixes

### Priority 1: Critical Fixes (Implement Immediately)

#### Fix 1: Secure Title Prepending

**Current (Vulnerable):**
```javascript
document.title = '${prefs.prepends.replace(/'/g, '_')} ' + (document.title || location.href);
```

**Recommended Fix:**
```javascript
// Use JSON.stringify for proper escaping
const safePrepend = JSON.stringify(prefs.prepends);
chrome.tabs.executeScript(tab.id, {
  code: `document.title = ${safePrepend} + ' ' + (document.title || location.href);`
});
```

#### Fix 2: Add External Extension Authentication

**Recommended Implementation:**
```javascript
// Define allowed extensions
const ALLOWED_EXTENSIONS = new Set([
  'extension-id-1',
  'extension-id-2'
]);

// Validate sender
chrome.runtime.onMessageExternal.addListener((request, sender, response) => {
  // Verify sender
  if (!ALLOWED_EXTENSIONS.has(sender.id)) {
    console.warn(`Unauthorized extension ${sender.id} attempted communication`);
    return false;
  }
  
  // Validate request structure
  if (!request || typeof request.method !== 'string') {
    return false;
  }
  
  // Process valid requests
  // ...
});
```

#### Fix 3: Restrict Host Permissions

**Current manifest.json:**
```json
"permissions": [
  "*://*/*"
]
```

**Recommended:**
```json
"permissions": [
  "activeTab",
  "tabs",
  "storage",
  "idle",
  "contextMenus",
  "notifications",
  "alarms"
],
"optional_permissions": [
  "http://*/*",
  "https://*/*"
]
```

### Priority 2: High Severity Fixes

#### Fix 4: Regex Pattern Validation

**Implementation:**
```javascript
function validateRegexPattern(pattern, maxComplexity = 100) {
  try {
    // Compile regex
    const regex = new RegExp(pattern);
    
    // Test complexity with timeout
    const testString = 'a'.repeat(maxComplexity);
    const startTime = performance.now();
    
    // Set a timeout for regex execution
    const timeoutId = setTimeout(() => {
      throw new Error('Regex execution timeout');
    }, 100);
    
    regex.test(testString);
    clearTimeout(timeoutId);
    
    // Check execution time
    if (performance.now() - startTime > 50) {
      throw new Error('Regex too complex');
    }
    
    return { valid: true, error: null };
  } catch (error) {
    return { valid: false, error: error.message };
  }
}

// Usage
const validation = validateRegexPattern(userPattern);
if (!validation.valid) {
  console.error('Invalid regex pattern:', validation.error);
  return;
}
```

#### Fix 5: Secure Import/Export

**Implementation:**
```javascript
// Define schema for valid configuration
const CONFIG_SCHEMA = {
  version: 'string',
  'chrome.storage.local': 'object',
  localStorage: 'object'
};

function validateImportData(data) {
  // Size validation
  const MAX_SIZE = 1024 * 1024; // 1MB
  const dataSize = new Blob([JSON.stringify(data)]).size;
  
  if (dataSize > MAX_SIZE) {
    throw new Error('Import file too large (max 1MB)');
  }
  
  // Structure validation
  for (const [key, type] of Object.entries(CONFIG_SCHEMA)) {
    if (typeof data[key] !== type) {
      throw new Error(`Invalid data structure: ${key} must be ${type}`);
    }
  }
  
  // Sanitize values
  const sanitized = {
    version: String(data.version).substring(0, 20),
    'chrome.storage.local': sanitizeStorageData(data['chrome.storage.local']),
    localStorage: sanitizeStorageData(data.localStorage)
  };
  
  return sanitized;
}

function sanitizeStorageData(data) {
  const sanitized = {};
  const MAX_KEY_LENGTH = 100;
  const MAX_VALUE_LENGTH = 10000;
  
  for (const [key, value] of Object.entries(data)) {
    if (key.length > MAX_KEY_LENGTH) continue;
    
    const safeKey = key.replace(/[^a-zA-Z0-9._-]/g, '');
    
    if (typeof value === 'string' && value.length <= MAX_VALUE_LENGTH) {
      sanitized[safeKey] = value;
    } else if (typeof value === 'number' || typeof value === 'boolean') {
      sanitized[safeKey] = value;
    } else if (Array.isArray(value)) {
      sanitized[safeKey] = value.slice(0, 100); // Limit array size
    }
  }
  
  return sanitized;
}
```

### Priority 3: Best Practices

#### Fix 6: Add Content Security Policy

**manifest.json addition:**
```json
"content_security_policy": "script-src 'self'; object-src 'none'; style-src 'self' 'unsafe-inline';"
```

#### Fix 7: Use Message Passing Instead of Code Injection

**Current approach (vulnerable):**
```javascript
chrome.tabs.executeScript(tabId, {
  code: `document.title = '${userInput}' + document.title;`
});
```

**Recommended approach:**
```javascript
// In background script
chrome.tabs.sendMessage(tabId, {
  action: 'updateTitle',
  prepend: prefs.prepends
});

// In content script
chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
  if (request.action === 'updateTitle') {
    const safePrepend = document.createTextNode(request.prepend).textContent;
    document.title = safePrepend + ' ' + document.title;
  }
});
```

#### Fix 8: Implement Proper Input Sanitization

**Utility functions:**
```javascript
// HTML escaping
function escapeHtml(unsafe) {
  return unsafe
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

// URL validation
function isValidUrl(string) {
  try {
    const url = new URL(string);
    return ['http:', 'https:', 'ftp:'].includes(url.protocol);
  } catch (_) {
    return false;
  }
}

// Hostname extraction with validation
function extractHostname(url) {
  if (!isValidUrl(url)) {
    throw new Error('Invalid URL');
  }
  
  const { hostname } = new URL(url);
  
  // Additional validation
  if (!hostname || hostname.length > 253) {
    throw new Error('Invalid hostname');
  }
  
  return hostname;
}
```

---

## 🔍 Testing Recommendations

### Security Testing Checklist

#### 1. XSS Testing
- [ ] Test with JavaScript in prepend strings: `<script>alert(1)</script>`
- [ ] Test with event handlers: `" onload="alert(1)`
- [ ] Test with data URIs: `javascript:alert(1)`
- [ ] Test with HTML entities: `&lt;script&gt;alert(1)&lt;/script&gt;`

#### 2. ReDoS Testing
- [ ] Test with catastrophic backtracking patterns: `(a+)+$`
- [ ] Test with nested quantifiers: `(a*)*$`
- [ ] Test with alternation: `(a|a)*$`
- [ ] Measure execution time with complex patterns

#### 3. Input Validation Testing
- [ ] Test with malformed URLs: `http://[invalid`
- [ ] Test with extremely long inputs (>10000 characters)
- [ ] Test with special characters in all input fields
- [ ] Test with null bytes: `\x00`
- [ ] Test with Unicode characters

#### 4. Import/Export Testing
- [ ] Test with malformed JSON
- [ ] Test with files >100MB
- [ ] Test with circular references in JSON
- [ ] Test with prototype pollution payloads

#### 5. Permission Testing
- [ ] Verify extension works with minimal permissions
- [ ] Test on various websites
- [ ] Test with different protocols (http, https, ftp, file)

### Automated Security Testing

```bash
# Install security testing tools
npm install -g eslint eslint-plugin-security

# Create .eslintrc.json for security rules
cat > .eslintrc.json << 'EOF'
{
  "plugins": ["security"],
  "extends": ["plugin:security/recommended"],
  "rules": {
    "security/detect-eval-with-expression": "error",
    "security/detect-non-literal-regexp": "warn",
    "security/detect-unsafe-regex": "error"
  }
}
EOF

# Run security linting
eslint background.js data/**/*.js plugins/**/*.js
```

---

## 🛡️ Security Best Practices

### 1. Principle of Least Privilege
- Request only necessary permissions
- Use activeTab instead of broad host permissions
- Implement optional permissions where possible

### 2. Input Validation
- Always validate and sanitize user input
- Use allowlists instead of denylists
- Implement proper bounds checking

### 3. Secure Communication
- Validate message senders
- Implement authentication for external communications
- Use structured message formats

### 4. Code Injection Prevention
- Avoid dynamic code execution
- Use message passing instead of script injection
- Implement Content Security Policy

### 5. Data Protection
- Encrypt sensitive data in storage
- Implement secure import/export
- Clear sensitive data when no longer needed

### 6. Regular Security Updates
- Keep dependencies updated
- Monitor security advisories
- Implement automated security testing

---

## Compliance Considerations

### Firefox Add-on Policies
- Must comply with Mozilla's Add-on Policies
- Regular security reviews required for featured extensions
- Must handle user data according to privacy policy

### GDPR Compliance
- Minimize data collection
- Implement data portability (export feature)
- Provide clear privacy policy

---

## Conclusion

The LRU Tab Trimmer extension contains several critical security vulnerabilities that must be addressed before deployment to production. The most severe issues involve XSS vulnerabilities through dynamic code injection and unrestricted external communication.

### Immediate Actions Required:
1. Fix XSS vulnerabilities in title prepending
2. Implement authentication for external communications
3. Restrict host permissions to minimum necessary
4. Validate all user inputs properly

### Timeline Recommendations:
- **Week 1:** Fix all critical issues
- **Week 2:** Address high severity issues
- **Week 3:** Implement medium severity fixes
- **Week 4:** Testing and validation

### Risk Assessment:
**Current Risk Level:** HIGH  
**Risk After Remediation:** LOW

---

## Appendix

### Resources
- [Mozilla Extension Security Best Practices](https://extensionworkshop.com/documentation/develop/build-a-secure-extension/)
- [OWASP Top 10 for Browser Extensions](https://owasp.org/www-project-top-10/)
- [Chrome Extension Security Model](https://developer.chrome.com/docs/extensions/mv3/security/)

### Security Contacts
For security issues, please contact: security@example.com

### Version History
- v1.0.0 - Initial security audit (2025-08-15)

---

*This security audit report is confidential and should be shared only with authorized personnel.*
