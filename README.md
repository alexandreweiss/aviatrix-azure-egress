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

Marketing VM will be used to demonstrate internet egress. You can connect to it using ssh public key via Azure Bastion

Marketing and accounting spoke are both connected to the Azure Hub transit using Aviatrix Spoke to Transit attachment (we do not use native Azure vnet peering)

## How to apply the secure egress policy ?
Distributed Cloud Firewall is used to do egress filtering based on domain and URLs.
Workloads like Marketing is identified by a "Smart Group" that will be used as "Source" of the security rule.