# Legal Documentation for FilmStock

## Overview
This document summarizes the legal documentation added to FilmStock for App Store submission.

## Files Created

### 1. Privacy Policy (`PrivacyPolicyView.swift`)
**Location:** `FilmStock/Views/PrivacyPolicyView.swift`

**Key Points:**
- ✅ States that NO data is collected or transmitted
- ✅ Explains local-only data storage
- ✅ Details camera usage (for film box photos)
- ✅ Describes in-app purchase handling (via Apple)
- ✅ Lists third-party services (only Apple: StoreKit, WidgetKit)
- ✅ No analytics, advertising, or tracking
- ✅ Data deletion instructions
- ✅ Contact information provided

**Access:** Available in About screen via "Privacy Policy" link

---

### 2. Terms of Service (`TermsOfServiceView.swift`)
**Location:** `FilmStock/Views/TermsOfServiceView.swift`

**Key Points:**
- ✅ License grant (personal, non-commercial use)
- ✅ App purpose and limitations
- ✅ User responsibilities
- ✅ Data backup disclaimer (user's responsibility)
- ✅ In-app purchase terms (non-refundable, support-only)
- ✅ Intellectual property protection
- ✅ Warranty disclaimer (AS IS)
- ✅ Limitation of liability
- ✅ Governing law (Norway)
- ✅ Contact information

**Access:** Available in About screen via "Terms of Service" link

---

## Copyright Updates

### Fixed Copyright Year: 2025 → 2024
**Reason:** App is being prepared in November 2024

**Files Updated:**
1. ✅ `FilmStock.xcodeproj/project.pbxproj` (2 locations)
2. ✅ `FilmStockWidget/Info.plist`
3. ✅ `AboutView.swift` (added copyright footer)

**Format:** `Copyright © 2024 Jonas Halbe. All rights reserved.`

---

## UI Integration

### AboutView Updates
**Location:** `FilmStock/Views/AboutView.swift`

**Added:**
1. NavigationLink to Privacy Policy
2. NavigationLink to Terms of Service
3. Copyright notice footer
4. All styled consistently with app design

**Appearance:**
```
Contact Button
    ↓
Privacy Policy (link)
Terms of Service (link)
    ↓
© 2024 Jonas Halbe. All rights reserved.
```

---

## App Store Compliance

### Privacy Policy - App Store Requirements ✅
- Clear explanation of data practices
- Camera usage justified
- No tracking or analytics
- Local data storage only
- Third-party services listed (Apple only)

### Terms of Service - Best Practices ✅
- License terms defined
- Liability limitations
- User responsibilities
- Refund policy (via Apple)
- Governing law specified

### Copyright ✅
- Current year (2024)
- Owner clearly stated
- Appears in app and project settings

---

## For App Store Connect

When submitting to App Store Connect, you can:

1. **Privacy Policy URL:** 
   - Option 1: Point to in-app view (not a URL, so use "View in App")
   - Option 2: Create a simple webpage at your domain hosting the same content
   - Option 3: Use GitHub Pages with the privacy policy

2. **Support URL:**
   - Use: `mailto:hello@halbe.no` or create a support page

3. **Marketing URL (optional):**
   - Not required for this app

---

## Notes

- All content is written in plain English
- Privacy policy emphasizes NO data collection (very favorable)
- Terms are fair and standard for this type of app
- No unreasonable restrictions or obligations
- Contact information consistently provided
- Compliant with Apple's App Store Review Guidelines

---

## Review Checklist

- [x] Privacy Policy created and accessible
- [x] Terms of Service created and accessible  
- [x] Copyright year corrected to 2024
- [x] Copyright appears in app
- [x] Copyright in project settings
- [x] Legal docs linked from About page
- [x] Contact information provided in all legal docs
- [x] No linter errors

---

Last updated: November 2024

