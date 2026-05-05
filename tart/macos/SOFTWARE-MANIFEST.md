# Software Manifest

The MAUI Tart VM images include comprehensive software manifests available in human-readable and machine-readable formats, including industry-standard SBOM (Software Bill of Materials).

## Formats

### Markdown (Human-Readable)

**Location:** `/usr/local/share/installed-software.md`
**Symlink:** `~/installed-software.md`

Formatted markdown document with detailed descriptions, examples, and expandable sections. Perfect for viewing in a terminal or browser.

### JSON (Machine-Readable)

**Location:** `/usr/local/share/installed-software.json`
**Symlink:** `~/installed-software.json`

Structured JSON document with the same information in a queryable format. Perfect for automation, CI/CD scripts, and programmatic access.

### SPDX 2.3 (Software Bill of Materials)

**Location:** `/usr/local/share/installed-software.spdx.json`
**Symlink:** `~/installed-software.spdx.json`

Industry-standard Software Bill of Materials (SBOM) in SPDX 2.3 format. SPDX is ISO-certified (ISO/IEC 5962:2021) and widely used for supply chain security, compliance, and vulnerability tracking. Compatible with SBOM analysis tools and security platforms.

### CycloneDX 1.6 (Software Bill of Materials)

**Location:** `/usr/local/share/installed-software.cdx.json`
**Symlink:** `~/installed-software.cdx.json`

Industry-standard Software Bill of Materials (SBOM) in CycloneDX 1.6 format. CycloneDX is an OWASP project ratified as ECMA-424 and designed with a security-first approach. Lightweight format optimized for DevSecOps workflows, vulnerability management, and VEX (Vulnerability Exploitability eXchange) support.

All formats contain the same software inventory information - choose based on your use case and tooling requirements.

## Contents

The manifest includes detailed information about:

### System Information
- macOS version and build number
- Kernel version
- Architecture (arm64/x86_64)
- Image build date

### Development Tools
- **Xcode**: All installed versions, SDKs, and simulators
- **.NET**: SDK versions, runtimes, workloads, and global tools
- **Android**: SDK platforms, build tools, and NDK versions
- **Languages**: Node.js, Python, Ruby, Java versions
- **Package Managers**: Homebrew, npm, gem, CocoaPods
- **Utilities**: Git, curl, wget, jq, gh, cmake, fastlane, etc.

### Environment Variables
Standard paths and configuration for:
- DOTNET_ROOT
- ANDROID_HOME / ANDROID_SDK_ROOT
- JAVA_HOME

### Build Information
- Base image details
- .NET channel and workload set version
- Xcode versions included
- Build date and configuration

## Viewing the Manifest

### Inside a Running VM

```bash
# SSH into the VM
ssh admin@$(tart ip maui-dev-tahoe-dotnet10.0)

# View the markdown manifest (easy path in home directory)
cat ~/installed-software.md
less ~/installed-software.md

# View the JSON manifest
cat ~/installed-software.json | jq .

# View the SPDX SBOM
cat ~/installed-software.spdx.json | jq .

# View the CycloneDX SBOM
cat ~/installed-software.cdx.json | jq .

# Or use the full paths
cat /usr/local/share/installed-software.md
cat /usr/local/share/installed-software.json
cat /usr/local/share/installed-software.spdx.json
cat /usr/local/share/installed-software.cdx.json
```

### From the Host

```bash
# Start VM and get IP
tart run maui-dev-tahoe-dotnet10.0 &
sleep 10
VM_IP=$(tart ip maui-dev-tahoe-dotnet10.0)

# Copy manifests to host (using convenient home directory paths)
scp admin@${VM_IP}:installed-software.md ./
scp admin@${VM_IP}:installed-software.json ./
scp admin@${VM_IP}:installed-software.spdx.json ./
scp admin@${VM_IP}:installed-software.cdx.json ./

# View locally
cat installed-software.md
jq . installed-software.json
jq . installed-software.spdx.json
jq . installed-software.cdx.json
```

### Extract from Image Without Running

