# Team Collaboration Guide - PetClinic AKS Deployment

## 📤 Sharing This Branch

### Branch Information

- **Branch Name**: `feature/mcp-aks-complete-deployment`
- **Repository**: `cloud-sre-demo-applications`
- **Azure DevOps Project**: `SRE_Demo_Assets`

### 🔗 Quick Links

**Browse Branch in Azure DevOps:**
```
https://dev.azure.com/arul-moorthy/SRE_Demo_Assets/_git/cloud-sre-demo-applications?version=GBfeature/mcp-aks-complete-deployment
```

**Repository URL:**
```
https://dev.azure.com/arul-moorthy/SRE_Demo_Assets/_git/cloud-sre-demo-applications
```

---

## 👥 For Team Members

### Option 1: Clone Repository and Checkout Branch

If you don't have the repository yet:

```powershell
# Clone the repository
git clone https://arul-moorthy@dev.azure.com/arul-moorthy/SRE_Demo_Assets/_git/cloud-sre-demo-applications

# Navigate to the project
cd cloud-sre-demo-applications/spring-petclinic-microservices

# Checkout the feature branch
git checkout feature/mcp-aks-complete-deployment

# Verify you're on the correct branch
git branch --show-current
```

### Option 2: Fetch and Checkout (If Repository Already Cloned)

If you already have the repository:

```powershell
# Navigate to repository
cd path\to\cloud-sre-demo-applications

# Fetch latest changes
git fetch origin

# Checkout the feature branch
git checkout feature/mcp-aks-complete-deployment

# Pull latest changes
git pull origin feature/mcp-aks-complete-deployment

# Verify
git branch --show-current
```

### Option 3: Download as ZIP

1. Go to Azure DevOps web URL (link above)
2. Click on the **"..."** menu (top right)
3. Select **"Download as Zip"**
4. Extract and use

---

## 🚀 Getting Started After Checkout

### 1. Verify Files

After checking out the branch, you should see:

```powershell
# List essential files
Get-ChildItem | Where-Object { $_.Name -match "deploy-complete|EXECUTION|README|DEPLOYMENT-SUMMARY" }
```

**Expected files:**
- ✅ `deploy-complete-azure-infrastructure.ps1`
- ✅ `EXECUTION-STEPS.md`
- ✅ `COMPLETE-INFRASTRUCTURE-DEPLOYMENT-README.md`
- ✅ `PETCLINIC-DEPLOYMENT-SUMMARY.md`
- ✅ `k8s/petclinic-with-monitoring.yaml`
- ✅ `k8s/mcp-servers.yaml`

### 2. Read Documentation

**Start Here:**
```powershell
code EXECUTION-STEPS.md
```

This file contains:
- Prerequisites checklist
- Step-by-step deployment instructions
- Verification procedures
- Troubleshooting guide

**Comprehensive Guide:**
```powershell
code COMPLETE-INFRASTRUCTURE-DEPLOYMENT-README.md
```

### 3. Run Deployment

```powershell
# Navigate to project directory
cd spring-petclinic-microservices

# Review the script first
code deploy-complete-azure-infrastructure.ps1

# Run deployment with defaults
.\deploy-complete-azure-infrastructure.ps1

# OR with custom configuration
.\deploy-complete-azure-infrastructure.ps1 `
    -ResourceGroupName "your-rg-name" `
    -AcrName "youracr123" `
    -Location "eastus"
```

---

## 📧 Sharing Instructions

### Email Template

```
Subject: PetClinic on AKS - Complete Deployment Solution

Hi Team,

I've completed the automated deployment solution for PetClinic on Azure Kubernetes Service. 
The code is ready in a feature branch for your review and use.

🔗 Branch URL:
https://dev.azure.com/arul-moorthy/SRE_Demo_Assets/_git/cloud-sre-demo-applications?version=GBfeature/mcp-aks-complete-deployment

📋 Branch Name: feature/mcp-aks-complete-deployment

🎯 What's Included:
- Single PowerShell script for complete infrastructure deployment
- Deploys Azure resources (ACR, AKS, PostgreSQL)
- Deploys PetClinic with 7 microservices
- Deploys observability stack (Prometheus, Grafana, Loki, Tempo)
- Deploys 3 MCP servers for AI integration
- Complete documentation with step-by-step guides

⏱️ Deployment Time: 30-50 minutes (fully automated)

📖 Getting Started:
1. Clone/checkout the branch (see TEAM-SHARING-GUIDE.md)
2. Read EXECUTION-STEPS.md for quick start
3. Run: .\deploy-complete-azure-infrastructure.ps1

Let me know if you have any questions!

Best regards
```

### Teams/Slack Message

```
🚀 **PetClinic AKS Deployment - Ready for Review**

Branch: `feature/mcp-aks-complete-deployment`

🔗 https://dev.azure.com/arul-moorthy/SRE_Demo_Assets/_git/cloud-sre-demo-applications?version=GBfeature/mcp-aks-complete-deployment

✨ **Features:**
✅ Complete automated deployment (30-50 min)
✅ 7 microservices + observability + MCP servers
✅ Single command deployment
✅ Comprehensive documentation

