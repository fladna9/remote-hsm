# Remote HSM

## Introduction
The goal of this script is to share a locally plugged HSM to a remote host using SSH tunnel.

This script is written to be launched on the local machine, so the token plugged in is shared to remote.


## PKI and HSM in a SME

This script is part of the tutorial i wrote called PKI and HSM in a SME. 

You can view it here: https://fladnag.net/?page_id=167


## Requirements
You'll need:
- A local machine (tested on Debian 9 stretch amd64)
- A remote machine (tested on Debian 9 stretch amd64)
- A HSM (tested with a Nitrokey)
- The PKCS11 library to communicate to your HSM (tested with OpenSC, as Nitrokey is a OpenSmartCard implementation)
- Compiled p11-kit on local AND remote machine (Debian stretch one is not *recent* enough to have the remote functionality working)
- The p11-kit-client systemd service (see below)


## Script pseudo-code
1. Present user the parameters used for the script
2. Enable and start local and remote systemd user service if needed
3. Look if a sharing is already in progress on the remote
4. Test if local and remote PKCS11 providers are present
5. Start the token sharing on the first (and only one) token found, from local to remote
6. Test if remote can see the SSH-tunneled token
7. Test if EJBCA is present on remote
8. Restart EJBCA on remote 


## Clean up script
In case you have a problem, or main script seems stuck for more than a minute, interrupt execution of `remote-hsm.sh`and execute `cleanup.sh`, then try again.


## p11-kit client Systemd Service (to do on local and remote machines)
Its only goal is to create a folder in ``/run/user/`id -u` `` where the Unix socket file will be kept, locally and remotely. 

You need to have the following service to be created at ``~/.config/systemd/user/p11-kit-client.service``:

````ini
[Unit]
Description=p11-kit client

[Service]
Type=oneshot
RemainAfterExit=true
RuntimeDirectory=p11-kit
ExecStart=/bin/true

[Install]
WantedBy=default.target
````

After installation, don't forget to run ``$ systemctl --user daemon-reload`` and ``systemctl --user enable p11-kit-client.service && systemctl --user start p11-kit-client.service``.

You can check everything is ok with ``$ ls /run/user/`id -u`/``: if a ``p11-kit``folder exists, we're okay to go :)