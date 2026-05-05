# PR Validation Workflow

This document explains how the PR validation workflow works and how to use it effectively.

## Overview

The PR validation workflow (`.github/workflows/pr-validation.yml`) automatically runs on pull requests to validate Docker image builds without publishing them. This ensures that PRs don't break the build system before being merged.

## When It Runs

The workflow triggers automatically on:
- Pull requests targeting the `main` branch
- Changes to relevant files:
  - `base/**` - Base image files
  - `test/**` - Test image files
  - `common-functions.ps1` - Workload management functions
  - `.github/workflows/**` - Workflow files

You can also run it manually using the `workflow_dispatch` trigger.

## What It Does

### 1. Workload Discovery Validation 🔍
- Tests that workload sets can be discovered for all .NET versions
- Validates that Android SDK requirements are properly extracted
- Shows detailed workload information in the job summary
- **Fails fast** if workload discovery is broken (no point building images)

### 2. Docker Image Builds 🔨
- Builds Docker images locally (never pushes to registry)
- Supports three test modes:
  - **`single-platform`**: Fastest - builds one .NET version on Linux base only
  - **`base-only`**: Medium - builds base images for all .NET versions and platforms
  - **`all`**: Comprehensive - builds base and test images (slower)
- Runs builds in parallel with resource limits to avoid overloading build hosts

### 3. Image Validation Tests 🧪
- **Base Images**: Tests .NET version, MAUI workloads, PowerShell, Android SDK, Java
- **Test Images**: Checks Appium, Android Emulator, and system images

### 4. Summary Report 📋
- Provides clear pass/fail status for the entire PR
- Details what was tested and any issues found
- Confirms no images were published

## Manual Execution

You can manually run the validation with different options:

1. Go to **Actions** → **PR Validation - Build Docker Images**
2. Click **Run workflow**
3. Configure options:
   - **dotnet_versions**: JSON array like `["9.0", "10.0"]`
   - **test_subset**: Choose validation depth:
     - `single-platform` - Quick test (5-10 minutes)
     - `base-only` - Medium test (15-30 minutes) 
     - `all` - Full test (45-90 minutes)

## Understanding Results

### ✅ Success Indicators
- **Workload Discovery**: All .NET versions found valid workload sets
- **Image Builds**: All Docker images built successfully and loaded locally
- **Validation Tests**: Key functionality verified in each image type
- **Overall Status**: "PR validation passed! This PR is ready for review."

### ❌ Failure Indicators
- **Workload Discovery Failed**: Issue with .NET workload resolution
- **Build Failed**: Docker build errors or missing dependencies
- **Validation Failed**: Built image missing expected functionality
- **Overall Status**: "PR validation failed - Please fix issues before merging."

## Performance Considerations

- **Windows builds** are slower than Linux builds
- **Test images** take longest due to Android Emulator setup
- **Parallel builds** are limited to 4 concurrent jobs
- Use **`base-only`** mode for most PRs unless testing test image changes

## Troubleshooting

### Common Issues

1. **"No workload sets found"**
   - Check if .NET version is properly supported
   - Verify prerelease auto-detection logic in `common-functions.ps1`

2. **"Image not found after build"**
   - Docker build succeeded but image wasn't properly tagged
   - Check build script parameters and image naming logic

3. **"MAUI workload may not be installed"**
   - Workload installation failed during image build
   - Check workload installation steps in Dockerfile

### Getting Help

- Check the **Actions** tab for detailed logs from each job
- Look at the **Job Summary** for high-level status
- Individual validation steps show specific test results
- Compare working builds with failing ones to identify changes

## Best Practices

1. **For small changes**: Use `single-platform` or `base-only` mode
2. **For major changes**: Use `all` mode to test everything
3. **Before requesting review**: Ensure PR validation passes
4. **When debugging**: Check individual job logs, not just the summary
5. **For workload changes**: Pay special attention to workload discovery results

This validation ensures that your changes won't break the production build system while providing fast feedback during development.
