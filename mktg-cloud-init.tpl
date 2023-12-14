#cloud-config
package_update: true
packages:
  - docker.io
write_files:
  - owner: root:root
    append: true
    path: /root/config.yaml
    content: |
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
runcmd:
  - sudo docker run -d --restart unless-stopped --name gatus -p 80:8080 --mount type=bind,source=/root/config.yaml,target=/config/config.yaml aweiss4876/gatus-aviatrix
