# Runbook: Safely Uninstall Local Paperclip (MacBook)

Execution record:

- [Local Paperclip Removal Record](local-paperclip-removal-record.md)

## Context
During the initial diagnostic and setup phases, `npx paperclipai` and `npx companies.sh` were executed locally on the MacBook. This inadvertently spun up a local development instance of Paperclip (running on port `3100`), complete with its own embedded PostgreSQL database, configuration files, and background Node.js processes. 

To prevent port conflicts, save local resources, and ensure all AI management is properly routed to the "Sovereign AI" Proxmox host (`192.168.1.30`), this local instance must be completely removed.

## Dependencies & Footprint
The local Paperclip instance leaves traces in three main areas on your Mac:
1.  **Active Processes:** Node.js server threads and an embedded PostgreSQL cluster.
2.  **State Directory:** `~/.paperclip/` (Contains the database, local logs, secrets, and configuration).
3.  **NPM Cache:** Downloaded executable packages inside the hidden `~/.npm/_npx/` folder.

---

## Step-by-Step Removal Instructions

### Step 1: Stop All Local Paperclip Processes
Before deleting any files, we must terminate the background processes to avoid database corruption or zombie ports.

Open your local MacBook terminal and run:
```bash
# Kill any processes matching the name 'paperclip'
pkill -9 -f paperclip

# Specifically target the embedded postgres instance spawned by Paperclip
pkill -9 -f embedded-postgres/darwin-arm64
```
*Verification:* Run `ps aux | grep -i paperclip`. You should only see the `grep` command itself returned.

### Step 2: Delete the Paperclip State Directory
This is the most critical step. This directory holds the local embedded database and the `mcp.json` we temporarily created locally.

Run the following command:
```bash
# Safely remove the entire hidden .paperclip directory from your home folder
rm -rf ~/.paperclip
```
*Note:* Deleting this will **not** affect the FinOSafe company files you saved in your workspace (`proxmox_home_server/paperclip/finosafe/`), as those are safely stored outside the hidden system directory.

### Step 3: Clean Up Global NPM Packages & NPX Cache
We want to remove the cached CLI tools (`paperclipai`, `companies.sh`) so they don't accidentally execute locally again.

```bash
# Remove global installations (if any were installed via npm install -g)
npm uninstall -g paperclipai @paperclipai/companies-tool companies.sh

# Clear the npx cache to remove downloaded execution binaries
rm -rf ~/.npm/_npx/*/node_modules/paperclipai
rm -rf ~/.npm/_npx/*/node_modules/companies.sh
rm -rf ~/.npm/_npx/*/node_modules/@embedded-postgres
```
*Alternative:* If you want to aggressively clear the entire NPX cache (this will clear cached downloads for other npx commands too, but is perfectly safe as npm will just re-download them next time they are needed):
```bash
rm -rf ~/.npm/_npx/
```

### Step 4: Verify Complete Removal
To confirm that your MacBook is completely clean of Paperclip:
1.  Check port 3100: `lsof -i :3100` (Should return nothing).
2.  Check for the directory: `ls -la ~/.paperclip` (Should return "No such file or directory").

## Conclusion
Your MacBook is now thoroughly cleaned of the local Paperclip instance. All future Paperclip management should occur directly on the Proxmox dashboard at `http://192.168.1.30:3101`.
