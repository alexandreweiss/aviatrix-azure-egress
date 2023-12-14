ui:
  header: "Azure egress from Marketing App"
  title: "Azure egress from Marketing App"
endpoints:
  - name : Accounting-VM
    url: "icmp://${accounting_vm_ip}"
    interval: 10s
    group: Applications
    conditions:
      - "[CONNECTED] == true"
  - name: www.aviatrix.com
    method: HEAD
    url: "https://www.aviatrix.com/"
    interval: 5s
    group: Internet
    conditions:
      - "[STATUS] == 200"
  - name: github.com/AviatrixSystems
    method: HEAD
    url: "https://github.com/AviatrixSystems"
    interval: 5s
    group: Internet
    conditions:
      - "[STATUS] == 200"
  - name: github.com/microsoft
    method: HEAD
    url: "https://github.com/microsoft"
    interval: 5s
    group: Internet
    conditions:
      - "[STATUS] == 200"