```bash
# Clone the image if not already local
tart clone ghcr.io/maui-containers/maui-macos:tahoe-dotnet10.0 maui-dev-tahoe-dotnet10.0

# Mount the image filesystem (requires root)
# Note: This is advanced usage and may vary by macOS version
```

## Format

The manifest follows a predictable markdown structure:

1. **Operating System** - Version and build info
2. **Xcode** - All versions and SDKs
3. **.NET** - SDKs, runtimes, workloads
4. **Android** - SDK components
5. **Languages and Runtimes** - Version list
6. **Package Managers** - Installed managers and versions
7. **Development Tools** - Utilities and CLI tools
8. **Homebrew Packages** - Complete list (expandable section)
9. **iOS Simulators** - Available device types (expandable section)
10. **Environment Variables** - Standard paths
11. **Build Information** - Detailed build metadata (expandable section)

## Use Cases

### Verify Tool Availability

**Using Markdown:**
```bash
ssh admin@$(tart ip maui-dev-tahoe-dotnet10.0) \
  "grep -A 5 'Node.js' ~/installed-software.md"
```

**Using JSON:**
```bash
ssh admin@$(tart ip maui-dev-tahoe-dotnet10.0) \
  "jq '.languages.node' ~/installed-software.json"
```

### Troubleshooting

**Using Markdown:**
```bash
ssh admin@$(tart ip maui-dev-tahoe-dotnet10.0) \
  "grep -A 20 '## .NET' ~/installed-software.md"
```

**Using JSON:**
```bash
ssh admin@$(tart ip maui-dev-tahoe-dotnet10.0) \
  "jq '.dotnet' ~/installed-software.json"
```

### Programmatic Queries

The JSON format is ideal for automation:

```bash
# Check if a specific .NET workload is installed
ssh admin@$(tart ip maui-dev-tahoe-dotnet10.0) \
  "jq '.dotnet.workloads | contains([\"maui\"])' ~/installed-software.json"

# Get all installed Xcode versions
ssh admin@$(tart ip maui-dev-tahoe-dotnet10.0) \
  "jq -r '.xcode.installedVersions[]' ~/installed-software.json"

# Find a specific Homebrew package
ssh admin@$(tart ip maui-dev-tahoe-dotnet10.0) \
  "jq '.homebrewPackages[] | select(.name == \"git\")' ~/installed-software.json"

# Check minimum tool version requirements
ssh admin@$(tart ip maui-dev-tahoe-dotnet10.0) \
  'jq -r ".languages.node" ~/installed-software.json | \
   awk -F. "{if (\$1 >= 18) print \"OK\"; else print \"Version too old\"}"'
```

### Documentation
Reference the manifest in your project documentation to specify required VM image versions.

### Auditing
Track what software is included in each image version for compliance or security auditing.

### SBOM Analysis and Supply Chain Security

Both SPDX and CycloneDX formats enable integration with industry-standard SBOM analysis tools:

**SPDX Examples:**
```bash
# Query specific packages from SPDX
ssh admin@$(tart ip maui-dev-tahoe-dotnet10.0) \
  "jq '.packages[] | select(.name == \"dotnet-sdk\")' ~/installed-software.spdx.json"

# List all packages with their suppliers
ssh admin@$(tart ip maui-dev-tahoe-dotnet10.0) \
  "jq -r '.packages[] | \"\(.name) - \(.versionInfo) (\(.supplier))\"' ~/installed-software.spdx.json"

# Extract package relationships
ssh admin@$(tart ip maui-dev-tahoe-dotnet10.0) \
  "jq '.relationships' ~/installed-software.spdx.json"

# Validate SPDX document structure
ssh admin@$(tart ip maui-dev-tahoe-dotnet10.0) \
  "jq '{spdxVersion, documentNamespace, packages: (.packages | length), relationships: (.relationships | length)}' ~/installed-software.spdx.json"
```

