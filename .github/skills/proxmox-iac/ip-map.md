# IP Address Map

Subnet: `192.168.0.0/24` · Gateway: `192.168.0.1` · Static container block: `.200–.254`

**Keep this file up to date when adding or removing containers. Next free IP: `192.168.0.211`**

| IP Address      | CT ID | Node  | Hostname                | Notes                                                     |
|-----------------|-------|-------|-------------------------|-----------------------------------------------------------|
| 192.168.0.1     | —     | —     | router                  | Gateway, do not assign                                    |
| 192.168.0.202   | 100   | node2 | pihole                  |                                                           |
| 192.168.0.203   | 101   | node2 | nginxproxymanager       |                                                           |
| 192.168.0.211   | 109   | node2 | n8n                     |                                                           |
| 192.168.0.213   | 102   | node1 | docker                  |                                                           |
| 192.168.0.214   | 112   | node1 | invoiceninja            |                                                           |
| 192.168.0.221   | 113   | node1 | CT113                   | React/Vite/Tailwind clone baseline, not Terraform-managed |
| 192.168.0.225   | 104   | node1 | prometheus              |                                                           |
| 192.168.0.226   | 105   | node1 | grafana                 |                                                           |
| 192.168.0.227   | 106   | node1 | uptimekuma              |                                                           |
| 192.168.0.230   | 900   | node1 | ops-controller          |                                                           |
| 192.168.0.231   | 103   | node1 | redis                   | Terraform-managed                                         |
| 192.168.0.232   | 111   | node1 | prometheus-pve-exporter |                                                           |
| 192.168.0.210   | 114   | node1 | samba                   | Samba file server; bind mounts /backup_pool/documents + /media |
| 192.168.0.173   | 108   | node2 | cloudflare-ddns         | Static IP outside reserved container block                |