📖 **Quick Start:**
```bash
git checkout feature/mcp-aks-complete-deployment
.\deploy-complete-azure-infrastructure.ps1
```

See `EXECUTION-STEPS.md` for details.
```

---

## 🔐 Access Permissions

### Ensure Team Has Access

Team members need:

1. **Azure DevOps Access**
   - Access to `arul-moorthy` organization
   - Access to `SRE_Demo_Assets` project
   - Read/Write permissions on repository

2. **Azure Subscription Access**
   - If they want to deploy, they need:
     - Contributor role on subscription
     - Or ability to create resource groups

### How to Grant Azure DevOps Access

#### Step 1: Add Users to Organization

1. **Navigate to Organization Settings:**
   ```
   https://dev.azure.com/arul-moorthy/_settings/users
   ```

2. **Click "Add users"**

3. **Enter user details:**
   - **Users or Service Principals**: Enter email addresses (comma-separated for multiple)
   - **Access Level**: 
     - **Basic** (recommended) - Full access to most features
     - **Stakeholder** - Limited access (read-only)
   - **Add to projects**: Select `SRE_Demo_Assets`
   - **Azure DevOps Groups**: Select appropriate group

4. **Click "Add"**

#### Step 2: Add Users to Project

1. **Navigate to Project Settings:**
   ```
   https://dev.azure.com/arul-moorthy/SRE_Demo_Assets/_settings/teams
   ```

2. **Select a team** (or create new team):
   - Click on team name (e.g., "SRE_Demo_Assets Team")
   - Click **"Add"** button

3. **Search and add users:**
   - Type user email or name
   - Click **"Save"**

#### Step 3: Set Repository Permissions

1. **Navigate to Repository Security:**
   ```
   https://dev.azure.com/arul-moorthy/SRE_Demo_Assets/_settings/repositories?repo=cloud-sre-demo-applications&_a=permissionsMid
   ```

2. **Add users/groups:**
   - Click **"Add"** → **"Add user or group"**
   - Search for user or team
   - Click **"Save changes"**

3. **Set permissions** (recommended for contributors):
   - ✅ **Read** - View repository and code
   - ✅ **Contribute** - Push commits, create branches
   - ✅ **Create Branch** - Create new branches
   - ✅ **Contribute to Pull Requests** - Create and approve PRs
   - ❌ **Force Push** - Usually not needed
   - ❌ **Manage Permissions** - Admin only

#### Step 4: Verify Access

Ask team members to:

```powershell
# Test access by listing repos
az repos list --organization https://dev.azure.com/arul-moorthy --project SRE_Demo_Assets

# Or try cloning
git clone https://dev.azure.com/arul-moorthy/SRE_Demo_Assets/_git/cloud-sre-demo-applications
```

### Permission Levels Explained

| Level | Can View | Can Clone | Can Push | Can Create PR | Can Approve PR | Can Manage |
|-------|----------|-----------|----------|---------------|----------------|------------|
| **Reader** | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| **Contributor** | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| **Build Admin** | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ Pipelines |
| **Project Admin** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

**Recommended:** Grant **Contributor** access for team members who will work on code.

### Using Azure CLI to Grant Access

Alternatively, use Azure CLI:

```powershell
# Add user to project team
az devops user add `
    --email-id "user@example.com" `
    --license-type basic `
    --organization https://dev.azure.com/arul-moorthy

# Add user to specific team
az devops team create `
    --name "PetClinic Team" `
    --organization https://dev.azure.com/arul-moorthy `
    --project SRE_Demo_Assets

az devops team member add `
    --email-id "user@example.com" `
    --team "PetClinic Team" `
    --organization https://dev.azure.com/arul-moorthy `
    --project SRE_Demo_Assets
```

### Troubleshooting Access Issues

**Issue: "Repository not found" when cloning**

✅ **Solutions:**
1. Verify user has been added to organization
2. Check project membership
3. Confirm repository permissions
4. Try authenticating: `git config --global credential.helper wincred`
5. Use personal access token (PAT) instead of password

**Issue: "Permission denied" when pushing**

✅ **Solutions:**
1. Verify **Contribute** permission is granted
2. Check if branch policies are blocking push
3. Ensure not pushing to protected branch (main)
4. Try creating feature branch first

**Create Personal Access Token (PAT):**

1. Go to: https://dev.azure.com/arul-moorthy/_usersSettings/tokens
2. Click **"New Token"**
3. Set name: "Git Access"
4. Set expiration: 90 days
5. Select scopes:
   - ✅ **Code** → Read & Write
   - ✅ **Build** → Read (optional)
6. Click **"Create"**
7. **Copy token** (won't be shown again!)
8. Use as password when cloning:
   ```powershell
   git clone https://<PAT>@dev.azure.com/arul-moorthy/SRE_Demo_Assets/_git/cloud-sre-demo-applications
   ```

### Quick Access Checklist

Send this to new team members:

```
✅ Access Checklist:

