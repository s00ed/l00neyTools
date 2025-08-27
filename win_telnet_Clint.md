# Guide to Enable Telnet Client in Windows 10

## Step 1: Run Command Prompt as Administrator

1. Press `Windows + S` and type `cmd`.
2. Right-click **Command Prompt** → choose **Run as administrator**.
3. Click **Yes** if prompted by User Account Control (UAC).

## Step 2: Install Telnet Client

In the elevated Command Prompt, type the following command and press Enter:

```
# DISM = Deployment Image Servicing and Management
dism /online /Enable-Feature /FeatureName:TelnetClient
```

Wait for the operation to complete.

## Step 3: Verify Telnet Installation

In the same Command Prompt, type:

```
telnet
```

If Telnet is installed correctly, you will see the Telnet prompt.

---

*Telnet Client is now enabled on your Windows 10 system.*