**CycloneDX Examples:**
```bash
# Query specific components from CycloneDX
ssh admin@$(tart ip maui-dev-tahoe-dotnet10.0) \
  "jq '.components[] | select(.name == \"dotnet-sdk\")' ~/installed-software.cdx.json"

# List all components by type
ssh admin@$(tart ip maui-dev-tahoe-dotnet10.0) \
  "jq -r '.components[] | \"\(.type): \(.name)@\(.version)\"' ~/installed-software.cdx.json"

# Extract components with Package URLs (PURL)
ssh admin@$(tart ip maui-dev-tahoe-dotnet10.0) \
  "jq -r '.components[] | \"\(.\"bom-ref\")\"' ~/installed-software.cdx.json"

# Validate CycloneDX document structure
ssh admin@$(tart ip maui-dev-tahoe-dotnet10.0) \
  "jq '{bomFormat, specVersion, serialNumber, components: (.components | length)}' ~/installed-software.cdx.json"

# Filter by component type (e.g., frameworks only)
ssh admin@$(tart ip maui-dev-tahoe-dotnet10.0) \
  "jq '.components[] | select(.type == \"framework\")' ~/installed-software.cdx.json"
```

**Integration with Security Tools:**
- Import into vulnerability scanners supporting SPDX or CycloneDX
- Track dependencies for security compliance
- Generate software supply chain reports
- Meet regulatory requirements (e.g., Executive Order 14028)
- Integrate with SBOM management platforms
- Use with VEX (Vulnerability Exploitability eXchange) for CycloneDX

**Example: Extract for compliance reporting**
```bash
# Copy both SBOM formats for compliance archive
scp admin@$(tart ip maui-dev-tahoe-dotnet10.0):installed-software.spdx.json \
  ./compliance/sbom-maui-dev-$(date +%Y%m%d).spdx.json
scp admin@$(tart ip maui-dev-tahoe-dotnet10.0):installed-software.cdx.json \
  ./compliance/sbom-maui-dev-$(date +%Y%m%d).cdx.json
```

## JSON Structure

The JSON manifest follows this schema:

```json
{
  "manifestVersion": "1.0",
  "imageType": "maui-development",
  "generatedAt": "2025-01-05T12:00:00Z",
  "operatingSystem": {
    "productVersion": "16.0",
    "buildVersion": "25A123",
    "kernelVersion": "25.0.0",
    "architecture": "arm64"
  },
  "xcode": {
    "defaultVersion": "26.0",
    "defaultBuild": "26A123",
    "installedVersions": ["26.0", "16.4"],
    "sdks": ["iphoneos18.0", "macosx16.0", "appletvos18.0"]
  },
  "dotnet": {
    "version": "10.0.100",
    "sdks": [{"version": "10.0.100", "path": "..."}],
    "runtimes": [{"name": "Microsoft.NETCore.App", "version": "10.0.0"}],
    "workloads": ["maui", "wasm-tools"],
    "globalTools": [{"name": "AndroidSdk.Tool", "version": "1.0.0"}]
  },
  "android": {
    "sdkRoot": "/Users/admin/Library/Android/sdk",
    "platforms": ["platforms;android-35", "platforms;android-34"],
    "buildTools": ["build-tools;35.0.0", "build-tools;34.0.0"]
  },
  "languages": {
    "node": "20.11.0",
    "npm": "10.2.4",
    "python": "3.12.1",
    "ruby": "3.3.0",
    "java": "21.0.x",
    "git": "2.43.0"
  },
  "packageManagers": {
    "homebrew": "4.2.0",
    "gem": "3.5.3",
    "cocoapods": "1.15.0"
  },
  "tools": {
    "curl": "8.5.0",
    "jq": "1.7.1",
    "gh": "2.42.0"
  },
  "homebrewPackages": [
    {"name": "git", "version": "2.43.0"},
    {"name": "node", "version": "20.11.0"}
  ],
  "environmentVariables": {
    "DOTNET_ROOT": "/Users/admin/.dotnet",
    "ANDROID_HOME": "~/Library/Android/sdk"
  },
  "buildInfo": { /* contents of build-info.json */ }
}
```

## SPDX Structure

