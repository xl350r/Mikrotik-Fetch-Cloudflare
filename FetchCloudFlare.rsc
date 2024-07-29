# Fetch the JSON data from the URL
/tool fetch url="https://api.cloudflare.com/client/v4/ips" mode=https http-header-field="Content-Type: application/json" dst-path=cf_ips.json

# Read the JSON data from the file
:local jsonContent [/file get cf_ips.json contents]

# Define keys to look for in JSON content
:local ipv4Key "\"ipv4_cidrs\""
:local ipv6Key "\"ipv6_cidrs\""

# Extract the ipv4_cidrs array
:local ipv4Start ([:find $jsonContent $ipv4Key] + ([:len $ipv4Key] + 2))
:local ipv4End [:find $jsonContent "]" $ipv4Start]
:local ipv4Cidrs [:pick $jsonContent $ipv4Start $ipv4End]

# Extract the ipv6_cidrs array
:local ipv6Start ([:find $jsonContent $ipv6Key] + ([:len $ipv6Key] + 2))
:local ipv6End [:find $jsonContent "]" $ipv6Start]
:local ipv6Cidrs [:pick $jsonContent $ipv6Start $ipv6End]

# Print extracted data
#:put "ipv4_cidrs: $ipv4Cidrs"
#:put "ipv6_cidrs: $ipv6Cidrs"

:global addressListExists do={
    :local listName $1
    :local exists false
    /ip firewall address-list
    :foreach item in=[find] do={
        :if ([get $item list] = $listName) do={
            :set exists true
        }
    }
    :return $exists
}

:global cleanCidr do={
    :local cidr $1
    :if ([:pick $cidr 0 1] = "0") do={
        :set cidr [:pick $cidr 1 [:len $cidr]]

    }
    :return $cidr
}

:put "deleting lists"
# delete existing lists if they exist
:if ([$addressListExists "cloudflare-ipv4"]) do={
    /ip firewall address-list 
    :foreach item in=[find list="cloudflare-ipv4"] do={
        remove $item
    }
}
:if ([$addressListExists "cloudflare-ipv6"]) do={
    /ip firewall address-list 
    :foreach item in=[find list="cloudflare-ipv6"] do={
        remove $item
    }
}

:put "creating lists"
/ip firewall address-list
add list="cloudflare-ipv4" disabled=no
add list="cloudflare-ipv6" disabled=no

:put "Adding to lists"

# Process and print IPv4 CIDRs
:local ipv4List [:toarray $ipv4Cidrs]
:foreach cidr in=$ipv4List do={
    #:local cCider 
    #:put [$cleanCidr [:pick $cidr 1 ([:len $cidr])]]
    #:put "IPv4 CIDR: $cCidr"
    /ip firewall address-list add list="cloudflare-ipv4" address=[$cleanCidr [:pick $cidr 1 ([:len $cidr])]]
}

# Process and print IPv6 CIDRs
#:local ipv6List [:toarray $ipv6Cidrs]
#:foreach cidr in=$ipv6List do={
#    :local cCidr [:pick $cidr 1 ([:len $cidr] )]
#    :put "IPv6 CIDR: $cCidr"
#    /ip firewall address-list add list="cloudflare-ipv6" address=$cleanCidr
#}
:put "Done adding to lists"
# Clean up

:foreach item in=[find list="cloudflare-ipv4"] do={:if ([get $item address] = "0.0.0.0") do={remove $item} }  
:foreach item in=[find list="cloudflare-ipv6"] do={:if ([get $item address] = "0.0.0.0") do={remove $item} }  
