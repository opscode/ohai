# frozen_string_literal: true
#
# Author:: Benjamin Black (<bb@chef.io>)
# Copyright:: Copyright (c) 2008-2016 Chef Software, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

Ohai.plugin(:Network) do
  require_relative "../../mixin/network_helper"

  provides "network", "network/interfaces"
  provides "counters/network", "counters/network/interfaces"

  include Ohai::Mixin::NetworkHelper

  def parse_media(media_string)
    media = {}
    line_array = media_string.split(" ")

    0.upto(line_array.length - 1) do |i|
      unless line_array[i].eql?("none")

        if line_array[i + 1] =~ /^\<([a-zA-Z\-\,]+)\>$/
          media[line_array[i]] = {} unless media.key?(line_array[i])
          if media[line_array[i]].key?("options")
            $1.split(",").each do |opt|
              media[line_array[i]]["options"] << opt unless media[line_array[i]]["options"].include?(opt)
            end
          else
            media[line_array[i]]["options"] = $1.split(",")
          end
        else
          if line_array[i].eql?("autoselect")
            media["autoselect"] = {} unless media.key?("autoselect")
            media["autoselect"]["options"] = []
          end
        end
      else
        media["none"] = { "options" => [] }
      end
    end

    media
  end

  def darwin_encaps_lookup(ifname)
    return "Loopback" if ifname.eql?("lo")
    return "1394" if ifname.eql?("fw")
    return "IPIP" if ifname.eql?("gif")
    return "6to4" if ifname.eql?("stf")
    return "dot1q" if ifname.eql?("vlan")

    "Unknown"
  end

  def scope_lookup(scope)
    return "Node" if scope.eql?("::1")
    return "Link" if /^fe80\:/.match?(scope)
    return "Site" if /^fec0\:/.match?(scope)

    "Global"
  end

  def excluded_setting?(setting)
    setting.match("_sw_cksum")
  end

  def locate_interface(ifaces, ifname, mac)
    return ifname unless ifaces[ifname].nil?
    # oh well, time to go hunting!
    return ifname.chop if /\*$/.match?(ifname)

    ifaces.each_key do |ifc|
      ifaces[ifc][:addresses].each_key do |addr|
        return ifc if addr.eql? mac
      end
    end

    nil
  end

  collect_data(:darwin) do
    network Mash.new unless network
    network[:interfaces] ||= Mash.new
    counters Mash.new unless counters
    counters[:network] ||= Mash.new

    so = shell_out("route -n get default")
    so.stdout.lines do |line|
      if line =~ /(\w+): ([\w\.]+)/
        case $1
        when "gateway"
          network[:default_gateway] = $2
        when "interface"
          network[:default_interface] = $2
        end
      end
    end

    iface = Mash.new
    so = shell_out("ifconfig -a")
    cint = nil
    so.stdout.lines do |line|
      if line =~ /^([0-9a-zA-Z\.\:\-]+): \S+ mtu (\d+)$/
        cint = $1
        iface[cint] ||= Mash.new
        iface[cint][:addresses] ||= Mash.new
        iface[cint][:mtu] = $2
        if line =~ /\sflags\=\d+\<((UP|BROADCAST|DEBUG|SMART|SIMPLEX|LOOPBACK|POINTOPOINT|NOTRAILERS|RUNNING|NOARP|PROMISC|ALLMULTI|SLAVE|MASTER|MULTICAST|DYNAMIC|,)+)\>\s/
          flags = $1.split(",")
        else
          flags = []
        end
        iface[cint][:flags] = flags.flatten
        if cint =~ /^(\w+)(\d+.*)/
          iface[cint][:type] = $1
          iface[cint][:number] = $2
          iface[cint][:encapsulation] = darwin_encaps_lookup($1)
        end
      end
      if line =~ /^\s+ether ([0-9a-f\:]+)/
        iface[cint][:addresses] ||= Mash.new
        iface[cint][:addresses][$1] = { "family" => "lladdr" }
        iface[cint][:encapsulation] = "Ethernet"
      end
      if line =~ /^\s+lladdr ([0-9a-f\:]+)\s/
        iface[cint][:addresses] ||= Mash.new
        iface[cint][:addresses][$1] = { "family" => "lladdr" }
      end
      if line =~ /\s+inet (\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}) netmask 0x(([0-9a-f]){1,8})\s*$/
        iface[cint][:addresses] ||= Mash.new
        iface[cint][:addresses][$1] = { "family" => "inet", "netmask" => hex_to_dec_netmask($2) }
      end
      if line =~ /\s+inet (\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}) netmask 0x(([0-9a-f]){1,8}) broadcast (\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/
        iface[cint][:addresses] ||= Mash.new
        iface[cint][:addresses][$1] = { "family" => "inet", "netmask" => hex_to_dec_netmask($2) , "broadcast" => $4 }
      end
      if line =~ /\s+inet6 ([a-f0-9\:]+)(\s*|(\%[a-z0-9]+)\s*) prefixlen (\d+)\s*/
        iface[cint][:addresses] ||= Mash.new
        iface[cint][:addresses][$1] = { "family" => "inet6", "prefixlen" => $4 , "scope" => scope_lookup($1) }
      end
      if line =~ /\s+inet6 ([a-f0-9\:]+)(\s*|(\%[a-z0-9]+)\s*) prefixlen (\d+) scopeid 0x([a-f0-9]+)/
        iface[cint][:addresses] ||= Mash.new
        iface[cint][:addresses][$1] = { "family" => "inet6", "prefixlen" => $4 , "scope" => scope_lookup($1) }
      end
      if line =~ /^\s+media: ((\w+)|(\w+ [a-zA-Z0-9\-\<\>]+)) status: (\w+)/
        iface[cint][:media] ||= Mash.new
        iface[cint][:media][:selected] = parse_media($1)
        iface[cint][:status] = $4
      end
      if line =~ /^\s+supported media: (.*)/
        iface[cint][:media] ||= Mash.new
        iface[cint][:media][:supported] = parse_media($1)
      end
    end

    so = shell_out("arp -an")
    so.stdout.lines do |line|
      if line =~ /^\S+ \((\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\) at ([a-fA-F0-9\:]+) on ([a-zA-Z0-9\.\:\-]+).*\[(\w+)\]/
        # MAC addr really should be normalized to include all the zeroes.
        next if iface[$3].nil? # this should never happen

        iface[$3][:arp] ||= Mash.new
        iface[$3][:arp][$1] = $2
      end
    end

    settings = Mash.new
    so = shell_out("sysctl net")
    so.stdout.lines do |line|
      if line =~ /^([a-zA-Z0-9\.\_]+)\: (.*)/
        # should normalize names between platforms for the same settings.
        settings[$1] = $2 unless excluded_setting?($1)
      end
    end

    network[:settings] = settings
    network[:interfaces] = iface

    net_counters = Mash.new
    so = shell_out("netstat -i -d -l -b -n")
    so.stdout.lines do |line|
      if line =~ /^([a-zA-Z0-9\.\:\-\*]+)\s+\d+\s+\<[a-zA-Z0-9\#]+\>\s+([a-f0-9\:]+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/ ||
          line =~ /^([a-zA-Z0-9\.\:\-\*]+)\s+\d+\s+\<[a-zA-Z0-9\#]+\>(\s+)(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/
        ifname = locate_interface(iface, $1, $2)
        next if iface[ifname].nil? # this shouldn't happen, but just in case

        net_counters[ifname] ||= Mash.new
        net_counters[ifname] = { rx: { bytes: $5, packets: $3, errors: $4, drop: 0, overrun: 0, frame: 0, compressed: 0, multicast: 0 },
                                 tx: { bytes: $8, packets: $6, errors: $7, drop: 0, overrun: 0, collisions: $9, carrier: 0, compressed: 0 },
        }
      end
    end

    counters[:network][:interfaces] = net_counters
  end
end