The SPDX 2.3 SBOM follows the ISO/IEC 5962:2021 standard with this structure:

```json
{
  "spdxVersion": "SPDX-2.3",
  "dataLicense": "CC0-1.0",
  "SPDXID": "SPDXRef-DOCUMENT",
  "name": "maui-dev-tahoe-dotnet10.0",
  "documentNamespace": "https://github.com/maui-containers/maui-docker/spdx/...",
  "creationInfo": {
    "created": "2025-01-06T12:00:00Z",
    "creators": [
      "Tool: maui-docker-manifest-generator",
      "Organization: MAUI Development Environment"
    ]
  },
  "packages": [
    {
      "SPDXID": "SPDXRef-Package-macOS",
      "name": "macOS",
      "versionInfo": "16.0",
      "supplier": "Organization: Apple Inc.",
      "downloadLocation": "NOASSERTION",
      "filesAnalyzed": false,
      "licenseConcluded": "NOASSERTION",
      "licenseDeclared": "NOASSERTION",
      "copyrightText": "NOASSERTION"
    },
    {
      "SPDXID": "SPDXRef-Package-dotnet-sdk",
      "name": "dotnet-sdk",
      "versionInfo": "10.0.100",
      "supplier": "Organization: Microsoft Corporation",
      "downloadLocation": "https://dot.net/"
    }
  ],
  "relationships": [
    {
      "spdxElementId": "SPDXRef-DOCUMENT",
      "relationshipType": "DESCRIBES",
      "relatedSpdxElement": "SPDXRef-Package-macOS"
    },
    {
      "spdxElementId": "SPDXRef-Package-macOS",
      "relationshipType": "CONTAINS",
      "relatedSpdxElement": "SPDXRef-Package-dotnet-sdk"
    }
  ]
}
```

**Key SPDX Fields:**
- `spdxVersion`: Format version (SPDX-2.3)
- `SPDXID`: Unique identifier for each element
- `documentNamespace`: Globally unique URI for this SBOM
- `packages`: Array of software components with version and supplier info
- `relationships`: Describes how packages relate (DESCRIBES, CONTAINS, etc.)

**SPDX Relationships:**
- `DESCRIBES`: Document describes the root package (macOS)
- `CONTAINS`: Root package contains all installed software components

## CycloneDX Structure

The CycloneDX 1.6 SBOM follows the ECMA-424 standard with this structure:

```json
{
  "$schema": "http://cyclonedx.org/schema/bom-1.6.schema.json",
  "bomFormat": "CycloneDX",
  "specVersion": "1.6",
  "serialNumber": "urn:uuid:...",
  "version": 1,
  "metadata": {
    "timestamp": "2025-01-06T12:00:00Z",
    "tools": [
      {
        "vendor": "MAUI Development Environment",
        "name": "maui-docker-manifest-generator",
        "version": "1.0"
      }
    ],
    "component": {
      "type": "container",
      "bom-ref": "pkg:oci/maui-dev-tahoe-dotnet10.0@10.0",
      "name": "maui-dev-tahoe-dotnet10.0",
      "version": "10.0",
      "description": "MAUI development environment..."
    }
  },
  "components": [
    {
      "type": "operating-system",
      "bom-ref": "pkg:generic/macos@16.0",
      "name": "macOS",
      "version": "16.0",
      "supplier": {
        "name": "Apple Inc."
      },
      "description": "macOS 16.0 build 25A123, architecture arm64"
    },
    {
      "type": "framework",
      "bom-ref": "pkg:nuget/Microsoft.NET.Sdk@10.0.100",
      "name": "dotnet-sdk",
      "version": "10.0.100",
      "supplier": {
        "name": "Microsoft Corporation"
      },
      "description": ".NET SDK"
    }
  ],
  "dependencies": [
    {
      "ref": "pkg:oci/maui-dev-tahoe-dotnet10.0@10.0",
      "dependsOn": [
        "pkg:generic/macos@16.0"
      ]
    }
  ]
}
```

