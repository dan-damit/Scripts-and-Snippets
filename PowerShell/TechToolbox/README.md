# 🧰 TechToolbox  
A modular, technician‑grade PowerShell toolbox designed for automation, diagnostics, and environment‑agnostic workflows.

TechToolbox organizes your scripts into a clean, scalable module structure with dedicated folders for public commands, private helpers, and centralized configuration. Each tool lives in its own `.ps1` file, making the system easy to maintain, extend, and version over time.

---

## 📦 Module Structure

```
TechToolbox/
│   TechToolbox.psd1      # Module manifest (metadata, versioning)
│   TechToolbox.psm1      # Module loader (imports functions & config)
│
├── Public/               # User-facing commands (exported)
│     <FunctionName>.ps1
│
├── Private/              # Internal helpers (not exported)
│     <HelperName>.ps1
│
└── Config/               # Environment-agnostic configuration
      config.json
```

### **Public**
Contains all functions intended to be called directly by the user.  
Each file contains exactly one function.

### **Private**
Contains internal helper functions used by the public commands.  
These are automatically loaded but not exported.

### **Config**
Holds JSON configuration files that the module loads once at import time.

---

## 🚀 Getting Started

### **Import the module**

```powershell
Import-Module .\TechToolbox
```

### **List available commands**

```powershell
Get-Command -Module TechToolbox
```

### **View help for a command**

```powershell
Get-Help <FunctionName> -Full
```

---

## 🛠 Adding New Tools

1. Create a new `.ps1` file in `Public` (or `Private` if it’s a helper).  
2. Add a single function to the file.  
3. Include comment-based help for clarity.  
4. Reload the module:

```powershell
Import-Module .\TechToolbox -Force
```

The module loader automatically imports all functions — no need to modify the `.psm1`.

---

## 🧩 Versioning

The module version is defined in `TechToolbox.psd1`.  
Increment the version whenever you add or refine tools.

---

## 📄 License

TBD if sharing the module.
