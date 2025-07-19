# Azure Users Ansible Playbook

This Ansible playbook retrieves the list of users from Microsoft Azure Active Directory and generates detailed reports. It includes specific functionality to filter and report on users with 2FA (Multi-Factor Authentication) enabled.

## Prerequisites

1. **Ansible Installation**: Ensure Ansible is installed on your system
2. **Azure Service Principal**: You need a service principal with appropriate permissions
3. **Python Dependencies**: Install required Python packages

## Setup Instructions

### 1. Install Azure Collection

```bash
ansible-galaxy collection install -r requirements.yml
```

### 2. Install Python Dependencies

```bash
pip install azure-identity azure-mgmt-graphrbac msrest
```

### 3. Azure Service Principal Setup

You need to create a service principal in Azure with the following permissions:
- **Microsoft Graph API**: `User.Read.All` or `Directory.Read.All`
- **Azure Active Directory Graph**: `Directory.Read.All`

#### Create Service Principal using Azure CLI:

```bash
# Login to Azure
az login

# Create service principal
az ad sp create-for-rbac --name "ansible-azure-users" --role "Directory.Read.All"

# Note down the output values:
# - appId (client_id)
# - password (client_secret)
# - tenant (tenant_id)
# - subscriptionId (subscription_id)
```

### 4. Environment Variables

Set the following environment variables with your Azure credentials:

```bash
export AZURE_SUBSCRIPTION_ID="your-subscription-id"
export AZURE_TENANT_ID="your-tenant-id"
export AZURE_CLIENT_ID="your-client-id"
export AZURE_CLIENT_SECRET="your-client-secret"
```

Alternatively, you can modify the playbook variables directly in `azure-users-playbook.yml`.

## Usage

### Get All Users

```bash
ansible-playbook azure-users-playbook.yml
```

### Get Only 2FA Enabled Users (Collection Method)

```bash
ansible-playbook azure-users-playbook.yml
```

### Get Only 2FA Enabled Users (CLI Method - More Accurate)

```bash
ansible-playbook azure-2fa-users-cli-playbook.yml
```

### Reset User's 2FA Authentication

#### Using the Easy Script (Recommended):
```bash
# Dry run to check current status
./reset-user-2fa.sh hemanth.kumar2@sony.com gisc-in

# Actual 2FA reset
./reset-user-2fa.sh hemanth.kumar2@sony.com gisc-in --force
```

#### Using Ansible Playbook Directly:
```bash
# Dry run
ansible-playbook azure-reset-user-2fa-cli-playbook.yml

# Actual reset
ansible-playbook azure-reset-user-2fa-cli-playbook.yml -e "force_reset=true"
```

### Run with Verbose Output

```bash
ansible-playbook azure-users-playbook.yml -v
```

### Run with Custom Variables

```bash
ansible-playbook azure-users-playbook.yml \
  -e "subscription_id=your-subscription-id" \
  -e "tenant_id=your-tenant-id" \
  -e "client_id=your-client-id" \
  -e "client_secret=your-client-secret"
```

## Output

The playbooks generate:

### For All Users:
1. **Console Output**: Displays user information in the terminal
2. **Markdown Report**: `azure_users_report_YYYY-MM-DD.md` - Human-readable report
3. **JSON File**: `azure_users_YYYY-MM-DD.json` - Machine-readable data

### For 2FA Enabled Users Only:
1. **Console Output**: Displays only users with 2FA enabled
2. **Markdown Report**: `azure_2fa_users_report_YYYY-MM-DD.md` - 2FA users report
3. **JSON File**: `azure_2fa_users_YYYY-MM-DD.json` - 2FA users data
4. **CLI Method Reports**: `azure_2fa_users_cli_report_YYYY-MM-DD.md` and `azure_2fa_users_cli_YYYY-MM-DD.json`

## Sample Output

### Console Output (All Users)
```
Found 25 users in Azure AD:

User: John Doe
Email: john.doe@company.com
UPN: john.doe@company.com
Object ID: 12345678-1234-1234-1234-123456789012
Account Enabled: true
---
```

### Console Output (2FA Enabled Users Only)
```
Found 15 users with 2FA enabled out of 25 total users:

User: John Doe
Email: john.doe@company.com
UPN: john.doe@company.com
Object ID: 12345678-1234-1234-1234-123456789012
Account Enabled: true
MFA Methods: 2
---
```

### Markdown Report
```markdown
# Azure AD Users Report
Generated on: 2024-01-15T10:30:00Z
Total Users: 25

## User 1
- Display Name: John Doe
- Email: john.doe@company.com
- User Principal Name: john.doe@company.com
- Object ID: 12345678-1234-1234-1234-123456789012
- Account Enabled: true
- User Type: Member
- Creation Date: 2023-01-15T10:30:00Z
```

## Troubleshooting

### Common Issues

1. **Authentication Error**: Ensure your service principal has the correct permissions
2. **Collection Not Found**: Run `ansible-galaxy collection install -r requirements.yml`
3. **Python Module Error**: Install required Python packages

### Debug Mode

Run with debug information:

```bash
ansible-playbook azure-users-playbook.yml -vvv
```

## Security Notes

- Never commit credentials to version control
- Use environment variables or Azure Key Vault for secrets
- Regularly rotate service principal credentials
- Follow the principle of least privilege for permissions

## File Structure

```
.
├── azure-users-playbook.yml                    # Main playbook (all users + 2FA filter)
├── azure-2fa-users-cli-playbook.yml            # CLI-based 2FA users playbook
├── azure-reset-user-2fa-playbook.yml           # 2FA reset playbook (collection method)
├── azure-reset-user-2fa-cli-playbook.yml       # 2FA reset playbook (CLI method)
├── reset-user-2fa.sh                           # Easy-to-use 2FA reset script
├── requirements.yml                            # Collection requirements
├── inventory.yml                              # Inventory configuration
├── ansible.cfg                                # Ansible configuration
├── setup.sh                                   # Setup script
└── README.md                                  # This file
```

## Additional Features

The playbooks include:
- **2FA Detection**: Filter users with Multi-Factor Authentication enabled
- **2FA Reset**: Find users in specific groups and reset their 2FA authentication
- **Multiple Methods**: Both Azure collection and CLI-based approaches
- **Error handling**: For missing users, groups, and authentication issues
- **Multiple output formats**: Console, markdown, and JSON reports
- **Timestamped report files**: Each run creates dated reports
- **Summary statistics**: Including 2FA adoption rate
- **Configurable authentication**: Service principal and environment variables
- **MFA Method Details**: Shows authentication methods for each user
- **Dry Run Mode**: Safe preview of operations before execution
- **Easy-to-use Script**: Simple command-line interface for 2FA reset operations