**Key CycloneDX Fields:**
- `bomFormat`: Always "CycloneDX"
- `specVersion`: Format version (1.6)
- `serialNumber`: Unique URN identifier for this BOM instance
- `bom-ref`: Package URL (PURL) identifiers for each component
- `components`: Array of software components with type classification
- `dependencies`: Explicit dependency relationships

**CycloneDX Component Types:**
- `operating-system`: macOS base system
- `application`: Standalone applications (Xcode, Node.js, tools)
- `framework`: .NET SDK, workloads, Android platforms
- `library`: Reusable libraries and build tools
- `container`: The VM image itself (in metadata)

**Package URL (PURL) Examples:**
- `pkg:oci/maui-dev-tahoe-dotnet10.0@10.0` - OCI container image
- `pkg:nuget/Microsoft.NET.Sdk@10.0.100` - NuGet package
- `pkg:generic/xcode@26.0` - Generic package
- `pkg:generic/android-platform@35` - Android component

## Comparison with GitHub Actions

Like GitHub's hosted runners, our manifests provide:
- ✅ Complete software inventory
- ✅ Version information for all tools
- ✅ Environment variable documentation
- ✅ Machine-readable JSON format
- ✅ Build date and base image tracking

Unlike GitHub's runners:
- Our manifests are generated inside the VM (not in a separate repository)
- We provide four formats: markdown, JSON, SPDX SBOM, and CycloneDX SBOM
- Dual industry-standard SBOM formats (SPDX 2.3 and CycloneDX 1.6) for supply chain security
- We focus on MAUI/.NET development tools
- We include Tart/VM-specific information

## Standard Compliance

The manifests follow multiple industry standards:

- **Readable inventory**: Markdown and JSON formats provide a stable inventory of installed tools and versions
- **SPDX 2.3 / ISO/IEC 5962:2021**: ISO-certified Software Bill of Materials format, ideal for compliance-focused organizations and government requirements
- **CycloneDX 1.6 / ECMA-424**: OWASP/ECMA-standardized SBOM format, optimized for DevSecOps workflows and security tooling
- **Supply Chain Security**: Meets requirements for software transparency (e.g., US Executive Order 14028)
- **Dual SBOM Support**: Both leading SBOM standards supported for maximum compatibility with security tools and platforms

## Generating Updated Manifests

The manifests are automatically generated during image builds. To manually regenerate:

```bash
# Inside the VM - Generate all four formats
/tmp/generate-software-manifest.sh /usr/local/share/installed-software.md
/tmp/generate-software-manifest.json.sh /usr/local/share/installed-software.json
/tmp/generate-software-manifest-spdx.sh /usr/local/share/installed-software.json /usr/local/share/installed-software.spdx.json
/tmp/generate-software-manifest-cyclonedx.sh /usr/local/share/installed-software.json /usr/local/share/installed-software.cdx.json
```

The generation scripts are located at:
- Build-time:
  - `macos/tart/scripts/generate-software-manifest.sh` (Markdown)
  - `macos/tart/scripts/generate-software-manifest.json.sh` (JSON)
  - `macos/tart/scripts/generate-software-manifest-spdx.sh` (SPDX 2.3)
  - `macos/tart/scripts/generate-software-manifest-cyclonedx.sh` (CycloneDX 1.6)
- Runtime: Available in VM at `/tmp/` during provisioning

## Related Files

- **Software Manifest (Markdown)**: `/usr/local/share/installed-software.md` (symlink: `~/installed-software.md`)
- **Software Manifest (JSON)**: `/usr/local/share/installed-software.json` (symlink: `~/installed-software.json`)
- **Software Manifest (SPDX 2.3)**: `/usr/local/share/installed-software.spdx.json` (symlink: `~/installed-software.spdx.json`)
- **Software Manifest (CycloneDX 1.6)**: `/usr/local/share/installed-software.cdx.json` (symlink: `~/installed-software.cdx.json`)
- **Build Info**: `/usr/local/share/build-info.json` (machine-readable JSON)

## Contributing

If you notice missing information in the manifest or have suggestions for additional sections, please open an issue or pull request in the repository.
