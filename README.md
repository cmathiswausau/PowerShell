# Password Expiry Notification Script (Refactored)

## Overview
This project is a refactored version of a PowerShell-based password expiration notification system for Active Directory.

The repository contains a mix of original scripts and third-party scripts. My work focuses specifically on improving the password expiry notification process by introducing configuration-driven design and enhancing maintainability.

---

## My Contributions

### Refactored Password Expiry Script
- Updated `PasswordExpiry.ps1` to remove hardcoded values
- Improved structure and readability
- Integrated external configuration support

---

### XML-Based Configuration (`settings.xml`)
- Introduced a centralized configuration file
- Organized into:
  - Variables
  - Settings
  - Email templates

**Configurable elements include:**
- SMTP settings
- Email sender details
- Password policy requirements
- Notification timing
- Testing mode

---

### HTML Email Templates
- Replaced plain-text emails with structured HTML templates
- Improved formatting and user readability
- Enabled easy customization without modifying script logic

---

### Testing Mode
- Added a configurable testing mode to safely validate behavior
- Prevents unintended notifications during development

---

### Improved Maintainability
- Separated configuration from script logic
- Reduced need for direct code changes across environments

---

## Important Note on Other Scripts

This repository also contains additional PowerShell scripts that were **not created by me**.

- These scripts are included as part of the broader project environment
- They were **not modified or authored** as part of this refactor effort
- My work is limited to the password expiry notification components

---

## File Structure
