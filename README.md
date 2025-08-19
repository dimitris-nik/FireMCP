# FireMCP
Usage
Run get-imgs.sh to generate kernel and rootfs (Docker required).
Run start.py to create networks and start the firecracker microVM.
Place the run-inside-guest.sh script inside the guest vm (easiest method currently is propably just copy pasting and using vi).

If all went well (most certanly not) two mcp fetch servers are now running on two firejail containers inside the firecracker vm on 172.20.0.2:8080 
