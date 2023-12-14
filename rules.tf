# Distributed firewall
resource "aviatrix_distributed_firewalling_config" "enable-dcf" {
  enable_distributed_firewalling = true
}

resource "aviatrix_smart_group" "mktg" {
  name = "MarketingApp"
  selector {
    match_expressions {
      type = "vm"
      tags = {
        environment = "mktg"
      }
    }
  }
}

resource "aviatrix_smart_group" "acct" {
  name = "AccountingApp"
  selector {
    match_expressions {
      type = "vm"
      tags = {
        environment = "acct"
      }
    }
  }
}

resource "aviatrix_smart_group" "vpn" {
  name = "VpnUsers"
  selector {
    match_expressions {
      type = "subnet"
      name = "avx-gw-subnet"
    }
    match_expressions {
      type = "subnet"
      name = "avx-hagw-subnet"
    }
  }
}

resource "aviatrix_smart_group" "source-ip" {
  name = "source-ip"
  selector {
    match_expressions {
      cidr = var.source_ip
    }
  }
}

resource "aviatrix_smart_group" "aci-subnet" {
  name = "MarketingAppAci"
  selector {
    match_expressions {
      type = "subnet"
      name = "aci-subnet"
    }
  }
}

resource "aviatrix_web_group" "allowed_url" {
  name = "allowed-urls"
  selector {
    match_expressions {
      urlfilter = "https://github.com/AviatrixSystems"
    }
  }
}

resource "aviatrix_web_group" "allowed_web" {
  name = "allowed-domains"
  selector {
    match_expressions {
      snifilter = "aviatrix.com"
    }
    match_expressions {
      snifilter = "www.aviatrix.com"
    }
  }
}

resource "aviatrix_distributed_firewalling_policy_list" "policy" {
  policies {
    name     = "inbound-http"
    action   = "PERMIT"
    priority = 4
    protocol = "TCP"
    port_ranges {
      lo = 8080
    }
    logging = true
    watch   = false
    src_smart_groups = [
      aviatrix_smart_group.source-ip.uuid
    ]
    dst_smart_groups = [
      aviatrix_smart_group.aci-subnet.uuid
    ]
  }
  policies {
    name     = "aci-smb-access"
    action   = "PERMIT"
    priority = 5
    protocol = "TCP"
    port_ranges {
      lo = 445
    }
    logging = true
    watch   = false
    src_smart_groups = [
      aviatrix_smart_group.aci-subnet.uuid
    ]
    dst_smart_groups = [
      "def000ad-0000-0000-0000-000000000001",
    ]
  }
  policies {
    name     = "aci-web-access"
    action   = "PERMIT"
    priority = 10
    protocol = "TCP"
    port_ranges {
      lo = 443
    }
    port_ranges {
      lo = 80
    }
    logging = true
    watch   = false
    src_smart_groups = [
      aviatrix_smart_group.aci-subnet.uuid
    ]
    dst_smart_groups = [
      "def000ad-0000-0000-0000-000000000001",
    ]
  }
  policies {
    name     = "mktg-vm-web-traffic"
    action   = "PERMIT"
    priority = 50
    protocol = "TCP"
    port_ranges {
      lo = 443
    }
    port_ranges {
      lo = 80
    }
    logging = true
    watch   = false
    src_smart_groups = [
      aviatrix_smart_group.mktg.uuid,
    ]
    dst_smart_groups = [
      "def000ad-0000-0000-0000-000000000001",
    ]
  }

  policies {
    name     = "MarketingAccounting"
    action   = "PERMIT"
    priority = 50
    protocol = "ICMP"
    logging  = true
    watch    = false
    src_smart_groups = [
      aviatrix_smart_group.mktg.uuid
    ]
    dst_smart_groups = [
      aviatrix_smart_group.acct.uuid
    ]
  }

  policies {
    name     = "AllowFromClient"
    action   = "PERMIT"
    priority = 100
    protocol = "Any"
    logging  = false
    watch    = false
    src_smart_groups = [
      aviatrix_smart_group.vpn.uuid
    ]
    dst_smart_groups = [
      aviatrix_smart_group.mktg.uuid,
      aviatrix_smart_group.acct.uuid,
      aviatrix_smart_group.aci-subnet.uuid
    ]
  }

  policies {
    name     = "ExplicitDenyAll"
    action   = "DENY"
    priority = 4096
    protocol = "Any"
    logging  = true
    watch    = false
    src_smart_groups = [
      "def000ad-0000-0000-0000-000000000000"
    ]
    dst_smart_groups = [
      "def000ad-0000-0000-0000-000000000000"
    ]
  }

  policies {
    name     = "DefaultAllowAll"
    action   = "PERMIT"
    priority = 2147483647
    protocol = "Any"
    logging  = false
    watch    = true
    src_smart_groups = [
      "def000ad-0000-0000-0000-000000000000"
    ]
    dst_smart_groups = [
      "def000ad-0000-0000-0000-000000000000"
    ]
  }
  depends_on = [
    aviatrix_distributed_firewalling_config.enable-dcf
  ]
}
