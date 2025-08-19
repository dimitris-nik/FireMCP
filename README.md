# FireMCP

## Usage

- Run `get-imgs.sh` to generate kernel and rootfs (Docker required).  
- Run `start.py` to create networks and start the Firecracker microVM.  
- Place the `run-inside-guest.sh` script inside the guest VM (easiest method currently is probably just copy-pasting and using `vi`).  

If all went well (most certainly not) two MCP fetch servers are now running on two Firejail containers inside the Firecracker VM on `172.20.0.2:8080`.
