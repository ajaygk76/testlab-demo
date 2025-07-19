# Azure Users Ansible Playbook

This Ansible playbook retrieves the list of users from Microsoft Azure Active Directory and generates detailed reports.

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

### Run the Playbook

```bash
ansible-playbook azure-users-playbook.yml
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

The playbook generates:

1. **Console Output**: Displays user information in the terminal
2. **Markdown Report**: `azure_users_report_YYYY-MM-DD.md` - Human-readable report
3. **JSON File**: `azure_users_YYYY-MM-DD.json` - Machine-readable data

## Sample Output

### Console Output
```
Found 25 users in Azure AD:

User: John Doe
Email: john.doe@company.com
UPN: john.doe@company.com
Object ID: 12345678-1234-1234-1234-123456789012
Account Enabled: true
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
├── azure-users-playbook.yml    # Main playbook
├── requirements.yml            # Collection requirements
├── inventory.yml              # Inventory configuration
├── ansible.cfg                # Ansible configuration
└── README.md                  # This file
```

## Additional Features

The playbook includes:
- Error handling for missing users
- Multiple output formats (console, markdown, JSON)
- Timestamped report files
- Summary statistics
- Configurable authentication methods