1. [ ] Received invite email from Azure DevOps
2. [ ] Accepted invitation
3. [ ] Can access: https://dev.azure.com/arul-moorthy/SRE_Demo_Assets
4. [ ] Can see repository: cloud-sre-demo-applications
5. [ ] Can clone repository
6. [ ] Can checkout feature branch: feature/mcp-aks-complete-deployment
7. [ ] Created personal access token (if needed)

If any step fails, contact repository admin.
```

---

## 📋 Code Review / Pull Request

### Create Pull Request for Review

If you want formal code review before merging to main:

**Via Azure DevOps Web:**

1. Go to branch URL (link above)
2. Click **"Create Pull Request"**
3. Fill in details:
   - **Title**: "feat: Complete automated Azure infrastructure deployment"
   - **Description**: 
     ```
     ## Summary
     Complete automated deployment solution for PetClinic on AKS
     
     ## Changes
     - Added single deployment script (deploy-complete-azure-infrastructure.ps1)
     - Added comprehensive documentation (3 guides)
     - Cleaned up 64 redundant files
     - Consolidated K8s manifests
     
     ## Impact
     - 30-50 minute end-to-end deployment
     - Production-ready solution
     - 92% code reduction
     
     ## Testing
     - Deployed successfully to AKS
     - All 19+ pods running
     - MCP servers operational
     
     ## Documentation
     - EXECUTION-STEPS.md - Quick start guide
     - COMPLETE-INFRASTRUCTURE-DEPLOYMENT-README.md - Full guide
     - PETCLINIC-DEPLOYMENT-SUMMARY.md - Architecture overview
     ```
4. Select reviewers
5. Click **"Create"**

**Via Git Command:**

```powershell
# This will open browser to create PR
az repos pr create `
    --repository cloud-sre-demo-applications `
    --source-branch feature/mcp-aks-complete-deployment `
    --target-branch main `
    --title "feat: Complete automated Azure infrastructure deployment" `
    --description "See EXECUTION-STEPS.md for details"
```

---

## 🤝 Collaboration Workflow

### For Team Members Working Together

**1. Keep Branch Updated**

```powershell
# Regularly pull latest changes
git checkout feature/mcp-aks-complete-deployment
git pull origin feature/mcp-aks-complete-deployment
```

**2. Make Changes**

```powershell
# Create a sub-branch for your work
git checkout -b feature/mcp-aks-complete-deployment-yourname

# Make changes, commit
git add .
git commit -m "feat: your changes"

# Push to remote
git push origin feature/mcp-aks-complete-deployment-yourname
```

**3. Merge Back**

```powershell
# Switch back to main feature branch
git checkout feature/mcp-aks-complete-deployment

# Merge your changes
git merge feature/mcp-aks-complete-deployment-yourname

# Push
git push origin feature/mcp-aks-complete-deployment
```

---

## 📊 Deployment Dashboard

After team members deploy, they can track:

### View All Deployments

```powershell
# List all resource groups (multiple team deployments)
az group list --query "[?starts_with(name, 'petclinic')].{Name:name, Location:location, Status:properties.provisioningState}" -o table
```

### Share Deployment Info

After running the deployment script, share the generated file:

```powershell
# Generated after deployment
cat deployment-info.json
```

Send this to team for access URLs.

---

## ✅ Checklist for Team Members

**Before Starting:**
- [ ] Clone/checkout the branch
- [ ] Read `EXECUTION-STEPS.md`
- [ ] Verify prerequisites (Azure CLI, kubectl, Docker, etc.)
- [ ] Ensure Azure subscription access

**During Deployment:**
- [ ] Run deployment script
- [ ] Monitor progress (30-50 minutes)
- [ ] Save `deployment-info.json`

**After Deployment:**
- [ ] Verify all pods running
- [ ] Access PetClinic and Grafana URLs
- [ ] Test MCP servers
- [ ] Share results with team

**Cleanup (When Done):**
- [ ] Delete resource group: `az group delete --name petclinic-rg`

---

## 🆘 Support

**For Questions:**
- Check `EXECUTION-STEPS.md` → Troubleshooting section
- Check `COMPLETE-INFRASTRUCTURE-DEPLOYMENT-README.md`
- Review pod logs: `kubectl logs <pod-name> -n petclinic`

**Common Issues:**
- ACR name must be globally unique
- AKS creation takes 10-15 minutes
- LoadBalancer IPs take 2-3 minutes to assign

---

## 📁 Key Files Reference

| File | Purpose |
|------|---------|
| `deploy-complete-azure-infrastructure.ps1` | Main deployment script |
| `EXECUTION-STEPS.md` | Quick start guide |
| `COMPLETE-INFRASTRUCTURE-DEPLOYMENT-README.md` | Comprehensive guide |
| `PETCLINIC-DEPLOYMENT-SUMMARY.md` | Architecture overview |
| `k8s/petclinic-with-monitoring.yaml` | Complete K8s manifest |
| `k8s/mcp-servers.yaml` | MCP servers manifest |
| `deployment-info.json` | Generated deployment details |

---

**Branch**: `feature/mcp-aks-complete-deployment`  
**Status**: ✅ Production Ready  
**Last Updated**: January 23, 2026  
**Total Deployment Time**: 30-50 minutes
