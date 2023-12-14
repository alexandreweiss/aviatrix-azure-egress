# Internet Egress in Azure using Aviatrix

## Context
By Sep. 2025, Microsoft will stop providing default internet egress for VMs that :
- Do not have a public,
- Are not behind a Standard Load Balancer with outbound rules,
- Are not behind a NAT Gateway
- OR ... ARE NOT BEHIND AN AVIATRIX GATEWAY !
  
To illustrate that 4th case, code in this repository deploys Aviatrix in Hub and Spoke fashion with decentralized secured egress using Aviatrix spoke gateway.

## What this will deploy ?
This code will create :
- One resource group containing Aviatrix Hub : one vnet and Aviatrix Gateway,
- One resource group containing Aviatrix Accounting spoke : one vnet and Aviatrix Gateway,
- One resource group containing Aviatrix Marketing spoke and Azure bastion along with one vnet,
- One resource group containing test VMs inserted into each department vnet.

Marketing VM will be used to demonstrate internet egress. You can use Azure Bastion to connect to Windows Jumpbox VM, then browse Marketing VM on port 80
Username of the Windows Jumpbox VM is admin-lab

Marketing and accounting spoke are both connected to the Azure Hub transit using Aviatrix Spoke to Transit attachment (we do not use native Azure vnet peering)

## How to apply the secure egress policy ?
Distributed Cloud Firewall is used to do egress filtering based on domain and URLs.
Workloads like Marketing is identified by a "Smart Group" that will be used as "Source" of the security rule.

## Deployment
- First deploy with isStep2 = false
- Once deployed, force isStep2 = true and run deployment again.

We rely on a modified version of Gatus where we inject the Aviatrix Root CA needed for Gatus to test endpoints where Aviatrix Spoke is doing TLS decryption.
Below is the DockerFile sample : 

```
# Build the go application into a binary
FROM golang:alpine as builder
RUN apk --update add ca-certificates
WORKDIR /app
COPY . ./
COPY ca-aviatrix.pem /usr/local/share/ca-certificates
RUN update-ca-certificates
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o gatus .

# Run Tests inside docker image if you don't have a configured go environment
#RUN apk update && apk add --virtual build-dependencies build-base gcc
#RUN go test ./... -mod vendor

# Run the binary on an empty container
FROM scratch
COPY --from=builder /app/gatus .
COPY --from=builder /app/config.yaml ./config/config.yaml
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
ENV PORT=8080
EXPOSE ${PORT}
ENTRYPOINT ["/gatus"]
```

# Open container access via MKTG spoke
- Open Spoke NSG to port 80 with your source IP
- Create a DNAT rule with 
  - your source IP as Src CIDR
  - internal IP address of mktg spoke as Dst CIDR
  - port 80 as Dst Port
  - TCP as Protocol
  - IP of the MKTG App ACI
  - port 8080 as DNAT Port
  - Apply to route table
- DCF must have inbound rule
  - your source IP as source smart group
  - ACI Subnet as destination subnet
  - TCP as Protocol
  - 8080 as Port (ACI container listen on that port)